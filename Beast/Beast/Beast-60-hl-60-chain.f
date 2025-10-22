;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CHAIN implementation
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
usage:

chained chain-test

:noname 2 bl #emit ." chain first\n" do-exit ?< do-exit chain-res! >? ; chain chain-test
:noname 4 bl #emit ." chain second\n" ; chain chain-test
:noname 1 bl #emit ." chain before-first\n" ; prechain chain-test

executing "chain-test" return chain result set with "chan-res!", or 0.
setting chain result to non-zero prevent execution of the following
chained words (but doesn't immediately exit the current one).

it is ok to use "exit" in chained word.


chain item uses 2 dwords: next, action-cfa
chained word points to the first, and to the last.
*)


extend-module CHAIN-SUPPORT

0 quan (CURR-CHAIN-RES)

;; chain list: next, action-cfa
: (CHAIN-DOER)  ( pfa -- cres )
\ endcr ." CHAIN-DOER!\n"
  (curr-chain-res) >r (curr-chain-res):!0
  << @ dup not?v|| dup >r 4+ @?execute r> (curr-chain-res) not?^|| v|| >> drop
  (curr-chain-res) r> (curr-chain-res):! ;


extend-module SYSTEM

: ?CHAINED  ( cfa )
  doer@ ['] chain-support:(chain-doer) = not?error" not a chained word" ;

: MK-CHAINED  ( addr count )
  ['] chain-support:(chain-doer) vocid: chain-support:(chain-mtx) vocobj:mk-vocid
  ( head ) 0 , ( tail ) 0 , ;

end-module SYSTEM


|: CHAIN-FIRST  ( action-cfa chainer-pfa )
  here over ! 4+ here swap !
  ( next) 0 , ( action-cfa) , ;

: CHAIN-TAIL  ( action-cfa chainer-pfa )
  align-here-4 dup @ not?exit< chain-first >?
  4+ dup @ here swap !  here swap !
  ( next) 0 , ( action-cfa) , ;

: CHAIN-HEAD  ( action-cfa chainer-pfa )
  align-here-4 dup @ not?exit< chain-first >?
  dup @ here rot ! ( next) , ( action-cfa) , ;

: CHAIN-RESET  ( chainer-pfa )  0 av-!++ !0 ;

: CHAIN-SAVE    ( buffer chainer-pfa )  swap 8 cmove ;
: CHAIN-RESTORE ( buffer chainer-pfa )  8 cmove ;

: -CHAINED  ( -- pfa )
  -find-required dup system:?chained dart:cfa>pfa ;

: CHAIN-DO,  ( run-cfa chain-pfa )  system:comp? ?< #, \, || swap execute-tail >? ;

: CHAINED-THIS@  ( chain-pfa )
  ws-vocab-cfa dup system:?chained dart:cfa>pfa ;

extend-module (CHAIN-MTX)
!*: !     ( run-cfa )  ['] chain-tail chained-this@ chain-do, ;
!*: +!    ( run-cfa )  ['] chain-head chained-this@ chain-do, ;
!*: !latest   system:latest-cfa ['] chain-tail chained-this@ chain-do, ;
!*: +!latest  system:latest-cfa ['] chain-head chained-this@ chain-do, ;
!*: reset  ['] chain-reset chained-this@ chain-do, ;
!*: >buf   ( buf )  ['] chain-save chained-this@ chain-do, ;
!*: buf>   ( buf )  ['] chain-restore chained-this@ chain-do, ;
end-module (CHAIN-MTX)

end-module CHAIN-SUPPORT


extend-module FORTH

8 constant CHAIN-#BUF

: CHAINED  ( 'name' )  parse-name system:mk-chained ;

;; non-zero means "do not execute other chains, exit"
: CHAIN-RES!  ( value )  chain-support:(curr-chain-res):! ;

end-module FORTH
