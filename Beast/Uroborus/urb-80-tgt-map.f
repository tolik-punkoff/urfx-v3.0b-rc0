;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; write code map
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(*
: tgt-find-word-by-cfa  ( cfa-xt-va -- nfa-xt-va TRUE // FALSE )
  tgt-xfa-va << tcom:@ dup not?v| 2drop false |?
    2dup tgt-xfa>cfa = not?^||
  else| drop tgt-cfa>nfa true >> ;

: x86-tgt-find-name  ( cfa-xt-va -- addr count // dummy 0 )
  tgt-find-word-by-cfa not?exit< pad 0 >?
  tcom:>real idcount ;
*)

: tgt-write-map-file
  tgt-map-file not?exit
  image-name@ pad$:! " .map" pad$:+ pad$:@
  endcr 2dup ." writing map file: " type cr
  base @ >r hex
  file:create >r
  tgt-xfa-va << tcom:@ dup not?v||
    ^| dup tgt-xfa>cfa
       dup <# bl #hold # # # # # # # # #> r@ file:write
       dup dup tgt-cfa>wlen tcom:@ + <# bl #hold # # # # # # # # #> r@ file:write
       dup tgt-cfa>wlen tcom:@ <# " ) " #holds # # # # # # # # " (" #holds #> r@ file:write
       dup tgt-cfa>nfa tcom:>real idcount r@ file:write
       " \n" r@ file:write
       drop | >> drop
  r> file:close  r> base ! ;
