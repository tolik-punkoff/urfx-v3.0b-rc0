;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IR code superinstruction manual rules
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM
extend-module IR
extend-module OPT


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; unconditional branch to the next node optimiser

: opt-"BRANCH"
  OPT-OPTIMIZE-BRANCHES? not?exit
  curr-node dup node:ir-dest
  swap node:next = not?exit
  " BRANCH to the next instruction -> removed" .sopt-br-notice
  free-curr-node
  check-labels! ;; in case the label is not used anymore
  was-optim! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FOR/DO optimisers

: opt-"(FOR)"
  OPT-OPTIMIZE-SUPER? not?exit
  ;; lit (FOR) -> lit (FOR8)  (if possible)
  prev-node node-lit? not?exit
  dup hi-byte ?exit< drop >?
  lo-byte 0?exit
  [ OPT-REPORTS? ] [IF]
    " LIT:" pad$:! prev-node node:value pad$:#s
    "  (FOR) -> LIT:" pad$:+ prev-node node:value pad$:#s
    "  (FOR8)" pad$:+
    pad$:@ .sopt-notice
  [ENDIF]
  curr-node node:ir-dest
  (opt-zx-"(FOR8)") replace-curr-node-spfa
  curr-node node:ir-dest:!
  was-optim! ;

: opt-"(FOR8)"
  OPT-OPTIMIZE-SUPER? not?exit
  ;; lit (FOR8) -> lit (FOR8:LIT)  (if possible)
  prev-node node-lit? not?exit lo-byte
  dup 0?exit< drop >?
  [ OPT-REPORTS? ] [IF]
    " LIT:" pad$:! dup pad$:#s
    "  (FOR8) -> (FOR8:LIT:" pad$:+
    dup pad$:#s " )" pad$:+
    pad$:@ .sopt-notice
  [ENDIF]
  free-prev-node
  (opt-zx-"(FOR8:LIT)") new-lit-node-spfa
  replace-curr-node
  was-optim! ;


end-module OPT
end-module IR
end-module TCOM
