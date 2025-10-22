;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; AND/~AND/OR/XOR/SET/RES
;; directly included from "zx-22-prims-math.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-system>
primitive: ~AND8:LIT  ( au8 -- au8&[~bu8] )
:codegen-xasm
  ?curr-node-lit-value
  ;; if next IR node is a good branch, "and a, # n" should be used,
  ;; because "res" doesn't set flags.
  (cgen-u8-pot?) ?<
    ;; just reset the bit, it is 8ts (vs 15ts)
    tos-r16 swap res-r16l-n
  ||
    tos-r16 r16l->a
    -1 xor lo-byte and-a-c#
    tos-r16 a->r16l
  >? ;

primitive: ~AND8-HI:LIT  ( au8 -- au8&[~bu8] )
:codegen-xasm
  ?curr-node-lit-value lo-byte
  (cgen-u8-pot?) ?<
    ;; just reset the bit, it is 8ts (vs 15ts)
    tos-r16 swap res-r16h-n
  ||
    tos-r16 r16h->a
    -1 xor lo-byte and-a-c#
    tos-r16 a->r16h
  >? ;
<zx-forth>

primitive: ~AND8  ( au8 bu8 -- au8&~bu8 )
:codegen-xasm
  pop-non-tos-peephole
  tos-r16 r16l->a
  cpl
  non-tos-r16 and-a-r16l
  non-tos-r16 a->r16l
  TOS-invert! ;

primitive: ~AND8-HI  ( au8 bu8 -- au8&~{bu8*256} )
:codegen-xasm
  pop-non-tos-peephole
  tos-r16 r16l->a
  cpl
  non-tos-r16 and-a-r16h
  non-tos-r16 a->r16h
  TOS-invert! ;

primitive: ~AND  ( a b -- a&~b )
:codegen-xasm
  pop-non-tos-peephole
  tos-r16 r16l->a
  cpl
  non-tos-r16 and-a-r16l
  tos-r16 a->r16l
  tos-r16 r16h->a
  cpl
  non-tos-r16 and-a-r16h
  tos-r16 a->r16h ;


<zx-system>
primitive: AND8:LIT  ( au8 -- au8&[bu8] )
Succubus:setters:in-8bit
Succubus:setters:out-8bit
:codegen-xasm
  ;; if prev was byte LIT, don't bother clearing
  (cgen-prev-byte-node?) ( skip-clear-flag )
  ?curr-node-lit-value   ( skip-clear-flag value )
  ;; if next IR node is a good branch, "and a, # n" should be used,
  ;; because "res" doesn't set flags.
  (cgen-next-T/0-BRANCH?) ?<
    ;; can we use "bit"? this has sense only if we don't have the result in A already
    (cgen-prev-a->tos-r16l?) not?<
      (cgen-u8-pot?) ?exit<
        nip ;; we don't need clear flag
        tos-r16 swap bit-r16l-n
        ;; that's all, folks!
      >?
    >?
    false
  || (cgen-~u8-pot?) >?
  ?<
    ;; just reset the bit, it is 8ts (vs 15ts)
    tos-r16 swap res-r16l-n
  ||
    ;; if we just loaded the required register from A...
    (cgen-prev-a->tos-r16l?) ?<
      ;; remove the load, and use A directly (it's ok to leave it in place, though)
      1 can-remove-n-last? ?< remove-last-instruction >?
      and-a-c#
    ||
      c#->a
      tos-r16 and-a-r16l
    >?
    tos-r16 a->r16l
  >?
  ;; clear here, for other peephole opts
  not?< 0 tos-r16 c#->r16h >? ;

primitive: AND8-HI:LIT  ( au8 -- au8&[bu8] )
:codegen-xasm
  ?curr-node-lit-value
  ;; if next IR node is a good branch, "and a, # n" should be used,
  ;; because "res" doesn't set flags.
  (cgen-next-T/0-BRANCH?) ?<
    ;; can we use "bit"? this has sense only if we don't have the result in A already
    (cgen-prev-a->tos-r16h?) not?<
      (cgen-u8-pot?) ?exit<
        nip ;; we don't need clear flag
        tos-r16 swap bit-r16h-n
        ;; that's all, folks!
      >?
    >?
    false
  || (cgen-~u8-pot?) >?
  ?<
    ;; just reset the bit, it is 8ts (vs 15ts)
    tos-r16 swap res-r16h-n
  ||
    ;; if we just loaded the required register from A...
    (cgen-prev-a->tos-r16h?) ?<
      ;; remove the load, and use A directly (it's ok to leave it in place, though)
      1 can-remove-n-last? ?< remove-last-instruction >?
      and-a-c#
    ||
      c#->a
      tos-r16 and-a-r16h
    >?
    tos-r16 a->r16h
  >?
  0 tos-r16 c#->r16l ;

primitive: AND:LIT  ( a -- a&[b] )
:codegen-xasm
  ;; we should not come here with high or low bytes equal to zero
  ;; (superoptimiser ensures this), so there is no reason to check for that cases.
  ?curr-node-lit-value
  tos-r16 r16l->a
  dup lo-byte and-a-c#
  tos-r16 a->r16l
  tos-r16 r16h->a
  hi-byte and-a-c#
  tos-r16 a->r16h ;

;; superoptimiser can generate this too
primitive: RES-BIT:LIT  ( a -- a&[~{1<<b}] )
:codegen-xasm
  ;; bit range is always valid here, superoptimiser ensures this
  tos-r16
  ?curr-node-lit-value
  dup 8 >= ?< 8 - res-r16h-n || res-r16l-n >? ;

;; superoptimiser can generate this too
primitive: SET-BIT:LIT  ( a -- a|[~{1<<b}] )
:codegen-xasm
  ;; bit range is always valid here, superoptimiser ensures this
  tos-r16
  ?curr-node-lit-value
  dup 8 >= ?< 8 - set-r16h-n || set-r16l-n >? ;
<zx-forth>


primitive: AND8  ( au8 bu8 -- au8&bu8 )
Succubus:setters:in-8bit
Succubus:setters:out-8bit
:codegen-xasm
  (cgen-prev-byte-node?) ( skip-clear-flag )
  pop-non-tos-peephole
  tos-r16 r16l->a
  non-tos-r16 and-a-r16l
  tos-r16 a->r16l
  not?< 0 tos-r16 c#->r16h >? ;

primitive: AND8-HI  ( u bu8 -- u&{bu8*256} )
:codegen-xasm
  (cgen-prev-byte-node?) ( skip-clear-flag )
  pop-non-tos-peephole
  tos-r16 r16l->a
  non-tos-r16 and-a-r16h
  ;; if prev node is a byte one, we can use faster clear.
  ;; this is because TOS r16h is guaranteed to be 0.
  ?< tos-r16 a->r16h
     0 tos-r16 c#->r16l
  || tos-r16 tos-r16 r16h->r16l
     tos-r16 a->r16h
  >? ;


primitive: AND  ( a b -- a&b )
:codegen-xasm
  pop-non-tos-peephole
  tos-r16 r16l->a
  non-tos-r16 and-a-r16l
  tos-r16 a->r16l
  tos-r16 r16h->a
  non-tos-r16 and-a-r16h
  tos-r16 a->r16h ;


;; common code for OR/XOR 8-bit primitives
primopt: (cgen-mk-bitlog8-op)  ( op-cfa )
  pop-non-tos-peephole
  tos-r16 r16l->a
  non-tos-r16 swap execute
  non-tos-r16 a->r16l
  TOS-invert! ;

;; common code for OR/XOR 8-bit primitives
primopt: (cgen-mk-bitlog8-hi-op)  ( op-cfa )
  pop-non-tos-peephole
  tos-r16 r16l->a
  non-tos-r16 swap execute
  non-tos-r16 a->r16h
  TOS-invert! ;

;; common code for OR/XOR 16-bit primitives
primopt: (cgen-mk-bitlog16-op)  ( oplo-cfa ophi-cfa )
  swap
  pop-non-tos-peephole
  tos-r16 r16l->a
  non-tos-r16 swap execute
  tos-r16 a->r16l
  tos-r16 r16h->a
  non-tos-r16 swap execute
  tos-r16 a->r16h ;


<zx-system>
primitive: OR8:LIT  ( au8 -- au8|[bu8] )
:codegen-xasm
  ?curr-node-lit-value lo-byte
  dup pot +0?exit< pot
    ;; just set the bit, it is 8ts (vs 15ts)
    tos-r16 swap set-r16l-n >?
  c#->a
  tos-r16 or-a-r16l
  tos-r16 a->r16l ;

primitive: OR8-HI:LIT  ( au8 -- au8|[bu8] )
:codegen-xasm
  ?curr-node-lit-value lo-byte
  dup pot +0?exit< pot
    ;; just set the bit, it is 8ts (vs 15ts)
    tos-r16 swap set-r16h-n >?
  c#->a
  tos-r16 or-a-r16h
  tos-r16 a->r16h ;

primitive: OR:LIT  ( a -- a|[b] )
:codegen-xasm
  ;; we should not come here with high or low bytes equal to zero
  ;; (superoptimiser ensures this), so there is no reason to check for that cases.
  ?curr-node-lit-value
  tos-r16 r16l->a
  dup lo-byte or-a-c#
  tos-r16 a->r16l
  tos-r16 r16h->a
  hi-byte or-a-c#
  tos-r16 a->r16h ;
<zx-forth>


primitive: OR8  ( a bu8 -- a|bu8 )
:codegen-xasm
  ['] or-a-r16l (cgen-mk-bitlog8-op) ;

primitive: OR8-HI  ( a bu8 -- a|bu8 )
:codegen-xasm
  ['] or-a-r16h (cgen-mk-bitlog8-hi-op) ;

primitive: OR  ( a b -- a|b )
:codegen-xasm
  ['] or-a-r16l ['] or-a-r16h (cgen-mk-bitlog16-op) ;


<zx-system>
primitive: XOR8:LIT  ( au8 -- au8^[bu8] )
:codegen-xasm
  ?curr-node-lit-value
  c#->a
  tos-r16 xor-a-r16l
  tos-r16 a->r16l ;

primitive: XOR8-HI:LIT  ( au8 -- au8^[bu8] )
:codegen-xasm
  ?curr-node-lit-value
  c#->a
  tos-r16 xor-a-r16h
  tos-r16 a->r16h ;

primitive: XOR:LIT  ( a -- a^[b] )
:codegen-xasm
  ;; we should not come here with high or low bytes equal to zero
  ;; (superoptimiser ensures this), so there is no reason to check for that cases.
  ?curr-node-lit-value
  tos-r16 r16l->a
  dup lo-byte xor-a-c#
  tos-r16 a->r16l
  tos-r16 r16h->a
  hi-byte xor-a-c#
  tos-r16 a->r16h ;
<zx-forth>


primitive: XOR8  ( a bu8 -- a^bu8 )
:codegen-xasm
  ['] xor-a-r16l (cgen-mk-bitlog8-op) ;

primitive: XOR8-HI  ( a bu8 -- a^bu8 )
:codegen-xasm
  ['] xor-a-r16h (cgen-mk-bitlog8-hi-op) ;

primitive: XOR  ( a b -- a^b )
:codegen-xasm
  ['] xor-a-r16l ['] xor-a-r16h (cgen-mk-bitlog16-op) ;
