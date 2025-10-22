;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; high-level codegen for special words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module high
<disable-hash>
<published-words>

;; call this before compiling a new colon word
: reset
  low:force-reset-swap-stacks
  can-inline?:!f
  has-rets?:!f
  has-back-jumps?:!f did-any-align?:!f ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
: remove-last-push-tos?  ( -- removed? )
  low:dstack>cpu
  low:last-removable-push-tos? dup ?< low:remove-last-unsafe >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; optimise "pop ebx / push ebx".
;; this is called when we're going to overwrite TOS.
: push-tos-kill
  low:dstack>cpu
  ( low:last-removable-pop-tos?) false
  ?< low:remove-last-unsafe
  || low:ebx low:push-reg32 >? ;

: push-tos-anyway
  low:dstack>cpu
  low:ebx low:push-reg32 ;

;; optimise "pop ebx / push ebx".
;; this is called when we need TOS value.
(*
: push-tos-keep
  low:dstack>cpu
  low:last-removable-pop-tos?
  ?< low:remove-last-unsafe
     0 low:mov-ebx,[esp+value]
  || low:ebx low:push-reg32 >? ;
*)

: pop-tos
  low:dstack>cpu
  low:ebx low:pop-reg32 ;


: call-[addr]  ( addr )
  \ FF 15 78 56 34 12   call    dword [0x12345678]
  low:restore-stacks
  ilendb:cg-begin
  $15_FF code-dw, code-dd,
  ilendb:cg-end
  low:dstack>cpu ;


: call  ( addr )
  low:restore-stacks
  low:(call)
  ;; see comment for "start-colon"
  low:dstack>cpu ;


: jump  ( addr )
  low:restore-stacks
  low:(jump)
  ;; see comment for "start-colon"
  low:dstack>cpu ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tail call optimisation

: tailcall-optim
  ilendb:last-type@ ilendb:it-jdisp = not?exit
  ilendb:last-len@ 5 = not?exit
  code-here 5 - dup bblock-start^ u>= not?exit< drop >?
  code-c@ $E8 = not?exit ;; call
  ;; replace with jmp
  $E9 code-here 5 - code-c!
  stat-tail-optim:1+! ;


0 quan final-tail-call-addr^

;; called after anayzer decided that the word is not inlineable.
;; final "ret" is already emited.
|: check-final-tailcall-optim-no-sswap
  ilendb:last-type@ ilendb:it-jdisp = not?exit
  ilendb:last-len@ 5 = not?exit
  \ code-here 5 - dup bblock-start^ u>= not?exit< drop >?
  code-here 5 - dup code-c@ $E8 = ?< final-tail-call-addr^:! || drop >? ;

|: check-final-tailcall-optim
  final-tail-call-addr^:!0
  ilendb:last-type@ ilendb:it-sswap = not?exit< check-final-tailcall-optim-no-sswap >?
  ilendb:prev-last-type@ ilendb:it-jdisp = not?exit
  ilendb:prev-last-len@ 5 = not?exit
  \ code-here 5 - dup bblock-start^ u>= not?exit< drop >?
  code-here 5 - ilendb:last-len@ - dup code-c@ $E8 = ?< final-tail-call-addr^:! || drop >? ;

;; called after anayzer decided that the word is not inlineable.
;; final "ret" is already emited.
: final-tailcall-optim
  final-tail-call-addr^ ?< $E9 final-tail-call-addr^ code-c! stat-tail-optim:1+! >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; exits
;; there is no need to explicitly finish basic block for exits

\ tgt-exit-as-branch [IF]
0 quan exit-chain-sswap   ;; when stacks are swapped
0 quan exit-chain         ;; when stacks are normal
\ [ENDIF]

;; compile "forward jump" (possibly chain) from address to HERE.
;; addr is the result of "MARK-J>".
|: resolve-jchain  ( chain-addr )
  dup not?exit< drop >?
\ endcr ." JCHAIN from $" dup .hex8 cr ."  dest=$" code-here .hex8 cr
  code-here >r << dup code-@ r@ rot low:branch-addr! dup ?^|| else| drop rdrop >> ;

;; branch should be already compiled
|: append-dchain  ( chain^ )
  code-here over @ code-dd, swap ! ;

|: final-exit-jumps
  exit-chain-sswap ?<
    \ low:stacks-swapped? not?< low:swap-stacks, low:stacks-swapped?:!t >?
    \ low:finish-ret-bblock
    low:dstack>cpu
\ endcr ." FINAL-SSWAP-JUMP at $" code-here .hex8 cr
    exit-chain-sswap resolve-jchain
    low:finish-ret-bblock >?
  exit-chain ?< low:finish-ret-bblock >?
  low:restore-stacks
\ exit-chain ?< endcr ." FINAL-JUMP at $" code-here .hex8 cr >?
  exit-chain resolve-jchain ;

|: exit-can-inline?  ( -- flag )
  can-inline? not?exit&leave
  has-rets? not not?exit&leave
  allow-forth-inlining-analysis not?exit&leave
  immediate-word? not?exit&leave
  inline-force-word? ?exit&leave
  ;; check length
  code-here code-start^ - #inline-bytes u<= ;


: final-exit,
\ endcr ." ***FINAL-EXIT!\n"
  check-final-tailcall-optim
  final-exit-jumps
\ exit-chain exit-chain-sswap or ?< endcr ." FINAL-RET at $" code-here .hex8 cr >?
\ exit-chain ?< endcr ." FINAL-JUMP at $" code-here .hex8 cr >?
  ilendb:cg-begin
  xasm:reset
    xasm:instr:ret,
  ilendb:cg-end-ret
  low:finish-ret-bblock ;

;; words with "ret" cannot be inlined yet, so we can perform TCO.
: exit,
  [ tgt-exit-as-branch ] [IF]
  exit-can-inline? ?exit<
\ endcr ." JEXIT AT $" code-here .hex8 cr
    low:last-instr-swap-stacks? ?<
      low:remove-last-stack-swap
      low:stacks-swapped? not low:stacks-swapped?:! >?
    ilendb:cg-begin
    $E9 code-db,
    low:stacks-swapped? ?< exit-chain-sswap:^ || exit-chain:^ >?
    append-dchain
    ilendb:cg-end-jdisp
    low:finish-ret-bblock
    low:dstack>cpu >?
  [ENDIF]
  low:restore-stacks
  tailcall-optim
  low:ret
  ;; this should not compile stacks-swap.
  ;; rationale: it interferes with "['] exit <\, \>".
  ;; also, it makes the system slightly bigger.
  ;; "<\," blocks inlining, so jump pad will not be inserted too.
  low:finish-ret-bblock ;

|: exit-jump-cond  ( cond )
  [ tgt-exit-as-branch ] [IF]
  exit-can-inline? ?exit<
\ endcr ." ?JEXIT " dup . ." AT $" code-here .hex8 cr
    low:last-instr-swap-stacks? ?<
      low:remove-last-stack-swap
      low:stacks-swapped? not low:stacks-swapped?:! >?
    ilendb:cg-begin
    $0F code-db, ( xasm:cond:invert) $80 + code-db,
    low:stacks-swapped? ?< exit-chain-sswap:^ || exit-chain:^ >?
    append-dchain
    ilendb:cg-end-jdisp >?
  [ENDIF]
  xasm:cond:z = ?< low:ret-z-sswap || low:ret-nz-sswap >? ;

: ?exit,
  remove-last-push-tos?
  low:test-ebx,ebx
  not?< pop-tos >?
  \ low:restore-stacks
  xasm:cond:nz exit-jump-cond
  low:finish-branch-bblock ;

: not?exit,
  remove-last-push-tos?
  low:test-ebx,ebx
  not?< pop-tos >?
  \ low:restore-stacks
  xasm:cond:z exit-jump-cond
  low:finish-branch-bblock ;

;; the following words will drop the flag on falure, but
;; leave it unchanged on success
: ?exit&leave,
  low:test-ebx,ebx
  \ low:restore-stacks
  xasm:cond:nz exit-jump-cond
  pop-tos
  low:finish-branch-bblock ;

;; the following words will drop the flag on falure, but
;; leave it unchanged on success
: not?exit&leave,
  low:test-ebx,ebx
  \ low:restore-stacks
  xasm:cond:z exit-jump-cond
  pop-tos
  low:finish-branch-bblock ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; branches
;; there is no need to explicitly finish basic block for branches

$include "Succubus-22-cg-brn-helpers.f"
<published-words>

;; this is used to synthesize conditional instructions, don't record
: jcond-short,  ( disp cond )
  ilendb:cg-begin
  15 and $70 or code-db,  code-db,
  ilendb:cg-end-jdisp ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; branch codegen
;; each branch generator should return address to patch

;; this is used for backward branches.
;; backward branch may branch to stack swap, so there is
;; no need to restore stack and then swap it back immediately.
false quan brn-stack-restore?

: brn-restore-stacks
  brn-stack-restore? ?< low:restore-stacks ||
    ;; there may be the case when our stacks are not swapped...
    ;; ...and we need to force-swap them into invalid state
    ;; (because it was the state assumed by the caller)
    low:dstack>cpu >? ;

;; conditional jump, used to *finish* branch instructions
: jcond,  ( cond -- patch-addr )
  brn-restore-stacks
  ilendb:cg-begin
  $0F code-db, 15 and $80 or code-db, code-here 0 code-dd,
  ilendb:cg-end-jdisp ;


: (branch),  ( -- patch-addr )
  brn-restore-stacks
  ilendb:cg-begin
  $E9 code-db, code-here 0 code-dd,
  ilendb:cg-end-jdisp ;

: (0branch),  ( -- patch-addr )
  tbranch-conds branch-cond-cg
  xasm:cond:invert jcond, ;

: (tbranch),  ( -- patch-addr )
  tbranch-conds branch-cond-cg
  jcond, ;

: (+0branch),  ( -- patch-addr )
  remove-last-push-tos?
\ brn-cdetect-debug
  low:test-ebx,ebx
  not?< pop-tos >?
  xasm:cond:ns jcond, ;

: (-0branch),  ( -- patch-addr )
  remove-last-push-tos?
\ brn-cdetect-debug
  low:cmp-ebx,#0
  not?< pop-tos >?
  xasm:cond:le jcond, ;

: (+branch),  ( -- patch-addr )
  remove-last-push-tos?
\ brn-cdetect-debug
  low:cmp-ebx,#0
  not?< pop-tos >?
  xasm:cond:g jcond, ;

: (-branch),  ( -- patch-addr )
  remove-last-push-tos?
\ brn-cdetect-debug
  low:test-ebx,ebx
  not?< pop-tos >?
  xasm:cond:s jcond, ;


;; ( 0 ) -- jmp
;; ( n !0 ) -- no jmp
;; i.e.: 0 -- pop, jump
;; i.e.: !0 -- pop, pop, not jump
;; this code sux
: (case-0branch),  ( -- patch-addr )
  remove-last-push-tos?
\ brn-cdetect-debug
  low:test-ebx,ebx
  not?< pop-tos >?
  $01 xasm:cond:z jcond-short, low:ebx low:pop-reg32
  xasm:cond:z jcond, ;


;; ( !0 ) -- jmp
;; ( n 0 ) -- no jmp
;; i.e.: !0 -- pop, jump
;; i.e.: 0 -- pop, pop, not jump
;; this code sux
: (case-tbranch),  ( -- patch-addr )
  remove-last-push-tos?
\ brn-cdetect-debug
  low:test-ebx,ebx
  not?< pop-tos >?
  $01 xasm:cond:nz jcond-short, low:ebx low:pop-reg32
  xasm:cond:nz jcond, ;

|: (xof-branch)  ( cond1 cond2 )
  low:dstack>cpu
  low:eax low:pop-reg32
  low:swap-eax,ebx-(use-edx)
  low:cmp-ebx,eax
  swap $01 swap jcond-short, low:ebx low:pop-reg32
  jcond, ;

;; val<>n: ( val n -- val ) branch
;; val=n:  ( val n ) no branch
;; i.e.: <> -- pop, jump
;; i.e.: = -- pop, pop, not jump
;; this code sux
: (of<>branch),  ( -- patch-addr )
  xasm:cond:nz xasm:cond:nz (xof-branch) ;

;; val=n:  ( val n -- val ) branch
;; val<>n: ( val n ) no branch
;; i.e.: = -- pop, jump
;; i.e.: <> -- pop, pop, not jump
;; this code sux
: (of=branch),  ( -- patch-addr )
  xasm:cond:z xasm:cond:z (xof-branch) ;

;; val<>n:  ( val n ) branch
;; val=n: ( val n -- val ) no branch
;; i.e.: <> -- pop, pop, jump
;; i.e.: = -- pop, not jump
;; this code sux
: (of<>branch-inv),  ( -- patch-addr )
  xasm:cond:z xasm:cond:nz (xof-branch) ;

;; val=n:  ( val n ) branch
;; val<>n: ( val n -- val ) no branch
;; i.e.: = -- pop, pop, jump
;; i.e.: <> -- pop, not jump
;; this code sux
: (of=branch-inv),  ( -- patch-addr )
  xasm:cond:nz xasm:cond:z (xof-branch) ;


;; used for DO/FOR
: (zflag-set-branch),  ( -- patch-addr )
  xasm:cond:z jcond, ;

: (zflag-reset-branch),  ( -- patch-addr )
  xasm:cond:nz jcond, ;

;; used for DO/FOR
: (cflag-reset-branch),  ( -- patch-addr )
  xasm:cond:nc jcond, ;

: (cflag-set-branch),  ( -- patch-addr )
  xasm:cond:c jcond, ;

;; used for DO/FOR
: (overflow-flag-branch),  ( -- patch-addr )
  xasm:cond:o jcond, ;

: (no-overflow-flag-branch),  ( -- patch-addr )
  xasm:cond:no jcond, ;

;; used for DO/FOR
: (le-flag-branch),  ( -- patch-addr )
  xasm:cond:le jcond, ;

: (g-flag-branch),  ( -- patch-addr )
  xasm:cond:g jcond, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; stack manipulation

;; doesn't swap stacks, doesn't pop EBX
|: n-esp-drop,  ( count )
  \ dup 0< ?error" invalid drop count"
  dup not?exit< drop >?
  << 1 of?v| low:eax low:pop-reg32 |?
     2 of?v| low:eax low:pop-reg32
             low:eax low:pop-reg32 |?
     3 of?v| low:eax low:pop-reg32
             low:eax low:pop-reg32
             low:eax low:pop-reg32 |?
  else| 4* low:lea-esp-[esp+value] >> ;


seal-module
end-module high (published)
