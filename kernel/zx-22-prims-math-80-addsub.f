;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; addition and subtraction
;; directly included from "zx-22-prims-math.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; add, sub

primopt: (peep-add?)  ( -- bool )
  OPT-OPTIMIZE-PEEPHOLE? not?exit&leave
  $here 2- word-begin = not?exit&leave
  last-ld-r16-r16? not?exit&leave
  1 can-remove-n-last? not?exit&leave
  ( rsrc rdest )
  dup reg:de = ?exit< drop
    << reg:bc of?v|
         ;; ld de, bc
         TOS-in-HL? not?error" wtf (+) (00)"
         remove-last-instruction
         add-hl-bc
         TOS-in-HL!
         zx-stats-peephole-addsub:1+!
         true exit |?
    else| drop false >>
  >?
  dup reg:hl = ?exit< drop
    << reg:bc of?v|
         ;; ld hl, bc
         TOS-in-DE? not?error" wtf (+) (01)"
         remove-last-instruction
         ex-de-hl
         add-hl-bc
         TOS-in-HL!
         zx-stats-peephole-addsub:1+!
         true exit |?
    else| drop false >>
  >?
  false ;

;; push  hl
;; ld    hl, () {addr}
;; "+" code (TOS: HL)
;; pop   de  -- already generated
primopt: (peep-add-2?)  ( -- bool )
  peep-pattern:[[
    push  hl
    ld    hl, () {addr}
    pop   de
  ]] peep-match not?exit&leave
  peep: {addr}
  peep-remove-instructions
  (nn)->de
  add-hl-de
  TOS-in-HL!
  zx-stats-peephole-addsub:1+!
  true ;

;; push  de
;; ld    de, () {addr}
;; "+" code (TOS: DE)
;; pop   hl  -- already generated
primopt: (peep-add-3?)  ( -- bool )
  peep-pattern:[[
    push  de
    ld    de, () {addr}
    pop   hl
  ]] peep-match not?exit&leave
  peep: {addr}
  peep-remove-instructions
  (nn)->hl
  add-hl-de
  TOS-in-HL!
  zx-stats-peephole-addsub:1+!
  true ;

;; push  hl
;; ld    hl, # {value}
;; "+" code (TOS: HL)
;; pop   de  -- already generated
primopt: (peep-add-4?)  ( -- bool )
  peep-pattern:[[
    push  hl
    ld    hl, # {value}
    pop   de
  ]] peep-match not?exit&leave
  peep: {value}
  peep-remove-instructions
  #->de
  add-hl-de
  TOS-in-HL!
  zx-stats-peephole-addsub:1+!
  true ;

;; push  de
;; ld    de, # {value}
;; "+" code (TOS: DE)
;; pop   hl  -- already generated
primopt: (peep-add-5?)  ( -- bool )
  peep-pattern:[[
    push  de
    ld    de, # {value}
    pop   hl
  ]] peep-match not?exit&leave
  peep: {value}
  peep-remove-instructions
  #->hl
  add-hl-de
  TOS-in-HL!
  zx-stats-peephole-addsub:1+!
  true ;

primitive: +  ( a b -- a+b )
:codegen-xasm
  pop-non-tos-peephole
  (peep-add?) ?exit
  (peep-add-2?) ?exit
  (peep-add-3?) ?exit
  (peep-add-4?) ?exit
  (peep-add-5?) ?exit
  add-hl-de
  TOS-in-HL! ;


primopt: (peep-sub1?)  ( -- bool )
  OPT-OPTIMIZE-PEEPHOLE? not?exit&leave
  $here 2- word-begin = not?exit&leave
  last-ld-r16-r16? not?exit&leave
  1 can-remove-n-last? not?exit&leave
  ;; it is faster with 8 bits if we need to move 16-bit register
  ;; (27ts vs 24ts).
  ( rsrc rdest )
  dup reg:hl = ?exit< drop
    remove-last-instruction
    ;; something to HL, then SBC HL, de
    ;; the only possible combination is "ld hl, bc".
    reg:bc = not?error" wtf in (peep-sub?) (00)"
    c->a
    sub-a-e
    a->l
    b->a
    sbc-a-d
    a->h
    TOS-in-HL!
    zx-stats-peephole-addsub:1+!
    true
  >?
  2drop
  false ;

;; push  hl
;; ld    hl,  () {addr}
;; - (TOS: HL)
;; pop   de
;; ex    de, hl
;; non-generated yet
;; xor   a
;; sbc   hl, de
primopt: (peep-sub2?)  ( -- bool )
  \ TOS-in-HL? not?exit&leave
  peep-pattern:[[
    push  hl
    ld    hl, () {addr}
    pop   de
    ex    de, hl
  ]] peep-match not?exit&leave
  peep: {addr}
  peep-remove-instructions
  ;; now transform to:
  ;;  ld  de, (nn)
  ;;  xor a
  ;;  sbc hl, de
  (nn)->de
  xor-a
  sbc-hl-de
  TOS-in-HL!
  zx-stats-peephole-addsub:1+!
  true ;

;; push  de
;; ld    de, () $AC38
;; - (TOS: DE)
;; pop   hl
;; non-generated yet
;; xor   a
;; sbc   hl, de
primopt: (peep-sub3?)  ( -- bool )
  peep-pattern:[[
    push  de
    ld    de, () {addr}
    pop   hl
  ]] peep-match not?exit&leave
  peep: {addr}
  peep-remove-instructions
  ;; now transform to:
  ;;  ld  hl, (nn)
  ;;  ex  de, hl
  ;;  xor a
  ;;  sbc hl, de
  (nn)->hl
  ex-de-hl
  xor-a
  sbc-hl-de
  TOS-in-HL!
  zx-stats-peephole-addsub:1+!
  true ;

primitive: -  ( a b -- a-b )
Succubus:setters:need-TOS-DE
:codegen-xasm
  restore-tos-de-pop-hl
  (peep-sub1?) ?exit
  (peep-sub2?) ?exit
  (peep-sub3?) ?exit
  xor-a-a
  sbc-hl-de
  TOS-in-HL! ;


primitive: SWAP-  ( a b -- b-a )
:codegen-xasm
  restore-tos-hl-pop-de
  xor-a-a
  sbc-hl-de
  TOS-in-HL! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some useful utils

primitive: UNDER+  ( a b c -- a+c b )
:codegen-xasm
  restore-tos-hl-pop-de
  ;; HL:c; DE:b
  pop-bc
  ;; HL:c; DE:b; BC:a
  add-hl-bc
  ;; HL:a+c; DE:b
  push-hl
  TOS-in-DE! ;

primitive: UNDER-  ( a b c -- a-c b )
:codegen-xasm
  ;; final: HL=a; DE=b; BC=c
  \ TOS-in-HL? ?< hl->bc || de->bc >?
  \ pop-de
  \ pop-hl
  TOS-in-HL? ?<
    pop-de-peephole
    hl->bc
    pop-hl
  ||
    ;; check if we can optimise pop
    last-push-non-tos? ?<
      pop-hl-peephole
      de->bc
      ex-de-hl
      pop-hl
    ||
      de->bc
      pop-de
      pop-hl
    >?
  >?
  xor-a
  sbc-hl-bc
  push-hl
  TOS-in-DE! ;
