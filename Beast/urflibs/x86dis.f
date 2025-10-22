;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 80386 Disassembler (public domain, i guess)
;; Andrew McKewan, April 1994
;; Tom Zimmer,  05/18/94 port to Win32f
;; Modified to word in decimal 08/03/94 10:04 tjz
;; 06-??-1995 SMuB NEXT sequence defined in FKERNEL
;; 06-21-1995 SMuB removed redundant COUNT calls from txb, lxs.
;; 04-??-1997 Extended by C.L. to include P6 and MMX instructions
;; 26-07-2001 Fixed MVX (Maksimov)
;; 11-05-2004 Fixed FDA and CMV (Serguei Jidkov)
;; 01-19-2015 Jos, Extended for XMM instructions (adaptation by Ketmar Dark)
;; 08-25-2020 Fixed bug in ENTER (Ketmar Dark)
;; 02-03-2024 Added POPCNT/LZCNT/TZCNT (Ketmar Dark)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; hide it all
module x86dis
<published-words>
<disable-hash>

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
false quan default-16bit?

: default-16bit  default-16bit?:!t ;
: default-32bit  default-16bit?:!f ;


;; this will be added to most addresses before printing
0 quan addr-offset

decimal

;; disasm reads memory via this
vect dis-c@  ( addr -- byte[addr] )
['] c@ dis-c@:!

;; find symbol name
vect find-name ( addr -- addr count )
:noname drop pad 0 ; find-name:!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
<private-words>

: dis-w@  ( addr -- w )  dup dis-c@ swap 1+ dis-c@ 256 * + ;
: dis-@  ( addr -- n )  dup dis-w@ swap 2+ dis-w@ 65536 * + ;

: cincr  ( n -- [n] = [n]+1 )  1 swap +c! ;
: c+place  ( ch c-addr )  dup cincr c@++ + 1- c! ;

;; put a u at dest as byte-counted string
: place  ( a u dest )
  >r lo-byte dup r@ c!  \ set length
  r> 1+ swap move ;

;; append string a u to counted string
;; let's hope it will not overflow ;-)
: +place  ( a u dest )
  2dup 2>r  \   at dest
  c@++ + swap lo-byte move
  2r> +c! ;

;; buffer for disassembled string (byte-counted)
;; any overflow will write to the extra bytes
create s-buf 520 allot create;

: 0>s  s-buf c!0 ;
: >s  ( a1 n1 )  s-buf +place ;
: s>  ( -- a1 n1 )  s-buf c@++ ;

: s-lastch-addr  ( -- addr )  s-buf c@++ + 1- ;
: s-lastch@  ( -- ch )  s-lastch-addr c@ ;
: s-chop  s-buf c@++ 1- 0 max swap 1- c! ;
: emit>s  ( c1 )  s-buf c+place ;
: sspaces ( n1 )  << dup +?^| bl emit>s 1- |? else| drop >> ;
: sspace  bl emit>s ;

;; strip trailing spaces from s-buf (buf must not be empty)
: s-strip-tail
  s-lastch-addr 1+ << dup s-buf u> not?v||
  1- dup c@ bl <= ?^|| else| >> s-buf - s-buf c! ;

: s-end-mnemo
  s-strip-tail 8 s-buf c@ - 1 max ( want at least one space ) sspaces ;

: >s-mnemo  ( a1 n1 )
  >s s-end-mnemo ;

*: .s"  ( 'text' -- )  [\\] " \\ >s ;  ;;"
*: .s-mnemo"  ( 'text' -- )  [\\] " \\ >s-mnemo ;  ;;"

: .r>s  ( n w )  >r <# #signed #> r> over - sspaces >s ;
: u.r>s ( u w )  >r <# #s #> r> over - sspaces >s ;

: h0.r>s  ( n )
  base @ swap hex
  dup 0 16 within ?< [char] 0 emit>s >?
  <# #s #> >s
  base ! ;

: h.>s  ( u )
  \ base @ swap hex <# #s #> >s base ! ;
  h0.r>s ;

: 0h.r>s  ( n1 n2 )
  base @ >r hex >r
  <# #s #>
  r> over -
  << dup ?^| 48 emit>s 1- |? else| drop >>
  >s r> base ! ;

: show-name  ( addr )
  dup >r find-name
  dup -0?exit< 2drop r> addr-offset + .s" $" 8 0h.r>s >?
  .s" <: " rdrop >s .s"  :>" ;

\ : ?.name>s  ( cfa )  .s" $" 8 0h.r>s ;
\ ' ?.name>s show-name:!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main disassembler code

0 quan size
0 quan 16-bit-data
0 quan 16-bit-addr
0 quan prefix-op
0 quan prefix-op-a16-d16  \ 0, 1, 2
0 quan prefix-seg
0 quan mmx-reg
0 quan xmm-reg  \ for a 32-bit environment
0 quan data-size-prefix    \ 0:don't need it; 1:"byte"; 2:"word"; 4:"dword"
0 quan disp-as-reg-offset


*: /mod-swap  \\ /mod \\ swap ;

: .,  .s" , " ;
: .#  .s" $" ;

: .,# ., .# ;
: .[  [char] [ emit>s ;
: .]  [char] ] emit>s ;

: .datasize
  data-size-prefix <<
    1 of?v| .s" byte " |?
    2 of?v| .s" word " |?
    4 of?v| .s" dword " |?
  else| drop 16-bit-data prefix-op-a16-d16 2 = land
        ?< prefix-op-a16-d16:!0 .s" word " >?
  >> data-size-prefix:!0 ;

: .segpfx
  prefix-seg dup 1 6 bounds ?<
    4* " cs: ds: ss: es: gs: gs: " drop + 4 >s
  || drop >? prefix-seg:!f ;

: set-data-size-with-bit ( bit )
  ?< 16-bit-data ?< 2 || 4 >? || 1 >? data-size-prefix:! ;

: cfetch ( addr -- addr+1 byte[addr] )  dup dis-c@ swap 1+ swap ;
: wfetch ( addr -- addr+2 n )  dup 2+ swap dis-w@ ;
: fetch  ( addr -- addr+4 n )  dup 4+ swap dis-@ ;

: sext  ( byte -- n )  c>s ; \ dup $80 and ?< $FFFFFF00 or >? ;

: mod/sib
  ( mod-r-r/m -- r/m r mod ) \ r including general, special, segment, MMX
  ( mod-op-r/m -- r/m op mod )
  ( s-i-b -- b i s )
  255 and 8 /mod-swap 8 /mod-swap ;

: ???   ( n1 )  .s" ???" drop ;
: ???-mnemo  ( n1 )  ??? s-end-mnemo ;

: ss. ( n adr len w )  >r drop  swap r@ * +  r> >s ; \ sspace ;
: ss-mnemo.  ss. s-end-mnemo ;

: tttn ( code ) 15 and " o nob aee nebea s nsp npl geleg " 2 ss. s-strip-tail ;

: sreg  ( sreg )  3 rshift 7 and " escsssdsfsgsXXXX" 2 ss. ;
: creg  ( eee )   3 rshift 7 and " cr0???cr2cr3cr4?????????" 3 ss. ;
: dreg  ( eee )   3 rshift 7 and " dr0dr1dr2dr3??????dr6dr7" 3 ss. ;
: treg  ( eee )   3 rshift 7 and " ?????????tr3tr4tr5tr6tr7" 3 ss. ; \ obsolete
: mreg  ( n )     7 and " mm0mm1mm2mm3mm4mm5mm6mm7" 3 ss. ;

: reg8  ( n )  7 and " alcldlblahchdhbh" 2 ss. ;
: reg16 ( n )  7 and " axcxdxbxspbpsidi" 2 ss. ;
: reg32 ( n )  7 and " eaxecxedxebxespebpesiedi" 3 ss. ;

: .xmmreg  ( n )  7 and " xmm0xmm1xmm2xmm3xmm4xmm5xmm6xmm7" 4 ss. ; \ 1

: reg16/32  ( n )
  16-bit-data ?exit< reg16 >? reg32 ;

: reg  ( a n -- a )
  xmm-reg ?exit< .xmmreg >?
  mmx-reg ?exit< mreg >?
  size ?exit< reg16/32 >?
  reg8 ;

: [base16]  ( r/m )
  .datasize .segpfx
  4- " [si][di][bp][bx]" 4 ss.
  ( r/m = 4 , 5 , 6 , 7 ) ;

: [ind16]  ( r/m )
  .datasize .segpfx
  " [bx+si][bx+di][bp+si][bp+di]" 7 ss.
  ( r/m = 0 , 1 , 2 , 3 ) ;

: [reg16] ( r/m )
  dup 4 < ?exit< [ind16] >? [base16] ;

: [reg32-nds]  ( n )
  [char] [ emit>s reg32 [char] ] emit>s ;

: [reg32]  ( n )
  .datasize .segpfx [reg32-nds] ;

: [reg*n] ( i n )
  over 7 and 4 = ?< nip .datasize .segpfx .s" [XXX]" || swap [reg32-nds] >?
  s-chop [char] * emit>s [char] 0 + emit>s .] ;

: [reg*2]  ( i )  2 [reg*n] ;
: [reg*4]  ( i )  4 [reg*n] ;
: [reg*8]  ( i )  8 [reg*n] ;

: [index-has-scaled]  ( sib -- add-disp-flag )
  ;; no esp scaled index
  mod/sib over 4 = ?exit< 3drop false >?
  s-lastch@ [char] ] = ?< s-lastch-addr s-chop || 0 >? >r
  << ( s )
    0 of?v| [reg32] |?
    1 of?v| [reg*2] |?
    2 of?v| [reg*4] |?
    3 of?v| [reg*8] |?
  else| error" internal error in `[index-has-scaled]`" >>
  r> dup ?< [char] + swap c! || drop >? drop true ;

: [index]  ( sib )
  [index-has-scaled] drop ;

: .+sign  ( val -- val )
  dup $8000_0000 u>= ?< abs [char] - || [char] + >? emit>s ;

: .dispnum  ( val )
  .+sign dup 10 < ?exit< 0 .r>s >? .# h0.r>s ;

: (.dispvalue)  ( val )
  dup data-size-prefix or ?exit< .dispnum >? drop ;

: .disp-value  ( val )
  \ disp-as-reg-offset ?< dup 0>= ?< .s" +" >? 0 .r>s || show-name >?
  data-size-prefix ?< .datasize .segpfx .[ >?
  disp-as-reg-offset ?< (.dispvalue) || show-name >?
  data-size-prefix ?exit< .] >? ;

: disp8-value  ( adr -- adr' value )
  cfetch c>s ;

: disp8  ( adr -- adr' )
  disp8-value .disp-value ;

: disp16-value  ( adr -- adr' value )
  wfetch  ( w>s )
  dup $8000 u>= ?< $10000 - >? ;

: disp16 ( adr -- adr' )
  disp16-value .disp-value ;

: disp32-value ( adr -- adr' value )
  fetch ( body> ) ;

: disp32 ( adr -- adr' )
  disp32-value .disp-value ;

: disp16/32  ( adr -- adr' )
  data-size-prefix ?< .datasize >?
  data-size-prefix:!0 .segpfx .[ 16-bit-addr ?< disp16 || disp32 >? .] ;

: iimm8-nocomma  ( adr -- adr' )
  cfetch
  dup $80 >= ?< 256 - abs [char] - emit>s >?
  dup 10 < ?exit< 0 .r>s >? .# h0.r>s ;

: iimm8  ( adr -- adr' )  ., iimm8-nocomma ;

: imm8-nocomma  ( adr -- adr' )
  .# cfetch h.>s ;

: imm8  ( adr -- adr' )  ., imm8-nocomma ;

: imm16/32-nocomma  ( adr -- adr' )
  16-bit-data ?< wfetch || fetch >?
  dup 10 < ?exit< 0 .r>s >? .# h.>s ;

: imm16/32  ( adr -- adr' )  ., imm16/32-nocomma ;

: (sib-disp) ( scl )
  s-chop
  (.dispvalue) \ r@ 0>= ?< [char] + emit>s >? r> 0 .r>s
  .] ;

: sib  ( adr mod -- adr )
  >r cfetch tuck 7 and 5 = r@ 0= and ?exit<
    \ disp32 swap [index] rdrop  \ ebp base and mod = 00
    disp32-value >r
    swap [index-has-scaled] ?< r@ (sib-disp) >?
    2rdrop >?
  r> << ( mod )
    1 of?v| disp8-value true |?
    2 of?v| disp32-value true |?
  else| drop false false >>
  swap >r >r
  swap dup [reg32] [index]
  r> ?< r@ (sib-disp) >? rdrop ;

: mod-reg-predisp
  s-lastch@ [char] ] = ?<
    data-size-prefix:!0
    disp-as-reg-offset:!t
    s-chop >? ;

: mod-reg-postdisp
  disp-as-reg-offset ?exit< s-strip-tail .] >? ;

: mod-r/m32  ( adr r/m mod -- adr' )
  \ mod = 3, register case
  dup 3 = ?exit< drop reg >?
  \ r/m = 4, sib case
  over 4 = ?exit< nip sib >?
  \ mod = 0, r/m = 5,
  2dup 0= swap 5 = and ?exit<
    .datasize .segpfx .[
    2drop disp32
    s-strip-tail .] >?
  rot swap >r swap [reg32] r>
  << ( mod )
    1 of?v| mod-reg-predisp disp8  mod-reg-postdisp |?
    2 of?v| mod-reg-predisp disp32 mod-reg-postdisp |?
  else| drop >> ;

: mod-r/m16  ( adr r/m mod -- adr' )
  2dup 0= swap 6 = and ?exit< 2drop disp16 >?
  << ( mod )
    0 of?v| [reg16] |?
    1 of?v| swap disp8  swap [reg16] |?
    2 of?v| swap disp16 swap [reg16] |?
    3 of?v| reg |?
  else| drop >> ;

: mod-r/m  ( adr modr/m -- adr' )
  mod/sib nip 16-bit-addr ?exit< mod-r/m16 >? mod-r/m32 ;

: r/m8      size:!0 mod-r/m ;
: r/m16/32  size:!1 mod-r/m ;
: r/m16     16-bit-data:!t r/m16/32 ;

: r,r/m  ( adr -- adr' )  cfetch dup 3 rshift reg ., mod-r/m ;
: r/m,r  ( adr -- adr' )  cfetch dup >r mod-r/m ., r> 3 rshift reg ;

: r/m  ( adr op -- adr' )  2 and ?exit< r,r/m >? r/m,r ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple opcodes
;;

;; put a u at dest as dword-counted string
: $-place  ( a u dest )
  2dup 2>r  4+ swap move  \ move first to handle overlap
  2r> ! ;                 \ then store count character

;; parse, copy parsed string to here as dword-counted string
: parse-name-to-here-cstr  ( -- here )
  parse-name here $-place here ;

: inh   ( -<name>- )
  <builds parse-name-to-here-cstr count 4+ allot drop
  does>
    count >s
    drop \ instruction code
    ( s-end-mnemo ) ;

inh clc  clc
inh stc  stc
inh cld  cld
inh std  std
\ inh rpnz repnz
\ inh repz repz
inh cbw  cbw
inh cdq  cdq
inh daa  daa
inh das  das
inh aaa  aaa
inh aas  aas
\ inh lock lock
inh inb  insb
inh osb  outsb
inh sah  sahf
inh lah  lahf
\ inh aam  aam
\ inh aad  aad
inh hlt  hlt
inh cmc  cmc
inh xlt  xlat
inh cli  cli
inh sti  sti

inh clt clts
inh inv invd
inh wiv wbinvd
inh ud2 ud2
inh wmr wrmsr
inh rtc rdtsc
inh rmr rdmsr
inh rpc rdpmc
inh ems emms
inh rsm rsm
inh cpu cpuid
inh ud1 ud1
\ inh lss lss
\ inh lfs lfs
\ inh lgs lgs

\ inh d16: d16:
\ inh a16: a16:
\ inh es:  es:
\ inh cs:  cs:
\ inh ds:  ds:
\ inh fs:  fs:
\ inh gs:  gs:

: aam  ( adr code -- adr' )  .s" aam" drop cfetch drop ;
: aad  ( adr code -- adr' )  .s" aad" drop cfetch drop ;

: d16  ( adr code -- adr' )
  drop \ .s" d16:"
  16-bit-data:!t
  prefix-op:!t
  2 prefix-op-a16-d16:! ;

: a16  ( adr code -- adr' )
  drop \ .s" a16:"
  16-bit-addr:!t
  prefix-op:!t
  1 prefix-op-a16-d16:! ;

: rpz  ( adr code -- adr' )  drop .s" repnz" prefix-op:!t ;

: rep-extra ( adr -- adr' )
  1+  ;; skip $0F
  cfetch <<
    $B8 of?v| .s-mnemo" popcnt" |?
    $BD of?v| .s-mnemo" lzcnt" |?
    $BC of?v| .s-mnemo" tzcnt" |?
  else| drop ??? exit >> 2 r/m ;

: rep  ( adr code -- adr' )
  drop dup dis-c@ $0F = ?exit< rep-extra >?
  .s" repz" prefix-op:!t ;

\ FIXME: this should have error checking added
: lok  ( adr code -- adr' )  drop .s" lock" prefix-op:!t ;

: make-seg-pfx  ( pfx-seg )  \ name
  <builds ,
  does> ( adr code pfa -- adr' )
    @ prefix-seg:! prefix-op:!t drop ;

1 make-seg-pfx cs:
2 make-seg-pfx ds:
3 make-seg-pfx ss:
4 make-seg-pfx es:
5 make-seg-pfx gs:
6 make-seg-pfx fs:

: isd  ( adr code -- adr' )
  drop 16-bit-data ?< .s-mnemo" insw" || .s-mnemo" insd" >? ;

: osd  ( adr code -- adr' )
  drop 16-bit-data ?< .s-mnemo" outsw" || .s-mnemo" outsd" >? ;

: .e-for-32-data
  16-bit-data not?exit< [char] e emit>s >? ;

: .(e)ax
  .e-for-32-data .s" ax" ;

: .(e)ax/al  ( bit-0-flag )
  1 and ?< .(e)ax || .s" al " >? ;

: inp  ( addr code -- addr' )
  .s-mnemo" in" .(e)ax/al .s" , " .# cfetch h.>s ;

: otp  ( addr code -- addr' )
  .s-mnemo" out" >r .# cfetch h.>s .s" , " r> .(e)ax/al ;

: ind
  ( addr code -- addr' )
  .s-mnemo" in" 1 and not?exit< .s" al, dx"  >?
  16-bit-data ?< .s" ax, dx" || .s" eax, dx" >? ;

: otd  ( addr code -- addr' )
  .s-mnemo" out" .s" dx, " .(e)ax/al ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ALU opcodes
;;

: .alu  ( n )  7 and " addor adcsbbandsubxorcmp" 3 ss. s-end-mnemo ;

: alu  ( adr op -- adr' )
  \ k8: data size; comment it to avoid prefixes on [reg],reg
  dup 1 and set-data-size-with-bit
  dup 3 rshift .alu r/m ;

: ali  ( adr op -- adr' )
  >r cfetch
  dup 3 rshift .alu

  \ k8: data size
  r@ 1 and set-data-size-with-bit

  mod-r/m
  r> 3 and dup ?<
    1 = ?< imm16/32
    || (* .,# cfetch sext
       base @ >r hex
       0 .r>s  \ sspace
       r> base ! *)
       iimm8 >?
  || drop imm8 >? ;

: ala  ( adr op -- adr' )
  dup 3 rshift .alu
  1 and ?exit< 0 reg imm16/32 >? 0 reg8 imm8 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test/xchg
;;

: txb  ( addr op -- addr' )
  dup 3 and " testtestxchgxchg" 4 ss-mnemo.
  1 and size:! r,r/m ;

: tst  ( addr op -- addr' )
  .s-mnemo" test" 1 and ?exit< .(e)ax imm16/32 >? .s" al" imm8 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; inc/dec
;;

: inc  ( addr op -- addr' )  .s-mnemo" inc" reg16/32 ;
: dec  ( addr op -- addr' )  .s-mnemo" dec" reg16/32 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; push/pop
;;

: psh  ( addr op -- addr' )  .s-mnemo" push" reg16/32 ;
: pop  ( addr op -- addr' )  .s-mnemo" pop" reg16/32 ;
: pss  ( addr op -- addr' )  .s-mnemo" push" sreg ;
: pps  ( addr op -- addr' )  .s-mnemo" pop" sreg ;

: .d-for-32-data
  16-bit-data not?exit< [char] d emit>s >? ;

: psa  ( addr op -- addr' )
  drop .s" pusha" .d-for-32-data s-end-mnemo ;

: ppa  ( addr op -- addr' )
  drop .s" popa" .d-for-32-data s-end-mnemo ;

: psi  ( addr op -- addr' )
  .s-mnemo" push" 2 and ?exit< imm8-nocomma >? imm16/32-nocomma ;

: psf  ( addr op -- addr' )
  drop .s" pushf" .d-for-32-data s-end-mnemo ;

: ppf  ( addr op -- addr' )
  drop .s" popf" .d-for-32-data s-end-mnemo ;

: 8F.  ( addr op -- addr' )
  drop cfetch .s-mnemo" pop" r/m16/32 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; move
;;

: mov-mnemo  .s-mnemo" mov" ;

: mov  ( addr op -- addr' )  mov-mnemo r/m ;

: mri  ( addr op -- addr' ) ( mov register, imm )
  mov-mnemo dup 8 and ?exit< reg16/32 imm16/32 >? reg8 imm8 ;

: mvi ( adr op -- adr' )   ( mov mem, imm )
  mov-mnemo
  \ drop
  1 and set-data-size-with-bit
  cfetch mod-r/m size ?exit< imm16/32 >? imm8 ;

// ??? was: "( 16-bit-data ) true ?< ... || ??? >?"
: mrs  ( addr op -- addr' )
  mov-mnemo drop size:!t cfetch dup mod-r/m ., sreg ;

// ??? was: "( 16-bit-data ) true ?< ... || ??? >?"
: msr  ( addr op -- addr' )
  mov-mnemo drop size:!t cfetch dup sreg ., mod-r/m ;

: mrc  ( addr op -- addr' )  mov-mnemo drop cfetch dup reg32 ., creg ;
: mcr  ( addr op -- addr' )  mov-mnemo drop cfetch dup creg ., reg32 ;
: mrd  ( addr op -- addr' )  mov-mnemo drop cfetch dup reg32 ., dreg ;
: mdr  ( addr op -- addr' )  mov-mnemo drop cfetch dup dreg ., reg32 ;
: mrt  ( addr op -- addr' )  mov-mnemo drop cfetch dup reg32 ., treg ;  \ obsolete
: mtr  ( addr op -- addr' )  mov-mnemo drop cfetch dup treg ., reg32 ;  \ obsolete

: mv1  ( addr op -- addr' )
  mov-mnemo .(e)ax/al .s" , " disp16/32 ;

: mv2  ( addr op -- addr' )
  mov-mnemo
  \ @@@ Bh fixed bug here
  swap disp16/32 ., swap .(e)ax/al ;

: lea  ( addr op -- addr' )
  .s-mnemo" lea" drop size:!t r,r/m ;

: lxs  ( addr op -- addr' )
  1 and ?< .s-mnemo" lds" || .s-mnemo" les" >? r,r/m ( SMuB removed COUNT ) ;

: bnd  ( addr op -- addr' )
  .s-mnemo" bound" drop size:!t r,r/m ;

: arp  ( addr op -- addr' )
  .s-mnemo" arpl" drop size:!t 16-bit-data:!t r,r/m ;

: mli  ( addr op -- addr' )
  size:!t .s-mnemo" imul" $69 = ?exit< r,r/m imm16/32 >? r,r/m imm8 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; jumps and calls
;;

: rel8  ( addr op -- addr' )
  cfetch sext over + show-name  ;

: rel16/32  ( addr op -- addr' )
  16-bit-addr ?< wfetch || fetch >? over + show-name ;

: jsr  ( addr op -- addr' )
  .s-mnemo" call" drop rel16/32 ;

: jmp-jp-mnemo  .s-mnemo" jmp" ;

: jmp  ( addr op -- addr' )
  jmp-jp-mnemo 2 and ?exit< rel8 >? rel16/32 ;

: .jxx  ( addr op -- addr' ) .s" j" tttn s-end-mnemo ;

: bra  ( addr op -- addr' )  .jxx rel8 ;
: lup  ( addr op -- addr' )  3 and " loopnzloopz loop  jecxz " 6 ss-mnemo. rel8 ;
: lbr  ( addr op -- addr' )  .jxx rel16/32 ;

\ .s" ret near"
: rtn  ( addr op -- addr' )
  .s" ret" 1 and 0= ?exit< s-end-mnemo .# wfetch h.>s >? ;

: rtf  ( addr op -- addr' )
  .s" ret far" 1 and 0= ?exit< sspace .# wfetch h.>s >? ;

: ent  ( addr op -- addr' )
  drop .s-mnemo" enter" wfetch 0 .r>s ., cfetch 0 .r>s ;

: cis  ( addr op -- addr' )
  $9a = ?< .s-mnemo" call" || jmp-jp-mnemo >?
  16-bit-data ?< .s" ptr16:16 " || .s" ptr16:32 " >?
  cfetch mod-r/m ;

: nt3  ( addr op -- addr' )  drop .s" int3" ;

: int  ( addr op -- addr' )  drop .s-mnemo" int" cfetch .# h.>s ;

inh lev leave
inh irt  iret
inh nto  into


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; string ops
;;

: str
  inh
 does>
  count >s 1 and ?< [char] d || [char] b >? emit>s ;

str mvs movs
str cps cmps
str sts stos
str lds lods
str scs scas


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; exchange
;;

;; k8: in case you don't know, "NOP" is "XCHG [E]AX, [E]AX"
: xga  ( addr op -- addr' )
  dup $90 = ?< drop .s" nop"
  || .s-mnemo" xchg" .s" eax, " reg16/32 >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; shifts & rotates
;;

: .shift ( n )  7 and " rolrorrclrcrshlshrxxxsar" 3 ss-mnemo. ;

: shf  ( addr op -- addr' )
  >r cfetch
  dup 3 rshift .shift
  mod-r/m
  r> $D2 and <<
    $C0 of?v| ( imm8) ., cfetch 0 .r>s |?
    $D0 of?v| ( 1 .# h.>s) |?
    $D2 of?v| ., 1 reg8 |?
  else| drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; extended opcodes
;;

: wf1  ( addr -- addr' )
  1+ cfetch dup
  $0c0 < ?<
    dup 3 rshift 7 and <<
      6 of?v| .s-mnemo" fstenv" mod-r/m |?
      7 of?v| .s-mnemo" fstcw" .s" word " mod-r/m |?
    else| 2drop 2- .s" fwait" >>
  || drop 2- .s" fwait" >? ;

: wf2  ( addr -- addr' )
  1+ cfetch <<
    $E2 of?v| .s" fclex" |?
    $E3 of?v| .s" finit" |?
  else| drop 2- .s" fwait" >> ;

: wf3  ( addr -- addr' )
  1+ cfetch dup 3 rshift 7 and <<
    6 of?v| .s-mnemo" fsave" mod-r/m |?
    7 of?v| .s-mnemo" fstsw" .s" word " mod-r/m |?
  else| 2drop 2- .s" fwait" >> ;

: wf4  ( addr -- addr' )
  1+ cfetch $e0 = ?< .s-mnemo" fstsw" .s" ax" || 2- .s" fwait" >? ;

: fwaitops  ( addr op -- addr' )
  << $D9 of?v| wf1 |?
     $DB of?v| wf2 |?
     $DD of?v| wf3 |?
     $DF of?v| wf4 |?
  else| drop .s" fwait" >> ;

: w8f  ( addr op -- addr' )
  drop dup dis-c@ dup $f8 and $d8 = ?< fwaitops || drop .s" wait" >? ;

: falu1  ( xopcode )
  3 rshift 7 and " fadd fmul fcom fcompfsub fsubrfdiv fdivr" 5 ss-mnemo. ;

: falu5  ( xopcode )
  3 rshift 7 and " fadd fmul ???? ???? fsubrfsub fdivrfdiv " 5 ss-mnemo. ;

: sti.  ( op )  7 and .s" st(" 1 .r>s .s" )" ;

: fd8  ( addr opcode -- addr' )
  drop cfetch dup falu1
  dup $c0 < ?exit< .s" float " mod-r/m >?
  dup $f0 and $d0 = ?exit< sti. >? .s" st, " sti. ;

: fdc  ( addr opcode -- addr' )
  drop cfetch dup dup $c0 < ?exit< falu1 .s" double " mod-r/m >?
  falu5 sti. .s" ,st" ;

: fnullary-f   ( op )
  $0f and dup 8 < ?<
    " f2xm1  fyl2x  fptan  fpatan fxtractfprem1 fdecstpfincstp"
  || 8 -
    " fprem  fyl2xp1fsqrt  fsincosfrndintfscale fsin   fcos   "
  >? 7 ss-mnemo. ;

: fnullary-e  ( op )
  $0f and dup 8 < ?<
    " fchs   fabs   ???    ???    ftst   fxam   ???    ???    "
  || 8 -
    " fld1   fldl2t fldl2e fldpi  fldlg2 fldln2 fldz   ???    "
  >? 7 ss-mnemo. ;

: fnullary  ( op )
  dup $ef > ?exit< fnullary-f >?
  dup $e0 < ?exit< $d0 = ?< .s" fnop" || dup ??? >? >?
  fnullary-e ;

: fd9  ( addr op -- addr' )
  drop cfetch dup $c0 < ?<
    dup $38 and <<
      $00 of?v| .s-mnemo" fld" .s" float " |?
      $10 of?v| .s-mnemo" fst" .s" float " |?
      $18 of?v| .s-mnemo" fstp" .s" float " |?
      $20 of?v| .s-mnemo" fldenv" |?
      $28 of?v| .s-mnemo" fldcw" .s" word " |?
      $30 of?v| .s-mnemo" fnstenv" |?
      $38 of?v| .s-mnemo" fnstcw" .s" word " |?
    else| ???-mnemo >>
    mod-r/m
  ||
    dup $d0 < ?< dup $c8 < ?< .s-mnemo" fld" || .s-mnemo" fxch" >? sti.
    || fnullary >? >? ;

: falu3  ( op )
  3 rshift 7 and " fiadd fimul ficom ficompfisub fisubrfidiv fidivr"
  6 ss-mnemo. ;

: fcmova  ( op )
  3 rshift 7 and " fcmovb fcmove fcmovbefcmovu ???    ???    ???    ???    "
  7 ss-mnemo. ;

: fda  ( addr op )
  drop cfetch dup $c0 < ?exit< dup falu3 .s" dword " mod-r/m >?
  ;; 11-05-2004 Fixed FDA and CMV (Serguei Jidkov)
  dup $e9 = ?exit< .s" fucompp" drop >? dup fcmova sti. ;

: falu7  ( op )
  3 rshift 7 and " faddp fmulp ???   ???   fsubrpfsubp fdivrpfdivp "
  6 ss-mnemo. ;

: fde  ( addr op -- addr' )
  drop cfetch dup $c0 < ?exit< dup falu3 .s" word " mod-r/m >?
  dup $d9 = ?exit< .s" fcompp" drop >? dup falu7 sti. ;

: fcmovb  ( op )
  3 rshift 7 and " fcmovnb fcmovne fcmovnbefcmovnu ???     fucomi  fcomi   ???     "
  8 ss-mnemo. ;

: fdb  ( addr op -- addr' )
  drop cfetch dup $c0 < ?<
    dup $38 and <<
      $00 of?v| .s-mnemo" fild" .s" dword " |?
      $10 of?v| .s-mnemo" fist" .s" dword " |?
      $18 of?v| .s-mnemo" fistp" .s" dword " |?
      $28 of?v| .s-mnemo" fld" .s" extended " |?
      $38 of?v| .s-mnemo" fstp" .s" extended " |?
    else| ???-mnemo >>
    mod-r/m
  || << $E2 of?v| .s" fnclex" |?
        $E3 of?v| .s" fninit" |?
     else| ( dup dup) dup fcmovb sti. >>  \ FIXME: is this right?
  >? ;

: falu6  ( op )
  3 rshift 7 and
  " ffree ???   fst   fstp  fucom fucomp???   ???   "
  6 ss-mnemo.
;

: fdd  ( addr op -- addr' )
  drop cfetch dup $c0 < ?<
    dup $38 and <<
      $00 of?v| .s-mnemo" fld" .s" double " |?
      $10 of?v| .s-mnemo" fst" .s" double " |?
      $18 of?v| .s-mnemo" fstp" .s" double " |?
      $20 of?v| .s-mnemo" frstor" |?
      $30 of?v| .s-mnemo" fnsave" |?
      $38 of?v| .s-mnemo" fnstsw" .s" word " |?
    else| ???-mnemo >>
    mod-r/m
  || dup falu6 sti. >? ;

: fdf  ( addr op -- addr' )
  drop cfetch dup $c0 < ?<
    dup $38 and <<
      $00 of?v| .s-mnemo" fild" .s" word " |?
      $10 of?v| .s-mnemo" fist" .s" word " |?
      $18 of?v| .s-mnemo" fistp" .s" word " |?
      $20 of?v| .s-mnemo" fbld" .s" tbyte " |?
      $28 of?v| .s-mnemo" fild" .s" qword " |?
      $30 of?v| .s-mnemo" fbstp" .s" tbyte " |?
      $38 of?v| .s-mnemo" fistp" .s" qword " |?
    else| ??? s-end-mnemo >>
    mod-r/m
  || dup $e0 = ?< .s-mnemo" fnstsw" .s" ax " drop
     || dup $38 and <<
          $00 of?v| .s-mnemo" ffreep" sti. |?
          $28 of?v| .s-mnemo" fucomip" sti. |?
          $30 of?v| .s-mnemo" fcomip" sti. |?
        else| drop ??? >>
      >? >? ;

: gp6  ( addr op -- addr' )
  drop cfetch dup 3 rshift
  7 and " sldtstr lldtltr verrverw??? ???" 4 ss-mnemo.
  r/m16 ;

: gp7  ( addr op -- addr' )
  drop cfetch dup 3 rshift
  7 and dup " sgdt  sidt  lgdt  lidt  smsw  ???   lmsw  invlpg"
  6 ss-mnemo. 4 and 4 = ?exit< r/m16 >? r/m16/32 ;

: btx.  ( n )
  3 rshift 3 and " bt btsbtrbtc" 3 ss-mnemo. ;

: gp8  ( addr op -- addr' )
  drop cfetch dup btx. r/m16/32 imm8 ;

: lar  ( addr op -- addr' )  .s-mnemo" lar" drop r,r/m ;
: lsl  ( addr op -- addr' )  .s-mnemo" lsl" drop r,r/m ;
: lss  ( addr op -- addr' )  .s-mnemo" lss" drop r,r/m ;
: lfs  ( addr op -- addr' )  .s-mnemo" lfs" drop r,r/m ;
: lgs  ( addr op -- addr' )  .s-mnemo" lgs" drop r,r/m ;
: btx  ( addr op -- addr' )  btx. r/m,r ;
: sli  ( addr op -- addr' )  .s-mnemo" shld" drop r/m,r imm8 ;
: sri  ( addr op -- addr' )  .s-mnemo" shrd" drop r/m,r imm8 ;
: slc  ( addr op -- addr' )  .s-mnemo" shld" drop r/m,r .s" ,cl" ;
: src  ( addr op -- addr' )  .s-mnemo" shrd" drop r/m,r .s" ,cl" ;
: iml  ( addr op -- addr' )  .s-mnemo" imul" drop r,r/m ;
: cxc  ( addr op -- addr' )  .s-mnemo" cmpxchg" 1 and size:! r/m,r ;

: mvx  ( addr op -- addr' )
  dup 8 and ?< .s-mnemo" movsx" || .s-mnemo" movzx" >?
  1 and >r
  cfetch mod/sib r> ?<  \ size bit
    swap reg32 .,  \ word to dword case
    3 = ?exit< reg16 >?
    .s" word "
    drop dup 1- dis-c@  \ 26-07-2001 Fixed MVX (Maksimov)
    mod-r/m
  || swap reg16/32 .,  \ byte case
     3 = ?exit< reg8 >?
     .s" byte "
     drop dup 1- dis-c@  \ 26-07-2001 Fixed MVX (Maksimov)
     mod-r/m >? ;

: xad  ( addr op -- addr' )  .s-mnemo" xadd" 1 and size:! r/m,r ;
: bsf  ( addr op -- addr' )  .s-mnemo" bsf" drop r,r/m ;
: bsr  ( addr op -- addr' )  .s-mnemo" bsr" drop r,r/m ;
: cx8  ( addr op -- addr' )  .s-mnemo" cmpxchg8b" drop cfetch r/m16/32 ;
: bsp  ( addr op -- addr' )  .s-mnemo" bswap" reg32 ;

\ ??
: F6.  ( addr op -- addr' )
  >r cfetch
  dup 3 rshift 7 and dup >r " testXXXXnot neg mul imuldiv idiv" 4 ss-mnemo.
  mod-r/m r> 0= ?< r@ 1 and ?< imm16/32 || imm8 >? >? rdrop ;

: FE.  ( addr op -- addr' )
  drop cfetch
  dup 3 rshift 7 and <<
    0 of?v| .s-mnemo" inc" |?
    1 of?v| .s-mnemo" dec" |?
  else| drop ???-mnemo >>
  data-size-prefix:!1 r/m8 ;

: FF.  ( addr op -- addr' )
  drop cfetch
  dup 3 rshift 7 and <<
    0 of?v| .s-mnemo" inc" |?
    1 of?v| .s-mnemo" dec" |?
    2 of?v| .s-mnemo" call" |?
    3 of?v| .s" call far " |?
    4 of?v| jmp-jp-mnemo |?
    5 of?v| jmp-jp-mnemo s-strip-tail .s" far " |?
    6 of?v| .s-mnemo" push" |?
    else| drop ???-mnemo exit >>
  r/m16/32 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; conditional move
;;

: set  ( adr op )
  .s" set" tttn s-end-mnemo cfetch r/m8 ;

\ 11-05-2004 Fixed FDA and CMV (Serguei Jidkov)
: cmv  ( adr op )
  .s" cmov" tttn s-end-mnemo ( cfetch ) r,r/m ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MMX operations
;;

: mmx-size  ( op )  3 and " bwdq" 1 ss-mnemo. ;

: upl  ( adr op -- adr' )  3 and " punpcklbwpunpcklwdpunpckldq" 9 ss-mnemo. r,r/m ;
: uph  ( adr op -- adr' )  3 and " punpckhbwpunpckhwdpunpckhdq" 9 ss-mnemo. r,r/m ;
: cgt  ( adr op -- adr' )  .s" pcmpgt" mmx-size r,r/m ;
: ceq  ( adr op -- adr' )  .s" pcmpeq" mmx-size r,r/m ;

: psh. ( op )
  $30 and <<
    $10 of?v| .s" psrl" |?
    $20 of?v| .s" psra" |?
    $30 of?v| .s" psll" |?
  else| drop >> ;

: gpa  ( adr op -- adr' )  >r cfetch dup psh. r> mmx-size mreg imm8 ;
: puw  ( adr op -- adr' )  .s-mnemo" packusdw" drop r,r/m ;
: psb  ( adr op -- adr' )  .s-mnemo" packsswb" drop r,r/m ;
: psw  ( adr op -- adr' )  .s-mnemo" packssdw" drop r,r/m ;

: mpd  ( adr op -- adr' )
  .s-mnemo" movd" drop cfetch mod/sib swap mreg .,
  3 = ?exit< reg32 >? mod-r/m ;

: mdp  ( adr op -- adr' )
  .s-mnemo" movd" drop cfetch mod/sib
  3 = ?< swap reg32 || swap mod-r/m >? ., mreg ;

: mpq  ( adr op -- adr' )  .s-mnemo" movq" drop r,r/m ;
: mqp  ( adr op -- adr' )  .s-mnemo" movq" drop r/m,r ;
: shx  ( adr op -- adr' )  dup psh. mmx-size r,r/m ;
: mll  ( adr op -- adr' )  .s-mnemo" pmullw" drop r,r/m ;
: mlh  ( adr op -- adr' )  .s-mnemo" pmulhw" drop r,r/m ;
: mad  ( adr op -- adr' )  .s-mnemo" pmaddwd" drop r,r/m ;
: sus  ( adr op -- adr' )  .s" psubus" mmx-size r,r/m ;
: sbs  ( adr op -- adr' )  .s" psubs" mmx-size r,r/m ;
: sub  ( adr op -- adr' )  .s" psub" mmx-size r,r/m ;
: aus  ( adr op -- adr' )  .s" paddus" mmx-size r,r/m ;
: ads  ( adr op -- adr' )  .s" padds" mmx-size r,r/m ;
: add  ( adr op -- adr' )  .s" padd" mmx-size r,r/m ;
: pad  ( adr op -- adr' )  .s-mnemo" pand" drop r,r/m ;
: por  ( adr op -- adr' )  .s-mnemo" por" drop r,r/m ;
: pan  ( adr op -- adr' )  .s-mnemo" pandn" drop r,r/m ;
: pxr  ( adr op -- adr' )  .s-mnemo" pxor" drop r,r/m ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; opcode table
;;

\ : ops $10 for ' , endfor ;
: ops $10 << dup ?^| ' , 1- |? else| drop >> ;

create op-table2

\     0   1   2   3    4   5   6   7    8   9   A   B    C   D   E   F
ops  gp6 gp7 lar lsl  ??? ??? clt ???  inv wiv ??? ud2  ??? ??? ??? ???  \ 0
ops  ??? ??? ??? ???  ??? ??? ??? ???  ??? ??? ??? ???  ??? ??? ??? ???  \ 1
ops  mrc mrd mcr mdr  mrt ??? mtr ???  ??? ??? ??? ???  ??? ??? ??? ???  \ 2
ops  wmr rtc rmr rpc  ??? ??? ??? ???  ??? ??? ??? ???  ??? ??? ??? ???  \ 3

ops  cmv cmv cmv cmv  cmv cmv cmv cmv  cmv cmv cmv cmv  cmv cmv cmv cmv  \ 4
ops  ??? ??? ??? ???  ??? ??? ??? ???  ??? ??? ??? ???  ??? ??? ??? ???  \ 5
ops  upl upl upl puw  cgt cgt cgt psb  uph uph uph psw  ??? ??? mpd mpq  \ 6
ops  ??? gpa gpa gpa  ceq ceq ceq ems  ??? ??? ??? ???  ??? ??? mdp mqp  \ 7

ops  lbr lbr lbr lbr  lbr lbr lbr lbr  lbr lbr lbr lbr  lbr lbr lbr lbr  \ 8
ops  set set set set  set set set set  set set set set  set set set set  \ 9
ops  pss pps cpu btx  sli slc ??? ???  pss pps rsm btx  sri src ??? iml  \ A
ops  cxc cxc lss btx  lfs lgs mvx mvx  ??? ud1 gp8 btx  bsf bsr mvx mvx  \ B

ops  xad xad ??? ???  ??? ??? ??? cx8  bsp bsp bsp bsp  bsp bsp bsp bsp  \ C
ops  ??? shx shx shx  ??? mll ??? ???  sus sus ??? pad  aus aus ??? pan  \ D
ops  ??? shx shx ???  ??? mlh ??? ???  sbs sbs ??? por  ads ads ??? pxr  \ E
ops  ??? ??? shx shx  ??? mad ??? ???  sub sub sub ???  add add add ???  \ F
\     0   1   2   3    4   5   6   7    8   9   A   B    C   D   E   F

: 0F.  ( adr code )
  drop cfetch dup
  dup $70 and $50 $80 within mmx-reg:!
  op-table2 dd-nth @execute
  mmx-reg:!0 xmm-reg:!0 ;

create op-table

\     0   1   2   3    4   5   6   7    8   9   A   B    C   D   E   F
ops  alu alu alu alu  ala ala pss pps  alu alu alu alu  ala ala pss 0F.  \ 0
ops  alu alu alu alu  ala ala pss pps  alu alu alu alu  ala ala pss pps  \ 1
ops  alu alu alu alu  ala ala es: daa  alu alu alu alu  ala ala cs: das  \ 2
ops  alu alu alu alu  ala ala ss: aaa  alu alu alu alu  ala ala ds: aas  \ 3

ops  inc inc inc inc  inc inc inc inc  dec dec dec dec  dec dec dec dec  \ 4
ops  psh psh psh psh  psh psh psh psh  pop pop pop pop  pop pop pop pop  \ 5
ops  psa ppa bnd arp  fs: gs: d16 a16  psi mli psi mli  inb isd osb osd  \ 6
ops  bra bra bra bra  bra bra bra bra  bra bra bra bra  bra bra bra bra  \ 7

ops  ali ali ??? ali  txb txb txb txb  mov mov mov mov  mrs lea msr 8F.  \ 8
ops  xga xga xga xga  xga xga xga xga  cbw cdq cis w8f  psf ppf sah lah  \ 9
ops  mv1 mv1 mv2 mv2  mvs mvs cps cps  tst tst sts sts  lds lds scs scs  \ A
ops  mri mri mri mri  mri mri mri mri  mri mri mri mri  mri mri mri mri  \ B

ops  shf shf rtn rtn  lxs lxs mvi mvi  ent lev rtf rtf  nt3 int nto irt  \ C
ops  shf shf shf shf  aam aad ??? xlt  fd8 fd9 fda fdb  fdc fdd fde fdf  \ D
ops  lup lup lup lup  inp inp otp otp  jsr jmp cis jmp  ind ind otd otd  \ E
ops  lok ??? rpz rep  hlt cmc F6. F6.  clc stc cli sti  cld std FE. FF.  \ F
\     0   1   2   3    4   5   6   7    8   9   A   B    C   D   E   F


\ -------------------------- SSE2 Operations -------------------------------

\ -- swap reg fields in mod-r/m byte
: swap-regs ( u1 -- u2 )
  >r
  r@ ( mod-r/m ) 7 and 3 lshift
  r@ ( mod-r/m ) 3 rshift 7 and  or
  r@ ( mod-r/m ) $C0 and or
  rdrop ;

: ?swap-regs  ( u1 -- u2 )  dup $C0 and $C0 = ?< swap-regs >? ;

: modbyte  ( mod-r-r/m -- r/m r mod )   ( r including general, special, segment, MMX )
           ( mod-op-r/m -- r/m op mod )
  $ff and 8 /mod-swap 8 /mod-swap ;

(* defined above
: mod-r/m ( addr modr/m -- addr' )
  modbyte NIP ( [mod-r-r/m] -- r/m mod )
  dis.default-16bit? ?< mod-r/m16 || mod-r/m32 then
;
*)

\ : ::imm8  ( addr -- addr' )  ., cfetch h.>s  ;
: stab  ( pos - )  s-buf c@ - 1 max sspaces ;
: rstab  $08 stab ;
: r:sse2  xmm-reg:!1  mmx-reg:!0 ;
: r:reg  ( a n -- a )  7 and reg ;
: 0f-prefix?  ( adr -- adr' flag )  dup 1+ dis-c@ $0F = ;

: xm-r/m,r  ( addr -- addr' )  rstab r:sse2 r/m,r ;
: xm-r,r/m  ( addr -- addr' )  rstab r:sse2 r,r/m ;

\ the register is always XMM
: r32/m,xmmr ( addr -- addr' )
  rstab cfetch ?swap-regs xmm-reg:!1
  dup >r mod-r/m ., r> 3 rshift r:reg ;

\ dest register is XMM
: xmmr,r32/m  ( addr -- addr' )
  rstab xmm-reg:!1 cfetch dup 3 rshift r:reg
  ., xmm-reg:!0  r/m16/32 ;

\ 1st=r32 2nd=XMM
: r,xmm  ( addr -- addr' )
  rstab xmm-reg:!0 cfetch dup 3 rshift
  reg32 ., .xmmreg ;

: .cmp-sse ( adr -- adr' )
  dup 1+ dis-c@ <<
    0 of?v| .s" cmpeq" |?
    1 of?v| .s" cmplt" |?
    2 of?v| .s" cmple" |?
    3 of?v| .s" cmpunord" |?
    4 of?v| .s" cmpneq" |?
    5 of?v| .s" cmpnlt" |?
    6 of?v| .s" cmpnle" |?
    7 of?v| .s" cmpord" |?
  else| drop >> ;

: dis-cmpps ( adr -- adr' ) .cmp-sse .s-mnemo" ps" xm-r,r/m 1+ ;
: dis-cmpss ( adr -- adr' ) .cmp-sse .s-mnemo" ss" xm-r,r/m 1+ ;
: dis-cmppd ( adr -- adr' ) .cmp-sse .s-mnemo" pd" xm-r,r/m 1+ ;
: dis-cmpsd ( adr -- adr' ) .cmp-sse .s-mnemo" sd" xm-r,r/m 1+ ;

: save-adr  ( adr flag -- flag adr adr  )  true swap dup ;
: restore-adr  ( true adr adr1 --  false adr adr adr )  2drop nip false swap dup dup ;

: get-adrfl ( flag adr adr'  -- adrfl flag )  rot ?< nip true || drop false >? ;

: ?dis-3Aext  ( adr -- adr' )
  cfetch <<
    $40 of?v| .s-mnemo" dpps" xm-r,r/m imm8 |?
    $41 of?v| .s-mnemo" dppd" xm-r,r/m imm8 |?
  else| drop >> ;

: ?dis-660f ( adr flag -- adr' flag )
  ?< save-adr 2+ cfetch
    <<
      $10 of?v| .s-mnemo" movupd"   xm-r,r/m |?
      $11 of?v| .s-mnemo" movupd"   r32/m,xmmr |?
      $12 of?v| .s-mnemo" movlpd"   xm-r,r/m |?
      $13 of?v| .s-mnemo" movlpd"   r32/m,xmmr |?
      $14 of?v| .s-mnemo" unpcklpd" xmmr,r32/m |?
      $15 of?v| .s-mnemo" unpckhpd" xmmr,r32/m |?
      $16 of?v| .s-mnemo" movhpd"   xm-r,r/m |?
      $17 of?v| .s-mnemo" movhpd"   r32/m,xmmr |?
      $28 of?v| .s-mnemo" movapd"   xm-r,r/m |?
      $29 of?v| .s-mnemo" movapd"   r32/m,xmmr |?
      $2e of?v| .s-mnemo" ucomisd"  xm-r,r/m |?
      $2f of?v| .s-mnemo" comisd"   xm-r,r/m |?
      $3a of?v| ?dis-3Aext |?
      $51 of?v| .s-mnemo" sqrtpd"   xm-r,r/m |?
      $54 of?v| .s-mnemo" sqrtpd"   xm-r,r/m |?
      $54 of?v| .s-mnemo" andpd"    xm-r,r/m |?
      $55 of?v| .s-mnemo" andnpd"   xm-r,r/m |?
      $56 of?v| .s-mnemo" orpd"     xm-r,r/m |?
      $57 of?v| .s-mnemo" xorpd"    xm-r,r/m |?
      $58 of?v| .s-mnemo" addpd"    xm-r,r/m |?
      $59 of?v| .s-mnemo" mulpd"    xm-r,r/m |?
      $5a of?v| .s-mnemo" cvtps2ps" xm-r,r/m |?
      $5b of?v| .s-mnemo" cvtps2dq" xm-r,r/m |?
      $5c of?v| .s-mnemo" subpd"    xm-r,r/m |?
      $5d of?v| .s-mnemo" minpd"    xm-r,r/m |?
      $5e of?v| .s-mnemo" divpd"    xm-r,r/m |?
      $5f of?v| .s-mnemo" maxpd"    xm-r,r/m |?
      $6e of?v| .s-mnemo" movd"     xm-r,r/m |?
      $7e of?v| .s-mnemo" movd"     r32/m,xmmr |?
      $6f of?v| .s-mnemo" movqda"   xmmr,r32/m |?
      $7f of?v| .s-mnemo" movqda"   r32/m,xmmr |?
      $c2 of?v| dis-cmppd |?
      $c6 of?v| .s-mnemo" shufpd"   xm-r,r/m imm8 |?
      $d7 of?v| .s-mnemo" pmovmskb" r,xmm |?
    else| drop restore-adr >> get-adrfl
  || false ( no 66 0f ) >? ;

: ?dis-0f ( adr flag -- adr' flag )
  ?< true swap 1+ cfetch
    <<
      $10 of?v| .s-mnemo" movups"   xm-r,r/m |?
      $11 of?v| .s-mnemo" movups"   r32/m,xmmr |?
      $14 of?v| .s-mnemo" unpcklps" xmmr,r32/m |?
      $15 of?v| .s-mnemo" unpckhps" xmmr,r32/m |?
      $28 of?v| .s-mnemo" movaps"   xm-r,r/m |?
      $29 of?v| .s-mnemo" movaps"   r32/m,xmmr |?
      $2a of?v| .s-mnemo" movaps"   xmmr,r32/m |?
      $2e of?v| .s-mnemo" ucomisd"  xm-r,r/m |?
      $2f of?v| .s-mnemo" comiss"   xm-r,r/m |?
      $51 of?v| .s-mnemo" sqrtps"   xm-r,r/m |?
      $52 of?v| .s-mnemo" rsqrtps"  xm-r,r/m |?
      $53 of?v| .s-mnemo" rcpps"    xm-r,r/m |?
      $54 of?v| .s-mnemo" andps"    xm-r,r/m |?
      $55 of?v| .s-mnemo" andnps"   xm-r,r/m |?
      $56 of?v| .s-mnemo" orps"     xm-r,r/m |?
      $57 of?v| .s-mnemo" xorps"    xm-r,r/m |?
      $58 of?v| .s-mnemo" addps"    xm-r,r/m |?
      $59 of?v| .s-mnemo" mulps"    xm-r,r/m |?
      $5a of?v| .s-mnemo" cvtps2pd" xm-r,r/m |?
      $5b of?v| .s-mnemo" cvtdq2ps" xm-r,r/m |?
      $5c of?v| .s-mnemo" subps"    xm-r,r/m |?
      $5d of?v| .s-mnemo" minps"    xm-r,r/m |?
      $5e of?v| .s-mnemo" divps"    xm-r,r/m |?
      $5f of?v| .s-mnemo" maxps"    xm-r,r/m |?
      $c2 of?v| dis-cmpps |?
      $c6 of?v| .s-mnemo" shufps"   xm-r,r/m imm8 |?
    else| rot drop false nrot drop >> swap
   || false ( no 0f ) >? ;

: ?dis-f20f ( adr flag -- adr' flag )
  ?< save-adr 2+ cfetch
    <<
      $10 of?v| .s-mnemo" movsd"    xm-r,r/m |?
      $11 of?v| .s-mnemo" movsd"    xm-r/m,r |?
      $2a of?v| .s-mnemo" cvtsi2sd" xmmr,r32/m |?
      $51 of?v| .s-mnemo" sqrtsd"   xm-r,r/m |?
      $52 of?v| .s-mnemo" rsqrtsd"  xm-r,r/m |?
      $58 of?v| .s-mnemo" addsd"    xm-r,r/m |?
      $59 of?v| .s-mnemo" mulsd"    xm-r,r/m |?
      $5a of?v| .s-mnemo" cvtsd2ss" xm-r,r/m |?
      $5c of?v| .s-mnemo" subsd"    xm-r,r/m |?
      $5d of?v| .s-mnemo" minsd"    xm-r,r/m |?
      $5e of?v| .s-mnemo" divsd"    xm-r,r/m |?
      $5f of?v| .s-mnemo" maxsd"    xm-r,r/m |?
      $c2 of?v| dis-cmpsd |?
      $e6 of?v| .s-mnemo" cvtpd2dq" xmmr,r32/m |?
    else| drop restore-adr >> get-adrfl
   || false ( no f2 0f ) >? ;

: ?dis-f30f ( adr flag -- adr' flag )
  ?< save-adr 2+ cfetch ( f a0 a1 )
    <<
      $10 of?v| .s-mnemo" movss"     xm-r,r/m |?
      $11 of?v| .s-mnemo" movss"     xm-r/m,r |?
      $2a of?v| .s-mnemo" cvtsi2ss"  xmmr,r32/m |?
      $51 of?v| .s-mnemo" sqrtss"    xm-r,r/m |?
      $52 of?v| .s-mnemo" rsqrtss"   xm-r,r/m |?
      $53 of?v| .s-mnemo" rcpss"     xm-r,r/m |?
      $58 of?v| .s-mnemo" addss"     xm-r,r/m |?
      $59 of?v| .s-mnemo" mulss"     xm-r,r/m |?
      $5a of?v| .s-mnemo" cvtss2sd"  xm-r,r/m |?
      $5b of?v| .s-mnemo" cvttps2dq" xm-r/m,r |?
      $5c of?v| .s-mnemo" subss"     xm-r,r/m |?
      $5d of?v| .s-mnemo" minss"     xm-r,r/m |?
      $5e of?v| .s-mnemo" divss"     xm-r,r/m |?
      $5f of?v| .s-mnemo" maxss"     xm-r,r/m |?
      $6f of?v| .s-mnemo" movdqu"    xm-r,r/m |?
      $7f of?v| .s-mnemo" movdqu"    r32/m,xmmr |?
      $c2 of?v| dis-cmpss |?
      $e6 of?v| .s-mnemo" cvtdq2pd"  xmmr,r32/m |?
    else| drop restore-adr >> get-adrfl
  || false ( no f3 0f ) >? ;

: pf-coded? ( adr -- adr' flag )
  dup dis-c@ <<
    $66 of?v| 0f-prefix? ?dis-660f |?
    $f2 of?v| 0f-prefix? ?dis-f20f |?
    $f3 of?v| 0f-prefix? ?dis-f30f |?
  else| drop false >> ;

: prefix-coded? ( adr -- adr' flag )
  pf-coded? ?exit< true >?
  dup dup dis-c@ $0f = ?dis-0f ?< rot drop true || drop false >? ;

\ ------------------- END OF SSE2 Operations -------------------------------


: op-2byte lo-word , ' , ;

: inh-sized   ( -<name>- )
 <builds parse-name-to-here-cstr count 4+ allot drop
  parse-name-to-here-cstr count 4+ allot drop
 does>
  count default-16bit? ?< + count >? >s
  drop ( instruction code ) ;

inh-sized cwd    cwd    cdw
inh-sized cbwx   cbw    cwb
inh-sized cmpsx  cmpsw  cmpsd
inh-sized lodsx  lodsw  lodsd
inh-sized movsx  movsw  movsd
inh-sized stosx  stosw  stosd
inh-sized scasx  scasw  scasd
inh-sized insx   insw   insw
inh-sized outsx  outsw  outsd
inh-sized popax  popa   popad
inh-sized pushax pusha  pushad
inh-sized popfx  popf   popfd
inh-sized pushfx pushf  pushfd
inh-sized iretx  iretw  iret

\ FIXME: 16-bit is broken
create 2byte-oplist
$9966 op-2byte cwd
$9866 op-2byte cbwx
$A566 op-2byte movsx
$A766 op-2byte cmpsx
$AB66 op-2byte stosx
$AF66 op-2byte scasx
$AD66 op-2byte lodsx
$6D66 op-2byte insx
$6F66 op-2byte outsx
$6166 op-2byte popax
$6066 op-2byte pushax
$9D66 op-2byte popfx
$9C66 op-2byte pushfx
$CF66 op-2byte iretx
0 ,

: (dis-op-init-flags)
  data-size-prefix:!0
  disp-as-reg-offset:!f
  mmx-reg:!0 xmm-reg:!0 ;

: (dis-op-done-flags)
  prefix-op not?<
    default-16bit? dup 16-bit-data:! 16-bit-addr:!
    prefix-seg:!0
    prefix-op-a16-d16:!0 >? ;

: (dis-known-wtable)  ( addr -- addr' true // addr false )
  dup dis-w@ 2byte-oplist ( addr wp tbladdr )
  << 2dup w@ - not?v|| dup w@ not?v|| 2 4* + ^|| >>
  nip dup w@ ?< 4+ @ 0 swap execute 2+ true || drop false >? ;

: (dis-op-intr)  ( adr -- adr' )
  0>s prefix-op:!f  \ SMuB
  (dis-known-wtable) not?<
    cfetch
    dup 1 and size:!
    dup op-table dd-nth @execute >? ;

: beast-sswap?  ( adr -- adr' done-flag )
  dup dis-@ $EC_8B_D5_8B = not?exit&leave
  dup 4+ dis-w@ $E2_8B = not?exit&leave
  0>s .s" swap-stacks" 6 + true ;

: dis-op  ( adr -- adr' )
\  (dis-op-init-flags) 6 for
\    (dis-op-intr) prefix-op not?< break >?
\    prefix-seg prefix-op-a16-d16 or not?< break >?
\  endfor (dis-op-done-flags) ;
  beast-sswap? ?exit
  (dis-op-init-flags) 6 >r <<
    (dis-op-intr) prefix-op not?exit< rdrop (dis-op-done-flags) >?
    prefix-seg prefix-op-a16-d16 or not?exit< rdrop (dis-op-done-flags) >?
  r0:1-! r@ ?^|| else| 2drop >> (dis-op-done-flags) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level stuff
;;

<published-words>

: .s-buf  s-buf c@++ type ;

0 quan next-inst

;; on error, "next-inst" is unchanged
: do-one-inst  ( -- errorflag )
  next-inst   ;; addr
\ endcr ." XD86: pc=$" dup .hex8 bl emit ." $" dup dis-c@ .hex2 cr
  dup dis-op  ;; addr eaddr
  over addr-offset + .hex8 bl emit ;; type address
  swap 2dup - 16 u> ?< 2drop true >?
  over next-inst:!  ;; update next instruction address
  \ 2dup do i dis-c@ .hex2 bl emit loop
  2dup << 2dup u> ?^| dup dis-c@ .hex2 bl emit 1+ |? else| 2drop >>
  - 12 swap - 3 * bl #emit false ;


: .inst  ( adr -- adr' )
  next-inst:! do-one-inst ?error" disasm error" next-inst ;


\ @@@ BH fixed bugs in dis-xx

\ : dis-db  ( adr -- adr' )  0>s .s" db " cfetch h.>s .s-buf ;
\ : dis-dw  ( adr -- adr' )  0>s .s" dw " wfetch h.>s .s-buf ;
\ : dis-dd  ( adr -- adr' )  0>s .s" dd " fetch h.>s .s-buf ;
\ : dis-ds  ( adr -- adr' )  0>s .s" string " $22 emit>s c@++ 2dup >s + $22 emit>s .s-buf ;

: disasm-one  ( adr -- adr' )
  x86dis:.inst .s-buf cr ;

: disasm-range  ( start end )
  swap << 2dup u> ?^| disasm-one |? else| 2drop >> ;

[HAS-WORD] debug:(disasm-one) [IF]

|: find-word-by-cfa  ( cfa-xt -- nfa TRUE // FALSE )
  forth::(last-xfa) << @ dup not?v| 2drop false |?
    2dup dart:xfa>cfa = not?^||
  else| drop dart:cfa>nfa true >> ;

|: x86-find-name  ( cfa-xt -- addr count // dummy 0 )
  find-word-by-cfa not?exit< forth:pad 0 >? debug:idfull>pad ;

: install-see
  debug:(disasm-one) not?< ['] disasm-one debug:(disasm-one):! >?
  ['] x86-find-name find-name:! ;
install-see
[ENDIF]

seal-module
end-module x86dis
