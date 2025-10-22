;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; branch chains
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; branch chain compilers/resolvers

;; append label to IR code (backward jump)
: zx-<mark    ( -- ir-label )
  ir:append-restore-tos
  ir:lbl-backward ir:mk-label-and-append ;

;; label will be added later, so record previous branch IR node address to path in resolver.
: zx-chain>   ( ir-chain -- ir-chain-new )
  ir:?tail tuck ir:node:ir-dest:! ;

;; start new IR chain.
: zx-mark>    ( -- chain-new )
  0 zx-chain> ;

;; resolve backward jump.
;; this expects the ir-dest node to be the label.
: zx-<resolve ( ir-dest )
  dup 0?error" '<RESOLVE' what?"
  \ dup ir:node:lbl-used?:!t  ;; mark the label as used
  ir:?tail ir:node:ir-dest:! ;

;; resolve forward branch chain to the newly created label.
: zx-resolve> ( ir-chain )
  dup 0?exit< drop >? -- no jumps, so we don't need any label
  ir:append-restore-tos
  ir:lbl-forward ir:mk-label-and-append ;; destination label
  swap << ( ir-label ir-chain )
    dup ir:node:ir-dest nrot ;; next entry in chain
    2dup ir:node:ir-dest:!   ;; patch label reference
    drop swap
    dup ?^||
  else| drop >>
  ( ir-label )
  \ ir:node:lbl-used?:!t  ;; mark the label as used
  drop ;


end-module
