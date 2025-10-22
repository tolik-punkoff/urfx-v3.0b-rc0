;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; error, abort, etc.
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


code-naked-no-inline: ERROR  ( addr count )
  pop   eax
  jmp   dword^ # tgt-(abort)-cfa
;code-no-next (noreturn)

(*
code-swap-inline: ?ERROR  ( flag addr count )
  cmp   dword^ [esp+] 4 #, # 0
  jz    @@f
  swap-stacks
  pop   eax
  jmp   dword^ # tgt-(abort)-cfa
@@:
  lea   esp, [esp+] # 4 2 *
  pop   utos
;code-swap-next

code-swap-inline: NOT?ERROR  ( flag addr count )
  cmp   dword^ [esp+] 4 #, # 0
  jnz   @@f
  swap-stacks
  pop   eax
  jmp   dword^ # tgt-(abort)-cfa
@@:
  lea   esp, [esp+] # 4 2 *
  pop   utos
;code-swap-next
*)
