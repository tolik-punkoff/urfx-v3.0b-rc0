;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; memory copying and filling
;; directly included from "zx-20-prims.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CMOVE

primitive: CMOVE  ( asrc adest acount )
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-DE? ?< ex-de-hl TOS-in-HL! >?
  hl->bc
  pop-hl
  ;; HL: addr
  ;; DE: dest
  ;; BC: len
  b->a
  or-a-c
  cond:z jr-cc  ( .skip )
  ldir
  jr-dest!
  pop-tos ;

primitive: CMOVE-NC  ( asrc adest acount )
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-DE? ?< ex-de-hl TOS-in-HL! >?
  hl->bc
  pop-hl
  ;; HL: addr
  ;; DE: dest
  ;; BC: len
  ldir
  pop-tos ;

<zx-system>
primitive: CMOVE:LIT  ( asrc adest )  \ [acount]
:codegen-xasm
  pop-non-tos-peephole
  ?curr-node-lit-value lo-word dup 0?exit< drop pop-tos-peephole >?
  dup 1 = ?exit< drop
    ;; 2ts faster than LDI
    non-tos-r16 (r16)->a
    tos-r16 a->(r16)
    pop-tos
  >?
  restore-tos-de
  << 1 of?v| ldi |?
     2 of?v| ldi ldi |?
     3 of?v| ldi ldi ldi |?
     4 of?v| ldi ldi ldi ldi |?
  else|
    #->bc
    ;; HL: addr
    ;; DE: dest
    ;; BC: len
    ldir >>
  TOS-in-HL!
  pop-tos ;

primitive: CMOVE:LIT:LIT  ( asrc )  \ [acount](value) [adest](value2)
:codegen-xasm
  ?curr-node-lit-value lo-word dup 0?exit< drop pop-tos-peephole >?
  dup 1 = ?exit< drop
    (tos)->a
    curr-node node:value2 a->(nn)
    pop-tos
  >?
  restore-tos-hl
  curr-node node:value2 #->de
  << 1 of?v| ldi |?
     2 of?v| ldi ldi |?
     3 of?v| ldi ldi ldi |?
     4 of?v| ldi ldi ldi ldi |?
  else|
    #->bc
    ;; HL: addr
    ;; DE: dest
    ;; BC: len
    ldir >>
  pop-tos ;
<zx-forth>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CMOVE>

;; can be used to make some room.
;; moves from the last byte to the first one.
primitive: CMOVE>  ( asrc adest acount )
:codegen-xasm
  tos-r16 reg:bc r16->r16
  pop-hl
  pop-de
  ;; DE: src
  ;; HL: dest
  ;; BC: len
  b->a
  or-a-c
  cond:z jr-cc  ( .skip )
  ;; move both pointers to the end
  dec-bc
  add-hl-bc
  ex-de-hl
  add-hl-bc
  inc-bc
  lddr
  jr-dest!
  TOS-in-HL!
  pop-tos ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FILL

code: FILL  ( addr len byte )
  ex    de, hl
  pop   bc
  pop   hl
  ;; HL: addr
  ;; DE: byte
  ;; BC: len
  ld    a, b
  or    a
  jr    nz, # .long-fill
  ld    a, c
  or    a
  jr    z, # .exit
  ld    b, a
.short-loop:
  ld    (hl), e
  inc   hl
  djnz  # .short-loop
  jr    # .exit
.long-fill:
  ld    (hl), e
  ld    de, hl
  inc   de
  dec   bc
  ldir
.exit:
  pop   hl
;code
3 0 Succubus:setters:in-out-args


<zx-system>
primitive: FILL:LIT  ( addr count )  \ [value]
:codegen-xasm
  pop-non-tos-peephole
  ;; TOS: count; non-TOS: addr
  tos-r16 r16l->a
  tos-r16 or-a-r16h
  cond:z jr-cc  ( .skip1 )
  tos-r16 reg:bc r16->r16
  non-tos-r16 tos-r16 r16->r16
  ?curr-node-lit-value c#->(hl)
  inc-de
  dec-bc
  b->a
  or-a-c
  cond:z jr-cc  ( .skip1 .skip )
  ldir
  ;; .skip
  jr-dest!
  ;; .skip1
  jr-dest!
  pop-tos ;


primitive: FILL-NC:LIT  ( addr count )  \ [value]
:codegen-xasm
  pop-non-tos-peephole
  ;; TOS: count; non-TOS: addr
  tos-r16 reg:bc r16->r16
  non-tos-r16 tos-r16 r16->r16
  ?curr-node-lit-value c#->(hl)
  inc-de
  dec-bc
  b->a
  or-a-c
  cond:z jr-cc  ( .skip )
  ldir
  ;; .skip
  jr-dest!
  pop-tos ;


;; load value to (hl) if we have it in the register
primopt: (cgen-find-fill:lit:lit:n)  ( n -- TRUE // n FALSE )
  lo-byte >r
  ;; counter
  ir:curr-node ir:node:value2 1-
  dup lo-byte r@ = ?exit< rdrop drop c->(hl) true >?
  hi-byte r@ = ?exit< rdrop drop b->(hl) true >?
  r> false ;

;; node:value -- value
;; node:value2 -- count
primitive: FILL-NC:LIT:LIT  ( addr )  \ [value](value) [count](value2)
:codegen-xasm
  ?curr-node-lit-value lo-byte
  curr-node node:value2 lo-word
  ( value count )
  dup 0?exit< 2drop pop-tos >?
  ;; one byte?
  dup 1 = ?exit< drop
    c#->a-destructive
    a->(tos)
    pop-tos
  >?
  ;; short fill?
  dup hi-byte 0?exit<
    c#->b
    c#->a-destructive
    $here ( .loop )
    a->(tos)
    inc-tos
    djnz-#
    pop-tos
  >?
  ;; long fill
  1 - #->bc
  tos-r16 non-tos-r16 r16->r16
  inc-de
  (cgen-find-fill:lit:lit:n) not?< c#->(hl) >?
  ldir
  pop-tos ;
<zx-forth>


;; load value to (hl) if we have it in the register
primopt: (cgen-find-fill:lit:lit:lit:n)  ( n -- TRUE // n FALSE )
  lo-byte >r
  ;; counter
  ir:curr-node ir:node:value2 1-
  dup lo-byte r@ = ?exit< rdrop drop c->(hl) true >?
  hi-byte r@ = ?exit< rdrop drop b->(hl) true >?
  ;; source address
  ir:curr-node ir:node:value3
  dup lo-byte r@ = ?exit< rdrop drop l->(hl) true >?
  dup hi-byte r@ = ?exit< rdrop drop h->(hl) true >?
  ;; destination address
  1+
  dup lo-byte r@ = ?exit< rdrop drop e->(hl) true >?
  hi-byte r@ = ?exit< rdrop drop d->(hl) true >?
  r> false ;

;; node:value -- value
;; node:value2 -- count
;; node:value3 -- addr
primitive: FILL-NC:LIT:LIT:LIT  ( -- )  \ [value](value) [count](value2) [addr](value3)
:codegen-xasm
  ?curr-node-lit-value lo-byte
  curr-node node:value2 lo-word
  ( value count )
  dup 0?exit< 2drop >?
  ;; one byte?
  dup 1 = ?exit< drop
    c#->a-destructive
    curr-node node:value3 a->(nn)
  >?
  ;; short fill?
  dup hi-byte 0?exit<
    c#->b
    c#->a-destructive
    curr-node node:value3 non-tos-r16 #->r16
    $here ( .loop )
    a->(non-tos)
    inc-non-tos
    djnz-#
  >?
  ;; long fill
  exx
  curr-node node:value3 dup #->hl
  1+ #->de
  1 - #->bc
  (cgen-find-fill:lit:lit:lit:n) not?< c#->(hl) >?
  ldir
  exx ;
<zx-forth>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CFILL

primitive: CFILL  ( addr len byte )
:codegen-xasm
  pop-bc-peephole  ;; count
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl  ;; byte to DE
  ||
    pop-hl-peephole
  >?
  ;; HL: addr
  ;; DE: byte
  ;; BC: len
  c->a
  or-a-a
  cond:z jr-cc ( .exit )
  c->b
  $here
  e->(hl)
  inc-hl
  djnz-#
  ;; .exit
  jr-dest!
  pop-tos ;

<zx-system>
primitive: CFILL:LIT  ( addr count )
:codegen-xasm
  ?curr-node-lit-value lo-byte
  ( value )
  pop-non-tos-peephole  ;; addr
  ;; TOS: count; non-TOS: addr
  tos-r16 r16l->a
  or-a-a
  cond:z jr-cc   ( value .skip )
  a->b
  swap c#->a-destructive
  ( .skip )
  $here
  ( .skip .loop )
  non-tos-r16 a->(r16)
  inc-non-tos
  djnz-#
  ;; .skip
  jr-dest!
  pop-tos ;

primitive: CFILL-NC:LIT  ( addr count )
:codegen-xasm
  ?curr-node-lit-value lo-byte
  ( value )
  pop-non-tos-peephole  ;; addr
  ;; TOS: count; non-TOS: addr
  tos-r16 reg:bc r16l->r16h
  swap c#->a-destructive
  $here
  ( .loop )
  non-tos-r16 a->(r16)
  inc-non-tos
  djnz-#
  pop-tos ;

primitive: CFILL-NC:LIT:LIT  ( addr )
:codegen-xasm
  ;; TOS: addr
  ?curr-node-lit-value c#->a-destructive
  curr-node node:value2 c#->b
  $here
  ( .loop )
  tos-r16 a->(r16)
  inc-tos
  djnz-#
  pop-tos ;
<zx-forth>

primitive: CFILL-NC  ( addr len byte )
:codegen-xasm
  pop-bc-peephole  ;; count
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl  ;; byte to DE
  ||
    pop-hl-peephole
  >?
  ;; HL: addr
  ;; DE: byte
  ;; BC: len
  c->b
  $here
  e->(hl)
  inc-hl
  djnz-#
  pop-tos ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; XOR-FILL

primitive: XOR-FILL  ( addr len byte )
:codegen-xasm
  pop-bc-peephole  ;; count
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl  ;; byte to DE
  ||
    pop-hl-peephole
  >?
  ;; HL: addr
  ;; DE: byte
  ;; BC: len
  $here
  b->a
  or-a-c
  cond:z jr-cc
  e->a
  xor-a-(hl)
  a->(hl)
  dec-bc
  inc-hl
  jp-#
  jr-dest!
  pop-tos ;

primitive: XOR-CFILL  ( addr byte-len byte )
:codegen-xasm
  pop-bc-peephole  ;; count
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl  ;; byte to DE
  ||
    pop-hl-peephole
  >?
  ;; HL: addr
  ;; DE: byte
  ;; BC: len
  c->a
  or-a-a
  cond:z jr-cc ( .exit )
  c->b
  $here
  e->a
  xor-a-(hl)
  a->(hl)
  inc-hl
  djnz-#
  jr-dest!
  pop-tos ;

primitive: XOR-CFILL-NC  ( addr byte-len byte )
:codegen-xasm
  pop-bc-peephole  ;; count
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl  ;; byte to DE
  ||
    pop-hl-peephole
  >?
  ;; HL: addr
  ;; DE: byte
  ;; BC: len
  c->b
  $here
  e->a
  xor-a-(hl)
  a->(hl)
  inc-hl
  djnz-#
  pop-tos ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CINV-MEM

primitive: CINV-MEM  ( addr byte-len )
:codegen-xasm
  pop-non-tos-peephole
  tos-r16 r16l->a
  or-a-a
  cond:z jr-cc ( .exit )
  a->b
  $here
  non-tos-r16 (r16)->a
  cpl
  non-tos-r16 a->(r16)
  non-tos-r16 inc-r16
  djnz-#
  ;; .exit
  jr-dest!
  pop-tos ;

primitive: CINV-MEM-NC  ( addr byte-len )
:codegen-xasm
  pop-non-tos-peephole
  tos-r16 reg:bc r16l->r16h
  $here
  non-tos-r16 (r16)->a
  cpl
  non-tos-r16 a->(r16)
  non-tos-r16 inc-r16
  djnz-#
  pop-tos ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ERASE

;; load value to (hl) if we have it in the register
primopt: (cgen-find-erase:lit:0)  ( -- done-flag )
  ir:?curr-node-lit-value lo-word 1-
  dup lo-byte 0?exit< drop c->(hl) true >?
  dup hi-byte 0?exit< drop b->(hl) true >?
  drop false ;

<zx-system>
primitive: ERASE-NC:LIT  ( addr )
:codegen-xasm
  ?curr-node-lit-value lo-word
  \ dup not?exit< drop pop-tos-peephole >?
  ;; one byte?
  dup 1 = ?exit< drop
    pop-non-tos-peephole
    TOS-in-HL? ?<
      0 c#->(hl)
    ||
      xor-a-a
      a->(de)
    >?
    TOS-invert!
  >?
  ;; short fill?
  dup hi-byte 0?exit<
    pop-non-tos-peephole
    c#->b
    xor-a-a
    $here ( .loop )
    a->(tos)
    inc-tos
    djnz-#
    TOS-invert!
  >?
  ;; long fill
  TOS-in-HL? ?< hl->de || de->hl >?
  \ TODO: optimise clear
  1- #->bc
  inc-de
  (cgen-find-erase:lit:0) not?< 0 c#->(hl) >?
  ldir
  pop-tos-hl ;

;; load value to (hl) if we have it in the register
primopt: (cgen-find-erase:lit:lit:0)  ( -- done-flag )
  ir:curr-node ir:node:value2
  dup lo-byte 0?exit< drop l->(hl) true >?
  dup hi-byte 0?exit< drop h->(hl) true >?
  1+ lo-word
  dup lo-byte 0?exit< drop e->(hl) true >?
  dup hi-byte 0?exit< drop d->(hl) true >?
  drop
  ir:?curr-node-lit-value 1- lo-word
  dup lo-byte 0?exit< drop c->(hl) true >?
  dup hi-byte 0?exit< drop b->(hl) true >?
  drop false ;

<zx-system>
;; node:value -- count
;; node:value2 -- address
primitive: ERASE-NC:LIT:LIT  ( -- )
:codegen-xasm
  ?curr-node-lit-value lo-word
  \ dup not?exit< drop >?
  ;; one byte?
  dup 1 = ?exit< drop
    xor-a-a
    curr-node node:value2 a->(nn)
  >?
  ;; short fill?
  dup hi-byte 0?exit<
    c#->b
    curr-node node:value2 #->non-tos
    xor-a-a
    $here ( .loop )
    a->(non-tos)
    inc-non-tos
    djnz-#
  >?
  ;; long fill
  exx
  1- #->bc
  curr-node node:value2
  dup #->hl
  1+ #->de
  (cgen-find-erase:lit:lit:0) not?< 0 c#->(hl) >?
  ldir
  exx ;
<zx-forth>

code: ERASE  ( addr len )
  ld    bc, hl
  pop   hl
  ld    a, b
  or    a
  jr    z, # .short-fill
  ld    de, hl
  ld    (hl), # 0
  inc   de
  dec   bc
  ldir
.exit:
  pop   hl
  next
.short-fill:
  ld    a, c
  or    a
  jr    z, # .exit
  ld    b, c
  xor   a
.short-loop:
  ld    (hl), a
  inc   hl
  djnz  # .short-loop
  jr    # .exit
;code
2 0 Succubus:setters:in-out-args

primitive: ERASE-NC  ( addr len )
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?<
    hl->bc
    de->hl
  ||
    de->bc
    hl->de >?
  0 c#->(hl)
  inc-de
  dec-bc
  ldir
  pop-tos-hl ;

primitive: CERASE  ( addr len )
:codegen-xasm
  pop-non-tos-peephole
  tos-r16 r16l->a
  or-a-a
  cond:z jr-cc ( .exit )
  a->b
  xor-a
  $here
  non-tos-r16 a->(r16)
  non-tos-r16 inc-r16
  djnz-#
  ;; .exit
  jr-dest!
  pop-tos ;

primitive: CERASE-NC  ( addr len )
:codegen-xasm
  pop-non-tos-peephole
  tos-r16 reg:bc r16l->r16h
  xor-a
  $here
  non-tos-r16 a->(r16)
  non-tos-r16 inc-r16
  djnz-#
  pop-tos ;
