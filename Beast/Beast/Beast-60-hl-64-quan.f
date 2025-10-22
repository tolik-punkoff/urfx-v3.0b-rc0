;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; QUAN, VECT
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module QUAN-SUPPORT
using system

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; QUAN

: (XQUAN-DOES)  ( pfa )
  comp? ?exit< #, \\ forth:@ >? @ ;

: XQUAN?  ( cfa -- flag )
  dup does? not?exit< drop false >?
  doer@ ['] (xquan-does) = ;

extend-module (QUAN-MTX)
|: XQUAN-THIS  ( quan-pfa )
  ws-vocab-cfa dup xquan? not?error" invalid quan method call"
  dart:cfa>pfa ;

!*: !   ( value )
  xquan-this system:comp? ?exit< #, \\ forth:! >? forth:! ;
!*: +!  ( value )
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu
    Succubus:low:add-[addr]-ebx
    Succubus:high:pop-tos >?
  forth:+! ;
!*: -!  ( value )
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu
    Succubus:low:sub-[addr]-ebx
    Succubus:high:pop-tos >?
  forth:-! ;
!*: 1+! ( value )
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    Succubus:low:inc-[addr] >?
  forth:1+! ;
!*: 1-! ( value )
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    Succubus:low:dec-[addr] >?
  forth:1-! ;
!*: 2+!
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    2 Succubus:low:add-[addr]-value >?
  forth:2+! ;
!*: 2-!
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    2 Succubus:low:sub-[addr]-value >?
  forth:2-! ;
!*: 4+!
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    4 Succubus:low:add-[addr]-value >?
  forth:4+! ;
!*: 4-!
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    4 Succubus:low:sub-[addr]-value >?
  forth:4-! ;
!*: 8+!
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    8 Succubus:low:add-[addr]-value >?
  forth:8+! ;
!*: 8-!
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    8 Succubus:low:sub-[addr]-value >?
  forth:8-! ;
!*: !0
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    0 Succubus:low:store-[addr]-value >?
  forth:!0 ;
!*: !1
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    1 Succubus:low:store-[addr]-value >?
  forth:!1 ;
!*: !t
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    true Succubus:low:store-[addr]-value >?
  forth:!t ;
!*: !f
  xquan-this system:comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    false Succubus:low:store-[addr]-value >?
  forth:!f ;
!*: ^
  xquan-this [\\] {#,} ;
end-module (QUAN-MTX)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; VECT

: (XVECTOR-DOES)  ( pfa )
  system:comp? ?exit<
    Succubus:high:call-[addr] >?
  @execute-tail ;

: XVECTOR?  ( cfa -- flag )
  dup system:does? not?exit< drop false >?
  system:doer@ ['] (xvector-does) = ;

: ?XVECTOR  ( vector-cfa ) xvector? not?error" vector expected" ;

extend-module (VECTOR-MTX)
|: XVECTOR-THIS  ( quan-pfa )
  ws-vocab-cfa dup xvector? not?error" invalid vector method call" dart:cfa>pfa ;

!*: !
  xvector-this system:comp? ?exit<
    Succubus:low:dstack>cpu
    Succubus:low:store-[addr],ebx
    Succubus:high:pop-tos >?
  forth:! ;
!*: @
  xvector-this system:comp? ?exit<
    Succubus:high:push-tos-kill
    Succubus:low:load-ebx-[addr] >?
  forth:@ ;
!*: !undefined
  xvector-this system:comp? ?exit<
    ['] (notimpl) Succubus:low:store-[addr]-value >?
  ['] (notimpl) forth:swap forth:! ;
!*: !empty
  xvector-this system:comp? ?exit<
    ['] noop Succubus:low:store-[addr]-value >?
  ['] noop forth:swap forth:! ;
!*: ^
  xvector-this [\\] {#,} ;
end-module (VECTOR-MTX)

end-module QUAN-SUPPORT


extend-module FORTH
using system
using quan-support

: QUAN  ( value )  ( 'name' )
  parse-name ['] (xquan-does) (quan-vocid)
  vocobj:mk-vocid immediate ( value) , ;

: VECTORED  ( cfa )  ( 'name' )
  parse-name ['] (xvector-does) (vector-vocid)
  vocobj:mk-vocid immediate ( value) , ;

: VECT-EMPTY ( 'name' )  ['] noop vectored ;
: VECT       ( 'name' )  ['] (notimpl) vectored ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compatibility with some my old code

*:  TO  ( n )  ( 'name' )   " !" vocobj:-call ;
*: +TO  ( n )  ( 'name' )  " +!" vocobj:-call ;
*: -TO  ( n )  ( 'name' )  " -!" vocobj:-call ;

end-module FORTH
