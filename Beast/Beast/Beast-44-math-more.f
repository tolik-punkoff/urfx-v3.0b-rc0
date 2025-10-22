;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; more arithmetics (doubles, additional operations, hashing)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(*
;; negative is right
: LSH  ( n shift -- n<<shift-or-n>>shift )
  dup -?< negate dup 31 u> ?< 2drop 0 || rshift >?
  || dup 31 u> ?< 2drop 0 || lshift >? >? ;

;; negative is right
: ASH  ( n shift -- n<<shift-or-n>>shift )
  dup -?< negate dup 31 u> ?< drop -?< -1 || 0 >? || arshift >?
  || dup 31 u> ?< 2drop 0 || lshift >? >? ;
*)


[[ tgt-build-base-binary ]] [IFNOT]

;; rounds toward zero
code-swap-inline: SM/REM  ( d n -- ndiv nmod )
  pop   edx
  pop   eax
  idiv  utos
  mov   utos, edx
  push  eax
;code-swap-next

;; rounds toward negative infinity (like Oberon does)
code-swap-inline: FM/MOD  ( d n -- ndiv nmod )
  pop   edx
  pop   eax
  idiv  utos
  test  edx, edx
  jz    @@f
  mov   ecx, edx
  xor   ecx, utos
  jns   @@f
  dec   eax
  add   edx, utos
@@:
  mov   utos, edx
  push  eax
;code-swap-next

;; rounds toward zero
code-swap-inline: UM/MOD  ( ud u -- udiv umod )
  pop   edx
  pop   eax
  div   utos
  mov   utos, edx
  push  eax
;code-swap-next


;; "symmetrical"
code-swap-inline: Y/  ( n0 n1 -- n0/n1 )
  pop   eax
  cdq
  idiv  utos
  mov   utos, eax
;code-swap-next

;; "symmetrical"
code-swap-inline: YMOD  ( n0 n1 -- n0%n1 )
  pop   eax
  cdq
  idiv  utos
  mov   utos, edx
;code-swap-next

;; "symmetrical"
code-swap-inline: Y/MOD  ( n0 n1 -- n0/n1 n0%n1 )
  pop   eax
  ;; TOS=n1
  ;; EAX=n0
  cdq
  idiv  utos
  mov   utos, edx
  push  eax
;code-swap-next

;; "symmetrical"
code-swap-inline: Y*/  ( n0 n1 n2 -- n0*n1/n2 )
  pop   eax
  pop   ecx
  ;; TOS=n2
  ;; EAX=n1
  ;; EBX=n0
  imul  ecx
  idiv  utos
  mov   utos, eax
;code-swap-next

;; "symmetrical"
code-swap-inline: Y*/MOD  ( n0 n1 n2 -- n0*n1/n2 n0*n1%n2 )
  pop   eax
  pop   ecx
  ;; TOS=n2
  ;; EAX=n1
  ;; EBX=n0
  imul  ecx
  idiv  utos
  mov   utos, edx
  push  eax
;code-swap-next


;; return double result
code-swap-inline: M*  ( n0 n1 -- d )
  pop   eax
  imul  ebx
  mov   utos, edx
  push  eax
;code-swap-next

;; return double result
code-swap-inline: UM*  ( u0 u1 -- du )
  pop   eax
  mul   ebx
  mov   utos, edx
  push  eax
;code-swap-next

code-swap-inline: UM/  ( ud1 u1 -- ures )
  pop   edx
  pop   eax
  div   utos
  mov   utos, eax
;code-swap-next

code-swap-inline: UMMOD  ( ud1 u1 -- umod )
  pop   edx
  pop   eax
  div   utos
  mov   utos, edx
;code-swap-next

code-swap-inline: M/MOD  ( d1 n1 -- nres nmod )
  pop   edx
  pop   eax
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
;code-swap-next

code-swap-inline: M/  ( d1 n1 -- nres )
  pop   edx
  pop   eax
  idiv  utos
  test  edx, edx
  jz    @@f
  xor   utos, edx
  jns   @@f
  dec   eax
@@:
  mov   utos, eax
;code-swap-next

code-swap-inline: MMOD  ( d1 n1 -- nmod )
  pop   edx
  pop   eax
  idiv  utos
  test  edx, edx
  jz    @@f
  xor   utos, edx
  jns   @@f
  xor   utos, edx
  add   edx, utos
@@:
  mov   utos, edx
;code-swap-next

;; symmetric
code-swap-inline: YM/MOD  ( d1 n1 -- nres nmod )
  pop   edx
  pop   eax
  idiv  utos
  mov   utos, edx
  push  eax
;code-swap-next

;; symmetric
code-swap-inline: YM/  ( d1 n1 -- nres )
  pop   edx
  pop   eax
  idiv  utos
  mov   utos, eax
;code-swap-next

;; symmetric
code-swap-inline: YMMOD  ( d1 n1 -- nmod )
  pop   edx
  pop   eax
  idiv  utos
  mov   utos, edx
;code-swap-next


code-swap-inline: DABS  ( dlo dhi )
  test  utos, utos
  jns   @@f
  not   utos
  pop   eax
  not   eax
  add   eax, # 1
  adc   utos, # 0
  push  eax
@@:
  nop   ;; this is to stop inliner from removing "push eax"
;code-swap-next

code-swap-inline: DNEGATE  ( dlo dhi -- dlo dhi )
  not   utos
  pop   eax
  not   eax
  add   eax, # 1
  adc   utos, # 0
  push  eax
;code-swap-next

code-swap-inline: D2*  ( d -- d*2 )
  pop   eax
  shl   eax
  rcl   utos
  push  eax
;code-swap-next

code-swap-inline: D2/  ( d -- d/2 )
  pop   eax
  sar   utos
  rcr   eax
  push  eax
;code-swap-next

code-swap-inline: D2U/  ( d -- d/2 )
  pop   eax
  shr   utos
  rcr   eax
  push  eax
;code-swap-next

code-swap-inline: D+  ( d0l d0h d1l d1h -- dl dh )
  pop   eax
  pop   ecx
  pop   edx
  add   edx, eax
  adc   utos, ecx
  push  edx
;code-swap-next

: D- ( d0 d1 -- d0-d1 )  dnegate d+ ;

code-swap-inline: D0<  ( d -- flag )
  pop   eax
  test  utos, utos
  sets  bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-swap-inline: D0>=  ( d -- flag )
  pop   eax
  test  utos, utos
  setns bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-swap-inline: D0=  ( d -- flag )
  pop   eax
  or    utos, eax
  setz  bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-swap-inline: D<  ( d1 d2 -- flag )
  pop   eax
  pop   edx
  pop   ecx
  sub   ecx, eax
  sbb   edx, ebx
  setl  bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-swap-inline: D>  ( d1 d2 -- flag )
  pop   eax
  pop   edx
  pop   ecx
  sub   eax, ecx
  sbb   ebx, edx
  setl  bl
  movzx utos, bl
  neg   utos
;code-swap-next

code-swap-inline: D=  ( d1 d2 -- flag )
  pop   eax
  pop   edx
  pop   ecx
  xor   ecx, eax
  xor   utos, edx
  or    utos, ecx
  setz  bl
  movzx utos, bl
  neg   utos
;code-swap-next

;; the only thing we need to print double (64-bit) numbers
code-swap-no-inline: UDS/MOD  ( ud1 u1 -- ud2 u2 )
  pop   eax
  pop   ecx
  ;; EDI=u1
  ;; EAX=ud1-high
  ;; EBX=ud1-low
  xor   edx, edx
  div   utos
  \ fuckin' fuck86 has FUCKIN' SLOW xchg! wuta...
  xchg  eax, ecx
  div   utos
  push  eax
  push  ecx
  mov   utos, edx
;code-swap-next

code-swap-no-inline: UD*UD  ( ud0lo ud0hi ud1lo ud1hi -- ud2lo ud2hi )
  push  utos
  pop   ecx
  pop   ebx
  pop   edx
  pop   eax
  imul  ecx, eax
  imul  edx, ebx
  add   ecx, edx
  mul   ebx
  add   ecx, edx
  push  eax
  mov   utos, ecx
;code-swap-next

code-naked-no-inline: UDS*  ( ud1 u --> ud2 )
  push  edi
  mov   edi, utos
  upop  ebx
  upop  ecx
  mov   eax, ecx
  mul   edi
  upush edx
  mov   ecx, eax
  mov   eax, ebx
  mul   edi
  upop  edx
  add   eax, edx
  upush ecx
  mov   utos, eax
  pop   edi
;code-next


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 32-bit integer hash
;; http://burtleburtle.net/bob/hash/integer.html
;;
;; full avalance:
;; uint32_t U32HASH (uint32_t a) {
;;   a = (a+0x7ed55d16) + (a<<12);
;;   a = (a^0xc761c23c) ^ (a>>19);
;;   a = (a+0x165667b1) + (a<<5);
;;   a = (a+0xd3a2646c) ^ (a<<9);
;;   a = (a+0xfd7046c5) + (a<<3);
;;   a = (a^0xb55a4f09) ^ (a>>16);
;;   return a;
;; }
;;
;; half avalance:
;; uint32_t U32HASH/HALF (uint32_t a) {
;;   a = (a+0x479ab41d) + (a<<8);
;;   a = (a^0xe4aa10ce) ^ (a>>5);
;;   a = (a+0x9942f0a6) - (a<<14);
;;   a = (a^0x5aedd67d) ^ (a>>3);
;;   a = (a+0x17bea992) + (a<<7);
;;   return a;
;; }
(*
code: U32HASH-SLOW  ( u -- u )
  ;; a = (a+0x7ed55d16)+(a<<12);
  mov   eax, utos
  add   utos, # $7ed55d16
  shl   eax, # 12
  add   utos, eax
  ;; a = (a^0xc761c23c)^(a>>19);
  mov   eax, utos
  xor   utos, # $c761c23c
  shr   eax, # 19
  xor   utos, eax
  ;; a = (a+0x165667b1)+(a<<5);
  mov   eax, utos
  add   utos, # $165667b1
  shl   eax, # 5
  add   utos, eax
  ;; a = (a+0xd3a2646c)^(a<<9);
  mov   eax, utos
  add   utos, # $d3a2646c
  shl   eax, # 9
  xor   utos, eax
  ;; a = (a+0xfd7046c5)+(a<<3);
  mov   eax, utos
  add   utos, # $fd7046c5
  shl   eax, # 3
  add   utos, eax
  ;; a = (a^0xb55a4f09)^(a>>16);
  mov   eax, utos
  xor   utos, # $b55a4f09
  shr   eax, # 16
  xor   utos, eax
;code (no-stacks)
*)

;; very slightly faster
code-naked-no-inline: U32HASH  ( u -- u )
  mov   eax, utos
  mov   edx, eax
  shl   edx, # 12
  lea   eax, [edx+] [eax*1+] # $7ed55d16
  mov   edx, eax
  xor   eax, # $c761c23c
  shr   edx, # 19
  xor   eax, edx
  mov   edx, eax
  shl   edx, # 5
  add   edx, eax
  lea   eax, [edx+] # $165667b1
  shl   eax, # 9
  mov   ecx, eax
  lea   eax, [edx+] # -$160733e3
  xor   eax, ecx
  lea   edx, [eax+] [eax*8+] # -$28fb93b
  mov   eax, edx
  xor   edx, # $b55a4f09
  shr   eax, # 16
  xor   eax, edx
  mov   utos, eax
;code-no-stacks (no-stacks)

(*
code-naked: U32HASH/HALF-SLOW  ( u -- u )
  ;; a = (a+0x479ab41d) + (a<<8);
  mov   eax, utos
  add   utos, # $479ab41d
  shl   eax, # 8
  add   utos, eax
  ;; a = (a^0xe4aa10ce) ^ (a>>5);
  mov   eax, utos
  xor   utos, # $e4aa10ce
  shr   eax, # 5
  xor   utos, eax
  ;; a = (a+0x9942f0a6) - (a<<14);
  mov   eax, utos
  add   utos, # $9942f0a6
  shl   eax, # 14
  sub   utos, eax
  ;; a = (a^0x5aedd67d) ^ (a>>3);
  mov   eax, utos
  xor   utos, # $5aedd67d
  shr   eax, # 3
  xor   utos, eax
  ;; a = (a+0x17bea992) + (a<<7);
  mov   eax, utos
  add   utos, # $17bea992
  shl   eax, # 7
  add   utos, eax
;code-no-stacks (no-stacks)
*)

;; very slightly faster
code-naked-no-inline: U32HASH/HALF  ( u -- u )
  mov   eax, utos
  mov   edx, eax
  shl   edx, # 8
  lea   edx, [edx+] [eax*1+] # $479ab41d
  mov   eax, edx
  xor   edx, # $e4aa10ce
  shr   eax, # 5
  xor   eax, edx
  mov   edx, eax
  sub   eax, # $66bd0f5a
  shl   edx, # 14
  sub   eax, edx
  mov   edx, eax
  xor   eax, # $5aedd67d
  shr   edx, # 3
  xor   eax, edx
  mov   edx, eax
  shl   edx, # 7
  lea   utos, [eax+] [edx*1+] # $17bea992
;code-no-stacks (no-stacks)


;; fold 32-bit hash to 16-bit hash
code-naked-inline: UHASH32>16  ( u32hash -- u16hash )
  mov   eax, utos
  shr   eax, # 16
  sub   utos, eax
  movzx utos, bx
;code-no-stacks (no-stacks)

code-naked-inline: UHASH16>8  ( u16hash -- u8hash )
  sub   bl, bh
  movzx utos, bl
;code-no-stacks (no-stacks)

code-naked-inline: UHASH32>8  ( u32hash -- u8hash )
  mov   eax, utos
  shr   eax, # 16
  sub   utos, eax
  sub   bl, bh
  movzx utos, bl
;code-no-stacks (no-stacks)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; this is used in BDB

;; compare two double numbers stored as little-endian.
;; args are number addresses.
code-swap-no-inline: D2UCMP  ( udbl0^ udbl1^ -- -1//0//1 )
  pop   ecx
  ;; EDX: dbl0^
  ;; TOS: dbl1^
  ;; compare high dword
  mov   eax, [ecx+] # 4
  cmp   eax, [utos+] # 4
  jb    @@2
  ja    @@4
  ;; equal, compare low dword
  mov   eax, [ecx]
  cmp   eax, [utos]
  jb    @@2
  ja    @@4
  ;; equal
  xor   utos, utos
  jmp   @@9
@@2: ;; lesser
  mov   utos, # -1
  jmp   @@9
@@4: ;; higher
  mov   utos, # 1
@@9:
;code-swap-next


: M+  ( d1|ud1 n -- d2|ud2 )  s>d d+ ;

;; 32-bit sqrt (because why not?)
: SQRT ( u -- u )
  0 0 16 >r <<
    >r d2* d2* r> 2* >r
    r@ 2* 1+ 2dup u>= ?< - r> 1+ >r || drop >? r>
  r0:1-! r@ ?^|| else| rdrop nip nip >> ;

[ENDIF]

;; FIXME: move this to the better place!
: ?ERROR ( flag addr count )  rot ?< error >? 2drop ;
: NOT?ERROR ( flag addr count )  rot not?< error >? 2drop ;
: 0?ERROR ( flag addr count )  rot not?< error >? 2drop ;
: +?ERROR ( flag addr count )  rot +?< error >? 2drop ;
: -?ERROR ( flag addr count )  rot -?< error >? 2drop ;
: +0?ERROR ( flag addr count )  rot +0?< error >? 2drop ;
: -0?ERROR ( flag addr count )  rot -0?< error >? 2drop ;
