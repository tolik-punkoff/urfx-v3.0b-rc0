;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; comparisons with zero
;; directly included from "zx-22-prims-math.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; exit: zero flag is set if a<>0 (because the result is 0)
;; exit: zero flag is reset if a=0 (because the result is 1)
primitive: 0=  ( a -- a=0? )
Succubus:setters:out-bool
:codegen-xasm
  ;; was previous instruction generated a proper boolean?
  (cgen-prev-out-bool?) ?exit<
    ;; yes, just invert it
    stat-bool-optim:1+!
    (cgen-gen-ld-tosr16l-a-strict-8bit?) ?<
      1 xor-a-c#
    ||
      tos-r16 r16l->a
    >?
    a->tos
  >?
  ;; prev is not a bool
  (cgen-gen-ld-tosr16l-a-strict-8bit?) ?<
    or-a-a
  ||
    tos-r16 r16l->a
    tos-r16 or-a-r16h
  >?
  1 sub-a-c#  ;; carry:A=0; no-carry:A!=0
  0 c#->a
  tos-r16 a->r16h
  adc-a-a
  tos-r16 a->r16l ;
alias-for 0= is NOT  ( a -- a=0? )


;; exit: zero flag is set if a=0 (because the result is 0)
;; exit: zero flag is reset if a<>0 (because the result is 1)
primitive: 0<>  ( a -- a<>0? )
Succubus:setters:out-bool
:codegen-xasm
  (* checked in IR optimiser
  ;; was previous instruction generated a proper boolean?
  (cgen-prev-out-bool?) ?exit<
    ;; yes, there is nothing to do
    stat-bool-optim:1+!
  >?
  *)
  ;; prev is not a bool
  (cgen-gen-ld-tosr16l-a-strict-8bit?) ?<
    or-a-a
  ||
    tos-r16 r16l->a
    tos-r16 or-a-r16h
  >?
  1 sub-a-c#  ;; carry:A=0; no-carry:A!=0
  ccf
  0 c#->a
  tos-r16 a->r16h
  adc-a-a
  tos-r16 a->r16l ;


;; exit: zero flag is set if a>=0 (because the result is 0)
;; exit: zero flag is reset if a<0 (because the result is 1)
primitive: 0<  ( a -- a<0? )
Succubus:setters:out-bool
:codegen-xasm
  (cgen-gen-ld-tosr16l-a-strict-8bit?) ?<
    (cgen-remove-ld-a)
    xor-a-a
  ||
    xor-a
    tos-r16 rl-r16h
    tos-r16 a->r16h
    adc-a-a
    tos-r16 a->r16l
  >? ;


;; exit: zero flag is set if a<0 (because the result is 0)
;; exit: zero flag is reset if a>=0 (because the result is 1)
primitive: 0>=  ( a -- a>0? )
Succubus:setters:out-bool
:codegen-xasm
  (cgen-gen-ld-tosr16l-a-strict-8bit?) ?<
    (cgen-remove-ld-a)
    xor-a-a
  ||
    xor-a
    tos-r16 rl-r16h
    tos-r16 a->r16h
    ;; carry set if <0
    ccf
    adc-a-a
    tos-r16 a->r16l
  >? ;


;; exit: zero flag is set if a<=0 (because the result is 0)
;; exit: zero flag is reset if a>0 (because the result is 1)
;; smaller than the Forth version (and faster)
primitive: 0>  ( a -- a>=0? )
Succubus:setters:out-bool
:codegen-xasm
  ;; by DW0RKiN & k8
  ;; 4+6+4+4+4+7+4+4+4=41
  tos-r16 r16h->a   ;; save sign
  tos-r16 dec-r16   ;; zero to negative
  tos-r16 or-a-r16h
  rla               ;; carry:<=0; no-carry:>0
  ccf               ;; carry:>0; no-carry:<=0
  0 c#->a
  tos-r16 a->r16h
  adc-a-a
  tos-r16 a->r16l ;


;; exit: zero flag is set if a>0 (because the result is 0)
;; exit: zero flag is reset if a<=0 (because the result is 1)
primitive: 0<=  ( a -- a>=0? )
Succubus:setters:out-bool
:codegen-xasm
  ;; by DW0RKiN & k8
  ;; 4+6+4+4+7+4+4+4=37
  tos-r16 r16h->a   ;; save sign
  tos-r16 dec-r16   ;; zero to negative
  tos-r16 or-a-r16h
  rla               ;; carry:<=0; no-carry:>0
  0 c#->a
  tos-r16 a->r16h
  adc-a-a
  tos-r16 a->r16l ;
