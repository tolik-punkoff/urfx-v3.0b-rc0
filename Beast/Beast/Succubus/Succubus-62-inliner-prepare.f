;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; inlining native words: preparation, utilities
;; directly included from "Succubus-60-inliner.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; optinfo start address
0 quan cci-optinfo^
;; # of instruction lengthes
0 quan cci-opt-#iw
;; instruction length buffer (2 bytes per item)
0 quan cci-opt-iw^
;; code start
0 quan cci-start^
;; code length (in bytes)
0 quan cci-wlen

;; code start (never changes, used to check jmp/call destinations)
0 quan cci-w-start^
;; code end (never changes, used to check jmp/call destinations)
0 quan cci-w-lastb^ -- last word byte
;; used in aligner
0 quan cci-start-code-here

0 quan cci-fix-jumps?
0 quan cci-ret-count

;; jumping to word head prevents stack swap optimisation
-1 quan lowest-jump
;; do not remove anything above this jump point.
;; branch can jump directly to "ret" (because jumps are coded this way).
;; it is better to code jumps forward so they insert stack swap at the
;; destination, but alas, i can't. it *may* be possible (because stack
;; state is tracked), but i'm not sure (because i am too sleepy now).
0 quan highest-jump

;; above, fixed for the destination address
0 quan highest-jump-copied


: prepare-opt-ilen
  cci-optinfo^ dup not?error" no optinfo for inlineable word"
  optinfo-count@  ( info-addr counter )
  dup not?error" empty optinfo for inlineable word"
  cci-opt-#iw:! cci-opt-iw^:!
  code-here cci-start-code-here:! ;

: prepare-icode
  current-cfa dup cci-start^:! dup cci-w-start^:!
  cfa-wlen@ dup 0<= ?error" invalid wlen"
\ endcr ." WLEN=" dup . ." (instr=" cci-opt-#ilen 0.r ." )\n"
  dup cci-wlen:! cci-w-start^ + 1- cci-w-lastb^:! ;


: last-iw^  ( -- code-addr )  cci-opt-#iw 1- cci-opt-iw^ dw-nth ;
: last-iw@  ( -- ilen )  last-iw^ code-w@ ;
: first-iw@ ( -- ilen )  cci-opt-iw^ code-w@ ;

: nth-iw@   ( idx -- ilen )
  dup cci-opt-#iw u>= ?exit< drop 0 >?
  cci-opt-iw^ dw-nth code-w@ ;

: nth-last-iw@  ( idx -- ilen )
  cci-opt-#iw swap - 1- 0 max cci-opt-iw^ dw-nth code-w@ ;


;; skip first inlining word instruction
: chop-first
  first-iw@ ilendb:iw-len
  dup cci-start^:+! cci-wlen:-!
  cci-opt-iw^:2+! cci-opt-#iw:1-! ;

;; skip first inlining word instruction
: chop-last
  last-iw@ ilendb:iw-len cci-wlen:-!
  cci-opt-#iw:1-! ;


;; this is always legal
: remove-ret
  last-iw@ ilendb:iw-type ilendb:it-ret = not?exit
  chop-last
  cci-ret-count:1-! ;

;; should not end with "ret"
: sanity-check
  cci-start^ cci-wlen + 1- code-c@ $C3 -
  not?error" Succubus see something wicked" ;


: can-remove-iword-first?  ( -- flag )
  lowest-jump cci-start^ u> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make sure that the copied code is properly aligned.

: remove-nops
  cci-wlen not?exit  ;; empty word, nothing to do
  can-remove-iword-first? not?exit
  first-iw@ ilendb:iw-type ilendb:it-nop-align = not?exit
  chop-first recurse-tail ;

;; align with respect to removed instructions. this is because
;; the original align was done for the unchanged word.
: realign-code
  has-back-jumps?:!t  ;; so this word will be aligned too
  did-any-align?:!t   ;; flag for stack swap remover
  ;; to properly align the inlined code, we should:
  ;; 1. insert enough nops so original "code-here" would be aligned
  ;;    (this is because the word itself is always properly aligned).
  ;; 2. but we changed word start, so we need to compensate the difference.
  4 cci-start-code-here 3 and - 3 and   ;; align according to the original "code-here"
  cci-start^ cci-w-start^ - +           ;; add bytes expected to emit
  code-here cci-start-code-here - -     ;; subtract actuial number of emited bytes
  3 and                                 ;; no more than 3
\ endcr ." REALIGN at $" code-here .hex8 ."  count=" dup 0.r cr
  low:emit-nops ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; code copiers

: copy-jmp/call
  ;; conditional jumps should never point out of the word
  cci-start^ code-c@
\ endcr ." C-J/C: OPC=$" dup .hex2 cr
  code-db,  ;; copy opcode
  cci-start^ 1+ low:branch-addr@
  dup cci-w-start^ cci-w-lastb^ bounds
  ?< drop cci-start^ 1+ code-@ code-dd, || low:branch-addr, >?
  chop-first ;

;; we need to fix only CALL and JMP instructions.
;; check for type and length (the only 5-byte jdisps are the ones we want).
: iw-call/jmp?  ( iw -- flag )
  [ ilendb:it-jdisp 256 * 5 or ] {#,} = ;

: copy-instr
\ endcr ." copying instructions from $" cci-start^ .hex8 ."  (" first-ilen@ .hex4 ."  bytes)\n"
  cci-opt-#iw not?error" optinfo desync (0)"
  first-iw@ dup ilendb:len, ;; copy length
  dup iw-call/jmp? ?exit< drop copy-jmp/call >?
  ilendb:iw-len cci-start^ << ( len addr-va )
    dup code-c@ code-db, 1+
    1 under- over ?^||
  else| 2drop >>
  chop-first ;

: copy-code-simple
  cci-opt-#iw not?error" optinfo desync (0)"
  cci-wlen not?error" optinfo desync (1)"
\ endcr ." simple copying instructions from $" cci-start^ .hex8 ."  (" first-ilen@ . ." bytes)\n"
  ;; copy code
  cci-wlen cci-start^ << over +?^| dup code-c@ code-db, 1+ 1 under- |? else| 2drop >>
  ;; copy length data
  cci-opt-#iw cci-opt-iw^
  << over +?^| dup code-w@ ilendb:len, 2+ 1 under- |? else| 2drop >> ;

: calc-copied-highest-jump
  highest-jump dup ?< cci-start^ - code-here + >? highest-jump-copied:! ;

;; copy, fix calls by the way
: copy-code
\ endcr ." copying " cci-opt-#ilen . ." instructions from $" cci-start^ .hex8 ."  (" cci-wlen . ." bytes).\n"
  cci-wlen stat-bytes-inlined:+!
  cci-opt-#iw stat-instructions-inlined:+!
  calc-copied-highest-jump
  cci-fix-jumps? not?exit< copy-code-simple >?
  << cci-wlen ?^| copy-instr |? v|| >> ;
