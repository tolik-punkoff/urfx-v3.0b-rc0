;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; word finding mechanics
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module SYSTEM
using dart

;; allow pseudovocs "@@FORTH", "@@CONTEXT", "@@CURRENT", "@@UP"?
;; WARNING: removed for now; always allowed
\ true user-quan WS-ALLOW-PSEUDO?

;; name resolver sets this to the last vocab word searched.
;; i.e. for "wl:word" it will be cfa of "wl".
;; it is set even for failed search.
;; it is also set when calling vocid "find-cfa".
\ 0 user-quan WS-VOCAB-CFA

;; this is set to vocid of the wordlist where last "find" succeed.
;; not set for "find-in-vocid".
;; reset on failure.
;; used to call "execcomp".
\ 0 user-quan WS-VOCID-HIT

;; can be used to add/override pseudo names.
;; pseudo name always starts with "@@".
;; return 0 vocid to disable standard checks.
0 quan WS-PSEUDO?-CFA  ( addr count -- vocid TRUE // FALSE )


;; [-65535..65535] is not a good vocid. used as special stack mark.
: GOOD-VOCID?  ( vocid -- bool )  -65535 65536 within not ;


module FINDER
<disable-hash>

;; used in "@UP"
0 quan (WS-UP-LEVEL)  (private)


;; WARNING! private words expect validated args

;; high bit of name length is "case-sensitive compare"
: NAME=  ( addr count nfa -- flag )
  2dup c@ 127 and = not?exit< 3drop false >?
\ ." CMP" dup c@ 128 >= not?< ." -CI" >? ." : |" dup debug:.id ." | |" >r 2dup type r> ." |\n"
  dup 1 under+ c@ 128 < ?exit< swap string:mem=ci >? swap string:mem= ;

;; doesn't check parent vocids
: (FIND-IN-ONE-VOCID-NOHASH)  ( addr count skip-hidden? vocid -- cfa-xt TRUE // FALSE )
  2over hash-name >r vocid>latest  ( addr count skiphid? lfa | hash )
  << @ dup not?v| rdrop 4drop false |?
     dup lfa>hfa @ r@ <> ?^||
     over cand dup lfa>ffa @ wflag-private and ?^||
     dup >r 2over r> lfa>nfa name= not?^||
  else| rdrop >r 3drop true r> lfa>cfa swap >> ;

;; doesn't check parent vocids
: (FIND-IN-ONE-VOCID)  ( addr count skip-hidden? vocid -- cfa-xt TRUE // FALSE )
  [ tgt-disable-hash-find ] [IF] tcall (find-in-one-vocid-nohash)
  [ELSE]
  dup vocid-hashed? not?exit< (find-in-one-vocid-nohash) >?
  2over hash-name dup >r
  ( addr count skiphid? vocid hash | hash )
  hmask and over vocid-hashtbl@ +  ( addr count skiphid? vocid bfa | hash )
  << @ dup not?v| rdrop 4drop drop false |?
     dup bfa>hfa @ r@ <> ?^||
     2dup bfa>vfa @ <> ?^||
     >r over r> swap cand dup bfa>ffa @ wflag-private and ?^||
     >r 2over r@ bfa>nfa name= not?^| r> |?
  else| 4drop r> bfa>cfa rdrop true >> [ENDIF] ;

: (FIND-IN-VOCID)  ( addr count skip-hidden? vocid -- cfa-xt TRUE // FALSE )
  dup good-vocid? not?exit< 4drop false >?
  dup vocid-find-cfa@ ?execute-tail
  2over 2over (find-in-one-vocid) ?exit< >r 4drop r> true >?
  voc-parent-ofs + @
  recurse-tail ;

;; cut name up to ":" or "::"
: WSTART  ( addr count -- addr count TRUE // FALSE )
  \ over >r [char] : string:memchr ?exit< drop r@ swap r> - true >? rdrop 2drop false ;
  over swap [char] : string:find-ch not?exit< drop false >? true ;

: WREST  ( addr count -- addr count skiphidflag TRUE // FALSE )
  [char] : string:memchr not?exit< 2drop false >?
  string:/char dup -0?exit< 2drop false >?
  over c@ [char] : = ?< string:/char dup -0?exit< 2drop false >? false || true >? true ;

;; "@@FORTH"
: PSEUDO-FORTH?  ( addr count -- vocid TRUE // FALSE )
  wstart not?exit&leave
  7 = not?exit< drop false >? 2+
  " FORTH" string:mem=ci ?< vocid: forth true  vsp-depth (ws-up-level):! || false >? ;

;; "@@CURRENT" / "@@CONTEXT"
: PSEUDO-CUR/CTX?  ( addr count -- vocid TRUE // FALSE )
  wstart not?exit&leave
  9 = not?exit< drop false >? 2+
  dup " CONTEXT" string:mem=ci ?exit< nip context@ true  (ws-up-level):!0 >?
      " CURRENT" string:mem=ci ?exit< current@ true  vsp-depth (ws-up-level):! >?
  false ;

: PSEUDO-UP?  ( addr count -- vocid TRUE // FALSE )
    \ endcr ." UP? str=<" 2dup type ." >\n"
  wstart not?exit&leave
  4 = not?exit< drop false >? 2+
  " UP" string:mem=ci not?exit&leave
    \ endcr ." UP! level=" (ws-up-level) . ." depth=" nsp-depth 0.r cr
  (ws-up-level) vsp-depth u>= ?error" no more vocid up levels (0)"
  (ws-up-level) vsp-pick dup not?error" no more vocid up levels (1)"
  (ws-up-level):1+!
  true ;

: CHECK-PSEUDO-CB  ( addr count -- vocid TRUE // addr count FALSE )
  ws-pseudo?-cfa not?exit&leave
  2dup ws-pseudo?-cfa execute dup ?< 2swap 2drop >? ;

;; check for "@@FORTH", "@@CURRENT", "@@CONTEXT", "@@UP" pseudovocs
: STARTS-WITH-PSEUDO?  ( addr count -- vocid TRUE // FALSE )
  dup 3 < ?exit< 2drop false >?
  over w@ $4040 = not?exit< 2drop false >?
  check-pseudo-cb ?exit< dup not?< nip >? >?
  over 2+ c@ $20 or
  dup [char] f = ?exit< drop pseudo-forth? >?
  dup [char] u = ?exit< drop pseudo-up? >?
  [char] c = ?exit< pseudo-cur/ctx? >?
  2drop false ;

: CAN-BE-PSEUDO?  ( addr count -- flag )
  \ ws-allow-pseudo not?exit< 2drop false >?
  2 > ?< w@ $4040 = || drop false >? ;

;; recursive namespace search
: FIND-NS  ( addr count skip-hidden? vocid -- cfa-xt TRUE // FALSE )
  2>r 2dup wstart not?exit< 2rdrop 2drop false >?
  2r> dup ws-vocid-hit:! (find-in-vocid) not?exit< 2drop ws-vocid-hit:!0 false >? ( addr count cfa )
  dup vocid@ dup not?exit< 4drop ws-vocid-hit:!0 false >?
  dup ws-vocid-hit:!
  swap ws-vocab-cfa:!
  >r wrest not?exit< rdrop ws-vocid-hit:!0 false >?
  r> 2over 2over (find-in-vocid) ?exit< >r 4drop r> true >?
  recurse-tail ;

;; find with resolving
: FIND-RESV  ( addr count skip-hidden? vocid -- cfa-xt TRUE // FALSE )
  ws-vocid-hit:!0 ws-vocab-cfa:!0
  2over 2over (find-in-vocid) ?exit< >r ws-vocid-hit:! 3drop r> true >?
  2over can-be-pseudo? ?<
    2over starts-with-pseudo? ?< >r 2drop wrest not?exit< rdrop ws-vocid-hit:!0 false >?
                                 r> recurse-tail >?
  >?
  find-ns ;

end-module FINDER


;; given the vstack position, check if we've seen it before.
;; this is to avoid double calls.
|: VSTACK-CHECKED?  ( vidx vval -- bool )
  dup context@ = ?exit< 2drop true >?
  swap << ( vval vidx )
    1- dup -?v| 2drop false |?
    2dup vsp-pick = not?^| 1- |?
  else| 2drop true >> ;

;; iterate over context stack (vsp).
;; starts with "context@", and then iterates the stack.
;; stop at end-of-stack, or 0 item.
;; ignore items [-65535..65535] (they can be used as some special marks).
;; iterator should remove `vocid` if it returns 0 (continue).
;; otherwise it can leave anything on the stack before the result.
;; the stack has no additional elements when entering the iterator.
;; iter-cfa  ( ... vocid -- ... not-0 // ... 0 )
;; return 0 to continue, not-0 to stop.
: FOREACH-VSTACK  ( ... iter-cfa -- ... res // 0 )
  finder::(ws-up-level) >r
  >r  ( | [ws-up-level] iter-cfa )
  context@ good-vocid? ?<
    finder::(ws-up-level):!0
    context@ r@ execute dup ?exit< rdrop r> finder::(ws-up-level):! >? drop >?
  0 << ( vidx | [ws-up-level] iter-cfa )
    dup vsp-depth u>= ?v| drop rdrop 0 |?
    dup vsp-pick  ( vidx vvalue | iter-cfa )
    0 of?v| drop rdrop 0 |?
    dup good-vocid? not?^| drop 1+ |?  ;; just a special mark
    2dup vstack-checked? ?^| drop 1+ |?
    over 1+ finder::(ws-up-level):!
    r@ rot >r execute ( res | iter-cfa vidx )
    dup ?v| 2rdrop |? drop
  ^| r> 1+ | >>
  r> finder::(ws-up-level):! ;


: RUN-EXECCOMP  ( cfa vocid -- ... TRUE // cfa FALSE )
  dup not?exit system:vocid-execcomp-cfa@ ?execute-tail false ;


|: NOTFOUND-VSP-ITERATOR  ( addr count vocid -- addr count 0 // ... TRUE )
  vocid-notfound-cfa@ dup not?exit
  nrot 2dup 2>r rot execute
  dup ?exit< 2rdrop >?
  drop 2r> 0 ;

|: DOLITERAL-VSP-ITERATOR  ( lit vocid -- lit 0 // ... TRUE )
  vocid-literal-cfa@ ?execute-tail 0 ;

|: FIND-RESV-VSP-ITERATOR  ( addr count vocid -- addr count 0 // addr count cfa-xt TRUE )
  nrot 2dup 2>r rot ( addr count vocid | addr count )
  dup current@ <> swap ( addr count skip-hidden? vocid | addr count )
  finder:find-resv ( cfa-xt TRUE | addr count // FALSE | addr count )
  ?< 2r> rot true || 2r> 0 >? ;

end-module SYSTEM


;; call "NOTFOUND" handlers for wordlists in order.
;; the name of this word sux.
: FIND-TRY-NOTFOUND  ( addr count -- ... TRUE // addr count FALSE )
  dup -0?exit< false >?
  ['] system::notfound-vsp-iterator system:foreach-vstack ;

;; call "LITERAL" handlers for wordlists in order.
;; the name of this word sux.
: FIND-TRY-LITERAL  ( lit -- ... TRUE // lit FALSE )
  ['] system::doliteral-vsp-iterator system:foreach-vstack ;


;; no name resolving; doesn't modify "(ws-vocab-cfa)"
: VOCID-FIND  ( addr count vocid -- cfa-xt TRUE // FALSE )
  over 0<= over 0= or ?exit< 3drop false >?
  true swap system:finder:(find-in-vocid) ;
: FIND-IN-VOCID  vocid-find ;

;; no name resolving; doesn't modify "(ws-vocab-cfa)"
: VOCID-FIND-ANY  ( addr count vocid -- cfa-xt TRUE // FALSE )
  over 0<= over 0= or ?exit< 3drop false >?
  false swap system:finder:(find-in-vocid) ;
: FIND-IN-VOCID-WITH-PRIVATE  vocid-find-any ;


;; main entry point -- does name resolving, sets/resets "(ws-vocab-cfa)"
: FIND  ( addr count -- cfa-xt TRUE // FALSE )
  dup -0?exit< ws-vocid-hit:!0 ws-vocab-cfa:!0 2drop false >?
  ['] system::find-resv-vsp-iterator system:foreach-vstack
  ( addr count FALSE // addr count cfa-xt TRUE )
  ?< nrot 2drop true || 2drop false >? ;


: FIND-REQUIRED  ( addr count -- cfa-xt )
  dup 0> not?error" word name expected"
  2dup find ?exit< nrot 2drop >?
  2dup type ."  -- wut?\n"
  " \'" pad$:! pad$:+ " \' what?" pad$:+
  pad$:@ error ;


extend-module SYSTEM

-1 constant REDEFINE-WARN-ALL
 0 constant REDEFINE-SILENT
 1 constant REDEFINE-DISABLE-PUBLIC
 2 constant REDEFINE-DISABLE-ALL

REDEFINE-DISABLE-ALL quan REDEFINE-MODE

: REDEFINE-CHECKER  ( addr count )
  redefine-mode not?exit< 2drop >?
  2dup current@ vocid-find-any not?exit< 2drop >? drop
  redefine-mode +?<
   redefine-disable-public = ?<
      protected? ?exit<
        " OOPS! cannot redefine protected word \'" pad$:!
        pad$:+ " \'" pad$:+
        pad$:@ error >?
    || drop
      " OOPS! cannot redefine word \'" pad$:!
      pad$:+ " \'" pad$:+
      pad$:@ error >?
  || drop >?
  endcr ." WARNING: redefining word \'" type ." \' at "
  (segfault):(.inc-pos) @execute cr ;

end-module SYSTEM
