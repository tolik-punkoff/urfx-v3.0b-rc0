;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; directly included from "tcom-20-creatori-80-ir-cgen.f"
;; loops
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utilities for loop IR nodes

0 quan cg-current-for-node

: push-curr-loop
  [ 0 ] [IF]
    endcr ." LOOP-PUSH: " curr-node node:spfa shword:self-cfa dart:cfa>nfa debug:.id cr
  [ENDIF]
  cg-current-for-node curr-node node:prev-loop:!
  curr-node cg-current-for-node:! ;

: pop-loop
  cg-current-for-node dup 0?error" ICEFUCK!"
  [ 0 ] [IF]
    endcr ." LOOP-POP: " cg-current-for-node node:spfa shword:self-cfa dart:cfa>nfa debug:.id cr
  [ENDIF]
  node:prev-loop cg-current-for-node:! ;


: (?good-loop-start)  ( node^ )
  dup 0?error" loop operator is used out of the loop"
  node:spfa
  dup zsys: (DO) dart:cfa>pfa = ?exit< drop >?
  dup zsys: (FOR) dart:cfa>pfa = ?exit< drop >?
  dup zsys: (FOR8) dart:cfa>pfa = ?exit< drop >?
  dup zsys: (FOR8:LIT) dart:cfa>pfa = ?exit< drop >?
  drop error" not a loop node!" ;

: (loop-node-for8?)  ( node^ )
  dup (?good-loop-start)
  ir:node:spfa
  dup opt:(opt-zx-"(FOR8)") =
  swap opt:(opt-zx-"(FOR8:LIT)") = or ;

: (loop-node-for?)  ( node^ )
  dup (?good-loop-start)
  ir:node:spfa
  opt:(opt-zx-"(FOR)") = ;

: (loop-node-do?)  ( node^ )
  dup (?good-loop-start)
  ir:node:spfa
  opt:(opt-zx-"(DO)") = ;


: (loop#-for8?)  ( loop# -- for8? )
  cg-current-for-node dup 0?error" ICEFUCK!"
  dup (?good-loop-start)
  swap 1- for dup (?good-loop-start) ir:node:prev-loop endfor
  (loop-node-for8?) ;

: (loop#-for?)  ( loop# -- for8? )
  cg-current-for-node dup 0?error" ICEFUCK!"
  dup (?good-loop-start)
  swap 1- for dup (?good-loop-start) ir:node:prev-loop endfor
  (loop-node-for?) ;

: (calc-loop-index)  ( loop# -- ridx )
  0 cg-current-for-node dup 0?error" ICEFUCK!"
  dup (?good-loop-start)
  rot for ( counter loop-node^ )
    dup (?good-loop-start)
    dup (loop-node-for8?) ?< 1 || 2 >?
    rot + swap ir:node:prev-loop
  endfor drop ;

: (calc-loop#-drop)  ( loop# -- ridx )
  1+ (calc-loop-index) ;


extend-module WORKERS


|: (ir-loop-run-prim)  ( shadow-cfa )
  dart:cfa>pfa shword:ir-compile execute-tail ;

;; ir-loop-i
;; value: loop index
:noname
  curr-node node:value dup >r (calc-loop-index)
  curr-node node:value:!
  r@ (loop#-for8?) ?exit<
    zsys: (<n>FOR8-I) (ir-loop-run-prim)
    r> curr-node node:value:! >?
  r@ (loop#-for?) ?exit<
    zsys: (<n>FOR-I) (ir-loop-run-prim)
    r> curr-node node:value:! >?
  zsys: (<n>R@) (ir-loop-run-prim)
  r> curr-node node:value:!
; ->special-compiler: ir-loop-i

;; ir-loop-i'
;; value: loop index
:noname
  curr-node node:value dup >r (calc-loop-index)
  curr-node node:value:!
  r@ (loop#-for8?) ?exit<
    zsys: (<n>R1C@) (ir-loop-run-prim)
    r> curr-node node:value:! >?
  curr-node node:value:1+!
  zsys: (<n>R@) (ir-loop-run-prim)
  r> curr-node node:value:!
; ->special-compiler: ir-loop-i'

;; ir-unloop
;; value: loop index
:noname
  curr-node node:value dup >r (calc-loop#-drop)
  curr-node node:value:!
  zsys: (RDROP<n>) (ir-loop-run-prim)
  r> curr-node node:value:!
; ->special-compiler: ir-unloop

;; ir-loop-irev
;; value: loop index
:noname
  curr-node node:value dup >r (calc-loop-index)
  curr-node node:value:!
  r@ (loop#-for8?) ?exit<
    zsys: (<n>FOR8-IREV) (ir-loop-run-prim)
    r> curr-node node:value:! >?
  r@ (loop#-for?) ?exit<
    zsys: (<n>FOR-IREV) (ir-loop-run-prim)
    r> curr-node node:value:! >?
  r> curr-node node:value:!
  error" \'IREV\' cannot be used outside of \'FOR\'!"
; ->special-compiler: ir-loop-irev


end-module WORKERS
