;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; pixel manipulation
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$zx-require XY>SCR$ <gfx/scradr.f>

zxlib-begin" ROM PLOT library"


code: POINT  ( x y -- flag )
  \ pop   hl
  pop   de
  ld    a, h
  or    d
  jr    nz, # .invalid-coords
  ld    a, l
  cp    # 192
  jr    nc, # .invalid-coords
  ;; ROM calc screen address
  ;; IN:
  ;;   C: x
  ;;   A: y
  ;; OUT:
  ;;   HL: scr$
  ;;    A: bit number (from the msb; i.e. 0 means "$80")
  ;;   zflag: set if A is 0
  ld    c, e
  call  # $22B0
  ;; prepare for subtraction
  rlca
  rlca
  rlca
  ld    b, a
  ld    a, # @377 ;; "SET 7, A"
  sub   b         ;; fix bit number
  ld    .point-set-patch 1 - (), a
  xor   a
  set   0, a
.point-set-patch:
;; SMC is usually faster than loop
  and   (hl)
  jr    z, # .invalid-coords
  ld    hl, # 1
  next
.invalid-coords:
  ld    hl, # 0
;code

;; ROM
primitive: PLOT  ( x y )
:codegen-xasm
  pop-bc-peephole  ;; x is in the right place
  tos-r16 r16h->a
  or-a-b
  cond:nz jr-cc
  tos-r16 r16l->a
  192 cp-a-c#
  cond:nc jr-cc
  ;; B: y
  ;; C: x
  a->b
  @label: sysvar-coords bc->(nn)
  ;; ROM "PLOT" does unnecessary y check, skip it
  push-iy
  restore-iy
  $22B0 call-#
  $22EC call-#
  pop-iy
  jr-dest! jr-dest!
  pop-tos ;


;; don't touch attrs, ignore gover/inverse.
;; see below for mode set. default is "OR"
;; "off" mode always removes the pixel.
code: PSET  ( x y on? )
  \ pop   hl        ;; on?
  ld    a, l
  or    h
  pop   hl        ;; y
  pop   de        ;; x
  ex    af, afx   ;; A' holds the "on" flag
  ;; check for negative coords
  ld    a, h
  or    d
  jr    nz, # .done
  ;; check Y
  ld    a, l
  cp    # 192
  jr    nc, # .done
  ;; coords are valid
  ;; calc screen address
  ;; IN:
  ;;   C: x
  ;;   A: y
  ;; OUT:
  ;;   HL: scr$
  ;;    A: bit number (from the msb; i.e. 0 means "$80")
  ld    c, e
  ld    a, l
  call  # $22B0
  ;; prepare for subtraction
  rlca
  rlca
  rlca
  ld    b, a
  ex    af, afx   ;; A holds the "on" flag now
  or    a
  jr    z, # .do-reset
  ld    a, # @377 ;; "SET 7, A"
  sub   b         ;; fix bit number
  ld    .pset-set-patch 1 - (), a
  xor   a
  set   0, a
.pset-set-patch:
;; loop code: 16ts in the best case, 135ts in the worst case
;; loop-free code: 7+4+13+4+8=36ts in any case
@pset-instr-addr:
  or    (hl)
  ld    (hl), a
  pop   hl
  next
.do-reset:
  ld    a, # @277 ;; "RES 7, A"
  sub   b         ;; fix bit number
  ld    .pset-reset-patch 1 - (), a
  ld    a, # $FF
  res   0, a
.pset-reset-patch:
  and   (hl)
  ld    (hl), a
.done:
  pop   hl
;code

primitive: PSET-XOR!  ( -- )
zx-required: PSET
:codegen-xasm
  ;; xor (hl)
  $AE c#->a
  @label: pset-instr-addr a->(nn) ;

primitive: PSET-OR!  ( -- )
zx-required: PSET
:codegen-xasm
  ;; or (hl)
  $B6 c#->a
  @label: pset-instr-addr a->(nn) ;


;; don't touch attrs, ignore gover/inverse
;; see below for mode set. default is "XOR"
code: PXOR  ( x y )
  \ pop   hl        ;; y
  pop   de        ;; x
  ;; check for negative coords
  ld    a, h
  or    d
  jr    nz, # .done
  ;; check Y
  ld    a, l
  cp    # 192
  jr    nc, # .done
  ;; coords are valid
  ;; calc screen address
  ;; IN:
  ;;   C: x
  ;;   A: y
  ;; OUT:
  ;;   HL: scr$
  ;;    A: bit number (from the msb; i.e. 0 means "$80")
  ld    c, e
  ld    a, l
  call  # $22B0
  ;; prepare for subtraction
  rlca
  rlca
  rlca
  ld    b, a
  ld    a, # @377 ;; "SET 7, A"
  sub   b         ;; fix bit number
  ld    .pxor-set-patch 1 - (), a
  xor   a
  set   0, a
.pxor-set-patch:
;; SMC is usually faster than loop
@pxor-instr-addr:
  xor   (hl)    ;; $AE
\ flush! pxor-instr-addr zx-c@ .hex4 cr
  ld    (hl), a
.done:
  pop   hl
;code

primitive: PXOR-XOR!  ( -- )
zx-required: PXOR
:codegen-xasm
  ;; xor (hl)
  $AE c#->a
  @label: pxor-instr-addr a->(nn) ;


primitive: PXOR-OR!  ( -- )
zx-required: PXOR
:codegen-xasm
  ;; or (hl)
  $B6 c#->a
  @label: pxor-instr-addr a->(nn) ;

primitive: PXOR-NOP!  ( -- )
zx-required: PXOR
:codegen-xasm
  ;; nop
  xor-a-a
  @label: pxor-instr-addr a->(nn) ;


zxlib-end
