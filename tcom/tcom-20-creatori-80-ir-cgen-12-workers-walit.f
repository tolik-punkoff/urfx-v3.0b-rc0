;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; directly included from "tcom-20-creatori-80-ir-cgen.f"
;; WALIT internal node workers
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; note that WALIT workers should not be called, ever.
;; all WALIT nodes should be replaced by the corresponding LIT
;; nodes before the actual codegen runs.
;; this is the leftover from the early implementation, and
;; should be eventually removed.

extend-module WORKERS


|: (walit-get-val)  ( -- shadow-pfa )
  curr-node-spfa-ref shword:zx-begin
  dup -2 = ?exit<
    " IR-ICE: walit referenced unused word \'" pad$:!
    curr-node-spfa-ref shword:self-cfa dart:cfa>nfa idcount pad$:+
    " \'" pad$:+  pad$:@ error >?
  dup -666 = ?exit<
    " IR-ICE: walit referenced internal word \'" pad$:!
    curr-node-spfa-ref shword:self-cfa dart:cfa>nfa idcount pad$:+
    " \'" pad$:+  pad$:@ error >?
  [ turnkey-pass2? drop 1 ] [IF]
    cg-spfa shword:zx-begin +0?<
      dup -1 = ?exit<
        " cannot take address of the undefined word \'" pad$:!
        curr-node-spfa-ref shword:self-cfa dart:cfa>nfa idcount pad$:+
        " \' in \'" pad$:+
        cg-spfa shword:self-cfa dart:cfa>nfa idcount pad$:+
        " \'" pad$:+
        pad$:@ error >?
    >?
  [ENDIF]
  drop
  curr-node node:spfa-ref ;

;; hack: fix value
|: (walit-fix-value)  ( shadow-pfa )
  shword:zx-begin 0 max curr-node node:value:! ;

;; use `curr-node`
|: (do-walit)  ( primitive-pfa )
  dup shword:tk-flags tkf-primitive and not?exit<
    " \'" pad$:! shword:self-cfa dart:cfa>nfa idcount pad$:+
    " \' is not a primitive!" pad$:+ pad$:@ error >?
  dup shword:ir-compile dup 0?exit< drop
    " \'" pad$:! shword:self-cfa dart:cfa>nfa idcount pad$:+
    " \' has no codegen!" pad$:+ pad$:@ error >?
  ( primitive-pfa ir-compiler )
  nip >r
  (walit-get-val)
  (walit-fix-value)
  r> execute-tail ;

: create-walit-handler:  \ ir-special primitive-name
  system:?exec
  parse-name
  " (" pad$:! pad$:+ " )" pad$:+
  pad$:@ vocid: ir-specials find-in-vocid not?exit<
    "  -- no such special!" pad$:+ pad$:@ error >?
  dart:cfa>pfa dup shword:zx-begin -666 = not?exit<
    "  -- not an IR special!" pad$:+ pad$:@ error >?
  ( special-pfa )
  parse-name true (z-find-forward)
  dart:cfa>pfa
  ( special-pfa primitive-pfa )
  >r [\\] :noname r> [\\] {#,} \\ (do-walit) [\\] forth:;
  swap shword:ir-compile:! ;

;; ir-walit
;; spfa-ref: word
create-walit-handler: ir-walit LIT
  \ nflag-quan curr-node node-flag? ?< (walit-route-to-cfa) ?exit >?
\ :noname
\   (walit-get-val)
\   (walit-fix-value)
\   zsys-execute-primitive-codegen: LIT
\ ; ->special-compiler: ir-walit

;; ir-walit:@
;; spfa-ref: word
create-walit-handler: ir-walit:@ LIT:@

;; ir-walit:c@
;; spfa-ref: word
create-walit-handler: ir-walit:c@ LIT:C@

;; ir-walit:1c@
;; spfa-ref: word
create-walit-handler: ir-walit:1c@ LIT:1C@

;; ir-walit:@execute
;; spfa-ref: word
create-walit-handler: ir-walit:@execute LIT:@EXECUTE

;; ir-walit:!0
;; spfa-ref: word
create-walit-handler: ir-walit:!0 LIT:!0

;; ir-walit:c!0
;; spfa-ref: word
create-walit-handler: ir-walit:c!0 LIT:C!0

;; ir-walit:!1
;; spfa-ref: word
create-walit-handler: ir-walit:!1 LIT:!1

;; ir-walit:c!1
;; spfa-ref: word
create-walit-handler: ir-walit:c!1 LIT:C!1

;; ir-walit:!
;; spfa-ref: word
create-walit-handler: ir-walit:! LIT:!

;; ir-walit:c!
;; spfa-ref: word
create-walit-handler: ir-walit:C! LIT:C!

;; ir-walit:1c!
;; spfa-ref: word
create-walit-handler: ir-walit:1C! LIT:1C!

;; ir-walit:+!
;; spfa-ref: word
create-walit-handler: ir-walit:+! LIT:+!

;; ir-walit:+c!
;; spfa-ref: word
create-walit-handler: ir-walit:+c! LIT:+C!

;; ir-walit:-!
;; spfa-ref: word
create-walit-handler: ir-walit:-! LIT:-!

;; ir-walit:-c!
;; spfa-ref: word
create-walit-handler: ir-walit:-c! LIT:-C!

;; ir-walit:1+!
;; spfa-ref: word
create-walit-handler: ir-walit:1+! LIT:1+!

;; ir-walit:1+C!
;; spfa-ref: word
create-walit-handler: ir-walit:1+c! LIT:1+C!

;; ir-walit:1-!
;; spfa-ref: word
create-walit-handler: ir-walit:1-! LIT:1-!

;; ir-walit:1-c!
;; spfa-ref: word
create-walit-handler: ir-walit:1-c! LIT:1-C!


end-module WORKERS
