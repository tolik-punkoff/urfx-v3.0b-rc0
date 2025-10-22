;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler
;; architecture is inspired by Common Forth Experiment from Luke Lee
;; all code is written from scratch
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


['] system:Succubus:code-here  x86asm:emit:here:!
[']   system:Succubus:code-db, x86asm:emit:c,:!
[']   system:Succubus:code-c@  x86asm:emit:c!:!
[']   system:Succubus:code-c!  x86asm:emit:c!:!
[']    system:Succubus:code-@  x86asm:emit:@:!
[']    system:Succubus:code-!  x86asm:emit:!:!

[HAS-WORD] BEAST-MACS-DISABLED [IFNOT]
$include "urforth-macs.f"
[ELSE]
  BEAST-MACS-DISABLED [IFNOT]
    $include "urforth-macs.f"
  [ENDIF]
[ENDIF]
