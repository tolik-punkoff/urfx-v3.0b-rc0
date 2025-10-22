;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; detect stitched comparison primitives
;; used in branch optimisation
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module CDETECT
<disable-hash>

enum{
  def: c-none -- must be the first
  def: c-=
  def: c-<>
  def: c-<
  def: c-<=
  def: c->
  def: c->=
  def: c-u<
  def: c-u<=
  def: c-u>
  def: c-u>=

  def: c-~and
  def: c-and
  def: c-or
  def: c-xor

  def: c-not-mask?
  def: c-mask?
  def: c-not-~mask?
  def: c-~mask?

  def: c-0=
  def: c-0<>
  def: c-0<
  def: c-0>
  def: c-0<=
  def: c-0>=
}

(*
detection is table-based, starting from the last instruction (i.e.
instruction order is reversed).

format:
  dd c-type (0: no more)
    dd opcode (0: no more)
opcode format:

highest byte is length; opcode bytes compared backwards (so the order is
natural).

WARNING! this code is simply the corresponding primitives written
         backwards.

make sure that longest sequences comes first (just in case).
*)

(*

problem: i want to use x86asm to generate tables. because doing that
manually is not only boring, but very error-prone. it is easy to do in
Uroborus, but target system has no asm. so we have to ask Uroborus to
invoke x86asm for us.

pro:
  * making and modifying tables is easy.

contra:
  * there is no way to compile Succubus in standalone compiled system.

tbh, i don't care about (re)loading Succubus: this is something that cannot
be easily done due to many reasons. so asking Uroborus to help us sounds
like a sensible solution.

we need tables in several formats.

1. backward scan table: instruction order is reversed, byte order is reversed.
2. patch table: instruction order is direct, byte order is direct.

we can avoid byte ordering problems if we will work with bytes instead of
cells. this shouldn't be a problem on x86: it caches everything anyway.

still, working with dword data items is easier and slightly faster, so i
want to keep them. the disadvantage of that method is that we cannot have
instructions longer than 3 bytes here. which is hardly a problem, because
the only case when the instruction is longer is when it contains immediate
operands. our matcher cannot cope with such instructions yet anyway. and
when i'll do the new matcher, it will use different table format.

(still, i decided to work with bytes. meh.)

Uroborus support interface:

;; setup
<normal>|<reversed> <i-order>
<normal>|<reversed> <b-order>

<i-table>
....
<i-done>
*)

<reversed> <i-order>
<reversed> <b-order>
create opc-table
c-= ,  <i-table>
  xor   utos, eax
  sub   utos, # 1
  sbb   utos, utos
<i-done>
c-<> ,  <i-table>
  xor   utos, eax
  neg   utos
  sbb   utos, utos
<i-done>
c-< ,  <i-table>
  cmp   eax, utos
  setl  bl
  movzx utos, bl
  neg   utos
<i-done>
c-<= ,  <i-table>
  cmp   eax, utos
  setle bl
  movzx utos, bl
  neg   utos
<i-done>
c-> ,  <i-table>
  cmp   eax, utos
  setg  bl
  movzx utos, bl
  neg   utos
<i-done>
c->= ,  <i-table>
  cmp   eax, utos
  setge bl
  movzx utos, bl
  neg   utos
<i-done>
c-u< ,  <i-table>
  cmp   eax, utos
  sbb   utos, utos
<i-done>
c-u> ,  <i-table>
  cmp   utos, eax
  sbb   utos, utos
<i-done>
c-u<= ,  <i-table>
  cmp   utos, eax
  sbb   utos, utos
  not   utos
<i-done>
c-u>= ,  <i-table>
  cmp   eax, utos
  sbb   utos, utos
  not   utos
<i-done>

;; sometimes i tend to write "- ?< ... >?".
;; this is microoptimisation for "<> ?< ... >?"
c-<> ,  <i-table>
  neg   utos
  add   utos, eax
<i-done>

c-0= ,  <i-table> ;; and "NOT"
  sub   utos, # 1
  sbb   utos, utos
<i-done>
c-0<> ,  <i-table>
  neg   utos
  sbb   utos, utos
<i-done>
c-0< ,  <i-table>
  sar   utos, # 31
<i-done>
c-0> ,  <i-table>
  cmp   utos, # 0
  setg  bl
  movzx utos, bl
  neg   utos
<i-done>
c-0<= ,  <i-table>
  cmp   utos, # 0
  setle bl
  movzx utos, bl
  neg   utos
<i-done>
c-0>= ,  <i-table>
  sar   utos, # 31
  not   utos
<i-done>

c-not-mask? ,  <i-table> ;; for branches it can be replaced with a simple "AND" and inverted condition
  and   utos, eax
  neg   utos
  sbb   utos, utos
  not   utos
<i-done>
c-mask? ,  <i-table> ;; for branches it can be replaced with a simple "AND"
  and   utos, eax
  neg   utos
  sbb   utos, utos
<i-done>
c-not-~mask? ,  <i-table>
  not   utos
  and   utos, eax
  neg   utos
  sbb   utos, utos
  not   utos
<i-done>
c-~mask? ,  <i-table>
  not   utos
  and   utos, eax
  neg   utos
  sbb   utos, utos
<i-done>

c-~and ,  <i-table> ;; "~and brn" -- we can remove unnecessary "test" here
  not   utos
  and   utos, eax
<i-done>
c-and ,  <i-table> ;; "and brn" -- we can remove unnecessary "test" here
  and   utos, eax
<i-done>
c-or ,  <i-table> ;; "or brn" -- we can remove unnecessary "test" here
  or    utos, eax
<i-done>
c-xor ,  <i-table> ;; "xor brn" -- we can remove unnecessary "test" here
  xor   utos, eax
<i-done>

;; done
0 ,
create;


;; state quans
0 quan instr^
;; this is also number of instructions to remove (valid only when the match is found).
;; new "code-here" is "instr^" in this case.
0 quan #instr


: can-remove-n-bytes?  ( len -- success-flag )
  instr^ swap - bblock-start^ u>= ;

;; decrements "instr^".
;; on failure, "instr^" is undefined.
: check-n-bytes  ( opcode len -- success-flag )
  swap << ( len opcode )
    instr^:1-!
    dup lo-byte instr^ code-c@ = not?v| 2drop false |?
    256 u/ 1 under-
  over ?^|| else| 2drop true >> ;

;; check if the compiled opcode is equal and can be removed.
;; use cdetect state quans. they should be at the end of the next opcode on enter.
;; advances state quans to the start of the opcode on success.
;; state quans are undefined on failure.
: check-opcode  ( opcode -- success-flag )
  dup 24 rshift   ( opcode len )
  dup can-remove-n-bytes? not?exit< 2drop false >?
  dup #instr ilendb:nth-last-len@ = not?exit< 2drop false >?
  check-n-bytes dup #instr:-! ;

: reset-state  code-here instr^:!  #instr:!0 ;

;; on exit
: check-record  ( rec^ -- success-flag )
  reset-state
  << @++ dup $01_00_00_00 u< ?v| 2drop true |?
     check-opcode ?^|| else| drop false >> ;

: skip-record  ( rec^ -- next-rec^ )  << 4+ dup @ $01_00_00_00 u>= ?^|| else| >> ;

: detect-cond  ( -- ctype )
  opc-table <<
    @++ dup not?v| 2drop c-none reset-state |?
    ( rec^ type )
    over check-record ?v| nip |?
  ^| drop skip-record | >> ;

end-module CDETECT
