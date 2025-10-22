;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; main compiler interface
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
optimiser info block format:
  dd optcfa   ;; will be used in the future abstract-code-level optimiser
  #ilen    ;; number of machine code instruction lengthes, varint
   ...machine code instructions, starting from CFA
  note that non-inlineable words don't need any length info, and this
  block is absent.

  #ilen is encoded like this:
    if bit 7 is not set, length is bits [0..6].
    otherwise, this is *HIGH* byte of length, and low byte follows.
*)


\ module Succubus
\ <disable-hash>
<published-words>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; record info for optimiser (instruction lengthes).
|: optinfo-count,  ( cnt )
  dup $80 < ?< optinfo-db, || dup hi-byte $80 or optinfo-db, lo-byte optinfo-db, >? ;

: optinfo-count@  ( code-addr -- info-code-addr counter )
  dup code-c@ 1 under+
  ( #ilen^+1 [#ilen] )
  dup $80 > ?< $7F and 256 * over code-c@ + 1 under+ >? ;


|: record-optinfo
  can-inline? not?exit
  ilendb:#total dup not?exit< drop >?
  dup 32767 u> ?error" this doesn't fit into Succubus"
\ endcr ." optinfo length: " dup 0.r, cr
  optinfo-start
  dup optinfo-count,
  0 << ( limit index )
       2dup > ?^| dup ilendb:nth-iw@ optinfo-dw,  1+ |?
       else| 2drop >>
  optinfo-finish ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; record last compiled "(#)" address for simple optimisers
\ 0 quan last(#)-start-va
\ 0 quan last(#)-end-va
\ 0 quan last(#)-value

false quan wdata-guard
false quan was-wdata?

|: (reset)
  \ last(#)-start-va:!0 last(#)-end-va:!0
  low:force-reset-swap-stacks
  wdata-guard:!f was-wdata?:!f
  bblock-start^:!0 high:brn-stack-restore?:!f
  high:exit-chain-sswap:!0 high:exit-chain:!0 ;

|: reset
  (reset)
  code-here bblock-start^:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; inliner (moved to the separate file)

: cc\,-noinline
  current-cfa high:call ;

$include "Succubus-60-inliner.f"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; analyzer

$include "Succubus-70-anal.f"

: ?in-latex
  colon-type not?error" Succubus forgot her latex"
  wdata-guard ?error" Succubus is out of house temporarily" ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compile numeric literals

0 quan (#)-load-addr
0 quan (#)-load-value

|: last-load-lit?  ( -- flag )
  ilendb:last-type@ ilendb:it-#-load <> ?exit< false >?
  code-here ilendb:last-len@ 2 =
  ?exit< 2- (#)-load-addr:! (#)-load-value:!0 true >?
  ilendb:last-len@ 5 - ?error" shitacrap!"
  5 - dup (#)-load-addr:! 1+ code-@ (#)-load-value:! true ;

|: replace-lit?  ( n -- n FALSE // TRUE )
  last-load-lit? not?exit&leave
  (#)-load-addr bblock-start^ u>= not?exit&leave
  low:remove-last-unsafe
  (#)-load-value low:push-value
  low:ebx low:load-reg32-value true ;

|: kill-pope?  ( -- skip-push-tos-flag )
  ilendb:last-type@ ilendb:it-pop-ebx = not?exit&leave
  low:can-remove-last? not?exit&leave
\ endcr ." OPT-LIT! kill pope at $" code-here 1- .hex8 cr
  low:remove-last-unsafe
  true ;

|: kill-lit-mov-ebx-eax  ( -- skip-push-tos-flag )
  ilendb:last-len@ 2 = not?exit
  code-here 2- code-w@ $D8_8B = not?exit
  low:can-remove-last? not?exit
  low:remove-last-unsafe ;

;; "pop eax / push ebx" -> "mov [esp], ebx"
(* this is longer, and not much faster
|: kill-lit-pop-eax-push-ebx
  ilendb:last-type@ ilendb:it-push-ebx = not?exit
  ilendb:prev-last-type@ ilendb:it-pop-eax = not?exit
  low:can-remove-last-2? not?exit
  low:remove-last-unsafe
  low:remove-last-unsafe
  0 low:mov-[esp+value],ebx ;
*)

: cc-#,  ( n )
  ?in-latex
  low:dstack>cpu
  ;; check if we have a literal load as previous command
  replace-lit? ?exit
  ;; "pop ebx / push ebx" -- this is "drop lit"
  ;; remove "pop ebx", do not generate "push ebx"
\ endcr ." LIT-00 at $" code-here .hex8 cr
  kill-pope? not?< high:push-tos-anyway >?
  \ low:stacks-swapped? not?error" Succubus wants it swapped"
\ endcr ." LIT-01 at $" code-here .hex8 cr
  kill-lit-mov-ebx-eax
\  kill-lit-pop-eax-push-ebx
\ endcr ." LIT-02 at $" code-here .hex8 cr
  low:ebx low:load-reg32-value ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compile string literals

;; compile string literal
|: (cc-str#,)  ( addr count unescape? )
  ?in-latex
  ;; address
  high:push-tos-kill
  ilendb:cg-begin
  \ 68 nn nn nn nn  push   # n
  $68 code-db, ?< cg-string-addr, || cg-raw-string-addr, >?
  ilendb:cg-end
  low:ebx low:load-reg32-value ;

;; compile string literal
: cc-str#,  ( addr count )  true (cc-str#,) ;
: cc-raw-str#,  ( addr count )  false (cc-str#,) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compile consts and vars

: cc-inline/noinline-common  ( -- )
  inline-blocker-word? ?< can-inline?:!f >?
  inline-force-word? ?exit< inliner:inline-cfa >?
  disable-aggressive-inliner ?exit< cc\,-noinline >?
  ;; do not inline immediate words (because i said so)
  immediate-word? ?exit< cc\,-noinline >?
  inline-allowed-word? not?exit< cc\,-noinline >?
  inliner:inline-cfa ;

: cc-inline/noinline-common-does  ( -- )
\ endcr ." **DOES TEST-INLINE CFA $" current-cfa .hex8 cr
\ current-cfa ss-doer@
\ endcr ."   DOER CFA $" .hex8 cr
\ current-cfa ss-cfa>pfa
\ endcr ."   WORD PFA $" .hex8 cr
  ;; Uroborus can create forwards like this
  current-cfa ss-doer@ not?exit< cc\,-noinline >?
  ;; compile PFA address
  current-cfa ss-cfa>pfa cc-#,
  ;; switch to doer
  current-cfa ss-doer@ dup current-cfa:! cfa-ffa@ current-[ffa]:!
  ;; compile doer
  cc-inline/noinline-common ;


: cc\,-constant  current-cfa const-value cc-#, ;
: cc\,-variable  current-cfa var-addr cc-#, ;

: cc\,-uservar
  high:push-tos-kill
  current-cfa uvar-offset low:lea-ebx-[uv-addr] ;

: cc\,-uservalue
  high:push-tos-kill
  current-cfa uvar-offset low:load-ebx-[uv-addr] ;

;; this compiles call to the word built with "<builds ... does>"
: cc\,-does
  cc-inline/noinline-common-does ;
  \ cc\,-noinline ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level compiler API

create spw-handlers
['] cc\,-constant ,
['] cc\,-variable ,
['] cc\,-does ,
['] cc\,-uservalue ,
['] cc\,-uservar ,

['] high:exit, ,
['] high:?exit, ,
['] high:not?exit, ,
['] high:?exit&leave, ,
['] high:not?exit&leave, ,
create;

;; compile threaded code call to the target image.
;; pass target CFA here.
;; WARNING! do not call "CC\," from any compile handler called from "CC\," itself!
: cc\,  ( cfa-xt )
\ endcr ." **COMPILE CFA $" dup .hex8 cr
\ debug:.s
  ?in-latex
  dup current-cfa:!
  cfa-ffa@ current-[ffa]:!
  get-special-handler dup ?exit<
\ endcr ." **COMPILE special " dup 0.r cr
\ debug:.s
    dup (xxx-min-spw) (xxx-spw-max) within
    not?error" Succubus refuses to perform intercourse with this disgusting thing"
    (xxx-min-spw) - spw-handlers dd-nth @execute-tail >?
  drop
\ endcr ." **COMPILE word " debug-.current-cfa-name cr
\ debug:.s
\ depth 1 < ?< abort >?
  cc-inline/noinline-common ;

;; compile word which expects some arbitrary inline data to be followed.
;; this allows to use return stack tricks.
: cc\,-wdata  ( cfa-xt )
  wdata-guard ?error" Succubus is already out of house"
  dup current-cfa:!
  cfa-ffa@ current-[ffa]:!
  get-special-handler ?error" Succubus cannot walk with this"
  can-inline?:!f
  low:restore-stacks
  current-cfa low:(call)
  (finish-bblock-hook)
  code-here bblock-start^:!
  wdata-guard:!t was-wdata?:!t ;

: cc-finish-wdata
  wdata-guard not?error" Succubus never left the house"
  wdata-guard:!f
  ilendb:restart
  code-here code-start^:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level control API

;; call this to notify the compiler that we reached a basic block boundary.
;; standard compiler handlers for branches do this automatically.
: end-basic-block
  low:finish-bblock ;

: cannot-inline
  can-inline?:!f
  not-inlineable-word ;

;; call this in "DOES>" and other things, when you are completely sure
;; that the last compiled word will never return. this flushes the
;; optimiser state, performs all scheduled optimisations and such.
;; i.e. you will start from a clean state after calling this.
;; note that calling this word will prevent inlining. this is intended.
: finish-word-part
  ?in-latex
  low:stacks-swapped? ?error" Succubus is hanging from the roof"
  code-here bblock-start^:!
  \ reset
  can-inline?:!f ;

|: (start-word-common)
  colon-type ?error" Succubus already dressed in latex"
\ endcr ." COMPILING COLON: " tgt-latest-nfa tcom:>real debug:.id cr
\ tgt-latest-nfa tcom:>real idcount " (QUIT)" string:= ?< cc-regman:xxabort:!t >?
  reset slc-reset
  high:reset
  allow-forth-inlining-analysis 0<> can-inline?:!
  named-colon colon-type:!
  ilendb:restart
  code-here code-start^:! ;

;; call when starting a colon definition (after creating all support
;; structures, i.e. when we a ready to compile the code).
;; let's geterate an explicit stack swap. this may help for words
;; like ": a 0= ..." (for all words with "no-stack" primitives).
;; and it doesn't harm, because if we start the word from "CALL" or
;; something, stack swap optimiser will remove this useless thing.
: start-colon
  (start-word-common)
  low:dstack>cpu
  debug-colon-started ;

;; call this to compile out-of-colon code with optimisations.
;; this is used in "DOES>", for example, when it is called in interpreter.
: start-anonymous-colon
  (start-word-common)
\ endcr ." DOER COLON AT $" code-here .hex8 cr
  low:dstack>cpu
  doer-colon colon-type:! ;

;; call this to finish colon definition. it will compile the final "EXIT" for you.
: finish-colon
  ?in-latex
  \ this is for better inlining of words like ": BL?  bl <= ;"
  \ inliner:pre-optim-lit-cmp ;; optimise comparisons
  ;; compile final ret
  high:final-exit,
  set-last-word-length
  cg-slc-resolve
  record-optinfo
  was-wdata? not?<
    ;; we are working with the compiled word now
    ss-latest-cfa dup current-cfa:!
    cfa-ffa@ current-[ffa]:!
\ doer-colon colon-type = ?< endcr ." ANAL DOER COLON $" current-cfa .hex8 ."  can-inline=" can-inline? 0.r cr >?
    anal:analyze
\ doer-colon colon-type = ?< endcr ." DONE ANAL DOER COLON $" current-cfa .hex8 ."  can-inline=" can-inline? 0.r cr >?
    can-inline? not?< high:final-tailcall-optim >? >?
  ilendb:wipe
  can-inline?:!f
  colon-type:!0
  high:reset slc-reset
  debug-colon-finished ;


;; call when starting an assembler definition (after creating all support
;; structures, i.e. when we a ready to compile the code).
: start-code-word
  (start-word-common)
  can-inline?:!t -- this is required to record ilen info
  colon-type:!0
  debug-code-started ;

;; call this when assembler word ends.
: finish-code-word
  colon-type ?error" Succubus should not be dressed in latex"
  set-last-word-length
  record-optinfo
  ilendb:wipe
  high:reset
  debug-code-finished ;


;; call this on system reset.
: sys-reset
  (reset) slc-reset
  high:reset
  colon-type:!0
  ilendb:wipe ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; branch compilers

(*
very useful (for loops) branch optimisation: remove extra sswaps.

each branch restores the stack before "jmp". most of the time the stack is
immediately swapped again. so we can postpone stack swapping.

i.e. do not restore stack before "jmp", and leave tracker in "swapped"
state. when patching the branch, check if stacks are still swapped, and if
not, swap them.

this way we can avoid generating extra swaps for conditionals (forward
jumps). backward jumps are already fixed this way.

this alone cuts 400 msecs in PARASITE 2GB test.

also, align loops to dword boundary. yes, this gives a noticeable
speedup... on benchmark. inliner will align the whole word with loops to
keep loops aligned.

*)

;; align loop body start. this helps a little.
;; SuperScientificBruteForceTests tells that 4 bytes are enough.
: align-loop
  inliner:pre-optim-lit-cmp ;; optimise comparisons
  did-any-align?:!t ;; flag for stack swap remover
  4 code-here 3 and - 3 and low:emit-nops ;


create branch-dispatcher
['] high:(branch), ,
['] high:(branch), ,
['] high:(0branch), ,
['] high:(tbranch), ,
['] high:(+0branch), ,
['] high:(-branch), ,
['] high:(+branch), ,
['] high:(-0branch), ,
['] high:(case-0branch), ,
['] high:(case-tbranch), ,
['] high:(of<>branch), ,
['] high:(of=branch-inv), ,
['] high:(of=branch), ,
['] high:(of<>branch-inv), ,
['] high:(zflag-set-branch), ,
['] high:(zflag-reset-branch), ,
['] high:(cflag-set-branch), ,
['] high:(cflag-reset-branch), ,
['] high:(overflow-flag-branch), ,
['] high:(no-overflow-flag-branch), ,
['] high:(le-flag-branch), ,
['] high:(g-flag-branch), ,
create; (private)

: invert-branch  ( branch-id -- branch-id )
  dup (xxx-min-branch) (xxx-branch-max) within
  not?error" Succubus has no idea how to change sides in such position"
  1 xor ;


|: branch-handler  ( bcode -- patch-address )
  dup (xxx-min-branch) (xxx-branch-max) within
  not?error" Succubus puzzled of where is head or ... tail of this poor thingy"
  ;; optimise comparisons for unconditional branches
  dup (branch) = over (branch-branch) = or ?< inliner:pre-optim-lit-cmp >?
  (xxx-min-branch) - branch-dispatcher dd-nth @execute-tail ;

\ |: sswap-instruction-at-xchg?  ( addr -- ilen // 0 )
\   code-w@  dup $EC_87 = swap $E5_87 = or ?< 2 || 0 >? ;

|: sswap-instruction-at-mov?  ( addr -- ilen // 0 )
  dup code-@ $D5_8B_EC_8B = not?exit< drop 0 >?
  4+ code-w@ $E2_8B = ?< 6 || 0 >? ;

\ |: sswap-instruction-at?  ( addr -- ilen // 0 )
\   dup sswap-instruction-at-xchg? dup ?exit< nip >? drop
\   sswap-instruction-at-mov? ;

;; there is no need to check for basic block boundary, because
;; we never modify the code above (peephole doesn't look that far).
|: check-backward-branch  ( addr -- fixed-addr )
  dup sswap-instruction-at-mov?
  dup 0= high:brn-stack-restore?:!
  + ;

|: restore-branch-state  high:brn-stack-restore?:!f ;

: branch-to  ( addr branch-id )
  swap check-backward-branch swap
  branch-handler low:branch-addr!
  restore-branch-state
  low:finish-branch-bblock ;

;; mark place for backward branches.
;; return addr suitable for "<J-RESOLVE".
;; branches always keep stacks swapped.
: <j-mark  ( -- addr )
  [ tgt-align-loops ] [IF] align-loop [ENDIF]
  low:finish-bblock-xjmp ;

;; generate backward jump.
;; "addr" is the result of "<J-MARK".
: <j-resolve-brn  ( addr branch-id )
  \ swap check-backward-branch swap
  has-back-jumps?:!t
  branch-handler
  low:branch-addr!
  \ restore-branch-state
  low:finish-branch-bblock ;

;; reserve room for branch address, return addr suitable for "RESOLVE-J>".
: mark-j>-brn  ( branch-id -- chain-tail-addr )
  branch-handler
  low:finish-branch-bblock ;

;; use after "MARK-J>-BRN" to reserve jump and append it to jump chain.
: chain-j>-brn  ( prev-tail-addr branch-id -- new-tail-addr )
  branch-handler
  tuck code-!
  low:finish-branch-bblock ;

;; compile "forward jump" (possibly chain) from address to HERE.
;; addr is the result of "MARK-J>".
: resolve-j>  ( addr )
  dup not?exit< drop >?
  inliner:pre-optim-lit-cmp ;; optimise comparisons
  low:finish-bblock-xjmp-fwd >r
  ;; stacks are restored now
  ;; note that all forward branches will restore stacks too
  << dup code-@ r@ rot low:branch-addr! dup ?^|| else| drop rdrop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

: reset-statistics
  stat-words-inlineable:!0
  stat-words-inlined:!0
  stat-bytes-inlined:!0
  stat-instructions-inlined:!0
  stat-direct-optim:!0
  stat-tail-optim:!0
  stat-stitch-optim:!0
  stat-logbranch-optimised:!0
  stat-logbranch-blocked:!0
  stat-logbranch-litcmp:!0
  stat-logbranch-push-pop-tos:!0 ;


;; perform basic initialisation.
;; should be called on system startup, to clean up old values
;; left from image saving.
: initialise
  reset-statistics
  ilendb:initialise
  slc-initialise ;
