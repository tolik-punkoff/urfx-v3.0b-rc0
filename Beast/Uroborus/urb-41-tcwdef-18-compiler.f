;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; words to compile various things into target dictionary
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; define utility words for Succubus

;; negative: aggressive inline
;; positive: no inline
0 quan tgt-noinline-mark

module Succubus
<disable-hash>

: code-dd,    tcom:, ;
: code-dw,    tcom:w, ;
: code-db,    tcom:c, ;
: code-@      tcom:@ ;
: code-w@     tcom:w@ ;
: code-c@     tcom:c@ ;
: code-!      tcom:! ;
: code-w!     tcom:w! ;
: code-c!     tcom:c! ;
: code-here   tcom:here ;
: code-unallot  negate tcom:allot ;

\ tgt-disable-inliner [IF]
\ <published-words>
\ true constant debug-disable-inliner-peepopt
\ [ENDIF]

end-module Succubus

$include "../Beast/Succubus/Succubus-05-code-api.f"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utils

: .tgt-latest-name
  tgt-latest-nfa tcom:>real debug:.id ;

: .tgt-cg-current-name
  Succubus:current-cfa tgt-cfa>nfa tcom:>real debug:.id ;


extend-module Succubus
<published-words>

: (finish-bblock-hook)  ;

;; optinfo writers
: optinfo-start
\  endcr ." recording optinfo for \'" .tgt-latest-name ." \'\n"
  tcom:hdr-here tgt-latest-optinfo tcom:! ;

: optinfo-dw,  tcom:hdr-w, ;
: optinfo-db,  tcom:hdr-c, ;

: optinfo-finish
\  endcr ."  optinfo size: " tcom:hdr-here tgt-latest-optinfo tcom:@ - ., ." bytes.\n"
  tcom:hdr-here tgt-latest-optinfo tcom:@ - tcom:optinfo-size:+! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
: #inline-bytes
  tgt-noinline-mark dup -?exit< drop 8192 >?
  ?< 0 || tgt-#inline-bytes >? ;


: var-addr  tgt-cfa>pfa ;
: const-value  tgt-cfa>pfa tcom:@ ;
: uvar-offset  tgt-cfa>pfa tcom:@ ;

: set-last-word-length  tgt-set-last-word-length ;

: cfa-ffa@  ( cfa -- [ffa] )  tgt-cfa>ffa tcom:@ ;
: cfa>optinfo  ( cfa -- optinfo^ )  tgt-cfa>optinfo ;
: cfa-wlen@  ( cfa -- wlen )  tgt-cfa>wlen tcom:@ ;

: ss-latest-cfa  ( -- cfa )  tgt-latest-cfa ;
: ss-cfa>pfa  ( cfa -- pfa )  tgt-cfa>pfa ;
;; it is guaranteed to be called only on "DOES>" words
: ss-doer@  ( cfa -- doer-cfa )  8 + tcom:@ ;

: immediate-word?  ( -- bool-flag)  Succubus:current-[ffa] tgt-wflag-immediate mask? ;
: noreturn-word?  ( -- bool-flag)  Succubus:current-[ffa] tgt-wflag-noreturn mask? ;
: inline-blocker-word?  ( -- bool-flag)  Succubus:current-[ffa] tgt-wflag-inline-blocker mask? ;
: inline-allowed-word?  ( -- bool-flag)  Succubus:current-[ffa] tgt-wflag-inline-allowed mask? ;
: inline-force-word?  ( -- bool-flag)  Succubus:current-[ffa] tgt-wflag-inline-force mask? ;
: no-stacks-word?  ( -- bool-flag)  Succubus:current-[ffa] tgt-wflag-no-stacks mask? ;

: not-inlineable-word
  ?in-target
  [ tgt-wflag-inline-allowed tgt-wflag-inline-force or ] {#,}
  tgt-latest-ffa-~and! ;

: inlineable-word
  ?in-target
\ ." INLINEABLE: \'" tgt-latest-nfa tcom:>real idcount type ." \'\n"
  tgt-wflag-inline-allowed tgt-latest-ffa-or! ;

: word-has-back-jumps
  ?in-target
\ ." INLINEABLE: \'" tgt-latest-nfa tcom:>real idcount type ." \'\n"
  tgt-wflag-has-back-jumps tgt-latest-ffa-or! ;

: has-back-jumps-word?  ( -- bool-flag)
  Succubus:current-[ffa] tgt-wflag-has-back-jumps mask? ;


: debug-inliner-failed
  endcr ." FAILED to inline inlineable \'" .tgt-cg-current-name ." \'\n"
;

: debug-.latest-name  .tgt-latest-name ;
: debug-.current-cfa-name  .tgt-cg-current-name ;

tgt-asm-listing [IF]
BEAST-INCLUDE-DISASM [IF]
: debug-colon-started
  endcr cr cr ." compiling colon \'" .tgt-latest-name ." \' at $" tcom:here .hex8 cr
;

: debug-colon-finished  x86-disasm-last ;

: debug-code-started
  endcr cr cr ." compiling code \'" .tgt-latest-name ." \' at $" tcom:here .hex8 cr
;

: debug-code-finished  x86-disasm-last ;
[ENDIF]
[ENDIF]

[HAS-WORD] debug-colon-started [IFNOT] : debug-colon-started ; [ENDIF]
[HAS-WORD] debug-colon-finished [IFNOT] : debug-colon-finished ; [ENDIF]
[HAS-WORD] debug-code-started [IFNOT] : debug-code-started ; [ENDIF]
[HAS-WORD] debug-code-finished [IFNOT] : debug-code-finished ; [ENDIF]

: debug-inline-started ;
: debug-inline-finished ;
\ : debug-inliner-failed ;
\ : debug-.latest-name ;
\ : debug-.current-cfa-name ;
\ : debug-colon-started ;
\ : debug-colon-finished ;
\ : debug-code-started ;
\ : debug-code-finished ;

: get-special-handler  ( -- exec-cfa-xt // FALSE )
  Succubus:current-cfa tgt-cfa@
  dup ll@ do-constant - not?exit< drop spw-constant >?
  dup ll@ do-variable - not?exit< drop spw-variable >?
  dup ll@ do-does - not?exit< drop spw-does >?
  dup ll@ do-uservalue - not?exit< drop spw-uservalue >?
  dup ll@ do-uservar - not?exit< drop spw-uservar >?
  ll@ do-alias - not?error" no aliases yet"
  ;; check other specials
  Succubus:current-[ffa] tgt-wflag-dummy-word mask? not?exit&leave
  Succubus:current-cfa tgt-forwards:tgt-(exit) - not?exit< spw-exit >?
  Succubus:current-cfa tgt-forwards:tgt-(?exit) - not?exit< spw-?exit >?
  Succubus:current-cfa tgt-forwards:tgt-(not?exit) - not?exit< spw-not?exit >?
  Succubus:current-cfa tgt-forwards:tgt-(?exit&leave) - not?exit< spw-?exit&leave >?
  Succubus:current-cfa tgt-forwards:tgt-(not?exit&leave) - not?exit< spw-not?exit&leave >?
  Succubus:current-cfa tgt-forwards:tgt-(0?exit) - not?exit< spw-not?exit >?
  Succubus:current-cfa tgt-forwards:tgt-(0?exit&leave) - not?exit< spw-not?exit&leave >?
  \ HACK!
  " unknown dummy word \'" pad$:!
  Succubus:current-cfa tgt-cfa>nfa tcom:>real idcount pad$:+
  " \'!" pad$:+  pad$:@ error ;

end-module Succubus

\ true quan Succubus-In-Uroborus
$include "../Beast/Succubus/00-Succubus-loader.f"
\ Succubus-In-Uroborus:!f


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup the compiler

tgt-aggressive-inliner not Succubus:disable-aggressive-inliner:!
tgt-forth-inliner Succubus:allow-forth-inlining-analysis:!

Succubus:initialise


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
\ :noname
\   endcr ." trying to inline \'" .tgt-cg-current-name ." \' at $" tcom:here .hex8 cr
\ ; Succubus:debug-inline-started:!

\ :noname
\   endcr ." *** complete inline \'" .tgt-cg-current-name ." \' at $" tcom:here .hex8 cr
\ ; Succubus:debug-inline-finished:!



;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
extend-module FORTH
invite Succubus

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup x86asm

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
  Succubus:code-here 1- Succubus:code-c@
  dup $EC = swap $E5 = or ;
*)

(*
|: ixt-x86asm-mov-eax-ebx?  ( opc -- flag )
  ;; mov test; 2nd byte is mod-r/m
  $0100008B = not?exit&leave
  Succubus:code-here 1- Succubus:code-c@
  $C3 = ;
*)

false quan x86asm-no-reg-jumps?
0 quan tgt-cword-ilendb-skip

|: tgt-Succubus-istop
\ endcr x86asm:emit:here .hex8 ." : OPC: $" x86asm:emit:instr-opcode .hex8
\       ."  rdisp=" x86asm:emit:instr-rdisp? 0.r cr
  tgt-cword-ilendb-skip ?exit
  x86asm-no-reg-jumps? not?<
    x86asm:emit:instr-rdisp? ?exit< Succubus:ilendb:cg-end-jdisp >? >?
  x86asm:emit:instr-opcode
  ;; there is no need to check for "mov ebx, # n / xor ebx, ebx"
  dup ixt-x86asm-ret? ?exit< drop Succubus:ilendb:cg-end-ret >?
  dup ixt-x86asm-push-eax? ?exit< drop Succubus:ilendb:it-push-eax Succubus:ilendb:cg-end-typed >?
  dup ixt-x86asm-push-ebx? ?exit< drop Succubus:ilendb:it-push-ebx Succubus:ilendb:cg-end-typed >?
  dup ixt-x86asm-pop-eax? ?exit< drop Succubus:ilendb:it-pop-eax Succubus:ilendb:cg-end-typed >?
  dup ixt-x86asm-pop-ebx? ?exit< drop Succubus:ilendb:it-pop-ebx Succubus:ilendb:cg-end-typed >?
  dup ixt-x86asm-push-imm? ?exit< drop Succubus:ilendb:it-push-imm Succubus:ilendb:cg-end-typed >?
  \ dup ixt-x86asm-mov-eax-ebx? ?exit< drop Succubus:ilendb:it-mov-eax-ebx Succubus:ilendb:cg-end-typed >?
  \ dup ixt-x86asm-sswap? ?exit< drop Succubus:ilendb:cg-end-sswap >?
  drop Succubus:ilendb:cg-end ;

|: tgt-Succubus-istart
  tgt-cword-ilendb-skip not?< Succubus:ilendb:cg-begin >? ;

|: (setup-asm-for-Succubus)
  ['] tgt-Succubus-istart x86asm:emit:<instr:!
  ['] tgt-Succubus-istop x86asm:emit:instr>:!
  ['] Succubus:ilendb:cg-begin x86asm:sc-cg-begin:!
  ['] Succubus:ilendb:cg-end-sswap x86asm:sc-cg-end-sswap:! ;
(setup-asm-for-Succubus)

['] (setup-asm-for-Succubus) setup-asm-for-Succubus:!


end-module FORTH


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
: tgt-cc\,   Succubus:cc\, ;

: tgt-<\,    Succubus:cc\,-wdata ;
: tgt-\>     Succubus:cc-finish-wdata ;

: tgt-#,     system:comp? ?exit< Succubus:cc-#, >? ;
: tgt-str#,  system:?comp Succubus:cc-str#, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
tcf: asm-nop  ?comp-target Succubus:ilendb:cg-begin $90 tcom:c, Succubus:ilendb:cg-end ;tcf
tcf: asm-bp   ?comp-target Succubus:ilendb:cg-begin $CC tcom:c, Succubus:ilendb:cg-end ;tcf

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
0 [IF]
:noname ( lit -- 0:lit // !0: <none>)
  system:comp? not?exit
  in-target? not?exit
  tgt-#, true chain-res!
; interpret-hooks:do-literal:!
[ELSE]
|: (tc-voc-literal)  ( lit -- lit FALSE // TRUE )
  system:comp? not?exit&leave
  in-target? not?exit&leave
  tgt-#, true ;
['] (tc-voc-literal) (beast-forth-vocid) system:vocid-literal-cfa!
['] (tc-voc-literal) (tc-forth-vocid) system:vocid-literal-cfa!
[ENDIF]
