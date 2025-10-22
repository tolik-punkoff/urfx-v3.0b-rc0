;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; LIT variations
;; directly included from "zx-20-prims.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


primopt: (cgen-prev-removable-exx?)  ( -- bool )
  peep-pattern:[[
    exx
  ]] peep-match ;

primopt: (cgen-gen-exx-peephole)  ( -- removed-flag )
  (cgen-prev-removable-exx?) not?exit&leave
  ;; already have EXX, just remove it
  remove-last-instruction
  true ;

primopt: (cgen-lit:x-prev-lit:!0?)  ( -- bool )
  ir:prev-node-spfa ir:opt:(opt-zx-lit:!0) =
;

primopt: (cgen-lit:x-prev-lit:!1?)  ( -- bool )
  ir:prev-node-spfa ir:opt:(opt-zx-lit:!1) =
;

primopt: (cgen-lit:x-prev-lit:val2:!?)  ( -- bool )
  ir:prev-node-spfa ir:opt:(opt-zx-lit:val2:!) =
;

primopt: (cgen-lit:x-next-lit:!0?)  ( -- bool )
  ir:next-node-spfa ir:opt:(opt-zx-lit:!0) =
;

primopt: (cgen-lit:x-next-lit:!1?)  ( -- bool )
  ir:next-node-spfa ir:opt:(opt-zx-lit:!1) =
;

primopt: (cgen-lit:x-next-lit:val2:!?)  ( -- bool )
  ir:next-node-spfa ir:opt:(opt-zx-lit:val2:!) =
;

;; if we already have a removable exx, or the next node will/might generate exx...
primopt: (cgen-lit:x-use-exx?)  ( -- bool )
  (cgen-prev-removable-exx?) ?exit&leave
  ;; if TOS in HL, and next node could use EXX...
  TOS-in-HL? not?exit&leave
  (cgen-lit:x-next-lit:!0?) ?exit&leave
  (cgen-lit:x-next-lit:!1?) ?exit&leave
  (cgen-lit:x-next-lit:val2:!?)
;

primopt: (cgen-lit:x-next-want-tos-hl?)  ( -- bool )
  ir:next-node ir:node-need-TOS-HL?
;

primopt: (cgen-lit:x-next-want-tos-de?)  ( -- bool )
  ir:next-node ir:node-need-TOS-DE?
;


;; if next node wants TOS in HL, do not generate swaps
primopt: (cgen-lit:x-use-de?)  ( -- bool )
  ;; maybe HL is already free?
  TOS-in-HL? not?exit&leave
  ;; if next node needs TOS in HL, use DE to avoid double EX
  (cgen-lit:x-next-want-tos-hl?)
;

primitive: LIT  ( -- n )
:codegen-xasm
  OPT-OPTIMIZE-PEEPHOLE? ?<
    TOS-in-DE? ?<
      ;; if next instruction wants TOS in HL, put it in HL
      (cgen-lit:x-next-want-tos-hl?) ?exit<
        peep-pattern:[[
          pop   de
        ]] peep-match ?<
          peep-remove-instructions
        ||
          push-de
        >?
        TOS-in-HL!
        ?curr-node-lit-value #->tos
        stat-lit-tos:1+!
      >?
    >?
  >?
  push-tos-peephole ;; this will automatically optimise out "DROP"
  ?curr-node-lit-value #->tos ;


primitive: LIT:@EXECUTE  ( <unknown> )
:codegen-xasm
  restore-tos-de
  ?curr-node-lit-value (nn)->hl
  0 hl->(nn) $here 2-
  restore-tos-hl
  0 call-#
  $here 2- swap zx-w!
  ;; explicitly mark it
  reset-ilist ;

primitive: LIT:@  ( -- [n] )
:codegen-xasm
  push-tos-peephole
  ?curr-node-lit-value (nn)->tos ;


primitive: LIT:C@  ( -- b[n] )
Succubus:setters:out-8bit
:codegen-xasm
  TOS-in-HL? (cgen-lit:x-next-want-tos-de?) land ?<
    ;; current TOS is in HL, but next instruction wants it in DE
    push-hl
    TOS-in-DE!
  ||
    push-tos-peephole
  >?
  ;; for contended memory, prefer byte loads
  \ ?curr-node-lit-value $8000 lo-word >= ?exit<
  \   ?curr-node-lit-value (nn)->tos
  \   0 tos-r16 c#->r16h
  \ >?
  ?curr-node-lit-value (nn)->a
  a->tos ;

primitive: LIT:1C@  ( -- b[n] )
Succubus:setters:out-8bit
:codegen-xasm
  TOS-in-HL? (cgen-lit:x-next-want-tos-de?) land ?<
    ;; current TOS is in HL, but next instruction wants it in DE
    push-hl
    TOS-in-DE!
  ||
    push-tos-peephole
  >?
  ;; for contended memory, prefer byte loads
  \ ?curr-node-lit-value $8000 lo-word >= ?exit<
  \   ?curr-node-lit-value 1+ (nn)->tos
  \   0 tos-r16 c#->r16h
  \ >?
  ?curr-node-lit-value 1+ (nn)->a
  a->tos ;

primitive: LIT:@-LO-HI  ( -- b[n] b[n+1] )
Succubus:setters:out-8bit
:codegen-xasm
  push-tos-peephole
  ?curr-node-lit-value (nn)->hl
  h->e
  0 c#->h
  push-hl
  0 c#->d
  TOS-in-DE! ;

primitive: LIT:@-HI-LO  ( -- b[n+1] b[n] )
Succubus:setters:out-8bit
:codegen-xasm
  push-tos-peephole
  ?curr-node-lit-value (nn)->hl
  h->e
  0 c#->d
  push-de
  0 c#->h
  TOS-in-HL! ;


;; push  hl
;; ld    hl, # $88EE
;; LIT:! (TOS: HL) value: 32783 $800F
;; ld    $800F (), hl
;; pop   hl
primopt: (cgen-opt-lit:!-0)  ( -- success-flag )
  TOS-in-HL? not?exit&leave
  peep-pattern:[[
    push  hl
    ld    hl, # {value}
  ]] peep-match not?exit&leave
  peep: {value}
  peep-remove-instructions
  #->de ;; load to non-tos
  ir:?curr-node-lit-value de->(nn)
  stat-push-pop-removed:1+!
  true ;

primitive: LIT:!  ( value ) \ [n]=value
:codegen-xasm
  (cgen-opt-lit:!-0) ?exit
  ;; if we have "push tos / LIT:! / pop tos", push/pop is not needed
  OPT-OPTIMIZE-PEEPHOLE? ?<
    1 can-remove-n-last? ?<
      last-push-tos? dup ?< remove-last-instruction stat-push-pop-removed:1+! >?
    || false >?
  || false >?
  ?curr-node-lit-value tos->(nn)
  not?< pop-tos >? ;

primitive: LIT:VAL2:!  ( -- )  \ [n]=[val2]
:codegen-xasm
  (cgen-lit:x-use-exx?) ?exit<
    (cgen-gen-exx-peephole) not?< exx >?
    curr-node node:value2 #->hl
    ?curr-node-lit-value hl->(nn)
    exx
  >?
  (cgen-lit:x-use-de?) ?exit<
    curr-node node:value2 #->de
    ?curr-node-lit-value de->(nn)
  >?
  restore-tos-de
  curr-node node:value2 #->hl
  ?curr-node-lit-value hl->(nn) ;

primitive: LIT:SWAP:!  ( addr ) \ [addr]=n
:codegen-xasm
  ?curr-node-lit-value
  dup lo-byte over hi-byte = ?<
    c#->a-destructive
    tos-r16 a->(r16)
    tos-r16 inc-r16
    tos-r16 a->(r16)
  ||
    restore-tos-hl
    dup lo-byte c#->(hl) inc-hl
    hi-byte c#->(hl)
  >?
  pop-tos ;

;; E5           push  hl
;; 21 02 00     ld    hl, # $0002
;; LIT:C! (TOS: HL) value: 32776 $8008
;; 7D           ld    a, l
;; 32 08 80     ld    $8008 (), a
;; E1           pop   hl
primopt: (cgen-opt-lit:c!-0)  ( -- success-flag )
  TOS-in-HL? not?exit&leave
  peep-pattern:[[
    push  hl
    ld    hl, # {value}
  ]] peep-match not?exit&leave
  peep: {value} lo-byte
  peep-remove-instructions
  c#->a-destructive
  ir:?curr-node-lit-value a->(nn)
  stat-push-pop-removed:1+!
  true ;

;; 6F           ld    l, a
;; 26 00        ld    h, # $00
;; LIT:C! (TOS: HL) value: 33026 ($8102)
;; 7D           ld    a, l
;; 32 02 81     ld    $8102 (), a
;; E1           pop   hl
primopt: (cgen-opt-lit:c!-1)  ( -- success-flag )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    l, a
      ld    h, # 0
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    e, a
      ld    d, # 0
    ]]
  >?
  peep-match not?exit&leave
  peep-remove-instructions
  (cgen-opt-kill-push-tos?)
  ir:?curr-node-lit-value
  a->(nn)
  not?< pop-tos >?
  true ;

;; TOS=HL
;; 6F           ld    l, a
;; here should be poke
;;
;; TOS=DE
;; 5F           ld    e, a
;; here should be poke
primopt: (cgen-opt-lit:c!-2)  ( -- success-flag )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    l, a
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    e, a
    ]]
  >?
  peep-match not?exit&leave
  peep-remove-instructions
  (cgen-opt-kill-push-tos?)
  ir:?curr-node-lit-value
  a->(nn)
  not?< pop-tos >?
  true ;


primitive: LIT:C!  ( value ) \ b[n]=value
Succubus:setters:in-8bit
:codegen-xasm
  (*
  (cgen-opt-lit:c!-0) ?exit
  (cgen-opt-lit:c!-1) ?exit
  (cgen-opt-lit:c!-2) ?exit
  *)
  (cgen-gen-ld-tosr16l-a-kill-push-tos?)
  ?curr-node-lit-value
  a->(nn)
  not?< pop-tos >? ;

primitive: LIT:1C!  ( value ) \ b[n]=value
:codegen-xasm
  (cgen-gen-ld-tosr16l-a) \ tos-r16 r16l->a
  ?curr-node-lit-value 1+
  a->(nn)
  pop-tos ;

primitive: LIT:SWAP:C!  ( addr ) \ b[addr]=n
:codegen-xasm
  ?curr-node-lit-value
  TOS-in-HL? ?<
    lo-byte c#->(hl)
  ||
    c#->a-destructive
    non-tos-r16 a->(r16)
  >?
  pop-tos ;

primitive: LIT:C!0  ( -- ) \ b[n]=0
:codegen-xasm
  ?curr-node-lit-value
  ;; is A already zeroed?
  ir:opt:(opt-zx-lit:c!0) ir:prev-node-spfa = not?<
    xor-a-a
  >?
  a->(nn) ;

primitive: LIT:C!1  ( -- ) \ b[n]=1
:codegen-xasm
  ?curr-node-lit-value 1 c#->a a->(nn) ;


primitive: LIT:!0  ( -- )  \ [n]=0
:codegen-xasm
  ;; all WALIT nodes are replaced with LIT nodes, no need to check for them
  (cgen-lit:x-use-exx?) ?exit<
    (cgen-gen-exx-peephole) not?< exx >?
    (cgen-lit:x-prev-lit:!0?) ?exit<
      ?curr-node-lit-value hl->(nn)
      exx
    >?
    (cgen-lit:x-prev-lit:!1?) ?exit<
      dec-l ?curr-node-lit-value hl->(nn)
      exx
    >?
    0 #->hl
    ?curr-node-lit-value hl->(nn)
    exx
  >?
  (cgen-lit:x-use-de?) ?exit<
    0 #->de
    ?curr-node-lit-value de->(nn)
  >?
  restore-tos-de
  0 #->hl
  ?curr-node-lit-value hl->(nn) ;

primitive: LIT:!1  ( -- )  \ [n]=1
:codegen-xasm
  ;; all WALIT nodes are replaced with LIT nodes, no need to check for them
  (cgen-lit:x-use-exx?) ?exit<
    (cgen-gen-exx-peephole) not?< exx >?
    (cgen-lit:x-prev-lit:!1?) ?exit<
      ?curr-node-lit-value hl->(nn)
      exx
    >?
    (cgen-lit:x-prev-lit:!0?) ?exit<
      inc-l ?curr-node-lit-value hl->(nn)
      exx
    >?
    1 #->hl
    ?curr-node-lit-value hl->(nn)
    exx
  >?
  (cgen-lit:x-use-de?) ?exit<
    1 #->de
    ?curr-node-lit-value de->(nn)
  >?
  restore-tos-de
  1 #->hl
  ?curr-node-lit-value hl->(nn) ;


primitive: LIT:+!  ( value ) \ [n]+=value
:codegen-xasm
  ;; 8-bit code is faster than 16-bit
  ?curr-node-lit-value non-tos-r16 #->r16
  non-tos-r16 (r16)->a
  tos-r16 add-a-r16l
  non-tos-r16 a->(r16)
  non-tos-r16 inc-r16
  non-tos-r16 (r16)->a
  tos-r16 adc-a-r16h
  non-tos-r16 a->(r16)
  pop-tos ;

primitive: LIT:VAL2:+!  ( -- )  \ [n]+=[value2]
:codegen-xasm
  curr-node node:value2 w>s
  ;; small?
  dup -3 4 within ?exit<
    dup 0?exit< drop >?
    ;; 2*EXX cost is the same as "LD DE, (nn)"
    ?curr-node-lit-value dup non-tos-r16 (nn)->r16
    swap <<
      -3 of?v| dec-non-tos dec-non-tos dec-non-tos |?
      -2 of?v| dec-non-tos dec-non-tos |?
      -1 of?v| dec-non-tos |?
       1 of?v| inc-non-tos |?
       2 of?v| inc-non-tos inc-non-tos |?
       3 of?v| inc-non-tos inc-non-tos inc-non-tos |?
    else| error" ICE in \'LIT:VAL2:+!\'!" >>
    non-tos-r16 r16->(nn)
  >?
  ;; big
  (cgen-gen-exx-peephole) not?< exx >?
  ?curr-node-lit-value dup (nn)->hl
  swap <<
    -3 of?v| dec-hl dec-hl dec-hl |?
    -2 of?v| dec-hl dec-hl |?
    -1 of?v| dec-hl |?
     1 of?v| inc-hl |?
     2 of?v| inc-hl inc-hl |?
     3 of?v| inc-hl inc-hl inc-hl |?
  else| ;; 10+11=21
    #->de
    add-hl-de >>
  hl->(nn)
  exx ;

primitive: LIT:-!  ( value ) \ [n]-=value
:codegen-xasm
  ;; 8-bit code is faster than 16-bit
  ?curr-node-lit-value non-tos-r16 #->r16
  non-tos-r16 (r16)->a
  tos-r16 sub-a-r16l
  non-tos-r16 a->(r16)
  non-tos-r16 inc-r16
  non-tos-r16 (r16)->a
  tos-r16 sbc-a-r16h
  non-tos-r16 a->(r16)
  pop-tos ;

primitive: LIT:+C!  ( value ) \ [n]+=value
Succubus:setters:in-8bit
:codegen-xasm
  ?curr-node-lit-value non-tos-r16 #->r16
  non-tos-r16 (r16)->a
  tos-r16 add-a-r16l
  non-tos-r16 a->(r16)
  pop-tos ;

primitive: LIT:-C!  ( value ) \ [n]-=value
Succubus:setters:in-8bit
:codegen-xasm
  ?curr-node-lit-value non-tos-r16 #->r16
  non-tos-r16 (r16)->a
  tos-r16 sub-a-r16l
  non-tos-r16 a->(r16)
  pop-tos ;

primitive: LIT:1+!  ( -- )  \ [n]+=1
:codegen-xasm
  ;; faster than the honest 16 bit addition (even with 8-bit ops) (58)
  ;; with jr: 37/49; with jp: 35/52
  restore-tos-de
  ?curr-node-lit-value #->hl
  inc-(hl)
  cond:nz jr-cc
  inc-hl
  inc-(hl)
  jr-dest! ;

primitive: LIT:1-!  ( -- )  \ [n]-=1
:codegen-xasm
  ;; faster than the honest 16 bit addition (even with 8-bit ops) (58)
  ;; with jr: 48/60; with jp: 46/63
  restore-tos-de
  ?curr-node-lit-value #->hl
  (hl)->a
  dec-(hl)
  or-a-a
  cond:nz jr-cc
  inc-hl
  dec-(hl)
  jr-dest! ;
  (*
  ?curr-node-lit-value non-tos-r16 #->r16
  non-tos-r16 (r16)->a
  1 add-a-c#
  non-tos-r16 a->(r16)
  non-tos-r16 inc-r16
  non-tos-r16 (r16)->a
  0 adc-a-c#
  non-tos-r16 a->(r16)
  pop-tos ;
  *)

primitive: LIT:1+C!  ( -- )  \ [n]+=1
:codegen-xasm
  restore-tos-de
  ?curr-node-lit-value #->hl
  inc-(hl) ;

primitive: LIT:1-C!  ( -- )  \ [n]-=1
:codegen-xasm
  restore-tos-de
  ?curr-node-lit-value #->hl
  dec-(hl) ;

primitive: LIT:SWAP-  ( value -- [n]-value )
:codegen-xasm
  restore-tos-de
  xor-a-a
  ?curr-node-lit-value #->hl
  sbc-hl-de
  TOS-in-HL! ;

primitive: LIT:+  ( value -- value+[n] )
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop >?
  dup lo-byte 0?exit<
    hi-byte c>s
    << 1 of?v| tos-r16 inc-r16h |?
       2 of?v| tos-r16 inc-r16h  tos-r16 inc-r16h |?
       3 of?v| tos-r16 inc-r16h  tos-r16 inc-r16h  tos-r16 inc-r16h |?
      -1 of?v| tos-r16 dec-r16h |?
      -2 of?v| tos-r16 dec-r16h  tos-r16 dec-r16h |?
      -3 of?v| tos-r16 dec-r16h  tos-r16 dec-r16h  tos-r16 dec-r16h |?
    else|
      c#->a               ;; 7
      tos-r16 add-a-r16h  ;; 4
      tos-r16 a->r16h     ;; 4
    >>
  >?
  lo-word w>s
  <<   0 of?v||
       1 of?v| tos-r16 inc-r16 |?
       2 of?v| tos-r16 inc-r16  tos-r16 inc-r16 |?
       3 of?v| tos-r16 inc-r16  tos-r16 inc-r16  tos-r16 inc-r16 |?
      -1 of?v| tos-r16 dec-r16 |?
      -2 of?v| tos-r16 dec-r16  tos-r16 dec-r16 |?
      -3 of?v| tos-r16 dec-r16  tos-r16 dec-r16  tos-r16 dec-r16 |?
  else|
    non-tos-r16 #->r16  ;; 10
    add-hl-de           ;; 11
    TOS-in-HL! >> ;

primitive: LIT:UNDER+  ( a b -- a+[n] b )
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop >?
  pop-non-tos-peephole
  dup lo-byte 0?exit<
    hi-byte c>s
    << 1 of?v| non-tos-r16 inc-r16h |?
       2 of?v| non-tos-r16 inc-r16h  non-tos-r16 inc-r16h |?
       3 of?v| non-tos-r16 inc-r16h  non-tos-r16 inc-r16h  non-tos-r16 inc-r16h |?
      -1 of?v| non-tos-r16 dec-r16h |?
      -2 of?v| non-tos-r16 dec-r16h  non-tos-r16 dec-r16h |?
      -3 of?v| non-tos-r16 dec-r16h  non-tos-r16 dec-r16h  non-tos-r16 dec-r16h |?
    else|
      c#->a
      non-tos-r16 add-a-r16h
      non-tos-r16 a->r16h
    >>
    push-non-tos
  >?
  lo-word w>s
  <<   1 of?v| non-tos-r16 inc-r16  push-non-tos |?
       2 of?v| non-tos-r16 inc-r16  non-tos-r16 inc-r16  push-non-tos |?
       3 of?v| non-tos-r16 inc-r16  non-tos-r16 inc-r16  non-tos-r16 inc-r16  push-non-tos |?
      -1 of?v| non-tos-r16 dec-r16  push-non-tos |?
      -2 of?v| non-tos-r16 dec-r16  non-tos-r16 dec-r16  push-non-tos |?
      -3 of?v| non-tos-r16 dec-r16  non-tos-r16 dec-r16  non-tos-r16 dec-r16  push-non-tos |?
  else|
    TOS-in-HL? ?< ex-de-hl >?
    ;; HL is the value; DE is TOS
    #->bc
    add-hl-bc
    push-hl
    TOS-in-DE! >> ;


;; TOS is not changed; addr in HL; DE is destroyed
primopt: (cgen-opt-lit-plus-to-hl)  ( increment )
  w>s
  << 0 of?v| TOS-in-DE? ?< ex-de-hl >? |?
     1 of?v|
         TOS-in-DE? ?< ex-de-hl >?
         inc-hl |?
     2 of?v|
         TOS-in-DE? ?< ex-de-hl >?
         inc-hl inc-hl |?
     3 of?v|
         TOS-in-HL? ?< inc-hl inc-hl inc-hl
         || non-tos-r16 #->r16  add-hl-de >? |?
    -1 of?v|
         TOS-in-DE? ?< ex-de-hl >?
         dec-hl |?
    -2 of?v|
         TOS-in-DE? ?< ex-de-hl >?
         dec-hl dec-hl |?
    -3 of?v|
         TOS-in-HL? ?< dec-hl dec-hl dec-hl
         || non-tos-r16 #->r16  add-hl-de >? |?
  else|
    non-tos-r16 #->r16
    add-hl-de >> ;

primitive: LIT:+:@  ( addr -- [addr+[n]] )
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop
    restore-tos-hl
    (hl)->e inc-hl
    (hl)->d
    TOS-in-DE!
  >?
  dup lo-byte 0?exit<
    restore-tos-hl
    hi-byte c#->a
    add-a-h
    a->h
    (hl)->e inc-hl
    (hl)->d
    TOS-in-DE!
  >?
  (cgen-opt-lit-plus-to-hl)
  TOS-in-DE!
  (hl)->e inc-hl
  (hl)->d ;

primitive: LIT:+:C@  ( addr -- b[addr+[n]] )
Succubus:setters:out-8bit
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop
    restore-tos-hl
    (hl)->e
    0 c#->d
    TOS-in-DE!
  >?
  dup lo-byte 0?exit<
    restore-tos-hl
    hi-byte c#->a
    add-a-h
    a->h
    (hl)->e
    0 c#->d
    TOS-in-DE!
  >?
  (cgen-opt-lit-plus-to-hl)
  tos-r16 (hl)->r16l
  0 tos-r16 c#->r16h ;

primitive: LIT:+:!  ( value )  \ [addr+[n]]=value
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop
    restore-tos-hl
    pop-de
    e->(hl) inc-hl
    d->(hl)
    pop-tos-hl
  >?
  dup lo-byte 0?exit<
    restore-tos-hl
    hi-byte c#->a
    add-a-h
    a->h
    pop-de
    e->(hl) inc-hl
    d->(hl)
    pop-tos-hl
  >?
  (cgen-opt-lit-plus-to-hl)
  pop-de
  e->(hl) inc-hl
  d->(hl)
  pop-tos-hl ;

primitive: LIT:+:!0  ( addr )  \ [addr+[n]]=0
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop
    xor-a-a
    a->(hl) inc-hl
    a->(hl)
    pop-tos-hl
  >?
  dup lo-byte 0?exit<
    restore-tos-hl
    hi-byte c#->a
    add-a-h
    a->h
    xor-a-a
    a->(hl) inc-hl
    a->(hl)
    pop-tos-hl
  >?
  (cgen-opt-lit-plus-to-hl)
  xor-a-a
  a->(hl) inc-hl
  a->(hl)
  pop-tos-hl ;

primitive: LIT:+:!1  ( addr )  \ [addr+[n]]=1
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop
    1 c#->(hl) inc-hl
    0 c#->(hl)
    pop-tos-hl
  >?
  dup lo-byte 0?exit<
    restore-tos-hl
    hi-byte c#->a
    add-a-h
    a->h
    1 c#->(hl) inc-hl
    0 c#->(hl)
    pop-tos-hl
  >?
  (cgen-opt-lit-plus-to-hl)
  1 c#->(hl) inc-hl
  0 c#->(hl)
  pop-tos-hl ;

primitive: LIT:+:C!  ( value addr )  \ b[addr+[n]]=value
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop
    restore-tos-hl
    pop-de
    e->(hl)
    pop-tos-hl
  >?
  dup lo-byte 0?exit<
    restore-tos-hl
    hi-byte c#->a
    add-a-h
    a->h
    pop-de
    e->(hl)
    pop-tos-hl
  >?
  (cgen-opt-lit-plus-to-hl)
  pop-de
  e->(hl)
  pop-tos-hl ;

primitive: LIT:+:C!0  ( addr )  \ b[addr+[n]]=0
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop
    restore-tos-hl
    0 c#->(hl)
    pop-tos-hl
  >?
  dup lo-byte 0?exit<
    restore-tos-hl
    hi-byte c#->a
    add-a-h
    a->h
    0 c#->(hl)
    pop-tos-hl
  >?
  (cgen-opt-lit-plus-to-hl)
  0 c#->(hl)
  pop-tos-hl ;

primitive: LIT:+:C!1  ( addr )  \ b[addr+[n]]=1
:codegen-xasm
  ?curr-node-lit-value dup 0?exit< drop
    restore-tos-hl
    1 c#->(hl)
    pop-tos-hl
  >?
  dup lo-byte 0?exit<
    restore-tos-hl
    hi-byte c#->a
    add-a-h
    a->h
    1 c#->(hl)
    pop-tos-hl
  >?
  (cgen-opt-lit-plus-to-hl)
  1 c#->(hl)
  pop-tos-hl ;
