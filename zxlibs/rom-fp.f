;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FIXME: not tested as a library yet!
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ROM floating point library
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


\ OPT-ENABLE-FP? [IFNOT]
\   <zx-done>
\   " ROM floating point support is not enabled. use '--enable-rom-fp' to enable it!" error
\ [ENDIF]

zxlib-begin" ROM FP library"

5 constant #FLT ;; bytes in floating point number

;; maximum length of the string "STR>F" can parse.
;; we need to use internal buffer, hence the limitation.
25 label zx-fp-conv-strmax

;; not really a word
code: (FP-CONV-STR-BUF)
  next
\ zx-here label zx-fp-conv-str-buf
\ zx-here label zx-fp-conv-prstr-buf  ;; use the same buffer for both conversions
zx-fp-conv-str-buf:
zx-fp-conv-prstr-buf:  ;; use the same buffer for both conversions
  flush!
  ;; one extra byte for terminator, one extra byte for nothing
  25 2+ zx-allot0
  flush!
;code-no-next

\ ;; print-fp will never use more than 14 bytes, but let's play safe
\ zx-here label zx-fp-conv-prstr-buf
\ 18 zx-allot0

: FDEPTH  ( -- n )  SYS: FP@ ( SYS: FP0) asm-label: sys-fp0  @ - 5 U/ ;


;;TODO: turnkey tracer cannot optimise away FP words yet!

$31 zx-fp: FDUP
$02 zx-fp: FDROP
$01 zx-fp: FSWAP

$01 zx-fp: F-
$04 zx-fp: F*
$05 zx-fp: F/
$06 zx-fp: F**  ;; power
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
1 [IF]
: F2DROP  FDROP FDROP ;

code: F2SWAP
  push  bc
  rst   # $28
flush!
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
flush!
\ zx-fp-done-near-00:
  jp    # do-fp-done
;code-no-next

code: FOVER
  push  bc
  rst   # $28
flush!
  $C2 db, ;; to mem2
  $02 db, ;; drop
  $C1 db, ;; to mem1
  $E2 db, ;; from mem2
  $E1 db, ;; from mem1
  $38 db, ;; end-calc
flush!
  \ jr    # zx-fp-done-near-00
  jp    # do-fp-done
;code-no-next

code: F2DUP
  push  bc
  rst   # $28
flush!
  $C2 db, ;; to mem2
  $02 db, ;; drop
  $C1 db, ;; to mem1
  $02 db, ;; drop
  $E1 db, ;; from mem1
  $E2 db, ;; from mem2
  $E1 db, ;; from mem1
  $E2 db, ;; from mem2
  $38 db, ;; end-calc
flush!
  \ jr    # zx-fp-done-near-00
  jp    # do-fp-done
;code-no-next

code: FROT
  push  bc
  rst   # $28
flush!
  $C0 db, ;; to mem0
  $02 db, ;; drop
  $C1 db, ;; to mem1
  $02 db, ;; drop
  $C2 db, ;; to mem2
  $02 db, ;; drop
  $E1 db, ;; from mem1
  $E0 db, ;; from mem0
  $E2 db, ;; from mem2
flush!
  \ jr    # zx-fp-done-near-00
  jp    # do-fp-done
;code-no-next

code: FNROT
  push  bc
  rst   # $28
flush!
  $C0 db, ;; to mem0
  $02 db, ;; drop
  $C1 db, ;; to mem1
  $02 db, ;; drop
  $C2 db, ;; to mem2
  $02 db, ;; drop
  $E0 db, ;; from mem0
  $E2 db, ;; from mem2
  $E1 db, ;; from mem1
flush!
  \ jr    # zx-fp-done-near-00
  jp    # do-fp-done
;code-no-next
[ENDIF]
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; very slow string-to-fp
code: STR>F  ( addr count -- )
  pop   de      ;; length
  pop   hl      ;; src
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
  push  bc
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
  pop   bc
  ;; check for sign
  ld    a, () zx-fp-conv-str-buf
  cp    # [char] -
  jp    nz, # i-next
  push  bc
  rst   # $28
flush!
  $1B db, ;; neg
  $38 db, ;; end-calc
flush!
  jp    # do-fp-done
.hassign:
  inc   hl
  ld    a, (hl)
  jr    # .donumber
.dozero:
  ld    hl, # $1330
  ld    zx-fp-conv-str-buf (), hl
  jr    # .doit
;code-no-next


;; this converts floating number from the top of the calculator stack to string.
;; it should be safe to call it, but don't use this if F>S or F>U are suffice.
;; also note ROM bug: the stack may contain one trash value on exit.
;; this routine takes care of that bug.
code: F>STR  ( -- addr count )
  ;; puts the string as counted string into internal buffer
  ;; save IP
  push  bc
  ;; save channel flags
  ;; k8: we're using our own printing routine, no need to do that
  ;; !;ld    a, (iy+48)
  ;; !;push  af
  ;; !;res   4, (iy+48)   ;; not 'K' channel
  ;; save channel
  ld    hl, () $5C51  ;; CURCHL
  push  hl
  ;; force our printer
  ld    hl, # dsforth_fp_printa_addr
  ld    $5C51 (), hl
  ;; get fp stack
  ld    hl, () sys-fp
  ;; simulate fdrop
  dec   hl
  dec   hl
  dec   hl
  dec   hl
  dec   hl
  push  hl
  ;; setup result buffer
  ld    hl, # zx-fp-conv-prstr-buf
  ld    dsforth_fp_print_buffer_addr (), hl
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
  ;; restore IP
  pop   bc
  ;; push buffer address
  ld    hl, # zx-fp-conv-prstr-buf
  push  hl
  ;; push string length
  ld    de, () dsforth_fp_print_buffer_addr
  ex    de, hl
  or    a
  sbc   hl, de
  \ jp    # i-next-push-hl
  next-push-hl

dsforth_fp_printa:
  push  hl
  ld    hl, # 0   ;; patched by the main routine
$here 2- @def: dsforth_fp_print_buffer_addr
  ld    (hl), a
  inc   hl
  ld    dsforth_fp_print_buffer_addr (), hl
  pop   hl
  ret
flush!

dsforth_fp_printa_addr:
  " dsforth_fp_printa" z80-labman:ref-label,
;code-no-next


;; put signed int to calculator stack
code: S>F  ( u -- )
  exx
  pop   bc
  bit   7, b
  jr    nz, # .negative
  call  # $2D2B   ;; STACK_BC
  exx
  next
.negative:
  ;; negate it
  ld    de, bc
  ld    hl, # 0
  or    a
  sbc   hl, de
  ld    bc, hl
  call  # $2D2B   ;; STACK_BC
  ;; and negate on the calculator stack
  exx
  push  bc
  rst   # $28
flush!
  $1B db, ;; neg
  $38 db, ;; end-calc
flush!
  jp    # do-fp-done
;code-no-next

;; put unsigned int to calculator stack
code: U>F ( u )
  exx
  pop   bc
  call  # $2D2B   ;; STACK_BC
  exx
;code

;; pop unsigned int from calculator stack
;; this clamps value to [0..65535] range
code: F>U  ( -- u )
  push  bc
  call  # $2DA2   ;; FP_TO_BC
  ;; carry flag set on overflow
  ;; zero flag reset on negative
  ld    hl, bc
  pop   bc
  jr    c, # .overflow
  jr    z, # .done
  ld    hl, # 0
  jr    # .done
.overflow:
  ld    hl, # $FFFF
.done:
zx-fp-word-next-push-hl:
;code-push-hl

;; this clamps value to [-32768..32767] range
code: F>S  ( -- n )
  ;; pop int from calculator stack
  push  bc
  call  # $2DA2   ;; FP_TO_BC
  ld    hl, bc
  pop   bc
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
  jr    # zx-fp-word-next-push-hl
.positive:
  cp    # $80
  jr    nc, # .posover
  jr    # zx-fp-word-next-push-hl
.overflow:
  jr    z, # .posover
.negover:
  ld    hl, # $8000
  jr    # zx-fp-word-next-push-hl
.posover:
  ld    hl, # $7FFF
  jr    # zx-fp-word-next-push-hl
;code-no-next


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; the following words are not really necessary,
;; and could be easily emulated
1 [IF]
: FU.  F>U U. ;
: FU.R  ( n )  F>U SWAP U.R ;
\ : F.  F>S . ;
\ : F.R  ( n )  F>S SWAP .R ;
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; print proper floating point number

: F.R  ( n )  F>STR ROT ( a c n ) OVER - SPACES TYPE ;
: F.  0 F.R SPACE ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compile floating point constant

OPT-INTERPRETER? [IF]
*: FLITERAL
  SYS: STATE@ NOT?EXIT
  COMPILE SYS: FLIT
  0 F@M# 0 FM# HERE #FLT ALLOT #FLT CMOVE FDROP ;

*: F#  \ parse next word as floating point number, and push it
  BL WORD HERE COUNT STR>F
  [COMPILE] FLITERAL ;
[ENDIF]


zxlib-end
