;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; global definitions; should be manually loaded
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module Succubus
<published-words>

;; codegen can be shared between Uroborus and Beast, so
;; let's vectorise all required code file access operations.
;; actually, vectors are slower than direct calls, and cannot
;; be optimised. we don't need to switch the Succubus to another
;; set of words on the fly, so we can simply define the corresponding
;; words before compiling Succubus herself. this way the calls will
;; be properly inlined and optimised.
(*
vect code-db,
vect code-dw,
vect code-dd,

vect code-here
vect code-unallot
vect code-@
vect code-w@
vect code-c@
vect code-!
vect code-w!
vect code-c!

;; this is called *AFTER* stacks are swapped to be correct,
;; but before basic block pointer is adjusted.
;; i.e. current basic block is from "BBLOCK-START^" to "CODE-HERE".
vect-empty (finish-bblock)
*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[HAS-WORD] debug-disable-inliner-peepopt [IFNOT]
false constant debug-disable-inliner-peepopt
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; various flags and vars

;; maximum allowed inlineable bytes.
;; used in analyzer.
\ 69 quan #inline-bytes
\ vect #inline-bytes

;; this flag is set by the compiler if it compiled any inline blocker.
0 quan can-inline?
;; this flag is set by the compiler if it compiled any rets (except the last one).
false quan has-rets?
;; this is set when we compiled any backward branch. used later to
;; align inlined word (to keep loops aligned). there is no need to
;; align words w/o backward jumps, there are no loops there.
false quan has-back-jumps?
;; had we aligned any loops?
false quan did-any-align?

;; start address of the current basic block
0 quan bblock-start^

;; negative: normal colon
;; positive: anonymous colon (code after "DOES>")
-1 constant named-colon
 1 constant doer-colon  -- code after "DOES>"
0 quan colon-type


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some statistics

0 quan stat-words-inlineable
0 quan stat-words-inlined
0 quan stat-bytes-inlined
0 quan stat-instructions-inlined
0 quan stat-direct-optim
0 quan stat-tail-optim
0 quan stat-stitch-optim
0 quan stat-useless-sswaps

;; how many branches were optimised to not use proper bools?
0 quan stat-logbranch-optimised
;; how many logbranch optimisations vere bloked by "dup brn"?
0 quan stat-logbranch-blocked
;; how many literal comparisons were replaced in branches?
0 quan stat-logbranch-litcmp
;; how many push/pop of TOS were removed in branches?
0 quan stat-logbranch-push-pop-tos


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; branch types for mark/resolve
;; WARNING! this is used as table index later in code, so don't change!

;; low bit must be reset!
668 enum-from{
  def: (XXX-MIN-BRANCH) (private)
  1 -set  ;; roll back

  ;; branches are arranged in this order so flipping the last
  ;; will invert branch condition. wow, i'm so smart!

  def: (BRANCH)
  def: (BRANCH-BRANCH)  -- this is the same as "(BRANCH)", and used for branch inversion

  def: (0BRANCH)  ( flag )
  def: (TBRANCH)  ( flag )

  def: (+0BRANCH)  ( flag )
  def: (-BRANCH)  ( flag )

  def: (+BRANCH)  ( flag )
  def: (-0BRANCH)  ( flag )

  ;; ( 0 ) -- jmp
  ;; ( n !0 ) -- no jmp
  def: (CASE-0BRANCH)
  ;; ( !0 ) -- jmp
  ;; ( n 0 ) -- no jmp
  def: (CASE-TBRANCH)

  ;; val<>n: ( val n -- val ) branch
  ;; val=n:  ( val n ) no branch
  def: (OF<>BRANCH)
  ;; two "inverted" of-branches
  ;; val<>n:  ( val n ) branch
  ;; val=n: ( val n -- val ) no branch
  def: (OF=BRANCH-INV)

  ;; val=n:  ( val n ) branch
  ;; val<>n: ( val n -- val ) no branch
  def: (OF=BRANCH)
  ;; val=n:  ( val n -- val ) branch
  ;; val<>n: ( val n ) no branch
  def: (OF<>BRANCH-INV)

  ;; special branches, used in DO/FOR
  def: (ZFLAG-SET-BRANCH)
  def: (ZFLAG-RESET-BRANCH)
  def: (CFLAG-SET-BRANCH)
  def: (CFLAG-RESET-BRANCH)
  def: (OVERFLOW-FLAG-BRANCH)
  def: (NO-OVERFLOW-FLAG-BRANCH)

  def: (LE-FLAG-BRANCH)
  def: (G-FLAG-BRANCH)

  def: (XXX-BRANCH-MAX) (private)
}


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; special word kind
;; WARNING! this is used as table index later in code, so don't change!

-669 enum-from{
  def: (XXX-MIN-SPW) (private)
  1 -set  ;; roll back

  def: spw-constant
  def: spw-variable
  def: spw-does
  def: spw-uservalue
  def: spw-uservar

  def: spw-exit
  def: spw-?exit
  def: spw-not?exit
  def: spw-?exit&leave
  def: spw-not?exit&leave

  def: (XXX-SPW-MAX)
}


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; codegen options

false quan disable-aggressive-inliner
;; if "FALSE", colon words will be marked as non-inlineable with "can-inline?:!f"
 true quan allow-forth-inlining-analysis


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; external vectored API
;; see the comment about vectors at the top of this file

(*
;; start writing optinfo
vect optinfo-start  ( -- )
;; compile optinfo data
vect optinfo-db,  ( byte -- )
vect optinfo-dw,  ( word -- )
;; finish writing optinfo
vect optinfo-finish  ( -- )
*)

(*
;; get variable address to be compiled
vect var-addr  ( cfa-xt -- addr )
;; get constant value to be compiled
vect const-value  ( cfa-xt -- value )
;; get uservar offset to be compiled
vect uvar-offset  ( cfa-xt -- offset )

vect cfa-ffa@     ( cfa-xt -- [ffa] )
vect cfa>optinfo  ( cfa-xt -- optinfo^ )
;; this is used by the inliner
vect cfa-wlen@    ( cfa-xt -- word-code-length-in-bytes )

vect ss-latest-cfa  ( -- cfa-xt )

;; this is called to get handler for "special word".
;; returned CFA is executed. it doesn't take args.
;; you can get CFA of the compiling word from "CURRENT-CFA".
;; "CURRENT-[FFA]" is valid too.
vect get-special-handler  ( -- exec-cfa-xt // FALSE )

;; called when finished compiling words, but before string patching.
;; should set current word length.
vect set-last-word-length  ( -- )

;; check various word flags: ( -- bool-flag )
vect immediate-word?
vect noreturn-word?
vect inline-blocker-word?
vect inline-allowed-word?
vect inline-force-word?
vect no-stacks-word?
vect has-back-jumps-word?
vect word-has-back-jumps

;; called if analyzer detected that the word cannot be inlined
vect not-inlineable-word
;; called if analyzer decided that the compiled word is inlineable
vect inlineable-word
*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; debug hooks

(*
;; called when the compiler wants to inline the word
vect-empty debug-inline-started
vect-empty debug-inline-finished

;; called when inliner failed to inline word marked as inlineable
vect-empty debug-inliner-failed

vect-empty debug-.latest-name
vect-empty debug-.current-cfa-name

vect-empty debug-colon-started
vect-empty debug-colon-finished

vect-empty debug-code-started
vect-empty debug-code-finished
*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; various flags and vars

;; CFA of the currently compiling word.
;; set by "CC\,".
0 quan current-cfa

;; contents of the FFA of the currently compiling word.
;; set by "CC\,".
0 quan current-[ffa]

;; to know word length
0 quan code-start^


end-module Succubus
