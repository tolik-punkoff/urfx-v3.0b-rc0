;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IR code utilities
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM
extend-module IR

module CGEN

false constant DEBUG-CGEN

;; code generation is postponed
0 quan cg-prev-spfa
0 quan cg-spfa

module WORKERS
end-module WORKERS

end-module CGEN


module OPT

\ module WORKERS
\ end-module WORKERS

end-module OPT


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; note iterator API

0 quan (ir-current)


;; if we rewound the code in xasm, we need to fix zx-addr of the current node.
;; this is a hack, and it is required only for debug disasm for now,
:noname  ( n )
  zx-unallot
(*
  (ir-current) dup ?<
\ endcr ." UNALLOT \'" dup node:spfa shword:self-cfa dart:cfa>nfa debug:.id ." \' at $" zx-here .hex4 cr
    zx-here over node:zx-addr u< ?<
\ endcr ."  fix!"
      zx-here over node:zx-addr:!
    >?
  >? drop
*)
  ;; peephole can remove several words
  (ir-current) << dup 0?v||
    zx-here over node:zx-addr u>= ?v||
    zx-here over node:zx-addr:!
  ^| node:prev | >>
  drop
; xasm:rewind:!

:noname ( -- zx-addr )
  (ir-current) dup not?exit
  node:zx-addr
; xasm:word-begin:!

;; current node address
: curr-node  ( -- node^ )
  (ir-current) dup 0?error" wtf? no current node!" ;

: curr-node!  ( node^ )
  dup 0?error" wtf? no current node!"
  (ir-current):! ;

;; you can use this to stop the iteration
: ir-abort-iteration
  (ir-current):!0 ;

: curr-node-spfa  ( -- spfa )
  curr-node node:spfa ;

: curr-node-spfa-ref  ( -- spfa // 0 )
  curr-node node:spfa-ref ;


: prev-node  ( -- node^ )
  curr-node dup ?< node:prev >? ;

: prev-prev-node  ( -- node^ )
  prev-node dup ?< node:prev >? ;

: prev-prev-prev-node  ( -- node^ )
  prev-prev-node dup ?< node:prev >? ;


: node-spfa  ( node^ -- spfa // -1 )
  dup ?exit< node:spfa >? drop -1 ;


: prev-node-spfa  ( -- spfa // -1 )
  prev-node node-spfa ;

: prev-prev-node-spfa  ( -- spfa // -1 )
  prev-prev-node node-spfa ;


: next-node  ( -- node^ )
  curr-node node:next ;

: next-node-spfa  ( -- spfa // -1 )
  next-node node-spfa ;


: ?curr-node-lit-value  ( -- value )
  curr-node node:value
  dup -32768 65536 within not?error" invalid ZX literal value" ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; node manipulation utilities

;; remove and free previous node
: free-prev-node
  prev-node dup 0?error" IR-ICE: no previous node in \'free-prev-node\'!"
  dup remove free-node ;

: free-prev-prev-node
  prev-prev-node dup 0?error" IR-ICE: no previous node in \'free-prev-node\'!"
  dup remove free-node ;

;; remove and free next node
: free-next-node
  curr-node node:next dup 0?error" IR-ICE: no next node in \'free-prev-node\'!"
  dup remove free-node ;

;; remove and free current node.
;; WARNING! cannot remove first node!
: free-curr-node
  curr-node dup node:prev dup 0?error" IR-ICE: cannot remove first node if it is the current one!"
  curr-node!
  dup remove free-node ;

;; free current node, and replace it with the new one
: replace-curr-node  ( newnode^ )
  dup 0?error" IR-ICE: no new node in \'replace-curr-node\'!"
  curr-node over insert-before
  curr-node swap curr-node!
  dup remove free-node ;

: replace-curr-node-spfa  ( spfa )
  dup -0?error" IR-ICE: invalid SPFA in \'replace-curr-node-spfa\'!"
  new-spfa-node replace-curr-node ;

: curr-node-spfa:!  ( spfa )
  dup -0?error" IR-ICE: invalid SPFA in \'replace-curr-node-spfa\'!"
  curr-node node:spfa:! ;


;; free previous node, and replace it with the new one
: replace-prev-node  ( newnode^ )
  dup 0?error" IR-ICE: no new node in \'replace-curr-node\'!"
  curr-node swap insert-before
  curr-node node:prev node:prev
  dup remove free-node ;

: replace-prev-node-spfa  ( spfa )
  dup -0?error" IR-ICE: invalid SPFA in \'replace-prev-node-spfa\'!"
  new-spfa-node replace-prev-node ;


;; free previous node, and replace it with the new one
: replace-next-node  ( newnode^ )
  dup 0?error" IR-ICE: no new node in \'replace-next-node\'!"
  curr-node swap insert-after
  curr-node node:next node:next
  dup remove free-node ;

: replace-next-node-spfa  ( spfa )
  dup -0?error" IR-ICE: invalid SPFA in \'replace-next-node-spfa\'!"
  new-spfa-node replace-next-node ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; node creation utilities

opt-mk-zx-waddr (ncr-zx-lit)  SYS:LIT

: node-lit?  ( node^ -- value TRUE // FALSE )
  dup not?exit&leave
  dup node:spfa (ncr-zx-lit) = not?exit< drop false >?
  node:value true ;

: new-lit-node-spfa  ( value spfa -- node^ )
  new-spfa-node
  tuck node:value:! ;

: new-lit-node  ( value -- node^ )
  (ncr-zx-lit) new-lit-node-spfa ;

: node-walit?  ( node^ -- bool )
  dup not?exit&leave
  node:spfa ['] ir-specials:(ir-walit) dart:cfa>pfa = ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; debug words

: .node  ( node^ )
  dup 0?exit< ." <null>" >?
  node:spfa shword:self-cfa dart:cfa>nfa debug:.id ;

: .spfa
  curr-node .node ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; node iterators

;; -1: restart
|: (ir-current-next)
  (ir-current) dup -1 = ?exit< drop head (ir-current):! >?
  dup ?exit< node:next (ir-current):! >?
  drop ;

;; callback: ( node^ )
: ir-foreach-with-node  ( cfa )
  >r head (ir-current):!
  << (ir-current) dup ?^| r@ execute (ir-current-next) |?
  else| drop >> rdrop ;

;; callback: ( -- )
: ir-foreach  ( cfa )
  >r head (ir-current):!
  << (ir-current) ?^| r@ execute (ir-current-next) |?
  else| >> rdrop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; node checkers

: ir-special?  ( node^ -- flag )
  node:spfa shword:zx-begin -666 = ;

: ir-exit?  ( node^ -- flag )
  zforth: EXIT swap node-scfa? ;

: ir-any-exit?  ( node^ -- flag )
  zforth: EXIT over node-scfa? ?exit< drop true >?
  zforth: ?EXIT over node-scfa? ?exit< drop true >?
  zforth: NOT?EXIT over node-scfa? ?exit< drop true >?
  drop false ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; node list cloner

;; realloc things if necessary.
;; currently the only dynalloced field is `str$`.
|: (process-cloned-node)  ( node^ )
  dup node:str$ dup 0?exit< 2drop >?
  ( node^ str$ )
  count string:$new
  swap node:str$:! ;

: clone-node ( node^ -- new-node^ )
  dup 0?error" cannot clone null node!"
  dup node:spfa dup 0?error" cannot clone empty node!"
  (ir-current) >r swap (ir-current):!
  ( spfa )
  shword:ir-clone dup ?< execute
  || drop new-node  (ir-current) over bytes/node cmove  dup (process-cloned-node) >?
  ( new-node^ | spfa )
  \ dup node:flags:!0
  (ir-current) node:flags
    nflag-quan nflag-vect or nflag-do-inline or and
    over node:flags:!
  dup node:prev:!0
  dup node:next:!0
  dup node:zx-addr:!0
  dup node:temp:!0
  (ir-current) over node:temp:! ;; save old address to the new node
  dup (ir-current) node:temp:!  ;; save new address to the old node
  r> (ir-current):! ;


;; fix cloned node `ir-dest` field, which is pointing to the original node.
;; should be called with the address of the cloned node.
;; here, `temp` holds the address of the old node.
|: (fix-cloned-node-ir-dest)  ( new-node^ )
  dup node:ir-dest dup 0?exit< 2drop >?
  ( new-node^ old-label-node^ )
  node:temp swap node:ir-dest:! ;

;; fix cloned node `prev-loop` field, which is pointing to the original node.
;; should be called with the address of the cloned node.
;; here, `temp` holds the address of the old node.
|: (fix-cloned-node-prev-loop)  ( new-node^ )
  dup node:prev-loop dup 0?exit< 2drop >?
  ( new-node^ old-label-node^ )
  node:temp swap node:prev-loop:! ;

|: (fix-cloned-node)  ( new-node^ )
  dup (fix-cloned-node-ir-dest)
  dup (fix-cloned-node-prev-loop)
  drop ;

;; fix cloned node fields pointing to the original nodes.
;; should be called with the address of the cloned node.
;; here, `temp` holds the address of the old node.
|: (ir-fix-cloned-list-label)
  curr-node (fix-cloned-node)
  curr-node-spfa dup 0?error" cannot fix empty node!"
  ( spfa )
  shword:ir-post-clone dup ?exit< execute-tail >? drop ;


opt-mk-zx-waddr (cloner-zx-EXIT)      EXIT
opt-mk-zx-waddr (cloner-zx-?EXIT)     ?EXIT
opt-mk-zx-waddr (cloner-zx-NOT?EXIT)  NOT?EXIT

opt-mk-zx-waddr (cloner-zx-"BRANCH")    SYS:BRANCH
opt-mk-zx-waddr (cloner-zx-"0BRANCH")   SYS:0BRANCH
opt-mk-zx-waddr (cloner-zx-"TBRANCH")   SYS:TBRANCH

|: (ir-fix-exits-get-exit-label)  ( -- node^ )
  tail dup ?< node:spfa ir-label? >?
  ;; append label, if necessary
  not?<
    ['] ir-specials:(ir-restore-tos) append-special
    ['] ir-specials:(ir-label) append-special >?
  tail dup node:spfa ir-label? 0?error" REC-EXIT-LABEL: ICE!" ;

;; replace "EXIT" and "*?EXIT" with branches to the end of the list
|: (ir-fix-cloned-list-exits)
  curr-node-spfa
  << (cloner-zx-EXIT) of?v| (cloner-zx-"BRANCH") |?
     (cloner-zx-?EXIT) of?v| (cloner-zx-"TBRANCH") |?
     (cloner-zx-NOT?EXIT) of?v| (cloner-zx-"0BRANCH") |?
  else| drop exit >>
  ( spfa )
  (ir-fix-exits-get-exit-label)
  ( spfa label^ )
  swap new-spfa-node
  ( label^ node^ )
  tuck node:ir-dest:!
  replace-curr-node ;


: ir-replace-exits-with-branches
  ['] (ir-fix-cloned-list-exits) ir-foreach ;


: ir-clone-list  ( head^ -- new-tail^ new-head^ )
  dup 0?error" cannot clone empty list"
  head >r tail >r (ir-current) >r ;; save old list
  head:!0 tail:!0 ;; reset list
  << dup clone-node append
     node:next dup ?^||
  else| drop >>
  ['] (ir-fix-cloned-list-label) ir-foreach
  ['] (ir-fix-cloned-list-exits) ir-foreach
  tail head
  r> (ir-current):! r> tail:! r> head:! ;


: ir-append-clone  ( node^ )
  dup not?exit< drop >?
  ir-clone-list
  ( cloned-tail^ cloned-head^ )
  [ 0 ] [IF]
    head >r tail >r ;; save old list
    over tail:! dup head:!
    dump-ir
    r> tail:! r> head:!
  [ENDIF]
  ;; concat lists
  ( cloned-tail^ cloned-head^ )
  tail ?<
    dup tail node:next:!
    tail swap node:prev:!
  || head:! >?
  tail:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; find various worker words

: (find-cgen-worker)  ( addr count -- scfa )
  2dup vocid: cgen:workers find-in-vocid ?exit< nrot 2drop >?
  " cannot find IR worker word '" pad$:! pad$:+
  " '" pad$:+  pad$:@ error ;

: -find-cgen-worker  ( -- scfa )  \ name
  parse-name (find-cgen-worker) ;


: (find-opt-worker)  ( addr count -- scfa )  \ name
  2dup vocid: opt find-in-vocid ?exit< nrot 2drop >?
  " cannot find IR optimiser word '" pad$:! pad$:+
  " '" pad$:+  pad$:@ error ;

: -find-opt-worker  ( -- scfa )  \ name
  parse-name (find-opt-worker) ;


(*
: (find-stacker-worker)  ( addr cfa -- scfa )  \ name
  2dup vocid: stacker:workers find-in-vocid ?exit< nrot 2drop >?
  " cannot find IR optimiser word '" pad$:! pad$:+
  " '" pad$:+  pad$:@ error ;

: -find-stacker-worker  ( -- scfa )  \ name
  parse-name (find-stacker-worker) ;
*)

end-module IR


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; this helps defining peephole optimisers for primitives

0 quan (prim-colon-saved-scur)
0 quan (prim-colon-saved-sctx)

module PRIM-PEEPOPT-HELPERS
<disable-hash>
*: ;
  system:?comp
  [\\] forth:;
  context@ vocid: prim-peepopt-helpers = not?error" context imbalance!"
  pop-ctx
  " xasm" module-support:do-one-end-using
  module-support:finish-module
  [\\] <zx-definitions>
  (prim-colon-saved-scur) zx-shadow-current:!
  (prim-colon-saved-sctx) zx-shadow-context:!
;
end-module PRIM-PEEPOPT-HELPERS

extend-module ZX-DEFS
voc-ctx: forth
*: primopt:  \ name
  system:?exec
  zx-shadow-current (prim-colon-saved-scur):!
  zx-shadow-context (prim-colon-saved-sctx):!
  [\\] zx-defs:<zx-done>
  " TCOM" module-support:enter-module
  " xasm" module-support:do-one-using
  push-ctx voc-ctx: prim-peepopt-helpers
  [\\] :
;
end-module ZX-DEFS

end-module TCOM
