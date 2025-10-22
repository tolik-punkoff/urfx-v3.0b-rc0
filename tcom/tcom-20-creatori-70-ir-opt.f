;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IR code optimisers
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM
extend-module IR
extend-module OPT

false constant DEBUG-TCO-OPT
false constant SOPT-DEBUG?


opt-mk-zx-waddr (opt-zx-DUP)            DUP
opt-mk-zx-waddr (opt-zx-"0BRANCH")      SYS:0BRANCH
opt-mk-zx-waddr (opt-zx-"TBRANCH")      SYS:TBRANCH

opt-mk-zx-waddr (opt-zx-"(DO)")         SYS:(DO)
opt-mk-zx-waddr (opt-zx-"(FOR)")        SYS:(FOR)
opt-mk-zx-waddr (opt-zx-"(FOR8)")       SYS:(FOR8)
opt-mk-zx-waddr (opt-zx-"(FOR8:LIT)")   SYS:(FOR8:LIT)

opt-mk-zx-waddr (opt-zx-lit:!0)         SYS:LIT:!0
opt-mk-zx-waddr (opt-zx-lit:!1)         SYS:LIT:!1
opt-mk-zx-waddr (opt-zx-lit:val2:!)     SYS:LIT:VAL2:!

opt-mk-zx-waddr (opt-zx-lit)            SYS:LIT
opt-mk-zx-waddr (opt-zx-lit:c!0)        SYS:LIT:C!0

opt-mk-zx-waddr (opt-zx-and8)           AND8
opt-mk-zx-waddr (opt-zx-and8:LIT)       SYS:AND8:LIT
opt-mk-zx-waddr (opt-zx-and8-hi:LIT)    SYS:AND8-HI:LIT

;; used by branch peephole optimisers
opt-mk-zx-waddr (opt-zx-"0=")           0=
opt-mk-zx-waddr (opt-zx-"0<>")          0<>

opt-mk-zx-waddr (opt-zx-OR)             OR


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; run IR node analyzers
;; they are actually optimisers here

false quan anal-was-change?
false quan anal-check-labels?

: was-optim!  anal-was-change?:1+! ;
: check-labels!  anal-was-change?:1+! ;


: OPT-REPORTS?  ( -- flag )
  [ SOPT-DEBUG? ] [IF] true
  [ELSE]
    OPT-OPTIMIZE-SUPER-MSG? not?exit&leave
    turnkey? 0=  turnkey-pass2? lor
  [ENDIF] ;

: .sopt-notice  ( addr count )
  opt-reports? not?exit< 2drop >?
  endcr ." *** NOTICE: SUPEROPT: " type ."  in '" curr-word-snfa idcount type ." '\n" ;


: OPT-BR-REPORTS?  ( -- flag )
  [ SOPT-DEBUG? ] [IF] true
  [ELSE]
    OPT-OPTIMIZE-BRANCHES-MSG? not?exit&leave
    turnkey? 0=  turnkey-pass2? lor
  [ENDIF] ;

: .sopt-br-notice  ( addr count )
  opt-br-reports? not?exit< 2drop >?
  endcr ." *** NOTICE: BRANCH: " type ."  in '" curr-word-snfa idcount type ." '\n" ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; pattern database interface

false constant DEBUG-PDB-SETTERS?
false constant DEBUG-PDB-MATCHING?
false constant DEBUG-PDB-ACTIONS?

false constant DEBUG-PDB-FORCE-NOTICES?


;; list of pattern database words.
;; we will search this list when the shadow word is created.
module PATDB
<separate-hash>
end-module PATDB


;; attach cached forward pattern database
:noname  ( scfa )
  dup dart:cfa>nfa idcount
  ( scfa addr count )
  vocid: PATDB find-in-vocid not?exit<
    [ 0 ] [IF]
      endcr ." !!! PDB-DEBUG: no patterns for \'"
      dup dart:cfa>nfa debug:.id
      ." \'\n"
    [ENDIF]
    drop
  >?
  ( scfa patdb-cfa )
  dart:cfa>pfa swap dart:cfa>pfa swap
  ( spfa patdb-pfa )
  over shword:ir-patdb ?exit< drop
    " ICE: pattern database for \'" pad$:!
    shword:self-cfa dart:cfa>nfa idcount pad$:+
    " \' already attached!" pad$:+
    pad$:@ error
  >?
  [ DEBUG-PDB-SETTERS? ] [IF]
    endcr ." !!! PDB-DEBUG: attached postponed pattern database to \'"
    over shword:self-cfa dart:cfa>nfa debug:.id
    ." \'\n"
  [ENDIF]
  ( spfa patdb-pfa )
  2dup @ swap shword:ir-patdb:!
  ;; clear db; may be used for reports
  !0 drop
; (mk-shadow-word-done):!


;; address of the matched pattert
0 quan pmat-pattern-matched
;; address of the rewriter for that pattern
0 quan pmat-pattern-rewriter
;; currently crearted node
0 quan pmat-new-node
;; branch rewriter? set if either matcher or rewriter used label value
0 quan pmat-branch-optim?


|: (sopt-print-match-node)  ( mnode^ )
  dup 0?exit< drop >?
  TPAT:mnode:name$ count type
  bl emit ;

|: (sopt-print-match-nodes-list)  ( mnode^ )
  dup 0?exit< drop >?
  dup TPAT:mnode:next recurse
  (sopt-print-match-node) ;

|: (sopt-print-rewrite-nodes)  ( rnode^ )
  dup 0?exit<  ."  <nothing>" drop >?
  << dup ?^|
       bl emit dup TPAT:rnode:name$ count type
       TPAT:rnode:next
     |?
  else| drop >> ;

: .sopt-patdb
  [ DEBUG-PDB-FORCE-NOTICES? ] [IFNOT]
    pmat-branch-optim? ?< opt-br-reports? || opt-reports? >?
    not?exit
  [ENDIF]
  pmat-branch-optim? ?< endcr ." *** NOTICE: PAT-OPT-BRN: "
  || endcr ." *** NOTICE: PAT-OPT: "
  >?
  pmat-pattern-matched (sopt-print-match-nodes-list)
  ." ->" pmat-pattern-rewriter (sopt-print-rewrite-nodes)
  ."  in '" curr-word-snfa idcount type ." '\n" ;


bit-enum{
  def: ir-pat-matcher-lbl
  def: ir-pat-rewriter-lbl
}

struct:new ir-pattern
  field: next         -- next struct or 0
  field: matcher      -- matcher address (cannot be 0)
  field: mtcount      -- # of nodes in matcher
  field: rewriter     -- rewriter address (can be 0)
  field: labels-used  -- bitfield
end-struct

|: new-ir-pattern  ( -- addr^ )
  ir-pattern:@size-of dynmem:?zalloc
  TPAT:(curr-match-head) over ir-pattern:matcher:!
  TPAT:(curr-match-count) over ir-pattern:mtcount:!
  TPAT:(curr-rewrite-head) over ir-pattern:rewriter:!
  0
  TPAT:(match-label-seen?) ?< ir-pat-matcher-lbl or >?
  TPAT:(rewriter-label-seen?) ?< ir-pat-rewriter-lbl or >?
  over ir-pattern:labels-used:! ;

|: append-ir-pattern-to  ( pat^ lhead^ )
  dup @
  ( pat^ lhead^ pdb^ )
  dup ?< nip
    ( pat^ pdb^ )
    << dup ir-pattern:next ?^| ir-pattern:next |? else| >>
    ( pat^ last^ )
    ir-pattern:next:!
  || drop !
  >? ;

|: append-ir-pattern  ( pat^ spfa )
  shword:ir-patdb:^
  append-ir-pattern-to ;


|: (pat-xfind)  ( addr count -- scfa TRUE // FALSE )
  2dup vocid: forth-shadows find-in-vocid ?exit< nrot 2drop true >?
  vocid: system-shadows find-in-vocid ;


|: (mnode-spfa)  ( mnode^ -- spfa TRUE // FALSE )
  dup TPAT:mnode:spfa dup ?exit< nip true >? drop
  dup TPAT:mnode:name$ count
  ( mnode^ addr count )
  \ 2dup endcr ." <" type ." >\n"
  (pat-xfind) ?exit<
    ( mnode^ scfa )
    dart:cfa>pfa
    tuck swap TPAT:mnode:spfa:! ;; cache it
    true
  >?
  drop false ;


|: (mnode-fwdlist-pfa)  ( mnode^ -- pfa )
  dup TPAT:mnode:name$ count vocid: PATDB find-in-vocid ?exit<
    ( mnode^ cfa )
    nip dart:cfa>pfa
  >?
  TPAT:mnode:name$ count
  ( addr count )
  [ DEBUG-PDB-SETTERS? ] [IF]
    endcr ." !!! PDB-DEBUG: new postponed pattern list for \'"
    2dup type
    ." \'\n"
  [ENDIF]
  push-cur vocid: PATDB current!
  system:mk-create
    ( head) 0 ,
  system:latest-pfa
  pop-cur ;


;; CANNOT return string in PAD!
:noname  ( node^ -- addr count )
  node:spfa shword:self-cfa dart:cfa>nfa idcount
; TPAT:(pmat-get-node-name):!


;; called when the pattern is finished
:noname
  [ 0 ] [IF]
    endcr ." === MATCHER NODES ===\n"
    TPAT:(curr-match-head) TPAT:dump-match-nodes
  [ENDIF]
  [ 0 ] [IF]
    endcr ." === REWRITE NODES ===\n"
    TPAT:(curr-rewrite-head) TPAT:dump-rewrite-nodes
  [ENDIF]
  [ DEBUG-PDB-SETTERS? drop 0 ] [IF]
    endcr ." >>>FINISHED pattern for "
    TPAT:(curr-match-head) TPAT:mnode:name$ count type
    cr
  [ENDIF]
  new-ir-pattern
  dup ir-pattern:matcher
  ( pat^ mnode^ )
  dup (mnode-spfa) ?exit< ( pat^ mnode^ spfa )
    [ DEBUG-PDB-SETTERS? ] [IF]
      endcr ." !!! PDB-DEBUG: new pattern for \'"
      over TPAT:mnode:spfa shword:self-cfa dart:cfa>nfa debug:.id
      ." \'\n"
    [ENDIF]
    nip append-ir-pattern
  >?
  ;; no shadow word yet, register in PATDB
  ( pat^ mnode^ )
  [ DEBUG-PDB-SETTERS? drop 0 ] [IF]
    endcr ." >>>POSTPONED pattern for "
    dup TPAT:mnode:name$ count type
    ."  (fwdlist-pfa: $" dup TPAT:mnode:fwdlist-pfa .hex8 ." )"
    cr
  [ENDIF]
  (mnode-fwdlist-pfa)
  ( pat^ pfa )
  append-ir-pattern-to
; TPAT:(pmat-pattern-finished):!


;; the following two callbacks should be used to setup the module stack
:noname
  push-ctx
  0 vsp-push  ;; terminator
  voc-ctx: FORTH
  push-ctx
; TPAT:(pmat-begin-forth-rewriter):!

:noname
  pop-ctx
  context@ vocid: FORTH = not?error" module imbalance! (0)"
  vsp-pop ?error" module imbalance! (1)"
  pop-ctx
; TPAT:(pmat-end-forth-rewriter):!


:noname  ( addr count -- spfa ) -- throw an error if not found
  [ 0 ] [IF]
    endcr ." ###XFIND: <" 2dup type ." >\n"
  [ENDIF]
  2dup (pat-xfind) not?<
    " cannot find ZX word \'" pad$:! pad$:+ " \'!" pad$:+
    pad$:@ error
  >?
  dart:cfa>pfa
  nrot 2drop
; TPAT:(pmat-find-spfa):!


:noname  ( node^ -- spfa )
  node:spfa
; TPAT:(pmat-node-spfa):!


|: (pmat-get-nth-node)  ( index -- node^ )
  [ DEBUG-PDB-ACTIONS? drop 0 ] [IF]
    endcr ." getting node #" dup 0.r cr
  [ENDIF]
  dup -?error" ICE: negative node index in \'(pmat-get-nth-node)\'!"
  pmat-pattern-matched swap for
    dup 0?error" ICE: invalid node index in \'(pmat-get-nth-node)\'!"
    TPAT:mnode:next
  endfor
  dup 0?error" ICE: invalid node index in \'(pmat-get-nth-node)\'!"
  TPAT:mnode:node ;


;; get argument from the matched node
:noname  ( src-type node-index -- value )
  (pmat-get-nth-node)
  ( src-type node^ )
  swap <<
    -1 of?v| node:ir-dest |?
     0 of?v| node:value w>s |?
     1 of?v| node:value2 w>s |?
     2 of?v| node:value3 w>s |?
  else| error" ICE: invalid argument index in \'TPAT:(pmat-get-arg)\'!" >>
; TPAT:(pmat-get-arg):!


:noname  ( node^ type -- value )
  [ 0 ] [IF]
    endcr ." GETTING marg: type=" dup .
    ." from node " over node:spfa shword:self-cfa dart:cfa>nfa debug:.id
    cr
  [ENDIF]
  <<
    -1 of?v| node:ir-dest |?
     0 of?v| node:value w>s |?
     1 of?v| node:value2 w>s |?
     2 of?v| node:value3 w>s |?
  else| error" ICE: invalid argument index in \'TPAT:(pmat-get-marg)\'!" >>
; TPAT:(pmat-get-marg):!


:noname  ( value rvalue^ )  -- set current rewriting node argument using info from rvalue
  [ DEBUG-PDB-ACTIONS? ] [IF]
    endcr ." ...setting rvalue to " over .
    ." (dest-type=" dup TPAT:rvalue:dest-type 0.r
    ." )\n"
  [ENDIF]
  pmat-new-node swap
  TPAT:rvalue:dest-type <<
    -1 of?v| node:ir-dest:! |?
     0 of?v| swap w>s swap node:value:! |?
     1 of?v| swap w>s swap node:value2:! |?
     2 of?v| swap w>s swap node:value3:! |?
  else| error" ICE: invalid argument index in \'TPAT:(pmat-set-arg)\'!" >>
; TPAT:(pmat-set-arg):!


;; attach to the first pattern node (last parsed)
: pattern:[[
  TPAT:pattern:[[
;


:noname  ( mnode^ ir-node^ spfa -- mnode^ ir-node^ spfa )
  [ DEBUG-PDB-MATCHING? ] [IF]
  endcr ." DMX: mnode is \'" dup shword:self-cfa dart:cfa>nfa debug:.id
  ." \' -- ir-node is \'" over node:spfa shword:self-cfa dart:cfa>nfa debug:.id
  ." \'\n"
  [ENDIF]
; TPAT:(pmat-mt-debug):!


0 quan (cnm-first-mnode)

|: curr-node-matches?  ( mnode^ -- matched? )
  [ DEBUG-PDB-MATCHING? ] [IF]
    endcr ." +++ CHECK MNODE $" dup .hex8
    ."  for " dup TPAT:mnode:name$ count type
    cr
  [ENDIF]
  [ 0 ] [IF]
    endcr ." === CHECKING PATTERN ===\n"
    dup TPAT:dump-match-nodes-list
  [ENDIF]
  dup (cnm-first-mnode):!
  ;; run pre-condition checker
  curr-node over dup TPAT:mnode:cond-cfa execute not?exit< drop false >?
  ;; run argument matchers
  curr-node << ( mnode^ ir-node^ )
    over ?^|
      dup 0?exit< 2drop false >?
      ;; run checker (nope, only for the first node)
      \ 2dup 2>r
      \ swap dup TPAT:mnode:cond-cfa execute not?exit< 2rdrop false >?
      2>r
      ;; run matcher
      2r@
      swap dup TPAT:mnode:cfa execute not?exit< 2rdrop false >?
      ;; move to the next nodes
      2r>
      swap TPAT:mnode:next
      swap node:prev
    |?
  else| >>
  ( mnode^ ir-node^ )
  2drop
  ;; run post-checker (it is always attached to the first mnode)
  (cnm-first-mnode) TPAT:mnode:post-cfa execute ;


: pmat-free-matched-nodes
  pmat-pattern-matched <<
    TPAT:mnode:next dup ?^| free-prev-node |?
  else| drop >>
  free-curr-node ;


|: (rnode-spfa)  ( rnode^ -- spfa )
  dup TPAT:rnode:spfa dup ?exit< nip >? drop
  dup TPAT:rnode:name$ count TPAT:(pmat-find-spfa)
  ( rnode^ spfa )
  tuck swap TPAT:rnode:spfa:! ;


: curr-node-run-rewriter  ( pat^ )
  dup ir-pattern:matcher pmat-pattern-matched:!
  dup ir-pattern:labels-used 0<> pmat-branch-optim?:!
  ir-pattern:rewriter dup pmat-pattern-rewriter:!
  was-optim!
  dup ?<
    ;; insert new nodes
    curr-node pmat-new-node:!
    << ( rnode^ )
      dup ?^|
        [ 0 ] [IF]
          endcr ." ...NEW NODE: " dup TPAT:rnode:name$ count type cr
        [ENDIF]
        ;; create the new node
        new-node ( rnode^ node^ )
        ;; insert after current new node
        pmat-new-node over insert-after
        ;; make it new current new
        pmat-new-node:!
        ;; setup new node spfa
        ( rnode^ )
        dup (rnode-spfa)
        ( rnode^ spfa )
        pmat-new-node node:spfa:!
        ( rnode^ )
        dup TPAT:run-rewriter-vlist
        ( rnode^ )
        TPAT:rnode:next
      |?
    else| drop >>
  || drop pmat-new-node:!0 >?
  pmat-free-matched-nodes
  .sopt-patdb
  ;; this is important for literal optimiser! (nope)
  \ pmat-new-node ?< pmat-new-node curr-node! >?
;


: ir-pattern-allowed?  ( pat^ -- flag )
  ir-pattern:labels-used ?<
    OPT-OPTIMIZE-BRANCHES?
  ||
    OPT-OPTIMIZE-SUPER?
  >? ;

;; run pattern database checks for the current node
: curr-node-run-patdb
  curr-node node:spfa shword:ir-patdb
  << ( pat^ )
    dup ?^|
      dup ir-pattern-allowed? ?<
        ;; setting `pmat-pattern-matched` is required for post-checks
        dup ir-pattern:matcher dup pmat-pattern-matched:!
        curr-node-matches?
        ( pat^ matched? )
        ?exit< curr-node-run-rewriter >?
      >?
    ir-pattern:next |?
  else| drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main anayzer loop code

: (opt-clear-label-marks)  ( node^ )
  nflag-label-used swap node-reset-flag ;

: (opt-mark-node-label)  ( node^ )
  node:spfa shword:ir-brlabel dup not?exit< drop >?
  execute dup not?exit< drop >?
  nflag-label-used swap node-set-flag ;

\ TODO: remove preceding "ir-restore-tos"
: (opt-remove-unmarked-labels)  ( node^ )
  dup node:spfa ir-label? not?exit< drop >?
  nflag-label-used swap node-flag? ?exit
    endcr ." *** REMOVED UNUSED LABEL ***\n"
  free-curr-node
  ;; recheck in case we get more optimisations
  was-optim! ;

: curr-node-optim-enabled?  ( -- flag )
  tkf-branch-like curr-node-spfa shword:tk-flags and ?<
    OPT-OPTIMIZE-BRANCHES?
  ||
    OPT-OPTIMIZE-SUPER?
  >? ;

: opt-remove-unused-labels
  ['] (opt-clear-label-marks) ir-foreach-with-node
  ['] (opt-mark-node-label) ir-foreach-with-node
  ['] (opt-remove-unmarked-labels) ir-foreach-with-node ;

: (run-node-analyzer)
  curr-node-optim-enabled? not?exit
  [ OPT-DUMP-IR-OPTIM-CALLS? ] [IF]
    endcr ." ANAL: " curr-node-spfa shword:self-cfa dart:cfa>nfa debug:.id cr
  [ENDIF]
  curr-node-spfa shword:ir-patdb ?< curr-node-run-patdb >?
  curr-node-spfa shword:ir-analyze dup not?exit< drop >?
  depth 1- >r
  execute
  depth r> = not?exit<
    " stack imbalance after optimiser for \'" pad$:!
    curr-node-spfa shword:self-cfa dart:cfa>nfa idcount pad$:+
    " \'!" pad$:+  pad$:@ error
  >? ;

: run-analyzers
  << anal-was-change?:!f anal-check-labels?:!f
     ['] (run-node-analyzer) ir-foreach
     anal-check-labels? ?< opt-remove-unused-labels >?
     anal-was-change? ?^||
  else| >> ;


;; n DUP -> n n
: (expand-n-DUP-cb)
  curr-node-optim-enabled? not?exit
  (opt-zx-dup) curr-node-spfa = not?exit
  prev-node node-lit? not?exit
  " EXPAND: n DUP -> n n" .sopt-notice
  new-lit-node replace-curr-node ;

;; expand `n DUP` to `n n`, this helps constant folder
: expand-n-DUP
  ['] (expand-n-DUP-cb) ir-foreach ;


false quan was-compress?

;; n n -> n DUP
: (compress-n-n-cb)
  curr-node-optim-enabled? not?exit
  curr-node node-lit? not?exit
  prev-node node-lit? not?exit< drop >?
  = not?exit
  " COMPRESS: n n -> n DUP" .sopt-notice
  was-compress?:!t
  (opt-zx-dup) replace-curr-node-spfa ;

;; compress `n n` to `n DUP`.
;; set `was-compress?` flag.
: compress-n-n
  was-compress?:!f
  ['] (compress-n-n-cb) ir-foreach ;


end-module OPT
end-module IR
end-module TCOM
