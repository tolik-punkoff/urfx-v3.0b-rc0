;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create code and colon ZX words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create ZX code word

|: define-zx-code-word-label  ( addr count )
  " zx-word-" string:>pad string:pad+cc
  string:pad-cc@ zx-here z80-labman:lbl-new
  z80-labman:reset-locals ;


0 quan stack-cmt-in
0 quan stack-cmt-out
0 quan stack-cmt-in-r
0 quan stack-cmt-out-r

false quan stack-cmt-in-r?

|: parse-stack-in  ( -- out-found? )
  stack-cmt-in-r?:!f
  << parse-name/none dup not?error" proper stack comment expected"
       \ endcr 2dup type cr
     2dup " --" string:= ?v| 2drop true |?
     2dup " )" string:= ?v| 2drop false |?
     2dup " //" string:= ?^| 2drop stack-cmt-in-r? not?< -1 stack-cmt-in:! >? |?
     2dup " |" string:= ?^| 2drop stack-cmt-in-r?:!t |?
     2dup " <unknown>" string:= ?^| 2drop stack-cmt-in-r? not?< -1 stack-cmt-in:! -1 stack-cmt-out:! >? |?
  ^| 2drop stack-cmt-in-r? ?< stack-cmt-in-r +0?< stack-cmt-in-r:1+! >?
           || stack-cmt-in +0?< stack-cmt-in:1+! >? >? |
  >> ;

|: parse-stack-out
  stack-cmt-in-r?:!f
  << parse-name/none dup not?error" proper stack comment expected"
       \ endcr 2dup type cr
     2dup " --" string:= ?error" second delimiter? wtf?!"
     2dup " )" string:= ?v| 2drop |?
     2dup " //" string:= ?^| 2drop stack-cmt-in-r? not?< -1 stack-cmt-out:! >? |?
     2dup " |" string:= ?^| 2drop stack-cmt-in-r?:!t |?
     2dup " <unknown>" string:= ?^| 2drop stack-cmt-in-r? not?< -1 stack-cmt-in:! -1 stack-cmt-out:! >? |?
  ^| 2drop stack-cmt-in-r? ?< stack-cmt-out-r +0?< stack-cmt-out-r:1+! >?
           || stack-cmt-out +0?< stack-cmt-out:1+! >? >? |
  >> ;

|: parse-stack-comment
  \ parse-name/none dup not?exit< 2drop >?
  parse-name/none dup not?error" where is the stack effect comment?"
  " (" string:= not?error" where is the stack effect comment?"
  stack-cmt-in:!0 stack-cmt-out:!0
  stack-cmt-in-r:!0 stack-cmt-out-r:!0
  parse-stack-in ?< parse-stack-out >?
    \ endcr ." in: " stack-cmt-in . ." out: " stack-cmt-out 0.r cr
  stack-cmt-in +0?< stack-cmt-in Succubus:setters:in-args-force >?
  stack-cmt-out +0?< stack-cmt-out Succubus:setters:out-args-force >?
  stack-cmt-in-r +?< stack-cmt-in-r Succubus:setters:in-rargs >?
  stack-cmt-out-r +?< stack-cmt-out-r Succubus:setters:out-rargs >?
;


;; no asm code for this primitive
*: zx-primitive:  \ name
  zx-compile-mode ?error" still compiling something"
  zx-tick-register-ref ?error" missing \'create;\'"
  system:?exec zx-?exec
  ir:cgen-flush
  zx-here zx-tk-rewind-addr:!
  mk-shadow-as-primitive?:!t
  parse-name
  ['] ss-code-doer mk-shadow-header
  zx-here latest-shadow-pfa shword:zx-begin:!
  \ tkf-no-tco tkf-primitive or latest-shadow-pfa shword:tk-flags:^ or!
  ir:reset  ;; just in case
  \ @303 zx-c, 0 zx-w,  ;; no need to reserve bytes for primitives
  zx-fix-org
  parse-stack-comment ;


*: zx-code-raw:  \ name
  zx-compile-mode ?error" still compiling something"
  zx-tick-register-ref ?error" missing \'create;\'"
  system:?exec zx-?exec
  ir:cgen-flush
  zx-here zx-tk-rewind-addr:!
  parse-name 2dup 2>r
  ['] ss-code-doer mk-shadow-header
  zx-here latest-shadow-pfa shword:zx-begin:!
  zx-fix-org
  \ 2r> define-zx-code-word-label
  [\\] <asm>
  push-ctx voc-ctx: zxf-code
  zxc-code zx-compile-mode:!
  zxcode-raw zx-code-word-type:!
  2r> define-zx-code-word-label
  Succubus:setters:need-TOS-HL  \ even if takes no args, it need to preserve HL
  \ zx-opt-reset
  ir:reset  ;; just in case
  ;; statistics
  zx-stats-code:1+!
  zx-here zx-stx-last-code-start:! ;

*: zx-code:  \ name
  [\\] zx-code-raw:
  zxcode-cooked zx-code-word-type:!
  z80asm:instr:std-entry ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create ZX colon words

*: zx:  \ name
  zx-compile-mode ?error" still compiling something"
  zx-tick-register-ref ?error" missing \'create;\'"
  system:?exec zx-?exec
  ir:cgen-flush
  zx-here zx-tk-rewind-addr:! ;; useless
  parse-name
  ['] ss-forth-doer mk-shadow-header
  zx-here latest-shadow-pfa shword:zx-begin:!
  zx-fix-org
  push-ctx
  0 vsp-push
  vocid: forth-shadows vsp-push
  zx-shadow-context dup vocid: forth-shadows <> ?< vsp-push || drop >?
  \ zx-in-editor? ?< vocid: editor-shadows vsp-push >?
  vocid: shadow-helpers vsp-push
  voc-ctx: shadow-semi
  zx-comp!
  $c0de_0800
  zxc-colon zx-compile-mode:!
  zxcode-bad zx-code-word-type:!
  Succubus:setters:need-TOS-HL
  \ zx-opt-reset-here
  ir:reset
  xasm:reset
\ endcr ." ZX-COLON: $" zx-tk-rewind-addr .hex4 ."  -- " curr-word-snfa debug:.id cr
  ;; statistics
  zx-stats-colon:1+!
  zx-here zx-stx-last-colon-start:! ;

*: zx|:
  [\\] zx: ;

*: zx*:
  error" no immediate words, please!" ;


end-module
