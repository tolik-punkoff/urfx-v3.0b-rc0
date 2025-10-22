;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BEGIN, FOR, DO
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module LOOP-SUPPORT
<disable-hash>

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DO/FOR loops

;; universal "(DO)" prepare
;; loops from start to limit-1
;; sets zero flag if limit = start
code-swap-inline: (DO)  ( limit start -- | limit counter )
  pop   ecx
  mov   esi, utos
  mov   edx, # $8000_0000
  sub   edx, ecx    ;; limit = 80000000h-to
  add   utos, edx   ;; index = 80000000h-to+from
  ;; EDX: limit
  ;; TOS: index
  mov   eax, [uadr+] uofs@ (lsp^) #
  mov   [eax], edx
  mov   [eax+] 4 #, utos
  lea   eax, [eax+] # 8
  mov   [uadr+] uofs@ (lsp^) #, eax
  cmp   esi, ecx    ;; set zero flag if equal
  pop   utos
;code-swap-next (force-inline)

;; emulates "(DO)"
;; loops from start to limit-1
;; use "js" to skip the loop
code-swap-inline: (FOR)  ( limit -- | limit counter )
  mov   eax, [uadr+] uofs@ (lsp^) #
  mov   ecx, utos
  xor   utos, utos
  mov   edx, # $8000_0000
  sub   edx, ecx    ;; limit = 80000000h-to
  add   utos, edx   ;; index = 80000000h-to+from
  ;; EDX: limit
  ;; TOS: index
  mov   [eax], edx
  mov   [eax+] 4 #, utos
  ;; ECX is the original limit here
  cmp   ecx, # 0    ;; can't use "dec cx" due to minint value
  ;; always allocate lstack vars
  lea   eax, [eax+] # 8
  mov   [uadr+] uofs@ (lsp^) #, eax
  pop   utos
;code-swap-next (force-inline)

;; this code is very special: use "jno" as continue condition
;; "(UNLOOP)" is explicit
code-swap-inline: (+LOOP)  ( delta -- | limit counter )
  ;; ANS loops
  mov   eax, [uadr+] uofs@ (lsp^) #
  add   [eax+] -4 #, utos
  pop   utos
;code-swap-next (force-inline)

;; this code is very special: use "jno" as continue condition
;; "(UNLOOP)" is explicit
code-naked-inline: (LOOP)  ( -- | limit counter )
  mov   eax, [uadr+] uofs@ (lsp^) #
  add   dword^ [eax+] -4 #, # 1 ;; cannot use "inc" here!
;code-no-stacks (force-inline)

code-naked-inline: (UNLOOP)
  sub   [uadr+] uofs@ (lsp^) #, # 8
;code-no-stacks (force-inline)

code-swap-inline: (I)  ( | limit index -- real-index | limit index )
  mov   eax, [uadr+] uofs@ (lsp^) #
  push  utos
  mov   utos, [eax+] # -4
  sub   utos, [eax+] # -8
;code-swap-next (force-inline)

code-swap-inline: (J)  ( | limit index -- real-index | limit index )
  mov   eax, [uadr+] uofs@ (lsp^) #
  push  utos
  mov   utos, [eax+] # -4 8 -
  sub   utos, [eax+] # -8 8 -
;code-swap-next (force-inline)

code-naked-inline: (I#)  ( idx | limit index -- real-index | limit index )
  shl   utos, # 3
  neg   utos
  mov   eax, [uadr+] uofs@ (lsp^) #
  mov   ecx, [eax+] [utos*1+] # -4
  sub   ecx, [eax+] [utos*1+] # -8
  mov   utos, ecx
;code-no-stacks (force-inline)

end-module LOOP-SUPPORT


extend-module SYSTEM

;; called by loops to indicate that they are using several items on the locals stack.
;; at the end of the loop, it is called with negative number.
0 quan (lstack-use)  ( items )

0 quan (chain-break)
0 quan (chain-cont)
0 quan (loop-pair)

0xb0de_0301 constant PAIR-BEGIN
\ 0xb0de_0302 constant PAIR-IF
\ 0xb0de_0303 constant PAIR-IFELSE
0xb0de_0304 constant PAIR-DO
\ 0xb0de_0305 constant PAIR-CASE
\ 0xb0de_0306 constant PAIR-OF
\ 0xb0de_0307 constant PAIR-OTHER
0xb0de_0308 constant PAIR-WHILE
0xb0de_0309 constant PAIR-FOR
0xb0de_030a constant PAIR-QDO
\ 0xb0de_030b constant PAIR-IFEXIT
\ 0xb0de_029a constant PAIR-CBLOCK


: LOOPS-SYS-RESET
  (lstack-use):!0
  (chain-break):!0 (chain-cont):!0 (loop-pair):!0 ;

: (LS-ALLOT)  ( n )
  (lstack-use) dup ?< execute-tail || 2drop >? ;

: (COUNTED-LOOP?)  ( n -- bool )
  dup pair-do =  over pair-qdo = or  swap pair-for = or ;
  \ pair-do pair-qdo pair-for 3 one-of ;

;; all failed whiles will terminate the loop
: (COMPILE-WHILE)
  ?comp swap pair-begin ?pairs
  (chain-break) swap Succubus:chain-j>-brn (chain-break):!
  pair-begin ;

: (COMPILE-UNTIL)
  ?comp swap pair-begin ?pairs
  (chain-cont) swap Succubus:<j-resolve-brn
  (chain-break) Succubus:resolve-j>
  (loop-pair):! (chain-cont):! (chain-break):! ;

: (LOOP-FINISH)
  (chain-cont) Succubus:(no-overflow-flag-branch) Succubus:<j-resolve-brn
  (chain-break) Succubus:resolve-j>
  \\ loop-support:(unloop)
  (loop-pair):! (chain-cont):! (chain-break):! ;

end-module SYSTEM


extend-module FORTH
using system

*: BEGIN
  ?comp
  (chain-break) (chain-cont) (loop-pair)
  (chain-break):!0  Succubus:<j-mark (chain-cont):!
  pair-begin dup (loop-pair):! ;

;; all failed whiles will terminate the loop
*: WHILE      Succubus:(0branch) (compile-while) ;
*: NOT-WHILE  Succubus:(tbranch) (compile-while) ;
*: 0WHILE     Succubus:(tbranch) (compile-while) ;
*: -WHILE     Succubus:(+0branch) (compile-while) ;
*: +WHILE     Succubus:(-0branch) (compile-while) ;
*: -0WHILE    Succubus:(+branch) (compile-while) ;
*: +0WHILE    Succubus:(-branch) (compile-while) ;

*: REPEAT  Succubus:(branch) (compile-until) ;

*: UNTIL      Succubus:(0branch) (compile-until) ;
*: NOT-UNTIL  Succubus:(tbranch) (compile-until) ;
*: 0UNTIL     Succubus:(tbranch) (compile-until) ;
*: -UNTIL     Succubus:(+0branch) (compile-until) ;
*: +UNTIL     Succubus:(-0branch) (compile-until) ;
*: -0UNTIL    Succubus:(+branch) (compile-until) ;
*: +0UNTIL    Succubus:(-branch) (compile-until) ;


*: DO
  ?comp
  \\ loop-support:(do)
  (chain-break) (chain-cont) (loop-pair)
  (chain-break):!0  Succubus:<j-mark (chain-cont):!
  pair-do dup (loop-pair):!  2 (ls-allot) ;

*: ?DO
  ?comp
  \\ loop-support:(do)
  (chain-break) (chain-cont) (loop-pair)
  Succubus:(zflag-set-branch) Succubus:mark-j>-brn
  (chain-break):!  Succubus:<j-mark (chain-cont):!
  pair-qdo dup (loop-pair):!  2 (ls-allot) ;

*: LOOP
  ?comp pair-do pair-qdo ?2pairs
  \\ loop-support:(loop) system::(loop-finish) -2 (ls-allot) ;

*: +LOOP
  ?comp pair-do pair-qdo ?2pairs
  \\ loop-support:(+loop) system::(loop-finish) -2 (ls-allot) ;

*: I  ?comp (loop-pair) (counted-loop?) not?error" 'I' out of a loop" \\ loop-support:(i) ;
*: J  ?comp (loop-pair) (counted-loop?) not?error" 'J' out of a loop" \\ loop-support:(j) ;
;; roman numbers for loop counters, it's fun!
*: II  ?comp (loop-pair) (counted-loop?) not?error" 'II' out of a loop" \\ loop-support:(j) ;
*: III  ?comp (loop-pair) (counted-loop?) not?error" 'III' out of a loop" 2 #, \\ loop-support:(i#) ;
*: IV  ?comp (loop-pair) (counted-loop?) not?error" 'IV' out of a loop" 3 #, \\ loop-support:(i#) ;

*: UNLOOP  ?comp (loop-pair) (counted-loop?) not?error" 'UNLOOP' out of a loop" \\ loop-support:(unloop) ;

*: FOR
  ?comp
  \\ loop-support:(for)
  (chain-break) (chain-cont) (loop-pair)
  Succubus:(le-flag-branch) Succubus:mark-j>-brn
  (chain-break):!  Succubus:<j-mark (chain-cont):!
  pair-for dup (loop-pair):!  2 (ls-allot) ;

*: ENDFOR
  ?comp pair-for ?pairs
  \\ loop-support:(loop) system::(loop-finish) -2 (ls-allot) ;


*: BREAK
  ?comp
  (loop-pair) dup pair-begin = swap (counted-loop?) or ?<
    (chain-break) Succubus:(branch) Succubus:chain-j>-brn (chain-break):!
  || error" 'BREAK' out of loop" >? ;

*: LEAVE  [\\] BREAK ;

*: CONTINUE
  ?comp
  (loop-pair) pair-begin = ?<
    (chain-cont) Succubus:(branch) Succubus:<j-resolve-brn
  || (loop-pair) (counted-loop?) ?<
    \\ loop-support:(loop)
    (chain-cont) Succubus:(cflag-reset-branch) Succubus:<j-resolve-brn
    (chain-break) Succubus:(branch) Succubus:chain-j>-brn (chain-break):!
  || (loop-pair) (counted-loop?) not?error" 'CONTINUE' out of loop" >? >? ;

end-module FORTH
