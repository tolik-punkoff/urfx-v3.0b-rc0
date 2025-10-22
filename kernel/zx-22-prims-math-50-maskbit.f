;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MASK? and BIT?
;; directly included from "zx-22-prims-math.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


primopt: (cgen-common-mask8:lit-code)  ( u8 lo-byte? )
  >r lo-byte
  dup 0?exit< 0 tos-r16 #->r16 >? ;; should never happen, but why not?
  tos-r16 r> ?< r16l->a || r16h->a >?
  dup and-a-c#
  << $01 of?v|| ;; ready to use boolean
     $02 of?v| rra |? ;; with the epologue: 4+4+7=15
     $04 of?v| rra rra |? ;; with the epologue: 4+4+4+7=19
     $08 of?v| rra rra rra |? ;; with the epologue: 4+4+4+4+7=23
     \ $10 of?v| rra rra rra rra |? ;; with the epologue: 4+4+4+4+4+7=27
     $20 of?v| rlca rlca rlca |? ;; with the epologue: 4+4+4+4+7=23
     $40 of?v| rlca rlca |? ;; with the epologue: 4+4+4+7=19
     $80 of?v| rlca |? ;; with the epologue: 4+4+7=15
  else| drop
    (*
    0 tos-r16 c#->r16h
    1 sub-a-c# ;; carry set if 0
    ccf        ;; carry set if !0
    tos-r16 r16h->a ;; A is 0
    adc-a-a    ;; 0:a=0; !0: a=1
    tos-r16 a->r16l
    ;; with the eplogue: 7+4+4+4+4+4=27
    *)
    0 tos-r16 #->r16
    cond:z jr-cc  ( .skip )
    tos-r16 inc-r16l
    jr-dest!  ;; .skip
    ;; 22/21
    exit
  >>
  ;; final part of the one-bit mask code
  tos-r16 a->r16l
  0 tos-r16 c#->r16h ;


<zx-system>
primitive: MASK8:LIT  ( au8 -- {au8&[bu8]}<>0 )
Succubus:setters:in-8bit
Succubus:setters:out-bool
:codegen-xasm
  ?curr-node-lit-value
  true (cgen-common-mask8:lit-code) ;

primitive: MASK8-HI:LIT  ( u -- {u&[bu8<<8]}<>0 )
Succubus:setters:out-bool
:codegen-xasm
  ?curr-node-lit-value lo-byte
  false (cgen-common-mask8:lit-code) ;

primitive: MASK:LIT  ( u -- {u&[bu]}<>0 )
Succubus:setters:out-bool
:codegen-xasm
  ?curr-node-lit-value lo-word
  dup hi-byte 0?exit< true (cgen-common-mask8:lit-code) >?
  dup lo-byte 0?exit< hi-byte false (cgen-common-mask8:lit-code) >?
  (*
    ld    a, l
    and   # lo
    ld    l, a
    ld    a, h
    and   # hi
    or    l
    ld    h, # 0
    sub   # 1   ;; carry set if 0
    ccf         ;; carry set if !0
    ld    a, h
    adc   a, a
    ld    l, a
    ;; 4+7+4+4+7+4+10+7+4+4+4+4=63

    ld    a, l
    and   # lo
    ld    a, h
    ld    hl, # 1
    jr    nz, # .skip
    and   # hi
    jr    nz, # .skip
    ld    l, h  ;; this leaves the flags intact
  .skip:
    ;; 4+7+4+10+12=37
    ;; 4+7+4+10+7+7+12=51
    ;; 4+7+4+10+7+7+7+4=50
  *)
  ;; low byte
  tos-r16 r16l->a
  dup lo-byte and-a-c#
  tos-r16 r16h->a
  1 tos-r16 #->r16
  cond:nz jr-cc   ( .skip )
  ;; high byte
  tos-r16 r16h->a
  swap hi-byte and-a-c#
  cond:nz jr-cc   ( .skip .skip )
  tos-r16 tos-r16 r16h->r16l
  ;; .skip
  jr-dest! jr-dest! ;
<zx-forth>


;; returns proper boolean
primitive: MASK8?  ( au8 bu8 -- {au8&bu8}<>0 )
Succubus:setters:in-8bit
Succubus:setters:out-bool
:codegen-xasm
  pop-non-tos-peephole
  (*
  0 non-tos-r16 c#->r16h
  non-tos-r16 tos-r16 r16h->r16h
  non-tos-r16 r16l->a
  tos-r16 and-a-r16l
  1 sub-a-c# ;; carry set if 0
  ccf        ;; carry set if !0
  non-tos-r16 r16h->a ;; A is 0
  adc-a-a    ;; 0:a=0; !0: a=1
  tos-r16 a->r16l ;
  ;; 7+4+4+4+7+4+4+4+4=42
  *)
  tos-r16 r16l->a
  non-tos-r16 and-a-r16l
  0 tos-r16 #->r16
  cond:z jr-cc  ( .skip )
  tos-r16 inc-r16l
  jr-dest!  ;; .skip
  ;; 4+4+10+12=30
  ;; 4+4+10+7+4=29
;

;; returns proper boolean
primitive: MASK?  ( a b -- {a&b}<>0 )
Succubus:setters:out-bool
:codegen-xasm
  pop-non-tos-peephole
  (*
  ;; low byte
  tos-r16 r16l->a
  non-tos-r16 and-a-r16l
  tos-r16 r16h->a
  1 tos-r16 #->r16
  cond:nz jr-cc   ( .skip )
  ;; high byte
  tos-r16 r16h->a
  non-tos-r16 and-a-r16h
  cond:nz jr-cc   ( .skip .skip )
  tos-r16 tos-r16 r16h->r16l
  ;; .skip
  jr-dest! jr-dest!
  ;; 4+4+4+10+12=34
  ;; 4+4+4+10+7+4+4+12=49
  ;; 4+4+4+10+7+4+4+7+4=48
  *)
  tos-r16 r16l->a
  non-tos-r16 and-a-r16l
  tos-r16 a->r16l
  tos-r16 r16h->a
  non-tos-r16 and-a-r16h
  tos-r16 a->r16h
  tos-r16 or-a-r16l
  cond:z jr-cc  ( patch-addr )
  1 tos-r16 #->r16
  jr-dest!
  ;; 4+4+4+4+4+4+4+12=40
  ;; 4+4+4+4+4+4+4+7+10=45
;

;; index is masked.
;; self-modifying code for speed and stable timings.
primitive: BIT8?  ( val idx -- bool )
Succubus:setters:in-8bit
Succubus:setters:out-bool
:codegen-xasm
  \ FIXME: optimise this!
  restore-tos-de-pop-hl
  e->a
  $07 and-a-c#
  rlca
  rlca
  rlca
  @105 or-a-c#  ;; BIT 0, L
  0 a->(nn)
  ;; patch instruction
  $here 1+ $here 2- zx-w!
  0 bit-l-n
  0 #->hl
  cond:z jr-cc  ( .skip )
  inc-l
  jr-dest!
  TOS-in-HL! ;
;; 4+7+4+4+$+7+13+8+10+12=50
;; 4+7+4+4+$+7+13+8+10+7+4=49
;; faster than the table

;; return 0 on out-of-range index
;; self-modifying code for speed and almost stable timings.
;; nope, using the table is slightly faster here.
code: BIT?  ( val idx -- bool )
  pop   de
  ;; HL: index
  ;; DE: value
  ld    a, h
  or    a
  ld    a, l
  ld    hl, # 0
  jr    nz, # .done
  cp    # 16
  jr    nc, # .done
  cp    # 8
  jr    c, # .low-bit
  sub   a, # 8
  ld    e, d
.low-bit:
  ld    bc, # bit-mask-table
  add   a, c
  ld    c, a
  ld    a, (bc)
  and   e
  jr    z, # .done
  inc   l
.done:
;code
2 1 Succubus:setters:in-out-args
Succubus:setters:out-bool
