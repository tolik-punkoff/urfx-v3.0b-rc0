;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level: literals, branches
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


code-dummy: EXIT
(inline-blocker) (noreturn)

code-dummy: ?EXIT  ( flag )
(inline-blocker)

code-dummy: NOT?EXIT  ( flag )
(inline-blocker)

code-dummy: 0?EXIT  ( flag )
(inline-blocker)

;; the following words will drop the flag on falure, but
;; leave it unchanged on success
code-dummy: ?EXIT&LEAVE  ( exit: flag -- flag ) ( skip: flag )
(inline-blocker)

;; the following words will drop the flag on falure, but
;; leave it unchanged on success
code-dummy: NOT?EXIT&LEAVE  ( exit: flag -- flag ) ( skip: flag )
(inline-blocker)

code-dummy: 0?EXIT&LEAVE  ( exit: flag -- flag ) ( skip: flag )
(inline-blocker)


code-swap-inline: EXECUTE  ( cfaxt )
  mov   eax, utos
  pop   utos
  swap-stacks
  call  eax
;code-next

code-swap-inline: @EXECUTE  ( cfaxt )
  mov   eax, utos
  pop   utos
  swap-stacks
  call  dword^ [eax]
;code-next

code-swap-inline: ?EXECUTE  ( cfaxt )
  mov   eax, utos
  pop   utos
  test  eax, eax
  swap-stacks
  nz? do-when call  eax
;code-next

;; load, check for 0, execute if not 0
code-swap-inline: @?EXECUTE  ( cfa^ )
  mov   eax, utos
  pop   utos
  mov   eax, [eax]
  test  eax, eax
  swap-stacks
  nz? do-when call  eax
;code-next


code-swap-inline: EXECUTE-TAIL  ( cfaxt )
  mov   eax, utos
  pop   utos
  swap-stacks
  jmp   eax
;code-no-next (noreturn) (inline-blocker) (force-inline)

code-swap-inline: ?EXECUTE-TAIL  ( cfaxt )
  mov   eax, utos
  pop   utos
  test  eax, eax
  swap-stacks
  nz? do-when jmp   eax
;code-next (inline-blocker) (force-inline)

code-swap-inline: @EXECUTE-TAIL  ( cfaxt )
  mov   eax, utos
  pop   utos
  swap-stacks
  jmp   dword^ [eax]
;code-no-next (noreturn) (inline-blocker) (force-inline)

code-swap-inline: @?EXECUTE-TAIL  ( cfaxt )
  mov   eax, utos
  pop   utos
  mov   eax, [eax]
  test  eax, eax
  swap-stacks
  nz? do-when jmp   eax
;code-next (inline-blocker) (force-inline)
