;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; directly included from "tcom-20-creatori-80-ir-cgen.f"
;; labels and branches
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module WORKERS


: (branch-brfix)
  curr-node node:ir-dest dup 0?error" unresolved branch"
  node:zx-addr  ;; label address
  dup -0?error" IR-ICE: undefined label!"
  ( zx-addr )
  ;; do not patch end if `zx-patch` is negative
  curr-node node:zx-patch +0?<
    ;; use next node address -2
    dup curr-node node:next dup ?< node:zx-addr || drop zx-here >? 2-
      \ endcr ." ZX-PATCH: $" dup .hex8 ."  to $" over .hex8 cr
    zx-w!
  >?
  ( zx-addr )
  ;; also patch `zx-patch` if it is != 0
  dup curr-node node:zx-patch dup ?< abs zx-w! || 2drop >?
  ;; also patch `zx-patch2` if it is != 0
  dup curr-node node:zx-patch2 dup +?< zx-w! || 2drop >?
  drop ;

: (branch-brlabel)  ( -- ir-dest )
  curr-node node:ir-dest dup 0?error" unresolved branch" ;

: (branch-brlabel!)  ( ir-dest )
  curr-node node:ir-dest:! ;

(*
;; fix label. new label is in "node:temp".
: (branch-post-clone)
  curr-node node:ir-dest dup 0?error" unresolved branch"
  node:temp curr-node node:ir-dest:! ;
*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; label support

;; ir-label
:noname
  curr-node node-TOS-in-DE? ?error" ICE: TOS in DE on label!"
  xasm:reset-ilist
; ->special-compiler: ir-label

;; ir-restore-tos
:noname
  xasm:restore-tos-hl
  xasm:reset-ilist
; ->special-compiler: ir-restore-tos


;; this is used in trackers.
;; pull one stack item to the register.
;; you can use register hints here.
:noname ( pfa )
  error" ICE: this should not happen!"
; ->special-compiler: ir-pull-one

;; this is used in trackers.
;; spill one stack slot from the register.
:noname ( pfa )
  error" ICE: this should not happen!"
; ->special-compiler: ir-spill-one

;; this is used in trackers.
;; spill all stack slots from the registers, leaving TOS in HL.
:noname ( pfa )
  error" ICE: this should not happen!"
; ->special-compiler: ir-spill-all


end-module WORKERS
