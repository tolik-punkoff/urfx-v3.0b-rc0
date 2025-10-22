;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus module support
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


: tgt-enter-module-wmode!  tgt-wflag-private tgt-default-ffa ~and!
                           tgt-wflag-published tgt-default-ffa ~and! ;

: tgt-find-existing-module  ( addr count -- cfa )
  2dup current@ find-in-vocid-with-private ?exit< nrot 2drop >?
  2dup (tc-forth-vocid) find-in-vocid ?exit< nrot 2drop >?
  \ dup tgt-vocab? ?exit< nrot 2drop >? drop
  " cannot find target module \'" pad$:! pad$:+
  [char] " pad$:c+  pad$:@ error ;


tcf: MODULE  \ name
  ?exec-target
  parse-name 2dup current@ find-in-vocid-with-private ?error" duplicate module"
  tgt-mk-wordlist dup >r 0 2swap tgt-create-vocab
  module-support:vocid-module-enter
  vsp-pop drop  ;; remove "module-defs" vocabulary
  tgt-default-ffa @ nsp-push
  tgt-current@ nsp-push r> tgt-current!
  tgt-enter-module-wmode! ;tcf

tcf: END-MODULE
    \ current@ system:vocid>rfa @ idcount type cr current@ vocid-words
  ?exec-target
  nsp-pop tgt-current!
  nsp-pop tgt-default-ffa !
  module-words:end-module ;tcf

tcf: END-MODULE-ALIAS
    \ current@ system:vocid>rfa @ idcount type cr current@ vocid-words
  ?exec-target
  nsp-pop tgt-current!
  nsp-pop tgt-default-ffa !
  module-words:end-module ;tcf

tcf: EXTEND-MODULE  \ name
  ?exec-target
  parse-name tgt-find-existing-module
  dup >r module-support:voc-module-enter
  vsp-pop drop  ;; remove "module-defs" vocabulary
  tgt-default-ffa @ nsp-push
  tgt-current@ nsp-push r> dart:cfa>pfa 2 4* + @ tgt-current!
  tgt-enter-module-wmode! ;tcf

\ FIXME: works only for target vocabs yet!
tcf: PARENT-MODULE  \ name
  ?exec-target
  tgt-current@ dup tgt-vocid-parent@ ?error" module already has a parent"
  parse-name tgt-find-existing-module
  dart:cfa>pfa (shadow-tgt-voc@) swap tgt-vocid-parent! ;tcf

tcf: <DISABLE-HASH>
  ?exec-target tgt-current@ tgt-vocid-nohash! ;tcf

tcf: USING  \ name
  ?exec-target
  parse-name find not?error" using what?"
  system:?vocid@ module-support:vocid-using ;tcf

tcf: INVITE  \ name
  ?exec-target
  parse-name find not?error" using what?"
  system:?vocid@ module-support:vocid-using ;tcf

tcf: CLEAN-MODULE
  ?exec-target
  tgt-current@ tgt-remove-vocid-private ;tcf

tcf: SEAL-MODULE
  ?exec-target
  tgt-current@ tgt-remove-vocid-non-published ;tcf


tcf: <PUBLIC-WORDS>  tgt-wflag-private tgt-default-ffa ~and!
                     tgt-wflag-published tgt-default-ffa ~and! ;tcf
tcf: <PRIVATE-WORDS>  tgt-wflag-private tgt-default-ffa or!
                      tgt-wflag-published tgt-default-ffa ~and! ;tcf
tcf: <PUBLISHED-WORDS>  tgt-wflag-published tgt-default-ffa or! tgt-wflag-private tgt-default-ffa ~and! ;tcf
tcf: <NON-PUBLISHED-WORDS>  tgt-wflag-published tgt-default-ffa ~and! ;tcf
