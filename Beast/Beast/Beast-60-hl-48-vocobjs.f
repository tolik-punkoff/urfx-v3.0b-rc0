;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple way to create vocabs with custom "does>".
;; this can be used as a kind of OOP. see "system:ws-vocab-cfa".
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module VOCOBJ
<disable-hash>

: MK-VOCID  ( addr count doer-cfa vocid )
  swap >r system:mk-builds-vocab
  system:latest-cfa r> system:!doer ;

: MK  ( addr count doer-cfa -- vocid )
  system:mk-wordlist-nohash dup >r mk-vocid r> ;

;; this will destroy "system:ws-vocab-cfa"
: CALL  ( addr count vocobj-cfa )
  dup >r system:?vocid@ find-in-vocid not?error" method not found"
  ws-vocab-cfa >loc
    r> ws-vocab-cfa:! execute
  loc> ws-vocab-cfa:! ;

;; this will destroy "system:ws-vocab-cfa"
: -CALL  ( addr count )  ( 'name' )
  -find-required call ;

: THIS-CFA  ( -- obj-cfa )
  ws-vocab-cfa dup not?error" vocobject where?"
  dup system:?vocobj ;

: THIS?  ( doer-cfa -- flag )
  this-cfa system:doer@ = ;

: ?THIS  ( doer-cfa -- obj-pfa )
  this-cfa
  tuck system:doer@ = not?error" invalid vocobject class"
  dart:cfa>pfa ;

: THIS  ( -- obj-pfa )
  this-cfa dart:cfa>pfa ;

end-module VOCOBJ


extend-module SYSTEM

\ compatibility with the older code
: MK-VOCID-VOCOBJECT  ( addr count doer-cfa vocid )  vocobj:mk-vocid ;
: MK-VOCOBJECT  ( addr count doer-cfa -- vocid )  vocobj:mk ;
: VOCOBJECT-CALL  ( addr count vocobj-cfa )  vocobj:call ;
: -VOCOBJECT-CALL  ( addr count )  ( 'name' )  vocobj:-call ;
: VOCOBJECT-THIS-CFA  ( -- obj-cfa )  vocobj:this-cfa ;
: VOCOBJECT-THIS?  ( doer-cfa -- flag )  vocobj:this? ;
: ?VOCOBJECT-THIS  ( doer-cfa -- obj-pfa ) vocobj:?this ;
: VOCOBJECT-THIS  ( -- obj-pfa )  vocobj:this ;

end-module SYSTEM
