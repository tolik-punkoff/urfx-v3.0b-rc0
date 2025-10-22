;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; helpers for code words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

0 quan zx-stx-last-code-start ;; for stats


module ZXF-CODE
<disable-hash>

extend-module z80asm:instr
;; macro
: next
  z80asm:flush
  z80asm:postfix? >r
  true z80asm:postfix!
  zx-code-word-type <<
    zxcode-raw of?v| ret |?
    zxcode-cooked of?v| (ix) jp |?
  else| error" invalid code mode" >>
  \ " i-next" z80-labman:use-label # jp
  \ (ix) jp
  r> z80asm:postfix! ;

: next-pop-tos
  z80asm:flush
  z80asm:postfix? >r
  true z80asm:postfix!
  zx-code-word-type <<
    zxcode-raw of?v|
      ix pop
      hl pop
      (ix) jp |?
    zxcode-cooked of?v|
      hl pop
      (ix) jp |?
  else| error" invalid code mode" >>
  r> z80asm:postfix! ;

: std-entry
  z80asm:flush
  z80asm:postfix? >r
  true z80asm:postfix!
  ix pop
  r> z80asm:postfix! ;
end-module

;; either "jp" or "jr"
: jxr  z80asm:instr:jp ;
\ : jxr  z80asm:instr:jr ;

: ;code-no-next
  zx-compile-mode zxc-code = not?error" ZX code word was not started yet"
  z80asm:flush
  zx-fix-dp
  pop-ctx [\\] zxa:zx-code-def:<end-asm>
  zxc-none zx-compile-mode:!
  zxcode-bad zx-code-word-type:!
  ir:reset  ;; just in case
  ;; add at least 1 byte, we might need it
  zx-here zx-tk-rewind-addr - 1 < ?< 0 zx-c, >?
  \ zx-opt-reset
  zx-tk-rewind not?<
    ;; statistics
    zx-here zx-stx-last-code-start - zx-stats-mcode-bytes:+! >? ;

: ;code
  zx-compile-mode zxc-code = not?error" ZX code word was not started yet"
  z80asm:instr:next
  ;code-no-next ;

: ;code-pop-tos
  zx-compile-mode zxc-code = not?error" ZX code word was not started yet"
  z80asm:instr:next-pop-tos
  ;code-no-next ;

end-module


end-module
