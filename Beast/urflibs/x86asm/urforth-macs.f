;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler: operand definitions
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


: start-asm  0xbad0_b0da x86asm:emit:init push-ctx voc-ctx: x86asm:instructions ;

extend-module x86asm
;; k8: execute words until eol
: <rest>
  << parse-name/none dup not?v||
     ;; check for some comment types
     over c@ [char] ; = ?v| skip-line |?
     dup 2 = cand over w@ 0x2f2f = ?v| skip-line |?
     vocid: x86asm:instructions find-in-vocid not?error" wut?!"
  execute ^|| >> 2drop ;

extend-module instructions
: stop-asm  pop-ctx x86asm:emit:finish 0xbad0_b0da system:?pairs ;
end-module instructions


2 macro-narg: def-strz  ( addr count )
  << dup +?^| swap c@++ x86asm:emit:c, swap 1- |? else| 2drop >> 0 x86asm:emit:c, ;macro

;; convert low 4 bits of AL to hex digit ready to print
;; in: AL: nibble
;; out: AL: hex digit ready to print (uppercased)
;; it's voodoo %-) can somebody explain this code? %-)
;; heh, it's one byte shorter than the common snippets i've seen
;; many times in teh internets.
;; actually, this is the code from my Z80 library. %-)
(*
macro: Nibble2Hex
  and   al, # $0F
  cmp   al, # $0A
  sbb   al, # $69
  das ;macro
*)

[HAS-WORD] BEAST-TC-MACROS [IFNOT]

macro: SWAP-STACKS
  \ xchg  ebp, esp
  flush!
  \ mov   edx, ebp
  \ mov   ebp, esp
  \ mov   esp, edx
  system:Succubus:ilendb:cg-begin
  $8B emit:c, $D5 emit:c,
  $8B emit:c, $EC emit:c,
  $8B emit:c, $E2 emit:c,
  system:Succubus:ilendb:cg-end-sswap
;macro

macro: UPUSH
  lea USP, [USP+] # -4
  mov dword^ [USP],
;macro

macro: URPUSH
  push
;macro

macro: UPOP
  mov <rest> , dword^ [USP]
  lea USP, [USP+] # 4
;macro

;; drop without updating TOS
1 macro-narg: UXDROP  ( cnt )
  dup 0< ?error" wut?!"
  dup ?< >r
    lea USP, [USP+] # r> 4*
  || drop >?
;macro

;; counter includes TOS
1 macro-narg: U-NDROP  ( cnt )
  dup 0< ?error" wut?!"
  dup not?< drop
  || dup 1 = ?< drop
       mov utos, [USP]
       lea USP, [USP+] # 4
     || >r
       lea USP, [USP+] # r> 4*
       mov utos, [USP+] # -4
     >? >?
;macro

macro: URPOP
  pop <rest>
;macro

(*
macro: BEAST-ADVUIP
  lea UIP, [UIP+] # 4
;macro

macro: BEAST-ADVUIP2
  lea UIP, [UIP+] # 8
;macro

macro: BEAST-NEXTJMP
  jmp [UIP]
;macro

macro: BEAST-EXECJMP-EAX
  jmp   eax
;macro
*)

macro: BEAST-NEXTJMP
  ret
;macro


[ENDIF]

end-module x86asm


[HAS-WORD] BEAST-TC-MACROS [IFNOT]

*: CODE-SWAP:  \ name
  system:?exec parse-name system:mk-code system:set-smudge
  system:ctlid-code start-asm x86asm:instructions:swap-stacks ;

*: CODE-NAKED:  \ name
  system:?exec parse-name system:mk-code system:set-smudge
  system:ctlid-code start-asm ;

*: ;CODE-NEXT
  system:?exec
  x86asm:instructions:beast-nextjmp x86asm:instructions:stop-asm
  system:ctlid-code system:?pairs
  system:reset-smudge ;

*: ;CODE-SWAP-NEXT
  system:?exec
  x86asm:instructions:swap-stacks
  x86asm:instructions:beast-nextjmp
  x86asm:instructions:stop-asm
  system:ctlid-code system:?pairs
  system:reset-smudge ;

*: ;CODE-NO-NEXT
  system:?exec x86asm:instructions:stop-asm
  system:ctlid-code system:?pairs
  system:reset-smudge ;


extend-module x86asm

;; call Forth word
macro: FCALL  \ name
  -find-required ( dup system:simple-code? not?error" cannot call non-Forth word") >r
  call # r>
;macro

end-module x86asm
[ENDIF]
