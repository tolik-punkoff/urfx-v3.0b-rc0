;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; memory access primitives
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>

;; 2var: hi-word, lo-word; don't ask.

primitive: 2@  ( addr -- d-lo d-hi )
:codegen-xasm
  restore-tos-hl
  ;; hi
  (hl)->e
  inc-hl
  (hl)->d
  inc-hl
  ;; lo
  (hl)->c
  inc-hl
  (hl)->b
  push-bc
  TOS-in-DE! ;

primitive: 2!  ( d-lo d-hi addr )
:codegen-xasm
  pop-non-tos-peephole
  pop-bc-peephole
  restore-tos-hl
  ;; HL: addr; DE:hi
  ;; HL: addr; DE:hi; BC:lo
  ;; hi
  e->(hl)
  inc-hl
  d->(hl)
  inc-hl
  ;; lo
  c->(hl)
  inc-hl
  b->(hl)
  pop-tos ;


primitive: C@++  ( addr -- addr+1 b[addr] )
Succubus:setters:out-8bit
:codegen-xasm
  TOS-in-HL? ?<
    (hl)->e
    inc-hl
    push-hl
    0 c#->d
    TOS-in-DE!
  ||
    (tos)->a
    inc-tos
    push-tos
    a->tos
  >? ;
alias-for C@++ is COUNT  ( addr -- addr+1 b[addr] )

primitive: C@++/SWAP  ( addr -- b[addr] addr+1 )
:codegen-xasm
  TOS-in-HL? ?<
    (hl)->e
    inc-hl
    0 c#->d
    push-de
  ||
    (de)->a
    inc-de
    a->hl
    push-hl
  >? ;

primitive: C@--  ( addr -- addr-1 b[addr] )
Succubus:setters:out-8bit
:codegen-xasm
  TOS-in-HL? ?<
    (hl)->e
    dec-hl
    push-hl
    0 c#->d
    TOS-in-DE!
  ||
    (tos)->a
    dec-tos
    push-tos
    a->tos
  >? ;

primitive: ++C@  ( addr -- addr+1 b[addr+1] )
Succubus:setters:out-8bit
:codegen-xasm
  TOS-in-HL? ?<
    inc-hl
    (hl)->e
    push-hl
    0 c#->d
    TOS-in-DE!
  ||
    inc-tos
    (tos)->a
    push-tos
    a->tos
  >? ;

primitive: --C@  ( addr -- addr-1 b[addr-1] )
Succubus:setters:out-8bit
:codegen-xasm
  TOS-in-HL? ?<
    dec-hl
    (hl)->e
    push-hl
    0 c#->d
    TOS-in-DE!
  ||
    dec-tos
    (tos)->a
    push-tos
    a->tos
  >? ;

primitive: @++  ( addr -- addr+2 w[addr] )
:codegen-xasm
  restore-tos-hl
  non-tos-r16 (hl)->r16l
  inc-tos
  non-tos-r16 (hl)->r16h
  inc-tos
  push-tos
  TOS-invert! ;


primitive: +C!  ( value addr )
:codegen-xasm
  pop-non-tos-peephole
  (tos)->a
  non-tos-r16 add-a-r16l
  a->(tos)
  pop-tos ;
alias-for +C! is +!C

primitive: -C!  ( value addr )
:codegen-xasm
  pop-non-tos-peephole
  (tos)->a
  non-tos-r16 sub-a-r16l
  a->(tos)
  pop-tos ;
alias-for -C! is -!C


primitive: +!  ( value addr )
:codegen-xasm
  pop-non-tos-peephole
  (tos)->a
  non-tos-r16 add-a-r16l
  a->(tos)
  inc-tos
  (tos)->a
  non-tos-r16 adc-a-r16h
  a->(tos)
  pop-tos ;

primitive: -!  ( value addr )
:codegen-xasm
  pop-non-tos-peephole
  (tos)->a
  non-tos-r16 sub-a-r16l
  a->(tos)
  inc-tos
  (tos)->a
  non-tos-r16 sbc-a-r16h
  a->(tos)
  pop-tos ;

primitive: 1+!  ( addr )
:codegen-xasm
  restore-tos-hl
  inc-(hl)
  cond:nz jr-cc
  inc-hl
  inc-(hl)
  jr-dest!
  pop-tos ;

primitive: 1-!  ( addr )
:codegen-xasm
  restore-tos-hl
  (hl)->a
  1 sub-a-c#
  a->(hl)
  cond:nc jr-cc
  inc-hl
  dec-(hl)
  jr-dest!
  pop-tos ;

primitive: 1+C!  ( addr )
:codegen-xasm
  restore-tos-hl
  inc-(hl)
  pop-tos ;

primitive: 1-C!  ( addr )
:codegen-xasm
  restore-tos-hl
  dec-(hl)
  pop-tos ;

primitive: @  ( addr -- value )
:codegen-xasm
  restore-tos-hl
  (hl)->e
  inc-hl
  (hl)->d
  TOS-in-DE! ;

primitive: C@  ( addr -- byte )
Succubus:setters:out-8bit
:codegen-xasm
  TOS-in-HL? ?<
    (hl)->l
  ||
    (de)->a
    a->e
  >?
  0 c#->tosh ;

primitive: !  ( value addr )
:codegen-xasm
  pop-non-tos-peephole
  restore-tos-hl
  e->(hl)
  inc-hl
  d->(hl)
  pop-tos ;

primitive: SWAP!  ( addr value )
:codegen-xasm
  pop-non-tos-peephole
  restore-tos-de
  e->(hl)
  inc-hl
  d->(hl)
  pop-tos ;

primitive: SWAP!C  ( addr value )
:codegen-xasm
  pop-non-tos-peephole
  restore-tos-de
  e->(hl)
  pop-tos ;

primitive: C!  ( byte addr )
:codegen-xasm
  pop-non-tos-peephole
  restore-tos-hl
  e->(hl)
  pop-tos ;

primitive: C!++  ( byte addr -- addr+1 )
:codegen-xasm
  pop-non-tos-peephole
  restore-tos-hl
  e->(hl)
  inc-hl ;

primitive: SWAP-C!++  ( addr byte -- addr+1 )
:codegen-xasm
  pop-non-tos-peephole
  restore-tos-de
  e->(hl)
  inc-hl
  TOS-in-HL! ;

primitive: C!--  ( byte addr -- addr-1 )
:codegen-xasm
  pop-non-tos-peephole
  restore-tos-hl
  e->(hl)
  dec-hl ;

primitive: ++C!  ( byte addr -- addr+1 )
:codegen-xasm
  pop-non-tos-peephole
  restore-tos-hl
  inc-hl
  e->(hl) ;

;; push  hl
;; ld    hl, () {addr}
;; --C! (TOS: HL)
;; *** not generated yet ***
;; pop   de
;; dec   hl
;; ld    (hl), e
;; === NEW CODE ===
;; ex  de, hl
;; ld  hl, () {addr}
;; dec hl
;; ld  (hl), e
;; TOS-in-HL!
primopt: (cgen-opt-"--c!"-0)  ( -- success-flag )
  TOS-in-HL? not?exit&leave
  peep-pattern:[[
    push  hl
    ld    hl, () {addr}
  ]] peep-match not?exit&leave
  peep: {addr}
  peep-remove-instructions
  ex-de-hl
  (nn)->hl
  dec-hl
  e->(hl)
  true ;

;; push  de
;; ld    de, () {addr}
;; --C! (TOS: DE)
;; *** not generated yet ***
;; pop   hl
;; ex   de, hl
;; dec   hl
;; ld    (hl), e
;; === NEW CODE ===
;; ld  hl, () {addr}
;; dec hl
;; ld  (hl), e
;; TOS-in-HL!
primopt: (cgen-opt-"--c!"-1)  ( -- success-flag )
  TOS-in-DE? not?exit&leave
  peep-pattern:[[
    push  de
    ld    de, () {addr}
  ]] peep-match not?exit&leave
  peep: {addr}
  peep-remove-instructions
  (nn)->hl
  dec-hl
  e->(hl)
  TOS-in-HL!
  true ;

primitive: --C!  ( byte addr -- addr-1 )
:codegen-xasm
  (cgen-opt-"--c!"-0) ?exit
  (cgen-opt-"--c!"-1) ?exit
  pop-non-tos-peephole
  restore-tos-hl
  dec-hl
  e->(hl) ;

primitive: SWAP-C!  ( addr byte )
:codegen-xasm
  pop-non-tos-peephole
  restore-tos-de
  e->(hl)
  pop-tos ;

primitive: C!0  ( addr )
:codegen-xasm
  restore-tos-hl
  0 c#->(hl)
  pop-tos ;
alias-for C!0 is 0C!

primitive: C!1  ( addr )
:codegen-xasm
  restore-tos-hl
  1 c#->(hl)
  pop-tos ;
alias-for C!1 is 1C!

primitive: !1  ( addr )
:codegen-xasm
  restore-tos-hl
  1 c#->(hl)
  inc-hl
  0 c#->(hl)
  pop-tos ;
alias-for C!1 is 1C!
alias-for !1 is ON
alias-for !1 is 1!

primitive: !0  ( addr )
:codegen-xasm
  xor-a
  a->(tos)
  inc-tos
  a->(tos)
  pop-tos ;
alias-for !0 is OFF
alias-for !0 is 0!


primitive: AND!  ( val addr )
:codegen-xasm
  pop-bc-peephole
  (tos)->a
  and-c
  a->(tos)
  inc-tos
  (tos)->a
  and-b
  a->(tos)
  pop-tos ;

primitive: ~AND!  ( val addr )
:codegen-xasm
  pop-bc-peephole
  restore-tos-hl
  c->a
  cpl
  and-(hl)
  a->(hl)
  b->a
  cpl
  and-(hl)
  a->(hl)
  pop-tos ;

primitive: OR!  ( val addr )
:codegen-xasm
  pop-bc-peephole
  (tos)->a
  or-c
  a->(tos)
  inc-tos
  (tos)->a
  or-b
  a->(tos)
  pop-tos ;

primitive: XOR!  ( val addr )
:codegen-xasm
  pop-bc-peephole
  (tos)->a
  xor-c
  a->(tos)
  inc-tos
  (tos)->a
  xor-b
  a->(tos)
  pop-tos ;


;; Forth version is 14 bytes, this one is 8 (or even 7)
primitive: AND!C  ( val addr )
:codegen-xasm
  pop-bc-peephole
  (tos)->a
  xor-c
  a->(tos)
  pop-tos ;

primitive: ~AND!C  ( val addr )
:codegen-xasm
  pop-bc-peephole
  restore-tos-hl
  c->a
  cpl
  and-(hl)
  a->(hl)
  pop-tos ;

primitive: OR!C  ( val addr )
:codegen-xasm
  pop-bc-peephole
  (tos)->a
  or-c
  a->(tos)
  pop-tos ;

primitive: XOR!C  ( val addr )
:codegen-xasm
  pop-bc-peephole
  (tos)->a
  xor-c
  a->(tos)
  pop-tos ;

primitive: TOGGLE  ( addr byte )
:codegen-xasm
  pop-bc-peephole
  (bc)->a
  tos-r16 xor-a-r16l
  a->(bc)
  pop-tos ;


<zx-done>
