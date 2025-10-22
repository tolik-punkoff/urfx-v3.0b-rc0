;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler: instruction matcher and builder
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(*
after we found a match, we can "sort" operands. in any case we need to
process "r/m" first, because it creates "mod|reg|r/m" byte. then we
need to process reg, then imm, then ptr, then ctr, then rel. i mean,
this is already done, but we can sort operands once instead of testing
all of them for each new type.
*)

using iop-helpers

: imm-size-known?  ( size -- okflag TRUE / size FALSE )
  aa>type:@ imm = not?exit< drop 0 true >?
  aa>size:@ dup ?exit< = true >? drop
  aa>label:@ emit:known-value? not?exit< 4 = true >? -- forward reference
  false ;

: imm@  ( -- imm-value )
  aa>label:@ dup ?< emit:value@ || drop aa>imm:@ >? ;

: imm-size?  ( size -- okflag )
  imm-size-known? ?exit
  imm@ swap <<
    1 of?v| -128 256 within |?
    2 of?v| -32768 65536 within |?
  else| 2drop true >> ;

: iimm-size?  ( size -- okflag )
  imm-size-known? ?exit
  imm@ swap <<
    1 of?v| -128 128 within |?
    2 of?v| -32768 32768 within |?
  else| drop true >> ;

: uimm-size?  ( size -- okflag )
  imm-size-known? ?exit
  imm@ swap <<
    1 of?v| 128 |?
    2 of?v| 32768 |?
    4 of?v| 0x8000_0000 |?
  else| drop true >> u< ;

: addr-size? ( size -- okflag )  aa>size:@ = aa>type:@ addr = and ;

: fpu-addr-size? ( size -- okflag )
  aa>size:@ = not?exit&leave
  aa>type:@ dup rm32 =
  swap dup addr =
  swap sib32 = or or ;

: type?      ( type -- okflag )      aa>type:@ = ;
: type-srm?  ( type srm -- okflag )  aa>srm:@ = swap aa>type:@ = and ;

: mem?  ( -- okflag )
  aa>type:@ dup addr = over rm32 = or swap sib32 = or ;

: r/mX?  ( size regn -- okflag )
  type? ?exit< drop true >?
  aa>size:@ = dup ?exit< drop mem? >? ;

: calc-rel  ( value sz -- value )
  i>opcode 24 rshift + emit:here + - ;

: rel8?  ( -- okflag )
  imm type? dup not?exit drop
  aa>label:@ emit:known-value? dup not?exit drop
  imm@ 1 calc-rel -128 128 within ;


create arg-checkers id-helpers:iarg-max 4* allot create;
arg-checkers id-helpers:iarg-max 4* erase
: arg-checker!  ( cfa idx )  arg-checkers dd-nth ! ;

create iop-sizes id-helpers:iarg-max allot create;
iop-sizes id-helpers:iarg-max erase
: iop-size!  ( size idx )  iop-sizes + c! ;

create iop-classes id-helpers:iarg-max allot create;
iop-classes id-helpers:iarg-max erase
: iop-class!  ( size idx )  iop-classes + c! ;

: id-info!  ( class size checkcfa idx )
  dup >r arg-checker! r@ iop-size! r> iop-class! ;

: op-size@  ( idx -- size )  iop-sizes + c@ ;
: op-class@ ( idx -- size )  iop-classes + c@ ;

: arg?  ( iarg -- ok?bool )
  dup id-helpers:iarg-max u>= ?error" invalid #arg (internal error)"
  arg-checkers dd-nth @execute-tail ;

0 quan arg-rel-size -- to avoid having 2 classes for rel
7 constant max-class

;; the biggest part of the matcher ;-)
0    0 :noname 0 type? ; id-helpers:.... id-info!
3   db :noname 1 imm-size? ; id-helpers:imm8 id-info!
3   dw :noname 2 imm-size? ; id-helpers:imm16 id-info!
3   dd :noname 4 imm-size? ; id-helpers:imm32 id-info!
3   db :noname 1 iimm-size? ; id-helpers:iimm8 id-info!
3   db :noname 1 uimm-size? ; id-helpers:uimm8 id-info!
6 dany :noname rel8? emit:disp-rel8 arg-rel-size:! ; id-helpers:rel8 id-info!
6 dany :noname imm type? emit:disp-rel32 arg-rel-size:! ; id-helpers:rel32 id-info!
1   db :noname 1 reg8 r/mX? ; id-helpers:r/m8 id-info!
1   dw :noname 2 reg16 r/mX? ; id-helpers:r/m16 id-info!
1   dd :noname 4 reg32 r/mX? ; id-helpers:r/m32 id-info!
1   dq :noname 8 addr-size? ; id-helpers:m64 id-info!
1   dd :noname 4 rxmm r/mX? ; id-helpers:xr/m32 id-info!
1   dq :noname 8 rxmm r/mX? ; id-helpers:xr/m64 id-info!
1  d16 :noname 16 rxmm r/mX? ; id-helpers:xr/m128 id-info!
2   db :noname reg8 type? ; id-helpers:reg8 id-info!
2   dw :noname reg16 type? ; id-helpers:reg16 id-info!
2   dd :noname reg32 type? ; id-helpers:reg32 id-info!
2 dany :noname rxmm type? ; id-helpers:xmreg id-info!
2   dw :noname rseg type? ; id-helpers:SR id-info!
2 dfpu :noname rfpu type? ; id-helpers:STx id-info!
0 dfpu :noname rfpu 0 type-srm? ; id-helpers:ST0 id-info!
0   dw :noname rseg 3 type-srm? ; id-helpers:DS id-info!
0   dw :noname rseg 0 type-srm? ; id-helpers:ES id-info!
0   dw :noname rseg 2 type-srm? ; id-helpers:SS id-info!
0   dw :noname rseg 4 type-srm? ; id-helpers:FS id-info!
0   dw :noname rseg 5 type-srm? ; id-helpers:GS id-info!
5   dd :noname rctl type? ; id-helpers:ctreg id-info!
5   dd :noname rdbg type? ; id-helpers:dbreg id-info!
5   dd :noname rtst type? ; id-helpers:tsreg id-info!
0   db :noname reg8 0 type-srm? ; id-helpers:AL id-info!
0   db :noname reg8 1 type-srm? ; id-helpers:CL id-info!
0   dw :noname reg16 0 type-srm? ; id-helpers:AX id-info!
0   dw :noname reg16 2 type-srm? ; id-helpers:DX id-info!
0   dd :noname reg32 0 type-srm? ; id-helpers:EAX id-info!
4   db :noname 1 addr-size? ; id-helpers:bptr id-info!
4   dw :noname 2 addr-size? ; id-helpers:wptr id-info!
4   dd :noname 4 addr-size? ; id-helpers:dptr id-info!
4   dq :noname 8 addr-size? ; id-helpers:qptr id-info!
4   dt :noname 10 addr-size? ; id-helpers:tptr id-info!
4 dany :noname addr type? ; id-helpers:aptr id-info!
;; for fpu
7   db :noname 1 fpu-addr-size? ; id-helpers:fbptr id-info!
7   dw :noname 2 fpu-addr-size? ; id-helpers:fwptr id-info!
7   dd :noname 4 fpu-addr-size? ; id-helpers:fdptr id-info!
7   dq :noname 8 fpu-addr-size? ; id-helpers:fqptr id-info!
7   dt :noname 10 fpu-addr-size? ; id-helpers:ftptr id-info!

0 quan cid-size

: ?size
  cid-size dup not?exit< drop >?
  dup dany = ?exit< drop >?
  aa>size:@ dup not?exit< 2drop >?
  dup dany = ?exit< 2drop >?
  over dfpu = ?< drop 4 >= || = >? not?error" invalid size" ;

: prepare-disp  imm@ emit:disp:! aa>label:@ emit:label-disp:! ;
: prepare-addr  0o005 emit:mrm/sib:! prepare-disp ;
: prepare-rm32  aa>srm:@ emit:mrm/sib:! prepare-disp ;
: prepare-regXX aa>srm:@ 0o300 or emit:mrm/sib:! ;

: prepare-arg-r/m
  ?size aa>type:@ <<
    dup reg8 rxmm bounds ?of?v| prepare-regXX |?
    rm32 of?v| prepare-rm32 |?
    sib32 of?v| prepare-rm32 |?
    addr of?v| prepare-addr |?
  else| error" invalid instruction (internal error)" >> ;

;; we will come here with r/m processed
;; if there is no r/m set, then there should be a flag (or nothing)
: prepare-arg-reg
  aa>srm:@ 7 and  emit:mrm/sib hi-word not?< emit:reg!
  || i>flags id-helpers:/r = ?< emit:opcode# 1- 8 * lshift emit:opcode:+!
  || drop >? >? ;

: prepare-arg-imm
  aa>imm?:@ not?error" where's my imm?"
  cid-size dup not?error" imm size? (internal error)"
  aa>size:@ over > ?error" invalid imm size"
  emit:imm#:! imm@ emit:imm:! aa>label:@ emit:label-imm:! ;

: prepare-arg-mod|r/m
  emit:mrm/sib
  i>flags id-helpers:/0 id-helpers:/7 bounds ?< dup hi-word ?< drop 0o005 >?
  || drop emit:disp-addr >? emit:mrm/sib:! ;

: prepare-flags
  i>flags dup id-helpers:/0 id-helpers:/7 bounds
  ?exit< id-helpers:/0 - emit:reg! >? drop ;

: prepare-arg-ptr  ?size prepare-disp prepare-arg-mod|r/m ;
: prepare-arg-fap  ?size prepare-flags prepare-arg-r/m ;
: prepare-arg-ctr  aa>srm:@ 19 lshift emit:opcode:+! ;
: prepare-arg-rel  arg-rel-size emit:mrm/sib:! prepare-disp ;

: postfix-sizes
  emit:prefix lo-byte $66 = not?exit
  emit:imm# not?exit
  emit:imm -32768 65536 within not?error" imm too big" ;

: dsize-prefix!  emit:prefix 256 * $66 or emit:prefix:! ;
: cut-opc-byte  ( opc -- opc )  dup 256 u/ lo-word swap 0xff00_0000 and 0x0100_0000 - or ;

: prepare-opcode
  i>opcode dup lo-byte $66 = ?< dsize-prefix! cut-opc-byte >? emit:opcode:! ;

create preps -- class 0 is not used
  ['] prepare-arg-r/m ,
  ['] prepare-arg-reg ,
  ['] prepare-arg-imm ,
  ['] prepare-arg-ptr ,
  ['] prepare-arg-ctr ,
  ['] prepare-arg-rel ,
  ['] prepare-arg-fap ,
create;

;; argument indicies (+1) for each class
create alist max-class 1+ allot create;

: classify-args
  alist [ max-class 1+ ] {#,} erase
  3 for i i>op# op-class@ alist + i 1+ swap c! endfor ;

: prep-arg  ( aidx class )
  preps dd-nth swap 1- dup >arg-th i>op# op-size@ cid-size:! @execute-tail ;

: prepare-args
  alist 1+ max-class for c@++ dup ?< dup i prep-arg >? drop endfor drop ;

: prepare-builder
  classify-args prepare-opcode prepare-args prepare-flags postfix-sizes ;

: ?match  ( -- found-flag )
  true 3 for dup ?< i dup >arg-th i>op# arg? and >? endfor ;

: itable-match  ( -- found-flag )
  false begin <instr-table> @ while
  drop ?match dup ?< prepare-builder >? instr-size <instr-table>:+! dup until ;

: 16bit-size?  ( -- flag )
  aa>size:@ dup 2 > ?< drop 2 || 2 = ?< 4 aa>size:! >? 0 >? ;

: maybe-16bit?  ( -- bool )
  i>opcode lo-byte $66 = ?exit< false >?
  0 3 for i >arg-th aa>type:@ <<
    none of?v| 0 |?
    reg8 of?v| 1 |?
    reg16 of?v| reg32 aa>type:! 4 aa>size:! 1 |?
    reg32 of?v| 2 |?
    rseg of?v| 1 |?
    rm32 of?v| 16bit-size? |?
    addr of?v| 16bit-size? |?
    sib32 of?v| 16bit-size? |?
    imm of?v| imm@ -32768 65536 within ?< 1 16bit-size? or || 2 >? |?
  else| drop 2 >> or endfor 1 = ;

: build-instruction
  <instr-table> not?exit
  finish-arg <instr-table>
  itable-match not?< <instr-table>:! $66 emit:prefix:!
    maybe-16bit? ?< itable-match || false >?
  >?
  emit:opcode id-helpers:<invalid> = ?< drop false >?
  not?error" invalid instruction" ;
['] build-instruction emit:builder:!
