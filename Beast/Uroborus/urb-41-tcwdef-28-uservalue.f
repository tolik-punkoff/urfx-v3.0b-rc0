;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; define target USER-QUAN words
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


|: (tgt-does-uservalue)
  ?in-target system:?comp (shadow-tgt-cfa@) tgt-cc\, ;

: tgt-uservalue-this  ( tgt-quan-pfa )
  ?in-target ['] (tgt-does-uservalue) vocobj:?this
  (shadow-tgt-cfa@) tgt-cfa>pfa tcom:@ ;


module tgt-uservalue-methods
<disable-hash>
\ *: @  ?in-target tgt-uservalue-this (tgt-does-quan) ;
*: ^
  tgt-uservalue-this system:?comp
  Succubus:high:push-tos-kill
  Succubus:low:lea-ebx-[uv-addr] ;
*: OFFSET
  tgt-uservalue-this system:?comp
  tgt-#, ;
*: !   ( value )
  tgt-uservalue-this system:?comp
  Succubus:low:dstack>cpu
  Succubus:low:store-[uv-addr]-ebx
  Succubus:high:pop-tos ;
*: 1+!
  tgt-uservalue-this system:?comp
  Succubus:low:inc-[uv-addr] ;
*: 1-!
  tgt-uservalue-this system:?comp
  Succubus:low:dec-[uv-addr] ;
*: !0
  tgt-uservalue-this system:?comp
  0 Succubus:low:store-[uv-addr]-value ;
*: !1
  tgt-uservalue-this system:?comp
  1 Succubus:low:store-[uv-addr]-value ;
*: !t
  tgt-uservalue-this system:?comp
  true Succubus:low:store-[uv-addr]-value ;
*: !f
  tgt-uservalue-this system:?comp
  false Succubus:low:store-[uv-addr]-value ;
end-module tgt-uservalue-methods


: tgt-uservalue  ( va )  \ name
  ll@ (mt-area-start) - ( convert to user-relative )
  >r parse-name
  2dup tgt-uservalue-cfa (tgt-create-tgt-word-var-align)
  tgt-(uservalue-vocid) dup not?< drop
    tgt-userval-vocid-fixups tgt-convert-latest-to-vocobj-future
  || tgt-convert-latest-to-vocobj >?
  r> tcom:, ( value )
  ['] (tgt-does-uservalue) vocid: tgt-uservalue-methods (tgt-mk-rest-vocid) ;
