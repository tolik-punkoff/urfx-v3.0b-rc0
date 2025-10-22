;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; arithmetics
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; swap all dword bytes
code-naked-inline: BSWAP  ( u -- u )
  bswap utos
;code-no-stacks (no-stacks)

;; swap bytes of the low word
;; high word is untouched
code-naked-inline: WBSWAP  ( u -- u )
  xchg  bl, bh
;code-no-stacks (no-stacks)

;; swap high and low words of dword
code-naked-inline: SWAP-WORDS  ( u -- u )
  rol   utos, # 16
;code-no-stacks (no-stacks)

code-naked-inline: LO-BYTE  ( n -- c )
  movzx utos, bl
;code-no-stacks (no-stacks)

code-naked-inline: HI-BYTE  ( n -- c )
  movzx utos, bh
;code-no-stacks (no-stacks)

code-naked-inline: LO-WORD  ( n -- w )
  movzx utos, bx
;code-no-stacks (no-stacks)

code-naked-inline: HI-WORD  ( n -- w )
  shr   utos, # 16
;code-no-stacks (no-stacks)


;; return number of trailing 0-bits in u, starting at the least significant bit position
code-naked-inline: CTZ  ( u -- n )  \ count trailing 0 bits
  mov   eax, # 32
  bsf   utos, utos  ;; this sets Z flag on zero source
  cmovz utos, eax
;code-no-stacks (no-stacks)

;; return number of leading 0-bits in u, starting at the most significant bit position
code-naked-inline: CLZ  ( u -- n )  \ count leading 0 bits
  mov   eax, # 32 31 forth:xor
  bsr   utos, utos  ;; this sets Z flag on zero source
  cmovz utos, eax
  xor   utos, # 31
;code-no-stacks (no-stacks)

;; calculate the number of bits set to 1
code-naked-inline: POPCNT  ( u -- n )  \ calculate number of 1 bits
  popcnt utos, utos
;code-no-stacks (no-stacks)


;; WARNING! Succubus detects the following primitives
;; (mostly comparisons) by their exact code. i.e. if
;; you will change the primitives, tell Succubus about
;; their new code (in branch rewriter).
;; some primitives may look inefficient, but they are
;; written this way to let Succubus perform optimisations.

code-swap-inline: +  ( a b -- a+b )
  pop   eax
  add   utos, eax
;code-swap-next

\ a-b = a+(-b) = -b+a
code-swap-inline: -  ( a b -- a-b )
  \ fuckin' fuck86 has FUCKIN' SLOW xchg! wuta...
  pop   eax
  neg   utos
  add   utos, eax
;code-swap-next


code-swap-inline: =  ( a b -- bool )
  pop   eax
  xor   utos, eax
  sub   utos, # 1
  sbb   utos, utos
;code-swap-next

code-swap-inline: <>  ( a b -- bool )
  pop   eax
  xor   utos, eax
  neg   utos
  sbb   utos, utos
;code-swap-next

;; GCC seems to be ok with using SETcc, so do i
code-swap-inline: <  ( a b -- bool )
  pop   eax
  cmp   eax, utos
  setl  bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-swap-inline: <=  ( a b -- bool )
  pop   eax
  cmp   eax, utos
  setle bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-swap-inline: >  ( a b -- bool )
  pop   eax
  cmp   eax, utos
  setg  bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-swap-inline: >=  ( a b -- bool )
  pop   eax
  cmp   eax, utos
  setge bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-swap-inline: U<  ( a b -- bool )
  pop   eax
  cmp   eax, utos
  sbb   utos, utos
;code-swap-next

code-swap-inline: U>  ( a b -- bool )
  pop   eax
  cmp   utos, eax
  sbb   utos, utos
;code-swap-next

;; U> NOT
code-swap-inline: U<=  ( a b -- bool )
  pop   eax
  cmp   utos, eax
  sbb   utos, utos
  not   utos
;code-swap-next

;; U< NOT
code-swap-inline: U>=  ( a b -- bool )
  pop   eax
  cmp   eax, utos
  sbb   utos, utos
  not   utos
;code-swap-next

code-naked-inline: 0=  ( n -- !n )
  sub   utos, # 1
  sbb   utos, utos
;code-no-stacks (no-stacks)

code-naked-inline: 0<>  ( n -- !!n )
  neg   utos
  sbb   utos, utos
;code-no-stacks (no-stacks)

code-naked-inline: 0<  ( n -- n<0 )
  sar   utos, # 31
;code-no-stacks (no-stacks)

code-naked-inline: 0>  ( n -- n<0 )
  cmp   utos, # 0
  setg  bl
  movzx utos, bl
  neg   utos
;code-no-stacks (no-stacks)

code-naked-inline: 0<=  ( n -- n<0 )
  cmp   utos, # 0
  setle bl
  movzx utos, bl
  neg   utos
;code-no-stacks (no-stacks)

code-naked-inline: 0>=  ( n -- n<0 )
  sar   utos, # 31
  not   utos
;code-no-stacks (no-stacks)

;; same as 0=
code-naked-inline: NOT  ( n -- !n )
  sub   utos, # 1
  sbb   utos, utos
;code-no-stacks (no-stacks)

;; same as 0<>
code-naked-inline: >BOOL  ( n -- !n )
  neg   utos
  sbb   utos, utos
;code-no-stacks (no-stacks)

code-naked-inline: BITNOT  ( n -- ~n )
  not   utos
;code-no-stacks (no-stacks)

code-swap-inline: MASK?  ( n0 n1 -- n0&n1<>0 )
  pop   eax
  and   utos, eax
  neg   utos
  sbb   utos, utos
;code-swap-next

code-swap-inline: NOT-MASK?  ( n0 n1 -- n0&n1=0 )
  pop   eax
  and   utos, eax
  neg   utos
  sbb   utos, utos
  not   utos
;code-swap-next

code-swap-inline: ~MASK?  ( n0 n1 -- n0&~n1<>0 )
  pop   eax
  not   utos
  and   utos, eax
  neg   utos
  sbb   utos, utos
;code-swap-next

code-swap-inline: NOT-~MASK?  ( n0 n1 -- n0&~n1=0 )
  pop   eax
  not   utos
  and   utos, eax
  neg   utos
  sbb   utos, utos
  not   utos
;code-swap-next

code-swap-inline: AND  ( n0 n1 -- n0&n1 )
  pop   eax
  and   utos, eax
;code-swap-next

code-swap-inline: ~AND  ( n0 n1 -- n0&~n1 )
  pop   eax
  not   utos
  and   utos, eax
;code-swap-next

code-swap-inline: OR  ( n0 n1 -- n0|n1 )
  pop   eax
  or    utos, eax
;code-swap-next

code-swap-inline: XOR  ( n0 n1 -- n0^n1 )
  pop   eax
  xor   utos, eax
;code-swap-next


code-swap-inline: WITHIN  ( n a b -- n>=a&&n<b )
  pop   eax
  pop   ecx
  sub   utos, eax
  sub   ecx, eax
  sub   ecx, utos
  sbb   utos, utos
;code-swap-next

code-swap-inline: BOUNDS  ( u ua ub -- u>=ua&&u<=ub )
  pop   eax   ;; ua
  pop   edx   ;; u
  mov   ecx, utos
  ;; EDX: u
  ;; EAX: ua
  ;; ECX: ub
  xor   esi, esi
  mov   utos, # -1
  cmp   edx, eax
  cmovb utos, esi
  cmp   edx, ecx
  cmova utos, esi
;code-swap-next


;; check if `val` is equal to one of `count` items
code-swap-no-inline: ONE-OF  ( val ... count -- found? )
  mov   ecx, utos   ;; count
  xor   utos, utos  ;; found?
  cmp   ecx, # 0
  jle   @@9
  mov   eax, dword^ [esp+] [ecx*4]  ;; value
@@1:
  cmp   ecx, # 0
  jle   @@9
  dec   ecx
  pop   edx
  cmp   eax, edx
  jnz   @@1
  mov   utos, # -1
  ;; remove other values
  lea   esp, [esp+] [ecx*4]
@@9:
  pop   eax   ;; drop value
;code-swap-next


;; useful for array indexing
code-swap-inline: DB-NTH  ( count addr -- addr+count )
  pop   eax
  add   utos, eax
;code-swap-next

;; useful for array indexing
code-swap-inline: DW-NTH  ( count addr -- addr+count*2 )
  pop   eax
  lea   utos, [utos+] [eax*2]
;code-swap-next

;; useful for array indexing
code-swap-inline: DD-NTH  ( count addr -- addr+count*4 )
  pop   eax
  lea   utos, [utos+] [eax*4]
;code-swap-next


code-swap-inline: LAND  ( n0 n1 -- n0&&n1 )
  pop   eax
  neg   utos
  sbb   utos, utos
  neg   eax
  sbb   eax, eax
  and   utos, eax
;code-swap-next

code-swap-inline: LOR  ( n0 n1 -- n0||n1 )
  pop   eax
  or    utos, eax
  neg   utos
  sbb   utos, utos
;code-swap-next


code-naked-inline: BIT>MASK  ( n -- 1<<1 )
  mov   ecx, utos
  mov   utos, # 1
  shl   utos, cl
;code-no-stacks (no-stacks)

;; for all shifts, values greater than 31 are undefined
;; (acutally, only low 5 bits of the counter are used)
;; WARNING! DO NOT RELY ON THIS!
code-swap-inline: LSHIFT  ( n0 n1 -- n0<<n1 )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  shl   utos, cl
;code-swap-next

code-swap-inline: RSHIFT  ( n0 n1 -- n0>>n1 )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  shr   utos, cl
;code-swap-next

code-swap-inline: ARSHIFT  ( n0 n1 -- n0>>n1 )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  sar   utos, cl
;code-swap-next

code-swap-inline: ROL  ( n0 n1 -- n0-rol-n1 )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  rol   utos, cl
;code-swap-next

code-swap-inline: ROR  ( n0 n1 -- n0-ror-n1 )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  ror   utos, cl
;code-swap-next

code-swap-inline: ROL16  ( n0 n1 -- n0-rol-n1 )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  rol   bx, cl
;code-swap-next

code-swap-inline: ROR16  ( n0 n1 -- n0-ror-n1 )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  ror   bx, cl
;code-swap-next

code-swap-inline: ROL8  ( n0 n1 -- n0-rol-n1 )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  rol   bl, cl
;code-swap-next

code-swap-inline: ROR8  ( n0 n1 -- n0-ror-n1 )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  ror   bl, cl
;code-swap-next

;; power-of-2?
code-naked-inline: POT  ( u -- power-of-2 // -1 )
  ;; dup dup 1- and ?exit< false >?
  mov   edx, utos
  dec   utos
  and   utos, edx
  mov   utos, # -1
  z? do-when bsf utos, edx
;code-no-stacks (no-stacks)

code-naked-inline: SIGN  ( n -- -1/0/1 )
  mov   ecx, utos
  sar   utos, # 31
  cmp   ecx, # 0
  mov   edx, # 1
  cmovg utos, edx
;code-no-stacks (no-stacks)


;; avoid overflows
code-swap-inline: NCMP  ( n0 n1 -- -1/0/1 )
  pop   eax
  mov   edx, utos
  mov   ecx, # -1
  ;; EAX: n0
  ;; EDX: n1
  xor   utos, utos
  cmp   eax, edx
  cmovl utos, ecx
  mov   ecx, # 1
  cmp   eax, edx
  cmovg utos, ecx
;code-swap-next

;; avoid overflows
code-swap-inline: UCMP  ( u0 u1 -- -1/0/1 )
  pop   eax
  mov   ecx, utos
  ;; EAX: n0
  ;; EDX: n1
  xor   utos, utos
  cmp   eax, ecx
  sbb   utos, utos
  cmp   ecx, eax
  adc   utos, # 0
;code-swap-next


code-naked-inline: NEGATE  ( n -- -n )
  neg   utos
;code-no-stacks (no-stacks)

;; look ma, no jumps!
code-naked-inline: ABS  ( n -- |n| )
  mov   eax, utos
  sar   eax, # 31
  add   utos, eax
  xor   utos, eax
;code-no-stacks (no-stacks)


code-swap-inline: UMIN  ( u0 u1 -- umin )
  pop   eax
  cmp   eax, utos
  cmovc utos, eax
;code-swap-next

code-swap-inline: UMAX  ( u0 u1 -- umax )
  pop   eax
  cmp   utos, eax
  cmovc utos, eax
;code-swap-next

code-swap-inline: MIN  ( n0 n1 -- nmin )
  pop   eax
  cmp   utos, eax
  cmovg utos, eax
;code-swap-next

code-swap-inline: MAX  ( n0 n1 -- nmax )
  pop   eax
[[code-type-max]]
  cmp   utos, eax
  cmovl utos, eax
;code-swap-next

code-swap-inline: CLAMP  ( val lo hi -- val )
  pop   eax
  mov   ecx, utos
  pop   utos
  ;; TOS: val
  ;; EAX: lo
  ;; ECX: hi
  cmp   utos, eax
  cmovl utos, eax
  cmp   utos, ecx
  cmovg utos, ecx
;code-swap-next

code-swap-inline: UCLAMP  ( val lo hi -- val )
  pop   eax
  mov   ecx, utos
  pop   utos
  ;; TOS: val
  ;; EAX: lo
  ;; ECX: hi
  cmp   utos, eax
  cmovb utos, eax
  cmp   utos, ecx
  cmova utos, ecx
;code-swap-next


code-naked-inline: C>S  ( n-8-bit -- n )
  movsx utos, bl
;code-no-stacks (no-stacks)

code-naked-inline: C>U  ( u-8-bit -- u )
  movzx utos, bl
;code-no-stacks (no-stacks)

[[ tgt-build-base-binary ]] [IFNOT]
code-swap-inline: S>D  ( n -- dlo dhi )
  mov   eax, utos
  cdq
  mov   utos, edx
  push  eax
;code-swap-next

code-swap-inline: U>D  ( u -- udlo udhi )
  push  utos
  xor   utos, utos
;code-swap-next

code-swap-inline: D>S  ( dlo dhi -- dlo )
  pop   utos
;code-swap-next

code-naked-inline: W>S  ( n-16-bit -- n )
  movsx utos, bx
;code-no-stacks (no-stacks)

code-naked-inline: W>U  ( u-16-bit -- u )
  movzx utos, bx
;code-no-stacks (no-stacks)
[ENDIF]


code-swap-inline: *  ( n0 n1 -- n0*n1 )
  pop   eax
  imul  utos, eax
;code-swap-next

;; rounds toward negative infinity (like Oberon does)
code-swap-inline: /MOD  ( n0 n1 -- ndiv nmod )
  pop   eax
  cdq
  idiv  utos
  test  edx, edx
  jz    @@f
  xor   utos, edx
  jns   @@f
  dec   eax
  xor   utos, edx
  add   edx, utos
@@:
  mov   utos, edx
  push  eax
;code-swap-next (force-inline)

code-swap-inline-no-reg-jumps: /  ( n0 n1 -- n0/n1 )
  pop   eax
  [[code-type-idiv]]
  cdq
  idiv  utos
  test  edx, edx
  jz    @@f
  xor   utos, edx
  jns   @@f
  dec   eax
@@:
  mov   utos, eax
;code-swap-next (force-inline)

code-swap-inline: MOD  ( n0 n1 -- n0%n1 )
  pop   eax
  [[code-type-imod]]
  cdq
  idiv  utos
  test  edx, edx
  jz    @@f
  xor   utos, edx
  jns   @@f
  xor   utos, edx
  add   edx, utos
@@:
  mov   utos, edx
;code-swap-next (force-inline)

code-swap-inline: */  ( n0 n1 n2 -- n0*n1/n2 )
  pop   eax
  pop   ecx
  ;; TOS=n2
  ;; EAX=n1
  ;; ECX=n0
  imul  ecx
  idiv  utos
  test  edx, edx
  jz    @@f
  xor   utos, edx
  jns   @@f
  dec   eax
@@:
  mov   utos, eax
;code-swap-next (force-inline)

code-swap-inline: */MOD  ( n0 n1 n2 -- n0*n1/n2 n0*n1%n2 )
  pop   eax
  ;; TOS=n2
  ;; EAX=n1
  imul  dword^ [esp]
  idiv  utos
  test  edx, edx
  jz    @@f
  xor   utos, edx
  jns   @@f
  dec   eax
  xor   utos, edx
  add   edx, utos
@@:
  mov   [esp], eax
  mov   utos, edx
;code-swap-next (force-inline)

code-swap-inline: U*  ( u0 u1 -- n0*n1 )
  pop   eax
  mul   utos
  mov   utos, eax
;code-swap-next

code-swap-inline: U/  ( u0 u1 -- n0/n1 )
  pop   eax
  ;; TOS=n1
  ;; EAX=n0
  xor   edx, edx
  div   utos
  mov   utos, eax
;code-swap-next

code-swap-inline: UMOD  ( u0 u1 -- n0%n1 )
  pop   eax
  ;; TOS=n1
  ;; EAX=n0
  [[code-type-umod]]
  xor   edx, edx
  div   utos
  mov   utos, edx
;code-swap-next

code-swap-inline: U/MOD  ( u0 u1 -- u0/u1 u0%u1 )
  pop   eax
  ;; TOS=n1
  ;; EAX=n0
  xor   edx, edx
  div   utos
  mov   utos, edx
  push  eax
;code-swap-next

code-swap-inline: U*/  ( u0 u1 u2 -- u0*u1/u2 )
  pop   eax
  pop   ecx
  ;; TOS=n2
  ;; EAX=n1
  ;; EBX=n0
  mul   ecx
  div   utos
  mov   utos, eax
;code-swap-next

code-swap-inline: U*/MOD  ( u0 u1 u2 -- u0*u1/u2 u0*u1%u2 )
  pop   eax
  pop   ecx
  ;; TOS=n2
  ;; EAX=n1
  ;; EBX=n0
  mul   ecx
  div   utos
  mov   utos, edx
  push  eax
;code-swap-next


;; Succubus is able to properly optimise them after inlining,
;; so there is no reason to code them in asm.
: 1+  1 + ;
: 1-  1 - ;
: 2+  2 + ;
: 2-  2 - ;
: 4+  4 + ;
: 4-  4 - ;

: 2*  2 * ;
: 4*  4 * ;

: 2/  2 / ;
: 4/  4 / ;


: BETWEEN  ( n low high -- f )  over - nrot - u>= ;

(*
;; negative is right
code-swap-inline: LSH  ( n shift -- n<<shift-or-n>>shift )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  test  ecx, ecx
  js    # $ 6 +   ;; shift right; force near jump
  shl   utos, cl
  jmp   # $ 6 +   ;; force near jump
  neg   ecx
  shr   utos, cl
;code-swap-next

;; negative is right
code-swap-inline: ASH  ( n shift -- n<<shift-or-n>>shift )
  pop   eax
  mov   ecx, utos
  mov   utos, eax
  test  ecx, ecx
  js    # $ 6 +   ;; shift right; force near jump
  shl   utos, cl
  jmp   # $ 6 +   ;; force near jump
  neg   ecx
  sar   utos, cl
;code-swap-next
*)
