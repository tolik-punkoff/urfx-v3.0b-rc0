;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; user area primitives
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


code-naked-no-inline: (IMG-ADDR?)  ( addr -- flag )
  mov   eax, utos
  xor   utos, utos
  cmp   eax, # ll@ (elf-base-start)
  jb    @@f
  cmp   eax, dword^ # ll@ (dp-addr)
  jae   @@f
  dec   utos
@@:
;code-no-stacks (private)


;; reset user area (i.e. switch to "system" task)
code-naked-inline: (USER-RESET)
  mov   uadr, # ll@ (mt-area-start)
;code-no-stacks (private)

;; are we in "system" task?
code-swap-inline: USER-SYSTEM?  ( -- flag )
  push  utos
  cmp   uadr, # ll@ (mt-area-start)
  setz  bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-naked-inline: >USER-AREA  ( ofs -- addr )
  lea   utos, [utos+] [uadr*1]
;code-no-stacks

code-naked-inline: USER-AREA@  ( ofs -- [addr+ofs] )
  mov   utos, [utos+] [uadr*1]
;code-no-stacks

code-swap-inline: USER-AREA!  ( value ofs )  \ [addr+ofs]=value
  pop   eax
  mov   [utos+] [uadr*1], eax
  pop   utos
;code-swap-next


code-swap-inline: (BUF#-END)  ( -- addr )
  push  utos
  mov   utos, [uadr+] # uofs@ (padsize^)
  add   utos, [uadr+] # uofs@ (pad^)
;code-swap-next


code-swap-inline: (GHTABLE)  ( -- addr )
  push  utos
  mov   utos, dword^ ll@ (ghtable-addr) #
;code-swap-next
