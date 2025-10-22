;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target compiler assembler macros
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module tc-labels
end-module tc-labels


extend-module x86asm
0 quan in-swapped?

vect-empty sc-cg-begin
vect-empty sc-cg-end-sswap

;; WARNING! keep in sync with register map!
;; ESP is return stack pointer, EBP is data stack pointer
macro: SWAP-STACKS
  flush!
  \ mov   edx, ebp
  \ mov   ebp, esp
  \ mov   esp, edx
  sc-cg-begin
  $8B emit:c, $D5 emit:c,
  $8B emit:c, $EC emit:c,
  $8B emit:c, $E2 emit:c,
  sc-cg-end-sswap
  in-swapped? forth:not in-swapped?:!
;macro
(* old code
macro: SWAP-STACKS
  flush!
  \ xchg  ebp, esp
  sc-cg-begin
  $87 emit:c, $EC emit:c,
  sc-cg-end-sswap
  in-swapped? forth:not in-swapped?:!
;macro
*)

macro: UPUSH
  in-swapped? ?error" UPUSH in swapped code"
  lea   USP, [USP+] # -4
  mov   dword^ [USP],
;macro

macro: URPUSH
  in-swapped? not?error" URPUSH in swapped code"
  push
;macro

macro: UPOP
  in-swapped? ?error" UPOP in swapped code"
  mov   <rest> , dword^ [USP]
  lea   USP, [USP+] # 4
;macro

;; drop without updating TOS
1 macro-narg: UXDROP  ( cnt )
  in-swapped? ?error" UXDROP in swapped code"
  dup 0< ?error" wut?!"
  dup ?< >r
    lea USP, [USP+] # r> 4*
  || drop >?
;macro

;; counter includes TOS
1 macro-narg: U-NDROP  ( cnt )
  in-swapped? ?error" U-DROP in swapped code"
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
  in-swapped? not?error" URDROP in swapped code"
  pop   <rest>
;macro

macro: BEAST-NEXTJMP
  ret
;macro

\ macro: BEAST-EXECJMP-EAX
\   jmp   eax
\ ;macro
end-module x86asm


BEAST-INCLUDE-DISASM [IF]
0 quan saddr
0 quan eaddr
[ENDIF]
-1 quan x86-csp

: x86-start
  x86-csp 0>= " X86-START without X86-END" ?error
  depth to x86-csp
\ depth . ." ASM-START!\n"
  x86asm:emit:init
  [ BEAST-INCLUDE-DISASM ] [IF] x86asm:emit:here to saddr [ENDIF]
  push-ctx voc-ctx: forth push-ctx voc-ctx: x86asm:instructions ;

: x86-end
  x86-csp 0< ?error" X86-END without X86-START"
  pop-ctx pop-ctx x86asm:emit:finish
  depth x86-csp <> ?error" unbalanced stack" -1 to x86-csp
\ depth . ." ASM-END!\n"
  [ BEAST-INCLUDE-DISASM ] [IF] x86asm:emit:here to eaddr [ENDIF] ;

BEAST-INCLUDE-DISASM [IF]
: x86-disasm-last-code
  saddr eaddr x86dis:disasm-range ;
[ENDIF]

: x86-label-#:  ( value )
  current@ vocid: tc-labels current! swap constant current! ;

: x86-label:
  tcom:here x86-label-#: ;


: (x86-find-label)  ( addr count -- value )
  2dup vocid: tc-labels find-in-vocid
  not?< " label \'" pad$:! pad$:+ " \' not found" pad$:+ pad$:@ error >?
  nrot 2drop execute ;

: x86-find-label  ( -- value )  \ name
  parse-name (x86-find-label) ;

*: x86-label@  ( -- value )  \ name
  x86-find-label [\\] {#,} ;
alias-for x86-label@ is ll@
