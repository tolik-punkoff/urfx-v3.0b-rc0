;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


\ here  \ for size reports

module z80dis
<published-words>

;; set this! always return a proper byte!
vect zx-c@  ( pc -- byte )

0 quan pc  ;; can be bigger than $FFFF

;; show numbers in hex?
true quan hex?
;; allow "LD r16, 16" pseudoinstructions?
true quan allow-ld-r16-r16?
;; show opcodes in "disasm-range"?
true quan show-opcodes?

;; set by "disasm-one"
0 quan orig-pc
0 quan end-pc


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some info about disassembled instruction

enum{
  def: instr-other
  def: instr-jr
  def: instr-djnz
  def: instr-jp
  def: instr-call
  def: instr-ret
}

 0 quan instr     -- instruction type
-1 quan instr-cc  -- for conditional branches/rets
;; if instr-mm is negative for branch, it is "(hl)"
-1 quan instr-mm  -- memory address or branch destination


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
<private-words>

0 quan ixy-ch   ;; contains 0, [char] x or [char] y
0 quan cr-disp  ;; for (ix+) and (iy+)
0 quan cr-dptr  ;; pointer in the disasm string buffer
0 quan cr-opc   ;; current opcode


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; disassembly buffer

;; first char is counter (set in "disasm-one")
255 constant #disbuf
create disbuf #disbuf 1+ allot create;
disbuf #disbuf + constant disbuf-end

<published-words>
: .char ( ch )  cr-dptr dup disbuf-end < ?< c! cr-dptr:1+! || drop >? ;
: .str  ( addr len )  swap << over +?^| c@++ .char 1 under- |? else| 2drop >> ;

: ixy?  ( -- ch )  ixy-ch ;
<private-words>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; external label manager hooks
<published-words>

;; label types
enum{
  def: lbl-reg-8      ;; load into register
  def: lbl-reg-16     ;; load into register
  def: lbl-mem-8      ;; memory access
  def: lbl-mem-16     ;; memory access
  def: lbl-branch-8   ;; jr/djnz
  def: lbl-branch-16  ;; jump or call
  def: lbl-ixy-8      ;; ix/iy offset (you can use "ixy?" to get "x" or "y" char)
  def: lbl-port-8     ;; in/out with immediate byte port
}

0 quan label-type   -- see above
0 quan label-value  -- you can change this

;; default handler
: def-label-hook  ( TRUE // FALSE )  false ;

;; ( TRUE // FALSE )
;; return TRUE to stop the engine putting literal label value.
;; use ".char" and ".str" below to put the label name yourself.
['] def-label-hook vectored zx-label?
<private-words>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

create ixydisp-table
  $00 c, $00 c, $00 c, $00 c,
  $00 c, $00 c, $70 c, $00 c,
  $40 c, $40 c, $40 c, $40 c,
  $40 c, $40 c, $BF c, $40 c,
  $40 c, $40 c, $40 c, $40 c,
  $40 c, $40 c, $40 c, $40 c,
  $00 c, $08 c, $00 c, $00 c,
  $00 c, $00 c, $00 c, $00 c,
create;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; disassembly buffer

: .bl  bl .char ;
: .,   [char] , .char .bl ;
: .)   [char] ) .char ;
: .#bl [char] # .char .bl ;

: .str#2  ( addr )  2 string:-trailing .str ;
: .str#4  ( addr )  drop + 4 string:-trailing .str ;

;; end of mnemonics
: .mend   << cr-dptr disbuf - 7 < ?^| .bl |? else| >> ;
: .mnemo  ( addr count )  .str .mend ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
: ?lbl  ( value type -- bool )
  label-type:! label-value:! zx-label? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
: .n8  ( n )
  lo-byte
  base @ >r
  hex? ?< hex <# # # [char] $ #hold || decimal <# #s >?
  #> .str r> base ! ;

: .n16  ( n )
  lo-word
  base @ >r
  hex? ?< hex <# # # # # [char] $ #hold || decimal <# #s >?
  #> .str r> base ! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; advances PC

: cfetch  ( -- b )  pc lo-word zx-c@ pc:1+! ;
: wfetch  ( -- b )  cfetch cfetch 8 lshift or ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level numeric printers

;; used in " ld r16, value"
: .v16
  .#bl
  wfetch
  lbl-reg-16 ?lbl ?exit
  label-value .n16 ;

;; jp, call
: .j16
  .#bl
  wfetch dup instr-mm:!
  lbl-branch-16 ?lbl ?exit
  label-value .n16 ;

;; jr, djnz
: .jr8
  .#bl
  cfetch c>s pc + lo-word dup instr-mm:!
  lbl-branch-8 ?lbl ?exit
  label-value .n16 ;

;; "()", destination, 16 bit
: .m16-1st
  wfetch dup instr-mm:!
  lbl-mem-16 ?lbl not?< label-value .n16 >?
  "  ()" .str ;

;; "()", source, 16 bit
: .m16-2nd
  " () " .str
  wfetch dup instr-mm:!
  lbl-mem-16 ?lbl ?exit
  label-value .n16 ;

;; "()", destination, 8 bit
: .m8-1st
  wfetch dup instr-mm:!
  lbl-mem-8 ?lbl not?< label-value .n16 >?
  "  ()" .str ;

;; "()", source, 8 bit
: .m8-2nd
  " () " .str
  wfetch dup instr-mm:!
  lbl-mem-8 ?lbl ?exit
  label-value .n16 ;

;; (ix)/(iy) offset
: .disp
  cr-disp lbl-ixy-8 ?lbl ?exit
  cr-disp lo-byte c>s
  base @ >r decimal <# #signed #>
  .str r> base ! ;

|: .port-n8
  cfetch lbl-port-8 ?lbl ?exit
  label-value .n8 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; various helpers

0 quan (r1st)

|: .(ixy+)  " (i" .str ixy-ch .char " +)" .str ;

: .ixy-mem-1st  .disp .bl .(ixy+) ;
: .ixy-mem-2nd  .(ixy+) .bl .disp ;

: .ixy-mem  (r1st) ?< .ixy-mem-1st || .ixy-mem-2nd >? ;

: .r8hlm
  ixy-ch ?< .ixy-mem || " (hl)" .str >? ;

;; undocumented IX/IY 8-bit part access
: .r8ixy
  ixy-ch ?<
    dup [char] h = over [char] l = or ?< ixy-ch .char >?
  >? .char ;

: (.r8)  ( r8 1st? )
  (r1st):!
  7 and  " bcdehl.a" drop + c@
  dup [char] . = ?< drop .r8hlm || .r8ixy >? ;

: .r8-1st  ( r8 )  true (.r8) ;
: .r8-2nd  ( r8 )  false (.r8) ;

: .r16-hl-ixy
  ixy-ch ?exit< [char] i .char ixy-ch .char >? " hl" .str ;

: .r16-common  ( r16 addr count )
  drop swap 3 and 2* +
  dup c@ [char] h = ?exit< drop .r16-hl-ixy >?
  .str#2 ;

: .r16-sp  ( r16 )
  cr-opc 4 rshift " bcdehlsp" .r16-common ;

: .r16-af  ( r16 )
  cr-opc 4 rshift " bcdehlaf" .r16-common ;

: .cc  ( cc )
  dup instr-cc:!
  7 and 2* " nzz ncc popep m " drop + dup c@ .char
  1+ c@ dup 32 <> ?exit< .char >? drop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; $CB decoders

: cb-unixy
  ;; special undocumented thing
  ixy-ch not?exit ;; `bit` doesn't need undoc ixy
  cr-opc dup $80 and swap 7 and 6 <> and
  ?< ., .ixy-mem-2nd >? ;

: cb-bit
  cr-opc 4 rshift $0C and 4- " bit res set " .str#4 .mend
  cr-opc 3 rshift 7 and [char] 0 + .char
  ., ;

: cb-shift
  cr-opc 2/ $1C and
  " rlc rrc rl  rr  sla sra sls srl " .str#4 .mend ;

: cb
  cr-opc $C0 and ?< cb-bit || cb-shift >?
  cr-opc .r8-2nd cb-unixy ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; $ED decoders

: ed-xrep
  cr-opc <<
    ;; two instructions with the wrong mnemonic length ;-)
    $A3 of?v| " outi" .str |?
    $AB of?v| " outd" .str |?
  else| ;; common code
    dup 3 and 2* " ldcpinot" drop + .str#2
    dup $08 and ?< [char] d || [char] i >? .char
    $10 and ?< [char] r .char >?
  >> ;

|: ed-x04-ret
  instr-ret instr:!
  " ret" .str
  cr-opc $08 and ?< [char] i || [char] n >?
  .char ;

|: ed-x04-im
  " im" .mnemo
  cr-opc $47 = ?exit< " 0/1" .str >?
  " # " .str
  cr-opc $10 and ?<
    cr-opc $08 and ?< [char] 2 || [char] 1 >?
  || [char] 0 >?
  .char ;

|: ed-x04-07
  cr-opc <<
    $47 of?v| " ld" .mnemo " i, a" |?
    $4F of?v| " ld" .mnemo " r, a" |?
    $57 of?v| " ld" .mnemo " a, i" |?
    $5F of?v| " ld" .mnemo " a, r" |?
    $67 of?v| " rrd" |?
    $6F of?v| " rld" |?
  else| drop " nope" >>
  .str ;

|: ed-x04
  cr-opc 7 and <<
    $04 of?v| " neg" .str |?
    $05 of?v| ed-x04-ret |?
    $06 of?v| ed-x04-im |?
    $07 of?v| ed-x04-07 |?
  else| drop " nope" .str >> ;

|: ed-x02-to-rr  .r16-sp ., .m16-2nd ;
|: ed-x02-to-mm  .m16-1st ., .r16-sp ;

|: ed-x02
  ;; r16
  cr-opc $01 and ?exit<
    " ld" .mnemo
    cr-opc $08 and ?< ed-x02-to-rr || ed-x02-to-mm >?
  >?
  cr-opc 2/ 4 and " sbc adc " .str#4 .mend
  " hl, " .str
  .r16-sp ;

|: ed-x01
  " out" .mnemo " (c), " .str
  cr-opc 3 rshift
  ;; check for `(hl)`, it is special here
  dup 7 and 6 = ?< drop " # 0" .str || .r8-2nd >? ;

|: ed-x00
  " in" .mnemo
  cr-opc 3 rshift
  ;; check for `(hl)`, it is special here
  dup 7 and 6 <> ?< .r8-1st ., || drop >?
  " (c)" .str ;

: ed
  cr-opc $A4 and $A0 = ?exit< ed-xrep >?
  cr-opc $C0 and $40 <> ?exit< " nope" .str >?
  cr-opc $04 and ?exit< ed-x04 >?
  cr-opc $02 and ?exit< ed-x02 >?
  cr-opc $01 and ?exit< ed-x01 >?
  ed-x00 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ld r8, r8 (and halt)

|: norm-grp1-lixy
  ;; this is for "ld l, (ix)" and such
  ixy-ch >r
  cr-opc 3 rshift 7 and 6 <> ?< ixy-ch:!0 >?
  cr-opc 3 rshift .r8-1st
  .,
  cr-opc 7 and 6 <> ?< rdrop 0 || r> >? ixy-ch:!
  cr-opc .r8-2nd ;

: norm-grp1
  cr-opc $76 = ?exit< " halt" .str >?
  " ld" .mnemo
  ixy-ch 0<>  cr-opc 3 rshift 7 and 6 =  cr-opc 7 and 6 = or and ?exit< norm-grp1-lixy >?
  cr-opc 3 rshift .r8-1st
  .,
  cr-opc .r8-2nd ;

: .alu-str
  cr-opc 2/ $1C and " add adc sub sbc and xor or  cp  " .str#4 .mend
  ;; two special opcodes
  cr-opc $38 and dup $08 = over $18 = or swap $00 = or
  ?exit< " a, " .str >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; call, ret, push, pop, etc.

|: norm-grp3-01
  cr-opc $08 and ?<
    cr-opc $30 and <<
      $00 of?v| " ret" .str instr-ret instr:! |?
      $10 of?v| " exx" .str |?
      \ $20 of?v| " jp" .mnemo " (" .str .r16-hl-ixy .) instr-jp instr:! |?
      $20 of?v| " jp" .mnemo .r16-hl-ixy instr-jp instr:! |?
      $30 of?v| " ld" .mnemo " sp, " .str .r16-hl-ixy |?
    else| drop >>
  || " pop" .mnemo .r16-af >? ;

|: norm-grp3-03
  cr-opc $38 and <<
    $00 of?v| " jp" .mnemo instr-jp instr:! .j16 |?
    ;; CB:$08 of?v||
    $10 of?v| " out" .mnemo .port-n8 "  (), a" .str |?
    $18 of?v| " in" .mnemo " a, () " .str .port-n8 |?
    $20 of?v| " ex" .mnemo " (sp), " .str .r16-hl-ixy |?
    $28 of?v| " ex" .mnemo " de, hl" .str |?
    $30 of?v| " di" .str |?
    $38 of?v| " ei" .str |?
  else| drop >> ;

|: norm-grp3-05
  cr-opc $08 and ?<  ;; prefixes already done, so only CALL is left
    " call" .mnemo instr-call instr:! .j16
  || " push" .mnemo .r16-af >? ;

: norm-grp3
  cr-opc 7 and <<
    $00 of?v| " ret" .mnemo  cr-opc 3 rshift .cc instr-ret instr:! |?
    $01 of?v| norm-grp3-01 |?
    $02 of?v| " jp" .mnemo  cr-opc 3 rshift .cc ., instr-jp instr:! .j16 |?
    $03 of?v| norm-grp3-03 |?
    $04 of?v| " call" .mnemo  cr-opc 3 rshift .cc ., instr-call instr:! .j16 |?
    $05 of?v| norm-grp3-05 |?
    $06 of?v| .alu-str .#bl cfetch lbl-reg-8 ?lbl not?< label-value .n8 >? |?
    $07 of?v| " rst" .mnemo .#bl cr-opc $38 and .n8 |?
  else| drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
|: norm-grp0-00-01
  cr-opc $08 and ?< " add" .mnemo .r16-hl-ixy ., .r16-sp
  || " ld" .mnemo .r16-sp ., .v16 >? ;

|: norm-grp0-00-20
  instr-jr instr:!
  " jr" .mnemo cr-opc 3 rshift 3 and .cc ., .jr8 ;

|: norm-grp0-00-10
  cr-opc 2/ 4 and
  dup ?< instr-jr || instr-djnz >? instr:!
  " djnzjr  " .str#4 .mend .jr8 ;

|: norm-grp0-00
  cr-opc 1 and ?exit< norm-grp0-00-01 >?
  cr-opc $20 and ?exit< norm-grp0-00-20 >?
  cr-opc $10 and ?exit< norm-grp0-00-10 >?
  cr-opc $08 and ?< " ex" .mnemo " af, af'" || " nop" >? .str ;

|: norm-grp0-02-01
  cr-opc 2/ 4 and " inc dec " .str#4 .mend .r16-sp ;

|: norm-grp0-02
  cr-opc 1 and ?exit< norm-grp0-02-01 >?
  " ld" .mnemo
  cr-opc $3C and <<
    $00 of?v| " (bc), a" .str |?
    $08 of?v| " a, (bc)" .str |?
    $10 of?v| " (de), a" .str |?
    $18 of?v| " a, (de)" .str |?
    $20 of?v| .m16-1st ., .r16-hl-ixy |?
    $28 of?v| .r16-hl-ixy ., ( .bl) .m16-2nd |?
    $30 of?v| .m8-1st ., [char] a .char |?
    $38 of?v| " a, " .str .m8-2nd |?
  else| drop >> ;

|: norm-grp0-04
  cr-opc $01 and 2 lshift " inc dec " .str#4 .mend
  cr-opc 3 rshift .r8-1st ;

|: norm-grp0-06-shift
  cr-opc 2/ $1C and " rlcarrcarla rra daa cpl scf ccf " .str#4 ;

|: norm-grp0-06-ld
  " ld" .mnemo cr-opc 3 rshift .r8-1st ., .#bl
  cfetch lbl-reg-8 ?lbl not?< label-value .n8 >? ;

|: (norm-grp0-06)
  cr-opc 1 and ?exit< norm-grp0-06-shift >?
  norm-grp0-06-ld ;

: norm-grp0
  cr-opc $06 and <<
    $00 of?v| norm-grp0-00 |?
    $02 of?v| norm-grp0-02 |?
    $04 of?v| norm-grp0-04 |?
    $06 of?v| (norm-grp0-06) |?
  else| drop >> ;

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
: norm
  cr-opc $C0 and <<
    $00 of?v| norm-grp0 |?
    $40 of?v| norm-grp1 |?
    $80 of?v| .alu-str cr-opc .r8-2nd |?  ;; alu a, r8
  else| drop norm-grp3 >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
<published-words>

;; ignores "A" and "(HL)"
|: dis-opc-ld-r8-r8?  ( opc -- dst-r8 src-r8 TRUE // FALSE )
  dup @100 @160 within not?exit< drop false >?
  dup @007 and 6 < not?exit< drop false >?
  dup @070 and 3 rshift
  swap @007 and
  true ;

|: 2sort  ( a b -- min max )
  2dup min nrot max ;

|: good-r16-pair?  ( r8-0 r8-1 -- r16 TRUE // FALSE )
  2sort 2dup 1- - ?exit< 2drop false >?
  drop 2 u/ true ;

|: .r16-ld  ( r16 )
  2 * " bcdehl" drop + .str#2 ;

|: dis-ld-r16-r16?  ( -- done-flag )
  allow-ld-r16-r16? not?exit&leave
  cr-opc dis-opc-ld-r8-r8? not?exit&leave
  ( dst-r8-0 src-r8-0 )
  pc zx-c@ dis-opc-ld-r8-r8? not?exit< 2drop false >?
  ( dst-r8-0 src-r8-0 dst-r8-1 src-r8-1 )
  rot good-r16-pair? not?exit< 2drop false >?
  nrot good-r16-pair? not?exit< drop false >?
  ( src-r16 dst-r16 )
  " ld" .mnemo .r16-ld ., .r16-ld
  true ;

;; check ix/iy prefix
|: disasm-check-ipfx
  << $DD of?v| [char] x ixy-ch:! |?
     $FD of?v| [char] y ixy-ch:! |?
  else| drop >> ;

|: disasm-ipfx-pre
  cfetch dup cr-opc:!
  dup $DD = over $FD = or ?<
    drop " nopx" .str
    ;; one byte back
    pc 1- lo-word pc:!
    r> cr-dptr over - exit
  >?
  ;; check if we have disp here
  dup 3 rshift ixydisp-table + c@
  1 rot 7 and lshift and ?< cfetch c>s cr-disp:! >? ;

: reset-dis-str  disbuf 1+ cr-dptr:! ;

;; returns disassembled text (only command, no address or bytes )
: disasm-one  ( -- saddr slen )
  pc orig-pc:!
  instr-other instr:! instr-cc:!t instr-mm:!t
  disbuf 1+ dup >r cr-dptr:!
  ixy-ch:!0 cr-disp:!0
  cfetch dup cr-opc:!
  dis-ld-r16-r16? ?< drop cfetch drop
  || disasm-check-ipfx
     ixy-ch ?< disasm-ipfx-pre >?
     cr-opc <<
       $CB of?v| cfetch cr-opc:! cb |?
       $ED of?v| cfetch cr-opc:! ed |?
     else| drop norm >> >?
  r> cr-dptr over -  dup disbuf c!
  pc end-pc:! ;

: dis-one  disasm-one 2drop ;
: dis-str  ( -- saddr slen )  disbuf c@++ ;

: dump-opcodes  ( from to )
  base @ >r hex
  << 2dup u< ?^| over zx-c@ <# bl #hold # # #> type  1 under+ |?
  else| 2drop >> r> base ! ;

: disasm-one-print
  endcr pc .hex4 ." : "
  disasm-one
  show-opcodes? ?<
    orig-pc end-pc dump-opcodes
    4 end-pc orig-pc - - 3 * 1+ bl #emit >?
  type cr ;

: disasm-range  ( from to )
  swap pc:!
  << dup pc u> ?^| disasm-one-print |? else| drop >> ;

seal-module
end-module z80dis

(*
here swap -
 dup .( Z80 disasm size: ) . .( bytes\n)
drop
*)
