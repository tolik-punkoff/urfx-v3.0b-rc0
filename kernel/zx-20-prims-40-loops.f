;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; loops
;; directly included from "zx-20-prims.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-system>
;; `CFOR` is always counted backwards, and uses one rstack cell
primitive: (<n>FOR8-I)  ( -- x )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  ?curr-node-lit-value 2*
  dup 0 127 within not?error" invalid index in \'(<n>RC@)\'!"
  push-tos-peephole
  dup 1+ (iy+#)->a  ;; limit
  sub-a-(iy+#)      ;; subtract counter
  tos-r16 a->r16l
  0 tos-r16 c#->r16h ;

primitive: (<n>FOR8-IREV)  ( -- x )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  ?curr-node-lit-value 2*
  dup 0 127 within not?error" invalid index in \'(<n>RC@)\'!"
  push-tos-peephole
  tos-r16 (iy+#)->r16l ;; counter
  0 tos-r16 c#->r16h ;

;; `FOR` is always counted backwards
primitive: (<n>FOR-I)  ( -- x )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  ?curr-node-lit-value 2*
  dup 0 127 within not?error" invalid index in \'(<n>RC@)\'!"
  push-tos-peephole
  dup 2 + (iy+#)->a   ;; limit-lo
  dup sub-a-(iy+#)    ;; subtract counter-lo
  tos-r16 a->r16l
  dup 3 + (iy+#)->a   ;; limit-hi
  1+ sbc-a-(iy+#)     ;; subtract counter-hi
  tos-r16 a->r16h ;

primitive: (<n>FOR-IREV)  ( -- x )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  ?curr-node-lit-value 2*
  dup 0 127 within not?error" invalid index in \'(<n>RC@)\'!"
  push-tos-peephole
  dup tos-r16 (iy+#)->r16l
  1+ tos-r16 (iy+#)->r16h ;


primitive: (LOOP+1)  ( | a b -- | <unknown> )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  0 (iy+#)->a
  1 add-a-c#
  0 a->(iy+#)
  a->c
  1 (iy+#)->a
  0 adc-a-c#
  1 a->(iy+#)
  a->b
  c->a
  2 sub-a-(iy+#)
  b->a
  3 sbc-a-(iy+#)
  cond:m jp-cc negate curr-node node:zx-patch:!
  4 #->bc
  add-iy-bc
  cgen:pop-loop ;

primitive: (LOOP-1)  ( | a b -- | <unknown> )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  0 (iy+#)->a
  -1 add-a-c#
  0 a->(iy+#)
  a->c
  1 (iy+#)->a
  -1 adc-a-c#
  1 a->(iy+#)
  a->b
  2 (iy+#)->a
  sub-a-c
  3 (iy+#)->a
  sbc-a-b
  cond:m jp-cc negate curr-node node:zx-patch:!
  4 #->bc
  add-iy-bc
  cgen:pop-loop ;

primitive: (+LOOP)  ( inc | a b -- | <unknown> )
(*
;; return: carry set if need to continue
  ld    de, # 1
  \ ld    hl, () zx-rp
  ld    a, (iy+) 0
  add   a, e
  ld    0 (iy+), a
  ld    e, a
  \ inc   hl
  ld    a, (iy+) 1
  adc   a, d
  ld    1 (iy+), a
  \ inc   hl
  inc   d
  dec   d
  ld    d, a
  jp    m, # .skip0
  ld    a, e
  sub   (iy+) 2
  ld    a, d
  \ inc   hl
  sbc   a, (iy+) 3
  jp    # .skip1
.skip0:
  ld    a, (iy+) 2
  sub   e
  \ inc   hl
  ld    a, (iy+) 3
  sbc   a, d
.skip1:
  scf
  ret   m   ;; continue if negative!
  \ inc   hl
  \ ld    zx-rp (), hl
  \ inc   bc
  \ inc   bc
  inc iy  inc iy  inc iy  inc iy
  or    a   ;; reset carry
  ret
;code-no-next
*)
Succubus:setters:setup-branch
:codegen-xasm
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl
  ||
    pop-hl-peephole
    TOS-in-HL!
  >?
  ;; TOS in HL, increment in DE
  0 (iy+#)->a
  add-a-e
  0 a->(iy+#)
  a->e
  1 (iy+#)->a
  adc-a-d
  1 a->(iy+#)
  inc-d
  dec-d
  a->d
  cond:m jp-cc  ( .skip0 )
  e->a
  2 sub-a-(iy+#)
  d->a
  3 sbc-a-(iy+#)
  cond:m jp-cc negate curr-node node:zx-patch:!
  jp-somewhere  ( .skip0 .exit )
  swap jp-dest!
  ;; .skip0
  2 (iy+#)->a
  sub-a-e
  3 (iy+#)->a
  sbc-a-d
  cond:m jp-cc curr-node node:zx-patch2:!
  jp-dest!
  ;; .exit
  4 #->bc
  add-iy-bc
  cgen:pop-loop ;


primitive: (DO)  ( limit start | -- | a b )
:codegen-xasm
  -4 #->bc
  add-iy-bc
  TOS-in-HL? ?<
    0 l->(iy+#)
    1 h->(iy+#)
  ||
    0 e->(iy+#)
    1 d->(iy+#)
  >?
  pop-tos-hl
  2 l->(iy+#)
  3 h->(iy+#)
  pop-tos
  cgen:push-curr-loop ;


;; this branches over the loop
primitive: (FOR)  ( limit | -- | a b )
Succubus:setters:setup-branch
Succubus:setters:optimiser: opt-"(FOR)"
:codegen-xasm
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl
  ||
    pop-hl-peephole
    TOS-in-HL!
  >?
  ;; TOS is in HL now, DE is the limit
  d->a
  or-a-a
  cond:m jp-cc  negate curr-node node:zx-patch:!
  or-a-e
  cond:z jp-cc  curr-node node:zx-patch2:!
  -4 #->bc
  add-iy-bc
  dec-de
  ;; put start
  0 e->(iy+#)
  1 d->(iy+#)
  ;; put limit
  2 e->(iy+#)
  3 d->(iy+#)
  cgen:push-curr-loop ;

primitive: (ENDFOR)  ( | a b -- | <unknown> )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  0 (iy+#)->a
  0 dec-(iy+#)
  or-a-a
  cond:nz jp-cc negate curr-node node:zx-patch:!
  ;; overflow
  1 (iy+#)->a
  1 dec-(iy+#)
  or-a-a
  cond:nz jp-cc curr-node node:zx-patch2:!
  4 #->bc
  add-iy-bc
  cgen:pop-loop ;


;; LIT:@ (TOS: DE) value: 50832 ($C690)
;; push  de
;; ld    de, () $C690
;; *** not generated yet ***
;; (FOR8) (TOS: DE)
;; pop   hl
primopt: (cgen-opt-for8-load-de-0?)  ( -- success-flag )
  TOS-in-DE? not?exit&leave
  peep-pattern:[[
    push  de
    ld    de, () {addr}
  ]] peep-match not?exit&leave
  peep: {addr}
  peep-remove-instructions
  ;; replace "PUSH DE" with "EX DE, HL", and don't generate "POP HL"
  ;; this is because we want the loaded limit in DE, and 2nd stack item in HL
  ;; actually, rewrite to:
  ;;   ld  hl, (nn)
  ;;   ex  de, hl
  ;; becase DE holds the value for HL
  (nn)->hl
  ex-de-hl
  TOS-in-HL!
  true ;


;; LIT:@ (TOS: HL) value: 43815 ($AB27)
;; push  hl
;; ld    hl, () $AB27
;; (FOR8) (TOS: HL)
;; *** not generated yet ***
;; pop   de
;; ex    de, hl
primopt: (cgen-opt-for8-load-de-1?)  ( -- success-flag )
  TOS-in-HL? not?exit&leave
  peep-pattern:[[
    push  hl
    ld    hl, () {addr}
  ]] peep-match not?exit&leave
  peep: {addr}
  peep-remove-instructions
  ;; here, HL alread holds the value we want, so load to DE
  (nn)->de
  TOS-in-HL!
  true ;

;; LIT (TOS: HL)
;; push  hl
;; ld    hl, # $0000
;; SWAP (TOS: HL)
;; ex    (sp), hl
;; (FOR8) (TOS: HL)
;; *** not generated yet ***
;; pop   de
;; ex    de, hl
;; result we want:
;;   HL=lit
;;   DE=prev-hl
primopt: (cgen-opt-for8-load-de-2?)  ( -- success-flag )
  TOS-in-HL? not?exit&leave
  peep-pattern:[[
    push  hl
    ld    hl, # {value}
    ex    (sp), hl
  ]] peep-match not?exit&leave
  peep: {value}
  peep-remove-instructions
  ex-de-hl  ;; DE now contains TOS
  #->hl     ;; load new TOS
  TOS-in-HL!
  true ;

;; LIT (TOS: DE)
;; push  de
;; ld    de, # $0000
;; SWAP (TOS: DE)
;; ex    de, hl
;; ex    (sp), hl
;; (FOR8) (TOS: DE)
;; *** not generated yet ***
;; pop   de
;; ex    de, hl
;; result we want:
;;   HL=lit
;;   DE=prev-hl
primopt: (cgen-opt-for8-load-de-3?)  ( -- success-flag )
  TOS-in-DE? not?exit&leave
  peep-pattern:[[
    push  de
    ld    de, # {value}
    ex    de, hl
    ex    (sp), hl
  ]] peep-match not?exit&leave
  peep: {value}
  peep-remove-instructions
  ;; DE already contains TOS
  #->hl     ;; load new TOS
  TOS-in-HL!
  true ;

primopt: (cgen-opt-for8-load-de)
  (cgen-opt-for8-load-de-0?) ?exit
  (cgen-opt-for8-load-de-1?) ?exit
  (cgen-opt-for8-load-de-2?) ?exit
  (cgen-opt-for8-load-de-3?) ?exit
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl
  ||
    pop-hl-peephole
    TOS-in-HL!
  >? ;


;; this branches over the loop.
;; in non-recursive mode we can patch "(ENDFOR8)".
primitive: (FOR8)  ( limit-byte | -- | a )
Succubus:setters:setup-branch
Succubus:setters:optimiser: opt-"(FOR8)"
:codegen-xasm
  (cgen-opt-for8-load-de)
  ;; TOS is in HL now, DE is the limit
  e->a
  or-a-a
  cond:z jp-cc  negate curr-node node:zx-patch:!
  ;; always 8-bit counter
  [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
    dec-iy dec-yl
  [ELSE]
    dec-iy dec-iy
  [ENDIF]
  ;; A holds E here
  ;; put start
  0 a->(iy+#)
  ;; put limit
  1 a->(iy+#)
  cgen:push-curr-loop ;

;; this never over the loop, and does no initial checks.
;; in non-recursive mode we can patch "(ENDFOR8)".
primitive: (FOR8:LIT)  ( | -- | a )
:codegen-xasm
  restore-tos-hl
  ;; always 8-bit counter
  [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
    dec-iy dec-yl
  [ELSE]
    dec-iy dec-iy
  [ENDIF]
  ?curr-node-lit-value
  c#->a-destructive
  ;; put start
  0 a->(iy+#)
  ;; put limit
  1 a->(iy+#)
  cgen:push-curr-loop ;

(*
<zx-done>
extend-module TCOM
;; get loop start node.
;; should be called in ENDFOR/LOOP/+LOOP cgen!
: (cgen-get-for-node) ( -- node^ )
  ir:curr-node ir:node:ir-dest ir:node:prev
  dup ir:node:spfa ir:ir-restore-tos?
  ?< ir:node:prev >? ;

: (?cgen-for8)  ( node^ )
  ir:node:spfa zsys: (FOR8) dart:cfa>pfa =
  not?error" not a \'(FOR8)\' node!" ;

: (?cgen-for)  ( node^ )
  ir:node:spfa zsys: (FOR) dart:cfa>pfa =
  not?error" not a \'(FOR)\' node!" ;

: (?cgen-do)  ( node^ )
  ir:node:spfa zsys: (DO) dart:cfa>pfa =
  not?error" not a \'(DO)\' node!" ;

: (cgen-complex-for?)  ( -- bool )
  ir:nflag-i-used (cgen-get-for-node) dup (?cgen-for8) ir:node-flag? ;

end-module TCOM
<zx-definitions>
<zx-system>
*)

primitive: (ENDFOR8)  ( | a -- | <unknown> )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  0 dec-(iy+#)
  cond:nz jp-cc negate curr-node node:zx-patch:!
  [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
    inc-yl inc-iy
  [ELSE]
    inc-iy inc-iy
  [ENDIF]
  cgen:pop-loop ;


;; ENDFOR dispatcher
primitive: (ENDFORX)  ( | <unknown> -- | <unknown> )
Succubus:setters:setup-branch
:codegen
  0 cgen:(loop#-for8?)
  ?< forth:['] system-shadows:(ENDFOR8)
  || forth:['] system-shadows:(ENDFOR) >?
  dart:cfa>pfa shword:ir-compile execute-tail ;

<zx-forth>
