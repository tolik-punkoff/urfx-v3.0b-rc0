;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler
;; architecture is inspired by Common Forth Experiment from Luke Lee
;; all code is written from scratch
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; exclude rarely used instructions?
[HAS-WORD] X86ASM-SMALL [IFNOT]
false constant X86ASM-SMALL
[ENDIF]

;; include privileged instructions?
[HAS-WORD] X86ASM-PRIV [IFNOT]
false constant X86ASM-PRIV
[ENDIF]

;; include FPU instructions?
[HAS-WORD] X86ASM-FPU [IFNOT]
false constant X86ASM-FPU
[ENDIF]

module x86asm

;; all high-level instructions and operands will be here
module instructions
<separate-hash>
end-module instructions
vect put-arg

$include "x86asm-00-emit.f"
$include "x86asm-01-instr.f"
$include "x86asm-02-oper.f"
$include "x86asm-03-parg.f"
$include "x86asm-04-match.f"
$include "x86asm-05-ifthen.f"
$include "x86asm-06-loclabels.f"

[HAS-WORD] BEAST-TC-MACROS [IFNOT] 0 [ELSE] BEAST-TC-MACROS [ENDIF]
[IFNOT]
|: ixt-x86asm-ret?      ( opc -- flag )  dup $010000C2 = swap $010000C3 = or ;
|: ixt-x86asm-push-imm? ( opc -- flag )  dup $0100006A = swap $01000068 = or ;
|: ixt-x86asm-push-eax? ( opc -- flag )  $01000050 = ;
|: ixt-x86asm-push-ebx? ( opc -- flag )  $01000053 = ;
|: ixt-x86asm-pop-eax?  ( opc -- flag )  $01000058 = ;
|: ixt-x86asm-pop-ebx?  ( opc -- flag )  $0100005B = ;

(*
|: ixt-x86asm-sswap?  ( opc -- flag )
  ;; xchg test; 2nd byte is mod-r/m
  $01000087 = not?exit&leave
  system:Succubus:code-here 1- system:Succubus:code-c@
  dup $EC = swap $E5 = or ;
*)

|: Succubus-istop
  emit:instr-rdisp? ?exit< system:Succubus:ilendb:cg-end-jdisp >?
  emit:instr-opcode
  dup ixt-x86asm-ret? ?exit< drop system:Succubus:ilendb:cg-end-ret >?
  dup ixt-x86asm-push-eax? ?exit< drop system:Succubus:ilendb:it-push-eax system:Succubus:ilendb:cg-end-typed >?
  dup ixt-x86asm-push-ebx? ?exit< drop system:Succubus:ilendb:it-push-ebx system:Succubus:ilendb:cg-end-typed >?
  dup ixt-x86asm-pop-eax? ?exit< drop system:Succubus:ilendb:it-pop-eax system:Succubus:ilendb:cg-end-typed >?
  dup ixt-x86asm-pop-ebx? ?exit< drop system:Succubus:ilendb:it-pop-ebx system:Succubus:ilendb:cg-end-typed >?
  dup ixt-x86asm-push-imm? ?exit< drop system:Succubus:ilendb:it-push-imm system:Succubus:ilendb:cg-end-typed >?
  \ dup ixt-x86asm-sswap? ?exit< drop system:Succubus:ilendb:cg-end-sswap >?
  drop system:Succubus:ilendb:cg-end ;

['] system:Succubus:ilendb:cg-begin emit:<instr:!
['] Succubus-istop emit:instr>:!
[ENDIF]

clean-module
end-module x86asm
