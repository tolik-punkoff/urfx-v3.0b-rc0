;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; basic primitives
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>

<zx-system>

zx-s0 constant (S0)
zx-r0 constant (R0)

<zx-system>
$5C08 constant LAST-K

23606 constant-and-label CHARS sysvar-chars
\ 23675 constant-and-label UDGS sysvar-udgs
23675 label sysvar-udgs

23608 constant-and-label RASP sysvar-rasp ;; error beep length
23609 label sysvar-pip  ;; keyboard click length
23610 constant-and-label ERR-NR sysvar-err-nr   ;; IY points here
23611 label sysvar-flags
23617 constant-and-label TV-FLAG sysvar-tv-flag ;; ahem... this is MODE, tv-flag is 23612
23624 constant-and-label BORDCR sysvar-bordcr
23633 label sysvar-curchl
23649 label sysvar-worksp
23651 label sysvar-stkbot
23653 label sysvar-stkend
23655 label sysvar-calc-b-reg
23656 label sysvar-calc-mem
23658 constant FLAGS2
23665 label sysvar-flagx
\ 23672 constant-and-label FRAMES sysvar-frames
23672 constant FRAMES
23675 constant UDG^
23677 label sysvar-coords ;; x, then y
23677 label sysvar-coords-x
23678 label sysvar-coords-y
23684 constant-and-label DF-CC sysvar-df-cc   ;; scr$ for print
23688 constant-and-label S-POSN-X sysvar-s-posn-x ;; 33 minus print pos x
23689 constant-and-label S-POSN-Y sysvar-s-posn-y ;; 24 minus print pos y
;; bits 0-2: ink
;; bits 3-5: paper
;; bit 6: bright
;; bit 7: flash
23693 constant-and-label ATTR-P sysvar-attr-p
23694 constant-and-label MASK-P sysvar-mask-p
23695 constant-and-label ATTR-T sysvar-attr-t
23696 constant-and-label MASK-T sysvar-mask-t
;; bit 0: over-p
;; bit 1: over-t
;; bit 2: inverse-p
;; bit 3: inverse-t
;; bit 4: ink9-p
;; bit 5: ink9-t
;; bit 6: paper9-p
;; bit 7: paper9-t
23697 constant-and-label P-FLAG sysvar-p-flag
\ <zx-normal>


<zx-forth>

;; is IM2 mode active?
\ false constant IM2?

10 cquan (BASE)
\ 0 variable DPL
0 variable HLD


<zx-system>
tcom:zx-dp^ constant (DP)
<zx-forth>


0 constant FALSE
1 constant TRUE

32 constant BL
\ 13 constant NL


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; was constants, but should be quans.
;; this is because the startup code is setting them.
\ false quan 128?   -- will be set to 1 for 128K machine
\ false quan +3DOS? -- will be set to 1 if +3DOS is present

primitive: 128K?  ( -- bool )
:codegen-xasm
  push-tos-peephole
  tcom:zx-128k-flag^ (nn)->tos ;

primitive: +3DOS?  ( -- bool )
:codegen-xasm
  push-tos-peephole
  tcom:zx-p3dos-flag^ (nn)->tos ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZXEmuT API words

primitive: (BP)  ( -- )
:codegen-xasm  zxemut-bp ;


primitive: (PAUSE)  ( -- )
:codegen-xasm  zxemut-pause ;

primitive: (MSPD-ON)  ( -- )
:codegen-xasm  zxemut-max-speed ;

primitive: (MSPD-OFF)  ( -- )
:codegen-xasm  zxemut-normal-speed ;

primitive: (TS-RESET)  ( -- )
:codegen-xasm  zxemut-reset-ts-counter ;

primitive: (TS-PAUSE)  ( -- )
:codegen-xasm  zxemut-pause-ts-counter ;

primitive: (TS-RESUME)  ( -- )
:codegen-xasm  zxemut-resume-ts-counter ;

primitive: (TS-PRINT)  ( -- )
:codegen-xasm  zxemut-print-ts-counter ;

primitive: (TS-GET)  ( -- dlo dhi )
:codegen-xasm
  exx
  zxemut-get-ts-counter-de-hl
  exx
  push-tos
  exx
  push-hl
  ex-de-hl
  TOS-in-HL! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utilities

;; wait about ms milliseconds.
;; drifts a little, and tuned to IM 1 and contended memory.
code: MS  ( ms )
  pop   de
  ld    a, d
  or    e
  jp    z, # .done
.loop-0:
  ld    a, # 153    ;; was 171; decreased due to contended memory and such
.loop-1:
  nop
  dec   a
  jp    nz, # .loop-1
  dec   de
  ld    a, d
  or    e
  jp    nz, # .loop-0
.done:
;code
1 0 Succubus:setters:in-out-args

primitive: EI  ( -- )
:codegen-xasm  ei ;

primitive: DI  ( -- )
:codegen-xasm  di ;

primitive: HALT  ( -- )
:codegen-xasm  halt ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; useful in peephole

primopt: (cgen-prev-removable-ld-tosr16h-#0?)  ( -- flag )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    h, # 0
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    d, # 0
    ]]
  >?
  peep-match ;


;; this destroys proper value of TOS
primopt: (cgen-remove-ld-tosr16h-#0)
  (cgen-prev-removable-ld-tosr16h-#0?) ?<
    peep-remove-instructions
    stat-8bit-optim:1+!
  >? ;


primopt: (cgen-ld-tosr16l-a?)  ( -- bool )
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

primopt: (cgen-remove-ld-tosr16l-c#?)  ( -- byte TRUE // FALSE )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    l, # {byte}
    ]] peep-match not?exit&leave
    peep: {byte}
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    e, # {byte}
    ]] peep-match not?exit&leave
    peep: {byte}
  >?
  peep-remove-instructions
  true ;

primopt: (cgen-remove-ld-tosr16-#?)  ( -- byte TRUE // FALSE )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    hl, # {word}
    ]] peep-match not?exit&leave
    peep: {word}
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    de, # {word}
    ]] peep-match not?exit&leave
    peep: {word}
  >?
  peep-remove-instructions
  lo-byte
  true ;

primopt: (cgen-remove-ld-tosr16-()?)  ( -- addr TRUE // FALSE )
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    hl, () {addr}
    ]] peep-match not?exit&leave
    peep: {addr}
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    de, () {addr}
    ]] peep-match not?exit&leave
    peep: {addr}
  >?
  peep-remove-instructions
  true ;

;; this destroys flags, and proper value of TOS.
primopt: (cgen-gen-ld-tosr16l-a)
  (cgen-remove-ld-tosr16-#?) ?exit< stat-8bit-optim:1+! c#->a-destructive >?
  (cgen-remove-ld-tosr16-()?) ?exit< stat-8bit-optim:1+! (nn)->a >?
  stat-8bit-optim >r
  (cgen-remove-ld-tosr16h-#0)
  r@ stat-8bit-optim:!
  (cgen-ld-tosr16l-a?) ?exit< rdrop stat-8bit-optim:1+! peep-remove-instructions >?
  (cgen-remove-ld-tosr16l-c#?) ?exit< rdrop stat-8bit-optim:1+! c#->a-destructive >?
  (cgen-remove-ld-tosr16-()?) ?exit< rdrop stat-8bit-optim:1+! (nn)->a >?
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    l, (hl)
    ]] peep-match ?exit< rdrop stat-8bit-optim:1+!
      peep-remove-instructions
      (hl)->a
    >?
  >?
  TOS-in-DE? ?<
    peep-pattern:[[
      ld    e, (hl)
    ]] peep-match ?exit< rdrop stat-8bit-optim:1+!
      peep-remove-instructions
      (hl)->a
    >?
  >?
  r> stat-8bit-optim:!
  ;; alas
  tos-r16 r16l->a ;


primopt: (cgen-opt-kill-push-tos?)  ( -- was-push-tos-killed? )
  TOS-in-HL? ?<
    peep-pattern:[[
      push  hl
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      push  de
    ]]
  >?
  peep-match not?exit&leave
  stat-push-pop-removed:1+!
  peep-remove-instructions
  true ;


;; this destroys flags, and proper value of TOS.
primopt: (cgen-gen-ld-tosr16l-a-kill-push-tos?)  ( -- was-push-tos-killed? )
  (cgen-remove-ld-tosr16-#?) ?exit< stat-8bit-optim:1+! (cgen-opt-kill-push-tos?) swap c#->a-destructive >?
  (cgen-remove-ld-tosr16-()?) ?exit< stat-8bit-optim:1+! (cgen-opt-kill-push-tos?) swap (nn)->a >?
  stat-8bit-optim >r
  (cgen-remove-ld-tosr16h-#0)
  r@ stat-8bit-optim:!
  (cgen-ld-tosr16l-a?) ?exit< rdrop stat-8bit-optim:1+!
    peep-remove-instructions
    (cgen-opt-kill-push-tos?) ?exit&leave
    TOS-in-HL? ?<
      peep-pattern:[[
        push  hl
        ld    a, () {addr}
      ]] peep-match not?exit&leave
      peep: {addr}
    || TOS-in-DE? not?error" ICE!"
      peep-pattern:[[
        push  de
        ld    a, () {addr}
      ]] peep-match not?exit&leave
      peep: {addr}
    >?
    stat-push-pop-removed:1+!
    peep-remove-instructions
    (nn)->a
    true
  >?
  (cgen-remove-ld-tosr16l-c#?) ?exit< rdrop stat-8bit-optim:1+! (cgen-opt-kill-push-tos?) swap c#->a-destructive >?
  (cgen-remove-ld-tosr16-()?) ?exit< rdrop stat-8bit-optim:1+! (cgen-opt-kill-push-tos?) swap (nn)->a >?
  TOS-in-HL? ?<
    peep-pattern:[[
      ld    l, (hl)
    ]] peep-match ?exit< rdrop stat-8bit-optim:1+!
      peep-remove-instructions
      (cgen-opt-kill-push-tos?)
      (hl)->a
      true
    >?
  >?
  TOS-in-DE? ?<
    peep-pattern:[[
      ld    e, (hl)
    ]] peep-match ?exit< rdrop stat-8bit-optim:1+!
      peep-remove-instructions
      (cgen-opt-kill-push-tos?)
      (hl)->a
      true
    >?
  >?
  r> stat-8bit-optim:!
  ;; alas
  (cgen-opt-kill-push-tos?)
  tos-r16 r16l->a ;


;; this destroys flags, and proper value of TOS
primopt: (cgen-gen-ld-tosr16l-a-strict-8bit?)  ( -- success-flag )
  (cgen-prev-removable-ld-tosr16h-#0?) ?exit<
    peep-remove-instructions
    stat-8bit-optim:1+!
    (cgen-ld-tosr16l-a?) ?exit< peep-remove-instructions true >?
    (cgen-remove-ld-tosr16l-c#?) ?exit< c#->a-destructive true >?
    (cgen-remove-ld-tosr16-()?) ?exit< (nn)->a true >?
    peep-pattern:[[
      ld    l, (hl)
    ]] peep-match ?exit<
      peep-remove-instructions
      (hl)->a
      true
    >?
    peep-pattern:[[
      ld    e, (hl)
    ]] peep-match ?exit<
      peep-remove-instructions
      (hl)->a
      true
    >?
    ;; alas
    tos-r16 r16l->a
    true
  >?
  false ;


primopt: (cgen-remove-ld-a)
  peep-pattern:[[
    xor   a
  ]] peep-match ?exit< peep-remove-instructions >?
  peep-pattern:[[
    ld    a, # {n}
  ]] peep-match ?exit< peep-remove-instructions >?
  peep-pattern:[[
    ld    a, () {n}
  ]] peep-match ?exit< peep-remove-instructions >?
  peep-pattern:[[
    ld    a, b
  ]] peep-match ?exit< peep-remove-instructions >?
  peep-pattern:[[
    ld    a, c
  ]] peep-match ?exit< peep-remove-instructions >?
  peep-pattern:[[
    ld    a, d
  ]] peep-match ?exit< peep-remove-instructions >?
  peep-pattern:[[
    ld    a, e
  ]] peep-match ?exit< peep-remove-instructions >?
  peep-pattern:[[
    ld    a, h
  ]] peep-match ?exit< peep-remove-instructions >?
  peep-pattern:[[
    ld    a, l
  ]] peep-match ?exit< peep-remove-instructions >?
  peep-pattern:[[
    ld    a, (hl)
  ]] peep-match ?exit< peep-remove-instructions >?
;


primopt: (cgen-prev-out-bool?)  ( -- bool )
  ir:prev-node ir:node-out-bool? ;

primopt: (cgen-prev-out-8bit?)  ( -- bool )
  ir:prev-node ir:node-out-8bit? ;



;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; used in CASE

<zx-system>
;; used in "OF"
primitive: (OF<>)  ( a b -- a a-b )
:codegen-xasm
  pop-non-tos-peephole
  push-non-tos
  TOS-in-HL? ?< ex-de-hl >?
  xor-a-a
  sbc-hl-de
  TOS-in-HL! ;
<zx-forth>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; literals

<zx-system>
$include "zx-20-prims-10-lits.f"
$include "zx-20-prims-20-branches.f"
<zx-forth>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; exits

primitive: EXIT  ( <unknown> )
:codegen-xasm  error" ICE: EXIT should not end up in the codegen!" ;

primitive: ?EXIT  ( n )
:codegen-xasm  error" ICE: ?EXIT should not end up in the codegen!" ;

primitive: NOT?EXIT  ( n )
:codegen-xasm  error" ICE: NOT?EXIT should not end up in the codegen!" ;
alias-for NOT?EXIT is 0?EXIT


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; execute

primitive: EXECUTE  ( cfa -- <unknown> )
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?<
    ;; HL:cfa; DE:tos
    0 hl->(nn) $here 2- ;; save patch address
    ex-de-hl
  ||
    ;; DE:cfa; HL:tos
    0 de->(nn) $here 2- ;; save patch address
    TOS-in-HL!
  >?
  0 call-#
  ;; patch call code
  $here 2- swap zx-w!
  ;; explicitly mark it
  reset-ilist ;

primitive: @EXECUTE  ( addr -- <unknown> )
:codegen-xasm
  restore-tos-hl
  ;; load CFA
  (hl)->e
  inc-hl
  (hl)->d
  pop-tos
  ;; DE:cfa; HL:tos
  0 de->(nn) $here 2- ;; save patch address
  0 call-#
  ;; patch call code
  $here 2- swap zx-w!
  ;; explicitly mark it
  reset-ilist ;


$include "zx-20-prims-30-stack.f"
$include "zx-20-prims-36-rstack.f"
$include "zx-20-prims-40-loops.f"
$include "zx-20-prims-60-moves.f"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; upcase/locase

primitive: UPCHAR  ( ch -- ch )
Succubus:setters:in-8bit
Succubus:setters:out-8bit
:codegen-xasm
  (cgen-gen-ld-tosr16l-a) \ tos-r16 r16l->a
  [char] a cp-a-c#
  cond:c jr-cc  ( patch-addr )
  [char] z 1+ cp-a-c#
  cond:nc jr-cc  ( patch-addr )
  tos-r16 5 res-r16l-n
  jr-dest! jr-dest!
  0 tos-r16 c#->r16h ;

code: UPSTR  ( addr count )
  ex    de, hl
  pop   hl
.loop:
  ld    a, d
  or    e
  jr    z, #.done
  inc   hl
  ld    a, (hl)
  cp    # [char] a
  jr    c, # .bad-char
  cp    # [char] z 1+
  jr    nc, # .bad-char
  xor   # $20
  ld    (hl), a
.bad-char:
  dec   de
  jp    # .loop
.done:
  pop   hl
;code
2 2 Succubus:setters:in-out-args


primitive: LOCHAR  ( ch -- ch )
Succubus:setters:in-8bit
Succubus:setters:out-8bit
:codegen-xasm
  (cgen-gen-ld-tosr16l-a) \ tos-r16 r16l->a
  [char] A cp-a-c#
  cond:c jr-cc  ( patch-addr )
  [char] Z 1+ cp-a-c#
  cond:nc jr-cc  ( patch-addr )
  tos-r16 5 set-r16l-n
  jr-dest! jr-dest!
  0 tos-r16 c#->r16h ;


code: LOSTR  ( cstr )
  ex    de, hl
  pop   hl
.loop:
  ld    a, d
  or    e
  jr    z, #.done
  inc   hl
  ld    a, (hl)
  cp    # [char] A
  jr    c, # .bad-char
  cp    # [char] Z 1+
  jr    nc, # .bad-char
  xor   # $20
  ld    (hl), a
.bad-char:
  dec   de
  jp    # .loop
.done:
  pop   hl
;code
2 2 Succubus:setters:in-out-args


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; nothing. just nothing.

\ : NOOP  ; zx-mark-as-used
raw-code: NOOP  ( -- )
  ret
;code-no-next zx-mark-as-used
0 0 Succubus:setters:in-out-args


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple (and fast) number>string conversions

;; convert unsigned 16-bit number to decimal string.
;; put up to 5 digits to the internal buffer.
code: DECW>STR  ( num -- addr count )
  \ pop   hl
  ld    de, # .numbuf
  push  de  ;; addr
  ld    a, # @310 ;; ret z
  ld    .do-ret-z (), a
  ld    bc, # -10000
  call  # .printdec1
  ld    bc, # -1000
  call  # .printdec1
  ld    bc, # -100
  call  # .printdec1
  ld    c, # -10
  call  # .printdec1
  ld    a, l
  call  # .printdigit
  ex    de, hl
  ld    de, # .numbuf
  or    a
  sbc   hl, de
  next
.printdec1:
  ;; HL: number
  ;; BC: subtraction constant (negative, as we are using ADD instead)
  xor   a
.loop:
  add   hl, bc
  inc   a
  jp    c, # .loop
  sbc   hl, bc
  dec   a
.do-ret-z:
  ret   z
.printdigit:
  add   a, # 48
  ld    (de), a
  inc   de
  xor   a   ;; nop
  ld    .do-ret-z (), a
  ret
;; destination buffer
.numbuf:
  5 res0,
;code-no-next
1 2 Succubus:setters:in-out-args


;; convert unsigned 16-bit number to decimal string.
;; put 5 digits to the internal buffer.
code: DECW>STR5  ( num -- addr 5 )
  \ pop   hl
  ld    de, # .numbuf
  push  de  ;; addr
  ld    bc, # -10000
  call  # .printdec1
  ld    bc, # -1000
  call  # .printdec1
  ld    bc, # -100
  call  # .printdec1
  ld    c, # -10
  call  # .printdec1
  ld    a, l
  add   a, # 48
  ld    (de), a
  ld    hl, # 5
  next
.printdec1:
  ;; HL: number
  ;; BC: subtraction constant (negative, as we are using ADD instead)
  ld    a, # 47
.loop:
  add   hl, bc
  inc   a
  jp    c, # .loop
  sbc   hl, bc
  ld    (de), a
  inc   de
  ret
;; destination buffer
.numbuf:
  5 res0,
;code-no-next
1 2 Succubus:setters:in-out-args


;; convert unsigned 16-bit number to hex string.
;; put 4 digits to the internal buffer.
code: HEXW>STR  ( num -- addr 4 )
  \ pop   hl
  ld    de, # .numbuf
  push  de  ;; addr
  ld    a, h
  rrca
  rrca
  rrca
  rrca
  call  # .print_nibble
  ld    a, h
  call  # .print_nibble
  ld    a, l
  rrca
  rrca
  rrca
  rrca
  call  # .print_nibble
  ld    a, l
  call  # .print_nibble
  ld    hl, # 4
  next
.print_nibble:
;; convert nibble (low 4 bits of A) to hexadecimal digit
;; IN: A: nibble
;; OUT: A: digit ready to print
  and   a, # $0F
  cp    # 10
  sbc   a, # $69
  daa
  ld    (de), a
  inc   de
  ret
.numbuf:
  0 dw, 0 dw,
;code-no-next
1 2 Succubus:setters:in-out-args


<zx-done>
