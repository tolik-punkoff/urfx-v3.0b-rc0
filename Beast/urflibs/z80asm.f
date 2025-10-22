;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Forth-style prefix Z80 assembler
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
contrary to UrAsm, which is a standalone Z80 assembler application,
this is Forth-style cross-asm, intended to use in Forth code. it is
modelled after most other prefix Forth assemblers: it sets pointer
to instruction compile word, then collects operands on asm stack, and
then builds the instruction.

see "tests/z80asm-test.f" for examples. basically, the syntax is:

  ld a, # 69     -- immediate
  ld a, () 69    -- address
  ld a, (ix+) 69 -- indexing

the order doesn't matter, so "ld a, 69 #" is ok too. this is useful
for instructions like "ld $4000 (), hl". it is also possible to write
"ld a , b", because comma is a word by itself.

the assembler checks for most common errors, and reject most invalid
instructions, but may ocasionally miss something. watch your steps!

if you need to flush current instruction, use "z80asm:a;". it is safe
to call "a;" several times. by default, each new instruction flushes
the last one.

WARNING! flusher doesn't expect anything unrelated to instructions
argument on the data stack! i.e. "0x29a z80asm:a;" *MAY* fail. move
all unrelated data to return stack (or some other place) before
calling the flusher.

in asm mode, you can use "flush!" to flush current instruction.
there is also "$here", which flushes, and then returns current PC.

undocumented 3-operand BIT/SET/RES (and 2-operand extended shifts) are
not supported.

to create a label manager, set label callbacks, and use special words
for labels. such words should set "z80asm:arg-label" to label index.
it should also left label value on the stack, to allow " # lbl 3 + ".
for labels with yet unknown values, use, for example, "emit:$$".

or simply use "z80-labman" library, which is designed to work with
this asm, automaticaly resolves forwards, automaticaly declaring
labels, and so on.
*)

module z80asm

<published-words>
;; label types for "<label>"
enum{
  def: ltype-disp
  def: ltype-rel8
  def: ltype-byte
  def: ltype-word
}

;; set this if operand used a label
0 quan arg-label  -- label index for the current operand

module emit
<disable-hash>
<published-words>
;; current instruction start virtual address.
;; this is set by the assembler! no need to set it yourself.
0 quan $$

;; target address space words
vect c,   ( byte )
vect here ( -- addr )
vect c@   ( addr -- byte ) -- should *ALWAYS* return a proper byte
vect c!   ( byte addr )    -- should use "lo-byte" on value

;; called before emiting a label
vect <label> ( value type idx -- value )

vect-empty <instr ( -- ) -- called before emiting the instruction code
  ;; can use the following words: "i-ixy", "i-opc"
vect-empty instr> ( -- ) -- called after the instruction is finished (all bytes emited)
vect-empty <disp8> ( val -- val ) -- called before emiting ix/iy displacement
vect-empty <jrdisp8> ( val -- val ) -- called before emiting relative jump displacement
vect-empty <val8> ( val -- val ) -- called before emiting 8-bit value
vect-empty <val16> ( val -- val ) -- called before emiting 16-bit value
;; 16-bit address is "val16" too

;; that is, the callbacks may be used to record fixup addresses, for example.
;; `i-ixy` returns ix/iy prefix for the current instruction, or 0.
;; `i-opc` returns the current opcode. 2-byte opcodes have non-zero high byte (it is emited first).

;; handy words
: w,  ( word )
  dup lo-byte @@current:c,
  hi-byte @@current:c, ;

: w@  ( addr -- word )
  dup @@current:c@ swap 1+ @@current:c@ 256 * or ;

: w!  ( word addr )
  2dup @@current:c!
  swap hi-byte swap 1+ @@current:c! ;

end-module emit


<public-words>

false quan postfix-mode (private)
;; if no operand type was specified, assume "#".
;; this is to make things like the following work:
;;   ld  hl, $4000
;; instead of:
;;   ld  hl, # $4000
;; it will also allow omiting "#" in jumps:
;;   jp  nz, .label
true quan assume-# (private)

;; we actually don't need a stack for operands
0 quan ixy          -- IX($dd)/IY($fd) prefix, or 0; bit 8 is set if displacement is required
0 quan ixy-disp     -- displacement for (ix+...)/(iy+...)
0 quan disp-label   -- label index for "ixy-disp"
0 quan opcode       -- `<0` if none, otherwise 1 or 2 bytes; high byte emits first
0 quan op0          -- source operand or 0
0 quan op1          -- destination operand or 0
0 quan imm-sz       -- immediate operand size (from data stack): 0, 1, 2; bit 8: set if jr-disp
0 quan imm-val      -- immediate or address
0 quan imm-type     -- imm-val type ("imm" for number, "addr" for memref)
0 quan imm-label    -- label index for imm
vect-empty builder  -- instruction builder
0 quan opn-#fix     -- 0:none; 1:op1; 2:op2; 3:op2 if present, else op1
0 quan depth-start  -- saved depth on instruction start
0 quan depth-comma  -- saved depth after ","

;; for callbacks
@: i-ixy  ( -- flag )  ixy ;
@: i-opc  ( -- flag )  opcode ;

$c0_de constant comma  ;; special opcode for comma

$01_00 constant reg8
$02_00 constant reg16
$03_00 constant rm16
$04_00 constant cond
$05_00 constant ir8
$06_00 constant imm
$07_00 constant addr
$08_00 constant bit#
$09_00 constant port(c)

: optype  ( op -- optype )  $ff00 and ;
alias-for lo-byte is opval  ( op -- opval )


: bad-instr  error" invalid instruction" ;
: ?bad-instr  ( flag )  ?< bad-instr >? ;
: 0?bad-instr ( flag )  0= ?bad-instr ;

: (no-instr)  -1 opcode:! ;

@: asm-reset
  ixy:!0 ixy-disp:!0 op0:!0 op1:!0
  imm-sz:!0 imm-val:!0 imm-type:!0 arg-label:!0
  disp-label:!0 imm-label:!0 emit:here emit:$$:!
  opn-#fix:!0
  depth depth-start:! -1 depth-comma:!
  (no-instr) ['] (no-instr) builder:! ;

|: check-imm16  ( value type )
  swap addr = ?< 0 65535 bounds || -32768 65536 within >?
  not?error" z80asm: invalid 16-bit operand" ;

|: get-imm/addr  ( value op )
  imm-type ?error" too many imm/addr values"
  dup hi-word ?error" invalid operand (imm)"
  optype
  2dup check-imm16
  imm-type:! imm-val:! arg-label imm-label:! ;

|: get-ixy-imm  ( value )
  dup -128 128 within not?<
    " invalid displacement: " pad$:!
    pad$:#s  pad$:@ error
  >?
  lo-byte ixy-disp:! arg-label disp-label:! ;

;; called on operand flush
: get-imm  ( [value] op )
  dup optype
  ( [value] op optype )
  dup imm = swap addr = or ?< get-imm/addr
  || hi-word ?< get-ixy-imm >?
  >?
  arg-label:!0 ;

|: ?<label>  ( value type idx -- value )
  dup ?< emit:<label> || 2drop >? ;

|: (ixy-disp,)
  ixy hi-byte ?< ixy-disp ltype-disp disp-label ?<label>
                 emit:<disp8> emit:c, ixy:!0 >? ;

|: build-instr-ixy-prefix
  ixy dup ?< lo-byte emit:c, || drop >? ;

|: build-instr-opc
  opcode dup hi-byte dup ?<
    emit:c, ( 3rd byte is always IXY disp ) (ixy-disp,)
  || drop >? lo-byte emit:c, (ixy-disp,) ;

|: build-instr-rel8
  imm-val ltype-rel8 imm-label ?<label> emit:<jrdisp8> emit:c, ;

|: build-instr-imm8
  imm-val ltype-byte imm-label ?<label> emit:<val8> emit:c, ;

|: build-instr-imm8/rel8
  imm-sz hi-byte ?exit< build-instr-rel8 >?
  build-instr-imm8 ;

|: build-instr-imm16
  ltype-word imm-label ?<label> imm-val emit:<val16> emit:w, ;

|: build-instr-imm
  imm-sz lo-byte <<
    1 of?v| build-instr-imm8/rel8 |?
    2 of?v| build-instr-imm16 |?
  else| ?error" z80asm: bad imm-sz" >> ;

|: build-instr  ( opcode )
  emit:here emit:$$:!
  emit:<instr
    build-instr-ixy-prefix
    build-instr-opc
    build-instr-imm
  emit:instr> ;

|: need-fix-ops?  ( -- flag )
  assume-# not?exit&leave
  builder:@ ['] (no-instr) <> ;

|: fix-op0
  op0 ?exit
  op1 ?exit
  opn-#fix dup 1 = swap 3 = or not?exit
  \ depth depth-start - 1 < not?exit
  [ 0 ] [IF]
    endcr ." FIX op0 (" opn-#fix 0.r ." )\n"
    endcr ." opcode=" opcode .hex4 cr
    endcr ." op0=" op0 .hex4 ."  op1=" op1 .hex4 cr
    endcr ." depth=" depth . ." start=" depth-start . ." comma=" depth-comma 0.r cr
    system:(include-fname) type ."  at " system:(include-line#) 0.r cr
  [ENDIF]
  imm op0:! ;

|: fix-op1
  op0 not?exit
  op1 comma = not?exit
  opn-#fix dup 2 = swap 3 = or not?exit
  \ depth depth-comma - 1 < not?< arg-label not?exit >?
  [ 0 ] [IF]
    endcr ." FIX op1 (" opn-#fix 0.r ." )\n"
    endcr ." opcode=" opcode .hex4 cr
    endcr ." op0=" op0 .hex4 ."  op1=" op1 .hex4 cr
    endcr ." depth=" depth . ." start=" depth-start . ." comma=" depth-comma 0.r cr
    system:(include-fname) type ."  at " system:(include-line#) 0.r cr
  [ENDIF]
  imm op1:! ;

;; build the instruction
;; opcode is not valid until "builder" is called! oops.
@: a;
  need-fix-ops? ?< fix-op0 fix-op1 >?
  op1 dup comma = ?error" stray comma"
  dup not?< drop op0 >? get-imm
  op0 lo-word op0:! op1 lo-word op1:!
  builder opcode +0?< build-instr >?
  asm-reset ;

@: flush  a; ;

@: calc-jr-disp  ( disp-byte-addr dest-addr -- disp )  swap 1+ - ;
@: jr-disp>addr  ( disp-byte-addr disp-byte -- addr )  c>s + 1+ ;

@: postfix?  ( -- flag )  postfix-mode ;
@: postfix!  ( flag )     a; 0<> postfix-mode:! ;

@: assume-#? ( -- flag )  assume-# ;
@: assume-#! ( flag )     a; 0<> assume-#:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; instruction operands
;;

<published-words>
module instr
: flush!  a; ;
: $here   a; emit:here ;
end-module instr
<public-words>

|: (xflush)  ( pfa -- pfa )  postfix-mode not?< >r a; r> >? ;

|: (builder!)  ( cfa )
  builder:! postfix-mode ?< a; >? ;


0 quan latest-instr-pfa (private)
;; instruction word data:
;;   dd opcode
;;   dd builder-cfa
;;   dd imm-arg -- for `assume-#`
;;        1: op0 can be imm
;;        2: op1 can be imm
;;        3: op0 if no op1, else op1
: mk-instr  ( opcode )  \ name builder-name
  <builds , -find-required , 0 ,
  system:latest-pfa latest-instr-pfa:!
  does> (xflush) @++ opcode:! @++ swap @ opn-#fix:! (builder!) ;

|: (set-last-instr-#fix)  ( n )  latest-instr-pfa 4+ 4+ ! ;

: last-instr-imm-op0     1 (set-last-instr-#fix) ;
: last-instr-imm-op1     2 (set-last-instr-#fix) ;
: last-instr-imm-op0or1  3 (set-last-instr-#fix) ;

: put-op  ( value )
  op0 not?< op0:! || op1 comma <> ?error" missing comma/extra operand" op1:! >? ;

: mk-op  ( hibyte lobyte -- hibyte )  \ name
  over or <builds , does> @ put-op ;

;; special case
;; we need to check if another register is like this too
@: mk-op-(hl)  ( hibyte lobyte -- hibyte )  \ name
  over or <builds ,
  does> ixy ?error" register mismatch" @ put-op ;

*: [op@]  ( -- value )  \ name
  parse-name vocid: instr find-in-vocid not?error" wut?!" dart:cfa>pfa @ [\\] {#,} ;


extend-module instr
;; 8-bit registers
reg8
  $00 mk-op B
  $01 mk-op C
  $02 mk-op D
  $03 mk-op E
  $04 mk-op H
  $05 mk-op L
  $06 mk-op-(hl) (HL)
  $07 mk-op A
drop
;; 16-bit registers
reg16
  $00 mk-op BC
  $01 mk-op DE
  $02 mk-op HL
  $03 mk-op SP
  $13 mk-op AF
  $33 mk-op AFX
  $33 mk-op AF'
drop
;; 16-bit memreg
rm16
  $00 mk-op (BC)
  $01 mk-op (DE)
  $02 mk-op (SP)
drop
;; for OUT; allow OUT (BC) too
port(c)
  $00 mk-op (C)
drop
;; conditions
cond
  $00 mk-op NZ
  $01 mk-op Z
  $02 mk-op NC
  ;; alas, "C" is the register too; we'll hack around it
  $04 mk-op PO
  $05 mk-op PE
  $06 mk-op P
  $07 mk-op M
drop
;; special 8-bit registers
ir8
  $00 mk-op I
  $08 mk-op R
drop

 imm $00 mk-op #  drop  -- immediate number
addr $00 mk-op () drop  -- memory address
end-module instr


|: (set-ixy)  ( pfa )
  dup @ put-op 4+ @ ixy:! ;

;; special case
;; we need to check if another register is like this too
@: mk-hlxy  ( pfx regnum )  \ name
  <builds , ,
  does> ixy ?<
    dup 4+ @ ixy <> ?error" register mismatch"
    op0 dup [op@] H = swap [op@] L = or not?error" register mismatch"
  >? (set-ixy) ;

;; special case
;; we need to check if another register is like this too
@: mk-ixy  ( pfx regnum )  \ name
  <builds , ,
  does> ixy ?error" double index register" (set-ixy) ;

;; this is even more special: "IX, IX" and "IY, IY" are allowed
@: mk-ixy-spc  ( pfx )  \ name
  <builds ,
  does> @ ixy ?< dup ixy <> ?error" double index register" >?
        ixy:! ( [op@] hl ) [op@] HL put-op ;

extend-module instr
  ;; this is special: "IX, IX" and "IY, IY" are allowed
  $00_DD mk-ixy-spc IX
  $00_FD mk-ixy-spc IY

  $01_DD [op@] (HL) mk-ixy (IX)
  $01_FD [op@] (HL) mk-ixy (IY)
  $01_DD [op@] (HL) $1_0000 or mk-ixy (IX+)
  $01_FD [op@] (HL) $1_0000 or mk-ixy (IY+)

  $DD [op@] H mk-hlxy XH
  $DD [op@] L mk-hlxy XL
  $FD [op@] H mk-hlxy YH
  $FD [op@] L mk-hlxy YL
  alias-for XH is IXH
  alias-for XL is IXL
  alias-for YH is IYH
  alias-for YL is IYL
end-module instr

extend-module instr
;; comma is a kind of operand, yeah
: ,
  op1 ?error" too many operands"
  op0 0?<
    opn-#fix 1 = assume-#? lor ?<
      depth depth-start - 1 >= ?< imm op0:! >? >?
  >?
  op0 dup not?error" missing first operand"
  get-imm comma op1:!
  depth depth-comma:!
;

: $
  op1 dup not?< drop op0 >?
  dup [op@] # = swap [op@] () = or not?error" dollar what?"
  emit:here ;
end-module instr

;; handy aliases with a comma
;; we still need them!
: mk-op,  \ name
  parse-name dup not?error" name expected"
  2dup + 1- forth:c@ [char] , <> ?error" bad name"
  2dup system:mk-colon drop
  1- vocid: instr find-in-vocid not?error" wuta?"
  \, \\ instr:, system:semi-finish ;

extend-module instr
  mk-op, B, mk-op, C,
  mk-op, D, mk-op, E,
  mk-op, H, mk-op, L,
  mk-op, (HL), mk-op, A,

  mk-op, BC, mk-op, DE,
  mk-op, HL, mk-op, SP,
  mk-op, AF,

  mk-op, (BC), mk-op, (DE),
  mk-op, (SP),

  mk-op, (C),

  mk-op, NZ, mk-op, Z,
  mk-op, NC,
  mk-op, PO, mk-op, PE,
  mk-op, P, mk-op, M,

  mk-op, I, mk-op, R,

  mk-op, #, mk-op, (),

  mk-op, IX, mk-op, IY,
  mk-op, (IX), mk-op, (IY),
  mk-op, (IX+), mk-op, (IY+),

  mk-op, XH, mk-op, XL,
  mk-op, YH, mk-op, YL,

  mk-op, IXH, mk-op, IXL,
  mk-op, IYH, mk-op, IYL,
end-module instr

: mk-bit#  ( value )  \ name
  <builds bit# or , does> @
  ;; hack for "# n,"
  op1 0= op0 [op@] # = land ?< op0:!0 >?
  put-op instr:, ;

extend-module instr
  $00 mk-bit# 0,
  $01 mk-bit# 1,
  $02 mk-bit# 2,
  $03 mk-bit# 3,
  $04 mk-bit# 4,
  $05 mk-bit# 5,
  $06 mk-bit# 6,
  $07 mk-bit# 7,

  (*
  $00 mk-bit# #0,
  $01 mk-bit# #1,
  $02 mk-bit# #2,
  $03 mk-bit# #3,
  $04 mk-bit# #4,
  $05 mk-bit# #5,
  $06 mk-bit# #6,
  $07 mk-bit# #7,
  *)
end-module instr


: nops? ( -- flag )  op0 0= ;
: 1op?  ( -- flag )  op0 op1 0= land ;
: 2op?  ( -- flag )  op1 dup 0<> swap comma <> land ;

: reg8?  ( op -- flag )  optype reg8 = ;
: reg16-any?  ( op -- flag )  optype reg16 = ;
: reg16-rr?  ( op -- flag )  [op@] BC [op@] SP bounds ;
: reg16-norm?  ( op -- flag )  [op@] BC [op@] HL bounds ;
: cond?  ( op -- flag )  optype cond = ;
: ir?  ( op -- flag )  optype ir8 = ;
: sp?  ( op -- flag )  [op@] SP = ;
: hl?  ( op -- flag )  [op@] HL = ;
: (hl)?  ( op -- flag )  [op@] (HL) = ;
: (ixy+)?  ( -- flag )  ixy hi-byte ;
: (ixy+0)?  ( -- flag )  (ixy+)? dup ?< drop ixy-disp 0= >? ;
: a?  ( op -- flag )  [op@] A = ;
: port(c)?  ( op )  [op@] (C) = ;
: h/l?  ( op )  dup [op@] H = swap [op@] H = or ;
: bit?  ( -- flag ) op0 optype bit# = ;
: bc/de/sp?  ( op -- flag )  dup [op@] BC >= swap [op@] SP <= land ;
: (bc)/(de)?  ( op -- flag )  dup [op@] (BC) = swap [op@] (DE) = or ;
: op-imm?  ( op -- flag ) optype dup imm = swap addr = or ;

;; ignores XH, etc.
: ixy?  ( -- flag )
  ixy 1 $ff bounds dup ?< drop op0 h/l? op1 h/l? or 0= >? ;
  \ ?exit&leave op0 h/l? op1 h/l? or 0= ;
  \ op1 ?< op0 h/l? op1 h/l? or 0= || true >? ;
  \ ixy dup not?exit 1 $ff bounds 0= ;

: ?nops  nops? not?error" no operands expected" ;
: ?1op   1op? not?error" one operand expected" ;
: ?2op   2op? not?error" two operands expected" ;
: ?1/2op nops? ?error" one or two operands expected" ;

;; convert "C" register to "C" condition
: ?cond
  op0 dup [op@] C = ?< drop [ cond $03 or ] {#,} dup op0:! >?
  cond? not?error" condition expected" ;

: (?r16-intr)  ( flag )  not?error" 16-bit register expected" ;
: ?reg16-any  ( op )  reg16-any? (?r16-intr) ;
: ?reg16-rr  ( op )  reg16-rr? (?r16-intr) ;
: ?reg8  ( op )  reg8? not?error" 8-bit register expected" ;
: ?reg8-no-(hl)  ( op ) dup ?reg8 [op@] (HL) = ?error" (HL) is forbidden" ;


: imm-mem?  imm-type addr = ;
: imm-imm?  imm-type imm = ;

: ?imm-word?  ( okflag )
  not?error" address expected"
  imm-val 0 65535 bounds not?exit<
    " invalid address: " pad$:! imm-val <#signed> pad$:+  pad$:@ error
  >?
  2 imm-sz:! ;

: ?imm-mem   imm-mem? ?imm-word? ;
: ?imm-addr  imm-imm? ?imm-word? ;

: ?imm-value  ( -- value )  imm-imm? not?error" value expected" imm-val ;

: ?imm-byte
  ?imm-value -128 256 within not?error" byte value expected" imm-sz:!1 ;

: ?imm-word
  ?imm-value -32768 65536 within not?error" word value expected" 2 imm-sz:! ;

: ?imm-port
  imm-mem? not?error" port expected"
  imm-val 0 256 within not?error" invalid port number" imm-sz:!1 ;

: ?a  ( op -- flag )  a? not?error" A register expected" ;


|: simple-builder  ?nops ;

: simple-instr  ( opcode )  \ name
  <builds , does> (xflush) @ opcode:! ['] simple-builder (builder!) ;

\ instructions without operands
extend-module instr
  $00 simple-instr NOP   $ED44 simple-instr NEG
  $07 simple-instr RLCA    $0F simple-instr RRCA
  $17 simple-instr RLA     $1F simple-instr RRA
  $27 simple-instr DAA     $2F simple-instr CPL
  $37 simple-instr SCF     $3F simple-instr CCF
  $76 simple-instr HALT    $D9 simple-instr EXX
  $F3 simple-instr DI      $FB simple-instr EI
$EDA0 simple-instr LDI   $EDB0 simple-instr LDIR
$EDA1 simple-instr CPI   $EDB1 simple-instr CPIR
$EDA2 simple-instr INI   $EDB2 simple-instr INIR
$EDA3 simple-instr OUTI  $EDB3 simple-instr OTIR
$EDA8 simple-instr LDD   $EDB8 simple-instr LDDR
$EDA9 simple-instr CPD   $EDB9 simple-instr CPDR
$EDAA simple-instr IND   $EDBA simple-instr INDR
$EDAB simple-instr OUTD  $EDBB simple-instr OTDR
$ED67 simple-instr RRD   $ED6F simple-instr RLD
$ED45 simple-instr RETN  $ED4D simple-instr RETI
end-module instr

\ RST # addr
: rst-builder
  ?1op imm-type imm = not?error" address expected"
  imm-val dup 0 $38 bounds over $03 and 0= land not?error" invalid RST address"
  opcode or opcode:! ;

extend-module instr
0o307 mk-instr RST rst-builder
last-instr-imm-op0
end-module instr

\ IM # value
: im-builder
  ?1op imm-type imm = not?error" number expected"
  imm-val dup 0 2 bounds not?error" invalid IM mode"
  dup ?< 1- 2 or 8 * opcode or opcode:! || drop >? ;

extend-module instr
$ED46 mk-instr IM im-builder
last-instr-imm-op0
end-module instr

\ EX r16, r16
|: ex-r16  ( op0 -- opcode-part )
  << [op@] (SP) of?v|  ;; EX (SP), HL
       (ixy+)? ?error" invalind index register usage"
       0o040 |?
     [op@] DE of?v|  ;; EX DE, HL
       ixy ?error" invalind index register usage"
       0o050 |?
  else| error" invalid first EX operand" >> ;

: ex-builder
  ?2op op0 [op@] AF = ?<  ;; EX AF, AF'
    op1 [op@] AFX <> ?error" invalid EX instruction" 0o010
  || op0 hl? ?< op1 || op1 hl? not?error" invalid second EX operand" op0 >?
     ex-r16 opcode or
  >? opcode:! ;

extend-module instr
0o303 mk-instr EX ex-builder
end-module instr

\ RET [cond]
\ CALL [cond,] # addr
\ JP [cond,] # addr
: ret-builder
  1op? ?< ?cond op0 opval 8 * opcode or || ?nops 0o311 >? opcode:! ;

: call-builder
  \ endcr ." 0: op0=" op0 .hex4 ."  op1=" op1 .hex4 ."  a#" assume-# 0.r cr
  ?imm-addr 2op? ?< ?cond op0 opval 8 * opcode lo-word or
  || ?1op opcode hi-word >? opcode:! ;

: jp-builder
  2op? ?exit< call-builder >?
  ?1op op0 dup (hl)? swap hl? or not?exit< call-builder >?
  (ixy+)? ?< (ixy+0)? 0?bad-instr ixy lo-byte ixy:! >?
  0o351 opcode:! ;

extend-module instr
0o300 mk-instr RET  ret-builder
0o304 0o315 65536 * or mk-instr CALL call-builder  last-instr-imm-op0or1
0o302 0o303 65536 * or mk-instr JP   jp-builder    last-instr-imm-op0or1
end-module instr

\ PUSH r16 [, r16]
\ POP  r16 [, r16]
|: (p/p-fix-af)  ( r16 -- r16 )
  dup [op@] SP >= ?< [op@] AF <> ?error" invalid 16-bit register" 3 >? ;

|: (push/pop-r16)  ( r16 -- opcode )
  (p/p-fix-af) opval 16 * opcode or ;

(* this doesn't work with IX/IY paired
: push/pop-builder
  ?1/2op
  op0 dup ?reg16-any (push/pop-r16) ( opc )
  2op? ?< 256 * op1 dup ?reg16-any (push/pop-r16) or >?
  opcode:! ;
*)
: push/pop-builder
  ?1op
  op0 dup ?reg16-any (push/pop-r16) ( opc )
  opcode:! ;

extend-module instr
0o305 mk-instr PUSH push/pop-builder
0o301 mk-instr POP  push/pop-builder
end-module instr

\ INC/DEC r8/r16
|: (inc/dec-r8)  ( -- opc shift )
  \ FIXME
  \ ixy? ?error" invalid index register usage"
  opcode lo-byte 3 ;

|: (inc/dec-r16)  ( -- opc shift )
  op0 [op@] BC [op@] SP bounds 0?bad-instr
  opcode hi-byte 4 ;

: inc/dec-builder
  ?1op op0 reg8? ?< (inc/dec-r8) || (inc/dec-r16) >?
  op0 opval swap lshift or opcode:! ;

extend-module instr
$03_04 mk-instr INC inc/dec-builder
$0B_05 mk-instr DEC inc/dec-builder
end-module instr

\ ALU r8
|: (alu-r8)  ( -- opcode )
  \ FIXME!
  \ ixy? ?error" invalid index register usage"
  opcode op0 opval or ;

|: (alu-imm8)  ( -- opcode )
  ?imm-byte opcode 0o306 or ;

: alur8-builder
  2op? ?< op0 ?a op1 op0:! op1:!0 >?
  ?1op op0 reg8? ?< (alu-r8) || (alu-imm8) >?
  opcode:! ;

extend-module instr
\ 0o200 mk-instr ADD alur8-builder
\ 0o210 mk-instr ADC alur8-builder
0o220 mk-instr SUB alur8-builder    last-instr-imm-op0
\ 0o230 mk-instr SBC alur8-builder   last-instr-imm-op0
0o240 mk-instr AND alur8-builder    last-instr-imm-op0
0o250 mk-instr XOR alur8-builder    last-instr-imm-op0
0o260 mk-instr  OR alur8-builder    last-instr-imm-op0
0o270 mk-instr  CP alur8-builder    last-instr-imm-op0
end-module instr

\ ALU r16
|: (alu-hl)
  (ixy+)? ?error" invalid register combination"
  ixy ?< opcode hi-byte ?bad-instr >?
  op1 dup ?reg16-rr opval 16 * opcode lo-word or opcode:! ;

: alur16-builder
  2op? ?< op0 hl? ?exit< (alu-hl) >? >?
  ?1/2op opcode hi-word opcode:! alur8-builder ;

extend-module instr
0o200 65536 * 0o011 +         mk-instr ADD alur16-builder
0o210 65536 * 0o112 $ED00 + + mk-instr ADC alur16-builder
0o230 65536 * 0o102 $ED00 + + mk-instr SBC alur16-builder
end-module instr

\ RLx r8
: rlx-builder
  ?1op op0 dup ?reg8 opval opcode or opcode:! ;

extend-module instr
$CB00 0o000 + mk-instr RLC rlx-builder
$CB00 0o010 + mk-instr RRC rlx-builder
$CB00 0o020 + mk-instr RL  rlx-builder
$CB00 0o030 + mk-instr RR  rlx-builder
$CB00 0o040 + mk-instr SLA rlx-builder
$CB00 0o050 + mk-instr SRA rlx-builder
$CB00 0o060 + mk-instr SLL rlx-builder  -- bad name!
$CB00 0o060 + mk-instr SLS rlx-builder  -- good name
$CB00 0o060 + mk-instr SLI rlx-builder  -- yet another name ("inverted")
$CB00 0o060 + mk-instr SL1 rlx-builder  -- and yet another name
$CB00 0o060 + mk-instr SLIA rlx-builder -- more stupid names!
$CB00 0o070 + mk-instr SRL rlx-builder
end-module instr

\ BRS n,r8
: brs-builder
  ?2op bit? ?< op0 opval
  || ?imm-value dup 0 7 bounds not?error" invalid bit number" >?
  8 * opcode or opcode:! op1 op0:! op1:!0 rlx-builder ;

extend-module instr
$CB00 0o100 + mk-instr BIT brs-builder
$CB00 0o200 + mk-instr RES brs-builder
$CB00 0o300 + mk-instr SET brs-builder
end-module instr

\ IN/OUT instructions
: in/out-(c)-builder  ( op -- opcode )
  dup ?reg8-no-(hl) opval 8 * opcode or ;
: in/out-a-builder  ( op )
  a? not?error" A register expected" ?imm-port ;

: in-builder
  ?2op op1 port(c)? ?< op0 in/out-(c)-builder
  || op0 in/out-a-builder 0o333 >? opcode:! ;

: out-builder
  ?2op op0 port(c)? ?< op1 in/out-(c)-builder
  || op1 in/out-a-builder 0o323 >? opcode:! ;

extend-module instr
0o100 $ED00 + mk-instr  IN in-builder
0o101 $ED00 + mk-instr OUT out-builder
end-module instr

\ JR/DJNZ instructions
: ?rel-jump
  ?imm-addr imm-val emit:here 2+ -
  dup -128 128 within not?error" relative jump too long"
  imm-val:! $01_01 imm-sz:! ;

: djnz-builder
  ?1op ?rel-jump opcode lo-word opcode:! ;

|: jr-cond-fix
  ?cond op0 [op@] PO >= ?error" invalid condition"
  op0 opval 8 * opcode hi-word or opcode:! op1 op0:! op1:!0 ;

: jr-builder
  2op? ?< jr-cond-fix >? djnz-builder ;

extend-module instr
0o020                 mk-instr  DJNZ djnz-builder  last-instr-imm-op0
0o030 0o040 65536 * + mk-instr  JR   jr-builder    last-instr-imm-op0or1
end-module instr

\ LD -- The Most Complex Instruction
|: (r8->r8)  ( rsrc8 rdest8 -- opc )
  8 * or 0o100 or ;

|: (ld-r8,r8)
  op0 (hl)? op1 (hl)? land ?bad-instr
  op1 opval op0 opval ( 8 * or 0o100 or) (r8->r8) opcode:! ;

;; (...)
|: (ld-mem)  ?imm-mem
  op0 op-imm? ?< 0o000 op1 || 0o010 op0 >?
  << dup a? ?of?v| 0o062 |?
     dup hl? ?of?v| 0o042 |?
     dup bc/de/sp? ?of?v| [ 0o103 $ED00 or ] {#,}
                          over ?< op0 || op1 >? opval 16 * + |?
  else| bad-instr >> + opcode:! ;

|: (ld-r8/rr16,imm)
  op0 op-imm? ?bad-instr
  op0 reg16-rr? ?< ?imm-word op0 opval 16 * 0o001 or
  || ?imm-byte op0 dup ?reg8 opval 8 * 0o006 or >?
  opcode:! ;

|: (ld-a,smth)
  op1 (bc)/(de)? ?< op1 opval 16 * 0o012 or
  || op1 ir? ?< [ 0o127 $ED00 + ] {#,} op1 opval +
  || bad-instr >? >? opcode:! ;

|: (ld-smth,a)
  op0 (bc)/(de)? ?< op0 opval 16 * 0o002 or
  || op0 ir? ?< [ 0o107 $ED00 + ] {#,} op0 opval +
  || bad-instr >? >? opcode:! ;

;; synthetic instruction
|: (ld-r16,r16)
  op1 opval 2* op0 opval 2* ( rsrc8 rdest8 )
  2dup (r8->r8) ( rsrc8 rdest8 opc0 )
  256 * nrot    ( opc0 rsrc8 rdest8 )
  1+ 1 under+
  (r8->r8) + opcode:! ;

: ld-builder  ?2op
  op0 reg8? op1 reg8? land ?exit< (ld-r8,r8) >?
  imm-mem? ?exit< (ld-mem) >?
  imm-imm? ?exit< (ld-r8/rr16,imm) >?
  op0 a? ?exit< (ld-a,smth) >?
  op1 a? ?exit< (ld-smth,a) >?
  op0 sp? op1 hl? land ?exit< 0o371 opcode:! >?
  op0 reg16-norm? op1 reg16-norm? land ?exit< (ld-r16,r16) >?
  bad-instr ;

extend-module instr
0 mk-instr LD ld-builder  last-instr-imm-op0or1
end-module instr

\ final definitions
extend-module instr
: end-code  a; pop-ctx ;
end-module instr


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZXEmuT macro support

@: start-macro
  flush
  postfix? >loc
  true postfix! ;

@: end-macro
  flush
  loc> postfix! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZXEmuT macros

extend-module instr

: db,  ( byte )  >r flush! r> emit:c, ;
: dw,  ( byte )  >r flush! r> emit:w, ;

: bdup,  ( byte count ) 2>r flush! 2r> for dup emit:c, endfor drop ;
: wdup,  ( word count ) 2>r flush! 2r> for dup emit:w, endfor drop ;

: res0,  ( count )  0 swap bdup, ;

: str,  ( addr count )
  2>r flush! 2r>
  for c@++ emit:c, endfor drop ;

: str-or$80-last,  ( addr count )
  2>r flush! 2r>
  dup -0?exit< 2drop >?
  1- for c@++ emit:c, endfor
  c@ $80 forth:or emit:c, ;

: restore-iy
  $FD db, @041 db, $3A db, $5C db, ;

: db-dup-n  ( byte count )
  for dup >r db, r> endfor drop ;


: zxemut-trap-simple  ( code )
  >r $ED db, $FE db, $18 db,
  1 db, r> db, ;

: zxemut-trap-2b  ( code-hi code-lo )
  2>r $ED db, $FE db, $18 db,
  2 db, 2r> swap db, db, ;


: zxemut-bp                 2 zxemut-trap-simple ;
: zxemut-pause              $10 0 zxemut-trap-2b ;
: zxemut-max-speed          $10 1 zxemut-trap-2b ;
: zxemut-normal-speed       $10 2 zxemut-trap-2b ;
: zxemut-reset-ts-counter   0 zxemut-trap-simple ;
: zxemut-pause-ts-counter   $00 1 zxemut-trap-2b ;
: zxemut-resume-ts-counter  $00 2 zxemut-trap-2b ;
: zxemut-print-ts-counter   1 zxemut-trap-simple ;

: zxemut-get-ts-counter-de-hl   $01 1 zxemut-trap-2b ;

: zxemut-emit-char-a        $03 0 zxemut-trap-2b ;
: zxemut-emit-str-hl-bc     $03 1 zxemut-trap-2b ;
: zxemut-emit-strz-hl       $03 2 zxemut-trap-2b ;

: zxemut-emit-hex-a         $03 4 zxemut-trap-2b ;
: zxemut-emit-hex-hl        $03 5 zxemut-trap-2b ;

: zxemut-emit-udec-a-3      $03 6 zxemut-trap-2b ;
: zxemut-emit-udec-hl-5     $03 7 zxemut-trap-2b ;

: zxemut-emit-udec-a        $03 8 zxemut-trap-2b ;
: zxemut-emit-udec-hl       $03 9 zxemut-trap-2b ;

: zxemut-emit-dec-a         $03 10 zxemut-trap-2b ;
: zxemut-emit-dec-hl        $03 11 zxemut-trap-2b ;

;; always print the sign
: zxemut-emit-dec-a-sign    $03 10 zxemut-trap-2b ;
: zxemut-emit-dec-hl-sign   $03 11 zxemut-trap-2b ;

end-module instr


;; split things like "a,b" to two tokens
|: instr-do-,
  ['] z80asm:instr:, system:exec? ?< execute-tail >? \, ;

|: instr-do-#
  ['] z80asm:instr:# system:exec? ?< execute-tail >? \, ;

|: instr-do-()
  ['] z80asm:instr:() system:exec? ?< execute-tail >? \, ;

;; no comma
|: instr-ex-notfound-other  ( addr count -- processed-flag )
  ;; try "#smth"
  over c@ [char] # = ?exit<
    string:/char 2>r
    instr-do-#
    2r> interpret-word true >?
  ;; check for "(nnn)"
  dup 3 < ?exit< 2drop false >?
  over c@ [char] ( = not?exit< 2drop false >?
  2dup + 1- c@ [char] ) = not?exit< 2drop false >?
  string:/char 1- 2>r
  instr-do-()
  \ endcr ." ***Z80-ASM: () token: <" 2r@ type ." >\n"
  2r> interpret-word
  true ;

;; split on ",", execute.
;; actually, this is slightly more complex. ;-)
|: instr-ex-notfound  ( addr count -- processed-flag )
  dup 2 < ?exit< 2drop false >?
  2dup [char] , string:find-ch not?exit< instr-ex-notfound-other >?
  ( addr count comma-ofs )
  >r >r >r  ( comma-ofs count addr )
  ;; try to find token with comma first
  r@ r2:@ 1+ vocid: instr vocid-find ?<
    system:exec? ?< execute || \, >?
  ||
    r2:@ ?< r@ r2:@
      \ endcr ." ***Z80-ASM: first token: <" 2dup type ." >\n"
      interpret-word >?
    instr-do-, >?
  r> r> r> 1+ string:/chars
  ( addr count )
  dup not?exit< 2drop true >?
  \ endcr ." ***Z80-ASM: second token: <" 2dup type ." >\n"
  interpret-word
  true ;

['] instr-ex-notfound vocid: instr system:vocid-notfound-cfa!


seal-module
end-module z80asm

: z80-code  z80asm:asm-reset push-ctx voc-ctx: z80asm:instr ;
