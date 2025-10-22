;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; colon, semicolon
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module SYSTEM

[[ tgt-save-stack-comments ]] quan DEBUG-SAVE-STACK-COMMENTS?

;; flag: 0 -- no; 1: until EOL; -1: parens
: DBG-SKIP-WORD-COMMENT  ( -- had-comments-flag )
  parse-name/none 1- ?exit< drop false >?
  c@ dup $5C = ?exit< drop skip-line 1 >?
  $28 = not?exit&leave
  $29 parse dup not?exit +?< 2drop false || 2drop true >? ;

: DBG-COLLECT-WORD-COMMENTS  ( -- addr count )
  skip-spaces (tib-in) >r
  dbg-skip-word-comment dup not?exit< r> nip false >?
  +?exit< r@ (tib-in) r> - >?
  ;; optional second comment
  (tib-in) >r  ( staddr st2addr )
  dbg-skip-word-comment ?< rdrop r@ (tib-in) || r1:@ r> >? r> - ;

: DEBUG-RECORD-COMMENT
  debug-save-stack-comments? not?exit
  can-extend-sfa? not?exit
  >in >r
  dbg-collect-word-comments string:-trailing 254 min
    \ ." comments: |" 2dup type ." |\n"
  dup ?< ( save length) dup hdr-here 1- c! ( save string) hdr-cstr,
  || 2drop >? r> >in:! ;


;; number of "USING" in current colon def
0 quan (colon-imports)

: START-COLON
  ctlid-colon [\\] ]
  (colon-imports):!0
  Succubus:start-colon ;

: START-ANON-COLON
  ctlid-colon [\\] ]
  (colon-imports):!0
  Succubus:start-anonymous-colon ;

: MK-COLON-BODY  set-smudge ( forth-cfa) -1 cfa, ;

: MK-COLON   ( addr count )  mk-header-forth mk-colon-body start-colon ;
: NEW-COLON  ?exec parse-name mk-colon debug-record-comment ;

: MK-NONAME  ?exec mk-header-noname mk-colon-body start-anon-colon ;


: SEMI-FINISH
  ;; pop imports
  (colon-imports) << 1- dup +0?^| pop-ctx |? else| drop >> (colon-imports):!0
  ;; do not analyze immediate words
  ;; need to do this before finishing the colon, to avoid
  ;; useless recording of optimiser info
  Succubus-noinline-mark +?< Succubus:cannot-inline
  || latest-ffa @ [ wflag-inline-allowed wflag-immediate or ] {#,} and
     wflag-immediate - not?< Succubus:cannot-inline >? >?
  Succubus:finish-colon
  Succubus-noinline-mark:!0
  [\\] [
  reset-smudge
  [ wflag-immediate
    wflag-protected or
    wflag-private or
    wflag-published or ] {#,} default-ffa and! ;

: SEMI  ?comp ctlid-colon ?pairs semi-finish ;

: RECTAIL,  ( brn-cfa )
  ?comp latest-cfa swap Succubus:branch-to ;

end-module SYSTEM


extend-module FORTH
using system

;; use this before colon definition to prevent inlining.
;; note that this will prevent inlining of the word that
;; is using "no-inline" word too.
*: {INLINE-BLOCKER}  ?exec wflag-inline-blocker default-ffa or! ;

;; the following colon word should not be inlined, but doesn't block inlining per se.
*: {NO-INLINE}       ?exec system:Succubus-noinline-mark:!1 ;

;; try to inline the following colon word even if it is too big
*: {AGGRESSIVE-INLINE}  ?exec system:Succubus-noinline-mark:!t ;

;; define new Forth words
*:  :  new-colon ;
*: |:  new-colon wflag-private latest-ffa-or! wflag-published latest-ffa-~and! ;
*: *:  new-colon wflag-immediate latest-ffa-or! ;
*: @:  new-colon wflag-published latest-ffa-or! wflag-private latest-ffa-~and! ;

*: :NONAME  ?exec mk-noname latest-cfa swap ;

;; transform last call to branch, do not compile "EXIT"
;; doesn't work for primitives, so in this case no tail call will be done
;; also, beware of loops and such: no checks!
*:  ;  semi ;
;; do not perform TCO
*: ^;  Succubus:end-basic-block semi ;

: CREATE  parse-name mk-create ;
: CREATE; 4 n-align-here ;
: ;CREATE 4 n-align-here ;

: VARIABLE  ( value )  parse-name mk-variable ;
: CONSTANT  ( value )  parse-name mk-constant ;

: USER-VARIABLE  ( value )
  (#user) @ 4+ 0 (#user-max) 1+ within not?error" too many user variables"
  (#user) @ parse-name mk-uservar
  (#user) @ user-area!  (#user) 4 +! ;

: <BUILDS  parse-name mk-builds ;

*: DOES>
  ?comp ctlid-colon ?pairs
  ['] (does>) <\, here >r 0 , \> ( word-start-patch-address )
  semi-finish
  mk-noname latest-cfa r> ! ;

*: RECURSE           ?comp Succubus:cannot-inline
                           latest-cfa Succubus:high:call ;
*: RECURSE-TAIL      Succubus:(branch) rectail, ;
*: ?RECURSE-TAIL     Succubus:(tbranch) rectail, ;
*: NOT?RECURSE-TAIL  Succubus:(0branch) rectail, ;
*: +?RECURSE-TAIL    Succubus:(+branch) rectail, ;
*: -?RECURSE-TAIL    Succubus:(-branch) rectail, ;
*: +0?RECURSE-TAIL   Succubus:(+0branch) rectail, ;
*: -0?RECURSE-TAIL   Succubus:(-0branch) rectail, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; for 64-bit numbers

: 2#,  ( lo hi -- ) swap [\\] {#,} [\\] {#,} ;
*: {2#,}  ( lo hi -- )  system:comp? ?< 2#, >? ;
: 2CONSTANT  ( lo hi -- ) ( 'name' )  <builds immediate , , does> 2@be [\\] {2#,} ;
: 2VARIABLE ( -- ) ( 'name' )  <builds 0 , 0 , does> ;

end-module FORTH


extend-module FORTH

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tail call utils

;; tail-call the next word (if possible)
*: TCALL  \ name
  system:?comp -find-required
  dup system:immediate? ?error" cannot tail-call immediate word"
  system:Succubus:cannot-inline
  system:Succubus:high:jump ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; aliases
;; compiling an alias will compile the original word. executing an alias
;; will simply jump to the original word CCFA. so aliases are essentially
;; code words with a built-in jump.

: MK-ALIAS-FOR  ( addr count orig-cfa )
  dup system:vocid@ ?error" aliases for vocobjects are not supported yet"
  dup >r system:cfa>ffa@ >r system:mk-header-code
  r> system:wflag-mask and ( system:wflag-alias or) system:latest-ffa-or!
  r> system:alias-cfa, ;

: ALIAS-FOR  \ oldword IS newword
  -find-required >r ;; we'll need cfa later
  parse-name 2 = swap w@ $20_20 or $73_69 = and not?error" `IS` expected"
  parse-name r> mk-alias-for ;

end-module FORTH
