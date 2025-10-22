;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FPU words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(*
FPU Condition Code Bits after a test, compare or reduction
€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€

Vatious FPU test instructions set the Condition Code bits C0 to C3 based
on the values tested. Below is a list of possible bit combinations.

These C-bits map to the flags register as follows after stswax and sahf:

Eflags map: ZF  PF  -   CF  (C1 has no flag assigned to it)
            C3  C2  C1  C0

Examine     0   0   0   0   +Unnormal (positive, valid, unnormalized)
            0   0   0   1   +NaN      (positive, invalid, exponent is 0)
            0   0   1   0   -Unnormal (negative, valid, unnormalized)
            0   0   1   1   -NaN      (negative, invalid, exponent is 0)
            0   1   0   0   +Normal   (positive, valid, normalized)
            0   1   0   1   +Infinity (positive, infinity)
            0   1   1   0   -Normal   (negative, valid, normalized)
            0   1   1   1   -Infinity (negative, infinity)
            1   0   0   0   +Zero     (positive, zero)
            1   0   0   1   Empty     (empty register)
            1   0   1   0   -Zero     (negative, zero)
            1   0   1   1   Empty     (empty register)
            1   1   0   0   +Denormal (positive, invalid, exponent is 0)
            1   1   0   1   Empty     (empty register)
            1   1   1   0   -Denormal (negative, invalid, exponent is 0)
            1   1   1   1   Empty     (empty register)

FCOM or
STST        0   0   ?   0   ST > Source with FCOM or ST > 0 with FSTST
            0   0   ?   1   ST < Source with FCOM or ST < 0 with FSTST
            1   0   ?   0   ST = Source with FCOM or ST = 0 with FSTST
            1   1   ?   1   ST cannot be compared ot tested

Reduction   b1  0   b0  b2  If reduction was complete, bits 0,1 and 2
                            equal the three lowest bits of the qoutient
            ?   1   ?   ?   Reduction was incomplete


FPU Status Word, Control Word and Tag Word layout
€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€

The layout of the Status-, Control- and Tag Word of the FPU.

      FPU Status Word

      Bit 15                8                        0
      ‚€€ˆ€€ˆ€€ˆ€€Š€€ˆ€€ˆ€€ˆ€€Š€€ˆ€€ˆ€€ˆ€€Š€€ˆ€€ˆ€€ˆ€‰ƒ
       Bc3  ST n  c2c1c0ESsfPeUeOeZeDeIe
      „€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š…
            „€€Š€€…  „€€Š€€…                
      Busy ©     ¼        ²                   
      Stack Top€€…                           
      Condition Code Bits€…                   
      Exception Summary * €€€€€€…              
      Stack fault€€€€€€€€€€€€€€€€€€…            
      Precision exception (1=occurred)…          
      Underflow exception (1=occurred)€€€…        
      Overflow exception (1=occurred)€€€€€€€…      
      Zero divison exception (1=occurred)€€€€€€…    
      Denormalized operand exception (1=occurred)€…  
      Invalid operation exception (1=occurred)€€€€€€€…

      * The Exception summary is called Interrupt request on 8087.

      FPU Control Word

      Bit 15                8                        0
      ‚€€ˆ€€ˆ€€ˆ€€Š€€ˆ€€ˆ€€ˆ€€Š€€ˆ€€ˆ€€ˆ€€Š€€ˆ€€ˆ€€ˆ€‰ƒ
       r r ricroundprec.ie rPmUmOmZmDmIm
      „€€‰€€‰€€‰€Š‰€€‰€Š‰€Š‰€€‰€Š‰€€‰€Š‰€Š‰€Š‰€Š‰€Š‰€Š…
      Infinity                              
      control€€€€…                           
      Rounding control€…                      
      Precision control€€€…                    
      Interrupt enable mask€€€€€…               
                                      „ƒ         
      Precision exception Mask 1=masked…         
      Underflow exception Mask 1=masked€€…        
      Overflow exception Mask 1=masked€€€€€€…      
      Zero divison exception Mask 1=masked€€€€€…    
      Denormalized operand exception Mask 1=masked…  
      Invalid operation exception Mask 1=masked€€€€€€…

    Infinity control is supported on the 8087 and 287 only.
    The 87 and 287 (not the 287xl) have ic cleared by default and then
    support projective closure. The 287xl+ only support affine closure.
    To make sure an 87 or 287 will handle the numbers in the same way
    as the 287xl+, set bit ic to make 87 & 287 support affine closure
    as well. Note that a FINIT will clear ic again.
    The ic setting is ignored on 287xl+.

    Rounding control is set to 00 by default.
    00 = Round to nearest or even
    01 = Round down (towards negative infinity)
    10 = Round up (towards positive infinity)
    11 = Chop towards zero

    Precision control is set to 11 by default.
    00 = 24 bit precision (mantissa)
    01 = reserved
    10 = 53 bit precision (mantissa)
    11 = 64 bit precision (mantissa)

    Note: lesser precision does not significantly reduce execution time.


      FPU Tag Word

      Bit 15                8                        0
      ‚€€ˆ€€ˆ€€ˆ€€Š€€ˆ€€ˆ€€ˆ€€Š€€ˆ€€ˆ€€ˆ€€Š€€ˆ€€ˆ€€ˆ€‰ƒ
       x  x x  x x  x x  x x  x x  x x  x x  x
      „€€‰€Š‰€€‰€Š‰€€‰€Š‰€€‰€Š‰€€‰€Š‰€€‰€Š‰€€‰€Š‰€€‰€Š…
           7     6     5     4     3     2     1     0 Tag number

      The tag number 0 corresponds to the register which is
      currently ST0.
      The bits for each tag have the same meaning:

       0  0  Valid
       0  1  Zero
       1  0  Special (NaN,Infinity,Denormal,Unnormal,Unsupported)
       1  1  Empty
*)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FPU control
;;

;; reinit FPU
;; control word set to $37f (round to nearest, all exceptions masked, 64-bit precision)
;; all registers marked as empty
code-naked-inline: FINIT
  fninit
;code-no-stacks (no-stacks)

code-naked-inline: FWAIT
  fwait
;code-no-stacks (no-stacks)

code-naked-inline: FNOP
  fnop
;code-no-stacks (no-stacks)

code-swap-inline: FPU-GETSW  ( -- sw )
  push  UTOS
  xor   eax, eax
  fstsw ax
  fwait ;; it *MIGHT* be needed here
  movzx UTOS, ax
;code-swap-next

code-swap-inline: FPU-SETCW  ( u )
  push  UTOS
  fldcw word^ [esp]
  \ fwait ;; it *MIGHT* be needed here
  pop   UTOS
  pop   UTOS
;code-swap-next

code-swap-inline: FPU-GETCW  ( -- u )
  push  UTOS
  push  UTOS
  fstcw word^ [esp]
  \ fwait ;; it *MIGHT* be needed here
  pop   UTOS
  movzx UTOS, bx
;code-swap-next

code-naked-inline: FPU-TRUNC-MODE
  fstcw word^ [esp+] # -4
  bts   word^ [esp+] # -4 , # 10
  bts   word^ [esp+] # -4 , # 11
  fldcw word^ [esp+] # -4
;code-no-stacks

code-naked-inline: FPU-ROUND-MODE
  fstcw word^ [esp+] # -4
  btr   word^ [esp+] # -4 , # 10
  btr   word^ [esp+] # -4 , # 11
  fldcw word^ [esp+] # -4
;code-no-stacks

code-naked-inline: FPU-UP-MODE
  fstcw word^ [esp+] # -4
  btr   word^ [esp+] # -4 , # 10
  bts   word^ [esp+] # -4 , # 11
  fldcw word^ [esp+] # -4
;code-no-stacks

code-naked-inline: FPU-LOW-MODE
  fstcw word^ [esp+] # -4
  bts   word^ [esp+] # -4 , # 10
  btr   word^ [esp+] # -4 , # 11
  fldcw word^ [esp+] # -4
;code-no-stacks

;; low 6 bits masks #I #D #Z #O #U #P
;; unmask everything except #P (due to zero cond)
: FPU-ERROR-MODE
  FPU-GETCW
  127 ~and
  32 or
  FPU-SETCW ;

;; only #I and stack
: FPU-NORMAL-MODE
  FPU-GETCW
  127 or
  1 ~and
  FPU-SETCW ;

: FPU-SILENT-MODE
  FPU-GETCW
  127 or
  FPU-SETCW ;

|: (FPU-STATE?)  ( mask -- flag ) FPU-GETSW mask? ;
|: (FPU-MASK?)   ( mask -- flag ) FPU-GETCW mask? ;

: FPU-IE?  ( -- flag )  $01 (fpu-state?) ;  \ invalid operafion flag
: FPU-DE?  ( -- flag )  $02 (fpu-state?) ;  \ denormalised operand flag
: FPU-ZE?  ( -- flag )  $04 (fpu-state?) ;  \ zero division flag
: FPU-OE?  ( -- flag )  $08 (fpu-state?) ;  \ overflow exception flag
: FPU-UE?  ( -- flag )  $10 (fpu-state?) ;  \ underflow exception flag
: FPU-PE?  ( -- flag )  $20 (fpu-state?) ;  \ precision exception flag
: FPU-SF?  ( -- flag )  $40 (fpu-state?) ;  \ stack fauld
;; condition code bits (c0-c2), properly shifted; c0 is in bit 0
: FPU-CC?  ( -- cc )  FPU-GETSW hi-byte 7 and ;
;; get c3 flag
: FPU-C3?  ( -- c3? )  $4000 (fpu-state?) ;

;; exception masks (set means "disabled")
: FPU-IM?  ( -- flag )  $01 (fpu-mask?) ;  \ invalid opearion
: FPU-DM?  ( -- flag )  $02 (fpu-mask?) ;  \ denormalized operand
: FPU-ZM?  ( -- flag )  $04 (fpu-mask?) ;  \ zero divide
: FPU-OM?  ( -- flag )  $08 (fpu-mask?) ;  \ overflow
: FPU-UM?  ( -- flag )  $10 (fpu-mask?) ;  \ underflow
: FPU-PM?  ( -- flag )  $20 (fpu-mask?) ;  \ precision

: FPU-PREC?  ( -- n ) FPU-GETCW 8 rshift 3 and ;
: FPU-ROUND? ( -- n ) FPU-GETCW 10 rshift 3 and ;

: FPU-PREC!  ( n )  3 and 8 lshift FPU-GETCW $fcff and or FPU-SETCW ;
: FPU-ROUND! ( n )  3 and 10 lshift FPU-GETCW $f3ff and or FPU-SETCW ;

\ bits 8-9: precision control:
\   00: 24 bits (single precision, float)
\   01: who knows (reserved)
\   10: 53 bits (double precision)
\   11: 64 bits (extended precision)

\ bits 10-11: rounding control:
\   00: nearest or even
\   01: down (toward -inf)
\   10: up (toward +inf)
\   11: trunc towards zero

\ bit 12: infinity control (does nothing on 80387 and above)

;; called on system startup and in error handler
: FPU-RESET
  finit ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FPU stack operations

code-naked-inline: FDROP
  ;;ffree st0
  ;;fincstp
  fstp st0
;code-no-stacks (no-stacks)

code-naked-inline: FDUP
  fld st0
;code-no-stacks (no-stacks)

code-naked-inline: FOVER
  fld st1
;code-no-stacks (no-stacks)

code-naked-inline: FSWAP
  fxch  st1
;code-no-stacks (no-stacks)

code-naked-inline: FROT  ( f:a b c -- f:b c a )
  fxch  st2
  fxch  st1
  fxch  st2
  fxch  st1
;code-no-stacks (no-stacks)

code-naked-inline: FNROT  ( f:a b c -- f:c a b )
  fxch  st2
  fxch  st1
;code-no-stacks (no-stacks)

: FNIP   ( f:a b -- f:b )  fswap fdrop ;
: FTUCK  ( f:a b -- f:b a b )  fswap fover ;
: FUNDER ( f:a b -- f:a a b )  fover fswap ;

code-naked-inline: FSWAP-ST2  ( f:a b c -- f:c b a )
  fxch  st2
;code-no-stacks (no-stacks)

code-naked-inline: FSWAP-ST3
  fxch  st3
;code-no-stacks (no-stacks)

code-naked-inline: FSWAP-ST4
  fxch  st4
;code-no-stacks (no-stacks)

code-naked-inline: FSWAP-ST5
  fxch  st5
;code-no-stacks (no-stacks)

code-naked-inline: FSWAP-ST6
  fxch  st6
;code-no-stacks (no-stacks)

code-naked-inline: FSWAP-ST7
  fxch  st7
;code-no-stacks (no-stacks)


;; you are not supposed to understand this ;-)
code-swap-inline: FDEPTH  ( -- n )
  push  UTOS
  xor   eax, eax
  fstsw ax
  fwait ;; it *MIGHT* be needed here
  shr   eax, # 11
  and   eax, # 7
  jz    @@f
  neg   eax
  lea   eax, [eax+] # 8
@@:
  mov   UTOS, eax
;code-swap-next


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FPU <-> data stack

code-swap-inline: (F>D)  ( -- dl dh )
  push  UTOS
  push  UTOS
  push  UTOS
  fistp qword^ [esp]
  pop   UTOS
  xchg  UTOS, [esp]
;code-swap-next

: F>D  ( -- dl dh )
  FPU-GETCW >R
  FPU-TRUNC-MODE
  (F>D)
  R> FPU-SETCW ;

code-swap-inline: D>F  ( dl dh )
  xchg  UTOS, [esp]
  push  UTOS
  fild  qword^ [esp]
  pop   UTOS
  pop   UTOS
  pop   UTOS
;code-swap-next

\ push UTOS to the float stack
code-swap-inline: S>F  ( n )
  push  UTOS
  fild  dword^ [esp]
  pop   UTOS
  pop   UTOS
;code-swap-next

\ pop the top float stack number to the data stack
\ round or truncate according to the current mode
code-swap-inline: F>S  ( -- n )
  push  UTOS
  push  UTOS
  fistp dword^ [esp]
  pop   UTOS
;code-swap-next

code-swap-inline: F@S  ( -- n )
  push  UTOS
  push  UTOS
  fist  dword^ [esp]
  pop   UTOS
;code-swap-next


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; binary float representation <-> data stack

code-swap-inline: F32>F  ( n )
  push  UTOS
  fld   dword^ [esp]
  add   esp, # 4
  pop   UTOS
;code-swap-next

code-swap-inline: F>F32  ( -- n )
  push  UTOS
  push  UTOS
  fstp  dword^ [esp]
  pop   UTOS
;code-swap-next

code-swap-inline: F@F32  ( -- n )
  push  UTOS
  push  UTOS
  fst   dword^ [esp]
  pop   UTOS
;code-swap-next


code-swap-inline: F64>F  ( n0 n1 )
  push  UTOS
  fld   qword^ [esp]
  add   esp, # 8
  pop   UTOS
;code-swap-next

code-swap-inline: F>F64  ( -- n0 n1 )
  push  UTOS
  push  UTOS
  push  UTOS
  fstp  qword^ [esp]
  pop   UTOS
;code-swap-next

code-swap-inline: F@F64  ( -- n0 n1 )
  push  UTOS
  push  UTOS
  push  UTOS
  fst   qword^ [esp]
  pop   UTOS
;code-swap-next


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; binary float representation <-> return stack

code-swap-inline: F32R>F  ( | n -- )
  fld   dword^ [URP]
  add   URP, # 4
;code-swap-next (force-inline)

code-swap-inline: F>RF32  ( -- | n )
  sub   URP, # 4
  fstp  dword^ [URP]
;code-swap-next (force-inline)

code-swap-inline: F@RF32  ( -- | n )
  sub   URP, # 4
  fst   dword^ [URP]
;code-swap-next (force-inline)

code-swap-inline: F64R>F  ( | n0 n1 -- )
  fld   qword^ [URP]
  add   URP, # 8
;code-swap-next (force-inline)

code-swap-inline: F>RF64  ( -- | n0 n1 )
  sub   URP, # 8
  fstp  qword^ [URP]
;code-swap-next (force-inline)

code-swap-inline: F@RF64  ( -- n0 n1 )
  sub   URP, # 8
  fst   qword^ [URP]
;code-swap-next (force-inline)


code-swap-inline: F>R  ( -- | n0 n1 )
  sub   URP, # 8
  fstp  qword^ [URP]
;code-swap-next (force-inline)

code-swap-inline: R>F  ( | n0 n1 -- )
  fld   qword^ [URP]
  add   URP, # 8
;code-swap-next (force-inline)

code-swap-inline: F@R  ( -- | n0 n1 )
  sub   URP, # 8
  fst   qword^ [URP]
;code-swap-next (force-inline)

code-swap-inline: FRDROP  ( | n0 n1 -- )
  sub   URP, # 8
;code-swap-next (force-inline)

\ alias F>RF64 F>R
\ alias F64R>F R>F
\ alias F@RF64 F@R
\ alias 2rdrop FRDROP


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple mul/div with a constant

code-naked-inline: F10*
  mov   dword^ [esp+] # -4 , # 10
  fimul dword^ [esp+] # -4
;code-no-stacks

code-naked-inline: F10/
  mov   dword^ [esp+] # -4 , # 10
  fidiv dword^ [esp+] # -4
;code-no-stacks

code-naked-inline: F2*
  mov   dword^ [esp+] # -4 , # 2
  fimul dword^ [esp+] # -4
;code-no-stacks

code-naked-inline: F2/
  mov   dword^ [esp+] # -4 , # 2
  fidiv dword^ [esp+] # -4
;code-no-stacks

code-naked-inline: F1+
  mov   dword^ [esp+] # -4 , # 1
  fiadd dword^ [esp+] # -4
;code-no-stacks

code-naked-inline: F1-
  mov   dword^ [esp+] # -4 , # 1
  fisub dword^ [esp+] # -4
;code-no-stacks

code-naked-inline: F**2
  fmul st0, st0
;code-no-stacks


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; various constants

code-naked-inline: 0.E
  fldz
;code-no-stacks (no-stacks)

code-naked-inline: 1.E
  fld1
;code-no-stacks (no-stacks)

code-naked-inline: 2.E
  mov   dword^ [esp+] # -4 , # 2
  fild  dword^ [esp+] # -4
;code-no-stacks (no-stacks)

code-naked-inline: 10.E
  mov  dword^ [esp+] # -4 , # 10
  fild dword^ [esp+] # -4
;code-no-stacks (no-stacks)

code-naked-inline: FPI
  fldpi
;code-no-stacks (no-stacks)

code-naked-inline: FLG2
  fldlg2
;code-no-stacks (no-stacks)

code-naked-inline: FLN2
  fldln2
;code-no-stacks (no-stacks)

code-naked-inline: FL2T
  fldl2t
;code-no-stacks (no-stacks)

code-naked-inline: FL2E
  fldl2e
;code-no-stacks (no-stacks)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FPU stack <-> memory

;; store 8-byte float at the given address
code-swap-inline: DF!  ( addr )
  fstp  qword^ [UTOS]
  pop   UTOS
;code-swap-next

;; load 8-byte float from the given address
code-swap-inline: DF@  ( addr )
  fld   qword^ [UTOS]
  pop   UTOS
;code-swap-next

;; store 4-byte float at the given address
code-swap-inline: SF!  ( addr )
  fstp  dword^ [UTOS]
  pop   UTOS
;code-swap-next

;; load 4-byte float from the given address
code-swap-inline: SF@  ( addr )
  fld   dword^ [UTOS]
  pop   UTOS
;code-swap-next

code-swap-inline: F80MEM>F  ( addr )
  fld   tbyte^ [UTOS]
  pop   UTOS
;code-swap-next

code-swap-inline: F>F80MEM  ( addr )
  fstp  tbyte^ [UTOS]
  pop   UTOS
;code-swap-next


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FPU constants and variables

;; 10-byte transfers are deliberately omited

: FLOATS  ( n -- n*8 )  8 * ;
: FLOAT+  ( addr -- addr+8 )  8 + ;

: DFLOATS  ( n -- n*8 )  8 * ;
: DFLOAT+  ( addr -- addr+8 )  8 + ;

: SFLOATS  ( n -- n*4 )  4 * ;
: SFLOAT+  ( addr -- addr+4 )  4+ ;

: F!  ( addr )  DF! ;
: F@  ( addr )  DF@ ;
\ alias DF! F!
\ alias DF@ F@

: F,  ( -- )  ( f:value -- )  1 floats n-allot f! ;

: FCONST  \ name
  <builds f, create; does> f@ ;

: FVAR  \ name
  0.e <builds f, does> ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; comparisons

code-swap-inline: F0=  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  ftst
  ffree st0
  fincstp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  setz  bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: F0<  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  ftst
  ffree st0
  fincstp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  setb  bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: F0>  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  ftst
  ffree st0
  fincstp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  seta  bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: F0<=  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  ftst
  ffree st0
  fincstp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  setbe bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: F0>=  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  ftst
  ffree st0
  fincstp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  setae bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next


code-swap-inline: F=  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  fcompp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  sete  bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: F<  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  fcompp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  seta  bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: F>  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  fcompp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  setb  bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: F<=  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  fcompp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  setae bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: F>=  ( -- flag )
  push  UTOS
  xor   UTOS, UTOS
  xor   eax, eax
  fcompp
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  setbe bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utils
;;
code-naked-inline: FMAX
  fcom  st1
  xor   eax, eax
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  jb    @@f
  fxch  st1
@@:
  ffree st0
  fincstp
;code-no-stacks (no-stacks)

code-naked-inline: FMIN
  fcom  st1
  xor   eax, eax
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  ja    @@f
  fxch  st1
@@:
  ffree st0
  fincstp
;code-no-stacks (no-stacks)

code-naked-inline: FNEGATE
  fchs
;code-no-stacks (no-stacks)

code-naked-inline: FABS
  fabs
;code-no-stacks (no-stacks)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple operations
;;
code-naked-inline: FCOS
  fcos
;code-no-stacks (no-stacks)

code-naked-inline: FSIN
  fsin
;code-no-stacks (no-stacks)

code-naked-inline: FSINCOS  ( f:rad -- f:cos f:sin )
  fsincos
;code-no-stacks (no-stacks)

code-naked-inline: F*
  fmulp st1, st0
;code-no-stacks (no-stacks)

code-naked-inline: F+
  faddp st1, st0
;code-no-stacks (no-stacks)

code-naked-inline: F-
  fsubp st1, st0
;code-no-stacks (no-stacks)

code-naked-inline: F/
  fdivp st1, st0
;code-no-stacks (no-stacks)

code-naked-inline: FSQRT
  fsqrt
;code-no-stacks (no-stacks)

code-naked-inline: FINT
  frndint
;code-no-stacks (no-stacks)

(*
code-naked-inline: FPREM
  xor   eax, eax
@@1:
  fprem
  fstsw ax
  fwait ;; it *MIGHT* be needed here
  movzx eax, ax
  test  eax, # $0400
  jnz   @@1
;code-no-stacks (no-stacks)

code-naked-inline: FPREM1
  xor   eax, eax
@@1:
  fprem1
  fstsw ax
  fwait ;; it *MIGHT* be needed here
  movzx eax, ax
  test  eax, # $0400
  jnz   @@1
;code-no-stacks (no-stacks)
*)


code-naked-inline: FLN
  fldln2
  fxch  st1
  fyl2x
;code-no-stacks (no-stacks)

code-naked-inline: FLNP1
  fld1
  faddp st1, st0
  fldln2
  fxch  st1
  fyl2x
;code-no-stacks (no-stacks)

code-naked-inline: FLOG  ( -- )  ( f:n0 -- f:n1 )
  fldlg2
  fxch  st1
  fyl2x
;code-no-stacks (no-stacks)


;; e^(x) = 2^(x * LOG{2}e)
code-naked-inline: FEXP
  ;; normalize
  fldl2e
  fmulp st1, st0
  ;; set rounding mode to truncate
  fstcw word^ [esp+] # -4
  mov   eax, [esp+] # -4
  and   ah, # $F3
  or    ah, # $0C
  mov   [esp+] -8 #, eax
  fldcw word^ [esp+] # -8
  ;; get integer and fractional parts
  fld   st0
  frndint
  fxch  st1
  fsub  st0, st1
  ;; exponentiate fraction
  f2xm1
  fld1
  faddp st1, st0
  ;; scale in integral part
  fscale
  ;; clean up
  fxch  st1
  fcomp st1
  ;; restore mode
  fldcw word^ [esp+] # -4
;code-no-stacks (no-stacks)

: FEXPM1  FEXP F1- ;

;; power should be positive
code-naked-inline: F**
  fxch  st1
  fyl2x
  fld1
  fld   st1
  fprem
  f2xm1
  faddp st1, st0  ;; this was "fadd"
  fscale
  fxch  st1
  fstp  st0
;code-no-stacks (no-stacks)

code-naked-inline: FTAN
  fptan
  fdivp st1, st0
;code-no-stacks (no-stacks)

code-naked-inline: FATAN
  fld1
  fpatan
;code-no-stacks (no-stacks)

code-naked-inline: FATAN2
  fpatan
;code-no-stacks (no-stacks)

code-naked-inline: FACOS
  fld1
  fld   st1
  fmul  st0, st0
  fsubp st1, st0
  fsqrt
  fxch  st1
  fpatan
;code-no-stacks (no-stacks)

code-naked-inline: FASIN
  fld1
  fld   st1
  fmul  st0, st0
  fsubp st1, st0
  fsqrt
  fpatan
;code-no-stacks (no-stacks)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some non-standard words

code-naked-inline: FRAD>DEG
  mov   dword^ [esp+] -4 #, # 180
  fimul dword^ [esp+] # -4
  fldpi
  fdivp st1, st0
;code-no-stacks

code-naked-inline: FDEG>RAD
  fldpi
  fmulp st1, st0
  mov   dword^ [esp+] -4 #, # 180
  fidiv dword^ [esp+] # -4
;code-no-stacks

code-naked-inline: FLOG2  ( F: r1 -- r2 )
  fld1
  fxch  st1
  fyl2x
;code-no-stacks (no-stacks)

;; i don't remember why it's here
code-naked-inline: F[LOG]  ;; using 2 stack slots
  fldlg2
  fxch  st1
  fyl2x
  frndint
;code-no-stacks (no-stacks)


;; compare with doubles; i don't think that i need it
(*
code-swap-inline: FD=  ( dl dh -- flag )
  xchg  UTOS, [esp]
  push  UTOS
  xor   eax, eax
  ficom dword^ [esp]
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  pop   UTOS
  pop   UTOS
  sete  bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: FD<  ( dl dh -- flag )
  xchg  UTOS, [esp]
  push  UTOS
  xor   eax, eax
  ficom dword^ [esp]
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  pop   UTOS
  pop   UTOS
  setb  bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: FD>  ( dl dh -- flag )
  xchg  UTOS, [esp]
  push  UTOS
  xor   eax, eax
  ficom dword^ [esp]
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  pop   UTOS
  pop   UTOS
  seta  bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: FD<=  ( dl dh -- flag )
  xchg  UTOS, [esp]
  push  UTOS
  xor   eax, eax
  ficom dword^ [esp]
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  pop   UTOS
  pop   UTOS
  setbe bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: FD>=  ( dl dh -- flag )
  xchg  UTOS, [esp]
  push  UTOS
  xor   eax, eax
  ficom dword^ [esp]
  fstsw ax
  fwait   ;; it *MIGHT* be needed here
  sahf
  pop   UTOS
  pop   UTOS
  setae bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next
*)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; floor/round/trunc

|: (FPU-XFRT-DO)  ( mode-cfa )
  fpu-getcw >r execute fint r> fpu-setcw ;

: FFLOOR  ( F:r1 -- F:r2 )  ['] FPU-LOW-MODE (fpu-xfrt-do) ;
: FROUND  ( F:r1 -- F:r2 )  ['] FPU-ROUND-MODE (fpu-xfrt-do) ;
: FTRUNC  ( F:r1 -- F:r2 )  ['] FPU-TRUNC-MODE (fpu-xfrt-do) ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FPU state management

28 constant FPU-ENV-SIZE

code-swap-inline: FENV!  ( addr )
  fnstenv byte^ [UTOS]
  pop   UTOS
;code-swap-next

code-swap-inline: FENV@  ( addr )
  fldenv byte^ [UTOS]
  pop   UTOS
;code-swap-next

;; overestimate a little
108 constant FPU-SAVE-SIZE

code-swap-inline: FSAVE  ( addr )
  fnsave byte^ [UTOS]
  pop   UTOS
;code-swap-next

code-swap-inline: FRESTORE  ( addr )
  frstor byte^ [UTOS]
  pop   UTOS
;code-swap-next


\ create (F+INF) $7f80_0000 , create;
code-naked-inline: F+INF
  \ mov   eax, # tgt-['pfa] (F+INF)
  \ fld   dword^ [eax]
  push  # $7f80_0000
  fld   dword^ [esp]
  pop   eax
;code-no-stacks

\ create (F-INF) $ff80_0000 , create;
code-naked-inline: F-INF
  \ mov   eax, # tgt-['pfa] (F-INF)
  \ fld   dword^ [eax]
  push  # $ff80_0000
  fld   dword^ [esp]
  pop   eax
;code-no-stacks

;; quiet
\ create (F-QNAN) $7fc0_0000 , create;
code-naked-inline: FNAN
  \ mov   eax, # tgt-['pfa] (F-QNAN)
  \ fld   dword^ [eax]
  push  # $7fc0_0000
  fld   dword^ [esp]
  pop   eax
;code-no-stacks

;; signaling
\ create (F-SNAN) $7f80_0001 , create;
code-naked-inline: FSNAN
  \ mov   eax, # tgt-['pfa] (F-SNAN)
  \ fld   dword^ [eax]
  push  # $7f80_0001
  fld   dword^ [esp]
  pop   eax
;code-no-stacks

code-swap-inline: FSIGN  ( -- sign )  ( f:n -- f:n )
  push  UTOS
  fst   dword^ [esp+] # -4
  xor   UTOS, UTOS
  test  dword^ [esp+] -4 #, UTOS
  jz    @@f
  mov   UTOS, # 1
  jns   @@f
  mov   UTOS, # -1
@@:
;code-swap-next

code-swap-inline: F-FINITE?  ( -- flag )  ( f:n -- f:n )
  push  UTOS
  fst   dword^ [esp+] # -4
  xor   UTOS, UTOS
  mov   eax, dword^ [esp+] # -4
  and   eax, # $7f80_0000
  cmp   eax, # $7f80_0000
  setnz bl
  movzx UTOS, bl
  neg   UTOS
;code-swap-next

code-swap-inline: F-DENORMAL?  ( -- flag )  ( f:n -- f:n )
  push  UTOS
  fst   dword^ [esp+] # -4
  mov   UTOS, dword^ [esp+] # -4
  and   UTOS, # $7FFF_FFFF
  jz    @@f
  and   UTOS, # $7f80_0000
  setz  bl
  movzx UTOS, bl
  neg   UTOS
@@:
;code-swap-next

: F-KILL-DENORMAL  ( f:n -- f:n )
  f-denormal? ?< fdrop 0.E >? ;

: F-NAN?  ( -- flag )  ( f:n -- f:n )
  f@f32 1 lshift $ff000000 u> ;

: F-INF?  ( -- false // 1 // -1 )  ( f:n -- f:n )
  f@f32 dup 1 lshift $ff000000 <> ?< drop 0 >?
  sign ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; parse floating number
;; WARNING! cannot be used for reliable round-trip!
;; this is far from the best way of doing it
;; (actually, this is one of the worst ways)
;; but until i port a better parser, this one can be used for rough fp input

module FLT-PARSE
<disable-hash>
<private-words>

0 quan (FM-SAVED)
vect bad-float

: fpu-setup   fpu-getcw (fm-saved):! fpu-up-mode ;
: fpu-restore (fm-saved) fpu-setcw ;

;; default handled, set in "COLD"
: (bad-float)  error" invalid floating number" ;


: *pow10  ( count )  ( f:value -- f:value*pow10 )
  << dup +?^| f10* 1- |? else| drop >> ;

: /pow10  ( count )  ( f:value -- f:value/pow10 )
  << dup +?^| f10/ 1- |? else| drop >> ;

;; parse integral part of the floating number
;; uses 2 FP registers
: parse-float-int  ( addr u -- addr1 u1 )  ( -- f:value )
  dup -0?exit< fpu-restore bad-float >?
  dup >r
  0.e << ( addr u )
    dup 0?v||
    over c@ 10 numparse:digit not?v||
    f10* s>f f+
  ^| string:/char | >>
  dup r> = ?exit< fpu-restore bad-float >? ;

;; parse integral part of the floating number
;; uses 2 FP registers
;; dot should be already eaten
: parse-float-frac  ( addr u -- addr1 u1 )  ( -- f:value )
  dup -0?exit< 0.e >?
  dup >r parse-float-int r>
  ( addr1 u1 u )
  over - /pow10 ;

;; 'e' should be already eaten
;; uses 2 FP registers
: parse-float-exp  ( addr u )  ( f:value -- f:exped-value )
  dup -0?exit< fpu-restore bad-float >?
  true >r
  ;; parse exponent sign
  over c@ <<
    [char] + of?v| string:/char |?
    [char] - of?v| false r! string:/char |?
  else| drop >>
  ( addr u | positive-flag )
  ;; parse exponent value
  10 numparse:based not?exit< fpu-restore bad-float >?
  r>
  ( expval positive-flag )
  over $800 u>= ?exit< fdrop nip ?< f+inf || f-inf >? >?
  ( expval positive-flag )
  ?< *pow10 || /pow10 >? ;

: first-char?  ( addr u ch -- flag )
  swap -0?exit< 2drop false >?
  swap c@ string:upchar = ;

;; uses 4 FP registers
@: PARSE-FLOAT  ( addr u )  ( -- f:value )
  dup -0?exit< bad-float >?
  ;; negate flag
  false >r
  over c@ <<
    [char] + of?v| string:/char |?
    [char] - of?v| true r! string:/char |?
  else| drop >>
  2dup " inf" string:=ci ?exit< 2drop r> ?< f-inf || f+inf >? >?
  2dup " nan" string:=ci ?exit< 2drop rdrop fnan >?
  fpu-setup
  parse-float-int
  2dup [char] . first-char? ?<
    string:/char
    parse-float-frac f+ >?
  2dup [char] E first-char? not?< 2drop || string:/char parse-float-exp >?
  r> ?< fnegate >? fpu-restore ;

seal-module
end-module FLT-PARSE


;; this stores float as string, hence the double colon
;; the string will be parsed at runtime
;; WARNING! no error checking!
*: F"  ( -- )  ( -- f:value )  ;; "
  system:comp? ?< str#, \\ flt-parse:parse-float
  || 34 parse-qstr flt-parse:parse-float >? ;


;; this stores float as 8 bytes
;; remember that float parser sux!
*: F#  ( -- )  ( -- f:value )
  parse-name flt-parse:parse-float
  system:comp? ?< f>f64 swap #, #, \\ f64>f >? ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; print floating number
;; WARNING! cannot be used for reliable round-trip!
;; this is not the best way of doing it
;; i have to port Ruy instead, but for now let's have at least something


module FLT-PRINT
<disable-hash>

17 quan (PRECISION)

;; digits in the integral parts
: (FPU-#EXP)  ( -- n ) ( r -- r )
  fdup f0= ?< (precision) || fdup fabs flog ffloor f>d drop >? ;

: (0.1E)  1.e 10.e f/ ;


16 constant (FPU-MPREC) ;; maximum precision
create (FPU-EXP) 32 allot create;  ;; exponent and sign (actually, only 8 bytes)

;; from http://www.alphalink.com.au/~edsa/represent.html (at least this is what SP-Forth says ;-)
;; if exponent is negative or zero, it is number zeroes right after the decimal point (i.e. for "0.001" it will be -2)
;; if exponent is positive, it is number of digits (i.e. for "1000" it will be 4)
;; for zero, exponent is 1 (becase it indicates number of digits at the left side, and zero is ".0" here)
: REPRESENT  ( c-addr u -- exponent negative-flag nonzero-flag ) ( F: r -- )
  2dup [char] 0 fill
  (fpu-mprec) min 2>r
  fdup f0<
  0 (fpu-exp) 2!be
  fabs fdup f0= 0=
  << ( flag ) ?^|
   fdup 1.e f< not?< 10.e f/ 1
   || fdup (0.1e) f< ?< 10.e f* -1
   || 0 >? >?
   dup (fpu-exp) +!
  |? else| >>
  1.e r@ \ 0 ?do 10.e f* loop f*
    << ( counter ) dup +?^| f10* 1- |? else| drop >> f*
  fround f>d
  2dup <#ds> dup r@ - (fpu-exp) +!
  2r> rot min 1 max cmove
  d0= (fpu-exp) 2@be swap rot ?< 2drop 1 false >?  ;; 0.0e fix-up
  true ;


;; trim trailing zeroes
: (FPU-TRIM-0)  ( c-addr u1 -- c-addr u2 )
  ;;fstrict if exit endif
  << ( addr count ) dup -0?v||
    1- 2dup + c@ [char] 0 = ?^||
  else| >> 1+ ;

: (<f#)  fpad (fhld):! ;

: (f#>)  ( addr count )  fpad (fhld) over - ;

;; this is not backwards
: (f#put)  ( ch )
  (fhld) c!
  (fhld):1+! ;

: (f#put-str)  ( addr count )
  swap << ( count addr )
    over +?^| c@++ (f#put)  1 under- |?
  else| 2drop >> ;


;; "e-nontation"
;; use "scientific", with one dot
;; the original number should be non-zero
;; fpad+128 should contain the result of "represent"
: (f.e)  ( exp -- addr count )
  fpad 128 + c@ (f#put)
  [char] . (f#put)
  fpad 129 + (precision) 1- 0 max (fpu-trim-0)
  (f#put-str)
  [char] E (f#put)
  1-
  dup 0>= ?< [char] + || negate [char] - >?
  (f#put)
  0 <#ds> (f#put-str) ;

;; decimal, with possible dot
;; the original number should be non-zero
;; fpad+128 should contain the result of "represent"
: (f.f)  ( exp -- addr count )
  dup -0?exit<
    negate  ;; now it is number of zeroes after the decimal point
    [char] 0 (f#put)
    [char] . (f#put)
    \ 0 ?do [char] 0 (f#put) loop
    << dup +?^| [char] 0 (f#put) 1- |? else| drop >>
    fpad 128 + (precision) (fpu-trim-0) (f#put-str) >?
  ;; integral part
  dup >r
  (precision) min fpad 128 + swap (f#put-str)
  ;; floating part
  r@ (precision) < ?<
    fpad 128 + r@ + (precision) r> - (fpu-trim-0)
    dup 1 = ?< over c@ [char] 0 = ?< 1- >? >?
    dup ?< [char] . (f#put) (f#put-str) || 2drop >?
  || rdrop >? ;

: (f.)  ( f:n -- addr count )
  base @ >r decimal
  (<f#)
  f-finite? ?<
    fpad 128 + (precision) represent
    0?<
      ;; zero
      [char] 0 (f#put)
      2drop
    ||
      ;; non-zero
      ?< [char] - (f#put) >?
      ;; if exponent is lower or greater than precision, use "e-notation"
      ;; FIXME: this is invalid for negative exponents (see above)
      ;;        for negative exponents, we should count real number of digits
      ;; calc lower exponent bound
      dup -0?<
        (precision)
        fpad 128 + over (fpu-trim-0) nip 2+ - 0 max
        negate
      || 0 >?
      over swap (precision) within ?< (f.f) || (f.e) >?
    >?
  ||
    f-nan? ?< " nan"
    || f-inf? dup ?< -?< [char] - || [char] + >? (f#put) " inf"
    || drop " wtf" >? >?
    fdrop
    (f#put-str)
  >?
  (f#>)
  r> base ! ;

end-module FLT-PRINT


: FPRECISION  ( -- u )  flt-print:(precision) ;
: SET-FPRECISION  ( u )  1 max 17 min flt-print:(precision):! ;

: F>STR  ( f:n -- addr count ) flt-print:(f.) ;
: F0.R  ( f:n -- )  f>str type ;
: F.  ( f:n -- )  f0.r bl emit ;
