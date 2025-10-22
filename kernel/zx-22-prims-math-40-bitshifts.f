;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; shifts and shift-alikes
;; directly included from "zx-22-prims-math.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; multiplication and division converted to shifts

primitive: 2*  ( n -- n*2 )
:codegen-xasm
  restore-tos-hl
  add-hl-hl ;

;; why not?
primitive: 3*  ( n -- n*3 )
:codegen-xasm
  TOS-in-HL? ?< hl->de || de->hl >?
  add-hl-hl
  add-hl-de
  TOS-in-HL! ;

primitive: 4*  ( n -- n*4 )
:codegen-xasm
  restore-tos-hl
  add-hl-hl
  add-hl-hl ;

primitive: 8*  ( n -- n*8 )
:codegen-xasm
  restore-tos-hl
  add-hl-hl
  add-hl-hl
  add-hl-hl ;

\ TODO: 8-bit optimisation?
primitive: 16*  ( n -- n*16 )
:codegen-xasm
  restore-tos-hl
  add-hl-hl
  add-hl-hl
  add-hl-hl
  add-hl-hl ;

\ TODO: 8-bit optimisation?
primitive: 32*  ( n -- n*32 )
:codegen-xasm
  restore-tos-hl
  add-hl-hl
  add-hl-hl
  add-hl-hl
  add-hl-hl
  add-hl-hl ;

primitive: 64*  ( n -- n*64 )
:codegen-xasm
  ;; add: 11*6=66
  ;; 6 shl
  \ 15 14 13 12 11 10 9 8  7 6 5 4 3 2 1 0
  \  9  8  7  6  5  4 3 2  1 0 . . . . . .
  ;; 4+(8+8+4)*2+4+4=52
  xor-a-a
  tos-r16 rr-r16h  tos-r16 rr-r16l  rra
  tos-r16 rr-r16h  tos-r16 rr-r16l  rra
  tos-r16 tos-r16 r16l->r16h
  tos-r16 a->r16l ;

primitive: 128*  ( n -- n*128 )
:codegen-xasm
  ;; add: 11*7=77
  ;; 7 shl
  (*
  \ 15 14 13 12 11 10 9 8  7 6 5 4 3 2 1 0
  \  8  7  6  5  4  3 2 1  0 . . . . . . .
  ;; 4+(8+8+4)*1+4+4=32
  *)
  xor-a-a
  tos-r16 rr-r16h  tos-r16 rr-r16l  rra
  tos-r16 tos-r16 r16l->r16h
  tos-r16 a->r16l ;

primitive: 256*  ( n -- n*256 )
:codegen-xasm
  tos-r16 tos-r16 r16l->r16h
  0 tos-r16 c#->r16l ;


primitive: 2*C  ( u8 -- u8*2 )
:codegen-xasm
  tos-r16 sla-r16l ;

primitive: 4*C  ( u8 -- u8*4 )
:codegen-xasm
  tos-r16 sla-r16l
  tos-r16 sla-r16l ;

primitive: 8*C  ( u8 -- u8*8 )
:codegen-xasm
  tos-r16 sla-r16l
  tos-r16 sla-r16l
  tos-r16 sla-r16l ;

\ TODO: 8-bit optimisation?
primitive: 16*C  ( u8 -- u8*16 )
:codegen-xasm
  ;; this is 1ts faster than SLA
  tos-r16 r16l->a
  rla
  rla
  rla
  rla
  $F0 and-a-c#
  tos-r16 a->r16l ;

\ TODO: 8-bit optimisation?
primitive: 32*C  ( u8 -- u8*32 )
:codegen-xasm
  \ 7 6 5 4 3 2 1 0
  \ 2 1 0 . . . . .
  tos-r16 r16l->a
  rrca
  rrca
  rrca
  $E0 and-a-c#
  tos-r16 a->r16l ;

primitive: 64*C  ( u8 -- u8*64 )
:codegen-xasm
  \ 7 6 5 4 3 2 1 0
  \ 1 0 . . . . . .
  tos-r16 r16l->a
  rrca
  rrca
  $C0 and-a-c#
  tos-r16 a->r16l ;

primitive: 128*C  ( u8 -- u8*128 )
:codegen-xasm
  \ 7 6 5 4 3 2 1 0
  \ 0 . . . . . . .
  tos-r16 r16l->a
  rrca
  $80 and-a-c#
  tos-r16 a->r16l ;


;; high byte is not changed
primitive: 2U/C  ( u8 -- u8/2 )
:codegen-xasm
  tos-r16 srl-r16l ;

;; high byte is not changed
primitive: 4U/C  ( u8 -- u8/4 )
:codegen-xasm
  tos-r16 srl-r16l
  tos-r16 srl-r16l ;

;; high byte is not changed
primitive: 8U/C  ( u8 -- u8/8 )
:codegen-xasm
  tos-r16 srl-r16l
  tos-r16 srl-r16l
  tos-r16 srl-r16l ;

;; high byte is not changed
primitive: 16U/C  ( u8 -- u8/16 )
:codegen-xasm
  tos-r16 r16l->a
  rra
  rra
  rra
  rra
  $0F and-a-c#
  tos-r16 a->r16l ;

;; high byte is not changed
primitive: 32U/C  ( u8 -- u8/32 )
:codegen-xasm
  tos-r16 r16l->a
  rlca
  rlca
  rlca
  $07 and-a-c#
  tos-r16 a->r16l ;

;; high byte is not changed
primitive: 64U/C  ( u8 -- u8/64 )
:codegen-xasm
  tos-r16 r16l->a
  rlca
  rlca
  $03 and-a-c#
  tos-r16 a->r16l ;

;; high byte is not changed
primitive: 128U/C  ( u8 -- u8/128 )
:codegen-xasm
  tos-r16 r16l->a
  rlca
  $01 and-a-c#
  tos-r16 a->r16l ;


primitive: 2U/  ( u -- u/2 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?exit<
    tos-r16 srl-r16l
  >?
  tos-r16 srl-r16h  tos-r16 rr-r16l ;

primitive: 4U/  ( u -- u/4 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?exit<
    tos-r16 srl-r16l
    tos-r16 srl-r16l
  >?
  tos-r16 srl-r16h  tos-r16 rr-r16l
  tos-r16 srl-r16h  tos-r16 rr-r16l ;

primitive: 8U/  ( u -- u/8 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?<
    tos-r16 r16l->a
    rra
    rra
    rra
    $1F and-a-c#
  ||
    ;; 4ts faster than simple shifts
    tos-r16 r16l->a
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
  >?
  tos-r16 a->r16l ;

primitive: 16U/  ( u -- u/16 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?<
    tos-r16 r16l->a
    rra
    rra
    rra
    rra
    $0F and-a-c#
  ||
    ;; 8ts faster than simple shifts
    tos-r16 r16l->a
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
  >?
  tos-r16 a->r16l ;

\ FIXME: this could be optimised, i believe
primitive: 32U/  ( u -- u/32 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?<
    tos-r16 r16l->a
    \ 7 6 5 4 3 2 1 0
    \           7 6 5
    ;; 1ts faster than 4 shifts
    rlca rlca rlca
    $07 and-a-c#
  ||
    ;; 12ts faster than simple shifts
    tos-r16 r16l->a
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
  >?
  tos-r16 a->r16l ;

\ FIXME: this could be optimised, i believe
primitive: 64U/  ( u -- u/64 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?<
    tos-r16 r16l->a
    \ 7 6 5 4 3 2 1 0
    \             7 6
    ;; 5ts faster than 5 shifts
    rlca rlca
    $03 and-a-c#
  ||
    ;; 16ts faster than simple shifts
    tos-r16 r16l->a
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
  >?
  tos-r16 a->r16l ;

\ FIXME: this could be optimised, i believe
primitive: 128U/  ( u -- u/128 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?<
    tos-r16 r16l->a
    \ 7 6 5 4 3 2 1 0
    \               7
    ;; 13ts faster than 6 shifts
    rlca
    $01 and-a-c#
  ||
    ;; 20ts faster than simple shifts
    tos-r16 r16l->a
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
    tos-r16 srl-r16h  rra
  >?
  tos-r16 a->r16l ;


primitive: 2/  ( n -- n/2 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?exit<
    tos-r16 srl-r16l
  >?
  (cgen-prev-load-tosr16h-#255?) ?exit<
    scf tos-r16 rr-r16l
  >?
  tos-r16 sra-r16h  tos-r16 rr-r16l ;

primitive: 4/  ( n -- n/4 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?exit<
    tos-r16 srl-r16l
    tos-r16 srl-r16l
  >?
  (cgen-prev-load-tosr16h-#255?) ?exit<
    scf tos-r16 rr-r16l
    tos-r16 sra-r16l
  >?
  tos-r16 sra-r16h  tos-r16 rr-r16l
  tos-r16 sra-r16h  tos-r16 rr-r16l ;

primitive: 8/  ( n -- n/8 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?exit<
    tos-r16 r16l->a
    rra
    rra
    rra
    $1F and-a-c#
    tos-r16 a->r16l >?
  (cgen-prev-load-tosr16h-#255?) ?exit<
    tos-r16 r16l->a
    rra
    rra
    rra
    $E0 or-a-c#
    tos-r16 a->r16l >?
  ;; 4ts faster than simple shifts
  tos-r16 r16l->a
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 a->r16l ;

primitive: 16/  ( n -- n/16 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?exit<
    tos-r16 r16l->a
    rra
    rra
    rra
    rra
    $0F and-a-c#
    tos-r16 a->r16l >?
  (cgen-prev-load-tosr16h-#255?) ?exit<
    tos-r16 r16l->a
    rra
    rra
    rra
    rra
    $F0 or-a-c#
    tos-r16 a->r16l >?
  ;; 8ts faster than simple shifts
  tos-r16 r16l->a
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 a->r16l ;

\ FIXME: this could be optimised, i believe
primitive: 32/  ( n -- n/32 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?exit<
    tos-r16 r16l->a
    \ 7 6 5 4 3 2 1 0
    \           7 6 5
    ;; 1ts faster than 4 shifts
    rlca rlca rlca
    $07 and-a-c#
    tos-r16 a->r16l >?
  (cgen-prev-load-tosr16h-#255?) ?exit<
    tos-r16 r16l->a
    \ 7 6 5 4 3 2 1 0
    \           7 6 5
    ;; 1ts faster than 4 shifts
    rlca rlca rlca
    $F8 or-a-c#
    tos-r16 a->r16l >?
  ;; 12ts faster than simple shifts
  tos-r16 r16l->a
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 a->r16l ;

\ FIXME: this could be optimised, i believe
primitive: 64/  ( n -- n/64 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?exit<
    tos-r16 r16l->a
    \ 7 6 5 4 3 2 1 0
    \             7 6
    rlca rlca
    $03 and-a-c#
    tos-r16 a->r16l >?
  (cgen-prev-load-tosr16h-#255?) ?exit<
    tos-r16 r16l->a
    \ 7 6 5 4 3 2 1 0
    \             7 6
    rlca rlca
    $FC or-a-c#
    tos-r16 a->r16l >?
  ;; 16ts faster than simple shifts
  tos-r16 r16l->a
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 a->r16l ;

\ FIXME: this could be optimised, i believe
primitive: 128/  ( n -- n/128 )
:codegen-xasm
  (cgen-prev-load-tosr16h-#0?) ?exit<
    tos-r16 r16l->a
    \ 7 6 5 4 3 2 1 0
    \               7
    rlca
    $01 and-a-c#
    tos-r16 a->r16l >?
  (cgen-prev-load-tosr16h-#255?) ?exit<
    tos-r16 r16l->a
    \ 7 6 5 4 3 2 1 0
    \               7
    rlca
    $FE or-a-c#
    tos-r16 a->r16l >?
  ;; 20ts faster than simple shifts
  tos-r16 r16l->a
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 sra-r16h  rra
  tos-r16 a->r16l ;

primitive: 256/  ( n -- n/256 )
:codegen-xasm
  tos-r16 tos-r16 r16h->r16l
  tos-r16 rl-r16h
  sbc-a-a
  tos-r16 a->r16h ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; real shifts

code: SHL  ( a count -- a<<count )
  ld    a, l
  pop   hl
  and   # 15
  jr    z, # .done  ;; rarely taken
  ld    b, a
  sub   a, # 8
  jr    c, # .loop
  ld    h, l
  ld    l, # 0
  jr    z, # .done
  ld    b, a
.loop:
  add   hl, hl
  djnz  # .loop
.done:
;code
2 1 Succubus:setters:in-out-args
alias-for SHL is LSHIFT

code: SHR  ( a count -- a>>count )
  ld    a, l
  pop   hl
  and   # 15
  jr    z, # .done  ;; rarely taken
  ld    b, a
  sub   a, # 8
  jr    c, # .do-it
  ld    l, h
  ld    h, # 0
  jr    z, # .done
  ld    b, a
.do-it:
  ld    a, l
.loop:
  srl   h
  rra
  djnz  # .loop
  ld    l, a
.done:
;code
2 1 Succubus:setters:in-out-args
alias-for SHR is RSHIFT

\ FIXME: optimise this!
code: SAR  ( a count -- a>>count )
  ld    a, l
  pop   hl
  and   # 15
  jr    z, # .done  ;; rarely taken
  ld    b, a
  ld    a, l
.loop:
  sra   h
  rra
  djnz  # .loop
  ld    l, a
.done:
;code
2 1 Succubus:setters:in-out-args
alias-for SAR is ARSHIFT

code: ROL  ( a count -- a<r<count )
  ld    a, l
  pop   hl
  and   # 15
  jr    z, # .done  ;; rarely taken
  ld    b, a
  sub   a, # 8
  jr    c, # .do-it
  ld    e, l
  ld    l, h
  ld    h, e
  jr    z, # .done
  ld    b, a
.do-it:
  ld    a, l
.loop:
  add   hl, hl
  rla
  djnz  # .loop
  ld    l,a
.done:
;code
2 1 Succubus:setters:in-out-args

\ : ROR  ( a count -- a>r>count )  NEGATE ROL ;
code: ROR  ( a count -- a>r>count )
  ld    a, l
  pop   hl
  and   # 15
  jr    z, # .done  ;; rarely taken
  ld    b, a
  sub   a, # 8
  jr    c, # .do-it
  ld    e, l
  ld    l, h
  ld    h, e
  jr    z, # .done
  ld    b, a
.do-it:
  ld    a, h
.loop:
  srl   h
  rr    l
  rra
  djnz  # .loop
  ld    h, a
.done:
;code
2 1 Succubus:setters:in-out-args

code: ROL8  ( a count -- a<r<count )
  ld    a, l
  pop   hl
  and   # 7
  jr    z, # .done  ;; rarely taken
  ld    b, a
  ld    a, l
.loop:
  rlca
  djnz  # .loop
  ld    l, a
.done:
;code
2 1 Succubus:setters:in-out-args

\ : ROR8  ( a count -- a>r>count )  NEGATE ROL8 ;
code: ROR8  ( a count -- a>r>count )
  ld    a, l
  pop   hl
  and   # 7
  jr    z, # .done  ;; rarely taken
  ld    b, a
  ld    a, l
.loop:
  rrca
  djnz  # .loop
  ld    l, a
.done:
;code
2 1 Succubus:setters:in-out-args
