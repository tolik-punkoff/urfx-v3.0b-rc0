;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 42-column print driver
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; enable control code intepreting?
;; if `FALSE`, only 13 (CR) and 4 (ENDCR) will be recognized.
;; and in this mode, ENDCR is the same as CR.
false zx-lib-option OPT-EMIT-CCODES?

;; automatically setup the driver?
true zx-lib-option OPT-EMIT6-AUTOSETUP?

;; set "OBL?" variable?
true zx-lib-option OPT-EMIT6-OBL?

;; set "OUT#" variable?
true zx-lib-option OPT-EMIT6-OUT#?

;; set "SC#" variable?
true zx-lib-option OPT-EMIT6-SC#?

;; install cursor on/off words?
true zx-lib-option OPT-EMIT6-KCUR?

;; install "KEY" handler?
true zx-lib-option OPT-EMIT6-KEY?

;; use ROM font for small letters?
;; this saves 234 bytes.
false zx-lib-option OPT-EMIT6-UGLY?

$include "20-emit6.f"
$include "30-emit6-common.f"
