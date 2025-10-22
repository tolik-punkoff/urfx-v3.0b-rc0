;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; superinstruction optimiser pattern database support
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
pattern: LIT {v} ! --> LIT:! {v}
-- simple rewrite pattern, which extracts IR node valueN, and creates a new node.

pattern: LIT {a} LIT {b} --> LIT {[ a b + ]}
-- constant folding pattern. note the "{[ ... ]}" rewriter. it is possible to
use names from "{}" at the left part in it.

pattern: LIT {v} LIT:! {a} --> LIT:VAL2:! {a} {v}
-- rewrite pattern with 2 values.

pattern:[[ NEGATE LIT:-! {a} {? ( value -- success? ) 0= ?} --> LIT:+! {a} ]]
-- simple Forth argument checker. should come after the corresponding "{}" arg.

pattern:[[ LIT:1C@ {a0} LIT:C@ {a1} {: a0 a1 = :} --> LIT:@-HI-LO {a0} ]]
-- Forth post-condition checker. must be the last before "-->".

pattern: <= 0BRANCH {@l} --> >BRANCH {@l}
-- branch rewriter. {@...} means "labels from this node".
*)


module TPAT

;; cond-cfa is called before the matcher
struct:new mnode
  field: next       -- next node or 0
  field: cfa        -- matcher: ( ir-node^ mnode^ -- success? )
  field: cond-cfa   -- condition checker for this node: ( ir-node^ mnode^ -- success? )
  field: post-cfa   -- post-condition checker; used for `{: ... :}` ( -- success? )
  ;; data for standard nodes
  field: spfa       -- spfa of the word to match; 0 means "unknown yet"
  field: name$      -- word name to match, because we are doing lazy resolving
  field: margs      -- arguments; retained for checks
  ;; user data, not used by the default handlers
  field: udata
  ;; saved node address.
  ;; all matched nodes will be freed *AFTER* rewriting.
  ;; this is so we could access their fields.
  field: node
end-struct


0 quan matcher-ir-node

;; matcher argument list node
struct:new marg
  field: next       -- next value or 0
  field: name$      -- dynstring
  field: type       -- <0: labels; 0, 1, 2: valueN
  ;; when the checker is called, `matcher-ir-node` is properly set
  field: check-cfa  -- ( value -- success? )
end-struct


;; replacement value list node
struct:new rvalue
  field: next       -- next value or 0
  field: node-index -- in the matched array; indexed back from the current node
  field: src-type   -- <0: labels; 0, 1, 2: valueN
  field: dest-type  -- <0: labels; 0, 1, 2: valueN
  field: cfa        -- processor; can be default or custom for `{[ ... ]}`; ( rvalue^ -- value )
  field: rnode      -- pointer to the parent rnode
end-struct

;; replacement node
struct:new rnode
  field: next   -- next node or 0
  ;; data for standard nodes
  field: spfa   -- spfa of the word to match; 0 means "unknown yet"
  field: name$  -- word name to match, because we are doing lazy resolving
  field: vlist  -- pointer to values list for the new node
  ;; user data, not used by the default handlers
  field: udata
  ;; newly created node
  field: node
end-struct


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; callbacks to be set by the user

;; called when the pattern is finished
vect (pmat-pattern-finished)

;; the following two callbacks should be used to setup the module stack
vect (pmat-begin-forth-rewriter)
vect (pmat-end-forth-rewriter)

vect (pmat-find-spfa)  ( addr count -- spfa ) -- throw an error if not found
vect (pmat-node-spfa)  ( node^ -- spfa )

vect (pmat-get-arg)  ( src-type node-index -- value )
vect (pmat-set-arg)  ( value rvalue^ )  -- set current rewriting node argument using info from rvalue

vect (pmat-get-marg)  ( node^ type -- value )

;; CANNOT return string in PAD!
vect (pmat-get-node-name)  ( node^ -- addr count )


: (pmat-find-spfa-dummy)  ( addr count -- spfa )
  " cannot find ZX word \'" pad$:! pad$:+ " \'!" pad$:+
  pad$:@ error ;
['] (pmat-find-spfa-dummy) (pmat-find-spfa):!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
: pmat-default-cond  ( ir-node^ mnode^ -- success? )  2drop true ;
: pmat-default-post-cond  ( -- success? )  true ;

vect (pmat-mt-debug)  ( mnode^ ir-node^ spfa -- mnode^ ir-node^ spfa )

: pmat-mnode-spfa  ( mnode^ -- spfa )
  dup mnode:spfa dup ?exit< nip >? drop
  dup mnode:name$ count (pmat-find-spfa)
  ( mnode^ spfa )
  tuck swap mnode:spfa:! ;


|: (pmat-check-margs)  ( mnode^ ir-node^ -- success? )
  swap mnode:margs dup 0?exit< 2drop true >?
  swap matcher-ir-node:!
  << ( marg^ )
    dup ?^|
      dup marg:check-cfa ?<
        >r
        matcher-ir-node r@ marg:type (pmat-get-marg)
        r@ depth 1- >r
        marg:check-cfa execute
        depth r> = not?exit<
          " ICE: depth imbalance in pdb arg checker for \'" pad$:!
          matcher-ir-node (pmat-get-node-name) pad$:+
          " \'!" pad$:+
          pad$:@ error
        >?
        not?exit< rdrop false >?
        r>
      >?
    marg:next |?
  else| drop >>
  true ;

: pmat-default-matcher  ( ir-node^ mnode^ -- success? )
  over 0?exit< 2drop false >?
  dup mnode:spfa dup 0?< drop
    dup mnode:name$ count (pmat-find-spfa)
    ( ir-node^ mnode^ spfa )
    2dup swap mnode:spfa:!
  >?
  ( ir-node^ mnode^ spfa )
  rot swap
  ( mnode^ ir-node^ spfa )
  [ 1 ] [IF]
    (pmat-mt-debug)
  [ENDIF]
  over (pmat-node-spfa) = not?exit< 2drop false >?
  ( mnode^ ir-node^ )
  2dup (pmat-check-margs) not?exit< 2drop false >?
  swap mnode:node:!
  true ;

;; used in Forth rewriter too
: pmat-get-arg  ( rvalue^ -- arg )
  dup TPAT:rvalue:src-type
  swap TPAT:rvalue:node-index
  (pmat-get-arg) ;

: (pmat-get-arg-internal)
  (pmat-get-arg) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; helpers

: run-rewriter-vlist  ( rnode^ )
  rnode:vlist << ( rvalue^ )
    dup ?^|
      dup >r
      ( rvalue^ | rvalue^ )
      depth >r
      dup rvalue:cfa execute
      depth r> = not?<
        \ error" ICE: rewriter rvalue processor imbalance!"
        " ICE: depth imbalance in pdb rvaluer processor for \'" pad$:!
        matcher-ir-node (pmat-get-node-name) pad$:+
        " \'!" pad$:+
        pad$:@ error
      >?
      ( value | rvalue^ )
      r@
      \ depth 2 - >r
      (pmat-set-arg)
      \ depth r> = not?error" ICE: rewriter setarg imbalance!"
    r> rvalue:next |?
  else| drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; matcher nodes are added in reverse order
0 quan (curr-match-head)
0 quan (curr-match-vidx)  ;; next value index for args
0 quan (curr-match-lbl?)  ;; label already specified?
0 quan (curr-match-count)

;; rewrite nodes are added in normal order
0 quan (curr-rewrite-head)
0 quan (curr-rewrite-tail)
0 quan (curr-rewrite-vidx)  ;; next value index for args
0 quan (curr-rewrite-lbl?)  ;; label already specified?

0 quan (match-label-seen?)
0 quan (rewriter-label-seen?)


: reset-parser-state
  (curr-match-head):!0
  (curr-match-vidx):!0
  (curr-match-lbl?):!f
  (curr-match-count):!0

  (curr-rewrite-head):!0
  (curr-rewrite-tail):!0
  (curr-rewrite-vidx):!0
  (curr-rewrite-lbl?):!f

  (match-label-seen?):!f
  (rewriter-label-seen?):!f
;

: reset-match-node-args
  (curr-match-vidx):!0
  (curr-match-lbl?):!f
  (match-label-seen?):!f
;

: reset-rewrite-node-args
  (curr-rewrite-vidx):!0
  (curr-rewrite-lbl?):!f
  (rewriter-label-seen?):!f
;


(*
;; we don't need margs list anymore
|: (free-node-margs)  ( mnode^ )
  dup mnode:margs << ( mnode^ marg^ )
    dup ?^|
      dup mnode:name$ string:$free
      dup mnode:next
      swap dynmem:free
    |?
  else| drop >>
  0 swap mnode:margs:! ;


: free-margs
  (curr-match-head) <<
    dup ?^|
      dup (free-node-margs)
      mnode:next
    |?
  else| drop >> ;
*)


|: marg-find-at  ( addr count marg^ -- marg^ TRUE // FALSE )
  <<  ( addr count marg^ )
    dup ?^|
      >r 2dup r@ marg:name$ count string:=ci ?exit< 2drop r> true >?
      r> marg:next
    |?
  else| 3drop false >> ;


: marg-find  ( addr count -- marg^ TRUE // FALSE )
  (curr-match-head) dup not?error" wtf?!"
  << ( mnode^ )
    >r 2dup r@ mnode:margs marg-find-at ?exit< rdrop nrot 2drop true >?
  r> mnode:next dup ?^||
  else| 3drop >>
  false ;


0 quan marg-node
0 quan marg-index

: marg-find-for-rvalue  ( addr count -- marg^ TRUE // FALSE )
  (curr-match-head) dup not?error" wtf?!"
  marg-index:!0
  << ( mnode^ )
    marg-node:!
    2dup marg-node mnode:margs marg-find-at ?exit< nrot 2drop true >?
    marg-index:1+!
  marg-node mnode:next dup ?^||
  else| 3drop >>
  false ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dump matcher nodes

|: (dump-match-node)  ( mnode^ )
  dup 0?exit< drop >?
  endcr ." MT-NODE for \'" dup mnode:name$ count type ." \'"
  dup mnode:margs 0?exit< drop cr >?
  ."  -- args:"
  mnode:margs << ( marg^ )
    ."  {" dup marg:name$ count type
    ." }(" dup marg:type 0.r ." )"
  marg:next dup ?^||
  else| drop >>
  cr ;

|: (dump-match-nodes-list)  ( mnode^ )
  dup 0?exit< drop >?
  dup mnode:next recurse
  (dump-match-node) ;


: dump-match-nodes
  (curr-match-head) (dump-match-nodes-list) ;

: dump-match-nodes-list  ( mnode^ )
  (dump-match-nodes-list) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dump rewriter nodes

|: (dump-rvalue)  ( rvalue^ )
  ." @(" dup rvalue:node-index 0.r ." )"
  ." {d:" dup rvalue:dest-type 0.r ." }"
  dup rvalue:cfa ['] pmat-get-arg = ?exit<
    ." [t:" rvalue:src-type 0.r ." ]"
  >?
  drop ." [Forth]" ;


|: (dump-rewrite-node)  ( rnode^ )
  endcr ." RW-NODE \'" dup rnode:name$ count type ." \'"
  rnode:vlist dup 0?exit< drop cr >?
  ."  -- args:"
  << ( rnode^ )
    bl emit dup (dump-rvalue)
  rnode:next dup ?^||
  else| drop >>
  cr ;


: dump-rewrite-nodes
  (curr-rewrite-head) << ( rnode^ )
    dup ?^|
      dup (dump-rewrite-node)
      rnode:next
    |?
  else| drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; two modules with special finders

module TPAT-MATCHER-PARSER
<disable-hash>
end-module TPAT-MATCHER-PARSER

module TPAT-MATCHER-FORTH-SIMPLECHECK-PARSER
<disable-hash>
end-module TPAT-MATCHER-FORTH-SIMPLECHECK-PARSER

module TPAT-MATCHER-FORTH-POSTCHECK-PARSER
<disable-hash>
end-module TPAT-MATCHER-FORTH-POSTCHECK-PARSER

module TPAT-REWRITER-PARSER
<disable-hash>
end-module TPAT-REWRITER-PARSER

module TPAT-REWRITER-FORTH-PARSER
<disable-hash>
end-module TPAT-REWRITER-FORTH-PARSER


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; parse matches

extend-module TPAT-MATCHER-PARSER

;; end of pattern
: ]]
  error" no rewriter!"
;

;; start of rewriter
: -->
  (curr-match-head) not?error" no pattern!"
  context@ vocid: TPAT-MATCHER-PARSER = not?error" module imbalance!"
  voc-ctx: TPAT-REWRITER-PARSER
;

: {?
  ;; Forth code
  context@ vocid: TPAT-MATCHER-PARSER = not?error" module imbalance!"
  (pmat-begin-forth-rewriter)
  voc-ctx: TPAT-MATCHER-FORTH-SIMPLECHECK-PARSER
  [\\] :noname ;

: {:
  ;; Forth code
  context@ vocid: TPAT-MATCHER-PARSER = not?error" module imbalance!"
  (pmat-begin-forth-rewriter)
  voc-ctx: TPAT-MATCHER-FORTH-POSTCHECK-PARSER
  [\\] :noname ;

end-module TPAT-MATCHER-PARSER


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; parse simple Forth checkers
;; TODO: different calbacks, do not reuse rewriter ones!

extend-module TPAT-MATCHER-FORTH-SIMPLECHECK-PARSER

*: ?}
  system:?comp
  context@ vocid: TPAT-MATCHER-FORTH-SIMPLECHECK-PARSER = not?error" module imbalance!"
  (pmat-end-forth-rewriter)
  [\\] forth:;
  (curr-match-head) mnode:margs dup 0?error" checker for which arg?"
  ( cfa marg^ )
  marg:check-cfa:!
  voc-ctx: TPAT-MATCHER-PARSER ;

*: ]]
  error" Forth checker is not finished!" ;

*: ]}
  error" Forth checker is not finished!" ;

*: -->
  error" Forth checker is not finished!" ;

*: ->
  error" Forth checker is not finished!" ;

*: ;
  error" use \']}\' to finish Forth argument checker!" ;

end-module TPAT-MATCHER-FORTH-SIMPLECHECK-PARSER


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; parse Forth post-checker
;; TODO: different calbacks, do not reuse rewriter ones!

extend-module TPAT-MATCHER-FORTH-POSTCHECK-PARSER

*: :}
  system:?comp
  context@ vocid: TPAT-MATCHER-FORTH-POSTCHECK-PARSER = not?error" module imbalance!"
  (pmat-end-forth-rewriter)
  [\\] forth:;
  (curr-match-head)
  ( cfa mnode^ )
  mnode:post-cfa:!
  voc-ctx: TPAT-MATCHER-PARSER ;

*: ]]
  error" Forth checker is not finished!" ;

*: ]}
  error" Forth checker is not finished!" ;

*: -->
  error" Forth checker is not finished!" ;

*: ->
  error" Forth checker is not finished!" ;

*: ;
  error" use \']}\' to finish Forth argument checker!" ;

end-module TPAT-MATCHER-FORTH-POSTCHECK-PARSER


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; parse rewrites

extend-module TPAT-REWRITER-PARSER

;; end of pattern
: ]]
  context@ vocid: TPAT-REWRITER-PARSER = not?error" module imbalance!"
  pop-ctx
  \ free-margs
  (pmat-pattern-finished) ;

;; start of rewriter
: -->
  error" already in rewriter!" ;

: {[
  ;; Forth code
  context@ vocid: TPAT-REWRITER-PARSER = not?error" module imbalance!"
  (pmat-begin-forth-rewriter)
  voc-ctx: TPAT-REWRITER-FORTH-PARSER
  [\\] :noname
  \\ drop ;; drop unused `rvalue^`
;

end-module TPAT-REWRITER-PARSER


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; parse Forth rewrites

extend-module TPAT-REWRITER-FORTH-PARSER

*: ]}
  system:?comp
  context@ vocid: TPAT-REWRITER-FORTH-PARSER = not?error" module imbalance!"
  (pmat-end-forth-rewriter)
  [\\] forth:;
  [ 0 ] [IF]
    endcr ." ::: SETTING FRW for " (curr-rewrite-tail) rnode:name$ count type cr
  [ENDIF]
  (curr-rewrite-tail) rnode:vlist rvalue:cfa:!
  voc-ctx: TPAT-REWRITER-PARSER ;

*: ]]
  error" Forth rewriter is not finished!" ;

*: -->
  error" already in rewriter!" ;

*: ->
  error" already in rewriter!" ;

*: ;
  error" use \']}\' to finish Forth argument rewriter!" ;

end-module TPAT-REWRITER-FORTH-PARSER


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; matcher parsing code
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; argument name parsing

|: mtparser-bad-arg  ( addr count )
  " invalid argument: \'" pad$:! pad$:+ " \'!" pad$:+ pad$:@ error
; (noreturn)

|: mtparser-bad-arg-{}  ( addr count )
  " invalid argument: \'{" pad$:! pad$:+ " }\'!" pad$:+ pad$:@ error
; (noreturn)


|: ?mtparser-arg-name-len  ( addr count -- addr count )
  dup 3 < ?< mtparser-bad-arg >? ;

|: ?mtparser-arg-name-end  ( addr count -- addr count )
  ?mtparser-arg-name-len
  2dup + 1- c@ [char] } = not?< mtparser-bad-arg >? ;

|: ?mtparser-label-name  ( addr count -- addr count )
  ?mtparser-arg-name-end
  over 1+ c@ [char] @ = not?exit
  dup 4 < ?< mtparser-bad-arg >?
  2dup + 2 - c@ [char] @ = not?< mtparser-bad-arg >? ;

|: ?mtparser-arg-name  ( addr count -- addr count )
  ?mtparser-arg-name-end ;


|: mtparser-new-marg  ( addr count -- marg^ )
  string:$new
  marg:@size-of dynmem:?zalloc
  tuck marg:name$:!
  (curr-match-head) mnode:margs over marg:next:!
  dup (curr-match-head) mnode:margs:! ;


|: mtparser-new-label  ( addr count )
  (curr-match-lbl?) ?<
    endcr ." ERROR: duplicate label argument!" cr
    mtparser-bad-arg-{}
  >?
  (curr-match-lbl?):!t
  (match-label-seen?):!t
  mtparser-new-marg
  -1 swap marg:type:! ;

|: mtparser-new-value  ( addr count )
  (curr-match-vidx) 3 >= ?<
    endcr ." ERROR: too many value arguments!" cr
    mtparser-bad-arg-{}
  >?
  mtparser-new-marg
  (curr-match-vidx) swap marg:type:!
  (curr-match-vidx):1+! ;

;; guaranteed to start with "{"
|: mtparser-arg  ( addr count )
  ?mtparser-arg-name
  (curr-match-head) 0?error" arguments for what?"
  ;; remove brackets
  1 under+ 2-
  2dup marg-find ?< drop
    " duplicate argument: \'{" pad$:! pad$:+ " }\'!" pad$:+ pad$:@ error
  >?
  ;; create new argument
  over c@ [char] @ = ?< mtparser-new-label || mtparser-new-value >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; new matcher node parsing

;; matcher nodes are added in reverse order
|: mtparser-new-mnode  ( addr count -- mnode^ )
  string:$new
  mnode:@size-of dynmem:?zalloc
  tuck mnode:name$:!
  (curr-match-head) over mnode:next:!
  dup (curr-match-head):!
  ['] pmat-default-matcher over mnode:cfa:!
  ['] pmat-default-cond over mnode:cond-cfa:!
  ['] pmat-default-post-cond over mnode:post-cfa:!
;

|: mtparser-node  ( addr count )
  reset-match-node-args
  mtparser-new-mnode
  drop
  (curr-match-count):1+!
;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; pattern parser callbacks

|: mtparser-execcomp-cb  ( cfa -- ... TRUE // cfa FALSE )
  system:?exec
  << -666 of?v||
     -667 of?v| TPAT-MATCHER-PARSER:--> |?
     -668 of?v| TPAT-MATCHER-PARSER:]] |?
     -669 of?v| TPAT-MATCHER-PARSER:{? |?
     -665 of?v| TPAT-MATCHER-PARSER:{: |?
  else| error" ICE: wtf?! the Hell mark is missing!" >>
  true ;
['] mtparser-execcomp-cb vocid: TPAT-MATCHER-PARSER system:vocid-execcomp-cfa!

|: mtparser-find-cb  ( addr count skip-hidden? vocid -- cfa TRUE // FALSE )
  system:?exec 2drop
  \ endcr ." <" 2dup type ." >\n"
  2dup " ->" string:= ?error" use \'-->\'!"
  2dup " -->" string:= ?exit< 2drop -667 true >? ;; go on
  2dup " ]]" string:= ?exit< 2drop -668 true >?  ;; go on
  2dup " {?" string:= ?exit< 2drop -669 true >?  ;; go on
  2dup " {:" string:= ?exit< 2drop -665 true >?  ;; go on
  ;; create new pattern node, or parse an arg `{...}`
  \ endcr ." <" 2dup type ." >\n"
  over c@ [char] { = ?< mtparser-arg || mtparser-node >?
  -666 true ;
['] mtparser-find-cb vocid: TPAT-MATCHER-PARSER system:vocid-find-cfa!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rewriter parsing code
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; argument name parsing

|: rwparser-bad-arg  ( addr count )
  " invalid argument: \'" pad$:! pad$:+ " \'!" pad$:+ pad$:@ error
; (noreturn)

|: rwparser-bad-arg-{}  ( addr count )
  " invalid argument: \'{" pad$:! pad$:+ " }\'!" pad$:+ pad$:@ error
; (noreturn)


|: ?rwparser-arg-name-len  ( addr count -- addr count )
  dup 3 < ?< rwparser-bad-arg >? ;

|: ?rwparser-arg-name-end  ( addr count -- addr count )
  ?rwparser-arg-name-len
  2dup + 1- c@ [char] } = not?< rwparser-bad-arg >? ;

|: ?rwparser-label-name  ( addr count -- addr count )
  ?rwparser-arg-name-end
  over 1+ c@ [char] @ = not?exit
  rwparser-bad-arg ;

|: ?rwparser-arg-name  ( addr count -- addr count )
  ?rwparser-arg-name-end ;

|: ?rwparser-not-fth-name  ( addr count -- addr count )
  dup 2 < ?exit
  over c@ [char] { = not?exit
  over 1+ c@ [char] [ = not?exit
  error" delimit \'{[\' with space!" ;


;; can be called with `0` to create rvalue suitable for Forth checker
|: rwparser-new-rvalue  ( marg^ -- rvalue^ )
  (curr-rewrite-vidx) 3 >= ?error" too many values in rewriter!"
  >r
  rvalue:@size-of dynmem:?zalloc
  (curr-rewrite-tail) rnode:vlist over rvalue:next:!
  dup (curr-rewrite-tail) rnode:vlist:!
  (curr-rewrite-tail) over rvalue:rnode:!
  ['] pmat-get-arg over rvalue:cfa:!
  ( rvalue^ | marg^ )
  marg-index over rvalue:node-index:!
  r> dup ?< marg:type over rvalue:src-type:! || drop >?
  (curr-rewrite-vidx) over rvalue:dest-type:!
  (curr-rewrite-vidx):1+! ;

;; sorry for the pasta!
|: rwparser-new-rvalue-label  ( marg^ -- rvalue^ )
  (curr-rewrite-lbl?) ?error" duplicate label value in rewriter!"
  >r
  rvalue:@size-of dynmem:?zalloc
  (curr-rewrite-tail) rnode:vlist over rvalue:next:!
  dup (curr-rewrite-tail) rnode:vlist:!
  (curr-rewrite-tail) over rvalue:rnode:!
  ['] pmat-get-arg over rvalue:cfa:!
  ( rvalue^ | marg^ )
  marg-index over rvalue:node-index:!
  r> marg:type -1 = not?error" ICE: marg is not a label rewriter!"
  -1 over rvalue:src-type:!
  -1 over rvalue:dest-type:!
  (rewriter-label-seen?):!t
  (curr-rewrite-lbl?):!t ;


;; guaranteed to start with "{"
|: rwparser-arg  ( addr count )
  ?rwparser-not-fth-name
  ?rwparser-arg-name
  (curr-rewrite-tail) 0?error" arguments for what?"
  ;; remove brackets
  1 under+ 2-
  2dup marg-find-for-rvalue not?< rwparser-bad-arg-{} >?
  ( addr count marg^ )
  nrot drop c@ [char] @ = ?< rwparser-new-rvalue-label || rwparser-new-rvalue >?
  drop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; new matcher node parsing

;; rewrite nodes are added in normal order
|: rwparser-new-rnode  ( addr count -- rnode^ )
  string:$new
  rnode:@size-of dynmem:?zalloc
  tuck rnode:name$:!
  (curr-rewrite-tail) ?<
    dup (curr-rewrite-tail) rnode:next:!
  || dup (curr-rewrite-head):! >?
  dup (curr-rewrite-tail):!
;

|: rwparser-node  ( addr count )
  reset-rewrite-node-args
  rwparser-new-rnode
  drop
;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rewriter parser callbacks

|: rwparser-execcomp-cb  ( cfa -- ... TRUE // cfa FALSE )
  system:?exec
  << -666 of?v||
     -667 of?v| TPAT-REWRITER-PARSER:--> |?
     -668 of?v| TPAT-REWRITER-PARSER:]] |?
     -669 of?v|
        0 rwparser-new-rvalue drop
        TPAT-REWRITER-PARSER:{[
      |?
  else| error" ICE: wtf?! the Hell mark is missing!" >>
  true ;
['] rwparser-execcomp-cb vocid: TPAT-REWRITER-PARSER system:vocid-execcomp-cfa!

|: rwparser-find-cb  ( addr count skip-hidden? vocid -- cfa TRUE // FALSE )
  system:?exec 2drop
  2dup " ->" string:= ?error" use \'-->\'!"
  2dup " -->" string:= ?exit< 2drop -667 true >? ;; go on
  2dup " ]]" string:= ?exit< 2drop -668 true >?  ;; go on
  2dup " {[" string:= ?exit< 2drop -669 true >?  ;; go on
  ;; create new pattern node, or parse an arg `{...}`
  over c@ [char] { = ?< rwparser-arg || rwparser-node >?
  -666 true ;
['] rwparser-find-cb vocid: TPAT-REWRITER-PARSER system:vocid-find-cfa!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Forth rewriter parser callbacks

|: forth-rwparser-notfound-cb  ( addr count -- processed? )
  system:comp? not?exit< 2drop false >?
  marg-find-for-rvalue not?exit&leave
  ( marg^ )
  marg:type [\\] {#,} ;; src-type
  marg-index [\\] {#,} ;; node-index
  \\ (pmat-get-arg-internal)
  true ;
['] forth-rwparser-notfound-cb vocid: TPAT-REWRITER-FORTH-PARSER system:vocid-notfound-cfa!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Forth postchecker parser callbacks

|: forth-postchecker-notfound-cb  ( addr count -- processed? )
  system:comp? not?exit< 2drop false >?
  marg-find-for-rvalue not?exit&leave
  ( marg^ )
  marg:type [\\] {#,} ;; src-type
  marg-index [\\] {#,} ;; node-index
  \\ (pmat-get-arg-internal)
  true ;
['] forth-postchecker-notfound-cb vocid: TPAT-MATCHER-FORTH-POSTCHECK-PARSER system:vocid-notfound-cfa!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create new pattern
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

: pattern:[[
  system:?exec
  reset-parser-state
  push-ctx
  voc-ctx: TPAT-MATCHER-PARSER
;

end-module TPAT


\EOF
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test patterns
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extend-module TPAT

pattern:[[ NEGATE LIT:+! {a} --> LIT:-! {a} ]]
." === MATCH NODES ===\n"
dump-match-nodes
." === REWRITE NODES ===\n"
dump-rewrite-nodes

pattern:[[ LIT {v} LIT:-! {a} --> LIT:VAL2:+! {a} {[ v negate ]} ]]
." === NODES ===\n"
dump-match-nodes
." === REWRITE NODES ===\n"
dump-rewrite-nodes

end-module TPAT

(*
pattern:[[ NEGATE LIT:-! {a} --> LIT:+! {a} ]]

pattern:[[ LIT:+ {v} LIT:!1 {a} --> LIT:+:!1 {[ a v + ]} ]]

pattern:[[ LIT {v} LIT:+! {a} --> LIT:VAL2:+! {a} {v} ]]
pattern:[[ LIT {v} LIT:-! {a} --> LIT:VAL2:+! {a} {[ v negate ]} ]]

;; simple Forth argument checker
pattern:[[ NEGATE LIT:-! {a} {? ( value -- success? ) ... ?} --> LIT:+! {a} ]]

*)
