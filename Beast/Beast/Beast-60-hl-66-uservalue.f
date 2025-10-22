;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; USER-VALUE
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module USERVALUE-SUPPORT

(*
|: (USER-VALUE-DOES)  ( pfa )
  @ comp? ?exit<
    high:push-tos
    low:load-ebx-[uv-addr] >?
  user-area@ ;

: USER-VALUE?  ( cfa -- flag )
  dup does? not?exit< drop false >?
  doer@ ['] (user-value-does) = ;
*)

extend-module (USERVALUE-MTX)
using system

|: USERVALUE-THIS  ( uval-pfa )
  ws-vocab-cfa dup user-value? not?error" invalid user value method call"
  dart:cfa>pfa @ ;

*: ^
  uservalue-this ?comp
  Succubus:high:push-tos-kill
  Succubus:low:lea-ebx-[uv-addr] ;
*: OFFSET
  uservalue-this ?comp
  #, ;
*: !   ( value )
  uservalue-this ?comp
  Succubus:low:dstack>cpu
  Succubus:low:store-[uv-addr]-ebx
  Succubus:high:pop-tos ;
*: 1+!
  uservalue-this ?comp
  Succubus:low:inc-[uv-addr] ;
*: 1-!
  uservalue-this ?comp
  Succubus:low:dec-[uv-addr] ;
*: !0
  uservalue-this ?comp
  0 Succubus:low:store-[uv-addr]-value ;
*: !1
  uservalue-this ?comp
  1 Succubus:low:store-[uv-addr]-value ;
*: !t
  uservalue-this ?comp
  true Succubus:low:store-[uv-addr]-value ;
*: !f
  uservalue-this ?comp
  false Succubus:low:store-[uv-addr]-value ;
end-module (USERVALUE-MTX)

end-module USERVALUE-SUPPORT
