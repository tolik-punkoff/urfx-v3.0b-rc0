;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; multiply and divide primitives
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; this is unrolled magic. DO NOT TOUCH!
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>

primitive: 10U/MOD  ( u -- quot rem )
:codegen-xasm
  restore-tos-hl
  ;;Inputs:
  ;;     HL
  ;;Outputs:
  ;;     HL is the quotient
  ;;     A is the remainder
  ;;     DE is not changed
  ;;     BC is 10
  $0D0A #->bc
  xor-a-a
  add-hl-hl  rla
  add-hl-hl  rla
  add-hl-hl  rla
  $here ;; loop label
  add-hl-hl  rla
  cp-a-c
  cond:c jr-cc
  sub-a-c
  inc-l
  jr-dest!
  djnz-#
  push-hl
  TOS-in-HL!
  a->tos ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; for 32-bit doubles, rarely used

code: UUD*  ( u1 u2 -- ud )
  \ pop   de
  \ pop   hl
  ex    de, hl
  pop   hl
  \ push  bc
  ld    b, h
  ld    a, l
  call  # .do-uud-small
  push  hl
  ld    h, a
  ld    a, b
  ld    b, h
  call  # .do-uud-small
  pop   de
  ld    c, d
  add   hl, bc
  adc   a, # 0
  ld    d, l
  ld    l, h
  ld    h, a
  \ pop   bc
  \ next-push-de-hl
  push  de
  next
.do-uud-small:
  ld    hl, # 0
  ld    c, # 8
.loop:
  add   hl, hl
  rla
  jr    nc, # .skip-add
  add   hl, de
  adc   a, # 0
.skip-add:
  dec   c
  jp    nz, # .loop
  ret
;code-no-next
2 2 Succubus:setters:in-out-args

;; stupid result order!
\ FIXME: simplify stack operations! no need to save BC.
code: UDU/MOD  ( ud u1 -- u-rem u-quot )
  push  hl  ;; ooph...
  ld    hl, # 4
  add   hl, sp
  ld    e, (hl)
  ld    (hl), c
  inc   hl
  ld    d, (hl)
  ld    (hl), b
  pop   bc
  pop   hl
  ld    a, l
  sub   c
  ld    a, h
  sbc   a, b
  jr    c, # .l60a0h
  ld    hl, # -1
  ld    de, hl
  jr    # .l60c0h
.l60a0h:
  ld    a, # 16
.l60a2h:
  add   hl, hl
  rla
  ex    de, hl
  add   hl, hl
  jr    nc, # .skip-inc
  inc   de
  or    a
.skip-inc:
  ex    de, hl
  rra
  push  af
  jr    nc, # .l60b4h
  and   l
  sbc   hl, bc
  jr    # .l60bbh
.l60b4h:
  or    a
  sbc   hl, bc
  jr    nc, # .l60bbh
  add   hl, bc
  dec   de
.l60bbh:
  inc   de
  pop   af
  dec   a
  jr    nz, # .l60a2h
.l60c0h:
  pop   bc
  push  hl
  \ push  de
  ex    de, hl
;code
2 2 Succubus:setters:in-out-args


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; faster 16-bit mul and div

;; fast 16-bit unsigned multiply.
;; uses AF'.
code: U* ( ua ub -- ua*ub )
  \ pop   de
  ex    de, hl
  pop   hl
  call  # .vmx-umul-hl-de
  next

.vmx-umul-hl-de:
  ld    a, h
  or    a
  jr    z, # .umul-hl-8
  ;; HL is 16 bit, check DE
  ld    a, d
  or    a
  jr    z, # .umul-de-8

  ld    a, l
  or    a
  jr    z, # .umul-hl-l0

  ld    a, e
  or    a
  jr    z, # .umul-de-e0

  ;; both values are 16 bit
  \ push  bc
;; Multiply 16-bit values (with 16-bit result)
;; In: Multiply HL with DE
;; Out: HL = result
.umul-16-16-16:
  ld    a, h
  ld    c, l
  call  # .umul-16-16-32-unroll-8
  call  # .umul-16-16-32-unroll-8
  \ pop   bc
  \ ex    de, hl
  \ jp    # vmf-prim-next
  ret

.umul-de-8:
  ex    de, hl
.umul-hl-8:
  ld    a, l
  ld    l, h      ;; H is 0 here
  \ call  # .umul-8-16-16
  \ ret

;; Multiply 8-bit value with a 16-bit value
;; In: Multiply A with DE
;; Out: HL = result
.umul-8-16-16:
 OPT-16BIT-MUL/DIV-UNROLLED? [IF]
  ;; 1
  add   hl, hl
  add   a, a
  jr    nc, # $ 3 +
  add   hl, de
  ;; 2
  add   hl, hl
  add   a, a
  jr    nc, # $ 3 +
  add   hl, de
  ;; 3
  add   hl, hl
  add   a, a
  jr    nc, # $ 3 +
  add   hl, de
  ;; 4
  add   hl, hl
  add   a, a
  jr    nc, # $ 3 +
  add   hl, de
  ;; 5
  add   hl, hl
  add   a, a
  jr    nc, # $ 3 +
  add   hl, de
  ;; 6
  add   hl, hl
  add   a, a
  jr    nc, # $ 3 +
  add   hl, de
  ;; 7
  add   hl, hl
  add   a, a
  jr    nc, # $ 3 +
  add   hl, de
  ;; 8
  add   hl, hl
  add   a, a
  ret   nc
  add   hl, de
 [ELSE]
  \ push  bc
  ld    b, # 7
.loop-mul8:
  add   hl, hl
  add   a, a
  jr    nc, # $ 3 +
  add   hl, de
  djnz  # .loop-mul8
  \ pop   bc
  ;; 8
  add   hl, hl
  add   a, a
  ret   nc
  add   hl, de
 [ENDIF]
  ret

.umul-de-e0:
  ex    de, hl
.umul-hl-l0:
  ld    a, h
  ld    h, l    ;; L is 0 here
  call  # .umul-8-16-16
  ld    h, l
  ld    l, # 0
  ret

.umul-16-16-32-unroll-8:
 OPT-16BIT-MUL/DIV-UNROLLED? [IF]
  ;; 1
  add   hl, hl
  sla   c
  rla
  jr    nc, # $ 3 +
  add   hl, de
  ;; 2
  add   hl, hl
  sla   c
  rla
  jr    nc, # $ 3 +
  add   hl, de
  ;; 3
  add   hl, hl
  sla   c
  rla
  jr    nc, # $ 3 +
  add   hl, de
  ;; 4
  add   hl, hl
  sla   c
  rla
  jr    nc, # $ 3 +
  add   hl, de
  ;; 5
  add   hl, hl
  sla   c
  rla
  jr    nc, # $ 3 +
  add   hl, de
  ;; 6
  add   hl, hl
  sla   c
  rla
  jr    nc, # $ 3 +
  add   hl, de
  ;; 7
  add   hl, hl
  sla   c
  rla
  jr    nc, # $ 3 +
  add   hl, de
  ;; 8
  add   hl, hl
  sla   c
  rla
  ret   nc
  add   hl, de
 [ELSE]
  ex    af, afx
  ld    a, b
  ex    af, afx
  ld    b, # 7
.loop-div16:
  add   hl, hl
  sla   c
  rla
  jr    nc, # $ 3 +
  add   hl, de
  djnz  # .loop-div16
  ex    af, afx
  ld    b, a
  ex    af, afx
  ;; 8
  add   hl, hl
  sla   c
  rla
  ret   nc
  add   hl, de
 [ENDIF]
  ret
;code-no-next
2 1 Succubus:setters:in-out-args


;; fast 16-bit unsigned division.
;; doesn't use alternate registers.
;; proper result order, but different from all other "/MOD" words. sigh.
code: UU/MOD  ( ua ub -- ua/ub ua%ub )
  ex    de, hl
  pop   hl
  ;; HL=a
  ;; DE=b
  call  # vmx-do-udivmod
  ;; HL=remainder
  ;; CA=quotient
  ld    d, c
  ld    e, a
  \ pop   bc
  \ next-push-de-hl
  push  de
  next

;; in:
;;   HL=a
;;   DE=b
;; out:
;;   CA=quotient
;;   HL=remainder
vmx-do-udivmod:
  \ ld    a, h
  \ or    l
  \ jr    z, # vmx-do-udivmod-0-hl
  ld    a, d
  or    e
  jr    z, # vmx-do-udivmod-0-de

  ld    bc, hl
  ld    hl, # 0
  ld    a, b
  call  # vmx-udiv-part
  ld    b, a
  ld    a, c
  ld    c, b
  call  # vmx-udiv-part
  \ ld    b, c
  \ ld    c, a
  ret

vmx-do-udivmod-0-de:
  ex    de, hl
vmx-do-udivmod-0-hl:
  ld    c, l
  ld    a, l
  ret

vmx-udiv-part:
 OPT-16BIT-MUL/DIV-UNROLLED? [IF]
  ;; 1
  rla
  adc   hl, hl
  sbc   hl, de
  jr    nc, # $ 3 +
  add   hl, de
  ;; 2
  rla
  adc   hl, hl
  sbc   hl, de
  jr    nc, # $ 3 +
  add   hl, de
  ;; 3
  rla
  adc   hl, hl
  sbc   hl, de
  jr    nc, # $ 3 +
  add   hl, de
  ;; 4
  rla
  adc   hl, hl
  sbc   hl, de
  jr    nc, # $ 3 +
  add   hl, de
  ;; 5
  rla
  adc   hl, hl
  sbc   hl, de
  jr    nc, # $ 3 +
  add   hl, de
  ;; 6
  rla
  adc   hl, hl
  sbc   hl, de
  jr    nc, # $ 3 +
  add   hl, de
  ;; 7
  rla
  adc   hl, hl
  sbc   hl, de
  jr    nc, # $ 3 +
  add   hl, de
  ;; 8
  rla
  adc   hl, hl
  sbc   hl, de
  jr    nc, # $ 3 +
  add   hl, de
  ;; done
  rla
  cpl
  ret
 [ELSE]
  ld  b, # 8
.loop0:
  rla
  adc   hl, hl
  sbc   hl, de
  jr    nc, # .skip-add-0
  add   hl, de
.skip-add-0:
  djnz  # .loop0
  rla
  cpl
  ret
 [ENDIF]
;code-no-next
2 2 Succubus:setters:in-out-args

primitive: U/  ( ua ub -- ua/ub )
zx-required: UU/MOD
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?< ex-de-hl >?
  ;; in:
  ;;   HL=a
  ;;   DE=b
  ;; out:
  ;;   CA=quotient
  ;;   HL=remainder
  @label: vmx-do-udivmod call-#
  TOS-in-HL? ?<
    c->h
    a->l
  ||
    c->d
    a->e
  >? ;

primitive: UMOD  ( ua ub -- ua%ub )
zx-required: UU/MOD
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?< ex-de-hl >?
  ;; in:
  ;;   HL=a
  ;;   DE=b
  ;; out:
  ;;   CA=quotient
  ;;   HL=remainder
  @label: vmx-do-udivmod call-#
  TOS-in-HL! ;

;; stupid result order!
primitive: U/MOD  ( ua ub -- ua%ub ua/ub )
zx-required: UU/MOD
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?< ex-de-hl >?
  ;; in:
  ;;   HL=a
  ;;   DE=b
  ;; out:
  ;;   CA=quotient
  ;;   HL=remainder
  @label: vmx-do-udivmod call-#
  push-hl
  TOS-in-HL? ?<
    c->h
    a->l
  ||
    c->d
    a->e
  >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; fast 16-bit signed mutliplication and division

;; the remainder takes its sign from the dividend.
;; k8: don't even ask me!
;; stupid result order!
code: /MOD  ( a b -- a%b a/b )
  ex    de, hl
  \ pop   de
  \ ld    hl, bc
  \ ex    (sp), hl
  pop   hl
  call  # zx-word-divmod-main
  \ pop   bc
  \ next-push-de-hl
  push  de
  next

  ;; in:
  ;;   HL=a
  ;;   DE=b
  ;; out:
  ;;   HL=a/b
  ;;   DE=a%b
zx-word-divmod-main:
  ld    a, d
  or    e
  jr    z, # vmx-do-divmod-0-de

  ld    a, h
  xor   d
  ex    af, afx ;; store flags
  push  hl      ;; save dividend

  call  # vmx-abs-de-hl
  call  # vmx-do-udivmod
  ;; HL=remainder
  ;; CA=quotient
  ld    b, c
  ld    c, a
  ;; HL=remainder
  ;; BC=quotient

  pop   af      ;; dividend high byte is in A
  rla
  jr    nc, # .remainder-is-ok
  ;; negate HL
  ex    de, hl
  ld    hl, # 0
  or    a
  sbc   hl, de
.remainder-is-ok:
  ex    de, hl
  ;; DE=remainder
  ;; BC=quotient
  ex    af, afx ;; sign flags
  ld    hl, bc
  ;; DE=remainder
  ;; HL=quotient
  jp    p, # .quot-is-ok
  ld    hl, # 0
  ;; carry is reset here
  sbc   hl, bc
.quot-is-ok:
  \ pop   bc
  \ next-push-de-hl
  ret

@vmx-do-divmod-0-de:
  ld    hl, de
  jr    # .quot-is-ok

vmx-abs-de-hl:
  ex    de, hl
  bit   7, h
  call  nz, # vmx-neg-hl
  ex    de, hl
  bit   7, h
  ret   z

vmx-neg-hl:
  ld    a, h
  cpl
  ld    h, a
  ld    a, l
  cpl
  ld    l, a
  inc   hl
  ret
;code-no-next
2 2 Succubus:setters:in-out-args

primitive: /  ( a b -- a/b )
zx-required: /MOD
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?< ex-de-hl >?
  ;; in:
  ;;   HL=a
  ;;   DE=b
  ;; out:
  ;;   HL=a/b
  ;;   DE=a%b
  @label: zx-word-divmod-main call-#
  TOS-in-HL! ;

primitive: MOD  ( a b -- a%b )
zx-required: /MOD
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?< ex-de-hl >?
  ;; in:
  ;;   HL=a
  ;;   DE=b
  ;; out:
  ;;   HL=a/b
  ;;   DE=a%b
  @label: zx-word-divmod-main call-#
  TOS-in-DE! ;

primitive: /MOD-REV  ( a b -- a/b a%b )
zx-required: /MOD
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?< ex-de-hl >?
  ;; in:
  ;;   HL=a
  ;;   DE=b
  ;; out:
  ;;   HL=a/b
  ;;   DE=a%b
  @label: zx-word-divmod-main call-#
  push-hl
  TOS-in-DE! ;


<zx-done>
