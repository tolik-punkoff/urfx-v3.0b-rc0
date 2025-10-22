;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; define target CHAINED words
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


|: (tgt-does-chained)
  ?comp-target (shadow-tgt-cfa@) tgt-cc\, ;

: tgt-chained-this  ( tgt-chained-pfa )
  ['] (tgt-does-chained) vocobj:?this
  (shadow-tgt-cfa@) tgt-cfa>pfa ;

module tgt-chain-methods
*: !
  ?in-target system:?comp
  tgt-chained-this tgt-#,
  tgt-forwards:tgt-(chain-tail)-cfa tgt-cc\, ;
end-module tgt-chain-methods

: tgt-chained  \ name
  parse-name
  2dup tgt-does-cfa (+ (tgt-create-tgt-word-4) +) (tgt-create-tgt-word-create-align)
  tgt-forwards:tgt-(chain-doer)-doer:tgt-latest-doer!
  tgt-(chain-vocid) dup not?< drop
    tgt-chain-vocid-fixups tgt-convert-latest-to-vocobj-future
  || tgt-convert-latest-to-vocobj >?
  ;; build "chained" PFA
  ( head) 0 tcom:, ( tail) 0 tcom:,
  ['] (tgt-does-chained) vocid: tgt-chain-methods (tgt-mk-rest-vocid) ;

tcf: chained
  ?exec-target tgt-chained ;tcf
