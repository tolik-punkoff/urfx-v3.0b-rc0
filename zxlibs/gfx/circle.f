;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FIXME: not tested as a library yet!
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; circle drawing
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$zx-require plot <plot.f>

zxlib-begin" CIRCLE library"


\ MIDPOINT CIRCLE ALGORITHM

\ <zx-hidden>
0 quan CX
0 quan CY
0 quan CP
0 quan CX1
0 quan CY1
0 quan PY
0 quan PXY
\ <zx-normal>

: CIRCLE  ( x y r )
  TO CX1 TO CY TO CX
  0 TO CP 0 TO CY1
  BEGIN CX1 CY1 < 0WHILE
    CP CY1 2* + 1+  TO PY
    PY CX1 2* - 1+  TO PXY
    CX CX1 + CY CY1 + PLOT
    CX CX1 - CY CY1 + PLOT
    CX CX1 + CY CY1 - PLOT
    CX CX1 - CY CY1 - PLOT
    CX CY1 + CY CX1 + PLOT
    CX CY1 - CY CX1 + PLOT
    CX CY1 + CY CX1 - PLOT
    CX CY1 - CY CX1 - PLOT
    PY TO CP 1 +TO CY1
    PXY ABS PY ABS < IF PXY TO CP 1 -TO CX1 ENDIF
  REPEAT ;


zxlib-end
