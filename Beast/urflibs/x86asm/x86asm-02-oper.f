;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler: operand definitions
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module iop-helpers

;; operand size
 0 constant nada
 1 constant db
 2 constant dw
 4 constant dd
 8 constant dq
10 constant dt
16 constant d16
68 constant dfpu
69 constant dany

;; operand type
enum{
  def: none
  -- "imm" slot (2)
  def: imm   -- immediate value
  -- "size" slot (3)
  def: size  -- operand size enforcement -- never seen in parsed arg
  -- reg/rm slot (0, 1)
  -- WARNING! order matters! (see the matcher)
  def: reg8  -- basic 8-bit register (low byte is register index)
  def: reg16 -- basic 16-bit register (low byte is register index)
  def: reg32 -- basic 32-bit register (low byte is register index)
  def: rxmm  -- XMM register
  def: rseg  -- segment register
  def: rctl  -- control register
  def: rdbg  -- debug register
  def: rtst  -- test register
  def: rfpu  -- FPU register
  def: rmmx  -- MMX register
  def: rm32  -- [reg32]
  def: rm32+ -- [reg32+] -- converted to "rm32"
  -- si slot (1)
  def: si32  -- [reg32*n] -- converted to "sib32"
  def: si32+ -- [reg32*n+] -- converted to "sib32"
  -- special value
  def: comma -- never seen in parsed arg
  ;; used only in argument parser
  def: addr   -- numeric address; created by "<size> #"
  def: sib32  -- completed "mod|r/m" and "sib"

  def: type-max
}

none 0 <> " invalid `imm` value!" ?error

(*
operand data format is:
  bits  0.. 7: mod|r/m
  bits  8..15: sib
  bits 16..23: type
  bits 24..31: size
*)

|: (fix-size)  ( [size] value type -- size value type )
  dup rm32 si32+ bounds ?< nada nrot >? ;

|: (fix-value)  ( value type -- value type )
  dup si32 si32+ bounds ?< swap 256 * swap >? ;

|: (pack-op)  ( [size] value type -- val )
  (fix-size) (fix-value) 65536 * or swap 24 lshift or ;

|: (mk-op)  ( addr count val )
  nrot system:mk-builds , does> @ put-arg ;

|: (mk-op-,)  ( addr count val )
  nrot system:mk-builds , does> @ put-arg [ comma 65536 * ] {#,} put-arg ;

: mk-op-,  ( size value type )  \ name
  (pack-op) >r
  parse-name 2dup + 1- c@ [char] , <> ?error" where's comma?"
  2dup r@ (mk-op-,)  1- r> (mk-op) ;

: op>type   ( opval -- type )   hi-word lo-byte ;
: op>size   ( opval -- sib )    hi-word hi-byte ;
: op>value  ( opval -- value )  lo-word ;

clean-module
end-module iop-helpers


;; Grand Operand List
extend-module instructions
using iop-helpers

;; register number
db 0 reg8 mk-op-, AL,
db 1 reg8 mk-op-, CL,
db 2 reg8 mk-op-, DL,
db 3 reg8 mk-op-, BL,
db 4 reg8 mk-op-, AH,
db 5 reg8 mk-op-, CH,
db 6 reg8 mk-op-, DH,
db 7 reg8 mk-op-, BH,

;; register number
dw 0 reg16 mk-op-, AX,
dw 1 reg16 mk-op-, CX,
dw 2 reg16 mk-op-, DX,
dw 3 reg16 mk-op-, BX,
dw 4 reg16 mk-op-, SP,
dw 5 reg16 mk-op-, BP,
dw 6 reg16 mk-op-, SI,
dw 7 reg16 mk-op-, DI,

;; register number
dd 0 reg32 mk-op-, EAX,
dd 1 reg32 mk-op-, ECX,
dd 2 reg32 mk-op-, EDX,
dd 3 reg32 mk-op-, EBX,
dd 4 reg32 mk-op-, ESP,
dd 5 reg32 mk-op-, EBP,
dd 6 reg32 mk-op-, ESI,
dd 7 reg32 mk-op-, EDI,

$include "urforth-regs.f"

;; r/m value
0o000 rm32 mk-op-, [EAX],
0o001 rm32 mk-op-, [ECX],
0o002 rm32 mk-op-, [EDX],
0o003 rm32 mk-op-, [EBX],
0o004 rm32 mk-op-, [ESP], -- this needs special processing in parser
0o005 rm32 mk-op-, [EBP], -- this needs special processing in parser
0o006 rm32 mk-op-, [ESI],
0o007 rm32 mk-op-, [EDI],

;; r/m value
;; this can be either "[reg+disp]" or SIB start
0o000 rm32+ mk-op-, [EAX+],
0o001 rm32+ mk-op-, [ECX+],
0o002 rm32+ mk-op-, [EDX+],
0o003 rm32+ mk-op-, [EBX+],
0o004 rm32+ mk-op-, [ESP+], -- this needs special processing in parser
0o005 rm32+ mk-op-, [EBP+], -- this allows only displacement
0o006 rm32+ mk-op-, [ESI+],
0o007 rm32+ mk-op-, [EDI+],

;; sib value; index-scale
0o000 si32 mk-op-, [EAX*1],
0o010 si32 mk-op-, [ECX*1],
0o020 si32 mk-op-, [EDX*1],
0o030 si32 mk-op-, [EBX*1],
0o050 si32 mk-op-, [EBP*1],
0o060 si32 mk-op-, [ESI*1],
0o070 si32 mk-op-, [EDI*1],

;; sib value; index-scale
0o000 si32+ mk-op-, [EAX*1+],
0o010 si32+ mk-op-, [ECX*1+],
0o020 si32+ mk-op-, [EDX*1+],
0o030 si32+ mk-op-, [EBX*1+],
0o050 si32+ mk-op-, [EBP*1+],
0o060 si32+ mk-op-, [ESI*1+],
0o070 si32+ mk-op-, [EDI*1+],

;; sib value; index-scale
0o100 si32 mk-op-, [EAX*2],
0o110 si32 mk-op-, [ECX*2],
0o120 si32 mk-op-, [EDX*2],
0o130 si32 mk-op-, [EBX*2],
0o150 si32 mk-op-, [EBP*2],
0o160 si32 mk-op-, [ESI*2],
0o170 si32 mk-op-, [EDI*2],

;; sib value; index-scale
0o100 si32+ mk-op-, [EAX*2+],
0o110 si32+ mk-op-, [ECX*2+],
0o120 si32+ mk-op-, [EDX*2+],
0o130 si32+ mk-op-, [EBX*2+],
0o150 si32+ mk-op-, [EBP*2+],
0o160 si32+ mk-op-, [ESI*2+],
0o170 si32+ mk-op-, [EDI*2+],

;; sib value; index-scale
0o200 si32 mk-op-, [EAX*4],
0o210 si32 mk-op-, [ECX*4],
0o220 si32 mk-op-, [EDX*4],
0o230 si32 mk-op-, [EBX*4],
0o250 si32 mk-op-, [EBP*4],
0o260 si32 mk-op-, [ESI*4],
0o270 si32 mk-op-, [EDI*4],

;; sib value; index-scale
0o200 si32+ mk-op-, [EAX*4+],
0o210 si32+ mk-op-, [ECX*4+],
0o220 si32+ mk-op-, [EDX*4+],
0o230 si32+ mk-op-, [EBX*4+],
0o250 si32+ mk-op-, [EBP*4+],
0o260 si32+ mk-op-, [ESI*4+],
0o270 si32+ mk-op-, [EDI*4+],

;; sib value; index-scale
0o300 si32 mk-op-, [EAX*8],
0o310 si32 mk-op-, [ECX*8],
0o320 si32 mk-op-, [EDX*8],
0o330 si32 mk-op-, [EBX*8],
0o350 si32 mk-op-, [EBP*8],
0o360 si32 mk-op-, [ESI*8],
0o370 si32 mk-op-, [EDI*8],

;; sib value; index-scale
0o300 si32+ mk-op-, [EAX*8+],
0o310 si32+ mk-op-, [ECX*8+],
0o320 si32+ mk-op-, [EDX*8+],
0o330 si32+ mk-op-, [EBX*8+],
0o350 si32+ mk-op-, [EBP*8+],
0o360 si32+ mk-op-, [ESI*8+],
0o370 si32+ mk-op-, [EDI*8+],

;; the usual segment register encoding
dw 0 rseg mk-op-, ES,
dw 1 rseg mk-op-, CS,
dw 2 rseg mk-op-, SS,
dw 3 rseg mk-op-, DS,
dw 4 rseg mk-op-, FS,
dw 5 rseg mk-op-, GS,

dd 0 rctl mk-op-, CR0,
dd 2 rctl mk-op-, CR2,
dd 3 rctl mk-op-, CR3,
dd 4 rctl mk-op-, CR4,

dd 0 rdbg mk-op-, DR0,
dd 1 rdbg mk-op-, DR1,
dd 2 rdbg mk-op-, DR2,
dd 3 rdbg mk-op-, DR3,
dd 6 rdbg mk-op-, DR6,
dd 7 rdbg mk-op-, DR7,

dd 3 rtst mk-op-, TR3,
dd 4 rtst mk-op-, TR4,
dd 5 rtst mk-op-, TR5,
dd 6 rtst mk-op-, TR6,
dd 7 rtst mk-op-, TR7,

dfpu 0 rfpu mk-op-, ST0,
dfpu 1 rfpu mk-op-, ST1,
dfpu 2 rfpu mk-op-, ST2,
dfpu 3 rfpu mk-op-, ST3,
dfpu 4 rfpu mk-op-, ST4,
dfpu 5 rfpu mk-op-, ST5,
dfpu 6 rfpu mk-op-, ST6,
dfpu 7 rfpu mk-op-, ST7,

dany 0 rmmx mk-op-, MM0,
dany 1 rmmx mk-op-, MM1,
dany 2 rmmx mk-op-, MM2,
dany 3 rmmx mk-op-, MM3,
dany 4 rmmx mk-op-, MM4,
dany 5 rmmx mk-op-, MM5,
dany 6 rmmx mk-op-, MM6,
dany 7 rmmx mk-op-, MM7,

dany 0 rxmm mk-op-, XMM0,
dany 1 rxmm mk-op-, XMM1,
dany 2 rxmm mk-op-, XMM2,
dany 3 rxmm mk-op-, XMM3,
dany 4 rxmm mk-op-, XMM4,
dany 5 rxmm mk-op-, XMM5,
dany 6 rxmm mk-op-, XMM6,
dany 7 rxmm mk-op-, XMM7,

-- no size enforcement, parser will process it separately
nada  db size mk-op-, BYTE^,
nada  dw size mk-op-, WORD^,
nada  dd size mk-op-, DWORD^,
nada  dq size mk-op-, QWORD^,
nada  dt size mk-op-, TBYTE^,
nada d16 size mk-op-, OWORD^,

nada dd size mk-op-, FLOAT^,
nada dq size mk-op-, DOUBLE^,
nada dt size mk-op-, EXTENDED^,

nada  dq size mk-op-, MMWORD^,
nada d16 size mk-op-, XMMWORD^,

;; numeric literal; it can be either immediate, or address (with SIZE^)
nada 0 imm mk-op-, #,

;; label reference; the same as "#", but denotes use of labels
;; first 256 values are reserved for local labels
;; positive id means "label value is known", negative is forward reference
nada  1 imm mk-op-, @@0,
nada  2 imm mk-op-, @@1,
nada  3 imm mk-op-, @@2,
nada  4 imm mk-op-, @@3,
nada  5 imm mk-op-, @@4,
nada  6 imm mk-op-, @@5,
nada  7 imm mk-op-, @@6,
nada  8 imm mk-op-, @@7,
nada  9 imm mk-op-, @@8,
nada 10 imm mk-op-, @@9,

;; back and forward references to "nameless label"
nada 254 imm mk-op-, @@b,
nada 255 imm mk-op-, @@f,

;; comma is this (we cannot define it the usual way)
: ,  [ comma 65536 * ] {#,} put-arg ;

clean-module
end-module instructions
