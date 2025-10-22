;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IR code generator
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM
extend-module IR

extend-module CGEN

OPT-DUMP-CGEN-IR-NODES-PRE? constant DEBUG-DUMP-CGEN-IR-NODES-PRE?
OPT-DUMP-CGEN-IR-NODES? constant DEBUG-DUMP-CGEN-IR-NODES?
OPT-DISASM-P1? constant DEBUG-DUMP-CGEN-P1?
OPT-DISASM-P2? constant DEBUG-DUMP-CGEN-P2?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; node name and params printer for various debug needs

: debug-print-node  ( node^ )
  dup 0?exit< drop ." <NULL>" >?
  dup node:spfa dup -1 = over 0 = or ?< 2drop ." <BAD-SPFA>" >?
  shword:self-cfa dart:cfa>nfa debug:.id

  ."  (TOS: " dup node-TOS-in-DE? ?< ." DE" || ." HL" >? ." )"

  dup ir:node-need-TOS-DE? ?< ."  (req TOS:DE)" >?
  dup ir:node-need-TOS-DE? ?< ."  (req TOS:HL)" >?

  dup ir:node-in-8bit? ?< ."  (in:8-bit)" >?

  dup ir:node-out-8bit? ?<
    dup ir:node-out-bool? ?< ."  (out:bool8)" || ."  (out:8bit)" >?
  || dup ir:node-out-bool? ?< ."  (out:bool16)" >?
  >?

  dup node:value ?<
    ."  value: " dup node:value dup . ." ($" lo-word .hex4 ." )"
  >?
  dup node:value2 ?<
    ."  value2: " dup node:value2 dup . ." ($" lo-word .hex4 ." )"
  >?
  dup node:value3 ?<
    ."  value3: " dup node:value3 dup . ." ($" lo-word .hex4 ." )"
  >?

  dup node-in-known? ?<
    ."  (in:"
    dup node-in-min dup 0.r
    over node-in-max <> ?< ." :" dup node-in-max 0.r >?
    ." )"
  >?

  dup node-out-known? ?<
    ."  (out:"
    dup node-out-min dup 0.r
    over node-out-max <> ?< ." :" dup node-out-max 0.r >?
    ." )"
  >?

  drop ;


$include "tcom-20-creatori-80-ir-cgen-10-workers.f"
$include "tcom-20-creatori-80-ir-cgen-12-workers-walit.f"
$include "tcom-20-creatori-80-ir-cgen-14-workers-label-branch.f"
$include "tcom-20-creatori-80-ir-cgen-16-workers-loops.f"
$include "tcom-20-creatori-80-ir-cgen-18-workers-strings.f"
$include "tcom-20-creatori-80-ir-cgen-30-cga.f"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; initial setup for IR looping

: setup-ir
  cg-spfa 0?error" wut?!"
  cg-spfa shword:ir-code \ dup 0?error" wut?! no IR code!"
  dup head:!
  dup ?<
    << dup node:next dup ?^| nip |? else| drop >>
  >?
  tail:!
  head (ir-current):! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; check if the word is recursive

;; scan IR code, set "recursive" flag if "RECURSE" was used
: fix-recurse-flag
  ;; if the flag is manually set, there is nothing to do
  cg-spfa shword:tk-flags tkf-allow-recurse and ?exit
  (*
  head 0?exit<
    endcr ." WTF? " cg-spfa shword:self-cfa dart:cfa>nfa debug:.id cr
  >?
  *)
  head <<
    dup node:spfa ir-recurse? ?exit< drop
      tkf-allow-recurse cg-spfa shword:tk-flags:^ or! >?
    node:next dup ?^||
  else| drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; entry and exit nodes utilities

;; insert entry and exit IR nodes.
;; "recursive" flag should be properly set.
: insert-entry-exit
  cg-spfa shword:tk-flags tkf-allow-recurse and ?exit<
    ['] ir-specials:(ir-rec-entry) prepend-special
    ['] ir-specials:(ir-rec-exit) append-special
    [ 0 ] [IF]
      endcr ." RECURSIVE: " cg-spfa shword:self-cfa dart:cfa>nfa debug:.id cr
    [ENDIF]
  >?
  cg-spfa shword:tk-flags tkf-no-return and ?exit<
    ['] ir-specials:(ir-noexit-entry) prepend-special
    ['] ir-specials:(ir-noexit-exit) append-special
  >?
  ['] ir-specials:(ir-nonrec-entry) prepend-special
  ['] ir-specials:(ir-nonrec-exit) append-special ;


: insert-dummy-begin-end-nodes
  ['] ir-specials:(ir-nothing) prepend-special
  ['] ir-specials:(ir-nothing) append-special
;

: remove-dummy-begin-end-nodes
  head ?< head node:spfa ir-nothing? ?< head dup remove free-node >? >?
  tail ?< tail node:spfa ir-nothing? ?< tail dup remove free-node >? >?
;

: any-ir-entry-node?  ( node^ -- bool )
  dup not?exit node:spfa
  dup shword:zx-begin -666 = not?exit< drop false >?
  dup ir-noexit-entry? ?exit< drop true >?
  dup ir-nonrec-entry? ?exit< drop true >?
  dup ir-rec-entry? ?exit< drop true >?
  drop false ;

: any-ir-exit-node?  ( node^ -- bool )
  dup not?exit node:spfa
  dup shword:zx-begin -666 = not?exit< drop false >?
  dup ir-noexit-exit? ?exit< drop true >?
  dup ir-nonrec-exit? ?exit< drop true >?
  dup ir-rec-exit? ?exit< drop true >?
  drop false ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; code generation loop handlers

|: (dump-curr-node-cgen)  ( addr count node^ )
  [ DEBUG-CGEN DEBUG-DUMP-CGEN-IR-NODES? or ] [IF]
    endcr type
    curr-node node:spfa shword:self-cfa dart:cfa>nfa debug:.id
    ."  -- $" curr-node node:zx-addr .hex4
    ." :$" zx-here .hex4
    cr
  [ELSE] 2drop
  [ENDIF]
;

|: node-start-addr!  ( node^ )
  zx-here swap node:zx-addr:! ;

|: node-tos-info!  ( node^ )
  xasm:TOS-in-DE? ?< node-TOS-in-DE! || node-TOS-in-HL! >? ;

|: (reg-other-node-refs)  ( node^ )
  ;; register secondary reference, if there is any
  node:spfa-ref dup ?< record-ref-spfa || drop >? ;


|: (compile-node-with-cg)  ( spfa )
  dup shword:ir-compile swap
\ endcr ." PRIM \'" dup shword:self-cfa dart:cfa>nfa debug:.id ." \' at $" zx-here .hex4 cr
  drop
  depth 1- >r
  execute
  depth r> = not?exit<
    endcr ." ***: \'"
    cg-spfa shword:self-cfa dart:cfa>nfa debug:.id
    ." \' -- "
    curr-node node:spfa shword:self-cfa dart:cfa>nfa debug:.id cr
    error" IR-ICE: stack imbalance (0)!" >?
;

;; FIXME: this word is terrible! factor it.
|: (compile-node)
  [ DEBUG-DUMP-CGEN-IR-NODES-PRE? ] [IF]
    endcr ." ### COMPILING NODE: "
    curr-node node:spfa shword:self-cfa dart:cfa>nfa debug:.id cr
  [ENDIF]
  curr-node
  dup node-start-addr!
  dup node-tos-info!
  dup >r node:spfa  ( spfa | node^ )
  ;; special handling for primitives
  dup shword:zx-begin
  ( spfa zx-begin | node^ )
  ;; -1: forward
  ;; -2: unused word (turnkey pass 2)
  ;; -666: special, do not register
  [ DEBUG-DUMP-CGEN-P1? 0= ] [IF]
  turnkey-pass2? ?<
    dup -2 = ?<
      ;; do not skip primitives
      over shword:tk-flags tkf-primitive and not?exit<
        drop rdrop "  SKIP: " (dump-curr-node-cgen) >?
    >?
  >?
  [ENDIF]
  ( spfa zx-begin | node^ )
  ;; register reference
  -1 >= ?< dup record-ref-spfa >?
  ( spfa | node^ )
  ;; register secondary reference, if there is any
  r@ (reg-other-node-refs)
  ( spfa | node^ )
  dup shword:ir-compile
  ?< rdrop (compile-node-with-cg)
     " *" (dump-curr-node-cgen)
  || rdrop 0 compile-zx-call-spfa-with-ofs-noreg
     "  " (dump-curr-node-cgen)
  >? ;


: (fixup-bref-node)
  curr-node-spfa shword:ir-branchfix dup not?exit< drop >?
  " BRFIX: " (dump-curr-node-cgen)
  execute-tail ;

: fixup-branch-refs
  ['] (fixup-bref-node) ir-foreach ;


;; call codegens
: generate-tcode
  xasm:reset
  ['] (compile-node) ir-foreach
  cg-spfa shword:zx-begin ?< zx-here cg-spfa shword:zx-end:! >?
  xasm:reset
  fixup-branch-refs ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; inliner
;; note that inliner copies the unoptimised IR code.
;; this is so the optimiser could do its work as if the inlined word
;; was directly copipasted.

|: (cgen-clone-ir-from)  ( head^ )
  dup not?exit< drop >?
  ir-clone-list nip cg-spfa shword:ir-code-clone:! ;


false quan (cgen-was-inlines?)

OPT-ALLOW-INLINING? [IF]
;; actually, replace the current node with the new list.
;; we ALWAYS have the previous and the next nodes.
;; we should skip the current list, to give optimisers a chance to run.
|: (cgen-insert-list-here)  ( new-tail^ new-head^ )
  \ over >r ;; this will be our new current node
  ;; insert after the current node
  ;; new-tail^.next := curr^.next
  over curr-node node:next swap node:next:!
  ;; curr^.next^.prev := new-tail^
  over curr-node node:next node:prev:!
  ;; curr^.next := new-head^
  dup curr-node node:next:!
  ;; new-head^.prev := curr^
  curr-node over node:prev:!
  2drop
  ;; remove current
  free-curr-node
  ;; skip new list, so the optimisers will run for it.
  ;; we will loop until there are no more inlines, so the inserted code
  ;; will be processed on the next loop iteration.
  \ r> curr-node! ;
  ;; no, actually, stop the process right now. otherwise the following code
  ;; will not be optimised:
  ;;   : w2 2 ; zx-inline
  ;;   : w3 5 w2 u/ ;
  ;; if we'll expand all inlines in a row, `w3` would be:
  ;;   : w3 5 2 uu/mod drop ;
  ;; which won't be optimised. yet if we'll stop at the first inline:
  ;;   : w3 5 2 u/ ;
  ;; now "u/" will have a chance to do its work.
  ir-abort-iteration ;


|: (cgen-inline-here)
  curr-node-spfa shword:ir-code-clone
  dup 0?error" wutafuck?!"
  [ 0 ] [IF]
    endcr ." INLINING \'" curr-node-spfa shword:self-cfa dart:cfa>nfa debug:.id
    ." \' into \'" cg-spfa shword:self-cfa dart:cfa>nfa debug:.id ." \'\n"
  [ENDIF]
  ir-clone-list  ( new-tail^ new-head^ )
  (cgen-insert-list-here)
  (cgen-was-inlines?):!t ;

;; FIXME: inlining two mutually recursive words will lead to the endless loop!
|: (cgen-need-inline?-spfa)  ( shadow-pfa -- flag )
  dup cg-spfa = ?exit< drop false >?  ;; just in case
  dup shword:tk-flags  tkf-allow-recurse tkf-allow-inline or tkf-no-return or  and
  tkf-allow-inline = not?exit< drop false >?
  shword:ir-code-clone 0<> ;

|: (cgen-inline-code-cb)
  curr-node node:flags nflag-do-inline and not?<
    curr-node-spfa (cgen-need-inline?-spfa) not?exit
  (*
  ||
    [ 1 ] [IF]
      endcr ." FORCE-INLINE: " curr-node-spfa shword:self-cfa dart:cfa>nfa debug:.id cr
    [ENDIF]
  *)
  >?
  (cgen-inline-here) ;

|: (cgen-inline-code)
  (cgen-was-inlines?):!f
  ['] (cgen-inline-code-cb) ir-foreach ;
[ELSE]
|: (cgen-inline-code)
  (cgen-was-inlines?):!f ;
[ENDIF]

: (cgen-clone-for-inliner)  ( spfa )
  dup 0?exit< drop >?
  cg-spfa >r dup cg-spfa:!
  shword:ir-code
  [ 1 ] [IF]
    dup 0?<
      endcr ." CANNOT create inliner clone for \'"
      cg-spfa shword:self-cfa dart:cfa>nfa debug:.id
      ." \'. oops.\n"
    (*
    ||
      endcr ." creating inliner clone for \'"
      cg-spfa shword:self-cfa dart:cfa>nfa debug:.id
      ." \'.\n"
    *)
    >?
  [ENDIF]
  (cgen-clone-ir-from)
  r> cg-spfa:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; debug disasm

|: (zx-c@++)  ( zx-addr -- zx-addr+1 byte )
  dup zx-c@ 1 under+ ;

|: (disasm-dump-bstr)  ( zx-addr-end )
  endcr ." ;; STR: \'"
  curr-node node:bstr-zx-addr
  curr-node node:bstr-zx-addr-end
  over - for
    (zx-c@++)
    dup 32 < over 127 = lor ?< ." \\x" .hex2
    || dup [char] " = ?< drop ." \\\'" || emit >?
    >?
  endfor drop
  ." \'\n" ;

|: disasm-annotated-cb
  endcr
  ." ;; " curr-node debug-print-node
  curr-node node:zx-addr
  curr-node node:next dup ?< node:zx-addr || drop cg-spfa shword:zx-end >?
  ( start end )
  [ 0 ] [IF]
    ."  (" over -?< over . || [char] $ emit over .hex4 bl emit >?
    ." : " dup -?< dup 0.r || [char] $ emit dup .hex4 >?
  [ENDIF]
  cr
  2dup >= ?exit< 2drop >?
  ;; correctly interpret nodes with byte-counted strings
  nflag-bstr-compiled curr-node node-flag? ?exit<
    dup >r drop
    curr-node node:bstr-zx-addr dup 0?error" ICE: bstr fuck!"
    z80dis:disasm-range
    (disasm-dump-bstr)
    curr-node node:bstr-zx-addr-end r@ < ?<
      curr-node node:bstr-zx-addr-end r@ z80dis:disasm-range
    >?
    rdrop
  >?
  z80dis:disasm-range ;

: disasm-annotated
  ['] disasm-annotated-cb ir-foreach ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimiser loop runner

: (cgen-run-optimise-loop)
  <<
    ;; twice
    opt:expand-n-DUP  ;; expand `n DUP` to `n n`, this helps constant folder
    opt:run-analyzers
    opt:compress-n-n  ;; compress `n n` back to `n DUP`, this generates better code
    opt:was-compress? ?<
      ;; if anything was compressed, run the optimisers again, just in case
      opt:run-analyzers
    >?
    (cgen-inline-code)
    (cgen-was-inlines?) ?^||
  else| >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; replace WALIT nodes with LIT nodes

false quan (cgen-was-walit-repl?)

: (cgen-walit-replacement)  ( spfa -- new-scfa TRUE // FALSE )
  dup ir-walit? ?exit< drop zsys: LIT true >?
  dup ir-walit:@? ?exit< drop zsys: LIT:@ true >?
  dup ir-walit:c@? ?exit< drop zsys: LIT:C@ true >?
  dup ir-walit:1c@? ?exit< drop zsys: LIT:1C@ true >?
  dup ir-walit:@execute? ?exit< drop zsys: LIT:@EXECUTE true >?
  dup ir-walit:!0? ?exit< drop zsys: LIT:!0 true >?
  dup ir-walit:c!0? ?exit< drop zsys: LIT:C!0 true >?
  dup ir-walit:!1? ?exit< drop zsys: LIT:!1 true >?
  dup ir-walit:c!1? ?exit< drop zsys: LIT:C!1 true >?
  dup ir-walit:!? ?exit< drop zsys: LIT:! true >?
  dup ir-walit:c!? ?exit< drop zsys: LIT:C! true >?
  dup ir-walit:1c!? ?exit< drop zsys: LIT:1C! true >?
  dup ir-walit:+!? ?exit< drop zsys: LIT:+! true >?
  dup ir-walit:+c!? ?exit< drop zsys: LIT:+C! true >?
  dup ir-walit:-!? ?exit< drop zsys: LIT:-! true >?
  dup ir-walit:-c!? ?exit< drop zsys: LIT:-C! true >?
  dup ir-walit:1+!? ?exit< drop zsys: LIT:1+! true >?
  dup ir-walit:1+c!? ?exit< drop zsys: LIT:1+C! true >?
  dup ir-walit:1-!? ?exit< drop zsys: LIT:1-! true >?
  dup ir-walit:1-c!? ?exit< drop zsys: LIT:1-C! true >?
  drop false ;

|: (cgen-walit-replace-cb)
  curr-node node:spfa (cgen-walit-replacement) not?exit
  ( new-scfa )
  ;; register used word
  curr-node node:spfa-ref dup 0?exit< 2drop >?
  ( new-scfa spfa-ref )
  dup shword:zx-begin dup -0?exit< 3drop >?
  ( new-scfa spfa-ref zx-addr )
  swap record-ref-spfa
  ( new-scfa zx-addr )
  curr-node node:value:!
  ( new-scfa )
  ;; replace spfa
  dart:cfa>pfa curr-node node:spfa:!
  0 curr-node node:spfa-ref:!
  (cgen-was-walit-repl?):!t ;

;; replace "walit" with "lit", register all used words.
;; this is so literal optimisations could do their work.
: (cgen-replace-walits-with-lits)  ( -- flag )
  (cgen-was-walit-repl?):!f
  ['] (cgen-walit-replace-cb) ir-foreach
  (cgen-was-walit-repl?) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main codegen entry (internal)

: (cgen-main)  ( spfa )
  cg-spfa:!
  turnkey-pass2? ?<
    cg-spfa shword:self-cfa tk-zx-word-used? not?exit
  >?
  zx-here zx-tk-rewind-addr:!
  zx-here cg-spfa shword:zx-begin:!
  ;; need to patch this for proper recording
  zx-tk-curr-word-scfa >r cg-spfa shword:self-cfa zx-tk-curr-word-scfa:!
  [ DEBUG-CGEN DEBUG-DUMP-CGEN-IR-NODES-PRE? or DEBUG-DUMP-CGEN-IR-NODES? or ] [IF]
    endcr ." \n=== CGEN: "
    cg-spfa shword:self-cfa dart:cfa>nfa debug:.id
    ."  ===\n"
  [ENDIF]
  setup-ir
  ;; insert two dummy nodes, so the optimisers will always have prev and next
  head ?<
    ir-replace-exits-with-branches  ;; get rid of "*EXIT"
    insert-dummy-begin-end-nodes
    ;; it is done this way so optimisers for inlined words will be executed.
    ;; without this, inlining, for example, `U*` will lead to skiped optimisations.
    cg-spfa shword:tk-flags tkf-no-optim and not?<
      (cgen-run-optimise-loop)
      (cgen-replace-walits-with-lits) ?< (cgen-run-optimise-loop) >?
    || ;; still need to replace walits
      (cgen-replace-walits-with-lits) drop
    >?
    ;; the word may be empty for some reason (if not used?)
    ;; so check for recursion here, while we have at least some nodes.
    fix-recurse-flag
    remove-dummy-begin-end-nodes
    [ 0 ] [IF]
      endcr ." === CLONE: "
      cg-spfa shword:self-cfa dart:cfa>nfa debug:.id
      ."  ===\n"
    [ENDIF]
  ||  ;; force inline for this word, it is empty
    [ 0 ] [IF]
      endcr ." === EMPTY: "
      cg-spfa shword:self-cfa dart:cfa>nfa debug:.id
      ."  ===\n"
    [ENDIF]
  >?
  insert-entry-exit
  head cg-spfa shword:ir-code:!
  [ 0 ] [IF]
    endcr ." === CGEN-FINAL: "
    cg-spfa shword:self-cfa dart:cfa>nfa debug:.id
    ."  ===\n"
    dump-ir
  [ENDIF]
  generate-tcode
  [ DEBUG-DUMP-CGEN-P1? DEBUG-DUMP-CGEN-P2? or ] [IF]
    DEBUG-DUMP-CGEN-P1? turnkey-pass2? or ?<
      cg-spfa shword:zx-begin cg-spfa shword:zx-end <
      cg-spfa shword:zx-begin 0>= and ?<
        endcr cr cr ." === CGEN-DISASM: "
        cg-spfa shword:self-cfa dart:cfa>nfa debug:.id
        ."  ===\n"
        \ cg-spfa shword:zx-begin
        \ cg-spfa shword:zx-end
        \ z80dis:disasm-range
        disasm-annotated
      >?
    >?
  [ENDIF]
  head cg-spfa shword:ir-code:!
  ;; add at least 1 byte, we might need it
  zx-here zx-tk-rewind-addr - 1 < ?< 0 zx-c, >?
  ;; rewind unneded word
  zx-tk-rewind not?<
    ;; statistics
    zx-here zx-stx-last-colon-start - zx-stats-tcode-bytes:+! >?
  r> zx-tk-curr-word-scfa:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; external codegen entries

: (cgen-do)  ( spfa )
  ;; need to be cloned here for inlining
  dup (cgen-clone-for-inliner)
  cg-prev-spfa
  swap cg-prev-spfa:!
  dup not?exit< drop >?
  (cgen-main) ;

;; flush all pending IR code; should be called in non-colon creators
: (cgen-flush)
  cg-prev-spfa not?exit
  cg-prev-spfa cg-prev-spfa:!0
  dup (cgen-clone-for-inliner)
  (cgen-main) ;
['] (cgen-flush) cgen-flush:!

;; should be called last, when no more code could be compiled
: cgen-finish
  cg-prev-spfa not?exit
  ;; no reason to clone it, it cannot be inlined anyway
  cg-prev-spfa (cgen-main) ;

['] (cgen-do) generate-code:!


end-module CGEN
end-module IR
end-module TCOM
