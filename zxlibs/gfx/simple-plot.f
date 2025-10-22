;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; pixel manipulation
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


zxlib-begin" simple ROM PLOT library"


;; WARNING! not a boolean!
primitive: POINT  ( x y -- flag )
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-DE? ?< ex-de-hl >?
  ;; DE:x; HL:y
  e->c
  l->b
  0 c#->l
  h->a
  or-a-d
  l->a
  cond:nz jr-cc ( .err )
  b->a
  176 cp-a-c#
  l->a
  cond:nc jr-cc ( .err .err )
  $22CE call-#
  $1E94 call-#
  jr-dest! jr-dest!
  a->tos ;

primitive: PLOT  ( x y )
:codegen-xasm
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-DE? ?< ex-de-hl >?
  ;; DE:x; HL:y
  h->a
  or-a-d
  cond:nz jr-cc ( .err )
  e->c
  l->b
  l->a
  176 cp-a-c#
  cond:nc jr-cc ( .err .err )
  $22DF call-#
  jr-dest! jr-dest!
  pop-tos ;


zxlib-end
