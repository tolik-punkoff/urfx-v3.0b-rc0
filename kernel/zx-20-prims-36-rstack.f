;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; return stack operations
;; directly included from "zx-20-prims.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level stack words

<zx-system>
primitive: RP@  ( -- rp )
:codegen-xasm
  push-tos
  push-iy
  pop-tos ;

primitive: R0  ( -- r0 )
:codegen-xasm
  push-tos-peephole
  zx-r0 tos-r16 #->r16 ;

primitive: RP0!  ( -- )
:codegen-xasm
  zx-r0 #->iy ;

<zx-forth>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; return stack push, pop, peek, drop

primitive: RPICK  ( u -- x )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  restore-tos-hl
  add-hl-hl
  push-iy
  pop-de
  add-hl-de
  (hl)->e inc-hl
  (hl)->d
  TOS-in-DE! ;

primitive: RTOSS  ( value idx )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  restore-tos-hl
  add-hl-hl
  push-iy
  pop-de
  add-hl-de
  pop-de
  e->(hl) inc-hl
  d->(hl)
  pop-tos ;

primitive: R0:@  ( | n -- n | n )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    0 (iy+#)->l
    1 (iy+#)->h
  ||
    0 (iy+#)->e
    1 (iy+#)->d
  >? ;
alias-for R0:@ is R@

primitive: R0:C@  ( | n -- n | n )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    0 (iy+#)->l
    0 c#->h
  ||
    0 (iy+#)->e
    0 c#->d
  >? ;

primitive: R0:1C@  ( | n -- n | n )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    1 (iy+#)->l
    0 c#->h
  ||
    0 (iy+#)->e
    1 c#->d
  >? ;

primitive: R1:@  ( | a b -- a | a b )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    2 (iy+#)->l
    3 (iy+#)->h
  ||
    2 (iy+#)->e
    3 (iy+#)->d
  >? ;

primitive: R1:C@  ( | a b -- a | a b )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    2 (iy+#)->l
    0 c#->h
  ||
    2 (iy+#)->e
    0 c#->d
  >? ;

primitive: R1:1C@  ( | a b -- a | a b )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    3 (iy+#)->l
    0 c#->h
  ||
    3 (iy+#)->e
    0 c#->d
  >? ;

primitive: R2:@  ( | a b c -- a | a b c )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    4 (iy+#)->l
    5 (iy+#)->h
  ||
    4 (iy+#)->e
    5 (iy+#)->d
  >? ;

primitive: R2:C@  ( | a b c -- a | a b c )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    4 (iy+#)->l
    0 c#->h
  ||
    4 (iy+#)->e
    0 c#->d
  >? ;

primitive: R2:1C@  ( | a b c -- a | a b c )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    5 (iy+#)->l
    0 c#->h
  ||
    5 (iy+#)->e
    0 c#->d
  >? ;

primitive: R3:@  ( | a b c d -- a | a b c d )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    6 (iy+#)->l
    7 (iy+#)->h
  ||
    6 (iy+#)->e
    7 (iy+#)->d
  >? ;

primitive: R3:C@  ( | a b c d -- a | a b c d )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    6 (iy+#)->l
    0 c#->h
  ||
    6 (iy+#)->e
    0 c#->d
  >? ;

primitive: R3:1C@  ( | a b c d -- a | a b c d )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    7 (iy+#)->l
    0 c#->h
  ||
    7 (iy+#)->e
    0 c#->d
  >? ;

primitive: R4:@  ( | a b c d e f -- a | a b c d e f )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    8 (iy+#)->l
    9 (iy+#)->h
  ||
    8 (iy+#)->e
    9 (iy+#)->d
  >? ;

primitive: R4:C@  ( | a b c d e f -- a | a b c d e f )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    8 (iy+#)->l
    0 c#->h
  ||
    8 (iy+#)->e
    0 c#->d
  >? ;

primitive: R4:1C@  ( | a b c d e f -- a | a b c d e f )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    9 (iy+#)->l
    0 c#->h
  ||
    9 (iy+#)->e
    0 c#->d
  >? ;

primitive: R0:!  ( a | n -- | a )
:codegen-xasm
  TOS-in-HL? ?<
    0 l->(iy+#)
    1 h->(iy+#)
  ||
    0 e->(iy+#)
    1 d->(iy+#)
  >?
  pop-tos ;
alias-for R0:! is R!

primitive: R1:!  ( a | n b -- | a b )
:codegen-xasm
  TOS-in-HL? ?<
    2 l->(iy+#)
    3 h->(iy+#)
  ||
    2 e->(iy+#)
    3 d->(iy+#)
  >?
  pop-tos ;

primitive: R2:!  ( a | b c d -- | a c d )
:codegen-xasm
  TOS-in-HL? ?<
    4 l->(iy+#)
    5 h->(iy+#)
  ||
    4 e->(iy+#)
    5 d->(iy+#)
  >?
  pop-tos ;

primitive: R3:!  ( a | b c d e -- | a c d e )
:codegen-xasm
  TOS-in-HL? ?<
    6 l->(iy+#)
    7 h->(iy+#)
  ||
    6 e->(iy+#)
    7 d->(iy+#)
  >?
  pop-tos ;

primitive: R4:!  ( a | b c d e f -- | a c d e f )
:codegen-xasm
  TOS-in-HL? ?<
    8 l->(iy+#)
    9 h->(iy+#)
  ||
    8 e->(iy+#)
    9 d->(iy+#)
  >?
  pop-tos ;

primitive: >R  ( n -- | n )
:codegen-xasm
  [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
    dec-iy dec-yl
  [ELSE]
    dec-iy dec-iy
  [ENDIF]
  TOS-in-HL? ?<
    0 l->(iy+#)
    1 h->(iy+#)
  ||
    0 e->(iy+#)
    1 d->(iy+#)
  >?
  pop-tos ;

primitive: R>  ( | n -- n )
:codegen-xasm
  push-tos-peephole
  TOS-in-HL? ?<
    0 (iy+#)->l
    1 (iy+#)->h
  ||
    0 (iy+#)->e
    1 (iy+#)->d
  >?
  [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
    inc-yl inc-iy
  [ELSE]
    inc-iy inc-iy
  [ENDIF] ;

primopt: (nrdrop-cgen)  ( count )
  dup 0< ?error" wtf in (nrdrop-cgen)!"
  << 0 of?v||
     1 of?v|
      [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
        inc-yl inc-iy
      [ELSE]
        inc-iy inc-iy
      [ENDIF] |?
  else|
    2* #->bc
    add-iy-bc >> ;
<zx-system>

primitive: (RDROP<n>)  ( | <unknown> -- | <unknown> )
:codegen
  ?curr-node-lit-value (nrdrop-cgen) ;
<zx-forth>

primitive: RDROP  ( | n -- )
:codegen  1 (nrdrop-cgen) ;

primitive: 2RDROP  ( | n n -- )
:codegen  2 (nrdrop-cgen) ;

primitive: 3RDROP  ( | n n n -- )
:codegen  3 (nrdrop-cgen) ;

primitive: 4RDROP  ( | n n n n -- )
:codegen  4 (nrdrop-cgen) ;

primitive: N-RDROP  ( n )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  TOS-in-HL? ?<
    ;; we cannot add HL to IY, but can optimise code a little
    add-hl-hl
    restore-tos-de
    add-iy-de
  ||
    add-iy-de
    add-iy-de
  >?
  pop-tos ;
\ TODO: optimiser!


<zx-system>
primitive: (<n>R@)  ( -- x )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  ?curr-node-lit-value 2*
  dup 0 127 within not?error" invalid index in \'(<n>R@)\'!"
  push-tos-peephole
  dup tos-r16 (iy+#)->r16l
  1+ tos-r16 (iy+#)->r16h ;

primitive: (<n>RC@)  ( -- x )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  ?curr-node-lit-value 2*
  dup 0 127 within not?error" invalid index in \'(<n>RC@)\'!"
  push-tos-peephole
  tos-r16 (iy+#)->r16l
  0 tos-r16 c#->r16h ;

primitive: (<n>R1C@)  ( -- x )
Succubus:setters:unknown-in-out-rargs
:codegen-xasm
  ?curr-node-lit-value 2*
  dup 0 127 within not?error" invalid index in \'(<n>RC@)\'!"
  push-tos-peephole
  1+ tos-r16 (iy+#)->r16l
  0 tos-r16 c#->r16h ;
<zx-forth>
