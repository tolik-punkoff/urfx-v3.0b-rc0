;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; this accumulated a lot of barely related things over time. sorry.
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


0xc0de_d00d constant tgt-code-pair
0xc1de_d11d constant tgt-colon-pair
0xc1de_d21d constant tgt-scolon-pair
0xcade_daad constant tgt-cblock-pair


0 quan tgt-(quan-vocid)
0 quan tgt-(vector-vocid)
0 quan tgt-(chain-vocid)
0 quan tgt-(uservalue-vocid)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utilities

: ?comp-target  system:?comp ?in-target ;
: ?exec-target  system:?exec ?in-target ;

$include "urb-41-tcwdef-10-helpers.f"
$include "urb-41-tcwdef-12-forwards.f"
$include "urb-41-tcwdef-18-compiler.f"
$include "urb-41-tcwdef-20-basic-defs.f"
$include "urb-41-tcwdef-22-chained.f"
$include "urb-41-tcwdef-24-quan.f"
$include "urb-41-tcwdef-26-vector.f"
$include "urb-41-tcwdef-28-uservalue.f"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some checkers

: tgt-good-shadow?  ( cfa -- flag )
  system:doer@ <<
    ['] (tgt-does-forth) of?v| true |?
    ['] (tgt-does-code) of?v| true |?
    ['] (tgt-does-const) of?v| true |?
    ['] (tgt-does-var) of?v| true |?
    ['] (tgt-does-uservar) of?v| true |?
    ['] (tgt-does-vocab) of?v| true |?
    ['] (tgt-does-chained) of?v| true |?
    ['] (tgt-does-quan) of?v| true |?
    ['] (tgt-does-vector) of?v| true |?
    ['] (tgt-does-dummy) of?v| true |?
    ['] (tcfx-doer) of?v| true |?
    ['] (tcfh-doer) of?v| true |?
  else| drop false >> ;

: ?tgt-good-shadow  ( cfa )  tgt-good-shadow? not?error" invalid word" ;

: tgt-forth?  ( cfa -- flag )
  system:doer@ ['] (tgt-does-forth) = ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
$include "urb-41-tcwdef-30-tcf-helpers.f"
$include "urb-41-tcwdef-40-colon.f"
