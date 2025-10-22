;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 32-column print driver
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; automatically setup the driver?
true zx-lib-option OPT-EMIT8-ROM-AUTOSETUP?

;; set "OBL?" variable?
true zx-lib-option OPT-EMIT8-ROM-OBL?

;; set "OUT#" variable?
true zx-lib-option OPT-EMIT8-ROM-OUT#?

;; set "SC#" variable?
true zx-lib-option OPT-EMIT8-ROM-SC#?

;; install cursor on/off words?
true zx-lib-option OPT-EMIT8-ROM-KCUR?

;; install "KEY" handler?
true zx-lib-option OPT-EMIT8-ROM-KEY?

0 [IF]
." OPT-EMIT8-ROM-AUTOSETUP?: " OPT-EMIT8-ROM-AUTOSETUP? 0.r cr
." OPT-EMIT8-ROM-OBL?: " OPT-EMIT8-ROM-OBL? 0.r cr
." OPT-EMIT8-ROM-OBL?: " OPT-EMIT8-ROM-OBL? 0.r cr
." OPT-EMIT8-ROM-OUT#?: " OPT-EMIT8-ROM-OUT#? 0.r cr
." OPT-EMIT8-ROM-SC#?: " OPT-EMIT8-ROM-SC#? 0.r cr
." OPT-EMIT8-ROM-KCUR?: " OPT-EMIT8-ROM-KCUR? 0.r cr
." OPT-EMIT8-ROM-KEY?: " OPT-EMIT8-ROM-KEY? 0.r cr
[ENDIF]


$include "10-emit8.f"
