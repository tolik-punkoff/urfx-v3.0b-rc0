;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple PRNG generators: Bob Jenkins' (2rot, 3rot), PCG32
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module PRNG
<disable-hash>
<published-words>

(*
absolutely non-scientific stupid benchmark:

=== testing Forth version speed (3 rotations) ===
268,435,456 values, 7,106 milliseconds: 37,775,887 values per second.
=== testing Forth version speed (2 rotations) ===
268,435,456 values, 6,812 milliseconds: 39,406,261 values per second.

=== testing asm version PCG32-RAW speed ===
268,435,456 values, 2,041 milliseconds: 131,521,536 values per second.
=== testing asm version speed (3 rotations) ===
268,435,456 values, 1,606 milliseconds: 167,145,364 values per second.
=== testing asm version speed (2 rotations) ===
268,435,456 values, 1,549 milliseconds: 173,295,969 values per second.
=== testing asm version PCG32 speed ===
268,435,456 values, 2,385 milliseconds: 112,551,553 values per second.
*)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; generate 32-bit seed (not cryptographically strong!)
;; also, don't call this repeatedly, it will produce bad seeds
: GEN-SEED32  ( -- u )
  linux:clock-monotonic linux:clock-gettime
  u32hash swap u32hash - linux:get-pid u32hash - ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; generate 32-bit random number, with first stream
;; it uses smaller 64 bit state, and slightly faster
;;
;; code for:
;; oldstate = state;
;; state = oldstate*6364136223846793005UL+((42<<1)|1);
;; u32 xorshifted = ((oldstate>>18)^oldstate)>>27;
;; u32 rot = oldstate>>59;
;; res = (xorshifted>>rot)|(xorshifted<<((-rot)&31));

8 constant #PCG32-STATE

code-naked-no-inline: PCG32-NEXT-RAW  ( statelo statehi -- newstatelo newstatehi u32prv )
  upush utos
  push  edi       ;; it will be used in the code
  sub   esp, # 8  ;; and two temp vars
  ;; [esp+0]: tmpvar0
  ;; [esp+4]: tmpvar1
  ;;
  ;; [usp+0]: statehi
  ;; [usp+4]: statelo
  mov   edx, [usp]        ;; statehi
  mov   eax, [usp+] # 4   ;; statelo
  mov   [esp], edx        ;; tmpvar0
  imul  edx, edx, # $4c957f2d
  imul  ecx, eax, # $5851f42d
  add   ecx, edx
  mov   edx, # $4c957f2d
  mov   [esp+] 4 #, eax   ;; tmpvar1
  mul   edx
  add   edx, ecx
  add   eax, # 85         ;; inclo
  adc   edx, # 0          ;; inchi
  mov   [usp], edx        ;; statehi
  mov   edx, [esp]        ;; tmpvar0
  mov   [usp+] 4 #, eax   ;; statelo
  mov   eax, [esp+] # 4   ;; tmpvar1
  shrd  eax, edx, # $12
  shr   edx, # $12
  xor   eax, [esp+] # 4   ;; tmpvar1
  xor   edx, [esp]        ;; tmpvar0
  shrd  eax, edx, # $1b
  shr   edx, # $1b
  mov   esi, eax
  mov   edx, [esp]        ;; tmpvar0
  mov   eax, [esp+] # 4   ;; tmpvar1
  shr   edx, # $1b
  mov   eax, edx
  mov   edi, eax
  mov   eax, esi
  mov   ecx, edi
  xor   edx, edx
  shr   eax, cl
  mov   ecx, edi
  neg   ecx
  mov   edx, esi
  and   ecx, # $1f
  shl   edx, cl
  or    eax, edx
  mov   utos, eax         ;; u32prv
  add   esp, # 8
  pop   edi
;code-next

code-naked-no-inline: PCG32-NEXT  ( ctx -- u32prv )
  push  edi       ;; it will be used in the code
  sub   esp, # 8  ;; and two temp vars
  ;; [esp+0]: tmpvar0
  ;; [esp+4]: tmpvar1
  mov   eax, [utos]       ;; statelo
  mov   edx, [utos+] # 4  ;; statehi
  mov   [esp], edx        ;; tmpvar0
  imul  edx, edx, # $4c957f2d
  imul  ecx, eax, # $5851f42d
  add   ecx, edx
  mov   edx, # $4c957f2d
  mov   [esp+] 4 #, eax   ;; tmpvar1
  mul   edx
  add   edx, ecx
  add   eax, # 85         ;; inclo
  adc   edx, # 0          ;; inchi
  mov   [utos+] 4 #, edx  ;; statehi
  mov   edx, [esp]        ;; tmpvar0
  mov   [utos], eax       ;; statelo
  mov   eax, [esp+] # 4   ;; tmpvar1
  shrd  eax, edx, # $12
  shr   edx, # $12
  xor   eax, [esp+] # 4   ;; tmpvar1
  xor   edx, [esp]        ;; tmpvar0
  shrd  eax, edx, # $1b
  shr   edx, # $1b
  mov   esi, eax
  mov   edx, [esp]        ;; tmpvar0
  mov   eax, [esp+] # 4   ;; tmpvar1
  shr   edx, # $1b
  mov   eax, edx
  mov   edi, eax
  mov   eax, esi
  mov   ecx, edi
  xor   edx, edx
  shr   eax, cl
  mov   ecx, edi
  neg   ecx
  mov   edx, esi
  and   ecx, # $1f
  shl   edx, cl
  or    eax, edx
  mov   utos, eax         ;; u32prv
  add   esp, # 8
  pop   edi
;code-next

;; very-very week seeding
: PCG32-SEED-U64-RAW  ( dlo dhi -- statelo statehi )
  0x29a 0xa29 pcg32-next-raw drop
  rot - nrot - pcg32-next-raw drop ;

;; very-very week seeding
: PCG32-SEED-U64  ( dlo dhi ctx )
  0x29a over ! 0xa29 over 4+ ! dup pcg32-next drop
  2dup 4+ ! nip 2dup ! nip pcg32-next drop ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bob Jenkins small PRNG -- http://burtleburtle.net/bob/rand/smallprng.html

(*
module bjprng
<disable-hash>
<private-words>

0
new-field-r/w bj>a
new-field-r/w bj>b
new-field-r/w bj>c
new-field-r/w bj>d

<published-words>
constant #state

: next-fast  ( state -- u32 )
  >r  ( | state )
  r@ bj>a@ r@ bj>b@ 27 rol -  ( e | state )
  r@ bj>b@ r@ bj>c@ 17 rol xor r@ bj>a!
  r@ bj>c@ r@ bj>d@ + r@ bj>b!
  r@ bj>d@ over + r@ bj>c!
  r@ bj>a@ + dup r> bj>d! ( this is also the result ) ;

: seed-fast  ( u32 state )
  >r 0xf1ea5eed r@ bj>a!
  dup r@ bj>b! dup r@ bj>c! r@ bj>d!
  r> 20 for dup next-fast drop endfor drop ;

: next  ( state -- u32 )
  >r  ( | state )
  r@ bj>a@ r@ bj>b@ 23 rol -  ( e | state )
  r@ bj>b@ r@ bj>c@ 16 rol xor r@ bj>a!
  r@ bj>c@ r@ bj>d@ 11 rol + r@ bj>b!
  r@ bj>d@ over + r@ bj>c!
  r@ bj>a@ + dup r> bj>d! ( this is also the result ) ;

: seed  ( u32 state )
  >r 0xf1ea5eed r@ bj>a!
  dup r@ bj>b! dup r@ bj>c! r@ bj>d!
  20 << 1- dup +0?^| r@ next drop |? else| rdrop drop >> ;

seal-module
end-module bjprng
*)

16 constant #BJ-STATE

;; 2 rotations
code-naked-no-inline: BJ-NEXT  ( ctx -- u32prv )
  (*
  mov   esi, utos
  ;; e = a-ROT(b, 27)
  mov   ecx, [esi]        ;; a
  mov   eax, [esi+] # 4   ;; b
  rol   eax, # 27
  sub   ecx, eax
  ;; ECX: e
  ;; a = b^ROT(c, 17)
  mov   ebx, [esi+] # 8   ;; c
  mov   edx, ebx
  ;; EDX: c
  rol   ebx, # 17
  xor   ebx, [esi+] # 4   ;; b
  mov   [esi], ebx        ;; a
  mov   ebx, [esi+] # 12  ;; d
  ;; EAX: free
  ;; EBX: d
  ;; ECX: e
  ;; EDX: c
  ;; b = c+d
  lea   eax, [edx+] [ebx*1]
  mov   [esi+] 4 #, eax   ;; b
  ;; c = e+d
  lea   eax, [ecx+] [ebx*1]
  mov   [esi+] 8 #, eax   ;; c
  ;; d = e+a -- u32prv
  mov   utos, [esi]       ;; a
  lea   utos, [utos+] [ecx*1]
  mov   [esi+] 12 #, utos ;; d
  *)
  mov   edx, ebx
  mov   ebx, [edx+] # 4
  mov   esi, [edx+] # 8
  mov   ecx, [edx]
  mov   eax, ebx
  ror   eax, # 5
  sub   ecx, eax
  mov   eax, esi
  ror   eax, # 15
  xor   eax, ebx
  mov   ebx, [edx+] # 12
  mov   [edx], eax
  add   eax, ecx
  mov   [edx+] 12 #, eax
  add   esi, ebx
  add   ebx, ecx
  mov   [edx+] 4 #, esi
  mov   [edx+] 8 #, ebx
  mov   utos, eax
;code-no-stacks (no-stacks)

;; 3 rotations
code-naked-no-inline: BJ-NEXT-SLOW  ( ctx -- u32prv )
  (*
  mov   esi, utos
  ;; e = a-ROT(b, 23)
  mov   ecx, [esi]        ;; a
  mov   eax, [esi+] # 4   ;; b
  rol   eax, # 23
  sub   ecx, eax
  ;; ECX: e
  ;; a = b^ROT(c, 16)
  mov   ebx, [esi+] # 8   ;; c
  mov   edx, ebx
  ;; EDX: c
  rol   ebx, # 16
  xor   ebx, [esi+] # 4   ;; b
  mov   [esi], ebx        ;; a
  mov   ebx, [esi+] # 12  ;; d
  ;; EAX: free
  ;; EBX: d
  ;; ECX: e
  ;; EDX: c
  ;; b = c+ROT(d, 11)
  mov   eax, ebx
  rol   eax, # 11
  lea   eax, [edx+] [eax*1]
  mov   [esi+] 4 #, eax   ;; b
  ;; c = e+d
  lea   eax, [ecx+] [ebx*1]
  mov   [esi+] 8 #, eax   ;; c
  ;; d = e+a -- u32prv
  mov   utos, [esi]       ;; a
  lea   utos, [utos+] [ecx*1]
  mov   [esi+] 12 #, utos ;; d
  *)
  push  edi
  mov   edx, ebx
  mov   eax, [edx+] # 4
  mov   edi, [edx]
  mov   ecx, eax
  ror   ecx, # 9
  sub   edi, ecx
  mov   ecx, edi
  mov   edi, [edx+] # 8
  mov   ebx, edi
  rol   ebx, # 16
  xor   eax, ebx
  mov   ebx, [edx+] # 12
  mov   [edx], eax
  add   eax, ecx
  mov   [edx+] 12 #, eax
  mov   esi, ebx
  add   ebx, ecx
  rol   esi, # 11
  mov   [edx+] 8 #, ebx
  add   esi, edi
  mov   [edx+] 4 #, esi
  mov   utos, eax
  pop   edi
;code-no-stacks (no-stacks)

  ;; this is how BJ does it for 32-bit seeds
|: BJ-DO-SEED  ( u ctx next-cfa )
  >r dup >r
  $f1ea5eed over !  ;; a
  4+ 2dup !      ;; b
  4+ 2dup !      ;; c
  4+ !           ;; d
  r> 20 << over r@ execute drop 1- dup ?^|| else| 2drop >> rdrop ;

: BJ-SEED       ( u ctx )  ['] bj-next bj-do-seed ;
: BJ-SEED-SLOW  ( u ctx )  ['] bj-next-slow bj-do-seed ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; produce biased result [0..range)
;; this is slightly faster than division.
;; it multiplies range and prv, and takes the high 32 bits of 64-bit result.
;; this (seemingly) performs worser than modulo on PRNGs with non-32-bit range.
;; if you need biased ranged result, and you are unsure, use "UMOD",
code-swap-inline: BIASED-RANGE ( u32prv urange -- u1 )
  pop   eax
  mul   utos
  mov   utos, edx
;code-swap-next

end-module PRNG (published)
