;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 42-column print driver
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; automatically setup the driver?
true zx-lib-option OPT-EMIT4-AUTOSETUP?

;; set "OBL?" variable?
true zx-lib-option OPT-EMIT4-OBL?

;; set "OUT#" variable?
true zx-lib-option OPT-EMIT4-OUT#?

;; set "SC#" variable?
true zx-lib-option OPT-EMIT4-SC#?

;; install cursor on/off words?
true zx-lib-option OPT-EMIT4-KCUR?

;; install "KEY" handler?
true zx-lib-option OPT-EMIT4-KEY?


$include "20-emit4.f"
$include "30-emit4-common.f"
