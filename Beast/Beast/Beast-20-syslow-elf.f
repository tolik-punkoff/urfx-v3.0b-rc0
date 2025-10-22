;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level os-specific GNU/Linux code
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


code-naked-no-inline: (NBYE)  ( code )
  mov   eax, # 1  ;; exit
  sys-call
;code-next (noreturn)

code-naked-no-inline: (BYE)
  mov   eax, # 1  ;; exit
  xor   ebx, ebx
  sys-call
;code-no-next (noreturn)


module RAW-EMIT
<disable-hash>

0 variable CR-CRLF?  ;; automatically print #13 after #10?
0 variable LASTCR?

code-naked-no-inline: EMIT  ( ch )
  xor   eax, eax
  cmp   bl, # 10
  z? do-when dec eax
  mov   dword^ tgt-['pfa] raw-emit:lastcr? #, eax
  mov   edx, # 1  ;; length
  cmp   bl, # 10
  jz    @@f
  cmp   dword^ tgt-['pfa] raw-emit:cr-crlf? #, # 0
  jz    @@f
  inc   edx
  mov   bh, # 13
@@:
  push  utos      ;; we will write from here
  mov   eax, # 4  ;; write
  mov   ebx, # 1  ;; stdout
  mov   ecx, esp  ;; address
  sys-call
  add   esp, # 4
  upop  utos
;code-next

code-naked-no-inline: TYPE  ( addr count )
  cmp   utos, # 0
  jle   @@9
  mov   edx, utos ;; length
  upop  ecx       ;; address
  ;; check if the last char is $0A
  xor   eax, eax
  cmp   byte^ [ecx+] [edx*1+] -1 #, # 10
  z? do-when dec eax
  mov   dword^ tgt-['pfa] raw-emit:lastcr? #, eax
  cmp   dword^ tgt-['pfa] raw-emit:cr-crlf? #, # 0
  jnz   @@3
  ;; do it
  mov   eax, # 4  ;; write
  mov   ebx, # 1  ;; stdout
  sys-call
  upop  utos
  beast-nextjmp

@@3:
  ;; ECX: address
  ;; EDX: length
  push  edi
  mov   edi, ecx
  mov   ecx, edx
@@4:
  ;; EDI: address
  ;; ECX: length
  mov   esi, edi
  mov   edx, ecx
  mov   eax, # 10
  repnz scasb
  jnz   @@7

  push  edx
  push  ecx
  mov   ecx, esi  ;; address
  mov   edx, edi
  sub   edx, esi  ;; length
  mov   eax, # 4  ;; write
  mov   ebx, # 1  ;; stdout
  sys-call

  push  # $0d     ;; we will write from here
  mov   eax, # 4  ;; write
  mov   ebx, # 1  ;; stdout
  mov   ecx, esp  ;; address
  mov   edx, # 1  ;; length
  sys-call
  add   esp, # 4

  pop   ecx
  pop   edx
  test  ecx, ecx
  jz    @@5
  jmp   @@4

@@7:
  mov   ecx, esi
  mov   eax, # 4  ;; write
  mov   ebx, # 1  ;; stdout
  sys-call
@@5:
  pop   edi
  upop  utos
  beast-nextjmp

@@9:
  2 u-ndrop
;code-next

code-swap-no-inline: ENDCR?  ( -- flag )
  push  utos
  mov   utos, dword^ tgt-['pfa] raw-emit:lastcr? #
;code-swap-next

code-swap-no-inline: ENDCR!  ( flag )
  ;; 0<>
  neg   utos
  sbb   utos, utos
  mov   dword^ tgt-['pfa] raw-emit:lastcr? #, utos
  pop   utos
;code-swap-next

code-naked-no-inline: ENDCR
  cmp   dword^ tgt-['pfa] raw-emit:lastcr? #, # 0
  jnz   @@f
  ;; (raw-cr)
  push  ebp
  push  utos
  push  # $0d0a   ;; we will write from here
  mov   eax, # 4  ;; write
  mov   ebx, # 1  ;; stdout
  mov   ecx, esp  ;; address
  mov   edx, # 1  ;; length
  cmp   dword^ tgt-['pfa] raw-emit:cr-crlf? #, # 0
  nz? do-when inc edx
  sys-call
  add   esp, # 4
  pop   utos
  pop   ebp
  mov   dword^ tgt-['pfa] raw-emit:lastcr? #, # -1
@@:
;code-next

;; returns -1 on EOF, or [0..255]
code-naked-no-inline: GETCH  ( -- ch )
  upush utos
  push  edi
  xor   eax, eax
  push  eax
@@1:
  mov   eax, # 3  ;; read
  mov   ebx, # 0  ;; stdin
  mov   ecx, esp  ;; address
  mov   edx, # 1  ;; length
  sys-call
  cmp   eax, # -4 ;; EINTR
  jz    @@1
  pop   utos      ;; read char
  pop   edi
  cmp   eax, # 1
  mov   edx, # -1
  cmovnz utos, edx
  ;; fix "lastcr?" (because why not?)
  xor   eax, eax
  cmp   utos, # 10
  z? do-when dec eax
  mov   dword^ tgt-['pfa] raw-emit:lastcr? #, eax
;code-next


end-module RAW-EMIT
