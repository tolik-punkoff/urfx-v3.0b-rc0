;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

endcr ." compiling LASERLIB demo app..." cr

$zx-use <emit8-rom>
$zx-use <stick-scan>
$zx-use <gfx/scradr>

$zx-use <sfx-joffa>
\ $zx-use <sfx-turner>
$zx-use <laserlib>


true constant DEPTH-CHECK?

zxlib-begin" application"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprites

" sprite-data.f" laserlib-include-sprites
\ laserlib-finish-include  ;; this is to rewind the data in pass1
" LASERLIB sprites" laserlib-finish-include-msg ;; the same, but with size message



DEPTH-CHECK? [IF]
0 quan (depth)

: SAVE-DEPTH  sys: depth (depth):! ; zx-inline
: ?DEPTH
  sys: depth (depth) = ?exit
  0 0 at ." STACK IMBALANCE!" (dihalt) ;
[ELSE]
: SAVE-DEPTH ; zx-inline
: ?DEPTH ; zx-inline
[ENDIF]

;; with interrupts
: xi
  1 BORDER
  DETECT-KJOY IF
    ." kempston detected" cr
    STICK-KJOY!
  ELSE
    ." no kempston!" cr
  ENDIF
  \ INIT-JSFX
  \ SPR-SETUP
  \ CLS CR CR CR
  ." \cLASERLIB Engine demo.\n"
  invv
  mirv
  invv

  atof
  128 ltk-spn!
  \ adjm
  ptbl

  aton

  3 ltk-row!
  4 ltk-col!
  13 ltk-spn!
  \ adjm
  ptbl

  16 ltk-row!
  2 ltk-col!
  1 ltk-spn!
  \ adjm
  ptbl

  (dihalt)
;

zxlib-end
