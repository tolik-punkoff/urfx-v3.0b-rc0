;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; signed numeric comparisons
;; directly included from "zx-22-prims-math.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


\ FIXME: optimise this!
primitive: =  ( a b -- a=b? )
Succubus:setters:out-bool
:codegen-xasm
  pop-non-tos-peephole
  xor-a
  sbc-hl-de
  tos-r16 a->r16h
  tos-r16 a->r16l
  cond:nz jr-cc
  tos-r16 inc-r16l
  jr-dest! ;


\ FIXME: optimise this!
primitive: <>  ( a b -- a<>b? )
Succubus:setters:out-bool
:codegen-xasm
  pop-non-tos-peephole
  xor-a
  sbc-hl-de
  tos-r16 a->r16h
  tos-r16 a->r16l
  cond:z jr-cc
  tos-r16 inc-r16l
  jr-dest! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; signed numeric comparisons

\ FIXME: optimise this!
primitive: <  ( a b -- a<b? )
Succubus:setters:out-bool
:codegen-xasm
  ;; a-b: positive if a>=b; negative if a<b
  pop-non-tos-peephole
  TOS-in-DE? not?< ex-de-hl >?
  xor-a-a
  sbc-hl-de
  TOS-in-HL!
  rl-h
  a->h
  rla
  a->l ;


\ FIXME: optimise this!
primitive: >  ( a b -- a>b? )
Succubus:setters:out-bool
:codegen-xasm
  ;; b-a: positive if a<=b; negative if a>b
  pop-non-tos-peephole
  TOS-in-HL? not?< ex-de-hl >?
  xor-a-a
  sbc-hl-de
  TOS-in-HL!
  rl-h
  a->h
  rla
  a->l ;


\ FIXME: optimise this!
primitive: >=  ( a b -- a>=b? )
Succubus:setters:out-bool
:codegen-xasm
  ;; a-b: positive if a>=b; negative if a<b
  pop-non-tos-peephole
  TOS-in-DE? not?< ex-de-hl >?
  xor-a-a
  sbc-hl-de
  TOS-in-HL!
  rl-h
  a->h
  ccf
  rla
  a->l ;


\ FIXME: optimise this!
primitive: <=  ( a b -- a<=b? )
Succubus:setters:out-bool
:codegen-xasm
  ;; b-a: positive if a<=b; negative if a>b
  pop-non-tos-peephole
  TOS-in-HL? not?< ex-de-hl >?
  xor-a-a
  sbc-hl-de
  TOS-in-HL!
  rl-h
  a->h
  ccf
  rla
  a->l ;
