;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler: instruction database
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module id-helpers

;; invalid instruction opcode
-1 constant <invalid>


;; instruction operand types
enum{
  def: ....

  def: imm8
  def: imm16
  def: imm32
  def: iimm8
  def: uimm8

  def: rel8
  def: rel32

  def: r/m8
  def: r/m16
  def: r/m32
  def: m64
  def: xr/m32
  def: xr/m64
  def: xr/m128

  def: reg8
  def: reg16
  def: reg32

  def: xmreg

  def: SR -- segment register
  def: STx -- FPU register
  -- this must be the last
  def: ST0 -- FPU register ST(0)

  def: DS
  def: ES
  def: SS
  def: FS
  def: GS

  def: ctreg -- CRx
  def: dbreg -- DRx
  def: tsreg -- TRx

  def: AL
  def: CL
  def: AX
  def: DX
  def: EAX

  def: bptr
  def: wptr
  def: dptr
  def: qptr
  def: tptr
  def: aptr -- any pointer

  ;; for FPU
  def: fbptr
  def: fwptr
  def: fdptr
  def: fqptr
  def: ftptr

  def: iarg-max
}

;; instruction flags
enum{
  def: ..
  def: /0 -- in RRR of "mod|r/m"
  def: /1 -- in RRR of "mod|r/m"
  def: /2 -- in RRR of "mod|r/m"
  def: /3 -- in RRR of "mod|r/m"
  def: /4 -- in RRR of "mod|r/m"
  def: /5 -- in RRR of "mod|r/m"
  def: /6 -- in RRR of "mod|r/m"
  def: /7 -- in RRR of "mod|r/m"
  def: /r -- register index is in low 3 bits
  def: /x -- special reg in RRR of "mod|r/m", and always generates "mod|r/m"
}

-2 quan xdepth  (private)

: {  xdepth -1 <> ?error" start error" depth xdepth:! ;

: }  ( opc op0 op1 op2 flags )
  depth xdepth - 5 <> ?error" end error"
  >r 2swap swap , c, swap c, c, r> c,
  -1 xdepth:! ;

: define  \ name
  -2 xdepth <> -1 xdepth <> and ?error" bad define"
  -1 xdepth = ?< 0 , ( terminator ) || -1 xdepth:! >?
  <builds does> >r emit:flush r> <instr-table>:! ;

;; for latest instruction
: alias
  -1 xdepth <> ?error" alias for what?"
  parse-name 0 , ( terminator )
  system:latest-cfa mk-alias-for ;

: define-instructions
  push-ctx push-cur voc-ctx: id-helpers voc-cur: instructions
  -2 xdepth:! ;

: end-instructions
  -1 xdepth <> ?error" your table is wrong"
  0 , ( termination flag for the last instruction )
  pop-ctx pop-cur ;

clean-module
end-module id-helpers

(*
instruction table format:
  dd opcode
  db op0
  db op1
  db op2
  db flags
*)

: i>opcode ( -- opcode ) <instr-table> @ ;
: i>op#    ( idx -- op# ) 4+ <instr-table> + c@ ;
: i>op0    ( -- op0 ) 0 i>op# ;
: i>op1    ( -- op1 ) 1 i>op# ;
: i>op2    ( -- op2 ) 2 i>op# ;
: i>flags  ( -- flags ) <instr-table> 7 + c@ ;

8 constant instr-size -- entry size

here
id-helpers:define-instructions

X86ASM-SMALL [IFNOT]
define AAA
{ $01000037  ....  ....  ....  .. }

define AAD
{ $02000AD5  ....  ....  ....  .. }

;; AAD with a different operand
;; this also properly sets flags
;; AL = AL + 10*AH
define MUL8
{ $010000D5  uimm8 ....  ....  .. }

define AAM
{ $02000AD4  ....  ....  ....  .. }

;; AAM with a different operand
;; this also properly sets flags
;; AH = quotient
;; AL = remainder
define DIV8
{ $010000D4  uimm8 ....  ....  .. }

define AAS
{ $0100003F  ....  ....  ....  .. }
[ENDIF]

define ADC
{ $01000014  AL    imm8  ....  .. }
{ $01000015  EAX   imm32 ....  .. }
{ $01000012  reg8  r/m8  ....  .. }
{ $01000013  reg32 r/m32 ....  .. }
{ $01000010  r/m8  reg8  ....  .. }
{ $01000011  r/m32 reg32 ....  .. }
{ $01000080  r/m8  imm8  ....  /2 }
{ $01000083  r/m32 iimm8 ....  /2 }
{ $01000081  r/m32 imm32 ....  /2 }

define ADD
{ $01000004  AL    imm8  ....  .. }
{ $01000005  EAX   imm32 ....  .. }
{ $01000002  reg8  r/m8  ....  .. }
{ $01000003  reg32 r/m32 ....  .. }
{ $01000000  r/m8  reg8  ....  .. }
{ $01000001  r/m32 reg32 ....  .. }
{ $01000080  r/m8  imm8  ....  /0 }
{ $01000083  r/m32 iimm8 ....  /0 }
{ $01000081  r/m32 imm32 ....  /0 }

define AND
{ $01000024  AL    imm8  ....  .. }
{ $01000025  EAX   imm32 ....  .. }
{ $01000022  reg8  r/m8  ....  .. }
{ $01000023  reg32 r/m32 ....  .. }
{ $01000020  r/m8  reg8  ....  .. }
{ $01000021  r/m32 reg32 ....  .. }
{ $01000080  r/m8  imm8  ....  /4 }
{ $01000083  r/m32 iimm8 ....  /4 }
{ $01000081  r/m32 imm32 ....  /4 }

X86ASM-PRIV [IF]
define ARPL
{ $01000063  r/m16 reg16 ....  .. }
[ENDIF]

X86ASM-SMALL [IFNOT]
define BOUND
{ $01000062  reg32 r/m32 ....  .. }
[ENDIF]

define BSF
{ $0200BC0F  reg32 r/m32 ....  .. }

define BSR
{ $0200BD0F  reg32 r/m32 ....  .. }

define BSWAP
{ $0200C80F  reg32 ....  ....  /r }
{ <invalid>  reg16 ....  ....  .. }

define BT
{ $0200A30F  r/m32 reg32 ....  .. }
{ $0200BA0F  r/m32 imm8  ....  /4 }

define BTC
{ $0200BB0F  r/m32 reg32 ....  .. }
{ $0200BA0F  r/m32 imm8  ....  /7 }

define BTR
{ $0200B30F  r/m32 reg32 ....  .. }
{ $0200BA0F  r/m32 imm8  ....  /6 }

define BTS
{ $0200AB0F  r/m32 reg32 ....  .. }
{ $0200BA0F  r/m32 imm8  ....  /5 }

define CALL
{ $010000E8  rel32 ....  ....  .. }
{ $010000FF  r/m32 ....  ....  /2 }

define CBW
{ $02009866  ....  ....  ....  .. }

define CWDE
{ $01000098  ....  ....  ....  .. }

;; clear carry flag
define CLC
{ $010000F8  ....  ....  ....  .. }

define CLD
{ $010000FC  ....  ....  ....  .. }

X86ASM-PRIV [IF]
define CLI
{ $010000FA  ....  ....  ....  .. }

;; clear task-switching flag; wtf is this, lol.
define CLTS
{ $0200060F  ....  ....  ....  .. }
[ENDIF]

define CMC
{ $010000F5  ....  ....  ....  .. }
alias CCF -- my mnemonic

define CMOVO
{ $0200400F  reg32 r/m32 ....  .. }

define CMOVNO
{ $0200410F  reg32 r/m32 ....  .. }

define CMOVC
{ $0200420F  reg32 r/m32 ....  .. }
alias CMOVNAE
alias CMOVB

define CMOVNC
{ $0200430F  reg32 r/m32 ....  .. }
alias CMOVNB
alias CMOVAE

define CMOVZ
{ $0200440F  reg32 r/m32 ....  .. }
alias CMOVE

define CMOVNZ
{ $0200450F  reg32 r/m32 ....  .. }
alias CMOVNE

define CMOVNA
{ $0200460F  reg32 r/m32 ....  .. }
alias CMOVBE

define CMOVA
{ $0200470F  reg32 r/m32 ....  .. }
alias CMOVNBE

define CMOVS
{ $0200480F  reg32 r/m32 ....  .. }

define CMOVNS
{ $0200490F  reg32 r/m32 ....  .. }

define CMOVP
{ $02004A0F  reg32 r/m32 ....  .. }
alias CMOVPE

define CMOVNP
{ $02004B0F  reg32 r/m32 ....  .. }
alias CMOVPO

define CMOVL
{ $02004C0F  reg32 r/m32 ....  .. }
alias CMOVNGE

define CMOVNL
{ $02004D0F  reg32 r/m32 ....  .. }
alias CMOVGE

define CMOVLE
{ $02004E0F  reg32 r/m32 ....  .. }
alias CMOVNG

define CMOVG
{ $02004F0F  reg32 r/m32 ....  .. }
alias CMOVNLE

define CMP
{ $0100003C  AL    imm8  ....  .. }
{ $0100003D  EAX   imm32 ....  .. }
{ $0100003A  reg8  r/m8  ....  .. }
{ $0100003B  reg32 r/m32 ....  .. }
{ $01000038  r/m8  reg8  ....  .. }
{ $01000039  r/m32 reg32 ....  .. }
{ $01000080  r/m8  imm8  ....  /7 }
{ $01000083  r/m32 iimm8 ....  /7 }
{ $01000081  r/m32 imm32 ....  /7 }
alias CP -- my mnemonic

define CMPSB
{ $010000A6  ....  ....  ....  .. }

define CMPSW
{ $0200A766  ....  ....  ....  .. }

define CMPSD
{ $010000A7  ....  ....  ....  .. }

define CMPXCHG
{ $0200A60F  r/m8  reg8  ....  .. }
{ $0200A70F  r/m32 reg32 ....  .. }

define CMPXCHG8B
{ $0200C70F  qptr  ....  ....  /1 }

define CPUID
{ $0200A20F  ....  ....  ....  .. }

define CWD
{ $02009966  ....  ....  ....  .. }

define CDQ
{ $01000099  ....  ....  ....  .. }

X86ASM-SMALL [IFNOT]
define DAA
{ $01000027  ....  ....  ....  .. }

define DAS
{ $0100002F  ....  ....  ....  .. }
[ENDIF]

define DEC
{ $01000048  reg32 ....  ....  /r }
{ $010000FF  r/m32 ....  ....  /1 }
{ $010000FE  r/m8  ....  ....  /1 }
{ $0200FF66  r/m16 ....  ....  /1 }

define DIV
{ $010000F6  r/m8  ....  ....  /6 }
{ $010000F7  r/m32 ....  ....  /6 }

X86ASM-SMALL [IFNOT]
define ENTER
{ $010000C8  imm16 imm8  ....  .. }
[ENDIF]

X86ASM-FPU [IF]
define FWAIT
{ $0100009B  ....  ....  ....  .. }

define F2XM1
{ $0200F0D9  ....  ....  ....  .. }

define FABS
{ $0200E1D9  ....  ....  ....  .. }

define FADD
{ $0200C1DE  ....  ....  ....  .. }
{ $010000D8  fdptr ....  ....  /0 }
{ $010000DC  fqptr ....  ....  /0 }
{ $0200C0D8  ST0   STx   ....  /r }
{ $0200C0DC  STx   ST0   ....  /r }

define FADDP
{ $0200C0DE  STx   ST0   ....  /r }

define FIADD
{ $010000DE  fwptr ....  ....  /0 }
{ $010000DA  fdptr ....  ....  /0 }

define FBLD
{ $010000DF  ftptr ....  ....  /4 }

define FBSTP
{ $010000DF  ftptr ....  ....  /6 }

define FCHS
{ $0200E0D9  ....  ....  ....  .. }

define FNCLEX
{ $0200E2DB  ....  ....  ....  .. }

define FCMOVB
{ $0200C0DA  ST0   STx   ....  /r }
{ $0200C0DA  STx   ....  ....  /r }

define FCMOVE
{ $0200C8DA  ST0   STx   ....  /r }
{ $0200C8DA  STx   ....  ....  /r }

define FCMOVBE
{ $0200D0DA  ST0   STx   ....  /r }
{ $0200D0DA  STx   ....  ....  /r }

define FCMOVU
{ $0200D8DA  ST0   STx   ....  /r }
{ $0200D8DA  STx   ....  ....  /r }

define FCMOVNB
{ $0200C0DB  ST0   STx   ....  /r }
{ $0200C0DB  STx   ....  ....  /r }

define FCMOVNE
{ $0200C8DB  ST0   STx   ....  /r }
{ $0200C8DB  STx   ....  ....  /r }

define FCMOVNBE
{ $0200D0DB  ST0   STx   ....  /r }
{ $0200D0DB  STx   ....  ....  /r }

define FCMOVNU
{ $0200D8DB  ST0   STx   ....  /r }
{ $0200D8DB  STx   ....  ....  /r }

define FCOM
{ $0200D1D8  ....  ....  ....  .. }
{ $0200D0D8  STx   ....  ....  /r }
{ $010000D8  fdptr ....  ....  /2 }
{ $010000DC  fqptr ....  ....  /2 }

define FCOMI
{ $0200F0DB  ST0   STx   ....  /r }
{ $0200F0DB  STx   ....  ....  /r }

define FCOMIP
{ $0200F0DF  ST0   STx   ....  /r }
{ $0200F0DF  STx   ....  ....  /r }

define FCOMP
{ $0200D9D8  ....  ....  ....  .. }
{ $0200D8D8  STx   ....  ....  /r }
{ $010000D8  fdptr ....  ....  /3 }
{ $010000DC  fqptr ....  ....  /3 }

define FCOMPP
{ $0200D9DE  ....  ....  ....  .. }

define FUCOMI
{ $0200E8DB  ST0   STx   ....  /r }
{ $0200E8DB  STx   ....  ....  /r }

define FUCOMIP
{ $0200E8DF  ST0   STx   ....  /r }
{ $0200E8DF  STx   ....  ....  /r }

define FCOS
{ $0200FFD9  ....  ....  ....  .. }

define FDECSTP
{ $0200F6D9  ....  ....  ....  .. }

define FDIV
{ $0200F9DE  ....  ....  ....  .. }
{ $010000D8  fdptr ....  ....  /6 }
{ $010000DC  fqptr ....  ....  /6 }
{ $0200F0D8  ST0   STx   ....  /r }
{ $0200F8DC  STx   ST0   ....  /r }

define FDIVP
{ $0200F8DE  STx   ST0   ....  /r }

define FIDIV
{ $010000DE  fwptr ....  ....  /6 }
{ $010000DA  fdptr ....  ....  /6 }

define FDIVR
{ $0200F1DE  ....  ....  ....  .. }
{ $010000D8  fdptr ....  ....  /7 }
{ $010000DC  fqptr ....  ....  /7 }
{ $0200F8D8  ST0   STx   ....  /r }
{ $0200F0DC  STx   ST0   ....  /r }

define FDIVRP
{ $0200F0DE  STx   ST0   ....  /r }
alias FDIVPR

define FIDIVR
{ $010000DE  fwptr ....  ....  /7 }
{ $010000DA  fdptr ....  ....  /7 }

define FFREE
{ $0200C0DD  STx   ....  ....  /r }

define FFREEP
{ $0200C0DF  STx   ....  ....  /r }

define FICOM
{ $010000DE  fwptr ....  ....  /2 }
{ $010000DA  fdptr ....  ....  /2 }

define FICOMP
{ $010000DE  fwptr ....  ....  /3 }
{ $010000DA  fdptr ....  ....  /3 }

define FILD
{ $010000DF  fwptr ....  ....  /0 }
{ $010000DB  fdptr ....  ....  /0 }
{ $010000DF  fqptr ....  ....  /5 }

define FINCSTP
{ $0200F7D9  ....  ....  ....  .. }

define FNINIT
{ $0200E3DB  ....  ....  ....  .. }

define FIST
{ $010000DF  fwptr ....  ....  /2 }
{ $010000DB  fdptr ....  ....  /2 }

define FISTP
{ $010000DF  fwptr ....  ....  /3 }
{ $010000DB  fdptr ....  ....  /3 }
{ $010000DF  fqptr ....  ....  /7 }

define FLD
{ $010000D9  fdptr ....  ....  /0 }
{ $010000DD  fqptr ....  ....  /0 }
{ $010000DB  ftptr ....  ....  /5 }
{ $0200C0D9  STx   ....  ....  /r }

define FLD1
{ $0200E8D9  ....  ....  ....  .. }

define FLDL2T
{ $0200E9D9  ....  ....  ....  .. }

define FLDL2E
{ $0200EAD9  ....  ....  ....  .. }

define FLDPI
{ $0200EBD9  ....  ....  ....  .. }

define FLDLG2
{ $0200ECD9  ....  ....  ....  .. }

define FLDLN2
{ $0200EDD9  ....  ....  ....  .. }

define FLDZ
{ $0200EED9  ....  ....  ....  .. }

define FLDCW
{ $010000D9  fwptr ....  ....  /5 }

define FLDENV
{ $010000D9  fbptr ....  ....  /4 }

define FMUL
{ $0200C9DE  ....  ....  ....  .. }
{ $010000D8  fdptr ....  ....  /1 }
{ $010000DC  fqptr ....  ....  /1 }
{ $0200C8D8  ST0   STx   ....  /r }
{ $0200C8DC  STx   ST0   ....  /r }

define FMULP
{ $0200C8DE  STx   ST0   ....  /r }

define FIMUL
{ $010000DE  fwptr ....  ....  /1 }
{ $010000DA  fdptr ....  ....  /1 }

define FNOP
{ $0200D0D9  ....  ....  ....  .. }

define FPATAN
{ $0200F3D9  ....  ....  ....  .. }

define FPREM
{ $0200F8D9  ....  ....  ....  .. }

define FPREM1
{ $0200F5D9  ....  ....  ....  .. }

define FPTAN
{ $0200F2D9  ....  ....  ....  .. }

define FRNDINT
{ $0200FCD9  ....  ....  ....  .. }

define FRSTOR
{ $010000DD  fbptr ....  ....  /4 }

define FNSAVE
{ $010000DD  fbptr ....  ....  /6 }

define FSCALE
{ $0200FDD9  ....  ....  ....  .. }

define FSIN
{ $0200FED9  ....  ....  ....  .. }

define FSINCOS
{ $0200FBD9  ....  ....  ....  .. }

define FSQRT
{ $0200FAD9  ....  ....  ....  .. }

define FST
{ $010000D9  fdptr ....  ....  /2 }
{ $010000DD  fqptr ....  ....  /2 }
{ $0200D0DD  STx   ....  ....  /r }

define FSTP
{ $010000D9  fdptr ....  ....  /3 }
{ $010000DD  fqptr ....  ....  /3 }
{ $010000DB  ftptr ....  ....  /7 }
{ $0200D8DD  STx   ....  ....  /r }

define FNSTCW
{ $010000D9  fwptr ....  ....  /7 }

define FNSTENV
{ $010000D9  fbptr ....  ....  /6 }

define FNSTSW
{ $010000DD  fwptr ....  ....  /7 }
{ $0200E0DF  AX    ....  ....  .. }

define FSUB
{ $0200E9DE  ....  ....  ....  .. }
{ $010000D8  fdptr ....  ....  /4 }
{ $010000DC  fqptr ....  ....  /4 }
{ $0200E0D8  ST0   STx   ....  /r }
{ $0200E8DC  STx   ST0   ....  /r }

define FSUBP
{ $0200E8DE  STx   ST0   ....  /r }

define FISUB
{ $010000DE  fwptr ....  ....  /4 }
{ $010000DA  fdptr ....  ....  /4 }

define FSUBR
{ $0200E1DE  ....  ....  ....  .. }
{ $010000D8  fdptr ....  ....  /5 }
{ $010000DC  fqptr ....  ....  /5 }
{ $0200E8D8  ST0   STx   ....  /r }
{ $0200E0DC  STx   ST0   ....  /r }

define FSUBRP
{ $0200E0DE  STx   ST0   ....  /r }

define FISUBR
{ $010000DE  fwptr ....  ....  /5 }
{ $010000DA  fdptr ....  ....  /5 }

define FTST
{ $0200E4D9  ....  ....  ....  .. }

define FUCOM
{ $0200E1DD  ....  ....  ....  .. }
{ $0200E0DD  STx   ....  ....  /r }

define FUCOMP
{ $0200E9DD  ....  ....  ....  .. }
{ $0200E8DD  STx   ....  ....  /r }

define FUCOMPP
{ $0200E9DA  ....  ....  ....  .. }

define FXAM
{ $0200E5D9  ....  ....  ....  .. }

define FXCH
{ $0200C9D9  ....  ....  ....  .. }
{ $0200C8D9  STx   ....  ....  /r }

define FXTRACT
{ $0200F4D9  ....  ....  ....  .. }

define FYL2X
{ $0200F1D9  ....  ....  ....  .. }

define FYL2XP1
{ $0200F9D9  ....  ....  ....  .. }

define FCLEX
{ $03E2DB9B  ....  ....  ....  .. }

define FINIT
{ $03E3DB9B  ....  ....  ....  .. }

define FSAVE
{ $0200DD9B  fbptr ....  ....  /6 }

define FSTCW
{ $0200D99B  fwptr ....  ....  /7 }

define FSTENV
{ $0200D99B  fbptr ....  ....  /6 }

define FSTSW
{ $0200DD9B  fwptr ....  ....  /7 }
{ $03E0DF9B  AX    ....  ....  .. }
[ENDIF]

X86ASM-PRIV [IF]
define HLT
{ $010000F4  ....  ....  ....  .. }
[ENDIF]

define IDIV
{ $010000F6  r/m8  ....  ....  /7 }
{ $010000F7  r/m32 ....  ....  /7 }

define IMUL
{ $010000F6  r/m8  ....  ....  /5 }
{ $010000F7  r/m32 ....  ....  /5 }
{ $0200AF0F  reg32 r/m32 ....  .. }
{ $0100006B  reg32 r/m32 iimm8 .. }
{ $01000069  reg32 r/m32 imm32 .. }

X86ASM-PRIV [IF]
define IN
{ $010000E4  AL    imm8  ....  .. }
{ $010000E5  EAX   imm8  ....  .. }
{ $010000EC  AL    DX    ....  .. }
{ $0200ED66  AX    DX    ....  .. } -- matcher cannot automatch it
{ $010000ED  EAX   DX    ....  .. }
[ENDIF]

define INC
{ $01000040  reg32 ....  ....  /r }
{ $010000FF  r/m32 ....  ....  /0 }
{ $010000FE  r/m8  ....  ....  /0 }
{ $0200FF66  r/m16 ....  ....  /0 }

X86ASM-PRIV [IF]
define INSB
{ $0100006C  ....  ....  ....  .. }

define INSW
{ $02006D66  ....  ....  ....  .. }

define INSD
{ $0100006D  ....  ....  ....  .. }
[ENDIF]

define INT3
{ $010000CC  ....  ....  ....  .. }

define INT
{ $010000CD  imm8  ....  ....  .. }

define INTO
{ $010000CE  ....  ....  ....  .. }

X86ASM-PRIV [IF]
define INVD
{ $0200080F  ....  ....  ....  .. }

define INVLPG
{ $0200010F  bptr  ....  ....  /7 }

define IRETW
{ $0200CF66  ....  ....  ....  .. }

define IRETD
{ $010000CF  ....  ....  ....  .. }
[ENDIF]

define JMP
{ $010000EB  rel8  ....  ....  .. }
{ $010000E9  rel32 ....  ....  .. }
{ $010000FF  r/m32 ....  ....  /4 }

define JO
{ $01000070  rel8  ....  ....  .. }
{ $0200800F  rel32 ....  ....  .. }

define JNO
{ $01000071  rel8  ....  ....  .. }
{ $0200810F  rel32 ....  ....  .. }

define JB
{ $01000072  rel8  ....  ....  .. }
{ $0200820F  rel32 ....  ....  .. }
alias JC
alias JNAE
alias J?U<

define JAE
{ $01000073  rel8  ....  ....  .. }
{ $0200830F  rel32 ....  ....  .. }
alias JNB
alias JNC
alias J?U>=

define JE
{ $01000074  rel8  ....  ....  .. }
{ $0200840F  rel32 ....  ....  .. }
alias JZ
alias J?0=
alias J?=

define JNE
{ $01000075  rel8  ....  ....  .. }
{ $0200850F  rel32 ....  ....  .. }
alias JNZ
alias J?0<>
alias J?<>

define JBE
{ $01000076  rel8  ....  ....  .. }
{ $0200860F  rel32 ....  ....  .. }
alias JNA
alias J?U<=

define JA
{ $01000077  rel8  ....  ....  .. }
{ $0200870F  rel32 ....  ....  .. }
alias JNBE
alias J?U>

define JS
{ $01000078  rel8  ....  ....  .. }
{ $0200880F  rel32 ....  ....  .. }
alias J?-

define JNS
{ $01000079  rel8  ....  ....  .. }
{ $0200890F  rel32 ....  ....  .. }
alias J?+0

define JPE
{ $0100007A  rel8  ....  ....  .. }
{ $02008A0F  rel32 ....  ....  .. }
\ alias JP -- nope

define JNP
{ $0100007B  rel8  ....  ....  .. }
{ $02008B0F  rel32 ....  ....  .. }
alias JPO

define JL
{ $0100007C  rel8  ....  ....  .. }
{ $02008C0F  rel32 ....  ....  .. }
alias JNGE
alias J?<

define JGE
{ $0100007D  rel8  ....  ....  .. }
{ $02008D0F  rel32 ....  ....  .. }
alias JNL
alias J?>=

define JLE
{ $0100007E  rel8  ....  ....  .. }
{ $02008E0F  rel32 ....  ....  .. }
alias JNG
alias J?<=

define JG
{ $0100007F  rel8  ....  ....  .. }
{ $02008F0F  rel32 ....  ....  .. }
alias JNLE
alias J?>

define JCXZ -- for some mysterious reason this is using address size prefix
{ $0200E367  rel8  ....  ....  .. }

define JECXZ
{ $010000E3  rel8  ....  ....  .. }

X86ASM-SMALL [IFNOT]
define LAHF
{ $0100009F  ....  ....  ....  .. }
[ENDIF]

X86ASM-PRIV [IF]
define LAR
{ $0200020F  reg32 r/m32 ....  .. }
[ENDIF]

define LEA
{ $0100008D  reg32 r/m32 ....  .. }

X86ASM-SMALL [IFNOT]
define LEAVE
{ $010000C9  ....  ....  ....  .. }
[ENDIF]

X86ASM-PRIV [IF]
define LGDT
{ $0200010F  qptr  ....  ....  /2 }

define LIDT
{ $0200010F  qptr  ....  ....  /3 }
[ENDIF]

X86ASM-SMALL [IFNOT]
define LDS
{ $010000C5  reg32 aptr  ....  .. }

define LES
{ $010000C4  reg32 aptr  ....  .. }

define LSS
{ $0200B20F  reg32 aptr  ....  .. }

define LFS
{ $0200B40F  reg32 aptr  ....  .. }

define LGS
{ $0200B50F  reg32 aptr  ....  .. }
[ENDIF]

X86ASM-PRIV [IF]
define LLDT
{ $0200000F  r/m16 ....  ....  /2 }

define LMSW
{ $0200010F  r/m16 ....  ....  /6 }
[ENDIF]

define LODSB
{ $010000AC  ....  ....  ....  .. }

define LODSW
{ $0200AD66  ....  ....  ....  .. }

define LODSD
{ $010000AD  ....  ....  ....  .. }

define LOOPNZ
{ $010000E0  rel8  ....  ....  .. }
alias LOOPNE

define LOOPZ
{ $010000E1  rel8  ....  ....  .. }
alias LOOPE

define LOOP
{ $010000E2  rel8  ....  ....  .. }

X86ASM-PRIV [IF]
define LSL
{ $0200030F  reg32 r/m32 ....  .. }

define LTR
{ $0200000F  r/m16 ....  ....  /3 }
[ENDIF]

;; count the number of leading zero bits in r/m32, return result in r32
define LZCNT
{ $03BD0FF3  reg32 r/m32 ....  .. }

define MOV
{ $010000A0  AL    bptr  ....  .. }
{ $010000A1  EAX   dptr  ....  .. }
{ $010000A2  bptr  AL    ....  .. }
{ $010000A3  dptr  EAX   ....  .. }
{ $0100008A  reg8  r/m8  ....  .. }
{ $0100008B  reg32 r/m32 ....  .. }
{ $01000088  r/m8  reg8  ....  .. }
{ $01000089  r/m32 reg32 ....  .. }
{ $010000B0  reg8  imm8  ....  /r }
{ $010000B8  reg32 imm32 ....  /r }
{ $010000C6  r/m8  imm8  ....  /0 }
{ $010000C7  r/m32 imm32 ....  /0 }
\ alias LD -- my mnemonic

-- rarely used, do not pollute MOV table
-- MOV is basically most used instruction, so let's make its table smaller
X86ASM-SMALL [IFNOT]
define MOV-SEG
{ $0100008C  r/m32 SR    ....  /r }
{ $0100008E  SR    r/m32 ....  /r }

define MOV-CTR
{ $03C0200F  reg32 ctreg ....  /r }
{ $03C0220F  ctreg reg32 ....  /r }
{ $03C0210F  reg32 dbreg ....  /r }
{ $03C0230F  dbreg reg32 ....  /r }
{ $03C0240F  reg32 tsreg ....  /r }
{ $03C0260F  tsreg reg32 ....  /r }
[ENDIF]

define MOVSB
{ $010000A4  ....  ....  ....  .. }

define MOVSW
{ $0200A566  ....  ....  ....  .. }

define MOVSD
{ $010000A5  ....  ....  ....  .. }
 -- sse
{ $03100FF2  xmreg   xr/m64  ....  /r }
{ $03110FF2  xr/m64  xmreg   ....  /r }

define MOVSX
{ $0200BE0F  reg32 r/m8  ....  .. }
{ $0200BF0F  reg32 r/m16 ....  .. }

define MOVZX
{ $0200B60F  reg32 r/m8  ....  .. }
{ $0200B70F  reg32 r/m16 ....  .. }

define MUL
{ $010000F6  r/m8  ....  ....  /4 }
{ $010000F7  r/m32 ....  ....  /4 }

define NEG
{ $010000F6  r/m8  ....  ....  /3 }
{ $010000F7  r/m32 ....  ....  /3 }

define NOT
{ $010000F6  r/m8  ....  ....  /2 }
{ $010000F7  r/m32 ....  ....  /2 }

define NOP
{ $01000090  ....  ....  ....  .. } -- XCHG EAX, EAX

define OR
{ $0100000C  AL    imm8  ....  .. }
{ $0100000D  EAX   imm32 ....  .. }
{ $0100000A  reg8  r/m8  ....  .. }
{ $0100000B  reg32 r/m32 ....  .. }
{ $01000008  r/m8  reg8  ....  .. }
{ $01000009  r/m32 reg32 ....  .. }
{ $01000080  r/m8  imm8  ....  /1 }
{ $01000083  r/m32 iimm8 ....  /1 }
{ $01000081  r/m32 imm32 ....  /1 }

X86ASM-PRIV [IF]
define OUT
{ $010000E6  imm8  AL    ....  .. }
{ $010000E7  imm8  EAX   ....  .. }
{ $010000EE  DX    AL    ....  .. }
{ $0200EF66  DX    AX    ....  .. } -- matcher cannot automatch it
{ $010000EF  DX    EAX   ....  .. }

define OUTSB
{ $0100006E  ....  ....  ....  .. }

define OUTSW
{ $02006F66  ....  ....  ....  .. }

define OUTSD
{ $0100006F  ....  ....  ....  .. }
[ENDIF]

define POP
{ $01000058  reg32 ....  ....  /r }
{ $0100008F  r/m32 ....  ....  /0 }

X86ASM-SMALL [IFNOT]
define POP-SEG
{ $0100001F  DS    ....  ....  .. }
{ $01000007  ES    ....  ....  .. }
{ $01000017  SS    ....  ....  .. }
{ $0200A10F  FS    ....  ....  .. }
{ $0200A90F  GS    ....  ....  .. }
[ENDIF]

define POPCNT
{ $03B80FF3  reg32 r/m32 ....  .. }

X86ASM-SMALL [IFNOT]
define POPAW
{ $02006166  ....  ....  ....  .. }
[ENDIF]

define POPAD
{ $01000061  ....  ....  ....  .. }

X86ASM-SMALL [IFNOT]
define POPFW
{ $02009D66  ....  ....  ....  .. }

define POPFD
{ $0100009D  ....  ....  ....  .. }
[ENDIF]

define PUSH
{ $01000050  reg32 ....  ....  /r }
{ $010000FF  r/m32 ....  ....  /6 }
{ $0100006A  imm8  ....  ....  .. }
{ $01000068  imm32 ....  ....  .. }

X86ASM-SMALL [IFNOT]
define PUSH-SEG
{ $01000016  SS    ....  ....  .. }
{ $0100001E  DS    ....  ....  .. }
{ $01000006  ES    ....  ....  .. }
{ $0200A00F  FS    ....  ....  .. }
{ $0200A80F  GS    ....  ....  .. }
[ENDIF]

X86ASM-SMALL [IFNOT]
define PUSHAW
{ $02006066  ....  ....  ....  .. }
[ENDIF]

define PUSHAD
{ $01000060  ....  ....  ....  .. }

X86ASM-SMALL [IFNOT]
define PUSHFW
{ $02009C66  ....  ....  ....  .. }

define PUSHFD
{ $0100009C  ....  ....  ....  .. }
[ENDIF]

define RCL
{ $010000D0  r/m8  ....  ....  /2 }
{ $010000D2  r/m8  CL    ....  /2 }
{ $010000C0  r/m8  imm8  ....  /2 }
{ $010000D1  r/m32 ....  ....  /2 }
{ $010000D3  r/m32 CL    ....  /2 }
{ $010000C1  r/m32 imm8  ....  /2 }

define RCR
{ $010000D0  r/m8  ....  ....  /3 }
{ $010000D2  r/m8  CL    ....  /3 }
{ $010000C0  r/m8  imm8  ....  /3 }
{ $010000D1  r/m32 ....  ....  /3 }
{ $010000D3  r/m32 CL    ....  /3 }
{ $010000C1  r/m32 imm8  ....  /3 }

define ROL
{ $010000D0  r/m8  ....  ....  /0 }
{ $010000D2  r/m8  CL    ....  /0 }
{ $010000C0  r/m8  imm8  ....  /0 }
{ $010000D1  r/m32 ....  ....  /0 }
{ $010000D3  r/m32 CL    ....  /0 }
{ $010000C1  r/m32 imm8  ....  /0 }

define ROR
{ $010000D0  r/m8  ....  ....  /1 }
{ $010000D2  r/m8  CL    ....  /1 }
{ $010000C0  r/m8  imm8  ....  /1 }
{ $010000D1  r/m32 ....  ....  /1 }
{ $010000D3  r/m32 CL    ....  /1 }
{ $010000C1  r/m32 imm8  ....  /1 }

define RDTSC
{ $0200310F  ....  ....  ....  .. }

X86ASM-PRIV [IF]
define RDMSR
{ $0200320F  ....  ....  ....  .. }
[ENDIF]

define RET
{ $010000C2  imm16 ....  ....  .. }
{ $010000C3  ....  ....  ....  .. }

X86ASM-SMALL [IFNOT]
define RETF
{ $010000CA  imm16 ....  ....  .. }
{ $010000CB  ....  ....  ....  .. }
[ENDIF]

X86ASM-FPU [IF]
define SAHF
{ $0100009E  ....  ....  ....  .. }
[ENDIF]

X86ASM-SMALL [IFNOT]
;; set AL to $FF if carry set, otherwise to $00
;; flags are unaffected
define SALC
{ $010000D6  ....  ....  ....  .. }
alias SETALC
[ENDIF]

define SAL
{ $010000D0  r/m8  ....  ....  /4 }
{ $010000D2  r/m8  CL    ....  /4 }
{ $010000C0  r/m8  imm8  ....  /4 }
{ $010000D1  r/m32 ....  ....  /4 }
{ $010000D3  r/m32 CL    ....  /4 }
{ $010000C1  r/m32 imm8  ....  /4 }
alias SHL

define SAR
{ $010000D0  r/m8  ....  ....  /7 }
{ $010000D2  r/m8  CL    ....  /7 }
{ $010000C0  r/m8  imm8  ....  /7 }
{ $010000D1  r/m32 ....  ....  /7 }
{ $010000D3  r/m32 CL    ....  /7 }
{ $010000C1  r/m32 imm8  ....  /7 }

define SHR
{ $010000D0  r/m8  ....  ....  /5 }
{ $010000D2  r/m8  CL    ....  /5 }
{ $010000C0  r/m8  imm8  ....  /5 }
{ $010000D1  r/m32 ....  ....  /5 }
{ $010000D3  r/m32 CL    ....  /5 }
{ $010000C1  r/m32 imm8  ....  /5 }

define SBB
{ $0100001C  AL    imm8  ....  .. }
{ $0100001D  EAX   imm32 ....  .. }
{ $0100001A  reg8  r/m8  ....  .. }
{ $0100001B  reg32 r/m32 ....  .. }
{ $01000018  r/m8  reg8  ....  .. }
{ $01000019  r/m32 reg32 ....  .. }
{ $01000080  r/m8  imm8  ....  /3 }
{ $01000083  r/m32 iimm8 ....  /3 }
{ $01000081  r/m32 imm32 ....  /3 }

define SCASB
{ $010000AE  ....  ....  ....  .. }

define SCASW
{ $0200AF66  ....  ....  ....  .. }

define SCASD
{ $010000AF  ....  ....  ....  .. }


define SETO
{ $0200900F  r/m8  ....  ....  .. }

define SETNO
{ $0200910F  r/m8  ....  ....  .. }

define SETB
{ $0200920F  r/m8  ....  ....  .. }
alias SETC
alias SETNAE

define SETAE
{ $0200930F  r/m8  ....  ....  .. }
alias SETNB
alias SETNC

define SETE
{ $0200940F  r/m8  ....  ....  .. }
alias SETZ

define SETNE
{ $0200950F  r/m8  ....  ....  .. }
alias SETNZ

define SETBE
{ $0200960F  r/m8  ....  ....  .. }
alias SETNA

define SETA
{ $0200970F  r/m8  ....  ....  .. }
alias SETNBE

define SETS
{ $0200980F  r/m8  ....  ....  .. }

define SETNS
{ $0200990F  r/m8  ....  ....  .. }

define SETP
{ $02009A0F  r/m8  ....  ....  .. }
alias SETPE

define SETNP
{ $02009B0F  r/m8  ....  ....  .. }
alias SETPO

define SETL
{ $02009C0F  r/m8  ....  ....  .. }
alias SETNGE

define SETGE
{ $02009D0F  r/m8  ....  ....  .. }
alias SETNL

define SETLE
{ $02009E0F  r/m8  ....  ....  .. }
alias SETNG

define SETG
{ $02009F0F  r/m8  ....  ....  .. }
alias SETNLE

X86ASM-PRIV [IF]
define SGDT
{ $0200010F  bptr  ....  ....  /0 }

define SIDT
{ $0200010F  bptr  ....  ....  /1 }
[ENDIF]

define SHLD
{ $0200A40F  r/m32 reg32 imm8  .. }
{ $0200A50F  r/m32 reg32 CL    .. }

define SHRD
{ $0200AC0F  r/m32 reg32 imm8  .. }
{ $0200AD0F  r/m32 reg32 CL    .. }

X86ASM-PRIV [IF]
define SLDT
{ $0200000F  r/m16 ....  ....  /0 }

define SMSW
{ $0200010F  r/m16 ....  ....  /4 }
[ENDIF]

define STC
{ $010000F9  ....  ....  ....  .. }
alias SCF -- my mnemonic

define STD
{ $010000FD  ....  ....  ....  .. }

X86ASM-PRIV [IF]
define STI
{ $010000FB  ....  ....  ....  .. }
[ENDIF]

define STOSB
{ $010000AA  ....  ....  ....  .. }

define STOSW
{ $0200AB66  ....  ....  ....  .. }

define STOSD
{ $010000AB  ....  ....  ....  .. }

X86ASM-PRIV [IF]
define STR
{ $0200000F  r/m16 ....  ....  /1 }
[ENDIF]

define SUB
{ $0100002C  AL    imm8  ....  .. }
{ $0100002D  EAX   imm32 ....  .. }
{ $0100002A  reg8  r/m8  ....  .. }
{ $0100002B  reg32 r/m32 ....  .. }
{ $01000028  r/m8  reg8  ....  .. }
{ $01000029  r/m32 reg32 ....  .. }
{ $01000080  r/m8  imm8  ....  /5 }
{ $01000083  r/m32 iimm8 ....  /5 }
{ $01000081  r/m32 imm32 ....  /5 }

define TEST
{ $010000A8  AL    imm8  ....  .. }
{ $010000A9  EAX   imm32 ....  .. }
{ $01000084  r/m8  reg8  ....  .. }
{ $01000085  r/m32 reg32 ....  .. }
{ $010000F6  r/m8  imm8  ....  /0 }
{ $010000F7  r/m32 imm32 ....  /0 }

;; count the number of trailing zero bits in r/m32, return result in r32
define TZCNT
{ $03BC0FF3  reg32 r/m32 ....  .. }

X86ASM-PRIV [IF]
define VERR
{ $0200000F  r/m16 ....  ....  /4 }

define VERW
{ $0200000F  r/m16 ....  ....  /5 }
[ENDIF]

X86ASM-FPU [IF]
define WAIT
{ $0100009B  ....  ....  ....  .. }
[ENDIF]

X86ASM-PRIV [IF]
define WBINVD
{ $0200090F  ....  ....  ....  .. }

define WRMSR
{ $0200300F  ....  ....  ....  .. }
[ENDIF]

define XADD
{ $0200C00F  r/m8  reg8  ....  .. }
{ $0200C10F  r/m32 reg32 ....  .. }

define XCHG
{ $01000090  EAX   reg32 ....  /r }
{ $01000090  reg32 EAX   ....  /r }
{ $01000086  reg8  r/m8  ....  .. }
{ $01000087  reg32 r/m32 ....  .. }
{ $01000086  r/m8  reg8  ....  .. }
{ $01000087  r/m32 reg32 ....  .. }

define XLAT -- [EBX+(unsigned)AL] implied
{ $010000D7  ....  ....  ....  .. }
alias XLATB

define XOR
{ $01000034  AL    imm8  ....  .. }
{ $01000035  EAX   imm32 ....  .. }
{ $01000032  reg8  r/m8  ....  .. }
{ $01000033  reg32 r/m32 ....  .. }
{ $01000030  r/m8  reg8  ....  .. }
{ $01000031  r/m32 reg32 ....  .. }
{ $01000080  r/m8  imm8  ....  /6 }
{ $01000083  r/m32 iimm8 ....  /6 }
{ $01000081  r/m32 imm32 ....  /6 }

X86ASM-SMALL [IFNOT]
define ES:
{ $01000026  ....  ....  ....  .. }

define CS:
{ $0100002E  ....  ....  ....  .. }

define SS:
{ $01000036  ....  ....  ....  .. }

define DS:
{ $0100003E  ....  ....  ....  .. }

define FS:
{ $01000064  ....  ....  ....  .. }

define GS:
{ $01000065  ....  ....  ....  .. }
[ENDIF]

define REPNZ
{ $010000F2  ....  ....  ....  .. }
alias REPNE

define REP
{ $010000F3  ....  ....  ....  .. }
alias REPZ
alias REPE

define LOCK
{ $010000F0  ....  ....  ....  .. }

X86ASM-SMALL [IFNOT]
define MOVUPS
{ $0200100F  xmreg   xr/m128 ....  /r }
{ $0200110F  xr/m128 xmreg   ....  /r }

define MOVUPD
{ $03100F66  xmreg   xr/m128 ....  /r }
{ $03110F66  xr/m128 xmreg   ....  /r }

define MOVSS
{ $03100FF3  xmreg   xr/m32  ....  /r }
{ $03110FF3  xr/m32  xmreg   ....  /r }

define MOVLPD
{ $03120F66  xmreg   m64     ....  /r }
{ $03130F66  m64     xmreg   ....  /r }
[ENDIF]

;; Linux x86 syscall (INT 0x80)
define SYS-CALL
{ $020080CD  ....  ....  ....  .. }

end-instructions

here swap - ." x86asm opcode table size: " 0.r cr
