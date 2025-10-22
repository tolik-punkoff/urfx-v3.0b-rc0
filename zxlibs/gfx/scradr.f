;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scr$ address calculations
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


zxlib-begin" SCRADR library"

(*
just to remind this to myself:
screen address layout is:

  010 zz yyy | rrr ccccc

where:
  zz: the index of 1/3 of the screen$: [0..2]
  yyy: the vertical position inside the character cell
  rrr: the vertical position of the character inside the current 1/3 (row)
  ccccc: the horizontal position in the current row (column)

ccccc: bits 0..4 of the low byte
rrr: bits 5..7 of the low byte
yyy: bits 0..2 of the high byte
zz: bits 3..4 of the high byte
*)


;; convert char coords to screen$ bitmap address.
;; return 0 for invalid coord.
code: CXY>SCR$-SAFE  ( x y -- scr$ )
  pop   de
  ;; HL: y
  ;; DE: x
  ld    a, h
  or    d
  ld    d, l
  ;; D=y, E=x
  ld    hl, # 0
  jr    nc, # .done
  ld    a, e
  cp    # 32
  jr    nc, # .done
  ld    a, d
  cp    # 24
  jr    nc, # .done
  ;; IN:
  ;;   D: y
  ;;   E: x
  ;; OUT:
  ;;   HL: scr$addr
  ;;   AF: dead
  ;;   carry flag: reset
  \ ld    a, d
  and   # $18
  or    # $40
  ld    h, a
  ld    a, d
  rrca
  rrca
  rrca
  and   # $E0
  or    e
  ld    l, a
.done:
;code
2 1 Succubus:setters:in-out-args

;; convert char coords to screen$ attribute address.
;; return 0 for invalid coord.
code: CXY>ATTR-SAFE  ( x y -- attr-addr )
  pop   de
  ;; HL: y  (HL)
  ;; DE: x
  ld    a, h
  or    d
  ld    d, l
  ;; D=y, E=x
  ld    hl, # 0
  jr    nc, # .done
  ld    a, e
  cp    # 32
  jr    nc, # .done
  ld    a, d
  cp    # 24
  jr    nc, # .done
  ;; IN:
  ;;   A: y
  ;;   E: x
  ;; OUT:
  ;;   HL: attr addr
  ;;   DE: dead
  ;;   AF: dead
  ;;   carry flag is reset
  \ ld    a, d
  rrca
  rrca
  rrca
  ld    d, a
  ;; low byte
  and   # $E0
  or    e
  ld    l, a
  ;; high byte
  ld    a, d
  and   # $03
  or    # $58
  ld    h, a
.done:
;code
2 1 Succubus:setters:in-out-args

;; convert pixel coords to screen$ bitmap address and shift.
;; return 0, 0 for invalid coord.
;; FIXME: this doesn't work yet
code: XY>SCR$-SAFE  ( x y -- scr$ shift )
  pop   de
  ;; DE:x; HL:y
  ld    a, h
  or    d
  jr    nz, # .fail
  ld    a, l
  cp    # 192
  jr    nc, # .fail
  ;; ROM calc screen address
  ;; IN:
  ;;   C: x
  ;;   A: y
  ;; OUT:
  ;;   HL: scr$
  ;;    A: bit number (from the msb; i.e. 0 means "$80")
  ld    c, e
  call  # $22B0
  ld    l, a
  ld    h, # 0
  push  hl
  next
.fail:
  ld    hl, # 0
  push  hl
;code
2 2 Succubus:setters:in-out-args


;; screen$ address to attribute address.
;; WARNING! no sanity checks!
primitive: SCR$>ATTR  ( scr$ -- attr-addr )
:codegen-xasm
  tos-r16 r16h->a
  $87 or-a-c#
  rra
  rra
  srl-a ;; rra for #C000 screen
  tos-r16 a->r16h ;

;; attribute address to screen$ address.
;; WARNING! no sanity checks!
primitive: ATTR>SCR$  ( attr-addr -- scr$ )
:codegen-xasm
  ;; works for #C000 too
  ;; tnx, Lethargeek
  tos-r16 r16h->a
  add-a-a
  add-a-a
  add-a-a
  tos-r16 and-a-r16h
  tos-r16 a->r16h ;

;; common code in WIN8
primopt: (cgen-opt-cxy>attr-0)
  TOS-in-HL? not?exit ;; just in case
  peep-pattern:[[
    push  hl
    ld    d, # 0
    ;; CXY>ATTR (TOS: DE)
    pop   hl
    ex    de, hl
  ]] peep-match not?exit
  peep-remove-instructions
  ;; if last is "LD H, # 0", reuse H
  peep-pattern:[[
    ld    h, # 0
  ]] peep-match ?<
    h->d
  ||
    0 c#->d
  >?
  ex-de-hl ;

primopt: (cgen-opt-cxy>attr-1)
  TOS-in-HL? not?exit ;; just in case
  peep-pattern:[[
    push  de
    ld    l, h
    ld    h, # 0
    ;; CXY>SCR$ (TOS: HL)
    pop   de
  ]] peep-match not?exit
  peep-remove-instructions
  peep-pattern:[[
    ld    e, l
    ld    d, # 0
  ]] peep-match ?<
    h->l
    d->h
  ||
    h->l
    0 c#->h
  >? ;


;; convert char coords to screen$ bitmap address.
;; return 0 for invalid coord.
;; WARNING! no sanity checks!
primitive: CXY>SCR$  ( x y -- scr$ )
Succubus:setters:in-8bit
:codegen-xasm
  pop-non-tos
  restore-tos-hl
  (cgen-opt-cxy>attr-0)
  (cgen-opt-cxy>attr-1)
  ;; TOS: y  (HL)
  ;; non-TOS: x  (DE)
  l->a
  $18 and-a-c#
  $40 or-a-c#
  a->h
  l->a
  rrca
  rrca
  rrca
  $E0 and-a-c#
  or-a-e
  a->l ;

;; convert char coords to screen$ attribute address.
;; return 0 for invalid coord.
;; WARNING! no sanity checks!
primitive: CXY>ATTR  ( x y -- attr-addr )
Succubus:setters:in-8bit
:codegen-xasm
  pop-non-tos
  restore-tos-hl
  (cgen-opt-cxy>attr-0)
  (cgen-opt-cxy>attr-1)
  ;; TOS: y  (HL)
  ;; non-TOS: x  (DE)
  l->a
  rrca
  rrca
  rrca
  a->d
  ;; low byte
  $E0 and-a-c#
  or-a-e
  a->l
  ;; high byte
  d->a
  $03 and-a-c#
  $58 or-a-c#
  a->h ;

;; convert pixel y coord to screen$ attribute address.
;; return 0 for invalid coord.
;; WARNING! no sanity checks!
primitive: Y>ATTR  ( y -- attr-addr )
Succubus:setters:in-8bit
:codegen-xasm
  restore-tos-hl
  ;; TOS: y  (HL)
  l->a
  $F8 and-a-c#
  a->l
  $16 c#->h
  add-hl-hl
  add-hl-hl ;


;; convert pixel coords to screen$ bitmap address and shift.
;; return 0, 0 for invalid coord.
;; WARNING! no sanity checks!
primitive: XY>SCR$  ( x y -- scr$ shift )
Succubus:setters:in-8bit
:codegen-xasm
  ;; TOS: y
  pop-bc-peephole  ;; x is in the right register
  tos-r16 r16l->a
  $22B0 call-#
  a->e
  0 c#->d
  push-hl
  TOS-in-DE! ;


;; convert pixel coords to screen$ bitmap address and shift.
;; WARNING! no sanity checks!
primitive: Y>SCR$  ( y -- scr$ )
Succubus:setters:in-8bit
:codegen-xasm
  ;; TOS: y
  tos-r16 r16l->a
  or-a-a
  rra
  scf
  rra
  or-a-a
  rra
  tos-r16 xor-a-r16l
  $F8 and-a-c#
  tos-r16 xor-a-r16l
  tos-r16 a->r16h
  tos-r16 r16l->a
  $C7 and-a-c#
  tos-r16 xor-a-r16l
  rlca
  rlca
  tos-r16 a->r16l ;


;; down one pixel line.
;; WARNING! address must be valid!
primitive: SCR$V  ( scr$addr -- scr$addr )
:codegen-xasm
  tos-r16 inc-r16h
  tos-r16 r16h->a
  $07 and-a-c#
  cond:nz jp-cc ;; taken most of the time
  tos-r16 r16l->a
  -32 sub-a-c#
  tos-r16 a->r16l
  sbc-a-a
  $F8 and-a-c#
  tos-r16 add-a-r16h
  tos-r16 a->r16h
  jp-dest! ;
;; 4+4+7+10=25
;; 4+4+7+10+4+7+4+4+7+4+4=59

;; up one pixel line.
;; WARNING! address must be valid!
;; WARNING! this is slower than "SCR$V", so use that instead if possible
primitive: SCR$^  ( scr$addr -- scr$addr )
:codegen-xasm
  tos-r16 r16h->a
  tos-r16 dec-r16h
  $07 and-a-c#
  cond:nz jp-cc ;; taken most of the time
  tos-r16 r16l->a
  32 sub-a-c#
  tos-r16 a->r16l
  cond:c jp-cc ;; taken most of the time
  tos-r16 r16h->a
  8 add-a-c#
  tos-r16 a->r16h
  jp-dest! jp-dest! ;
;; 4+4+7+10=25
;; 4+4+7+10+4+7+4+10=50
;; 4+4+7+10+4+7+4+10+4+7+4=65


;; down one char line.
;; WARNING! address must be valid!
primitive: CSCR$V  ( scr$addr -- scr$addr )
:codegen-xasm
  ;; move down one row
  tos-r16 r16l->a
  32 add-a-c#
  tos-r16 a->r16l
  ;; we need to fix high byte anyway
  tos-r16 r16h->a
  cond:nc jp-cc ( .no-next-third )
  8 add-a-c#
  jp-dest!
  $F8 and-a-c#
  tos-r16 a->r16h ;
;; 4+7+4+4+10+7+4=40
;; 4+7+4+4+10+7+7+4=47

;; up one char line.
;; WARNING! address must be valid!
;; WARNING! untested, and i wrote it while i was sleepy... but it *SHOULD* work. ;-)
primitive: CSCR$^  ( scr$addr -- scr$addr )
:codegen-xasm
  ;; move up one row
  tos-r16 r16l->a
  -32 add-a-c#
  tos-r16 a->r16l
  ;; we need to fix high byte anyway
  tos-r16 r16h->a
  cond:nc jp-cc ( .no-next-third )
  8 sub-a-c#
  jp-dest!
  $F8 and-a-c#
  tos-r16 a->r16h ;
;; 4+7+4+4+10+7+4=40
;; 4+7+4+4+10+7+7+4=47


;; fill the screen with checkered pattern.
;; code by Introspec.
primitive: SCR$-CHECKER-PATTERN!  ( -- )
:codegen-xasm
  TOS-in-HL? dup ?< ex-de-hl >?
  16384 6143 + #->hl
  $here ( .loop )
  h->a
  rra
  sbc-a-a
  %01010101 xor-a-c#
  a->(hl)
  dec-hl
  6 bit-h-n
  cond:nz jr-disp-cc
  ?< ex-de-hl >? ;


zxlib-end
