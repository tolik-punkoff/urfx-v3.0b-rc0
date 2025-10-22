;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; doers for DTC-SMALL
;; WARNING! do not load directly!
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; do-forth and others for DTC-SMALL

;; "<builds ... does>" words
;; call to this is put to CFA; we have PFA-4 on the stack
\ tcom:align-here-64
64 tcom:xalign
x86-label: do-does
x86-start
  pop   eax               ;; PFA-4 -- i.e. doer execution address
  swap-stacks
  push  utos
  swap-stacks
  mov   ecx, [eax+] # 3   ;; doer
  ;; move to PFA; we are right after CFA, use FFA CFA length
  movzx utos, byte^ [eax+] # -4 5 -     ;; CFA size (from FFA)
  lea   utos, [utos+] [eax*1+] # -4 5 - ;; move to PFA
  jmp   ecx
x86-end

\ tcom:align-here-64
64 tcom:xalign
x86-label: do-uservar
x86-start
  pop   eax
  swap-stacks
  push  utos
  swap-stacks
  movzx utos, byte^ [eax+] # -4 5 -     ;; CFA size (from FFA)
  mov   utos, dword^ [eax+] [utos*1+] # -4 5 - ;; load PFA
  lea   utos, [utos+] [uadr*1]
  ret
x86-end

\ tcom:align-here-64
64 tcom:xalign
x86-label: do-uservalue
x86-start
  pop   eax
  swap-stacks
  push  utos
  swap-stacks
  movzx utos, byte^ [eax+] # -4 5 -     ;; CFA size (from FFA)
  mov   utos, dword^ [eax+] [utos*1+] # -4 5 - ;; load PFA
  mov   utos, [utos+] [uadr*1]
  ret
x86-end

;; variable words: push PFA
\ tcom:align-here-64
64 tcom:xalign
x86-label: do-variable
x86-start
  swap-stacks
  push  utos
  swap-stacks
  pop   utos
  movzx eax, byte^ [utos+] # -4 5 -     ;; CFA size (from FFA)
  lea   utos, dword^ [eax+] [utos*1+] # -4 5 - ;; load PFA address
  ret
x86-end

;; constant words: push PFA contents
\ tcom:align-here-64
64 tcom:xalign
x86-label: do-constant
x86-start
  swap-stacks
  push  utos
  swap-stacks
  pop   utos
  movzx eax, byte^ [utos+] # -4 5 -     ;; CFA size (from FFA)
  mov   utos, dword^ [eax+] [utos*1+] # -4 5 - ;; load PFA
  ret
x86-end

;; alias words: execute CFA from PFA
\ tcom:align-here-64
64 tcom:xalign
x86-label: do-alias
x86-start
  pop   eax
  movzx ecx, byte^ [eax+] # -4 5 -      ;; CFA size (from FFA)
  jmp   dword^ [eax+] [ecx*1+] # -4 5 -  ;; load PFA
x86-end
