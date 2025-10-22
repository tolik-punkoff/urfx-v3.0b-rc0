;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; define target VECT words
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


|: (tgt-does-vector)
  ?comp-target (shadow-tgt-cfa@) tgt-cfa>pfa
  Succubus:high:call-[addr] ;

: tgt-vector-this  ( tgt-quan-pfa )
  ['] (tgt-does-vector) vocobj:?this
  (shadow-tgt-cfa@) tgt-cfa>pfa ;

module tgt-vector-methods
<disable-hash>
*: !
  ?in-target tgt-vector-this system:comp? ?exit<
    Succubus:low:dstack>cpu
    Succubus:low:store-[addr],ebx
    Succubus:high:pop-tos >?
  tcom:! ;
*: @
  ?in-target tgt-vector-this system:comp? ?exit<
    Succubus:high:push-tos-kill
    Succubus:low:load-ebx-[addr] >?
  tcom:@ ;
end-module tgt-vector-methods

: (mk-tgt-new-vector)  \ name
  parse-name
  2dup tgt-does-cfa (tgt-create-tgt-word-var-align)
  tgt-forwards:tgt-(vector-doer)-doer:tgt-latest-doer!
  tgt-wflag-immediate tgt-latest-ffa-or!
  tgt-(vector-vocid) dup not?< drop
    tgt-vector-vocid-fixups tgt-convert-latest-to-vocobj-future
  || tgt-convert-latest-to-vocobj >? ;

: tgt-new-vector  \ name
  (mk-tgt-new-vector)
  tgt-forwards:tgt-(notimpl)-cfa:,
  ['] (tgt-does-vector) vocid: tgt-vector-methods (tgt-mk-rest-vocid) ;

: tgt-new-vector-noop  \ name
  (mk-tgt-new-vector)
  tgt-forwards:tgt-(noop)-cfa:,
  ['] (tgt-does-vector) vocid: tgt-vector-methods (tgt-mk-rest-vocid) ;

tcf: vect  system:?exec tgt-new-vector ;tcf
tcf: vect-empty  system:?exec tgt-new-vector-noop ;tcf

;; vector vocid
tcf: (vector-vocid)  ?in-target tgt-(vector-vocid) tgt-#, ;tcf
