;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dictionary and article header creation
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$include "tcom-20-creatori-10-base.f"


extend-module TCOM


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; shadow word struct (in shadow word PFA)

bit-enum{
  def: tkf-used
  def: tkf-traced
  def: tkf-no-tco         -- TCO calls are not allowed for this word
  ;; for STC
  def: tkf-allow-recurse  -- this word might be called recursive (need to properly modify rstack)
                          -- will be automatically set for words with "RECURSE"
  def: tkf-allow-inline   -- this *Forth* word should be inlined
  def: tkf-no-return      -- this word never returns
  def: tkf-primitive      -- this is primitive without a body
  def: tkf-no-optim       -- debug flag: disable IR optimiser (but not peephole)
  ;; helper for pattern database processor
  def: tkf-branch-like
}

bit-enum{
  def: cgf-stack-in-known
  def: cgf-stack-out-known
  ;; requirements, checked by the codegen to generate better code.
  ;; the following two flags are mutually exclusive.
  def: cgf-need-TOS-DE
  def: cgf-need-TOS-HL    -- set for all non-primitive words
  ;; this word uses only 8-bit inputs
  def: cgf-in-8bit
  ;; this word produces only boolean values
  ;; this has the priority over "out-8bit", but DOES require it to be set
  def: cgf-out-bool
  ;; this word produces only 8-bit values; high byte is always 0
  def: cgf-out-8bit
  \ TODO (maybe)
  ;; this word has 8-bit out, and it can propagate it up the IR list.
  ;; that is, if the word is marked with "out-8bit", it can propagate it to its input.
  ;; i.e. AND8 expects 8-bit input. it then marks the previous word as "8-bit output".
  ;; and that previous word could be marked as "in-8bit" if this flag is set.
  \ def: cgf-propagate-8bit-up
}

;; WARNING! keep in sync with `(mk-shadow-word)`!
struct:new shword
  field: zx-begin       -- ZX start address; also, the address to call the word
                        -- -1: forward; -2: not used (turnkey pass 2 only)
                        -- -666: primitive
  field: zx-end         -- ZX end address (first byte after the word; only for code and colon words)
  field: fwdfix-chain   -- fixup chain for forwards
  field: ref-list       -- words, see "creatori-18-refs.f"
  field: def-labels     -- list of defined asm labels in this word
  field: ref-labels     -- list of referenced asm labels in this word
  field: self-cfa       -- to get from PFA to CFA (shadow, not ZX!)
  field: tk-flags       -- turnkey flags
  field: cg-flags       -- codegen flags
  field: zx-alias-scfa  -- to trace aliases
  field: prev-scfa      -- previous defined shadow word
  -- TODO: IR compiler
  field: ir-code        -- for Forth words; pointer to IR list
  field: ir-code-clone  -- for Forth words; used for inlining; IR nodes *BEFORE* the optimisation!
  field: ir-analyze     -- CFA, ready to execute; can be 0; called by the optimiser; use "ir:curr-node" to get the node
  field: ir-compile     -- CFA, ready to execute; can be 0; called by the ZX codegen; use "ir:curr-node" to get the node
  field: ir-branchfix   -- CFA//0; called after codegen is complete, to fix branch addresses; use "ir:curr-node" to get the node
  field: ir-brlabel     -- CFA//0; get branch label; may return 0; use "ir:curr-node" to get the node
  field: ir-brlabel!    -- CFA//0; set branch label; ( ir-dest ); use "ir:curr-node" to get the node
  field: ir-clone       -- CFA//0; clone node ( -- newnode^ ); use "ir:curr-node" to get the node
  field: ir-post-clone  -- CFA//0; clone node; use "ir:curr-node" to get the node
  \ field: ir-do-stack    -- CFA//0; used in stack tracer; use "ir:curr-node" to get the node
  field: ir-patdb       -- pattern database for this word (can be 0)
  union{
    ;; for constants
    field: const-value
    ;; for FP commands
    field: calc-opcode
  }
  -- TODO: add STC codegen fields here
  ;; number of input stack args (valid if `cgf-stack-in-known` flag is set)
  field: in-min
  field: in-max
  ;; number of output stack args (valid if `cgf-stack-out-known` flag is set)
  field: out-min
  field: out-max
end-struct


: spfa-tk-flag?  ( mask spfa -- and-result )  shword:tk-flags and ;
: spfa-tk-flag+  ( mask spfa )  shword:tk-flags:^ or! ;
: spfa-tk-flag-  ( mask spfa )  shword:tk-flags:^ dup @ rot ~and swap ! ;

: spfa-cg-flag?  ( mask spfa -- and-result )  shword:cg-flags and ;
: spfa-cg-flag+  ( mask spfa )  shword:cg-flags:^ or! ;
: spfa-cg-flag-  ( mask spfa )  shword:cg-flags:^ dup @ rot ~and swap ! ;

: spfa-cg-want-TOS-HL?  ( spfa -- bool )  cgf-need-TOS-HL swap spfa-cg-flag? 0<> ;
: spfa-cg-want-TOS-DE?  ( spfa -- bool )  cgf-need-TOS-DE swap spfa-cg-flag? 0<> ;
: spfa-cg-want-TOS?     ( spfa -- bool )  cgf-need-TOS-HL cgf-need-TOS-DE or swap spfa-cg-flag? 0<> ;


vect (mk-shadow-word-done)  ( scfa )

:noname  ( scfa )
  \ endcr ." SWW: " dup dart:cfa>nfa debug:.id cr
  drop
; (mk-shadow-word-done):!

;; no checks, no linking into any list
: (mk-shadow-word)  ( addr count tc-doer vocid -- latest-cfa )
  swap >r
  push-cur current! system:mk-builds
  ;; init struct
  system:latest-pfa >r
  here  shword:@size-of allot  here over - erase
  -1 r@ shword:zx-begin:!
  -1 r@ shword:zx-end:!
  system:latest-cfa r@ shword:self-cfa:!
  -1 r@ shword:in-min:!
  -1 r@ shword:out-min:!
  rdrop
  system:latest-cfa dup pop-cur r> system:!doer
  dup (mk-shadow-word-done) ;

module Succubus
end-module Succubus

end-module TCOM


$include "tcom-20-creatori-02-ir-base.f"
$include "tcom-20-creatori-04-ir-stacker.f"

extend-module TCOM
extend-module Succubus

module setters
;; for the last word
: analyzer    ( cfa )  curr-word-spfa shword:ir-analyze:! ;
: compiler    ( cfa )  curr-word-spfa shword:ir-compile:! ;
: brfixer     ( cfa )  curr-word-spfa shword:ir-branchfix:! ;
: brlabel     ( cfa )  curr-word-spfa shword:ir-brlabel:! ;
: brlabel!    ( cfa )  curr-word-spfa shword:ir-brlabel!:! ;
: clone       ( cfa )  curr-word-spfa shword:ir-clone:! ;
: post-clone  ( cfa )  curr-word-spfa shword:ir-post-clone:! ;
\ : do-stack    ( cfa )  curr-word-spfa shword:ir-do-stack:! ;

(*
bit-enum{
  def: A
  def: F
  def: B
  def: C
  def: D
  def: E
  def: H
  def: L
  def: A'
  def: F'
  def: B'
  def: C'
  def: D'
  def: E'
  def: H'
  def: L'
  def: IXL
  def: IXH
  def: IYL
  def: IYH
}

A F + constant AF
H L + constant HL
D E + constant DE
B C + constant BC

A' F' + constant AF'
H' L' + constant HL'
D' E' + constant DE'
B' C' + constant BC'

IXL IXH + constant IX
IYL IYH + constant IY

: used-reg  ( reg )  drop ;
: no-used-regs  ;

: used-A  A used-reg ; : used-F  F used-reg ;
: used-B  B used-reg ; : used-C  C used-reg ;
: used-D  D used-reg ; : used-E  E used-reg ;
: used-H  H used-reg ; : used-L  L used-reg ;

: used-A'  A' used-reg ; : used-F'  F' used-reg ;
: used-B'  B' used-reg ; : used-C'  C' used-reg ;
: used-D'  D' used-reg ; : used-E'  E' used-reg ;
: used-H'  H' used-reg ; : used-L'  L' used-reg ;

: used-IXL  IXL used-reg ; : used-IXH  IXH used-reg ;
: used-IYL  IYL used-reg ; : used-IYH  IYH used-reg ;

: used-AF  AF used-reg ;
: used-BC  BC used-reg ;
: used-DE  DE used-reg ;
: used-HL  HL used-reg ;

: used-AF'  AF' used-reg ;
: used-BC'  BC' used-reg ;
: used-DE'  DE' used-reg ;
: used-HL'  HL' used-reg ;

: used-EXX  used-BC' used-DE' used-HL' ;
*)

(*
enum{
  def: ZFLAG-OK
  def: ZFLAG-SET
  def: ZFLAG-RESET
  def: CFLAG-SET
  def: CFLAG-RESET
  def: CFLAG-SUB8
  def: CFLAG-ADD8
  def: CFLAG-SUB16
  def: CFLAG-ADD16
}

: flag  ( flag )  drop ;
: no-flags-changed  ;

: flag-z-ok  ZFLAG-OK flag ;
: flag-z-set  ZFLAG-SET flag ;
: flag-z-reset  ZFLAG-RESET flag ;

: flag-c-set  CFLAG-SET flag ;
: flag-c-reset  CFLAG-RESET flag ;

: flag-c-add8  CFLAG-ADD8 flag ;
: flag-c-add16  CFLAG-ADD16 flag ;
: flag-c-sub8  CFLAG-SUB8 flag ;
: flag-c-sub16  CFLAG-SUB16 flag ;
*)


|: (cw-cg-flag-)  ( mask ) curr-word-spfa spfa-cg-flag- ;
|: (cw-cg-flag+)  ( mask ) curr-word-spfa spfa-cg-flag+ ;
|: (cw-cg-flag?)  ( mask ) curr-word-spfa spfa-cg-flag? ;

|: (cw-set-stack-in)  ( nmin nmax )
  cgf-stack-in-known (cw-cg-flag+)
  curr-word-spfa shword:in-max:!
  curr-word-spfa shword:in-min:! ;

|: (cw-set-stack-out)  ( nmin nmax )
  cgf-stack-out-known (cw-cg-flag+)
  curr-word-spfa shword:out-max:!
  curr-word-spfa shword:out-min:! ;

: in-args-force  ( n )  dup (cw-set-stack-in) ;
: out-args-force  ( n )  dup (cw-set-stack-out) ;

: in-args  ( n )
  cgf-stack-in-known (cw-cg-flag?) ?exit<
    dup curr-word-spfa shword:in-min = not?error" in: incompatible with stack comment"
    dup curr-word-spfa shword:in-max = not?error" in: incompatible with stack comment"
    drop
  >?
  dup (cw-set-stack-in) ;

: out-args  ( n )
  cgf-stack-out-known (cw-cg-flag?) ?exit<
    dup curr-word-spfa shword:out-min = not?error" out: incompatible with stack comment"
    dup curr-word-spfa shword:out-max = not?error" out: incompatible with stack comment"
    drop
  >?
  dup (cw-set-stack-out) ;

: in-out-args  ( in out )  out-args in-args ;

: in-rargs  ( in out )  drop ;
: out-rargs  ( in out )  drop ;
: in-out-rargs  ( in out )  2drop ;

: unknown-in-args  cgf-stack-in-known (cw-cg-flag-) ;
: unknown-out-args cgf-stack-out-known (cw-cg-flag-)  ;
: unknown-in-out-args  unknown-in-args unknown-out-args ;

: unknown-in-rargs  ;
: unknown-out-rargs  ;
: unknown-in-out-rargs  ;

: need-TOS-HL
  cgf-need-TOS-DE (cw-cg-flag-)
  cgf-need-TOS-HL (cw-cg-flag+) ;

: need-TOS-DE
  cgf-need-TOS-HL (cw-cg-flag-)
  cgf-need-TOS-DE (cw-cg-flag+) ;

: in-8bit
  cgf-in-8bit (cw-cg-flag+) ;

: out-8bit
  cgf-out-bool (cw-cg-flag-)
  cgf-out-8bit (cw-cg-flag+) ;

: out-16bit
  cgf-out-bool cgf-out-8bit or (cw-cg-flag-) ;

: out-bool
  cgf-out-8bit (cw-cg-flag+)
  cgf-out-bool (cw-cg-flag+) ;


end-module setters
end-module Succubus
end-module TCOM

;; keep loading
$include "tcom-20-creatori-12-base.f"
$include "tcom-20-creatori-16-fixups.f"
$include "tcom-20-creatori-18-refs.f"
$include "tcom-20-creatori-20-mk-shadow.f"
$include "tcom-20-creatori-22-mk-zx.f"
$include "tcom-20-creatori-26-zx-forwards.f"
$include "tcom-20-creatori-30-shadow-helpers.f"
$include "tcom-20-creatori-32-zxf-code-helpers.f"
$include "tcom-20-creatori-34-zxf-semi-helpers.f"
$include "tcom-20-creatori-36-mk-zx-code-colon.f"
$include "tcom-20-creatori-38-mk-zx-other.f"
$include "tcom-20-creatori-40-zx-mode.f"
$include "tcom-20-creatori-50-refproc.f"
$include "tcom-20-creatori-60-ir-utils.f"
$include "tcom-20-creatori-64-patdb.f"
$include "tcom-20-creatori-68-peep-patterns.f"
$include "tcom-20-creatori-70-ir-opt.f"
$include "tcom-20-creatori-72-rules.f"
$include "tcom-20-creatori-76-special-rules.f"
$include "tcom-20-creatori-80-ir-cgen.f"


extend-module TCOM
extend-module Succubus
extend-module setters

: analyzer:   ir:-find-cgen-worker analyzer ;
: compiler:   ir:-find-cgen-worker compiler ;
: brfixer:    ir:-find-cgen-worker brfixer ;
: brlabel:    ir:-find-cgen-worker brlabel ;
: brlabel!:   ir:-find-cgen-worker brlabel! ;
: clone:      ir:-find-cgen-worker clone ;
: post-clone: ir:-find-cgen-worker post-clone ;

: optimiser:  ir:-find-opt-worker analyzer ;
\ : do-stack:   ir:-find-stacker-worker do-stack ;

: setup-branch
  " (branch-brfix)" ir:(find-cgen-worker) brfixer
  " (branch-brlabel)" ir:(find-cgen-worker) brlabel
  " (branch-brlabel!)" ir:(find-cgen-worker) brlabel!
  \ " (branch-post-clone)" ir:(find-cgen-worker) post-clone
  tkf-branch-like curr-word-spfa shword:tk-flags:^ or! ;

end-module setters
end-module Succubus


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SHADOWS vocab methods (compile literals, create forwards)

|: zx-voc-literal  ( lit -- ... TRUE // lit FALSE )
  zx-comp? not?exit&leave
  system:?exec zx-#, true ;
['] zx-voc-literal vocid: forth-shadows system:vocid-literal-cfa!

;; automatically create forwards (Forth by default).
|: zx-voc-notfound  ( addr count -- processed-flag )
\ endcr ." ZX-NOTFOUND: |" 2dup type ." |\n"
  zx-comp? not?exit< 2drop false >?
  ss-mk-forth-forward dart:cfa>pfa ss-call,
  true ;
['] zx-voc-notfound vocid: forth-shadows system:vocid-notfound-cfa!


: zx-disasm-last
  endcr ." === DISASM ===\n"
  curr-word-spfa shword:zx-begin
  curr-word-spfa shword:zx-end
  z80dis:disasm-range ;


end-module
