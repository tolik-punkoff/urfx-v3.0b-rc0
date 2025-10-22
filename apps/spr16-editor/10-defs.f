;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Z80 Abersoft fig-FORTH recompiled
;; Copyright (C) 2024 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16x16 XOR sprites, no runtime shifting
;; sprite editor
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; bytes per one sprite (1 byte is reserved)
16 2 * 2 + constant BT/SPR

;; load in block format (old file format)?
false constant SPR-LOAD-BLK

SPR-LOAD-BLK [IF]
;; sprites per one buffer
256 ( B/BUF)  BT/SPR u/ constant SPR/BUF

;; number of buffers reserved for sprites
16 constant #SPR-BUFS

;; first sprite buffer
40 constant 1ST-SPR-BUF

;; 7 4x4 sprite tabs
#SPR-BUFS SPR/BUF * constant MAX-SPR#

[ELSE]  \ SPR-LOAD-BLK
4 4 * 7 * constant MAX-SPR#
[ENDIF]  \ SPR-LOAD-BLK
0 constant SPR-FILE-OFFSET

\ MAX-SPR# . cr

;; the sprites are kept here, up to $7000
$6000 constant SPR-MEM

;; currently editing sprite (32 bytes, shifted back, upside-down)
$7000 constant WK-SPR-BUF
;; shift amount for the current sprite
0 quan WK-SPR-RSHIFT

;; currently editing sprite
0 quan WK-SPR#

;; first sprite in the sprite bar
0 quan SE-BAR-FIRST

;; used for animation demo
0 quan WK-ANIM-BASE   ;; base sprite for the current animation sequence
4 quan WK-ANIM-LEN    ;; number of sprites in the current animation sequence

;; undo buffer for the current sprite
$7040 constant UNDO-SPR-BUF

;; temp buffer
\ $7080 constant TMP-BUF-START
\ $7300 constant TMP-BUF-END

10 constant SE-ANIM-XOFS
 2 constant SE-ANIM-YOFS

20 constant SE-SBAR-XOFS
 1 constant SE-SBAR-YOFS

 3 constant SE-WALK-XOFS
16 constant SE-WALK-YOFS
