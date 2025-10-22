;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; floating point support via ROM routines
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>

$5C63 label sys-fp0  ;; STKBOT
$5C65 label sys-fp   ;; STKEND
23698 label sys-fp-membot

$5C63 constant sys-fp0  ;; STKBOT
$5C65 constant sys-fp   ;; STKEND
23698 constant sys-fp-membot


<zx-system>
;; embedded FP literal
raw-code: FLIT
  pop   hl
  ld    de, () sys-fp
  ld    bc, # 5
  ldir
  ld    sys-fp (), de
  jp    hl
;code-no-next
0 0 Succubus:setters:in-out-args


primitive: FP@  ( -- n )
:codegen-xasm
  push-tos-peephole
  ;; this points AFTER the current value
  ( sys-fp) $5C65 tos-r16 (nn)->r16 ;

primitive: FP!  ( n )
:codegen-xasm
  ;; this points AFTER the current value
  ( sys-fp) $5C65 tos-r16 r16->(nn)
  pop-tos ;

primitive: FP0!  ( -- )
:codegen-xasm
  ( sys-fp0) $5C63 non-tos-r16 (nn)->r16
  ( sys-fp) $5C65 non-tos-r16 r16->(nn) ;


(*
primitive: (FP-OP)  ( -- )
:codegen-xasm
  ?curr-node-lit-value  ;; opcode
  push-tos
  push-ix
  push-iy
  restore-iy
  c#->b     ;; opcode
  $28 rst-#
  $3B byte, ;; fp-calc-2
  $38 byte, ;; end-calc
  pop-iy
  pop-ix
  pop-tos-hl ;
*)

;; execute embedded FP operation
raw-code: (FP-OP)
  ex    (sp), hl
  ld    b, (hl)
  inc   hl
  push  hl
  push  iy
  restore-iy
  rst   # $28
  $3B db, ;; fp-calc-2
  $38 db, ;; end-calc
  pop   iy
  pop   ix
  pop   hl
  jp    ix
;code-no-next

raw-code: (FP-OP-XMEM)
  ;; HL: memindex
  ex    de, hl
  pop   hl
  ld    a, (hl)
  add   a, e
  ld    b, a
  inc   hl
  push  hl
  push  iy
  restore-iy
  rst   # $28
  $3B db, ;; fp-calc-2
  $38 db, ;; end-calc
  pop   iy
  pop   ix
  pop   hl
  jp    ix
;code-no-next

<zx-forth>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level FP code

5 constant #FLT ;; bytes in floating point number

;; maximum length of the string "STR>F" can parse.
;; we need to use internal buffer, hence the limitation.
;; print-fp will never use more than 14 bytes, but let's play safe
25 label zx-fp-conv-strmax

;; not really a word
raw-code: (FP-CONV-STR-BUF)
  ret
zx-fp-conv-str-buf:
zx-fp-conv-prstr-buf:  ;; use the same buffer for both conversions
  ;; one extra byte for terminator, one extra byte for nothing
  0 25 2+ db-dup-n
;code-no-next

(*
create (fp-conv-prstr-buf)
zx-here label zx-fp-conv-prstr-buf
25 2+ zx-allot0
create;
*)


: FDEPTH  ( -- n )  SYS: FP@ ( SYS: FP0) asm-label: sys-fp0  @ - 5 U/ ;


$31 zx-fp: FDUP
$02 zx-fp: FDROP
$01 zx-fp: FSWAP

$01 zx-fp: F-
$04 zx-fp: F*
$05 zx-fp: F/
$06 zx-fp: F**  ;; power
$06 zx-fp: FPOW ;; power
$0F zx-fp: F+
$28 zx-fp: FSQRT
$32 zx-fp: FMOD

$27 zx-fp: FINT
$3A zx-fp: FTRUNC
$2A zx-fp: FABS
$1B zx-fp: FNEGATE
$1B zx-fp: FMINUS
$29 zx-fp: FSGN

$1F zx-fp: FSIN
$20 zx-fp: FCOS
$21 zx-fp: FTAN
$22 zx-fp: FASIN
$23 zx-fp: FACOS
$24 zx-fp: FATAN
$25 zx-fp: FLN
$26 zx-fp: FEXP

$36 zx-fp: F0<
$37 zx-fp: F0>
$30 zx-fp: F0=

$0D zx-fp: F<
$09 zx-fp: F<=
$0C zx-fp: F>
$0A zx-fp: F>=
$0E zx-fp: F=
$0B zx-fp: F<>

$A0 zx-fp: F#0     ;; push 0
$A1 zx-fp: F#1     ;; push 1
$A4 zx-fp: F#10    ;; push 10
$A2 zx-fp: F#0.5   ;; push 0.5
$A3 zx-fp: F#PI/2  ;; push PI/2

$C0 zx-fp-xmem: F@M#  ( memreg )  ;; to mem0
$E0 zx-fp-xmem: M#>F  ( memreg )  ;; from mem0
: F>M# ( memreg )  F@M# FDROP ;
: FM#  ( idx -- addr )  #FLT * ( FMEMBOT) asm-label: sys-fp-membot + ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; the following words are not really necessary,
;; and could be easily emulated
: F2DROP  FDROP FDROP ; zx-inline

raw-code: F2SWAP
  push  hl
  push  iy
  restore-iy
  rst   # $28

  $C2 db, ;; to mem2
  $02 db, ;; drop
  $C1 db, ;; to mem1
  $02 db, ;; drop

  $C4 db, ;; to mem4
  $02 db, ;; drop
  $C3 db, ;; to mem3
  $02 db, ;; drop

  $E1 db, ;; from mem1
  $E2 db, ;; from mem2

  $E3 db, ;; from mem3
  $E4 db, ;; from mem4

  $38 db, ;; end-calc

  pop   iy
  pop   hl
;code

raw-code: FOVER
  push  hl
  push  iy
  restore-iy
  rst   # $28

  $C2 db, ;; to mem2
  $02 db, ;; drop
  $C1 db, ;; to mem1
  $E2 db, ;; from mem2
  $E1 db, ;; from mem1
  $38 db, ;; end-calc

  pop   iy
  pop   hl
;code

raw-code: F2DUP
  push  hl
  push  iy
  restore-iy
  rst   # $28

  $C2 db, ;; to mem2
  $02 db, ;; drop
  $C1 db, ;; to mem1
  $02 db, ;; drop
  $E1 db, ;; from mem1
  $E2 db, ;; from mem2
  $E1 db, ;; from mem1
  $E2 db, ;; from mem2
  $38 db, ;; end-calc

  pop   iy
  pop   hl
;code

raw-code: FROT
  push  hl
  push  iy
  restore-iy
  rst   # $28

  $C0 db, ;; to mem0
  $02 db, ;; drop
  $C1 db, ;; to mem1
  $02 db, ;; drop
  $C2 db, ;; to mem2
  $02 db, ;; drop
  $E1 db, ;; from mem1
  $E0 db, ;; from mem0
  $E2 db, ;; from mem2

  pop   iy
  pop   hl
;code

raw-code: FNROT
  push  hl
  push  iy
  restore-iy
  rst   # $28

  $C0 db, ;; to mem0
  $02 db, ;; drop
  $C1 db, ;; to mem1
  $02 db, ;; drop
  $C2 db, ;; to mem2
  $02 db, ;; drop
  $E0 db, ;; from mem0
  $E2 db, ;; from mem2
  $E1 db, ;; from mem1

  pop   iy
  pop   hl
;code


;; very slow string-to-fp
code: STR>F  ( addr count -- )
  ex    de, hl  ;; length
  pop   hl      ;; src

  push  ix
  push  iy
  restore-iy

  ld    a, d
  or    a
  jr    nz, # .dozero
  ld    a, e
  or    a
  jr    z, # .dozero
  cp    # zx-fp-conv-strmax
  jr    c, # .lenok
  ld    e, # zx-fp-conv-strmax
.lenok:
  ;; copy to temp buffer
  ld    bc, de
  ld    de, # zx-fp-conv-str-buf
  ldir
  ;; put terminator
  ld    a, # 13
  ld    (de), a
  ;; call calculator internals
.doit:
  ld    hl, # zx-fp-conv-str-buf
  ld    a, (hl)     ;; it is necessary to load the first char into A
  ;; that routine cannot parse signs, so do it manually later
  cp    # [char] +
  jr    z, # .hassign
  cp    # [char] -
  jr    z, # .hassign
.donumber:
  ld    23645 (), hl  ;; put it to CH_ADD (we won't bother restoring it)
  call  # $2CB8       ;; ask calculator to parse it
  ;; check for sign
  ld    a, () zx-fp-conv-str-buf
  cp    # [char] -
  jr    nz, # .finish
  rst   # $28
  $1B db, ;; neg
  $38 db, ;; end-calc
  jr    # .finish
.hassign:
  inc   hl
  ld    a, (hl)
  jr    # .donumber
.dozero:
  ld    hl, # $1330
  ld    zx-fp-conv-str-buf (), hl
  jr    # .doit

.finish:
  pop   iy
  pop   ix
;code-pop-tos
zx-required: (FP-CONV-STR-BUF)


;; this converts floating number from the top of the calculator stack to string.
;; it should be safe to call it, but don't use this if F>S or F>U are suffice.
;; also note ROM bug: the stack may contain one trash value on exit.
;; this routine takes care of that bug.
code: F>STR  ( -- addr count )
  push  hl

  push  ix
  push  iy
  restore-iy

  ;; put the string as counted string into internal buffer
  ;; save channel flags
  ;; k8: we're using our own printing routine, no need to do that
  ;; !;ld    a, (iy+48)
  ;; !;push  af
  ;; !;res   4, (iy+48)   ;; not 'K' channel
  ;; save channel
  ld    hl, () $5C51  ;; CURCHL
  push  hl
  ;; force our printer
  ld    hl, # urfx_fp_printa_addr
  ld    $5C51 (), hl
  ;; get fp stack
  ld    hl, () sys-fp
  ;; simulate fdrop
  ld    bc, # -5
  xor   a
  sbc   hl, bc
  push  hl
  ;; setup result buffer
  ld    hl, # zx-fp-conv-prstr-buf
  ld    urfx_fp_print_buffer_addr (), hl
  ;; print-fp
  call  # $2DE3
  ;; restore fp stack (due to the ROM bug we'll do it manually)
  pop   hl
  ld    sys-fp (), hl
  ;; restore channel
  pop   hl
  ld    $5C51 (), hl  ;; CURCHL
  ;; restore channel flags
  ;; !;pop   af
  ;; !;ld    (iy+48),a

  pop   iy
  pop   ix

  ;; push buffer address
  ld    hl, # zx-fp-conv-prstr-buf
  push  hl
  ;; push string length
  ld    de, () urfx_fp_print_buffer_addr
  ex    de, hl
  or    a
  sbc   hl, de

  next

urfx_fp_printa:
  push  hl
  ld    hl, # 0   ;; patched by the main routine
$here 2- @def: urfx_fp_print_buffer_addr
  ld    (hl), a
  inc   hl
  ld    urfx_fp_print_buffer_addr (), hl
  pop   hl
  ret
flush!

urfx_fp_printa_addr:
  " urfx_fp_printa" z80-labman:ref-label,
;code-no-next
zx-required: (FP-CONV-STR-BUF)


;; put signed int to calculator stack
code: S>F  ( u -- )
  push  ix
  push  iy
  restore-iy
  bit   7, h
  jr    nz, # .negative
  ld    bc, hl
  call  # $2D2B   ;; STACK_BC
  jr    # .done
.negative:
  ;; negate it
  ex    de, hl
  ld    hl, # 0
  or    a
  sbc   hl, de
  ld    bc, hl
  call  # $2D2B   ;; STACK_BC
  ;; and negate on the calculator stack
  rst   # $28
  $1B db, ;; neg
  $38 db, ;; end-calc
.done:
  pop   iy
  pop   ix
;code-pop-tos

;; put unsigned int to calculator stack
code: U>F ( u )
  ld    bc, hl
  push  ix
  push  iy
  restore-iy
  call  # $2D2B   ;; STACK_BC
  pop   iy
  pop   ix
;code-pop-tos

;; pop unsigned int from calculator stack
;; this clamps value to [0..65535] range
code: F>U  ( -- u )
  push  hl
  push  ix
  push  iy
  restore-iy
  call  # $2DA2   ;; FP_TO_BC
  ;; carry flag set on overflow
  ;; zero flag reset on negative
  ld    hl, bc
  jr    c, # .overflow
  jr    z, # .done
  ld    hl, # 0
  jr    # .done
.overflow:
  ld    hl, # $FFFF
.done:
  pop   iy
  pop   ix
;code

;; this clamps value to [-32768..32767] range
code: F>S  ( -- n )
  push  hl
  push  ix
  push  iy
  restore-iy
  ;; pop int from calculator stack
  call  # $2DA2   ;; FP_TO_BC
  ld    hl, bc
  ;; carry flag set on overflow
  ;; zero flag reset on negative
  jr    c, # .overflow
  ld    a, h
  jr    z, # .positive
  ;; negative number, check overflow
  cp    # $80
  jr    nc, # .negover
  ;; negate it
  ex    de, hl
  ld    hl, # 0
  or    a
  sbc   hl, de
  jr    # .done
.positive:
  cp    # $80
  jr    nc, # .posover
  jr    # .done
.overflow:
  jr    z, # .posover
.negover:
  ld    hl, # $8000
  jr    # .done
.posover:
  ld    hl, # $7FFF
  jr    # .done
.done:
  pop   iy
  pop   ix
;code


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; printing

: FU.  F>U U. ; zx-inline
: FU.R  ( n )  F>U SWAP U.R ; zx-inline
\ : F.  F>S . ;
\ : F.R  ( n )  F>S SWAP .R ;

: F.R  ( n )  F>STR ROT ( a c n ) OVER - SPACES TYPE ;
: F0.R  0 F.R ; zx-inline
: F.  F0.R SPACE ; zx-inline


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compile floating point constant

(*
OPT-INTERPRETER? [IF]
*: FLITERAL
  SYS: STATE@ NOT?EXIT
  COMPILE SYS: FLIT
  0 F@M# 0 FM# HERE #FLT ALLOT #FLT CMOVE FDROP ;

*: F#  \ parse next word as floating point number, and push it
  BL WORD HERE COUNT STR>F
  [COMPILE] FLITERAL ;
[ENDIF]
*)

<zx-done>
