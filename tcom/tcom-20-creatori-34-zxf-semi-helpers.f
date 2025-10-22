;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; separate wordlist for ";", to make helper definitions easier
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

0 quan zx-stx-last-colon-start ;; for stats

: (zx-;-common)  ( compile-exit? )
  system:?exec zx-?comp
  swap $c0de_0800 system:?pairs
  zx-compile-mode zxc-colon = not?error" ZX colon word was not started yet"
  ;; IR codegen doesn't need last "EXIT"
  not?< tkf-no-return curr-word-spfa shword:tk-flags:^ or! >?  \ ?< forth-shadows:exit >?
  ir:head curr-word-spfa shword:ir-code:!
  \ zx-opt-reset
  zx-here curr-word-spfa shword:zx-begin:!
  curr-word-spfa ir:generate-code
  zx-exec!
  zxc-none zx-compile-mode:!
  zxcode-bad zx-code-word-type:!
  << vsp-pop ?^|| else| >> pop-ctx
\ endcr ." ZX-SEMI: $" zx-tk-rewind-addr .hex4 ."  -- " curr-word-snfa debug:.id cr
  [ 0 ] [IF]
    endcr ." ======== " curr-word-snfa debug:.id ."  ========\n"
    \ ir:dump-ir
  [ENDIF]
  (*
  zx-tk-rewind not?<
    ;; statistics
    zx-here zx-stx-last-colon-start - zx-stats-tcode-bytes:+! >?
  *)
;

module SHADOW-SEMI
<disable-hash>

*: [
  system:?exec zx-?comp
  zx-compile-mode zxc-colon = not?error" invalid \'[\' usage in ZX mode"
  push-ctx
  \ -666 vsp-push
  \ voc-ctx: forth
  0 vsp-push
  vocid: forth vsp-push
  vocid: shadow-semi vsp-push
  vocid: zx-consts vsp-push
  voc-ctx: tcom
  zx-exec! ;

*: {#,}
  system:?exec zx-?comp
  zx-compile-mode zxc-colon = not?error" invalid \'{#,}\' usage in ZX mode"
  zx-#, ;

*: ]
  system:?exec zx-?exec
  zx-compile-mode zxc-colon = not?error" invalid \']\' usage in ZX mode"
  \ << vsp-pop -666 <> ?^|| else| >> pop-ctx
  << vsp-pop ?^|| else| >> pop-ctx
  zx-comp! ;

*: ;noreturn  false (zx-;-common) ;
*: ;          true (zx-;-common) ;

end-module


end-module
