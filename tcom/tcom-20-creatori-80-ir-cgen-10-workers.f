;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; directly included from "tcom-20-creatori-80-ir-cgen.f"
;; codegen handlers for various internal nodes
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main workers part

extend-module WORKERS

;; workers are called with `curr-node` set to the right node.

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; entry and exit nodes

;; ir-nonrec-entry
:noname
  xasm:TOS-in-HL!
  xasm:pop-bc
  0 xasm:bc->(nn)
  xasm:$here 2- curr-node node:zx-patch:! ;; this will be patched in exit
  xasm:reset
; ->special-compiler: ir-nonrec-entry
:noname
  curr-node node:zx-patch dup -0?error" ICE: nonrec-e/e fucked!"
  tail node:zx-patch dup -0?error" ICE: nonrec-e/e fucked!"
  ( entry exit )
  swap zx-w! ;
->special-fixup: ir-nonrec-entry

;; ir-nonrec-exit
:noname
  xasm:restore-tos-hl
  xasm:$here 1+ curr-node node:zx-patch:! ;; this will be patched in exit
  0 xasm:jp-#
  xasm:reset
; ->special-compiler: ir-nonrec-exit


;; ir-rec-entry
:noname
  xasm:TOS-in-HL!
  xasm:pop-bc
  [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
    xasm:dec-iy xasm:dec-yl
  [ELSE]
    xasm:dec-iy xasm:dec-iy
  [ENDIF]
  0 xasm:c->(iy+#)
  1 xasm:b->(iy+#)
  xasm:reset
; ->special-compiler: ir-rec-entry

;; ir-rec-exit
:noname
  xasm:restore-tos-hl
  0 xasm:(iy+#)->c
  1 xasm:(iy+#)->b
  [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
    xasm:inc-yl xasm:inc-iy
  [ELSE]
    xasm:inc-iy xasm:inc-iy
  [ENDIF]
  xasm:push-bc
  xasm:ret
  xasm:reset
; ->special-compiler: ir-rec-exit


;; ir-noexit-entry
:noname
  xasm:pop-af
  xasm:reset
; ->special-compiler: ir-noexit-entry

;; ir-noexit-exit
:noname
  xasm:reset
; ->special-compiler: ir-noexit-exit


;; ir-recurse
:noname
  curr-node-spfa-ref dup 0?error" IR-ICE: recurse bug!"
  shword:zx-begin dup -?error" IR-ICE: recurse bug!"
  xasm:restore-tos-hl
  xasm:call-#
; ->special-compiler: ir-recurse


;; ir-tail-call
:noname
  error" tail calls are not supported (yet?)"
; ->special-compiler: ir-tail-call


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; execute the vector

;; ir-walit:exec-vect
;; spfa-ref: word
:noname
  curr-node-spfa-ref -1 compile-zx-call-spfa-with-ofs-noreg
; ->special-compiler: ir-walit:exec-vect


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ROM floating point support

;; ir-fp-start
:noname
  xasm:push-tos
  xasm:push-iy
  xasm:restore-iy
  $28 xasm:rst-n
  xasm:TOS-in-HL!
  xasm:reset
; ->special-compiler: ir-fp-start

;; ir-fp-end
:noname
  $38 xasm:byte, ;; end-calc
  xasm:reset
  xasm:pop-iy
  xasm:TOS-in-HL!
  xasm:pop-tos
; ->special-compiler: ir-fp-end

;; ir-fp-opcode
;; value: opcode
:noname
  curr-node node:value xasm:byte,
; ->special-compiler: ir-fp-opcode


end-module WORKERS
