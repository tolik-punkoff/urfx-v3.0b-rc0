;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; unsigned numeric comparisons
;; directly included from "zx-22-prims-math.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


\ FIXME: optimise this!
primitive: U<  ( ua ub -- ua<ub? )
Succubus:setters:out-bool
:codegen-xasm
  restore-tos-de-pop-hl
  TOS-in-HL!
  xor-a
  sbc-hl-de
  a->h
  adc-a-a
  a->l ;


\ FIXME: optimise this!
primitive: U>  ( ua ub -- ua>ub? )
Succubus:setters:out-bool
:codegen-xasm
  restore-tos-hl-pop-de
  xor-a
  sbc-hl-de
  a->h
  adc-a-a
  a->l ;


\ FIXME: optimise this!
primitive: U>=  ( ua ub -- ua>=ub? )
Succubus:setters:out-bool
:codegen-xasm
  restore-tos-de-pop-hl
  TOS-in-HL!
  ;; HL: a; DE: b
  xor-a
  sbc-hl-de
  ;; carry:a<b; no-carry:a>=b
  a->h
  ccf
  adc-a-a
  a->l ;


\ FIXME: optimise this!
primitive: U<=  ( ua ub -- ua<=ub? )
Succubus:setters:out-bool
:codegen-xasm
  restore-tos-hl-pop-de
  ;; HL: b; DE: a
  xor-a
  sbc-hl-de
  ;; carry:a>b; no-carry:a<=b
  a->h
  ccf
  adc-a-a
  a->l ;
