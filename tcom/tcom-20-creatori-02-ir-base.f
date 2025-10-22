;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IR code base definitions
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; intermediate code, dynamically allocated


module IR
\ <disable-hash>

;; honestly free replaced/removed nodes?
;; there is no reason in doing it, because the OS will release
;; all the memory on app termination, and UrF/X will never use
;; even 1MB of RAM anyway. but why not?
;; freeing memory doesn't have any noticeable effect on run times anyway,
;; so let's be polite. ;-)
true constant IR-REALLY-FREE-NODES?

module IR-SPECIALS
<disable-hash>
end-module

vect generate-code  ( spfa )
vect cgen-flush  ( -- )

;; label types
bit-enum{
  def: lbl-forward  -- forward jump destination
  def: lbl-backward -- backward jump destination
}

;; node flags
bit-enum{
  def: nflag-appended   -- is node appended to the list?
  def: nflag-label-used -- temp flag for optimiser
  def: nflag-quan       -- for walits
  def: nflag-vect       -- for walits
  def: nflag-TOS-DE     -- is TOS in DE at the beginning? (used for debug dumps)
  def: nflag-do-inline  -- force-inline this node
  def: nflag-i-used     -- set for DO/FOR loops if the code used "I" or "I'"
  ;; for disasm
  def: nflag-bstr-compiled
  ;; for dead code removal
  def: nflag-node-used  -- this node is reachable
}

(*
note that `lbl-use-head` and `ulist-next` are not fixed by the cloning operation.
they are ment to be used on the final codegen stage, and have no meaning otherwise.
*)
struct:new node
  field: flags      -- see `nflag-XXX` constants
  field: prev       -- previous IR item or 0
  field: next       -- next IR item or 0
  field: spfa       -- shadow word PFA
  field: spfa-ref   -- record the reference to this word on tracing; used for `[']` and such
  field: zx-addr    -- starting address of the generated code in virtual ZX RAM
  field: zx-patch   -- used for branches, holds secondary patch address
  field: zx-patch2  -- used for branches, holds secondary patch address; 0: don't patch
  -- for literals
  field: value      -- 16-bit number, might be signed
  field: value2     -- 16-bit number, might be signed
  field: value3     -- 16-bit number, might be signed
  -- for branch nodes
  field: ir-dest    -- pointer to IR node, usually a label; fixed by the cloning
  field: ulist-next -- next item in label use list (head is pointed by `lbl-use-head`)
  -- for strlit nodes
  field: str$ -- dynalloced string
  -- for labels
  field: lbl-type       -- label type
  field: lbl-use-head   -- link to the first branch in list which used this node
  ;; temp field, used in various tasks
  ;; (in cloning, for example, to record the address of the cloned/old node)
  field: temp
  ;; used in FOR/DO loops to hold the address of the previous loop node.
  ;; used both in compilation mode, and in codegen phase.
  ;; fixed by the cloning.
  field: prev-loop
  ;; for disasm, set by the bstr codegen
  field: bstr-zx-addr
  field: bstr-zx-addr-end
  \ TODO: add more STC codegen fields here
  ;; current stack depth, will be used in STC codegen
  ;; <0: unknown
  field: sdepth
  field: rdepth
  \ TODO: add fields to track stack and register contents
end-struct
node:@size-of constant bytes/node
\ endcr ." nn: " bytes/node 0.r cr


@: node-set-flag  ( flag node^ )  node:flags:^ or! ;
@: node-reset-flag  ( flag node^ )  node:flags:^ ~and! ;

@: node-flag-and?  ( flag node^ ) node:flags and ;
@: node-flag?  ( flag node^ ) node:flags mask? ;

@: node-TOS-in-DE!  ( node^ )  nflag-TOS-DE swap node-set-flag ;
@: node-TOS-in-DE?  ( node^ -- bool )  nflag-TOS-DE swap node-flag? ;

@: node-TOS-in-HL!  ( node^ )  nflag-TOS-DE swap node-reset-flag ;
@: node-TOS-in-HL?  ( node^ -- bool )  nflag-TOS-DE swap node-flag-and? 0= ;


@: node-spfa-cf-flags  ( node^ -- flags )
  dup 0?exit
  node:spfa dup -0?exit< drop 0 >?
  shword:cg-flags ;

@: node-need-TOS-DE?  ( node^ -- bool )  cgf-need-TOS-DE swap node-spfa-cf-flags mask? ;
@: node-need-TOS-HL?  ( node^ -- bool )  cgf-need-TOS-HL swap node-spfa-cf-flags mask? ;

@: node-in-8bit?  ( node^ -- bool )  cgf-in-8bit swap node-spfa-cf-flags mask? ;

@: node-out-8bit?  ( node^ -- bool )  cgf-out-8bit swap node-spfa-cf-flags mask? ;
@: node-out-bool?  ( node^ -- bool )  cgf-out-bool swap node-spfa-cf-flags mask? ;

@: node-in-known?   ( node^ -- bool )  cgf-stack-in-known swap node-spfa-cf-flags mask? ;
@: node-out-known?  ( node^ -- bool )  cgf-stack-out-known swap node-spfa-cf-flags mask? ;

;; the following getters are undefined if the corresponding flags (see above) are not set
@: node-in-min   ( node^ -- value//-1 )  dup node-in-known? ?< node:spfa shword:in-min || drop -1 >? ;
@: node-in-max   ( node^ -- value//-1 )  dup node-in-known? ?< node:spfa shword:in-max || drop -1 >? ;
@: node-out-min  ( node^ -- value//-1 )  dup node-out-known? ?< node:spfa shword:out-min || drop -1 >? ;
@: node-out-max  ( node^ -- value//-1 )  dup node-out-known? ?< node:spfa shword:out-max || drop -1 >? ;

@: node-in-equal  ( n node^ -- bool )
  cgf-stack-in-known over node-spfa-cf-flags and 0?exit< 2drop false >?
  node:spfa dup shword:in-min swap shword:in-max
  ( n min max )
  over = not?exit< 2drop false >?
  = ;

@: node-out-equal  ( n node^ -- bool )
  cgf-stack-out-known over node-spfa-cf-flags and 0?exit< 2drop false >?
  node:spfa dup shword:out-min swap shword:out-max
  ( n min max )
  over = not?exit< 2drop false >?
  = ;


0 quan latest-special-cfa

|: (mk-ir-special)  ( doer-cfa addr name )
  rot vocid: ir-specials (mk-shadow-word) (published)
  dup latest-special-cfa:!  dart:cfa>pfa
  -666 over shword:zx-begin:!
  ['] noop swap shword:ir-compile:! ;

;; check spfa
: (mk-ir-special-checker)  ( doer-cfa addr name )
  system:mk-builds ,
  does> ( shadow-pfa our-pfa )
    @ swap dup not?exit< 2drop false >?
    ( doer-cfa shadow-pfa )
    shword:self-cfa
    dup system:does? not?exit< 2drop false >?
    system:doer@ = ;

;; usage:
;;  :noname .... ; mk-ir-special: ir-walit
;; creates:
;;   (ir-walit) shadow word
;;   ir-walit? checker
: mk-ir-special:  ( doer-cfa )  \ name
  parse-name
  " (" pad$:! pad$:+ [char] ? pad$:c+
  dup pad$:@ string:/char (mk-ir-special-checker)
  [char] ) pad$:last-c!
  pad$:@ (mk-ir-special) ;

: latest-ir-special-set-flag ( flag )
  latest-special-cfa dart:cfa>pfa shword:tk-flags:^ or! ;

;; usage:
;;  :noname .... ; ->special-compiler: ir-walit
: ->special-compiler:  ( compiler-cfa )  \ special-name
  parse-name
  " (" pad$:! pad$:+ " )" pad$:+
  pad$:@ vocid: ir-specials find-in-vocid not?exit<
    "  -- no such special!" pad$:+ pad$:@ error >?
  dart:cfa>pfa dup shword:zx-begin -666 = not?exit<
    "  -- not an IR special!" pad$:+ pad$:@ error >?
  shword:ir-compile:! ;

: ->special-optimiser:  ( optimiser-cfa )  \ special-name
  parse-name
  " (" pad$:! pad$:+ " )" pad$:+
  pad$:@ vocid: ir-specials find-in-vocid not?exit<
    "  -- no such special!" pad$:+ pad$:@ error >?
  dart:cfa>pfa dup shword:zx-begin -666 = not?exit<
    "  -- not an IR special!" pad$:+ pad$:@ error >?
  shword:ir-analyze:! ;

: ->special-fixup:  ( fixup-cfa )  \ special-name
  parse-name
  " (" pad$:! pad$:+ " )" pad$:+
  pad$:@ vocid: ir-specials find-in-vocid not?exit<
    "  -- no such special!" pad$:+ pad$:@ error >?
  dart:cfa>pfa dup shword:zx-begin -666 = not?exit<
    "  -- not an IR special!" pad$:+ pad$:@ error >?
  shword:ir-branchfix:! ;

;; ir-nothing
;; does nothing; dummy node used in optimiser
:noname ( pfa )  drop ; mk-ir-special: ir-nothing


;; this is used in trackers.
;; pull one stack item to the register.
;; you can use register hints here.
:noname ( pfa )  drop ; mk-ir-special: ir-pull-one

;; this is used in trackers.
;; spill one stack slot from the register.
:noname ( pfa )  drop ; mk-ir-special: ir-spill-one

;; this is used in trackers.
;; spill all stack slots from the registers, leaving TOS in HL.
:noname ( pfa )  drop ; mk-ir-special: ir-spill-all


;; ir-restore-tos
;; branches/loop starts will restore TOS on their own, but we
;; still need to insert this before labels.
:noname ( pfa )  drop ; mk-ir-special: ir-restore-tos

;; ir-label
;; branch destinatin label
:noname ( pfa )  drop ; mk-ir-special: ir-label


;; ir-noexit-entry
;; entry to the non-recursive Forth word which will never return
:noname ( pfa )  drop ; mk-ir-special: ir-noexit-entry

;; ir-noexit-exit
;; exit from the non-recursive Forth word which will never return; always the last
:noname ( pfa )  drop ; mk-ir-special: ir-noexit-exit

;; ir-nonrec-entry
;; entry to the non-recursive Forth word; always the first
:noname ( pfa )  drop ; mk-ir-special: ir-nonrec-entry

;; ir-nonrec-exit
;; exit from the non-recursive Forth word; always the last
:noname ( pfa )  drop ; mk-ir-special: ir-nonrec-exit

;; ir-rec-entry
;; entry to the non-recursive Forth word; always the first
:noname ( pfa )  drop ; mk-ir-special: ir-rec-entry

;; ir-rec-exit
;; exit from the recursive Forth word; always the last
:noname ( pfa )  drop ; mk-ir-special: ir-rec-exit

(*
;; ir-nonrec-tcall
;; tail call from the non-recursive Forth word
:noname ( pfa )  drop ; mk-ir-special: ir-nonrec-tcall

;; ir-rec-tcall
;; tail call from the recursive Forth word
:noname ( pfa )  drop ; mk-ir-special: ir-rec-tcall
*)

;; `nflag-quan`/`ir:nflag-vect` is set for quans and vects.
;; the actual quan/vect address is in `spfa-ref`.

;; ir-walit
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit

;; ir-walit:@
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:@

;; ir-walit:c@
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:c@

;; ir-walit:1c@
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:1c@

;; ir-walit:@execute
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:@execute

;; ir-walit:exec-vect
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:exec-vect

;; ir-walit:!0
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:!0

;; ir-walit:c!0
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:c!0

;; ir-walit:!1
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:!1

;; ir-walit:c!1
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:c!1

;; ir-walit:!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:!

;; ir-walit:c!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:c!

;; ir-walit:1c!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:1c!

;; ir-walit:+!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:+!

;; ir-walit:+c!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:+c!

;; ir-walit:-!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:-!

;; ir-walit:-c!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:-c!

;; ir-walit:1+!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:1+!

;; ir-walit:1+c!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:1+c!

;; ir-walit:1-!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:1-!

;; ir-walit:1-c!
;; word address literal
:noname ( pfa )  drop ; mk-ir-special: ir-walit:1-c!


;; ir-recurse
;; recursive call to the current word
:noname ( pfa )  drop ; mk-ir-special: ir-recurse

;; ir-tail-call
;; compile tail call
:noname ( pfa )  drop ; mk-ir-special: ir-tail-call
tkf-no-return latest-ir-special-set-flag


;; ir-fp-start
;; start ROM FP code
:noname ( pfa )  drop ; mk-ir-special: ir-fp-start

;; ir-fp-end
;; end ROM FP code
:noname ( pfa )  drop ; mk-ir-special: ir-fp-end

;; ir-fp-opcode
;; ROM calc opcode; should be inside fp-start/fp-end
:noname ( pfa )  drop ; mk-ir-special: ir-fp-opcode


;; ir-loop-i
:noname ( pfa )  drop ; mk-ir-special: ir-loop-i

;; ir-loop-irev
:noname ( pfa )  drop ; mk-ir-special: ir-loop-irev

;; ir-loop-i'
:noname ( pfa )  drop ; mk-ir-special: ir-loop-i'

;; ir-unloop
:noname ( pfa )  drop ; mk-ir-special: ir-unloop


: node-scfa?  ( scfa node^ -- flag )
  dup not?exit< 2drop false >?
  node:spfa swap dart:cfa>pfa = ;

: node-spfa?  ( spfa node^ -- flag )
  dup not?exit< 2drop false >?
  node:spfa = ;


;; current IR list
<published-words>
0 quan head
0 quan tail

;; label word, not in ZX kernel
<public-words>

@: tail-set-flag  ( flag )  tail node-set-flag ;
@: tail-reset-flag  ( flag )  tail node-reset-flag ;


|: (dump-spfa-name)  ( spfa )
  shword:self-cfa dart:cfa>nfa debug:.id ;

;; dump current IR
@: (dump-ir)  ( head^ )
  endcr
  << dup ?^|
    dup node:spfa (dump-spfa-name)
    dup node:spfa-ref ?< ."  ref: " dup node:spfa-ref (dump-spfa-name) >?
    ."  value: " dup node:value 0.r
    cr
  node:next |?
  else| drop >> ;

@: dump-ir
  head (dump-ir) ;


;; reset IR variables, prepare for new IR
@: reset
  head:!0 tail:!0 ;

|: (new-node)  ( size -- node^ )
  dup node:@size-of >= not?error" IR: node size too small"
  dynmem:?zalloc ;

@: new-node  ( -- node^ )
  bytes/node (new-node) ;

@: free-node  ( node^ )
  [ IR-REALLY-FREE-NODES? ] [IF]
  dup ?<
    dup node:str$ string:$free
    dup dynmem:free
  >?
  [ENDIF]
  drop ;

@: new-spfa-node  ( spfa -- node^ )
  dup -0?error" invalid SPFA in \'new-spfa-node\'!"
  new-node tuck node:spfa:! ;


|: (null?)  ( node^ -- flag )
  0= ;

|: (inserted?)  ( node^ -- flag )
  node:flags nflag-appended mask? ;

|: mark-inserted  ( node^ )
  node:flags:^ nflag-appended swap or! ;

|: mark-uninserted  ( node^ )
  node:flags:^ nflag-appended swap ~and! ;


@: ?tail  ( -- node^ )
  tail dup (null?) ?error" IR: empty IR list (wtf?!)" ;

@: append  ( node^ )
  dup (null?) ?error" IR: trying to append null node"
  dup (inserted?) ?error" IR: trying to append already appended node"
  \ dup node:prev over node:next or ?error" IR: trying to append already appended node"
  head 0?< dup head:! || dup tail node:next:! >?
  tail over node:prev:!
  dup tail:!
  mark-inserted
  [ 0 ] [IF]
    endcr ." NODE: " tail node:spfa shword:self-cfa dart:cfa>nfa debug:.id cr
  [ENDIF] ;

@: prepend  ( node^ )
  dup (null?) ?error" IR: trying to prepend null node"
  dup (inserted?) ?error" IR: trying to prepend already appended node"
  \ dup node:prev over node:next or ?error" IR: trying to append already appended node"
  tail 0?< dup tail:! || dup head node:prev:! >?
  head over node:next:!
  dup head:!
  mark-inserted ;

;; WARNING! node will not be freed!
@: remove  ( node^ )
  dup (null?) ?error" IR: trying to remove null node"
  dup (inserted?) not?error" IR: trying to remove already removed node"
  dup node:prev dup ?< ( node^ prev^ ) over node:next swap node:next:!
                    || ( node^ prev^ ) drop dup node:next head:! >?
  dup node:next dup ?< ( node^ next^ ) over node:prev swap node:prev:!
                    || ( node^ next^ ) drop dup node:prev tail:! >?
  dup node:prev:!0 dup node:next:!0
  mark-uninserted ;

;; if `befnode^` is 0, prepend to the list head
@: insert-before  ( befnode^ newnode^ )
  dup (null?) ?error" IR: trying to insert null node"
  dup (inserted?) ?error" IR: trying to insert already inserted node"
  over 0?exit< nip prepend >?
  swap dup (inserted?) not?error" IR: trying to insert before not inserted node"
  ;; first node?
  dup node:prev 0?exit< drop prepend >?
  ;; insert
  >r  ( node^ | befnode^ )
  r@ node:prev over node:prev:! ;; fix `node^.prev`
  r@ over node:next:!           ;; fix `node^.next`
  dup r@ node:prev node:next:!  ;; fix `befnode^.prev.next`
  dup r> node:prev:!            ;; fix `befnode^.prev`
  mark-inserted ;

;; if `afternode^` is 0, append to the list tail
@: insert-after  ( afternode^ newnode^ )
  dup (null?) ?error" IR: trying to insert null node"
  dup (inserted?) ?error" IR: trying to insert already inserted node"
  over 0?exit< nip append >?
  swap dup (inserted?) not?error" IR: trying to insert before not inserted node"
  ;; get next node, and insert before it
  node:next dup 0?exit< drop append >?
  swap insert-before ;


@: new-special  ( special-cfa -- node^ )
  dart:cfa>pfa
  new-node 2dup node:spfa:!
  ;; just in case, disable TCO optimisation for specials
  swap shword:tk-flags:^ tkf-no-tco swap or! ;

@: append-special  ( special-cfa )
  new-special append ;

@: prepend-special  ( special-cfa )
  new-special prepend ;


@: new-zxword  ( scfa -- node^ )
  dart:cfa>pfa
  new-node tuck node:spfa:! ;

@: append-zxword  ( scfa )
  new-zxword append ;

@: prepend-zxword  ( scfa )
  new-zxword prepend ;


@: mk-label-and-append  ( type -- ir-label^ )
  new-node
  ['] ir-specials:(ir-label) dart:cfa>pfa over node:spfa:!
  2dup node:lbl-type:!
  nip dup append ;


@: append-restore-tos
  ['] ir-specials:(ir-restore-tos) append-special ;


end-module IR
end-module TCOM
