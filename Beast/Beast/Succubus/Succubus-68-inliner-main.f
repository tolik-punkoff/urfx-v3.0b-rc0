;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; inlining native words: main inliner part
;; directly included from "Succubus-60-inliner.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; jmp/call tracer

;; all kinds of jmp/call
: trj-j/c  ( addr ilen -- addr ilen )
\ endcr ." J/C at $" over .hex8 ."  ilen=" dup .hex4 cr
  swap over ilendb:iw-len
  <<
    5 of?v| ;; 1-byte opcode, 32-bit jdisp
      dup 1+ low:branch-addr@ false
        \ endcr ."   J/C to $" over .hex8 ."  end=$" cci-w-lastb^ .hex8 cr
      |?
    6 of?v| ;; 2-byte opcode, 32-bit jdisp
      dup 2+ low:branch-addr@ true
        \ endcr ."   COND to $" over .hex8 ."  end=$" cci-w-lastb^ .hex8 cr
        \ 2>r dup code-c@ bl emit .hex2 cr 2r>
      |?
    2 of?v| ;; 1-byte opcode, 8-bit jdisp
      dup 1+ low:branch-addr-c@ true
        \ endcr ."   SHORT-COND to $" over .hex8 ."  end=$" cci-w-lastb^ .hex8 cr
      |?
    else| error" Succubus had never seen such type of branch" >>
  ( ilen addr bdest check-flag )
  ;; conditional jumps should never point out of the word
  over cci-w-start^ cci-w-lastb^ bounds
  ( ilen addr bdest check-flag in-word? )
  swap ?< dup not?error" Succubus doesn't want to jump so far" >?
  ( ilen addr bdest in-word? )
  ?< dup lowest-jump umin lowest-jump:!
     highest-jump umax highest-jump:!
  || drop cci-fix-jumps?:!t >?
  swap ;

;; trace code, find lowest jump.
;; this is not the best way to do it, but meh...
;; actually, it should be done only once, and the result should be remembered.
;; i'll move this to word finalising later.
;; note that final "ret" is still alive here.
: trace-jumps
  lowest-jump:!t highest-jump:!0
  cci-fix-jumps?:!f cci-ret-count:!0
\ endcr ." JUMP TRACER for " debug-.current-cfa-name ."  #iw=" cci-opt-#iw 0.r cr
  cci-opt-iw^ >r cci-opt-#iw cci-start^ << ( i-counter addr-va | iw^ )
    r@ code-w@
\ endcr ."    addr=$" over .hex8 ."  ilc=$" dup .hex4 cr
    dup ilendb:iw-type ilendb:it-jdisp =
    ?< trj-j/c || dup ilendb:iw-type ilendb:it-ret = ?< cci-ret-count:1+! >? >?
    ilendb:iw-len +  r0:1+! r0:1+! \ 1+r! 1+r! -- two, because one item is 2 bytes
  1 under- over ?^|| else| rdrop 2drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; initial stack swap fixers

: starts-with-swap-stacks?  ( -- flag )
  [ SC-EXPERIMENTAL-NO-SSWAP-OPT ] [IF] false exit [ENDIF]
  first-iw@ ilendb:iw-type ilendb:it-sswap = ;


0 quan ssdepth

;; any stack user expects "normal" stack state on entry.
;; for "no stacks" still switch to the data stack, it's usually better.
: setup-stacks
  \ no-stacks-word? ?exit
  no-stacks-word? ?exit< low:dstack>cpu >?
  starts-with-swap-stacks? not?exit< low:restore-stacks >?
  can-remove-iword-first? not?exit< low:restore-stacks >?
  low:stacks-swapped? ?exit< chop-first >?
  ;; stacks are guaranteed not to be swapped here
  [ 0 ] [IF]
    low:last-instr-swap-stacks? not?<
      endcr ." blocked start stack optim for \'" debug-.current-cfa-name ." \'\n" >?
  [ENDIF]
  low:last-instr-swap-stacks? not?exit
  low:stacks-swapped?:!t
  chop-first
  low:remove-last-stack-swap ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; final stack swap fixer

;; any stack user expects "normal" stack state on entry
: check-final-swap-stacks
  no-stacks-word? ?exit
  ;; it is guaranteed by the compiler that stack state is "normal" here
  low:stacks-swapped?:!f
  low:last-instr-swap-stacks? not?exit
  ;; ret + sswap
  highest-jump cci-w-lastb^ 1- ilendb:sswap-len - u< not?exit
  ;; remove last stack swap
  ilendb:sswap-len stat-bytes-inlined:-!
  low:remove-last-stack-swap
  low:stacks-swapped?:!t ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; new codeblock starts either at the end of the word.
;; it is ok, because we already removed extra stack swap.
;; this is the only case when codeblock may have swapped stacks.
\ FIXME: i don't like it, but it is an easy way to block sswap remove.
: setup-new-codeblock
  \ code-here bblock-start^:!
  highest-jump-copied not?exit
\ endcr ." hj: $" highest-jump cci-w-start^ - .hex8 ."  hj-copied: $" highest-jump-copied .hex8 cr
  highest-jump-copied
  ;; skip one instruction (to preserve it)
  ;; k8: why i decided to do this?!
  \ dup code-here u< ?< ilendb:last-len@ + >?
  dup code-here u> ?error" Succubus refuses to perform leap of faith"
\ endcr ."   new bblock start at $: " dup .hex8 cr
  bblock-start^:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main word

: inline-cfa
  current-cfa cfa>optinfo code-@ cci-optinfo^:!
\ endcr ." INLINING " debug-.current-cfa-name cr
\ debug:.s
  \ did-any-align? not?< has-back-jumps-word? did-any-align?:! >?

  debug-inline-started
  prepare-opt-ilen
  prepare-icode
  trace-jumps
\ endcr ." RETS: " cci-ret-count 0.r cr
  remove-ret
  remove-nops
  cci-ret-count ?<
    inline-force-word? not?exit<
        \ endcr ." ret count: " cci-ret-count 0.r cr
        debug-inliner-failed
        cc\,-noinline
        >? >? ;; alas, there are some "ret"s there
  cci-wlen not?exit  ;; empty word, nothing to do
  sanity-check

  ;; ok, we have something to copy
  setup-stacks

  ;; order matters!
  [ debug-disable-inliner-peepopt ] [IFNOT]
  low:stacks-swapped? ?<
    << was-any-stitch-optim?:!f
       remove-end-pop-ebx-start-push-ebx
       remove-end-push-eax-start-pop-eax
       remove-end-push-ebx-start-pop-eax
       remove-end-push-ebx-mov-ebx-eax-start-pop-eax
       remove-end-push-ebx-mov-ebx-lit-start-pop-eax -- most important for benchmark ;-)
       remove-end-push-ebx-mov-ebx-mod-r/m-start-pop-eax
       remove-end-push-[esp+4]-start-pop-eax
       remove-end-push-ebx-mov-ebx-start-pop-ebx
       remove-end-push-ebx-start-pop-ebx
       remove-end-lit-load-start-[ebx]-load  -- this may remove the only instruction in "@"
       remove-end-push-lit-nonpop-start-pop-eax
       pre-optim-end-mov-[ebp],ebx-start-mov-ebx,[ebp]
       pre-optim-add/sub-under
       pre-optim-swap-store
       pre-optim-end-push-ebx-lit-shift-start-pop-eax
       pre-optim-lit-cmp
       remove-nops
    was-any-stitch-optim? cci-wlen land ?^|| else| >>
  >?
  [ENDIF]

  cci-wlen ?<
    ;; if inlining word has any backward jumps, it also has
    ;; aligned loops. align the whole word, so loops will stay aligned.
    ;; do it here, after applying optimisations, so we could calculate
    ;; the proper NOP count.
    remove-nops
    [ tgt-align-loops ] [IF] has-back-jumps-word? ?< realign-code >? [ENDIF]
    copy-code
    check-final-swap-stacks
    setup-new-codeblock
  >?
  \ TODO: do the same for iwords. i.e. inlined forth word can have "add/mul/etc" with literal too!
  [ debug-disable-inliner-peepopt ] [IFNOT]
  low:stacks-swapped? ?<
    << was-any-stitch-optim?:!f
      optim-addr-store
      optim-rstack-store
      optim-rstack-push-lit
      optim-load-[esp]-rstack-pop
      optim-rstack-pop-drop
      optim-add-lit-fold
      optim-sub-lit-fold
      optim-add-lit-inc/dec
      optim-add-lit-add-lit
      optim-mov-lit-add-lit
      optim-mov-lit-umul
      optim-mov-lit-imul
      optim-mov-lit-udiv
      optim-mov-lit-idiv
      optim-mov-lit-imod/umod
      optim-mov-lit-shift
      optim-lit-shift
      optim-0max
      optim-swap-sub
      optim-lit-bitwise
      optim-lit-~and
      optim-lit-add-load
      optim-lit-add-store
      optim-lit-add/sub-[ebx]
      optim-n-drop
      optim-n-rdrop
      optim-lit-dd-nth
      optim-dd-nth-load
      optim-dd-nth-store
      optim-dd-nth-addr
      optim-dd-nth-addr-2
      optim-load-ebx-eax*4-lit
    was-any-stitch-optim? ?^|| else| >>
  >?
  [ENDIF]

  debug-inline-finished
\ endcr ."   done inlining.\n"
\ debug:.s
  stat-words-inlined:1+! ;
