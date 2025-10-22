;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; basick stack operations
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; data stack

code-swap-inline: (SP@)  ( -- sp )
  push  utos
  mov   utos, esp
;code-swap-next

code-swap-inline: (SP!)  ( n )
  mov   esp, utos
  pop   utos
;code-swap-next

code-swap-inline: (SP0)  ( -- n )
  push  utos
  mov   utos, [uadr+] uofs@ (sp0^) #
;code-swap-next

code-swap-inline: (SP0!)
  mov   esp, [uadr+] uofs@ (sp0^) #
  xor   utos, utos
;code-swap-next

code-swap-inline: (SP-START)
  push  utos
  mov   utos, [uadr+] uofs@ (sp-start^) #
;code-swap-next

code-swap-inline: (SP-END)
  push  utos
  mov   utos, [uadr+] uofs@ (sp-start^) #
  add   utos, [uadr+] uofs@ (dssize^) #
;code-swap-next

code-swap-inline: (SP-SIZE)  \ in bytes
  push  utos
  mov   utos, [uadr+] uofs@ (dssize^) #
;code-swap-next

code-swap-inline: DEPTH  ( -- stack-depth-before-this-call )
  push  utos
  mov   utos, [uadr+] uofs@ (sp0^) #
  sub   utos, esp
  sar   utos, # 2
  dec   utos
;code-swap-next

code-swap-inline: DUP  ( n -- n n )
  push  utos
;code-swap-next

code-swap-inline: 2DUP  ( n0 n1 -- n0 n1 n0 n1 )
  push  utos
  push  dword^ [esp+] # 4
;code-swap-next

code-swap-inline: DROP  ( n0 )
  pop   utos
;code-swap-next

code-swap-inline: N-DROP  ( count )
  [[code-type-ndrop]]
  test  utos, utos
  js    @@f
  lea   esp, [esp+] [utos*4]
@@:
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: SWAP  ( n0 n1 -- n1 n0 )
  \ xchg  [esp], utos  ;; this does automatic LOCK, avoid it
  pop   eax
  push  utos
  mov   utos, eax
;code-swap-next

code-swap-inline: 2SWAP  ( n0 n1 n2 n3 -- n2 n3 n0 n1 )
(* TOS: n3
n2<  n0<
n1   n3
n0   n2 TOS:n1
*)
  pop   eax
  pop   ecx
  pop   edx
  ;; EBX: n3
  ;; EAX: n2
  ;; ECX: n1
  ;; EDX: n0
  push  eax
  push  utos
  push  edx
  mov   utos, ecx
;code-swap-next

code-swap-inline: OVER  ( n0 n1 -- n0 n1 n0 )
  push  utos
  mov   utos, [esp+] # 4
;code-swap-next

code-swap-inline: 2OVER  ( n0 n1 n2 n3 -- n0 n1 n2 n3 n0 n1 )
  push  utos
  push  dword^ [esp+] # 4 3 *
  mov   utos, [esp+] # 4 3 *
;code-swap-next

;; sorry, but this is required sometimes (yes, i know that it is BAD)
code-swap-inline: PICK2  ( n0 n1 n2 -- n0 n1 n2 n0 )
  push  utos
  mov   utos, [esp+] # 2 4*
;code-swap-next


;; sorry, but this is required for the stupid benchmark
code-swap-inline: PICK3  ( n0 n1 n2 n3 -- n0 n1 n2 n3 n0 )
  push  utos
  mov   utos, [esp+] # 3 4*
;code-swap-next


code-swap-inline: TUCK2  ( a b c -- a a b c )
  pop   eax
  pop   edx
  ;; UTOS: c
  ;; EAX: b
  ;; EDX: a
  push  edx
  push  edx
  push  eax
;code-swap-next


code-swap-inline: ROT  ( n0 n1 n2 -- n1 n2 n0 )
  pop   eax
  pop   ecx
  ;; EBX: n2
  ;; EAX: n1
  ;; ECX: n0
  push  eax
  push  utos
  mov   utos, ecx
;code-swap-next

code-swap-inline: NROT  ( n0 n1 n2 -- n2 n0 n1 )
  pop   eax
  pop   ecx
  ;; EBX: n2
  ;; EAX: n1
  ;; ECX: n0
  push  utos
  push  ecx
  mov   utos, eax
;code-swap-next

;; SWAP DROP
;; written in forth now
\ code-swap-inline: NIP  ( n1 n2 -- n2 )
\   pop   eax
\ ;code-swap-next

;; SWAP OVER
;; DUP NROT
code-swap-inline: TUCK  ( n1 n2 -- n2 n1 n2 )
  pop   eax
  push  utos
  push  eax
;code-swap-next

;; OVER SWAP
code-swap-inline: UNDER  ( n0 n1 -- n0 n0 n1 )
  push  dword^ [esp]
;code-swap-next


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; return stack

code-swap-inline: (RP@)  ( -- rp )
  push  utos
  mov   utos, ebp
;code-swap-next (inline-blocker)

code-swap-inline: (RP!)  ( n )
  mov   ebp, utos
  pop   utos
;code-swap-next (inline-blocker) (force-inline)

code-swap-inline: (RP0)
  push  utos
  mov   utos, [uadr+] uofs@ (rp0^) #
;code-swap-next

code-swap-inline: (RP0!)
  mov   ebp, [uadr+] uofs@ (rp0^) #
;code-swap-next (inline-blocker) (force-inline)

code-swap-inline: (RP-START)
  push  utos
  mov   utos, [uadr+] uofs@ (rp-start^) #
;code-swap-next

code-swap-inline: (RP-END)
  push  utos
  mov   utos, [uadr+] uofs@ (rp-start^) #
  add   utos, [uadr+] uofs@ (rssize^) #
;code-swap-next

code-swap-inline: (RP-SIZE)  \ in bytes
  push  utos
  mov   utos, [uadr+] uofs@ (rssize^) #
;code-swap-next

code-swap-inline: >R  ( n -- | n )
  [[code-type-rpush]]
  lea   ebp, [ebp+] # -4
  mov   [ebp], utos
  [[code-type-finish]]
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R>  ( | n -- n )
  push  utos
  [[code-type-rpop]]
  mov   utos, [ebp]
  lea   ebp, [ebp+] # 4
;code-swap-next (force-inline)

code-swap-inline: R@  ( | n -- n | n )
  push  utos
  mov   utos, [ebp]
;code-swap-next (force-inline)

code-swap-inline: R!  ( n | n0 -- | n )
  mov   [ebp], utos
  pop   utos
;code-swap-next (force-inline)

(*
new: R0:+!
code-swap-inline: +R!  ( n | rn -- | rn+n )
  add   [ebp], utos
  pop   utos
;code-swap-next (force-inline)

new: R0:-!
code-swap-inline: -R!  ( n | rn -- | rn-n )
  sub   [ebp], utos
  pop   utos
;code-swap-next (force-inline)
*)


code-swap-inline: R0:@  ( | n -- n | n )
  push  utos
  mov   utos, [ebp]
;code-swap-next (force-inline)

code-swap-inline: R1:@  ( | n1 n0 -- n1 | n1 n0 )
  push  utos
  mov   utos, [ebp+] # 4
;code-swap-next (force-inline)

code-swap-inline: R2:@  ( | n2 n1 n0 -- n2 | n2 n1 n0 )
  push  utos
  mov   utos, [ebp+] # 2 4*
;code-swap-next (force-inline)

code-swap-inline: R3:@  ( | n3 n2 n1 n0 -- n3 | n3 n2 n1 n0 )
  push  utos
  mov   utos, [ebp+] # 3 4*
;code-swap-next (force-inline)

code-swap-inline: R4:@  ( | n4 n3 n2 n1 n0 -- n4 | n3 n2 n1 n0 )
  push  utos
  mov   utos, [ebp+] # 4 4*
;code-swap-next (force-inline)

code-swap-inline: R0:!  ( n | n0 -- | n )
  mov   [ebp], utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R1:!  ( n | n1 n0 -- | n n0 )
  mov   [ebp+] 4 #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R2:!  ( n | n2 n1 n0 -- | n n1 n0 )
  mov   [ebp+] 2 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R3:!  ( n | n3 n2 n1 n0 -- | n n2 n1 n0 )
  mov   [ebp+] 3 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R4:!  ( n | n4 n3 n2 n1 n0 -- | n n3 n2 n1 n0 )
  mov   [ebp+] 4 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R0:+!  ( n | rn -- | rn+n )
  add   [ebp], utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R0:-!  ( n | rn -- | rn-n )
  sub   [ebp], utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R1:+!  ( n | rn n0 -- | rn+n n0 )
  add   [ebp+] 1 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R1:-!  ( n | rn n0 -- | rn-n n0 )
  sub   [ebp+] 1 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R2:+!  ( n | rn n1 n0 -- | rn+n n1 n0 )
  add   [ebp+] 2 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R2:-!  ( n | rn n1 n0 -- | rn-n n1 n0 )
  sub   [ebp+] 2 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R3:+!  ( n | rn n2 n1 n0 -- | rn+n n2 n1 n0 )
  add   [ebp+] 3 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R3:-!  ( n | rn n2 n1 n0 -- | rn-n n2 n1 n0 )
  sub   [ebp+] 3 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R4:+!  ( n | rn n3 n2 n1 n0 -- | rn+n n3 n2 n1 n0 )
  add   [ebp+] 4 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R4:-!  ( n | rn n3 n2 n1 n0 -- | rn-n n3 n2 n1 n0 )
  sub   [ebp+] 4 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R0:1+!  ( | rn -- | rn+1 )
  inc   dword^ [ebp]
;code-swap-next (force-inline)

code-swap-inline: R0:1-!  ( | rn -- | rn-1 )
  dec   dword^ [ebp]
;code-swap-next (force-inline)

code-swap-inline: R1:1+!  ( | rn n0 -- | rn+1 n0 )
  inc   dword^ [ebp+] # 1 4*
;code-swap-next (force-inline)

code-swap-inline: R1:1-!  ( | rn n0 -- | rn-1 n0 )
  dec   dword^ [ebp+] # 1 4*
;code-swap-next (force-inline)

code-swap-inline: R2:1+!  ( | rn n1 n0 -- | rn+1 n1 n0 )
  inc   dword^ [ebp+] # 2 4*
;code-swap-next (force-inline)

code-swap-inline: R2:1-!  ( | rn n1 n0 -- | rn-1 n1 n0 )
  dec   dword^ [ebp+] # 2 4*
;code-swap-next (force-inline)

code-swap-inline: R3:1+!  ( | rn n2 n1 n0 -- | rn+1 n2 n1 n0 )
  inc   dword^ [ebp+] # 3 4*
;code-swap-next (force-inline)

code-swap-inline: R3:1-!  ( | rn n2 n1 n0 -- | rn-1 n2 n1 n0 )
  dec   dword^ [ebp+] # 3 4*
;code-swap-next (force-inline)

code-swap-inline: R4:1+!  ( | rn n3 n2 n1 n0 -- | rn+1 n3 n2 n1 n0 )
  inc   dword^ [ebp+] # 4 4*
;code-swap-next (force-inline)

code-swap-inline: R4:1-!  ( | rn n3 n2 n1 n0 -- | rn-1 n3 n2 n1 n0 )
  dec   dword^ [ebp+] # 4 4*
;code-swap-next (force-inline)


(*
code-swap-inline: R0@  ( | n -- n | n )
  push  utos
  mov   utos, [ebp]
;code-swap-next (force-inline)

code-swap-inline: R1@  ( | n1 n0 -- n1 | n1 n0 )
  push  utos
  mov   utos, [ebp+] # 4
;code-swap-next (force-inline)

code-swap-inline: R2@  ( | n2 n1 n0 -- n2 | n2 n1 n0 )
  push  utos
  mov   utos, [ebp+] # 2 4*
;code-swap-next (force-inline)

code-swap-inline: R3@  ( | n3 n2 n1 n0 -- n3 | n3 n2 n1 n0 )
  push  utos
  mov   utos, [ebp+] # 3 4*
;code-swap-next (force-inline)

code-swap-inline: R4@  ( | n4 n3 n2 n1 n0 -- n4 | n3 n2 n1 n0 )
  push  utos
  mov   utos, [ebp+] # 4 4*
;code-swap-next (force-inline)

code-swap-inline: R0!  ( n | n0 -- | n )
  mov   [ebp], utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R1!  ( n | n1 n0 -- | n n0 )
  mov   [ebp+] 4 #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R2!  ( n | n2 n1 n0 -- | n n1 n0 )
  mov   [ebp+] 2 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R3!  ( n | n3 n2 n1 n0 -- | n n2 n1 n0 )
  mov   [ebp+] 3 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: R4!  ( n | n4 n3 n2 n1 n0 -- | n n3 n2 n1 n0 )
  mov   [ebp+] 4 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: +R0!  ( n | rn -- | rn+n )
  add   [ebp], utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: -R0!  ( n | rn -- | rn-n )
  sub   [ebp], utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: +R1!  ( n | rn n0 -- | rn+n n0 )
  add   [ebp+] 1 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: -R1!  ( n | rn n0 -- | rn-n n0 )
  sub   [ebp+] 1 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: +R2!  ( n | rn n1 n0 -- | rn+n n1 n0 )
  add   [ebp+] 2 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: -R2!  ( n | rn n1 n0 -- | rn-n n1 n0 )
  sub   [ebp+] 2 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: +R3!  ( n | rn n2 n1 n0 -- | rn+n n2 n1 n0 )
  add   [ebp+] 3 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: -R3!  ( n | rn n2 n1 n0 -- | rn-n n2 n1 n0 )
  sub   [ebp+] 3 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: +R4!  ( n | rn n3 n2 n1 n0 -- | rn+n n3 n2 n1 n0 )
  add   [ebp+] 4 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: -R4!  ( n | rn n3 n2 n1 n0 -- | rn-n n3 n2 n1 n0 )
  sub   [ebp+] 4 4* #, utos
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: 1+R!  ( | rn -- | rn+1 )
  inc   dword^ [ebp]
;code-swap-next (force-inline)

code-swap-inline: 1-R!  ( | rn -- | rn-1 )
  dec   dword^ [ebp]
;code-swap-next (force-inline)

code-swap-inline: 1+R0!  ( | rn -- | rn+1 )
  inc   dword^ [ebp]
;code-swap-next (force-inline)

code-swap-inline: 1-R0!  ( | rn -- | rn-1 )
  dec   dword^ [ebp]
;code-swap-next (force-inline)

code-swap-inline: 1+R1!  ( | rn n0 -- | rn+1 n0 )
  inc   dword^ [ebp+] # 1 4*
;code-swap-next (force-inline)

code-swap-inline: 1-R1!  ( | rn n0 -- | rn-1 n0 )
  dec   dword^ [ebp+] # 1 4*
;code-swap-next (force-inline)

code-swap-inline: 1+R2!  ( | rn n1 n0 -- | rn+1 n1 n0 )
  inc   dword^ [ebp+] # 2 4*
;code-swap-next (force-inline)

code-swap-inline: 1-R2!  ( | rn n1 n0 -- | rn-1 n1 n0 )
  dec   dword^ [ebp+] # 2 4*
;code-swap-next (force-inline)

code-swap-inline: 1+R3!  ( | rn n2 n1 n0 -- | rn+1 n2 n1 n0 )
  inc   dword^ [ebp+] # 3 4*
;code-swap-next (force-inline)

code-swap-inline: 1-R3!  ( | rn n2 n1 n0 -- | rn-1 n2 n1 n0 )
  dec   dword^ [ebp+] # 3 4*
;code-swap-next (force-inline)

code-swap-inline: 1+R4!  ( | rn n3 n2 n1 n0 -- | rn+1 n3 n2 n1 n0 )
  inc   dword^ [ebp+] # 4 4*
;code-swap-next (force-inline)

code-swap-inline: 1-R4!  ( | rn n3 n2 n1 n0 -- | rn-1 n3 n2 n1 n0 )
  dec   dword^ [ebp+] # 4 4*
;code-swap-next (force-inline)
*)


code-swap-inline: 2>R  ( n0 n1 -- | n0 n1 )
  pop   eax   ;; n0; utos is n1
  lea   ebp, [ebp+] # -2 4*
  mov   [ebp], utos
  mov   [ebp+] 4 #, eax
  pop   utos
;code-swap-next (force-inline)

code-swap-inline: 2R>  ( | n0 n1 -- n0 n1 )
  push  utos
  mov   utos, [ebp]           ;; n1
  push  dword^ [ebp+] # 4 1 * ;; n0
  lea   ebp, [ebp+] # 2 4 *
;code-swap-next (force-inline)

code-swap-inline: 2R@  ( | n0 n1 -- n0 n1 | n0 n1 )
  push  utos
  mov   utos, [ebp]
  push  dword^ [ebp+] # 4 1 *
;code-swap-next (force-inline)

code-swap-inline: RDROP  ( | n0 -- )
  lea   ebp, [ebp+] # 1 4*
;code-swap-next (force-inline)

code-swap-inline: N-RDROP  ( count )
  [[code-type-nrdrop]]
  test  utos, utos
  js    @@f
  lea   ebp, [ebp+] [utos*4]
@@:
  pop   utos
;code-swap-next (force-inline)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; loop stack

code-naked-inline: LSP0!
  mov   eax, [uadr+] uofs@ (lp0^) #
  mov   [uadr+] uofs@ (lsp^) #, eax
;code-no-stacks

code-swap-inline: LSP@  ( -- sp )
  push  utos
  mov   utos, [uadr+] uofs@ (lsp^) #
;code-swap-next

code-swap-inline: LSP!  ( sp )
  mov   [uadr+] uofs@ (lsp^) #, utos
  pop   utos
;code-swap-next

code-swap-inline: LDEPTH  ( -- depth )
  push  utos
  mov   utos, [uadr+] uofs@ (lsp^) #
  sub   utos, [uadr+] uofs@ (lp0^) #
  sar   utos, # 2
;code-swap-next

code-swap-inline: >LOC  ( n )
  mov   eax, utos
  pop   utos
  mov   ecx, [uadr+] uofs@ (lsp^) #
  mov   [ecx], eax
  lea   ecx, [ecx+] # 4
  mov   [uadr+] uofs@ (lsp^) #, ecx
;code-swap-next

code-swap-inline: LOC>  ( -- n )
  push  utos
  mov   ecx, [uadr+] uofs@ (lsp^) #
  lea   ecx, [ecx+] # -4
  mov   utos, [ecx]
  mov   [uadr+] uofs@ (lsp^) #, ecx
;code-swap-next

code-naked-inline: LDROP  ( | n0 -- )
  sub   dword^ [uadr+] uofs@ (lsp^) #, # 4
;code-no-stacks (force-inline)

code-naked-inline: LPICK  ( idx -- n )
  shl   utos, # 2
  mov   ecx, [uadr+] uofs@ (lsp^) #
  sub   ecx, utos
  mov   utos, [ecx+] # -4
;code-no-stacks

code-swap-inline: LTOSS  ( value idx )
  shl   utos, # 2
  mov   eax, [esp]
  mov   ecx, [uadr+] uofs@ (lsp^) #
  sub   ecx, utos
  mov   [ecx+] -4 #, eax
  pop   eax
  pop   ebx
;code-swap-next

code-naked-inline: LALLOC  ( size -- addr )
  mov   eax, [uadr+] uofs@ (lsp^) #
  lea   utos, [eax+] [utos*4]
  mov   [uadr+] uofs@ (lsp^) #, utos
  mov   utos, eax
;code-no-stacks

code-swap-inline: LDEALLOC  ( n )
  shl   utos, # 2
  sub   dword^ [uadr+] uofs@ (lsp^) #, utos
  pop   utos
;code-swap-next

[[ tgt-build-base-binary ]] [IFNOT]
code-swap-inline: (LXALLOC)  ( size )
  mov   eax, [uadr+] uofs@ (lsp^) #
  lea   utos, [eax+] [utos*4]
  mov   [uadr+] uofs@ (lsp^) #, utos
  pop   utos
;code-swap-next

;; move n values from the data stack to the locals stack
code-swap-no-inline: (LOCMOVE)  ( n )
  cmp   utos, # 0
  jle   @@9
  mov   edx, [uadr+] uofs@ (lsp^) #
  lea   edx, [edx+] [utos*4]
  mov   [uadr+] uofs@ (lsp^) #, edx
@@1:
  pop   eax
  lea   edx, [edx+] # -4
  mov   [edx], eax
  dec   utos
  jnz   @@1
@@9:
  pop   utos
;code-swap-next

code-swap-inline: (LBP+@)  ( ofs -- value )
  mov   eax, [uadr+] uofs@ (lbp^) #
  lea   utos, [eax+] [utos*4]
  mov   utos, [utos]
;code-swap-next

code-swap-inline: (LBP+!)  ( value ofs )
  pop   eax
  mov   edx, [uadr+] uofs@ (lbp^) #
  lea   utos, [edx+] [utos*4]
  mov   [utos], eax
  pop   utos
;code-swap-next
[ENDIF]


;; for some reason it should be here! ;-)
{no-inline}
: NOOP ; (inline-blocker)

: NIP  ( n1 n2 -- n2 )  swap drop ;

: 2DROP 2 n-drop ; (force-inline)
: 3DROP 3 n-drop ; (force-inline)
: 4DROP 4 n-drop ; (force-inline)

: 2RDROP 2 n-rdrop ; (force-inline)
: 3RDROP 3 n-rdrop ; (force-inline)
: 4RDROP 4 n-rdrop ; (force-inline)
