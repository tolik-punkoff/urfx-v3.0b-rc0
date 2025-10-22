;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; stack operations
;; directly included from "zx-20-prims.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level stack words

<zx-system>

primitive: SP@  ( -- sp )
:codegen-xasm
  push-tos-peephole-restore-tos-hl
  0 #->hl
  add-hl-sp ;

primitive: SP0!  ( <unknown> )
:codegen-xasm
  zx-s0 #->sp ;

primitive: S0  ( -- s0 )
:codegen-xasm
  push-tos-peephole
  zx-s0 tos-r16 #->r16 ;

primitive: DEPTH  ( -- stack-depth )
:codegen-xasm
  push-tos
  xor-a-a
  zx-s0 #->hl
  sbc-hl-sp
  rr-h
  rr-l
  dec-hl
  TOS-in-HL! ;

<zx-forth>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; basic stack manipulations

primitive: PICK  ( <unknown> )
\ TODO: optimiser!
:codegen-xasm
  restore-tos-hl
  add-hl-hl
  add-hl-sp
  (hl)->e inc-hl
  (hl)->d
  TOS-in-DE! ;

primitive: TOSS  ( u idx <unknown> )
\ TODO: optimiser!
:codegen-xasm
  restore-tos-hl
  add-hl-hl
  add-hl-sp
  pop-de
  e->(hl) inc-hl
  d->(hl)
  pop-tos ;


primitive: 2DUP  ( a b -- a b a b )
\ TODO: optimiser!
:codegen-xasm
  pop-bc-peephole
  ;; BC: a; TOS: b
  push-bc
  ;; ( a b )
  push-tos
  ;; ( a b b )
  push-bc
  ;; ( a b a b )
;


primopt: (ndrop-cgen)  ( count )
  dup 0< ?error" wtf in (ndrop-cgen)!"
  << 0 of?v| exit |?
     1 of?v||
     2 of?v| tos-r16 pop-r16-peephole-ignore |?
     3 of?v| tos-r16 pop-r16-peephole-ignore tos-r16 pop-r16-peephole-ignore |?
  else|
    ;; 27 vs 30 for 3 `POP`s
    2* #->hl
    add-hl-sp
    hl->sp
    pop-tos
    exit >>
  pop-tos-peephole
  optim-last-tos-load ;
<zx-system>

primitive: (DROP<n>)  ( <unknown> )
:codegen
  ?curr-node-lit-value (ndrop-cgen) ;
<zx-forth>

primitive: DROP  ( a )
:codegen  1 (ndrop-cgen) ;

primitive: 2DROP  ( a b )
:codegen  2 (ndrop-cgen) ;

primitive: 3DROP  ( a b c )
:codegen  3 (ndrop-cgen) ;

primitive: 4DROP  ( a b c d )
:codegen  4 (ndrop-cgen) ;


primitive: 2SWAP  ( a b c d -- c d a b )
:codegen-xasm
  ;; TOS: d
  pop-non-tos-peephole ;; nonTOS: c
  pop-bc-peephole   ;; BC: b
  pop-af   ;; a
  push-non-tos ;; nonTOS: c
  push-tos ;; d
  push-af  ;; a
  reg:bc tos-r16 r16->r16 ;; b
;

primitive: 2OVER  ( a b c d -- a b c d a b )
:codegen-xasm
  ;; TOS: d
  pop-non-tos-peephole ;; nonTOS: c
  pop-bc-peephole   ;; BC: b
  pop-af   ;; a
  push-af  ;; a
  push-bc  ;; b
  push-non-tos ;; nonTOS: c
  push-tos ;; d
  push-af  ;; a
  reg:bc tos-r16 r16->r16 ;; b
;

;; SWAP DROP
primitive: NIP  ( a b -- b )
:codegen-xasm
  pop-bc-peephole ;

primitive: 2NIP  ( x1 x2 x3 x4 -- x3 x4 )
:codegen-xasm
  pop-bc-peephole
  pop-af
  pop-af
  push-bc ;

;; SWAP OVER
;; DUP NROT
primitive: TUCK  ( a b -- b a b )
:codegen-xasm
  pop-bc-peephole
  push-tos
  push-bc ;

;; OVER SWAP
;; OVER NROT
primitive: UNDER  ( a b -- a a b )
:codegen-xasm
  pop-bc-peephole
  push-bc
  push-bc ;

;; this primitive had some sense in the threaded code,
;; but with the compiled code it hurts the performance
;; (and data flow analysis too).
(*
primitive: ?DUP  ( a -- a a // 0 )
Succubus:setters:unknown-out-args
:codegen-xasm
  tos-r16 r16h->a
  tos-r16 or-a-r16l
  cond:z jr-cc  ( -- patch-addr )
  push-tos
  jr-dest! ;
alias-for ?DUP is -DUP  ( a -- a a // 0 )
*)

primitive: ROT  ( a b c -- b c a )
:codegen-xasm
  pop-bc-peephole   ;; b
  pop-non-tos-peephole ;; a
  push-bc  ;; b
  push-tos ;; c
  TOS-invert! ;

primitive: NROT  ( a b c -- c a b )
:codegen-xasm
  pop-non-tos-peephole ;; b
  pop-bc-peephole   ;; a
  push-tos ;; c
  push-bc  ;; a
  TOS-invert! ;
alias-for NROT is -ROT  ( a b c -- c a b )

primitive: OVER  ( a b -- a b a )
:codegen-xasm
  ;; TOS:b
  pop-non-tos-peephole
  ;; non-TOS:a
  push-non-tos
  push-tos ;; b
  TOS-invert! ;

primitive: SWAP  ( a b -- b a )
Succubus:setters:need-TOS-HL
:codegen-xasm
  restore-tos-hl
  ex-(sp)-hl ;

primitive: DUP  ( a -- a a )
:codegen-xasm
  push-tos ;
