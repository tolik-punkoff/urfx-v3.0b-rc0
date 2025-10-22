;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; module support
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; module-alike words
;;
;; "MODULE" creates vocabulary if it doesn't exist yet.
;; "END-MODULE" restores context search stack.

module MODULE-WORDS
<disable-hash>
end-module MODULE-WORDS

module MODULE-SUPPORT
<disable-hash>

: CHECK-EXISTING  ( addr count )
  2dup current@ find-in-vocid not?exit< 2drop >? drop
  " trying to redefine module \'" pad$:! pad$:+
  " \' not found" pad$:+ pad$:@ error ;

: FIND-EXISTING  ( addr count -- cfa )
  2dup find ?exit< nrot 2drop >?
  " module \'" pad$:! pad$:+
  " \' not found" pad$:+ pad$:@ error ;

;; nstack contents (bottom one is the last)
;;   previous CURRENT
;;   previous (VSP)@
;;   previous DEFAULT-FFA@
;;   current module vocid (used as a safety guard)
: VOCID-MODULE-ENTER  ( vocid )
  push-ctx push-cur (vsp) @ nsp-push system:default-ffa @ nsp-push dup nsp-push
  dup context! current!
  vocid: module-words vsp-push
  system:wflag-module-mask system:default-ffa and! ;

: VOCID-USING  ( vocid )   push-ctx context! ;
: VOC-MODULE-ENTER  ( voccfa )  system:?vocid@ vocid-module-enter ;

: MK-MODULE  ( addr count )
  2dup check-existing
  system:mk-wordlist dup >r system:mk-builds-vocab r>
  vocid-module-enter ;

: ENTER-MODULE  ( addr count )
  find-existing voc-module-enter ;

: FINISH-MODULE
  nsp-depth 4 < ?error" invalid module structure (nsp)"
  nsp-pop current@ <> ?error" invalid module structure (current)"
  nsp-pop system:default-ffa ! nsp-pop (vsp) ! pop-cur pop-ctx ;

: ?GOOD-SEAL-VOCID  ( vocid )
  dup vocid: forth = ?error" cannot seal FORTH vocab"
  dup vocid: system = ?error" cannot seal SYSTEM vocab"
  drop ;

: PARSE-OPTIONAL-MODULE-NAME  ( -- addr count TRUE // FALSE )
  opt-name-parse:parse-optional-name ;

: BAD-END-MODULE  ( addr count )
  " invalid END-MODULE name \'" pad$:! pad$:+ 34 pad$:c+
  pad$:@ error ;

: CHECK-END-MODULE
  parse-optional-module-name not?exit
  \ module-support:find-existing system:?vocid@
  \ current@ = not?error" invalid END-MODULE module name" ;
  current@ system:vocid-rfa@ dup not?exit< drop bad-end-module >?
  >r 2dup r> idcount string:=ci not?exit< bad-end-module >?
  2drop ;

: DO-ONE-USING  ( addr count )
  module-support:find-existing
  system:?vocid@ module-support:vocid-using
  system:comp? ?< system:(colon-imports):1+! >? ;

: DO-ONE-END-USING  ( addr count )
  dup ?< module-support:find-existing system:?vocid@
         context@ = not?error" invalid END-USING module name"
      || 2drop >?
  system:comp? ?exit<
    system:(colon-imports) not?error" invalid colon END-USING"
    pop-ctx system:(colon-imports):1-! >?
  nsp-depth dup not?< drop
  || 4 < ?error" end what?"
     0 nsp-pick current@ <> ?error" invalid module structure"
     (vsp) @ 2 nsp-pick u<= ?error" end using what?" >?
  pop-ctx ;

end-module MODULE-SUPPORT


extend-module MODULE-WORDS

;; name is optional
: END-MODULE  \ name
  module-support:check-end-module
  module-support:finish-module ;

: CLEAN-MODULE
  current@ dup module-support:?good-seal-vocid system:remove-vocid-private ;

: SEAL-MODULE
  current@ dup module-support:?good-seal-vocid system:remove-vocid-non-published ;

: PARENT-MODULE  \ name
  current@ dup module-support:?good-seal-vocid
  dup system:vocid-parent@ ?error" module already has a parent"
  parse-name module-support:find-existing system:?vocid@
  swap system:vocid-parent! ;

;; make the given module visible without its prefix
;; WARNING! do not use this in loops or conditionals!
;; i.e. you'd better call "using" at the start of the word, but
;; never do it inside "<< ... >>" or "?< ... >?", or "for .. endfor".
;; this is because other words may push their own modules to context stack,
;; and then you may call "using", and then some word will try to pop
;; its temporary context, and everything *WILL* break.
*: USING  \ name
  parse-name module-support:do-one-using
  << module-support:parse-optional-module-name ?^| module-support:do-one-using |? else| >> ;

;; check if the top module is correct, and remove it.
;; name is optional
*: END-USING  \ name
  module-support:parse-optional-module-name
  not?exit< 0 0 module-support:do-one-end-using >?
  << module-support:do-one-end-using module-support:parse-optional-module-name ?^|| else| >> ;

*: INVITE  ( 'name' )  [\\] using ;
*: THANK-YOU  [\\] end-using ;

;; "import module as alias"
;; this creates vocid alias
*: IMPORT  \ mname AS aliasname
  system:?exec
  parse-name module-support:find-existing system:?vocid@
  parse-name 2 = swap w@ $20_20 or $73_61 = and not?error" `AS` expected"
  parse-name rot system:mk-builds-vocab ;
  ;; make it private (or not?) system:wflag-private latest-ffa or!

;; hash mode changes could be done only on empty modules
: <DISABLE-HASH>  current@ system:vocid-nohash! ;
: <SEPARATE-HASH> current@ system:vocid-separate-hash! ;

: <UNPROTECTED-WORDS> system:wflag-protected system:default-ffa ~and! ;
: <PROTECTED-WORDS>   system:wflag-protected system:default-ffa or! ;
: <CASE-SENSITIVE>    system:fflag-case-sens system:default-ffa or! ;
: <CASE-INSENSITIVE>  system:fflag-case-sens system:default-ffa ~and! ;

: <PUBLIC-WORDS>      system:wflag-private system:~and-word-flags-np ;
: <PRIVATE-WORDS>     system:wflag-private system:or-word-flags-np ;
: <PUBLISHED-WORDS>   system:wflag-published system:default-ffa or!
                      system:wflag-private system:default-ffa ~and! ;

end-module-alias


extend-module FORTH

;; create new vocabulary if it's not here yet, push stacks, set current and context
: MODULE  \ name
  parse-name module-support:mk-module ;

;; this can be used for vocobjects too
: EXTEND-MODULE  \ name
  parse-name module-support:enter-module ;

;; this can be used for vocobjects too
: EXTEND-VOCID  ( vocid )
  module-support:vocid-module-enter ;


;; wipe all stacks, set the given vocab as The Only One
: ONLY  \ name
  parse-name module-support:find-existing
  system:comp? ?exit< \\ system:?vocid@ \\ dup \\ context! \\ current! \\ vsp0! \\ nsp0! >?
  system:?vocid@ dup context! current! vsp0! nsp0! ;


*: VOCID:  ( -- vocid )  \ vocname
  -find-required dart:cfa>vocid system:comp? ?exit< #, \\ @ >? @ ;

*: VOC-CTX:  ( 'vocname' )
  -find-required system:comp? ?exit< #, \\ system:?vocid@ \\ context! >?
                              system:?vocid@ context! ;

*: VOC-CUR:  ( 'vocname' )
  -find-required system:comp? ?exit< #, \\ system:?vocid@ \\ current! >?
                              system:?vocid@ current! ;

end-module FORTH
