;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; basic debug tools
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module DEBUG
<disable-hash>
using dart

code-naked-inline: (BP)
  int3
;code-no-stacks (force-inline)

true quan NAMED-BACKTRACE?

;; remove idx, copy nth item; 0 PICK is the same as DUP
code-swap-inline: PICK  ( ... idx -- ... n[top-idx-1] )
  mov   utos, [esp+] [utos*4]
;code-swap-next

;; remove idx, copy nth item; 0 RPICK is the same as RDUP
;; this is used only in DEBUG
code-swap-inline: RPICK  ( ... idx -- ... n[top-idx-1] )
  mov   utos, [ebp+] [utos*4]
;code-swap-next (inline-blocker) (force-inline)

code-swap-inline: RDEPTH  ( -- rstack-depth-before-this-call )
  push  utos
  mov   utos, [uadr+] uofs@ (rp0^) #
  sub   utos, ebp
  sar   utos, # 2
  dec   utos
;code-swap-next (inline-blocker)


\ : IMG-ADDR?  ( addr -- flag )  (elf-base-addr) here within ;
: IMG-ADDR?  ( addr -- flag )  forth::(img-addr?) ;

{no-inline}
: CFA-WHELP@  ( cfa -- addr count TRUE // FALSE )
  dup not?exit
  cfa>wfa dup not?exit ;; headerless word
  wfa>bfa bfa>sfa dup @ not?exit< drop false >?
  6 + c@++ dup ?< true || 2drop false >? ;

: .FREF  ( sfa )
  dup not?exit< drop >?
  @ dup not?exit< drop >?
  system:finfo>name system:finfo-name@ type ;

{no-inline}
: .ID  ( nfa )
  dup 0?exit< drop >?
  idcount dup 0?< 2drop " <noname>" >? type ;

{no-inline}
: .VOCNAME  ( vocid )
  dup ?exit< system:voc-header-nfa-ofs + @ .id >? drop ;

{no-inline}
: .IDVOCS  ( nfa )
  dup not?exit< drop >?
  nfa>lfa lfa>vfa @
  dup 0= over vocid: forth = or ?exit< drop >?
  system:voc-header-nfa-ofs + @
  dup not?exit< drop >?
  dup recurse .id ." :" ;

{no-inline}
: .IDFULL  ( nfa )
  dup not?exit< drop >? -- just in case
  dup .idvocs .id ;

{no-inline}
: .VOCNAME-FULL  ( vocid )
  dup 0?exit< drop >?
  system:voc-header-nfa-ofs + @ .idfull ;


: PAD+ID  ( nfa )
  dup 0?exit< drop >?
  idcount pad$:+ ;

: PAD+IDVOCS  ( nfa )
  dup not?exit< drop >?
  nfa>lfa lfa>vfa @
  dup 0= over vocid: forth = or ?exit< drop >?
  system:voc-header-nfa-ofs + @
  dup not?exit< drop >?
  dup recurse pad+id [char] : pad$:c+ ;

{no-inline}
: IDFULL>PAD  ( nfa -- addr count )
  pad$:!0
  dup not?< drop || dup pad+idvocs pad+id >? pad$:@ ;


;; dump data stack
{no-inline}
: .S
  endcr ." *** STACK DEPTH: " depth . ." ***\n"
  depth 32 min >r << r@ +?^| r0:1-! r@ 5 .r ." : "
                     r@ pick 12 .l
                     r@ pick ." $" .hex8 cr |? else| rdrop >> ;

: .HDR  ( nfa )
  ." NFA: $" dup .hex8 dup idcount ."  -- " type cr
  nfa>lfa
  ." HFA: $" dup lfa>hfa @ .hex8 cr
  ." VFA: $" dup lfa>vfa @ .hex8 cr
  ." XFA: $" dup lfa>xfa @ .hex8 cr
  ." FFA: $" dup lfa>ffa @ .hex8 cr
  ." CFA: $" dup lfa>cfa @ .hex8 cr
  ." PFA: $" dup lfa>pfa .hex8 cr
  drop ;

{no-inline}
: DUMP-IMG
  forth::(last-xfa) @ << dup ?^|
    ." ---------------------------\n" dup xfa>nfa .hdr @ |?
  else| drop >>
  ." ================================\n" ;

;; get word range from next and current xfa
: 2XFA>RANGE  ( next-xfa curr-xfa -- staddr endaddr )  xfa>dfa swap xfa>dfa ;
: IP-INSIDE?  ( next-xfa curr-xfa ip -- inside? )  nrot 2xfa>range bounds ;

;; this cannot find the very first word. meh.
{no-inline}
: IP>WORD-START/END  ( addr -- start-dfa after-last-pfa-byte TRUE // FALSE )
  dup img-addr? not?exit< drop false >?
  ;; first word?
\ endcr ." LAST-XFA: $" forth::(last-xfa) @ .hex8 ."  addr=$" dup .hex8 cr
  dup forth::(last-xfa) @ xfa>dfa u>= ?exit< drop forth::(last-xfa) @ xfa>dfa here true >?
  >r forth::(last-xfa) @ << ( curr | addr )
\ endcr ."   XFA: $" dup .hex8 ."  addr=$" r@ .hex8 cr
    dup @ dup not?v| rdrop 2drop false |?  ( next curr | addr )
\ endcr ."    DFA: $" dup xfa>dfa .hex8 ."  addr=$" r@ .hex8 cr
    over xfa>dfa r@ u< ?v| rdrop 2drop false |?
\ 2dup 2xfa>range ."   RNG: $" swap .hex8 ."  to $" .hex8 ."  addr: $" r@ .hex8 ."  bounds: " 2dup 2xfa>range r@ nrot bounds . cr
    2dup r@ ip-inside? not?^| nip |?
  else| rdrop 2xfa>range true >> ;

{no-inline}
: IP>WORD  ( addr -- nfa TRUE // FALSE )
  ip>word-start/end not?< false || drop dfa>wfa wfa>nfa true >? ;

{inline-blocker}
;; dump return stack
: (.R)  ( rskip )
  endcr ." *** RSTACK DEPTH: " rdepth over - . ." ***\n"
  rdepth over - 32 min +
  << dup +?^| 1-
     dup ?< dup 1- 5 forth:.r ." : " || ." <cur>: " >?
     dup rpick 12 forth:.l
     dup rpick ." $" .hex8
     named-backtrace? ?<
       dup rpick ip>word ?< ."  -- " dup .idfull
         nfa>lfa lfa>sfa dup @ ?< ."  (" .fref ." )" || drop >?
       >?
     >?
  cr |? else| drop >> ;

;; dump return stack
{inline-blocker}
: .R  1 (.r) ;

;; simple backtrace
{inline-blocker}
: BACKTRACE  .s 2 (.r) ;


{no-inline}
: .PFA?  ( addr )
  dup ip>word not?exit< drop >?
  2dup nfa>lfa lfa>pfa <> ?exit< 2drop >?
  ."  -- " .idfull drop ;

0 quan (disasm-one)  ( adr -- adr' )  (public)

{no-inline}
: (SEE)  ( cfa )
  endcr dup system:normal-code? not?exit< drop ." not a proper compiled word\n" >?
  (disasm-one) not?exit< drop ." load <x86dis> to use \'SEE\'\n" >?
  \ ." === ADDR: $" dup .hex8 ."  (PFA:$" dup cfa>pfa .hex8 ." ) ===\n"
  ." === ADDR: $" dup .hex8 ."  ===\n"
  ip>word-start/end not?exit< ." something strange\n" >? drop
  ." === DECOMPILE: " dup dfa>nfa .idfull ."  (" dup dfa>wfa wfa>wlen @ ., ." bytes) ===\n"
  dfa>cfa dup cfa>wlen @ over + swap
  ( end start )
  << 2dup u> ?^| (disasm-one) execute
      \ endcr ." curr=$" dup .hex8 ."  end=$" over .hex8 cr
      \ 2drop exit
   |? else| 2drop >> ;

: SEE-MEM  ( start end )
  (disasm-one) not?exit< drop ." load <x86dis> to use \'SEE-MEM\'\n" >?
  swap ( end start )
  << 2dup u> ?^| (disasm-one) execute |? else| 2drop >> ;


(*
: HEX-DUMP  ( saddr eaddr -- )
  swap begin 2dup u> while  ( eaddr saddr )
    dup .hex8 [char] : emit
    8 for 2dup u> ?< dup c@ bl emit .hex2 >? 1+ endfor
    2dup u> ?< bl emit >?
    8 for 2dup u> ?< dup c@ bl emit .hex2 >? 1+ endfor
  cr repeat 2drop ;
*)

0 quan DUMP-ADDR

|: (DL8)
  8 dump-addr << c@++ bl emit .hex2 1 under- over ?^|| else| dump-addr:! drop >> ;

|: (DL-XEMIT)  ( ch )
  dup 33 127 within not?< drop [char] . >? emit ;

|: (DL8-CH)
  8 dump-addr << c@++ (dl-xemit) 1 under- over ?^|| else| dump-addr:! drop >> ;

{no-inline}
: DL
  endcr dump-addr @ .hex8 [char] : emit
  dump-addr @ (dl8) bl emit (dl8) 2 bl #emit dump-addr !
  (dl8-ch) bl emit (dl8-ch) ;

{no-inline}
: DD  16 << dl 1- dup ?^|| else| drop >> ;
{no-inline}
: DUMP  ( saddr )  dump-addr ! dd ;

(*
: (DEFAULT-ABORT)  ( addr count )
  setup-raw-output endcr ." ***UrForth FATAL: " type cr
  backtrace 1 nbye ;
last-word-cfa-set tgt-(abort)-cfa
*)


{no-inline}
: .HERES
  ." HERE: $" here .hex8 ."  HDR-HERE: $" hdr-here .hex8 cr ;

: .plural  ( n )  1 <> ?exit< [char] s emit >? ;

;; for stats
0 quan tht-min
0 quan tht-max
0 quan tht-tbu
0 quan tht-tot

true quan hstats-full-names

: count-mhash-bucket  ( bva -- count )
  @ 0 swap << dup ?^| 1 under+ @ |? else| drop >> ;

: .bucket  ( bva )
  ." === BUCKET $" dup .hex8 ." (" dup count-mhash-bucket 0.r ." ) ===\n"
  @ << dup ?^|
       ."  HASH: $" dup bfa>hfa @ .hex8
       ."  NAME: " dup bfa>nfa hstats-full-names ?< .idfull || .id >? cr
       @ |? else| drop >> ;

: .hash-buckets
  hstats-full-names:!0
  system:#htable (ghtable) <<
    over ?^| 1 under- dup .bucket 4+ |?
    else| 2drop >> ;

: .bucket-with#  ( cnt )
  >r system:#htable (ghtable) <<
    over ?^| 1 under- dup count-mhash-bucket
             r@ = ?< dup .bucket >?
             4+ |?
    else| rdrop 2drop >> ;

: (calc-hash-stats)
  tht-max:!0 tht-tbu:!0 tht-tot:!0 max-int tht-min:!
  system:#htable (ghtable) <<
    over ?^| 1 under- dup count-mhash-bucket
             dup tht-max max tht-max:!
             dup ?< tht-tbu:1+! >?
             dup ?< dup tht-min min tht-min:! >?
             tht-tot:+! 4+ |?
    else| 2drop >> ;

{no-inline}
: .hashstats-more
  (calc-hash-stats)
  tht-max << dup +?^| dup .bucket-with# 1- |? else| drop >> ;

{no-inline}
: .hashstats
  (calc-hash-stats)
  system:#htable . ." hash table buckets (" tht-tbu . ." used); min="
  tht-min . ." max=" tht-max . ." uav=" tht-tot tht-tbu / 0.r cr
   \ .hashstats-more
  (* system:#htable . ." hash table buckets (" tht-tbu . ." used)" cr
  ." smallest bucket: " tht-min . ." item" tht-min .plural cr
  ."  biggest bucket: " tht-max . ." item" tht-max .plural cr
  ." useless average: " tht-tot tht-tbu / 0.r cr *) ;

end-module DEBUG


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; show words in the given vocabulary

[[ tgt-build-base-binary ]] [IFNOT]
80 quan WORDS-WIDTH
[ENDIF]

;; exec-cfa: ( cfa -- res )  -- exit, if res is not 0
: VOCID-FOREACH  ( vocid exec-cfa -- res )
  >r system:vocid-latest  ( vocid | exec-cfa )
  << dup ?^| dup >r dart:lfa>cfa r1:@ execute dup ?exit< 2rdrop >? drop r> @ |?
  else| rdrop drop false >> ;

[[ tgt-build-base-binary ]] [IFNOT]
|: (.WORD)  ( cols cfa -- res )
  dup system:private? over system:smudged? or ?exit< drop false >?
  dart:cfa>nfa idcount  ( cols addr count )
  dup not?exit< 2drop false >?
  rot over + 1+         ( addr count newcols )
  dup words-width > ?< drop dup 1+ cr >?
  nrot bl emit type  0 ;

{no-inline}
: VOCID-WORDS  ( vocid )
  endcr 0 swap ['] (.word) vocid-foreach 2drop endcr ;

{no-inline}
: WORDS  context@ vocid-words ;
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; show current vocabulary name

{no-inline}
: .VOCID-NAME  ( vocid )
  dup not?exit< drop ." <none>" >?
  system:vocid-rfa@ dup not?exit< drop ." <anonymous>" >? debug:.idfull ;

{no-inline}
: .CURRENT  current@ .vocid-name ;
{no-inline}
: .CONTEXT  context@ .vocid-name ;

;; show current vocabulary search order
{no-inline}
: .ORDER
  endcr ." CONTEXT: " .context cr
  (vsp) @ << dup (vp-start) @ u< ?v| drop |?
             dup @ dup not?v| 2drop |?
             ." > " .vocid-name cr 4- ^|| >> ;

[ENDIF]
