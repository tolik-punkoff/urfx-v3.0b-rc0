;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; branches
;; directly included from "zx-20-prims.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


primitive: BRANCH  ( -- )
Succubus:setters:setup-branch
Succubus:setters:optimiser: opt-"BRANCH"
:codegen-xasm
  restore-tos-hl
  0 jp-# ;


primopt: (cgen-opt-prev-c@-remove?)  ( -- r16 TRUE // FALSE )
  peep-pattern:[[
    ld    e, (hl)
    ld    d, # 0
  ]] peep-match ?exit<
    TOS-in-DE? not?error" wtf in (cgen-opt-prev-c@?) (00)"
    peep-remove-instructions
    reg:hl
    true
  >?
  peep-pattern:[[
    ld    l, (hl)
    ld    h, # 0
  ]] peep-match ?exit<
    TOS-in-HL? not?error" wtf in (cgen-opt-prev-c@?) (01)"
    peep-remove-instructions
    reg:hl  ;; not a bug! we return the register from which we are reading
    true
  >?
  false ;


primopt: (cgen-opt-push-pop?)  ( -- skip-pop-flag )
  OPT-OPTIMIZE-PEEPHOLE? not?exit&leave
  1 can-remove-n-last? not?exit&leave
  last-push-tos? dup not?< drop last-push-non-tos? >?
  ?exit<
    remove-last-instruction stat-push-pop-removed:1+!
    true
  >?
  false ;

;; remove "LD tos-r16l, a" or  "LD tos-r16h, a"
primopt: (cgen-opt-remove-"a->tosr16lh")
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    h, a
    ]] peep-match ?exit< peep-remove-instructions >?
    peep-pattern:[[
      ld    l, a
    ]] peep-match ?exit< peep-remove-instructions >?
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    d, a
    ]] peep-match ?exit< peep-remove-instructions >?
    peep-pattern:[[
      ld    e, a
    ]] peep-match ?exit< peep-remove-instructions >?
  >? ;

primopt: (cgen-prev-node-zflag-set?)  ( -- bool )
  OPT-OPTIMIZE-PEEPHOLE? not?exit&leave
  ir:prev-node-spfa dup -0?exit< drop false >?
  dup ir:opt:(opt-zx-and8) = ?exit< drop true >?
  dup ir:opt:(opt-zx-and8:lit) = ?exit< drop true >?
  dup ir:opt:(opt-zx-and8-hi:lit) = ?exit< drop true >?
  drop false ;


primopt: (cgen-opt-"a->tos-r16l"?)  ( -- bool )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    l, a
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    e, a
    ]]
  >?
  peep-match ;

primopt: (cgen-opt-"a->tos-r16h"?)  ( -- bool )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    h, a
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    d, a
    ]]
  >?
  peep-match ;

primopt: (cgen-gen-0/t-branch-0cmp)
  2 can-remove-n-last? ?<
    (cgen-opt-prev-c@-remove?) ?exit<
      ;; remove "push hl / pop hl"
      (cgen-opt-push-pop?) swap
      ( pop-tos-flag r16 )
      (r16)->a
      or-a-a
      ?< restore-tos-hl || pop-tos-hl >?
      zx-stats-peepbranch:1+!
    >?
  >?
  (cgen-prev-node-zflag-set?) ?exit<
    ;; zero flag is already set as we need it
    (cgen-opt-remove-"a->tosr16lh")
    pop-tos-hl
  >?
  (cgen-opt-"a->tos-r16l"?) ?exit<
    tos-r16 or-a-r16h
    pop-tos-hl
  >?
  (cgen-opt-"a->tos-r16h"?) ?exit<
    tos-r16 or-a-r16l
    pop-tos-hl
  >?
  tos-r16 r16l->a
  tos-r16 or-a-r16h
  pop-tos-hl ;
<zx-system>


primitive: 2DUP/OR/0BRANCH  ( a b -- a b )
Succubus:setters:setup-branch
:codegen-xasm
  pop-non-tos-peephole
  push-non-tos
  restore-tos-hl
  tos-r16 r16h->a
  tos-r16 or-a-r16l
  non-tos-r16 or-a-r16h
  non-tos-r16 or-a-r16l
  0 cond:z jp-#-cc ;

primitive: 2DUP/OR/TBRANCH  ( a b -- a b )
Succubus:setters:setup-branch
:codegen-xasm
  pop-non-tos-peephole
  push-non-tos
  restore-tos-hl
  tos-r16 r16h->a
  tos-r16 or-a-r16l
  non-tos-r16 or-a-r16h
  non-tos-r16 or-a-r16l
  0 cond:nz jp-#-cc ;

primitive: 2DUP/OR/+0BRANCH  ( a b -- a b )
Succubus:setters:setup-branch
:codegen-xasm
  pop-non-tos-peephole
  push-non-tos
  restore-tos-hl
  tos-r16 r16h->a
  non-tos-r16 or-a-r16h
  0 cond:p jp-#-cc ;

primitive: 2DUP/OR/-BRANCH  ( a b -- a b )
Succubus:setters:setup-branch
:codegen-xasm
  pop-non-tos-peephole
  push-non-tos
  restore-tos-hl
  tos-r16 r16h->a
  non-tos-r16 or-a-r16h
  0 cond:m jp-#-cc ;


primopt: (cgen-gen-r>-or)
  restore-tos-hl
  [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
    inc-yl inc-iy
  [ELSE]
    inc-iy inc-iy
  [ENDIF]
  -1 (iy+#)->a
  -2 or-a-(iy+#) ;

primopt: (cgen-gen-r>-or-hi)
  restore-tos-hl
  1 (iy+#)->a
  [ OPT-RSTACK-ALWAYS-ALIGNED? ] [IF]
    inc-yl inc-iy
  [ELSE]
    inc-iy inc-iy
  [ENDIF]
  or-a-a ;

primitive: R>/0BRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-gen-r>-or)
  0 cond:z jp-#-cc ;

primitive: R>/TBRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-gen-r>-or)
  0 cond:nz jp-#-cc ;

primitive: R>/+0BRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-gen-r>-or-hi)
  0 cond:p jp-#-cc ;

primitive: R>/-BRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-gen-r>-or-hi)
  0 cond:m jp-#-cc ;


primitive: LIT:@/0BRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value
  (nn)->de
  e->a
  or-a-d
  0 cond:z jp-#-cc ;

primitive: LIT:@/TBRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value
  (nn)->de
  e->a
  or-a-d
  0 cond:nz jp-#-cc ;

primitive: LIT:@/-BRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value
  1+ (nn)->a
  or-a-a
  0 cond:m jp-#-cc ;

primitive: LIT:@/+0BRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value
  1+ (nn)->a
  or-a-a
  0 cond:p jp-#-cc ;


primitive: LIT:C@/0BRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value
  (nn)->a
  or-a-a
  0 cond:z jp-#-cc ;

primitive: LIT:C@/TBRANCH  ( -- )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value
  (nn)->a
  or-a-a
  0 cond:nz jp-#-cc ;


primitive: 0BRANCH  ( n )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-prev-out-bool?) ?exit<
    (cgen-gen-ld-tosr16l-a)
    TOS-in-HL? ?<
      peep-pattern:[[
        ld    a, l
      ]] peep-match ?<
        peep-remove-instructions
        dec-l
      ||
        dec-a
      >?
    || TOS-in-DE? not?error" ICE: TOS not in HL/DE!"
      peep-pattern:[[
        ld    a, e
      ]] peep-match ?<
        peep-remove-instructions
        dec-e
      ||
        dec-a
      >?
    >?
    ;; zero flag is set if A was 1
    pop-tos-hl
    0 cond:nz jp-#-cc
  >?
  (cgen-gen-0/t-branch-0cmp)
  0 cond:z jp-#-cc ;

primitive: TBRANCH  ( n )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-prev-out-bool?) ?exit<
    (cgen-gen-ld-tosr16l-a)
    TOS-in-HL? ?<
      peep-pattern:[[
        ld    a, l
      ]] peep-match ?<
        peep-remove-instructions
        dec-l
      ||
        dec-a
      >?
    || TOS-in-DE? not?error" ICE: TOS not in HL/DE!"
      peep-pattern:[[
        ld    a, e
      ]] peep-match ?<
        peep-remove-instructions
        dec-e
      ||
        dec-a
      >?
    >?
    ;; zero flag is set if A was 1
    pop-tos-hl
    0 cond:z jp-#-cc
  >?
  (cgen-gen-0/t-branch-0cmp)
  0 cond:nz jp-#-cc ;


;; push  hl
;; -BRANCH (TOS: DE)
;; bit   7, d
;; pop   hl
primopt: (cgen-xbranch-TOS-DE-push-hl?)  ( -- push-removed? )
  TOS-in-DE? not?exit&leave
  peep-pattern:[[
    push  hl
  ]] peep-match not?exit&leave
  peep-remove-instructions
  TOS-in-HL!
  true ;

;; SWAP (TOS: HL)
;; ex    (sp), hl
;; +0BRANCH (TOS: HL)
;; bit   7, h
;; pop   hl
;;   rewrite to:
;; pop   de
;; bit   7, d
primopt: (cgen-xbranch-TOS-HL-swap?)  ( -- swap-removed? )
  TOS-in-HL? not?exit&leave
  peep-pattern:[[
    ex    (sp), hl
  ]] peep-match not?exit&leave
  peep-remove-instructions
  pop-de
  reg:de 7 bit-r16h-n
  true ;


primitive: -BRANCH  ( n )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-xbranch-TOS-HL-swap?) ?exit<
    0 cond:nz jp-#-cc
  >?
  TOS-in-HL? ?<
    ;; OR
    ;; -BRANCH
    peep-pattern:[[
      or    d
      ld    h, a
    ]] peep-match ?exit<
      ;; all required flags are already set
      remove-last-instruction
      pop-tos-hl
      0 cond:m jp-#-cc
    >?
  >?
  TOS-in-DE? ?<
    ;; OR
    ;; -BRANCH
    peep-pattern:[[
      or    h
      ld    d, a
    ]] peep-match ?exit<
      ;; all required flags are already set
      remove-last-instruction
      pop-tos-hl
      0 cond:m jp-#-cc
    >?
  >?
  (cgen-xbranch-TOS-DE-push-hl?) ( push-removed? )
  ;; WARNING! if push was removed, TOS was in DE, and we should check D!
  dup ?< reg:de || tos-r16 >? 7 bit-r16h-n
  not?< pop-tos-hl >?
  0 cond:nz jp-#-cc ;

primitive: +0BRANCH  ( n )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-xbranch-TOS-HL-swap?) ?exit<
    0 cond:z jp-#-cc
  >?
  TOS-in-HL? ?<
    ;; OR
    ;; +0BRANCH
    peep-pattern:[[
      or    d
      ld    h, a
    ]] peep-match ?exit<
      ;; all required flags are already set
      remove-last-instruction
      pop-tos-hl
      0 cond:p jp-#-cc
    >?
  >?
  TOS-in-DE? ?<
    ;; OR
    ;; -BRANCH
    peep-pattern:[[
      or    h
      ld    d, a
    ]] peep-match ?exit<
      ;; all required flags are already set
      remove-last-instruction
      pop-tos-hl
      0 cond:p jp-#-cc
    >?
  >?
  (cgen-xbranch-TOS-DE-push-hl?) ( push-removed? )
  ;; WARNING! if push was removed, TOS was in DE, and we should check D!
  dup ?< reg:de || tos-r16 >? 7 bit-r16h-n
  not?< pop-tos-hl >?
  0 cond:z jp-#-cc ;


primitive: -0BRANCH  ( n )
Succubus:setters:setup-branch
:codegen-xasm
  2 can-remove-n-last? ?<
    (cgen-opt-prev-c@-remove?) ?exit<
      (r16)->a
      or-a-a
      pop-tos-hl
      0 cond:z jp-#-cc
      zx-stats-peepbranch:1+!
    >?
  >?
  ;; by DW0RKiN
  tos-r16 r16h->a     ;; save sign
  tos-r16 dec-r16     ;; zero to negative
  tos-r16 or-a-r16h
  pop-tos-hl
  0 cond:m jp-#-cc ;

primitive: +BRANCH  ( n )
Succubus:setters:setup-branch
:codegen-xasm
  ;; by DW0RKiN
  tos-r16 r16h->a    ;; save sign
  tos-r16 dec-r16     ;; zero to negative
  tos-r16 or-a-r16h
  pop-tos-hl
  0 cond:p jp-#-cc ;


;; "LD DE, BC"
primopt: (cgen-brn-good-ld-de-bc?)  ( -- success-flag )
  TOS-in-HL? not?exit&leave
  peep-pattern:[[
    ld    d, b
    ld    e, c
  ]] peep-match ?exit&leave
  peep-pattern:[[
    ld    e, c
    ld    d, b
  ]] peep-match ;

primopt: (cgen-brn-gen-sbc-hl-de-HL=a)
  pop-non-tos-peephole
  ;;TOS=HL: HL=b; DE=a
  ;;TOS=DE: HL=a; DE=b
  TOS-in-HL? ?< ex-de-hl
  ||
    (cgen-brn-good-ld-de-bc?) ?exit<
      remove-last-instruction
      xor-a-a
      sbc-hl-bc
    >?
  >?
  ;; HL:a; DE:b
  xor-a-a
  sbc-hl-de ;

primopt: (cgen-brn-gen-sbc-hl-de-HL=b)
  pop-non-tos-peephole
  ;;TOS=HL: HL=b; DE=a
  ;;TOS=DE: HL=a; DE=b
  TOS-in-DE? ?< ex-de-hl
  ||
    (cgen-brn-good-ld-de-bc?) ?exit<
      remove-last-instruction
      xor-a-a
      sbc-hl-bc
    >?
  >?
  ;; HL:b; DE:a
  xor-a-a
  sbc-hl-de ;


primitive: =BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  pop-non-tos-peephole
  (cgen-brn-good-ld-de-bc?) ?<
    remove-last-instruction
    xor-a-a
    sbc-hl-bc
  ||
    xor-a-a
    sbc-hl-de
  >?
  pop-tos-hl
  0 cond:z jp-#-cc ;

primitive: <>BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  pop-non-tos-peephole
  (cgen-brn-good-ld-de-bc?) ?<
    remove-last-instruction
    xor-a-a
    sbc-hl-bc
  ||
    xor-a-a
    sbc-hl-de
  >?
  pop-tos-hl
  0 cond:nz jp-#-cc ;

primitive: <BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-brn-gen-sbc-hl-de-HL=a)
  ;; HL:a; DE:b
  ;; a-b: jump on negative
  pop-tos-hl
  0 cond:m jp-#-cc ;

primitive: >BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-brn-gen-sbc-hl-de-HL=b)
  ;; HL:b; DE:a
  ;; b-a: jump on negative
  pop-tos-hl
  0 cond:m jp-#-cc ;

primitive: >=BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-brn-gen-sbc-hl-de-HL=a)
  ;; HL:a; DE:b
  ;; a-b: jump if positive
  pop-tos-hl
  0 cond:p jp-#-cc ;

primitive: <=BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-brn-gen-sbc-hl-de-HL=b)
  ;; HL:b; DE:a
  ;; b-a: jump if positive
  pop-tos-hl
  0 cond:p jp-#-cc ;


primitive: U<BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-brn-gen-sbc-hl-de-HL=a)
  ;; HL:a; DE:b
  ;; a-b: jump if carry
  pop-tos-hl
  0 cond:c jp-#-cc ;

primitive: U>BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-brn-gen-sbc-hl-de-HL=b)
  ;; HL:b; DE:a
  ;; b-a: jump if carry
  pop-tos-hl
  0 cond:c jp-#-cc ;

primitive: U>=BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-brn-gen-sbc-hl-de-HL=a)
  ;; HL:a; DE:b
  ;; a-b: jump if no carry
  pop-tos-hl
  0 cond:nc jp-#-cc ;

primitive: U<=BRANCH  ( a b )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-brn-gen-sbc-hl-de-HL=b)
  ;; HL:b; DE:a
  ;; b-a: jump if no carry
  pop-tos-hl
  0 cond:nc jp-#-cc ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; non-destructive branches

;; ld    l, a
;; ld    h, # $00
;; 0BRANCH-ND (TOS: HL)
primopt: (cgen-opt-0BRANCH-ND-LIT:C@-0)  ( -- success-flag )
  TOS-in-HL? not?exit&leave
  peep-pattern:[[
    ld    l, a
    ld    h, # 0
  ]] peep-match ;

;; ld    e, a
;; ld    d, # $00
;; 0BRANCH-ND (TOS: HL)
primopt: (cgen-opt-0BRANCH-ND-LIT:C@-1)  ( -- success-flag )
  TOS-in-DE? not?exit&leave
  peep-pattern:[[
    ld    e, a
    ld    d, # 0
  ]] peep-match ;


primitive: 0BRANCH-ND  ( n -- n )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-opt-0BRANCH-ND-LIT:C@-0) ?exit<
    or-a-a
    restore-tos-hl
    0 cond:z jp-#-cc
  >?
  (cgen-opt-0BRANCH-ND-LIT:C@-1) ?exit<
    or-a-a
    restore-tos-hl
    0 cond:z jp-#-cc
  >?
  restore-tos-hl
  ;; if previous is "0=", zero flag is reset if TOS=0
  ir:opt:(opt-zx-"0=") prev-node-spfa = ?exit<
    0 cond:nz jp-#-cc
  >?
  ;; if previous is "0<>", zero flag is set if TOS=0
  ir:opt:(opt-zx-"0<>") prev-node-spfa = ?exit<
    0 cond:z jp-#-cc
  >?
  tos-r16 r16l->a
  tos-r16 or-a-r16h
  0 cond:z jp-#-cc ;

primitive: TBRANCH-ND  ( n -- n )
Succubus:setters:setup-branch
:codegen-xasm
  (cgen-opt-0BRANCH-ND-LIT:C@-0) ?exit<
    or-a-a
    restore-tos-hl
    0 cond:nz jp-#-cc
  >?
  (cgen-opt-0BRANCH-ND-LIT:C@-1) ?exit<
    or-a-a
    restore-tos-hl
    0 cond:nz jp-#-cc
  >?
  restore-tos-hl
  ;; if previous is "0=", zero flag is set if TOS<>0
  ir:opt:(opt-zx-"0=") prev-node-spfa = ?exit<
    0 cond:z jp-#-cc
  >?
  ;; if previous is "0<>", zero flag is reset if TOS<>0
  ir:opt:(opt-zx-"0<>") prev-node-spfa = ?exit<
    0 cond:nz jp-#-cc
  >?
  tos-r16 r16l->a
  tos-r16 or-a-r16h
  0 cond:nz jp-#-cc ;

primopt: (cgen-brncheck-prev-good-sbc?)  ( -- flag )
  TOS-in-HL? not?exit&leave
  peep-pattern:[[
    sbc   hl, de
  ]] peep-match ;

primitive: -BRANCH-ND  ( n -- n )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  (cgen-brncheck-prev-good-sbc?) ?<
    0 cond:m jp-#-cc
  ||
    tos-r16 7 bit-r16h-n
    0 cond:nz jp-#-cc
  >? ;

primitive: +0BRANCH-ND  ( n -- n )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  (cgen-brncheck-prev-good-sbc?) ?<
    0 cond:p jp-#-cc
  ||
    tos-r16 7 bit-r16h-n
    0 cond:z jp-#-cc
  >? ;

primitive: -0BRANCH-ND  ( n -- n )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ;; by DW0RKiN
  h->a    ;; save sign
  dec-hl  ;; zero to negative
  or-a-h
  inc-hl  ;; restore TOS
  0 cond:m jp-#-cc ;

primitive: +BRANCH-ND  ( n -- n )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ;; by DW0RKiN
  h->a    ;; save sign
  dec-hl  ;; zero to negative
  or-a-h
  inc-hl  ;; restore TOS
  0 cond:p jp-#-cc ;

primitive: =BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  ;; if TOS in HL, we can POP DE and use SBC; DE will become a new HL TOS
  TOS-in-HL? ?<
    pop-non-tos-peephole  ;; DE
    ;; HL:b; DE:a
    ;; 4+15+4=23
    xor-a-a
    sbc-hl-de
    ex-de-hl
  ||
    nd-branch-pop
    ;; 4+4+4+4+4+4=24
    l->a
    xor-e
    a->e
    h->a
    xor-d
    or-e
  >?
  0 cond:z jp-#-cc ;

primitive: <>BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  ;; if TOS in HL, we can POP DE and use SBC; DE will become a new HL TOS
  TOS-in-HL? ?<
    pop-non-tos-peephole  ;; DE
    ;; HL:b; DE:a
    ;; 4+15+4=23
    xor-a-a
    sbc-hl-de
    ex-de-hl
  ||
    nd-branch-pop
    ;; 4+4+4+4+4+4=24
    l->a
    xor-e
    a->e
    h->a
    xor-d
    or-e
  >?
  0 cond:nz jp-#-cc ;

primitive: <BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  nd-branch-pop
  ;; a-b: jump on negative
  ;; HL=a; DE=b
  ;; a-b
  l->a
  sub-a-e
  h->a
  sbc-a-d
  0 cond:m jp-#-cc ;

primitive: >BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  nd-branch-pop
  ;; b-a: jump on negative
  ;; HL=a; DE=b
  ;; b-a
  ;; 4+4+4+4=16
  e->a
  sub-a-l
  d->a
  sbc-a-h
  0 cond:m jp-#-cc ;

primitive: >=BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  nd-branch-pop
  ;; a-b: jump on positive
  ;; HL=a; DE=b
  ;; a-b
  l->a
  sub-a-e
  h->a
  sbc-a-d
  0 cond:p jp-#-cc ;

primitive: <=BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  nd-branch-pop
  ;; b-a: jump on positive
  ;; HL=a; DE=b
  ;; b-a
  e->a
  sub-a-l
  d->a
  sbc-a-h
  0 cond:p jp-#-cc ;

primitive: U<BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  nd-branch-pop
  ;; a-b: jump on carry
  ;; HL=a; DE=b
  ;; a-b
  l->a
  sub-a-e
  h->a
  sbc-a-d
  0 cond:c jp-#-cc ;

primitive: U>BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  nd-branch-pop
  ;; b-a: jump on carry
  ;; HL=a; DE=b
  ;; b-a
  e->a
  sub-a-l
  d->a
  sbc-a-h
  0 cond:c jp-#-cc ;

primitive: U>=BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  nd-branch-pop
  ;; a-b: jump on no carry
  ;; HL=a; DE=b
  ;; a-b
  l->a
  sub-a-e
  h->a
  sbc-a-d
  0 cond:nc jp-#-cc ;

primitive: U<=BRANCH-ND  ( a b -- a )
Succubus:setters:setup-branch
:codegen-xasm
  nd-branch-pop
  ;; b-a: jump on carry
  ;; HL=a; DE=b
  ;; b-a
  e->a
  sub-a-l
  d->a
  sbc-a-h
  0 cond:nc jp-#-cc ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; non-destructive branches with embedded literal

primitive: =BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    ;; with 0, should not happen, but ok
    l->a
    or-a-h
    0 cond:z jp-#-cc
  >?
  ;; TOS should be in HL
  dup hi-byte 0?exit<
    ;; compare with lo byte, hi byte is 0
    lo-byte c#->a
    sub-a-l
    or-a-h
    0 cond:z jp-#-cc
  >?
  dup lo-byte 0?exit<
    ;; compare with hi byte, lo byte is 0
    hi-byte c#->a
    sub-a-h
    or-a-l
    0 cond:z jp-#-cc
  >?
  ;; compare with full word
  ;; TOS is guaranteed to be in HL
  ;; we cannot destroy HL, alas
  dup lo-byte c#->a
  xor-l
  a->e
  hi-byte c#->a
  xor-h
  or-e
  0 cond:z jp-#-cc ;

primitive: <>BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    ;; with 0, should not happen, but ok
    l->a
    or-a-h
    0 cond:nz jp-#-cc
  >?
  ;; TOS should be in HL
  dup hi-byte 0?exit<
    ;; compare with lo byte, hi byte is 0
    lo-byte c#->a
    sub-a-l
    or-a-h
    0 cond:nz jp-#-cc
  >?
  dup lo-byte 0?exit<
    ;; compare with hi byte, lo byte is 0
    hi-byte c#->a
    sub-a-h
    or-a-l
    0 cond:nz jp-#-cc
  >?
  ;; compare with full word
  ;; TOS is guaranteed to be in HL
  ;; we cannot destroy HL, alas
  dup lo-byte c#->a
  xor-l
  a->e
  hi-byte c#->a
  xor-h
  or-e
  0 cond:nz jp-#-cc ;

primitive: <BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    7 bit-h-n
    0 cond:nz jp-#-cc >?
  \ FIXME: optimise this!
  dup lo-byte 0?exit<
    ;; hi-byte only
    h->a
    hi-byte sub-a-c#
    0 cond:m jp-#-cc
  >?
  ;; a-lit: jump on negative
  ;; we cannot destroy HL, alas
  l->a
  dup lo-byte sub-a-c#
  h->a
  hi-byte sbc-a-c#
  0 cond:m jp-#-cc ;

primitive: >BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    ;; this should not happen anyway
    error" ICE: >BRANCH-ND:LIT:0 should not happen!" >?
  \ FIXME: optimise this!
  ;; lit-a: jump on negative
  ;; we cannot destroy HL, alas
  dup lo-byte c#->a
  sub-a-l
  hi-byte c#->a
  sbc-a-h
  0 cond:m jp-#-cc ;

primitive: >=BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    7 bit-h-n
    0 cond:z jp-#-cc >?
  \ FIXME: optimise this!
  dup lo-byte 0?exit<
    ;; hi-byte only
    h->a
    hi-byte sub-a-c#
    0 cond:p jp-#-cc
  >?
  ;; a-lit: jump on positive
  ;; we cannot destroy HL, alas
  l->a
  dup lo-byte sub-a-c#
  h->a
  hi-byte sbc-a-c#
  0 cond:p jp-#-cc ;

primitive: <=BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    ;; this should not happen anyway
    error" ICE: <=BRANCH-ND:LIT:0 should not happen!" >?
  \ FIXME: optimise this!
  ;; lit-a: jump on positive
  ;; we cannot destroy HL, alas
  dup lo-byte c#->a
  sub-a-l
  hi-byte c#->a
  sbc-a-h
  0 cond:p jp-#-cc ;

primitive: U<BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    ;; a U< 0: never true
    error" ICE: U<BRANCH-ND:LIT:0 should not happen!"
    scf
    0 cond:nc jp-#-cc >?
  \ FIXME: optimise this!
  dup lo-byte 0?exit<
    ;; hi-byte only
    h->a
    hi-byte sub-a-c#
    0 cond:c jp-#-cc
  >?
  ;; a-lit: jump on carry
  ;; we cannot destroy HL, alas
  l->a
  dup lo-byte sub-a-c#
  h->a
  hi-byte sbc-a-c#
  0 cond:c jp-#-cc ;

primitive: U>BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    ;; this should not happen anyway
    ;; a U> 0 --> a<>0
    l->a
    or-a-h
    0 cond:nz jp-#-cc >?
  \ FIXME: optimise this!
  ;; lit-a: jump on carry
  ;; we cannot destroy HL, alas
  dup lo-byte c#->a
  sub-a-l
  hi-byte c#->a
  sbc-a-h
  0 cond:c jp-#-cc ;

primitive: U>=BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    ;; a U>= 0: never false
    0 jp-# >?
  \ FIXME: optimise this!
  dup lo-byte 0?exit<
    ;; hi-byte only
    h->a
    hi-byte sub-a-c#
    0 cond:nc jp-#-cc
  >?
  ;; a-lit: jump on no carry
  ;; we cannot destroy HL, alas
  l->a
  dup lo-byte sub-a-c#
  h->a
  hi-byte sbc-a-c#
  0 cond:nc jp-#-cc ;

primitive: U<=BRANCH-ND:LIT  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  restore-tos-hl
  ?curr-node-lit-value dup 0?exit< drop
    ;; this should not happen anyway
    ;; a U<= 0 --> a = 0
    l->a
    or-a-h
    0 cond:z jp-#-cc >?
  \ FIXME: optimise this!
  ;; lit-a: jump on no carry
  ;; we cannot destroy HL, alas
  dup lo-byte c#->a
  sub-a-l
  hi-byte c#->a
  sbc-a-h
  0 cond:nc jp-#-cc ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; destructive branches with embedded literal

primopt: (cgen-branch-gen-"TOS-LIT"-sign)  ( lit-value )
  ;; 4+7+4+7=22
  tos-r16 r16l->a
  dup lo-byte sub-a-c#
  tos-r16 r16h->a
  hi-byte sbc-a-c#
;

primopt: (cgen-branch-gen-"LIT-TOS"-sign)  ( lit-value )
  ;; LIT-TOS
  ;; we cannot easily negate TOS, so it is not commutative
  dup c#->a-destructive
  tos-r16 sub-a-r16l
  hi-byte c#->a
  tos-r16 sbc-a-r16h
;


;; generate proper zero flag
primopt: (cgen-branch-gen-"LIT-TOS"-zero)  ( lit-value )
  dup lo-byte 0?exit<
    ;; compare with hi byte, lo byte is 0
    hi-byte c#->a
    tos-r16 sub-a-r16h
    tos-r16 or-a-r16l
  >?
  ;; we need the proper zero flag here, oops
  ;; 7+4+4+7+4+4=30 (with loading A)
  dup lo-byte 0?exit<
    ;; 4+4+4+7+4+4=27
    xor-a-a
    tos-r16 sub-a-r16l
    tos-r16 a->r16l
    hi-byte c#->a
    tos-r16 sbc-a-r16h
    tos-r16 or-a-r16l
  >?
  ;; if we need to load A, then the above is 30ts,
  ;; but this is: 10+4+15=29
  negate lo-word non-tos-r16 #->r16
  xor-a-a
  sbc-hl-de
;


;; just to make the code more clean
primopt: (cgen-branch-gen-"TOS-LIT"-carry)  ( lit-value )
  (cgen-branch-gen-"TOS-LIT"-sign) ;

;; just to make the code more clean
primopt: (cgen-branch-gen-"LIT-TOS"-carry)  ( lit-value )
  (cgen-branch-gen-"LIT-TOS"-sign) ;


primopt: (cgen-branch-gen-jp-not-taken)
  pop-tos-hl
  xor-a-a
  0 cond:nz jp-#-cc ;

primopt: (cgen-branch-gen-jp-taken)
  pop-tos-hl
  0 jp-# ;


primopt: (cgen-branch-gen-jp-not-taken-no-pop)
  xor-a-a
  0 cond:nz jp-#-cc ;

primopt: (cgen-branch-gen-jp-taken-no-pop)
  0 jp-# ;


primopt: (cgen-opt-tos-h=0?)  ( -- flag )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    h, # 0
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    l, # 0
    ]]
  >? peep-match ;


;; (ir-walit:c@) (TOS: HL) value: 47056 ($B7D0)
;; TOS=HL
;;   push  hl
;;   ld    hl, () $B7D0
;; TOS=DE
;;   push  de
;;   ld    de, () $B7DC
;; >=BRANCH:LIT
;; 8-bit, we can load directly to A

;; also, removes the corresponding load, and forces TOS to be in HL
primopt: (cgen-opt-branch-lit:c@?)  ( -- zx-addr TRUE // FALSE )
  TOS-in-HL? ?<
    peep-pattern:[[
      push  hl
      ld    hl, () {addr}
    ]] peep-match not?exit&leave
    peep: {addr}
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      push  de
      ld    de, () {addr}
    ]] peep-match not?exit&leave
    peep: {addr}
  >?
  peep-remove-instructions
  restore-tos-hl
  true ;

;; ex    de, hl
;; ld    hl, # {addr}
;; inc   (hl)
;; LIT:C@ (TOS: DE) value: 47068 ($B7DC)
;; <BRANCH:LIT (TOS: DE) value: 10 ($000A)
;; ex    de, hl
primopt: (cgen-opt-branch-can-load-de?)  ( addr -- addr bool )
  peep-pattern:[[
    ex    de, hl
    ld    hl, # {addr}
    inc   (hl)
    ex    de, hl
  ]] peep-match not?exit&leave
  dup peep: {addr} = ;

primopt: (cgen-opt-branch-load-a-nn)  ( zx-addr )
  (cgen-opt-branch-can-load-de?) ?exit< drop (de)->a >?
  (nn)->a ;


;; "lit:c@" should be already removed, TOS stored in HL
primopt: (cgen-branch-gen-lit:c@:LIT-TOS)  ( litvalue zx-addr )
  TOS-in-HL? not?error" ICE: invariant violation in \'(cgen-branch-gen-walit:c@:LIT-TOS)\'!"
  1 can-remove-n-last? ?<
    (cgen-opt-branch-can-load-de?) ?<
      drop  ;; drop address
      remove-last-instruction ;; it is "EX DE, HL"
    ||
      ;; cannot use (HL)
      ;; remove "EX DE, HL", if there is any, or instert one if there is none ;-)
      ;; we need to do it, because TOS is in HL now, and we need to use HL.
      ;; prepare "remove instruction" flag
      peep-pattern:[[
        ex    de, hl
      ]] peep-match
      ?<
        remove-last-instruction ;; it was "EX DE, HL"
      ||
        ex-de-hl
      >?
      #->hl
    >?
  ||
    ex-de-hl
    #->hl
  >?
  c#->a-destructive
  sub-a-(hl)
  ex-de-hl  ;; restore TOS
;


(*
;; LIT:@ (TOS: HL) value: 39971 ($9C23)
9C72: E5           push  hl
9C73: 2A 23 9C     ld    hl, () $9C23
;; <BRANCH:LIT (TOS: HL) value: 2 ($0002)


;; LIT:C@ (TOS: HL) (out:8bit) value: 23560 ($5C08)
B635: E5           push  hl
B636: 3A 08 5C     ld    a, () $5C08
B639: 6F           ld    l, a
;; <>BRANCH:LIT (TOS: HL) value: 13 ($000D)
B63A: 3E 0D        ld    a, # $0D
B63C: 95           sub   l
B63D: E1           pop   hl
B63E: C2 4C B6     jp    nz, # $B64C
*)

(*
primopt: (cgen-prev-0-in-1-out?)  ( -- bool )
  0 ir:prev-node ir:node-in-equal not?exit&leave
  1 ir:prev-node ir:node-out-equal ;
*)

;; also, rewrites it to use A, and removes the initial PUSH.
;; TOS is guaranteed to be in HL.
primopt: (cgen-branch:lit-prev-c@?)  ( -- bool )
  TOS-in-HL? ?<
    peep-pattern:[[
      push  hl
      ld    a, () {addr}
      ld    l, a
      ld    h, # 0
    ]] peep-match not?exit&leave
    peep: {addr}
  || TOS-in-DE? not?error" ICE: TOS in not HL/DE!"
    peep-pattern:[[
      push  de
      ld    a, () {addr}
      ld    e, a
      ld    d, # 0
    ]] peep-match not?exit&leave
    peep: {addr}
  >?
  peep-remove-instructions
  restore-tos-hl
  (nn)->a
  true ;


primitive: =BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    ;; always inequal?
    dup hi-byte ?exit< drop
      ;; unsigned lit is always >255
      (cgen-remove-ld-a)
      ;; branch never taken
      scf
      0 cond:nc jp-#-cc
    >?
    lo-byte <<
      $00 of?v| or-a-a |?
      $01 of?v| dec-a |?
      $FF of?v| inc-a |?
    else| cp-a-c# >>
    0 cond:z jp-#-cc
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-not-taken-no-pop) >?
      (cgen-opt-branch-load-a-nn)
      lo-byte sub-a-c#
      0 cond:z jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-not-taken) >?
    ;; LIT-TOS
    c#->a-destructive
    tos-r16 sub-a-r16l
    pop-tos-hl
    0 cond:z jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    ;; with 0, should not happen, but ok
    tos-r16 r16l->a
    tos-r16 or-a-r16h
    pop-tos-hl
    0 cond:z jp-#-cc
  >?
  ;; TOS should be in HL
  dup hi-byte 0?exit<
    ;; compare with lo byte, hi byte is 0
    lo-byte c#->a
    tos-r16 sub-a-r16l
    tos-r16 or-a-r16h
    pop-tos-hl
    0 cond:z jp-#-cc
  >?
  (cgen-branch-gen-"LIT-TOS"-zero)
  pop-tos-hl
  0 cond:z jp-#-cc ;


primitive: <>BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    ;; always inequal?
    dup hi-byte ?exit< drop
      ;; unsigned lit is always >255
      (cgen-remove-ld-a)
      ;; branch always taken
      0 jp-#
    >?
    lo-byte <<
      $00 of?v| or-a-a |?
      $01 of?v| dec-a |?
      $FF of?v| inc-a |?
    else| cp-a-c# >>
    0 cond:nz jp-#-cc
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-taken-no-pop) >?
      (cgen-opt-branch-load-a-nn)
      lo-byte sub-a-c#
      0 cond:nz jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-taken) >?
    ;; LIT-TOS
    c#->a-destructive
    tos-r16 sub-a-r16l
    pop-tos-hl
    0 cond:nz jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    ;; with 0, should not happen, but ok
    tos-r16 r16l->a
    tos-r16 or-a-r16h
    pop-tos-hl
    0 cond:nz jp-#-cc
  >?
  ;; TOS should be in HL
  dup hi-byte 0?exit<
    ;; compare with lo byte, hi byte is 0
    lo-byte c#->a
    tos-r16 sub-a-r16l
    tos-r16 or-a-r16h
    pop-tos-hl
    0 cond:nz jp-#-cc
  >?
  (cgen-branch-gen-"LIT-TOS"-zero)
  pop-tos-hl
  0 cond:nz jp-#-cc ;


primitive: <BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    dup hi-byte ?exit<
      ;; a < lit
      (cgen-remove-ld-a)
      $80 >= ?< ;; lit is negative
        ;; branch never taken (a cannot be negative)
        scf
        0 cond:nc jp-#-cc
      ||
        ;; branch always taken (a always < 256)
        0 jp-#
      >?
    >?
    lo-byte <<
      $00 of?v| ;; a < 0, cannot ever happen
        (cgen-remove-ld-a)
        scf
        0 cond:nc jp-#-cc |?
      $01 of?v| ;; a < 1, can be converted to "A=0"
        or-a-a
        0 cond:z jp-#-cc |?
      $FF of?v| ;; a < 255
        ;; A+1 will set zero flag only if it is equal to 255.
        ;; coincidentally, the jump should be taken only if A<>255
        inc-a
        0 cond:nz jp-#-cc |?
    else|
      cp-a-c#
      0 cond:m jp-#-cc
    >>
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over w>s -?exit< 2drop (cgen-branch-gen-jp-not-taken-no-pop) >?
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-taken-no-pop) >?
      ;; TOS-LIT
      (cgen-opt-branch-load-a-nn)
      lo-byte sub-a-c#
      0 cond:c jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup w>s -?exit< drop (cgen-branch-gen-jp-not-taken) >?
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-taken) >?
    ;; TOS-LIT
    tos-r16 r16l->a
    lo-byte sub-a-c#
    pop-tos-hl
    0 cond:c jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    tos-r16 7 bit-r16h-n
    pop-tos-hl
    0 cond:nz jp-#-cc >?
  dup lo-byte 0?<
    ;; hi-byte only
    tos-r16 r16h->a
    hi-byte sub-a-c#
  ||
    (cgen-branch-gen-"TOS-LIT"-sign)
  >?
  pop-tos-hl
  0 cond:m jp-#-cc ;


primitive: >BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    dup hi-byte ?exit<
      ;; a > lit
      (cgen-remove-ld-a)
      $80 >= ?< ;; lit is negative
        ;; branch always taken (a cannot be negative)
        0 jp-#
      ||
        ;; branch never taken (a always < 256)
        scf
        0 cond:nc jp-#-cc
      >?
    >?
    lo-byte <<
      $00 of?v| ;; a > 0, which is the same as "A<>0"
        or-a
        0 cond:nz jp-#-cc |?
      $FE of?v| ;; a > 254, can happen only when A=255
        inc-a
        0 cond:z jp-#-cc |?
      $FF of?v| ;; a > 255, cannot ever happen
        (cgen-remove-ld-a)
        scf
        0 cond:nc jp-#-cc |?
    else| ;; convert to ">=", it is safe, as lit is never 0 or 255 here
      ;; a > 3 --> a >= 4
      ;; this way we can use the sign flag
      1+ cp-a-c#
      0 cond:p jp-#-cc
    >>
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over w>s -?exit< 2drop (cgen-branch-gen-jp-taken-no-pop) >?
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-not-taken-no-pop) >?
      (cgen-branch-gen-lit:c@:LIT-TOS)
      0 cond:c jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup w>s -?exit< drop (cgen-branch-gen-jp-taken) >?
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-not-taken) >?
    ;; LIT-TOS
    c#->a-destructive
    tos-r16 sub-a-r16l
    pop-tos-hl
    0 cond:c jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    ;; this should not happen anyway
    error" ICE: >BRANCH-ND:LIT:0 should not happen!" >?
  \ FIXME: optimise this!
  ;; lit-a: jump on negative
  (cgen-branch-gen-"LIT-TOS"-sign)
  pop-tos-hl
  0 cond:m jp-#-cc ;


primitive: >=BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    dup hi-byte ?exit<
      ;; a >= lit
      (cgen-remove-ld-a)
      $80 >= ?< ;; lit is negative
        ;; branch always taken (a cannot be negative)
        0 jp-#
      ||
        ;; branch never taken (a cannot be negative)
        scf
        0 cond:nc jp-#-cc
      >?
    >?
    lo-byte <<
      $00 of?v| ;; a >= 0, always true
        0 jp-# |?
      $01 of?v| ;; a >= 1, can be replaced with "A<>0"
        or-a
        0 cond:nz jp-#-cc |?
      $FF of?v| ;; a >= 255, can happen only when A=255
        inc-a
        0 cond:nz jp-#-cc |?
    else|
      cp-a-c#
      0 cond:p jp-#-cc
    >>
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over w>s -?exit< 2drop (cgen-branch-gen-jp-taken-no-pop) >?
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-not-taken-no-pop) >?
      ;; TOS-LIT
      (cgen-opt-branch-load-a-nn)
      lo-byte sub-a-c#
      0 cond:nc jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup w>s -?exit< drop (cgen-branch-gen-jp-taken) >?
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-not-taken) >?
    ;; TOS-LIT
    tos-r16 r16l->a
    lo-byte sub-a-c#
    pop-tos-hl
    0 cond:nc jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    tos-r16 7 bit-r16h-n
    pop-tos-hl
    0 cond:z jp-#-cc >?
  dup lo-byte 0?<
    ;; hi-byte only
    tos-r16 r16h->a
    hi-byte sub-a-c#
  ||
    (cgen-branch-gen-"TOS-LIT"-sign)
  >?
  pop-tos-hl
  0 cond:p jp-#-cc ;


primitive: <=BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    dup hi-byte ?exit<
      ;; a <= lit
      (cgen-remove-ld-a)
      $80 >= ?< ;; lit is negative
        ;; branch never taken (a cannot be negative)
        scf
        0 cond:nc jp-#-cc
      ||
        ;; branch always taken (a always < 256)
        0 jp-#
      >?
    >?
    lo-byte <<
      $00 of?v| ;; a <= 0, which is the same as "A=0"
        or-a
        0 cond:z jp-#-cc |?
      $FF of?v| ;; a >= 255, can happen only when A=255
        inc-a
        0 cond:z jp-#-cc |?
    else| ;; convert to "<", it is safe, as lit is never 0 or 255 here
      ;; a <= 3 --> a < 4
      ;; this way we can use the sign flag
      1+ cp-a-c#
      0 cond:m jp-#-cc
    >>
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over w>s -?exit< 2drop (cgen-branch-gen-jp-not-taken-no-pop) >?
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-taken-no-pop) >?
      (cgen-branch-gen-lit:c@:LIT-TOS)
      0 cond:nc jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup w>s -?exit< drop (cgen-branch-gen-jp-not-taken) >?
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-taken) >?
    ;; LIT-TOS
    c#->a-destructive
    tos-r16 sub-a-r16l
    pop-tos-hl
    0 cond:nc jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    ;; this should not happen anyway
    error" ICE: <=BRANCH-ND:LIT:0 should not happen!" >?
  \ FIXME: optimise this!
  ;; lit-a: jump on positive
  (cgen-branch-gen-"LIT-TOS"-sign)
  pop-tos-hl
  0 cond:p jp-#-cc ;


primitive: U<BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    dup hi-byte ?exit< drop
      ;; branch always taken (a always < 256)
      (cgen-remove-ld-a)
      0 jp-#
    >?
    lo-byte <<
      $00 of?v| ;; a < 0, cannot ever happen
        (cgen-remove-ld-a)
        scf
        0 cond:nc jp-#-cc |?
      $01 of?v| ;; a < 1, can be converted to "A=0"
        or-a-a
        0 cond:z jp-#-cc |?
      $FF of?v| ;; a < 255
        ;; A+1 will set zero flag only if it is equal to 255.
        ;; coincidentally, the jump should be taken only if A<>255
        inc-a
        0 cond:nz jp-#-cc |?
    else|
      cp-a-c#
      0 cond:c jp-#-cc
    >>
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-taken-no-pop) >?
      ;; TOS-LIT
      (cgen-opt-branch-load-a-nn)
      lo-byte sub-a-c#
      0 cond:c jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-taken) >?
    ;; TOS-LIT
    tos-r16 r16l->a
    lo-byte sub-a-c#
    pop-tos-hl
    0 cond:c jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    ;; a U< 0: never true
    error" ICE: U<BRANCH-ND:LIT:0 should not happen!"
    scf
    pop-tos-hl
    0 cond:nc jp-#-cc >?
  \ FIXME: optimise this!
  dup lo-byte 0?<
    ;; hi-byte only
    tos-r16 r16h->a
    hi-byte sub-a-c#
  ||
    (cgen-branch-gen-"TOS-LIT"-carry)
  >?
  pop-tos-hl
  0 cond:c jp-#-cc ;


primitive: U>BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    dup hi-byte ?exit<
      ;; a U> lit
      (cgen-remove-ld-a)
      ;; branch never taken (a always < 256)
      scf
      0 cond:nc jp-#-cc
    >?
    lo-byte <<
      $00 of?v| ;; a > 0, which is the same as "A<>0"
        or-a
        0 cond:nz jp-#-cc |?
      $FE of?v| ;; a > 254, can happen only when A=255
        inc-a
        0 cond:z jp-#-cc |?
      $FF of?v| ;; a > 255, cannot ever happen
        (cgen-remove-ld-a)
        scf
        0 cond:nc jp-#-cc |?
    else| ;; convert to ">=", it is safe, as lit is never 0 or 255 here
      ;; a > 3 --> a >= 4
      ;; this way we can use the carry flag
      1+ cp-a-c#
      0 cond:nc jp-#-cc
    >>
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-not-taken-no-pop) >?
      (cgen-branch-gen-lit:c@:LIT-TOS)
      0 cond:c jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-not-taken) >?
    ;; LIT-TOS
    c#->a-destructive
    tos-r16 sub-a-r16l
    pop-tos-hl
    0 cond:c jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    ;; this should not happen anyway
    ;; a U> 0 --> a<>0
    tos-r16 r16l->a
    tos-r16 or-a-r16h
    pop-tos-hl
    0 cond:nz jp-#-cc >?
  ;; lit-a: jump on carry
  (cgen-branch-gen-"LIT-TOS"-carry)
  pop-tos-hl
  0 cond:c jp-#-cc ;


primitive: U>=BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    dup hi-byte ?exit<
      ;; a U>= lit
      (cgen-remove-ld-a)
      ;; branch never taken (a always < 256)
      scf
      0 cond:nc jp-#-cc
    >?
    lo-byte <<
      $00 of?v| ;; a >= 0, always true
        0 jp-# |?
      $01 of?v| ;; a >= 1, can be replaced with "A<>0"
        or-a
        0 cond:nz jp-#-cc |?
      $FF of?v| ;; a >= 255, can happen only when A=255
        inc-a
        0 cond:nz jp-#-cc |?
    else|
      cp-a-c#
      0 cond:nc jp-#-cc
    >>
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-not-taken-no-pop) >?
      ;; TOS-LIT
      (cgen-opt-branch-load-a-nn)
      lo-byte sub-a-c#
      0 cond:nc jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-not-taken) >?
    ;; TOS-LIT
    tos-r16 r16l->a
    lo-byte sub-a-c#
    pop-tos-hl
    0 cond:nc jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    ;; a U>= 0: never false
    pop-tos-hl
    0 jp-# >?
  dup lo-byte 0?<
    ;; hi-byte only
    tos-r16 r16h->a
    hi-byte sub-a-c#
  ||
    (cgen-branch-gen-"TOS-LIT"-carry)
  >?
  pop-tos-hl
  0 cond:nc jp-#-cc ;


primitive: U<=BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ;; can we avoid the final POP, and get the 8-bit value in A?
  (cgen-branch:lit-prev-c@?) ?exit<
    ;; yes!
    ?curr-node-lit-value
    dup hi-byte ?exit<
      ;; a U<= lit
      (cgen-remove-ld-a)
      ;; branch always taken (a always < 256)
      0 jp-#
    >?
    lo-byte <<
      $00 of?v| ;; a <= 0, which is the same as "A=0"
        or-a
        0 cond:z jp-#-cc |?
      $FF of?v| ;; a >= 255, can happen only when A=255
        inc-a
        0 cond:z jp-#-cc |?
    else| ;; convert to "<", it is safe, as lit is never 0 or 255 here
      ;; a <= 3 --> a < 4
      ;; this way we can use the sign flag
      1+ cp-a-c#
      0 cond:c jp-#-cc
    >>
  >?

  restore-tos-hl-if-opt
  ?curr-node-lit-value
  ;; 8 bit?
  (cgen-opt-tos-h=0?) ?exit<
    zx-stats-peepbranch:1+!
    1 can-remove-n-last? ?< remove-last-instruction >? ;; the following check will fail if failed to remove; it is intended
    (cgen-opt-branch-lit:c@?) ?exit<
      ( value zx-addr )
      over hi-byte ?exit< 2drop (cgen-branch-gen-jp-taken-no-pop) >?
      (cgen-branch-gen-lit:c@:LIT-TOS)
      0 cond:nc jp-#-cc
    >?
    \ TODO! we cannot remove the jump yet
    dup hi-byte ?exit< drop (cgen-branch-gen-jp-taken) >?
    ;; LIT-TOS
    c#->a-destructive
    tos-r16 sub-a-r16l
    pop-tos-hl
    0 cond:nc jp-#-cc
  >?
  ;; 16 bit
  dup 0?exit< drop
    ;; this should not happen anyway
    ;; a U<= 0 --> a = 0
    tos-r16 r16l->a
    tos-r16 or-a-r16h
    pop-tos-hl
    0 cond:z jp-#-cc >?
  ;; lit-a: jump on no carry
  (cgen-branch-gen-"LIT-TOS"-carry)
  pop-tos-hl
  0 cond:nc jp-#-cc ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; more fun

primopt: (cgen-gen-and8-0/t-branch-mask-check)  ( byte -- result-in-carry? )
  ;; if we need to check bit 0 or bit 7, we can use bit shift, and carry flag
  dup $80 = ?exit< drop
    rlca
    true
  >?
  dup $01 = ?exit< drop
    rrca
    true
  >?
  and-a-c#
  false ;

primopt: (cgen-gen-fix-condition)  ( cond result-in-carry? -- cond )
  not?exit
  << cond:z of?v| cond:nc |?
     cond:nz of?v| cond:c |?
  else| error" ICE: invalid condition, expected Z or NZ!" >> ;


primopt: (cgen-gen-and8-0/t-branch-nd)  ( byte cond )
  >r lo-byte
  ;; if we already have tos-r16l in A, it is 1ts faster to check with the mask
  (cgen-ld-tosr16l-a?) not?<
    ;; simple bit check?
    dup pot dup +0?exit< nip
      ( bit-num )
      tos-r16 swap bit-r16l-n
      restore-tos-hl
      0 r> jp-#-cc
    >? drop
    tos-r16 r16l->a
  >?
  (cgen-gen-and8-0/t-branch-mask-check)
  r> swap (cgen-gen-fix-condition) >r
  restore-tos-hl
  0 r> jp-#-cc ;

primitive: AND8/0BRANCH:LIT-ND  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  ?curr-node-lit-value
  cond:z (cgen-gen-and8-0/t-branch-nd) ;

primitive: ~AND8/0BRANCH:LIT-ND  ( a -- a )
Succubus:setters:setup-branch
:codegen-xasm
  ?curr-node-lit-value -1 xor
  cond:z (cgen-gen-and8-0/t-branch-nd) ;


;; we can destroy TOS here
primopt: (cgen-gen-and8-0/t-branch)  ( byte cond )
  >r lo-byte
  (cgen-gen-ld-tosr16l-a-kill-push-tos?) swap
  ( was-push-tos-killed? byte )
  ;; it is 1ts faster to check with the mask than with BIT
  (cgen-gen-and8-0/t-branch-mask-check)
  r> swap (cgen-gen-fix-condition) >r
  not?< pop-tos-hl || restore-tos-hl >?
  0 r> jp-#-cc ;


primitive: AND8/0BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ?curr-node-lit-value
  cond:z (cgen-gen-and8-0/t-branch) ;

primitive: ~AND8/0BRANCH:LIT  ( a -- )
Succubus:setters:setup-branch
:codegen-xasm
  ?curr-node-lit-value -1 xor
  cond:z (cgen-gen-and8-0/t-branch) ;
