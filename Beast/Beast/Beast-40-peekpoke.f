;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; memory operations
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


code-swap-inline: HERE  ( -- addr )
  push  utos
  mov   utos, dword^ # ll@ (dp-addr)
;code-swap-next

code-swap-inline: (DPALLOT)  ( n )
  add   dword^ ll@ (dp-addr) #, utos
  pop   utos
;code-swap-next

code-swap-inline: (DP+!)  ( n )
  add   dword^ ll@ (dp-addr) #, utos
  pop   utos
;code-swap-next

code-swap-inline: (DP!)  ( n )
  mov   dword^ ll@ (dp-addr) #, utos
  pop   utos
;code-swap-next

;; alias for HERE, used to denote low-level DP manipulation
code-swap-inline: (DP@)  ( -- value )
  push  utos
  mov   utos, dword^ # ll@ (dp-addr)
;code-swap-next


code-swap-inline: HDR-HERE  ( -- addr )
  push  utos
  mov   utos, dword^ # ll@ (hdr-dp-addr)
;code-swap-next

code-swap-inline: (HDR-DP+!)  ( n )
  add   dword^ ll@ (hdr-dp-addr) #, utos
  pop   utos
;code-swap-next

code-swap-inline: (HDR-DP!)  ( n )
  mov   dword^ ll@ (hdr-dp-addr) #, utos
  pop   utos
;code-swap-next

;; alias for HDR-HERE, used to denote low-level HDR-DP manipulation
code-swap-inline: (HDR-DP@)  ( -- value )
  push  utos
  mov   utos, dword^ # ll@ (hdr-dp-addr)
;code-swap-next


code-swap-inline: AV-C!++  ( addr value -- addr+1 )  \ [addr]=value&$ff
  pop   eax
  mov   byte^ [eax], bl
  lea   utos, [eax+] # 1
;code-swap-next

code-swap-inline: AV-W!++  ( addr value -- addr+2 )  \ [addr]=value&$ffff
  pop   eax
  mov   word^ [eax], bx
  lea   utos, [eax+] # 2
;code-swap-next

code-swap-inline: AV-!++  ( addr value -- addr+4 )  \ [addr]=value
  pop   eax
  mov   [eax], utos
  lea   utos, [eax+] # 4
;code-swap-next

code-swap-inline: VA-C!++  ( value addr -- addr+1 )  \ [addr]=value&$ff
  pop   eax
  mov   byte^ [utos], al
  inc   utos
;code-swap-next

code-swap-inline: VA-W!++  ( value addr -- addr+2 )  \ [addr]=value&$ffff
  pop   eax
  mov   word^ [utos], ax
  lea   utos, [utos+] # 2
;code-swap-next

code-swap-inline: VA-!++  ( value addr -- addr+4 )  \ [addr]=value
  pop   eax
  mov   [utos], eax
  lea   utos, [utos+] # 4
;code-swap-next


code-swap-inline: C@++  ( addr -- addr+1 b^[addr] )
  mov   ecx, utos
  inc   utos
  push  utos
  movzx utos, byte^ [ecx]
;code-swap-next

code-swap-inline: C@--  ( addr -- addr+1 b^[addr] )
  mov   ecx, utos
  dec   utos
  push  utos
  movzx utos, byte^ [ecx]
;code-swap-next

code-swap-inline: W@++  ( addr -- addr+2 w^[addr] )
  mov   ecx, utos
  lea   utos, [utos+] # 2
  push  utos
  movzx utos, word^ [ecx]
;code-swap-next

code-swap-inline: W@--  ( addr -- addr+2 w^[addr] )
  mov   ecx, utos
  lea   utos, [utos+] # -2
  push  utos
  movzx utos, word^ [ecx]
;code-swap-next

code-swap-inline: @++  ( addr -- addr+4 [addr] )
  mov   ecx, utos
  lea   utos, [utos+] # 4
  push  utos
  mov   utos, [ecx]
;code-swap-next

code-swap-inline: @--  ( addr -- addr+4 [addr] )
  mov   ecx, utos
  lea   utos, [utos+] # -4
  push  utos
  mov   utos, [ecx]
;code-swap-next


code-naked-inline: @  ( addr -- [addr] )
  mov   utos, [utos]
;code-no-stacks (no-stacks)

code-swap-inline: !  ( value addr ) \ [addr]=value
  pop   eax
  mov   [utos], eax
  pop   utos
;code-swap-next


code-naked-inline: W@  ( addr -- [addr] )
  movzx utos, word^ [utos]
;code-no-stacks (no-stacks)

code-swap-inline: W!  ( value addr )  \ [addr]=value
  pop   eax
  mov   word^ [utos], ax
  pop   utos
;code-swap-next

code-naked-inline: C@  ( addr -- [addr] )
  movzx utos, byte^ [utos]
;code-no-stacks (no-stacks)

code-swap-inline: C!  ( value addr -- [addr]=value )
  pop   eax
  mov   byte^ [utos], al
  pop   utos
;code-swap-next

;; sane little-endian
code-swap-inline: 2@LE  ( addr -- [addr] [addr+4] )
  mov   eax, dword^ [utos]
  mov   utos, [utos+] # 4
  push  eax
;code-swap-next

;; sane little-endian
code-swap-inline: 2!LE  ( n0 n1 addr -- [addr]=n0 [addr+4]=n1 )
  pop   eax   ;; d-high
  pop   ecx   ;; d-low
  mov   [utos], ecx
  mov   [utos+] 4 #, eax
  pop   utos
;code-swap-next

;; ANS big-endian
code-swap-inline: 2@BE  ( addr -- [addr+4] [addr] )
  mov   eax, dword^ [utos+] # 4
  mov   utos, [utos]
  push  eax
;code-swap-next

;; ANS big-endian
code-swap-inline: 2!BE  ( n0 n1 addr -- [addr]=n1 [addr+4]=n0 )
  pop   eax   ;; d-high
  pop   ecx   ;; d-low
  mov   [utos], eax
  mov   [utos+] 4 #, ecx
  pop   utos
;code-swap-next


code-swap-inline: !0  ( addr )  \ [addr]=0
  mov   dword^ [utos], # 0
  pop   utos
;code-swap-next

code-swap-inline: !F  ( addr )  \ [addr]=0
  mov   dword^ [utos], # 0
  pop   utos
;code-swap-next

code-swap-inline: !T  ( addr )  \ [addr]=-1
  mov   dword^ [utos], # -1
  pop   utos
;code-swap-next

code-swap-inline: !1  ( addr )  \ [addr]=1
  mov   dword^ [utos], # 1
  pop   utos
;code-swap-next

code-swap-inline: W!0  ( addr )  \ [addr]=0
  mov   word^ [utos], # 0
  pop   utos
;code-swap-next

code-swap-inline: C!0  ( addr )  \ [addr]=0
  mov   byte^ [utos], # 0
  pop   utos
;code-swap-next

code-swap-inline: +!  ( value addr )  \ [addr]+=value
  pop   eax
  add   [utos], eax
  pop   utos
;code-swap-next

code-swap-inline: +W!  ( value addr )  \ w[addr]+=value
  pop   eax
  add   word^ [utos], ax
  pop   utos
;code-swap-next

code-swap-inline: +C!  ( value addr )  \ b[addr]+=value
  pop   eax
  add   byte^ [utos], al
  pop   utos
;code-swap-next

code-swap-inline: -!  ( value addr )  \ [addr]-=value
  pop   eax
  sub   [utos], eax
  pop   utos
;code-swap-next

code-swap-inline: -W!  ( value addr )  \ w[addr]-=value
  pop   eax
  sub   word^ [utos], ax
  pop   utos
;code-swap-next

code-swap-inline: -C!  ( value addr )  \ b[addr]-=value
  pop   eax
  sub   byte^ [utos], al
  pop   utos
;code-swap-next


code-swap-inline: 1+!  ( addr )  \ [addr]+=1
  inc   dword^ [utos]
  pop   utos
;code-swap-next

code-swap-inline: 1+W!  ( addr )  \ w[addr]+=1
  inc   word^ [utos]
  pop   utos
;code-swap-next

code-swap-inline: 1+C!  ( addr )  \ b[addr]+=1
  inc   byte^ [utos]
  pop   utos
;code-swap-next

code-swap-inline: 1-!  ( addr )  \ [addr]-=1
  dec   dword^ [utos]
  pop   utos
;code-swap-next

code-swap-inline: 1-W!  ( addr )  \ w[addr]-=1
  dec   word^ [utos]
  pop   utos
;code-swap-next

code-swap-inline: 1-C!  ( addr )  \ b[addr]-=1
  dec   byte^ [utos]
  pop   utos
;code-swap-next

code-swap-inline: 2+!  ( addr )  \ [addr]+=2
  add   dword^ [utos], # 2
  pop   utos
;code-swap-next

code-swap-inline: 2-!  ( addr )  \ [addr]-=2
  sub   dword^ [utos], # 2
  pop   utos
;code-swap-next

code-swap-inline: 4+!  ( addr )  \ [addr]+=4
  add   dword^ [utos], # 4
  pop   utos
;code-swap-next

code-swap-inline: 4-!  ( addr )  \ [addr]-=4
  sub   dword^ [utos], # 4
  pop   utos
;code-swap-next

code-swap-inline: 8+!  ( addr )  \ [addr]+=8
  add   dword^ [utos], # 8
  pop   utos
;code-swap-next

code-swap-inline: 8-!  ( addr )  \ [addr]-=8
  sub   dword^ [utos], # 8
  pop   utos
;code-swap-next


code-swap-inline: OR!  ( value addr )  \ [addr]|=value
  pop   eax
  or    [utos], eax
  pop   utos
;code-swap-next

code-swap-inline: XOR!  ( value addr )  \ [addr]^=value
  pop   eax
  xor   [utos], eax
  pop   utos
;code-swap-next

code-swap-inline: AND!  ( value addr )  \ [addr]^=value
  pop   eax
  and   [utos], eax
  pop   utos
;code-swap-next

code-swap-inline: ~AND!  ( value addr )  \ [addr]^=~value
  pop   eax
  not   eax
  and   [utos], eax
  pop   utos
;code-swap-next


code-naked-no-inline: CMOVE  ( source dest count )
  cmp   utos, # 0
  jle   @@9
  mov   ecx, utos
  push  edi
  mov   edi, [usp]      ;; dest
  mov   esi, [usp+] # 4 ;; src
  cmp   esi, edi
  jz    @@9
  rep   movsb
  pop   edi
@@9:
  3 u-ndrop
;code-next

;; can be used to make some room
;; moves from the last byte to the first one
code-naked-no-inline: CMOVE>  ( source dest count )
  cmp   utos, # 0
  jle   @@9
  push  edi
  mov   edi, [usp]      ;; dest
  mov   esi, [usp+] # 4 ;; src
  mov   ecx, utos
  ;; move pointers
  lea   esi, [esi+] [ecx*1+] # -1
  lea   edi, [edi+] [ecx*1+] # -1
  cmp   esi, edi
  jz    @@9
  std
  rep   movsb
  cld
  pop   edi
@@9:
  3 u-ndrop
;code-next

;; uses CMOVE or CMOVE> (i.e. works like libc `memmove`)
;; negative length does nothing (i.e. you cannot MOVE more that 2GB of data)
code-naked-no-inline: MOVE  ( from to len )
  cmp   utos, # 0
  jle   @@9
  push  edi
  mov   ecx, utos
  mov   edi, [usp]      ;; dest
  mov   esi, [usp+] # 4 ;; src
  cmp   esi, edi
  jz    @@6
  j?u>  @@3
  ;; esi < edi
  mov   eax, edi
  sub   eax, esi
  cmp   eax, ecx
  jge   @@3
  ;; backwards
  std
  lea   esi, [esi+] [ecx*1+] # -1
  lea   edi, [edi+] [ecx*1+] # -1
@@3:
  rep   movsb
  cld
@@6:
  pop   edi
@@9:
  3 u-ndrop
;code-next

code-naked-no-inline: FILL  ( addr count byte )
  push  edi
  mov   eax, utos
  mov   ecx, [usp]
  cmp   ecx, # 0
  jle   @@9
  mov   edi, [usp+] # 4
  rep   stosb
@@9:
  pop   edi
  3 u-ndrop
;code-next

code-naked-no-inline: FILL32  ( addr dd-count u32 )
  push  edi
  mov   eax, utos
  mov   ecx, [usp]
  cmp   ecx, # 0
  jle   @@9
  mov   edi, [usp+] # 4
  rep   stosd
@@9:
  pop   edi
  3 u-ndrop
;code-next

code-swap-inline: IDCOUNT  ( addr -- addr+1 [addr]&0x7f )
  inc   utos
  push  utos
  movzx utos, byte^ [utos+] # -1
  and   utos, # $7F
;code-swap-next

code-swap-inline: COUNT  ( addr -- addr+4 [addr] )
  add   utos, # 4
  push  utos
  mov   utos, [utos+] # -4
;code-swap-next

;; length of asciiz string
code-naked-no-inline: ZCOUNT  ( addr -- addr count )
  upush utos
  cmp   byte^ [utos], # 0
  jz    @@f
  push  edi
  mov   edi, utos
  xor   eax, eax
  \ mov   utos, # -2
  \ mov   ecx, # -1
  mov   ecx, eax
  dec   ecx
  \
  mov   utos, ecx
  dec   utos
  \
  repnz scasb
  sub   utos, ecx
  pop   edi
  beast-nextjmp
@@:
  xor   utos, utos
;code-next

[[ tgt-build-base-binary ]] [IFNOT]
;; length of asciiz string
code-naked-no-inline: ZCOUNT-MAX  ( addr max-size -- addr count )
  cmp   utos, # 0
  jle   @@9
  mov   edx, [usp]
  cmp   byte^ [edx], # 0
  jz    @@9
  push  edi
  mov   ecx, utos
  mov   edi, edx
  inc   edx
  xor   eax, eax
  repnz scasb
  sub   edi, edx
  mov   utos, edi
  pop   edi
  beast-nextjmp
@@9:
  xor   utos, utos
;code-next
[ENDIF]


code-swap-inline: UNDER+  ( n0 n1 n2 -- n0+n2 n1 )
  pop   eax
  add   [esp], utos
  mov   utos, eax
;code-swap-next

code-swap-inline: UNDER-  ( n0 n1 n2 -- n0-n2 n1 )
  pop   eax
  sub   [esp], utos
  mov   utos, eax
;code-swap-next


:  ,  ( value )  (dp@) va-!++ (dp!) ;
: W,  ( value )  (dp@) va-w!++ (dp!) ;
: C,  ( value )  (dp@) va-c!++ (dp!) ;

:   HDR,  ( value )  (hdr-dp@) va-!++ (hdr-dp!) ;
: HDR-W,  ( value )  (hdr-dp@) va-w!++ (hdr-dp!) ;
: HDR-C,  ( value )  (hdr-dp@) va-c!++ (hdr-dp!) ;
