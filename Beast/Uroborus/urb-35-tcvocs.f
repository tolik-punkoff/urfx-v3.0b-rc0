;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target wordlists (parallel to the main)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
WARNING! this heavily distorts the normal vocabulary list structure.
do not try to use FORGET or alike after using this.

the idea is that we should create a "shadow" word/vocab for each
target one, and use standard INTERPRET to compile the code. "shadow"
words will simply compile themselves to the target memory.

control structures and word definition are special, in the case that
they should know about target branch system, and compile branches.

also, vocabularies are triple-pfa. the first is the "shadow" vocid,
and the second is target one, and the third is target cfaxt. this way
executing it sets the correct one.
*)

0 quan (orig-voc-link)
0 quan (tc-voc-link)
0 quan (tc-forth-vocid)
0 quan (beast-forth-vocid)
false quan vocs-in-target?

0 quan (orig-context)
0 quan (orig-current)
0 quan (orig-vsp)
0 quan (orig-nsp)


: in-target?  vocs-in-target? ;
: ?in-target  in-target? not?error" should be in TARGET mode" ;

: >target-vocs
  vocs-in-target? not?<
    voc-link @ to (orig-voc-link) (tc-voc-link) voc-link !
    true to vocs-in-target? >? ;

: >orig-vocs
  vocs-in-target? ?<
    voc-link @ to (tc-voc-link) (orig-voc-link) voc-link !
    false to vocs-in-target? >? ;

|: save-vstate
  context@ to (orig-context) current@ to (orig-current)
  (vsp) @ to (orig-vsp) (nsp) @ to (orig-nsp) ;

|: restore-vstate
  (orig-context) context! (orig-current) current!
  (orig-vsp) (vsp) ! (orig-nsp) (nsp) ! ;

: >in-target
  vocs-in-target? ?error" double target"
  >target-vocs save-vstate
  (tc-forth-vocid) dup context! current!
  0 vsp-push ( vocstack search terminator ) ;

: >in-origin
  vocs-in-target? not?error" not in target"
  >orig-vocs restore-vstate ;

: init-target-wlist
  ( 0 true ) system:mk-wordlist
  dup system:vocid-separate-hash!
  (tc-forth-vocid):! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(*
  shadow vocab format (PFA):
    target-ccfa
    target-cfa
    target-vocid
*)
;; only for vocabs
: (shadow-tgt-voc@)  ( pfa -- tgt-vocid )  [ 2 4* ] {#,} + @ ;

: (tgt-does-vocab)
  system:comp? ?in-target ?< 4+ @ tcom:, || abort ( @ context! ) >? ;

: tgt-vocab?  ( cfa -- flag )
  dup system:does? not?exit< drop false >?
  system:doer@ ['] (tgt-does-vocab) = ;

;; if not empty
: tgt-vocab-set-latest-rfa  ( vocid )
  tgt-voc-header-nfa-ofs +
  dup tcom:@ not?< tgt-latest-nfa swap tcom:! || drop >? ;

;; should be called right after "tgt-mk-builds"
: tgt-convert-latest-to-vocobj  ( vocid )
  dup tgt-latest-vocid tcom:!
  tgt-vocab-set-latest-rfa ;

: tgt-mk-vocobj-noshadow  ( addr count vocid )
  >r ( tgt-mk-header-4) tgt-mk-header-create-align drop
  tgt-does-cfa tgt-cfa,
  r> tgt-convert-latest-to-vocobj
  0 tgt-latest-!doer ( this will be patched before saving ) ;

;; should be called right after "tgt-mk-builds"
: tgt-convert-latest-to-vocobj-future  ( node^ )
  here over @ , swap !
  tgt-latest-vocid , ;

: tgt-patch-vocobj-list  ( tgt-vocid node^ )
  << @ dup not?v|| ^| 2dup 4+ @ tcom:! | >> 2drop ;

: tgt-remember-vocdoer
  here
  tgt-vocdoer-list ,
  tgt-latest-doer^ ,
  tgt-vocdoer-list:! ;

: tgt-create-vocab  ( tgt-vocid shadowvocid/0 addr count -- tcom-vocid )
  2dup 2>r ( tgt-mk-header-4) tgt-mk-header-create-align
  >r over r> tgt-nfa>lfa tgt-lfa>wfa tgt-wfa>vocid tcom:! ;; set vocid in header
  tgt-does-cfa tgt-cfa,
  0 tgt-latest-!doer  ;; this will be patched before saving
  tgt-remember-vocdoer
  over tgt-voc-header-nfa-ofs + tgt-latest-nfa swap tcom:! ( fix hdr-nfa ) 2r>
  ;; create shadow vocab
  \ rot dup not?< drop ( 0 true ) system:mk-wordlist >? >r  ;; shadow vocid
  rot dup not?< drop ( 0 true ) system:mk-wordlist dup system:vocid-separate-hash! >? >r  ;; shadow vocid
  \ FIXME: two CFAs is a leftover from the previous system
  r@ system:mk-builds-vocab tgt-latest-cfa , tgt-latest-cfa , ( target vocid) ,
  system:latest-cfa ['] (tgt-does-vocab) system:!doer
  r> ;

;; initialise target FORTH vocabulary (with one word -- "FORTH")
;; start with this word, and then fill the target vocabulary
: init-target-voc
  (tc-voc-link) ?error" wutta?!"
  (tc-forth-vocid) ?error" wutta?!"
  current@
  >target-vocs init-target-wlist
  (tc-forth-vocid) current!
  tgt-mk-wordlist dup (beast-forth-vocid):!
  dup tgt-current! dup tgt-context-va tcom:! -- this is the first one, and the current one
  (tc-forth-vocid) " FORTH" tgt-create-vocab (tc-forth-vocid):!
  >orig-vocs current! ;

init-target-voc
\ ." TGT FORTH VOCID: 0x" (tc-forth-vocid) .hex8 cr
\ (tc-forth-vocid) vocid-words
\ ." -------\n"
