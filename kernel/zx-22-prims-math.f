;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; various math and compare primitives
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimiser utilities

primopt: (cgen-u8-pot?)  ( value -- pot TRUE // value FALSE )
  lo-byte dup pot dup +0?exit< nip true >?
  drop false ;

primopt: (cgen-~u8-pot?)  ( value -- pot TRUE // value FALSE )
  dup -1 xor lo-byte pot dup +0?exit< nip true >?
  drop lo-byte false ;


primopt: (cgen-next-T/0-BRANCH?)  ( -- bool )
  OPT-OPTIMIZE-PEEPHOLE? not?exit&leave
  ir:next-node-spfa
  dup ir:opt:(opt-zx-"0BRANCH") =
  swap ir:opt:(opt-zx-"TBRANCH") =
  or ;


primopt: (cgen-prev-prev-a->l?)  ( -- flag )
  peep-pattern:[[
    ld    l, a
  ]] peep-match ;


primopt: (cgen-prev-a->tos-r16l?)  ( -- flag )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    l, a
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    e, a
    ]]
  >?
  peep-match ;

primopt: (cgen-prev-a->tos-r16h?)  ( -- flag )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    h, a
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    d, a
    ]]
  >?
  peep-match ;

primopt: (cgen-prev-load-tosr16h-#0?)  ( -- flag )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    h, # 0
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    d, # 0
    ]]
  >?
  peep-match ;

primopt: (cgen-prev-load-tosr16h-#255?)  ( -- flag )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    h, # 255
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    d, # 255
    ]]
  >?
  peep-match ;

primopt: (cgen-prev-load-tosr16l-#0?)  ( -- flag )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    l, # 255
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    e, # 255
    ]]
  >?
  peep-match ;

primopt: (cgen-prev-byte-node?)  ( -- flag )
  OPT-OPTIMIZE-PEEPHOLE? not?exit&leave
  ir:prev-node-spfa ir:opt:(opt-zx-LIT) = ?exit<
    ir:prev-node ir:node:value hi-byte 0=
  >?
  ;; check for "ld tosr16h, # 0"
  ;; if next node is "0BRANCH" or "TBRANCH",
  ;; it will use our zflag, and we can remove the load
  ;; WARNING! this relies on the zflag peephole optimisation in those branches!
  (cgen-prev-load-tosr16h-#0?) not?exit<
    ;; still don't zero r16h if the next node is good branch
    (cgen-next-T/0-BRANCH?) ?exit&leave
    ir:prev-node ir:node-out-8bit?
  >?
  (cgen-next-T/0-BRANCH?) not?exit< true >?
  ;; we can remove TOS high byte clear, branch doesn't care
  1 can-remove-n-last? ?< remove-last-instruction >?
  true ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 32-bit operations

primitive: DNEGATE  ( dlo dhi -- negated-dlo negated-dhi )
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?< ex-de-hl >?
  ;; DE:HL -- da
  hl->bc
  xor-a
  a->h
  a->l
  sbc-hl-bc
  push-hl
  a->h
  a->l
  sbc-hl-de
  TOS-in-HL! ;
alias-for DNEGATE is DMINUS   ( dlo dhi -- negated-dlo negated-dhi )

primitive: DS+  ( d-lo d-hi b -- d+b-lo d+b-hi )
:codegen-xasm
  ;; TOS: b
  pop-non-tos-peephole
  ;; non-TOS: da-hi; TOS: b
  TOS-in-DE? ?< ex-de-hl >?
  ;; HL=b; DE=da-hi
  pop-bc
  ;; HL=b; DE=da-hi; BC=da-lo
  add-hl-bc
  push-hl      ;; store lo
  0 #->bc
  ex-de-hl
  adc-hl-bc
  TOS-in-HL! ;

primitive: SD+  ( b d-lo d-hi -- d+b-lo d+b-hi )
:codegen-xasm
  pop-non-tos-peephole
  ;; non-TOS: da-lo; TOS: da-hi
  TOS-in-HL? ?< ex-de-hl >?
  ;; DE:HL -- da
  pop-bc
  ;; BC: b
  add-hl-bc
  push-hl      ;; store lo
  0 #->bc
  ex-de-hl
  adc-hl-bc
  TOS-in-HL! ;

primitive: D+  ( da-lo da-hi db-lo db-hi -- da+b-lo da+b-hi )
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?< ex-de-hl >?
  ;; DE:HL -- db
  pop-af
  pop-bc
  push-af
  ;; BC: da-lo
  add-hl-bc
  pop-bc
  ;; BC: da-hi
  push-hl      ;; store lo
  ex-de-hl
  adc-hl-bc
  TOS-in-HL! ;

code: D-  ( da db -- da-db )
  ld    bc, hl
  pop   hl
  ;; BC:HL -- db
  pop   af
  pop   de
  push  af
  ;; DE: da-lo
  ex    de, hl
  xor   a
  sbc   hl, de
  ex    (sp), hl
  ;; HL: da-hi
  sbc   hl, bc
;code
4 2 Succubus:setters:in-out-args


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

$include "zx-22-prims-math-10-0cmp.f"
$include "zx-22-prims-math-20-cmp.f"
$include "zx-22-prims-math-30-ucmp.f"
$include "zx-22-prims-math-40-bitshifts.f"
$include "zx-22-prims-math-50-maskbit.f"
$include "zx-22-prims-math-60-andorxor.f"
$include "zx-22-prims-math-80-addsub.f"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; more bitwise operations

primitive: CPL8  ( a -- ~a )
:codegen-xasm
  tos-r16 r16l->a
  cpl
  tos-r16 a->r16l ;

primitive: CPL8-HI  ( a -- ~a )
:codegen-xasm
  tos-r16 r16h->a
  cpl
  tos-r16 a->r16h ;

primitive: CPL  ( a -- ~a )
:codegen-xasm
  tos-r16 r16l->a
  cpl
  tos-r16 a->r16l
  tos-r16 r16h->a
  cpl
  tos-r16 a->r16h ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; byte splitting and joining

primitive: LO-BYTE  ( u -- u>>8 )
Succubus:setters:out-8bit
:codegen-xasm
  0 tos-r16 c#->r16h ;

primitive: HI-BYTE  ( u -- u>>8 )
Succubus:setters:out-8bit
:codegen-xasm
  tos-r16 tos-r16 r16h->r16l
  0 tos-r16 c#->r16h ;
alias-for HI-BYTE is 256U/


primitive: BSWAP  ( n -- n-nswapped )
:codegen-xasm
  tos-r16 non-tos-r16 r16h->r16l
  tos-r16 non-tos-r16 r16l->r16h
  TOS-invert! ;


;; ( lo hi ) order is because doubles are represented like this too
primitive: SPLIT-BYTES  ( n -- n-lo n-hi )
Succubus:setters:out-8bit
:codegen-xasm
  (*
  0 c#->b
  tos-r16 reg:bc r16l->r16l
  push-bc
  tos-r16 tos-r16 r16h->r16l
  reg:bc tos-r16 r16h->r16h ;
  *)
  tos-r16 non-tos-r16 r16l->r16l
  0 non-tos-r16 c#->r16h
  push-non-tos
  tos-r16 tos-r16 r16h->r16l
  ;; for peephole optimiser
  0 tos-r16 c#->r16h ;

primitive: SPLIT-BYTES-HI-LO  ( n -- n-hi n-lo )
Succubus:setters:out-8bit
:codegen-xasm
  (*
  0 c#->b
  tos-r16 reg:bc r16h->r16l
  push-bc
  reg:bc tos-r16 r16h->r16h ;
  *)
  0 non-tos-r16 c#->r16h
  tos-r16 non-tos-r16 r16h->r16l
  push-non-tos
  tos-r16 tos-r16 r16h->r16l
  ;; for peephole optimiser
  \ 0 tos-r16 c#->r16h
  non-tos-r16 tos-r16 r16h->r16h ;


;; ( lo hi ) order is because doubles are represented like this too
primitive: JOIN-BYTES  ( n-lo n-hi -- n )
Succubus:setters:in-8bit
:codegen-xasm
  pop-non-tos-peephole
  tos-r16 tos-r16 r16l->r16h
  non-tos-r16 tos-r16 r16l->r16l ;

primitive: JOIN-BYTES-HI-LO  ( n-hi n-lo -- n )
Succubus:setters:in-8bit
:codegen-xasm
  pop-non-tos-peephole
  non-tos-r16 tos-r16 r16l->r16h ;



;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sign manipulation

primitive: NEGATE  ( a -- negated-a )
:codegen-xasm
  ;; 8-bit code is faster (yet might be 1 byte longer):
  ;; 16-bit: 4+4+4+15=27
  ;; 8-bit: 4+4+4+4+4+4=24
  xor-a-a
  tos-r16 sub-a-r16l
  tos-r16 a->r16l
  sbc-a-a
  tos-r16 sub-a-r16h
  tos-r16 a->r16h ;
alias-for NEGATE is MINUS  ( a -- negated-a )

primitive: ABS  ( a -- |a| )
:codegen-xasm
  tos-r16 7 bit-r16h-n
  cond:z jr-cc  ( patch-addr )
  ;; negate TOS
  xor-a-a
  tos-r16 sub-a-r16l
  tos-r16 a->r16l
  sbc-a-a
  tos-r16 sub-a-r16h
  tos-r16 a->r16h
  jr-dest! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; C>S, S->D

primitive: C>S  ( signed-byte -- n )
Succubus:setters:in-8bit
:codegen-xasm
  \ tos-r16 r16l->a  \ cannot, we need L untouched (cgen-gen-ld-tosr16l-a)
  (cgen-gen-ld-tosr16l-a)
  ;; HACK: if not from L, we need to put it into L
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    a, l
    ]] peep-match not?< a->l >?
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    a, e
    ]] peep-match not?< e->l >?
  >?
  rla
  sbc-a-a
  tos-r16 a->r16h ;
alias-for C>S is C->S
alias-for C>S is C>W

primitive: S>D  ( n -- d-lo d-hi )
:codegen-xasm
  push-tos
  tos-r16 rl-r16h
  sbc-a-a
  tos-r16 a->r16l
  tos-r16 a->r16h ;
alias-for S>D is S->D


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; macros

primitive: 0MAX  ( a -- a//0 )
:codegen-xasm
  tos-r16 7 bit-r16h-n
  cond:z jr-cc
  0 tos-r16 #->r16
  jr-dest! ;

primitive: 1MAX  ( a -- a//1 )
:codegen-xasm
  tos-r16 r16h->a
  or-a
  cond:m jp-cc  ( .failed )
  cond:nz jr-cc  ( .failed .done )
  or-l
  cond:nz jr-cc  ( .failed .done .done )
  ;; .failed
  rot jp-dest!
  1 tos-r16 #->r16
  ;; .done
  jr-dest! jr-dest! ;

<zx-system>
primopt: (cgen-opt-1max-byte-a->tosr16l?)  ( -- bool )
  (cgen-ld-tosr16l-a?) ?exit&leave
  false ;

primitive: 1MAX:BYTE  ( u8 -- u8//1 )
Succubus:setters:in-8bit
Succubus:setters:out-8bit
:codegen-xasm
  ;; it is usually better to not use "LD A, L" and such here, if possible
  (cgen-opt-1max-byte-a->tosr16l?) ?<
    or-a
  ||
    tos-r16 dec-r16l
    tos-r16 inc-r16l
  >?
  cond:nz jr-cc  ( .done )
  tos-r16 inc-r16l
  ;; .done
  jr-dest! ;
<zx-forth>

primitive: MIN  ( a b -- n )
:codegen-xasm
  ;; a-b: positive if a>=b; negative if a<b
  pop-non-tos-peephole
  ;; TOS:b; non-TOS:a
  non-tos-r16 r16l->a
  tos-r16 sub-a-r16l
  non-tos-r16 r16h->a
  tos-r16 sbc-a-r16h
  cond:p jp-cc  ( .a>=b )
  ex-de-hl
  jp-dest! ;

primitive: MAX  ( a b -- n )
:codegen-xasm
  ;; a-b: positive if a>=b; negative if a<b
  pop-non-tos-peephole
  ;; TOS:b; non-TOS:a
  non-tos-r16 r16l->a
  tos-r16 sub-a-r16l
  non-tos-r16 r16h->a
  tos-r16 sbc-a-r16h
  cond:m jp-cc  ( .a>=b )
  ex-de-hl
  jp-dest! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bit swapping

;; http://www.retroprogramming.com/2014/01/fast-z80-bit-reversal.html
code: REV16  ( u -- u )
  call  # .rev8-hl
  ld    l, h
  ld    h, a
@zx-word-do-rev8:
  call  # .rev8-hl
  ld    l, a
  next
.rev8-hl:
  \ ld    l, a  ;; a = 76543210
  ld    a, l
  rlca
  rlca        ;; a = 54321076
  xor   l
  and   # $AA
  xor   l     ;; a = 56341270
  ld    l, a
  rlca
  rlca
  rlca        ;; a = 41270563
  rrc   l     ;; l = 05634127
  xor   l
  and   # $66
  xor   l     ;; a = 01234567
  ret
;code-no-next
1 1 Succubus:setters:in-out-args

;; reverse bits; high 8 bits are untouched
;; FIXME: inline this!
code: REV8  ( u -- u )
  pop   hl
  jr    # zx-word-do-rev8
;code-no-next
1 1 Succubus:setters:in-out-args


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; fast 16-bit integer square root
;; 92 bytes, 344-379 cycles (average 362)
;; v2 - 3 t-state optimization spotted by Russ McNulty
;; http://www.retroprogramming.com/2017/07/a-fast-z80-integer-square-root.html
;; k8: NOT TESTED YET!
code: SQRT16-FAST  ( u -- result )
\ sqrt16_hl:
  ld    a, h
  ld    de, # $B0C0
  add   a, e
  jr    c, # .sq7
  ld    a, h
  ld    d, # $F0
.sq7:
;; ----------
  add   a, d
  jr    nc, # .sq6
  res   5, d
  254 db,
.sq6:
  sub   d
  sra   d
;; ----------
  set   2, d
  add   a, d
  jr    nc, # .sq5
  res   3, d
  254 db,
.sq5:
  sub   d
  sra   d
;; ----------
  inc   d
  add   a, d
  jr    nc, # .sq4
  res   1, d
  254 db,
.sq4:
  sub   d
  sra   d
  ld    h, a
;; ----------
  add   hl, de
  jr    nc, # .sq3
  ld    e, # $40
  210 db,
.sq3:
  sbc   hl, de
  sra   d
  ld    a, e
  rra
;; ----------
  or    # $10
  ld    e, a
  add   hl, de
  jr    nc, # .sq2
  and   # $DF
  218 db,
.sq2:
  sbc   hl, de
  sra   d
  rra
;; ----------
  or    # $04
  ld    e, a
  add   hl, de
  jr    nc, # .sq1
  and   # $F7
  218 db,
.sq1:
  sbc   hl, de
  sra   d
  rra
;; ----------
  inc   a
  ld    e, a
  add   hl, de
  jr    nc, # .sq0
  and   # $FD
.sq0:
  sra   d
  rra
  cpl
  ;; done
  ld    l, a
  ld    h, # 0
;code
1 1 Succubus:setters:in-out-args


code: SQRT16-SMALL  ( u -- result )
;; original code
;; 34 bytes, 1005-1101 cycles (average 1053)
  \ pop   de
  ex    de, hl
  ld    bc, # $8000
  ld    h, c
  ld    l, c
.sqrloop:
  srl   b
  rr    c
  add   hl, bc
  ex    de, hl
  sbc   hl, de
  jr    c, # .sqrbit
  ex    de, hl
  add   hl, bc
  jr    # .sqrfi
.sqrbit:
  add   hl, de
  ex    de, hl
  or    a
  sbc   hl, bc
.sqrfi:
  srl   h
  rr    l
  srl   b
  rr    c
  jr    nc, # .sqrloop
  ;; done
;code
1 1 Succubus:setters:in-out-args


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; the optimiser will do The Right Thing with the following

: 1+  ( a -- a+1 )  1 + ; zx-inline
: 2+  ( a -- a+2 )  2 + ; zx-inline
: 4+  ( a -- a+4 )  4 + ; zx-inline
: 8+  ( a -- a+8 )  8 + ; zx-inline
: 16+  ( a -- a+16 )  16 + ; zx-inline
: 32+  ( a -- a+32 )  32 + ; zx-inline
: 64+  ( a -- a+64 )  64 + ; zx-inline
: 128+  ( a -- a+128 )  128 + ; zx-inline
: 256+  ( a -- a+256 )  256 + ; zx-inline
: 1-  ( a -- a-1 )  1 - ; zx-inline
: 2-  ( a -- a-2 )  2 - ; zx-inline
: 4-  ( a -- a-4 )  4 - ; zx-inline
: 8-  ( a -- a-8 )  8 - ; zx-inline
: 16-  ( a -- a-16 )  16 - ; zx-inline
: 32-  ( a -- a-32 )  32 - ; zx-inline
: 64-  ( a -- a-64 )  64 - ; zx-inline
: 128-  ( a -- a-128 )  128 - ; zx-inline
: 256-  ( a -- a-256 )  256 - ; zx-inline

: UNDER+1  ( a -- a+1 )  1 UNDER+ ; zx-inline
: UNDER+2  ( a -- a+2 )  2 UNDER+ ; zx-inline
: UNDER+4  ( a -- a+4 )  4 UNDER+ ; zx-inline
: UNDER+8  ( a -- a+8 )  8 UNDER+ ; zx-inline
: UNDER+16  ( a -- a+16 )  16 UNDER+ ; zx-inline
: UNDER+32  ( a -- a+32 )  32 UNDER+ ; zx-inline
: UNDER+64  ( a -- a+64 )  64 UNDER+ ; zx-inline
: UNDER+128  ( a -- a+128 )  128 UNDER+ ; zx-inline
: UNDER+256  ( a -- a+256 )  256 UNDER+ ; zx-inline
: UNDER-1  ( a -- a-1 )  1 UNDER- ; zx-inline
: UNDER-2  ( a -- a-2 )  2 UNDER- ; zx-inline
: UNDER-4  ( a -- a-4 )  4 UNDER- ; zx-inline
: UNDER-8  ( a -- a-8 )  8 UNDER- ; zx-inline
: UNDER-16  ( a -- a-16 )  16 UNDER- ; zx-inline
: UNDER-32  ( a -- a-32 )  32 UNDER- ; zx-inline
: UNDER-64  ( a -- a-64 )  64 UNDER- ; zx-inline
: UNDER-128  ( a -- a-128 )  128 UNDER- ; zx-inline
: UNDER-256  ( a -- a-256 )  256 UNDER- ; zx-inline

<zx-done>
