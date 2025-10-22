;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Z80 Abersoft fig-FORTH recompiled
;; Copyright (C) 2024 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16x16 XOR sprites, no runtime shifting
;; room (and tile) editor
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; this is used to save scr$ under windows, if necessary.
;; it goes from "free-buf-end" up.
;; 3,328 bytes.
$7300 constant FREE-BUF-START
$8000 constant FREE-BUF-END

true zx-lib-option OPT-HOT-SPACED-TEXT?
true zx-lib-option OPT-HOT-SPACED-TEXT-FULL-PRINT?
false zx-lib-option OPT-HOT-FRAME-RECT-AREAS?
true zx-lib-option OPT-HOT-FRAME-TEXT-AREAS?

-1 zx-lib-option OPT-DOS-I/O-+3DOS-BUFFERS

$zx-use <arrow-mouse>
$zx-use <win8/mk-win>
$zx-use <hot-areas>
$zx-use <io/dos> -- will select the correct driver
$zx-use <gfx/plot>
$zx-use <gfx/scradr>

zxlib-begin" total room editor"
$include "room-edit.f"
zxlib-end
