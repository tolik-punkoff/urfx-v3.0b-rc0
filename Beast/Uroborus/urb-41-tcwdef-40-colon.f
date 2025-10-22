;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; create target colon definitions
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


: tgt-(mk-colon)  \ name
  ?exec-target parse-name
\ endcr ." COLON: " 2dup type cr
  tgt-create-forth-word
  tgt-debug-record-comment
  tgt-colon-pair [\\] ]
  Succubus:start-colon ;

: tgt-(mk-colon-noshadow)  \ name
  ?exec-target parse-name
\ endcr ." COLON-NO-SHADOW: " 2dup type cr
  tgt-mk-header-forth drop ( tgt-forth-cfa) -1 tgt-cfa,
  tgt-colon-pair [\\] ]
  Succubus:start-colon ;

;; define new Forth words
tcf:  :  tgt-(mk-colon) ;tcf
tcf: |:  tgt-(mk-colon) tgt-wflag-private tgt-latest-ffa-or!
                        tgt-wflag-published tgt-latest-ffa-~and! ;tcf
tcf: *:  tgt-(mk-colon) tgt-wflag-immediate tgt-latest-ffa-or! ;tcf
tcf: @:  tgt-(mk-colon) tgt-wflag-private tgt-latest-ffa-~and!
                        tgt-wflag-published tgt-latest-ffa-or! ;tcf

;; define new Forth words without creating shadow complements.
;; this is required if shadow words are already defined by Uroborus.
tcf:  !:  tgt-(mk-colon-noshadow) ;tcf
tcf: !|:  tgt-(mk-colon-noshadow) tgt-wflag-private tgt-latest-ffa-or! ;tcf
tcf: !*:  tgt-(mk-colon-noshadow) tgt-wflag-immediate tgt-latest-ffa-or! ;tcf
tcf: !@:  tgt-(mk-colon-noshadow) tgt-wflag-private tgt-latest-ffa-~and!
                                  tgt-wflag-published tgt-latest-ffa-or! ;tcf


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TCO, colon, etc.


: tgt-semi
  ?comp-target tgt-colon-pair system:?pairs

  ;; do not analyze immediate words
  ;; need to do this before finishing the colon, to avoid
  ;; useless recording of optimiser info
  tgt-noinline-mark +?< Succubus:cannot-inline
  || tgt-latest-ffa tcom:@
     [ tgt-wflag-inline-allowed tgt-wflag-immediate or ] {#,}
     and tgt-wflag-immediate - not?< Succubus:cannot-inline >? >?

  Succubus:finish-colon
  tgt-noinline-mark:!0

  [\\] [
  [ tgt-wflag-immediate
    tgt-wflag-protected or
    tgt-wflag-private or
    tgt-wflag-published or ] {#,} tgt-default-ffa and! ;

;; note that the word itself still may be inlined.
tcf: {inline-blocker}  ?exec-target tgt-wflag-inline-blocker tgt-default-ffa or! ;tcf

;; the following colon word should not be inlined, but doesn't block inlining per se.
tcf: {no-inline}       ?exec-target tgt-noinline-mark:!1 ;tcf

;; try to inline the following colon word even if it is too big
tcf: {aggrressive-inline}  ?exec-target tgt-noinline-mark:!t ;tcf

;; transform last call to branch, do not compile "EXIT"
;; doesn't work for primitives, so in this case no tail call will be done
;; also, beware of loops and such: no checks!
tcf:  ;  tgt-semi ;tcf
tcf: ^;  Succubus:end-basic-block tgt-semi ;tcf

;; tail-call the next word (if possible)
tcf: tcall  \ name
  ?comp-target -find-required dup ?tgt-good-shadow
  \ dup tgt-forth? not?error" cannot tail-call non-Forth word"
  dart:cfa>pfa dup (?shadow-notimm) (shadow-tgt-cfa@)
  Succubus:cannot-inline ;; this is inline blocker for now
  Succubus:high:jump ;tcf

tcf: does>
  ?comp-target
  tgt-forwards:tgt-(does>) tgt-<\, tcom:here >r 0 tcom:, tgt-\>
  tgt-semi
  " " (tgt-mk-header-forth) drop ( drop nfa)
  tgt-latest-cfa r> tcom:!
  tgt-colon-pair [\\] ]
  Succubus:start-anonymous-colon ;tcf
