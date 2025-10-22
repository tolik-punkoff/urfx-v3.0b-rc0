;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; COLD, WARM, etc.
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>

['] (DIHALT) TO (MAIN-WORD)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; basic error will be re-routed here

<zx-system>

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level "COLD"

OPT-BASIC-ERR-HANDLER? [IF]
['] (DIHALT) TO (BERR-HANDLER)
[ENDIF]

['] NOOP TO (INIT-I/O)


: ROM-IM1-MODE?  ( -- n )  asm-label: zx-im2-rom-im1 C@ ; zx-inline
: ROM-IM1-MODE!  ( n )  asm-label: zx-im2-rom-im1 C! ; zx-inline

: NO-ROM-IM1     0 ROM-IM1-MODE! ; zx-inline
: ROM-IM1-FIRST  1 ROM-IM1-MODE! ; zx-inline
: ROM-IM1-LAST   2 ROM-IM1-MODE! ; zx-inline

;; only AF and HL are saved!
: IM2-PROC@  ( -- addr ) asm-label: zx-im2-userproc-addr @ ; zx-inline
: IM2-PROC!  ( addr )    asm-label: zx-im2-userproc-addr ! ; zx-inline

<zx-forth>
<zx-done>
