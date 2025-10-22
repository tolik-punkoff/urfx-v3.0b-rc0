;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; define basic target word classes (Forth, code, etc.)
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create target code words

|: (tgt-does-dummy)
  \ HACK!
  \ " cannot use dummy word \'" pad$:!
  \ 12- dart:cfa>nfa idcount pad$:+
  \ " \'!" pad$:+
  \ pad$:@ error
  ?comp-target (shadow-tgt-cfa@) tgt-cc\, ;

|: (tgt-does-code)
\ endcr ." *** DOES CODE ***\n"
\ debug:.s
\ depth 2 < ?< abort >?
  ?comp-target (shadow-tgt-cfa@) tgt-cc\, ;

: tgt-create-code-word  ( addr count )
  2dup ( tgt-code-cfa) -1 (tgt-create-tgt-code-word)  ( tgt-nfa )
  ['] (tgt-does-code) (tgt-mk-rest2) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create target Forth words

|: (tgt-does-forth)
  ?comp-target dup (?shadow-notimm) (shadow-tgt-cfa@) tgt-cc\, ;

: tgt-create-forth-word  ( addr count )
  2dup ( tgt-forth-cfa) -1 (tgt-create-tgt-forth-word)  ( tgt-nfa )
  ['] (tgt-does-forth) (tgt-mk-rest2) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create target constants and variables

|: (tgt-does-const)
  ?in-target (shadow-tgt-cfa@) tgt-cfa>pfa tcom:@ tgt-#, ;

: tgt-constant  ( value )  \ name
  >r parse-name
    \ endcr ." NEW TGT CONST: " 2dup type cr
  2dup tgt-constant-cfa (tgt-create-tgt-word-var-align) r> tcom:, ( value )
  ['] (tgt-does-const) (tgt-mk-rest2) ;


|: (tgt-does-var)
  ?comp-target (shadow-tgt-cfa@) tgt-cfa>pfa tgt-#, ;

: tgt-variable  ( value )  \ name
  >r parse-name
    \ endcr ." NEW TGT VAR: " 2dup type cr
  2dup tgt-variable-cfa (tgt-create-tgt-word-var-align) r> tcom:, ( value )
  ['] (tgt-does-var) (tgt-mk-rest2) ;

: tgt-create  \ name
  parse-name
  2dup tgt-variable-cfa (tgt-create-tgt-word-create-align)
  ['] (tgt-does-var) (tgt-mk-rest2) ;


|: (tgt-does-uservar)
  ?in-target (shadow-tgt-cfa@) tgt-cc\, ;

: tgt-uservar  ( va )  \ name
  ll@ (mt-area-start) - ( convert to user-relative )
  >r parse-name
  2dup tgt-uservar-cfa (tgt-create-tgt-word-var-align) r> tcom:, ( value )
  ['] (tgt-does-uservar) (tgt-mk-rest2) ;


tcf: variable  system:?exec tgt-variable ;tcf
tcf: constant  system:?exec tgt-constant ;tcf

;; this actually executes a word
tcf: uro-constant@  ( -- n )  \ name
  push-ctx voc-ctx: forth -find-required execute pop-ctx ;tcf


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; non-immediate words with host actions in interpret mode

|: (tcfh-doer) ( pfa )
  system:comp? ?exit< ;; compile it
    ?comp-target dup (?shadow-notimm)
    (shadow-tgt-cfa@) tgt-cc\, >?
  ;; execute host action code
  tcf-jump@
  [ BEAST-DEVASTATOR ] [IF] execute-tail [ELSE] forth::(forth-branch) [ENDIF] ;


*: TCFH:
  [\\] TCF:
  system:latest-cfa ['] (tcfh-doer) system:!doer ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; non-immediate words with host actions in interpret mode

tcfh: here ?exec-target tcom:here ;tcf
tcfh: ,    ?exec-target tcom:, ;tcf
tcfh: c,   ?exec-target tcom:c, ;tcf
tcfh: w,   ?exec-target tcom:w, ;tcf


tcf: uro-label@
  ?in-target
  x86-find-label
  system:comp? ?< tgt-#, >? ;tcf
