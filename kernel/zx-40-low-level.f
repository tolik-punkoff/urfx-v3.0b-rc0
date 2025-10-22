;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level low-level words ;-)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>

;; this is often used with conditionals, so let's inline it for better optimisation
\ : WITHIN  ( test low high -- test>=low&&test<high )  OVER - >R - R> U< ; zx-inline
: WITHIN  ( test low high -- test>=low&&test<high )  OVER - NROT - U> ;

;; this is often used with conditionals, so let's inline it for better optimisation
\ : BOUNDS  ( utest ulow uhigh -- utest>=ulow&&utest<=uhigh )  OVER - >R - R> U<= ; zx-inline
: BOUNDS  ( utest ulow uhigh -- utest>=ulow&&utest<=uhigh )  OVER - NROT - U>= ;


;; need to be here
: HEXC>STR  ( num -- addr 2 )
  hexw>str drop 2+ 2 ; zx-inline


;; "MOVE" is too valuable, let's name it "MEMMOVE" instead
: MEMMOVE  ( from to len )
  >R 2DUP U> ?exit< R> CMOVE >? ;; from > to: use normal CMOVE
  ;; from <= to: use reverse CMOVE>
  R> CMOVE> ;


\ : TRAVERSE  ( addr1 n -- addr2 )
\   SWAP BEGIN OVER + 127 OVER C@ < UNTIL NIP ;

: -TRAILING  ( addr count -- addr1 count1 )
  \ DUP FOR 2DUP + 1- C@ BL - IF LEAVE ELSE 1- ENDIF ENDFOR ;
  DUP FOR 2DUP + 1- C@ BL - IF BREAK ENDIF 1- ENDFOR ;


: BASE@  ( -- n )  (BASE) ; zx-inline
: BASE!  ( n )     (BASE):! ; zx-inline

: HEX      16 BASE! ; zx-inline
: DECIMAL  10 BASE! ; zx-inline

: HERE   ( n )  SYS: (DP) @ ; zx-inline
: ALLOT  ( n )  SYS: (DP) +! ; zx-inline

: ,  ( n )  HERE ! 2 ALLOT ; zx-inline
: C, ( n )  HERE C! 1 ALLOT ; zx-inline


<zx-system>
(*
: (")   ( -- addr count )  R> COUNT 2DUP + >R ;
zx-no-tco-for-this zx-recursive
Succubus:setters:compiler: (ir-compile-bstr)
*)
primitive: (")  ( -- addr count )
Succubus:setters:compiler: (ir-compile-bstr-qq)
<zx-forth>

\ : ERASE  ( addr count )  0 FILL ; zx-inline
: BLANKS ( addr count )  BL FILL ; zx-inline
alias-for BLANKS is BLANK

\ : CERASE  ( addr count )  0 CFILL ; zx-inline
: CBLANKS ( addr count )  BL CFILL ; zx-inline

: PAD  ( -- pad^ )  HERE 32 + ; zx-inline


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level math

: +-  ( n1 n2 -- n3 )  -IF NEGATE ENDIF ; zx-inline
: D+- ( d1 n -- d2 )   -IF DNEGATE ENDIF ; zx-inline

\ : ABS  ( n1 -- n2 )  DUP +- ;
: DABS ( d1 -- d2 )  DUP D+- ; zx-inline

\ : D-  ( d1 d2 -- d1-d2 )  DNEGATE D+ ; zx-inline
\ OOPS!
\ : D<  ( d1 d2 -- bool )   D- NIP 0< ; zx-inline
\ : D<= ( d1 d2 -- bool )   D- NIP 0<= ; zx-inline
\ : D>  ( d1 d2 -- bool )   D- NIP 0> ; zx-inline
\ : D>= ( d1 d2 -- bool )   D- NIP 0>= ; zx-inline
: D<=  ( d1 d2 -- bool )   SWAP D- NIP 0>= ; zx-inline
: D>=  ( d1 d2 -- bool )   D- NIP 0>= ; zx-inline

: D=  ( d1 d2 -- bool )   D- OR 0= ; zx-inline
: D<> ( d1 d2 -- bool )   D- OR 0<> ; zx-inline

;; upgraded to primitives
\ : MIN  ( a b -- c )  2DUP > IF SWAP ENDIF DROP ;
\ : MAX  ( a b -- c )  2DUP < IF SWAP ENDIF DROP ;

: M*  ( n1 n2 -- d )  2DUP XOR >R ABS SWAP ABS UUD* R> D+- ;

;; this is SM/REM -- symmetric
;; and it should be called "M/MOD"!
;; divides a double into n giving quotient q and remainder r.
;; the remainder has the sign of dividend d.
( was "M/" )
: M/MOD  ( d n -- r q )  OVER >R >R DABS R@ ABS UDU/MOD R> R@ XOR +- SWAP R> +- SWAP ;

;; this works, but i don't think anybody will need it
: FM/MOD ( d n -- r q )
  DUP >R M/MOD OVER DUP 0<> SWAP 0<
  R@ 0< XOR AND IF 1- SWAP R> + SWAP ELSE RDROP ENDIF ;

: */MOD  ( a b -- a%b a/b )  >R M* R> M/MOD ; -- this should have the result in the reverse order!
: */     ( a b -- c )  */MOD NIP ; zx-inline
( was "M/MOD" )
: UM/MOD  ( ud1 u2 -- u3-rem ud4-quot )  >R 0 R@ UDU/MOD R> SWAP >R UDU/MOD R> ;

;; for truncated result, there is no difference between signed and unsigned multiplication
\ : *  ( a b -- c )  U* ;
alias-for U* is *
;; upgraded to primitives
\ : U/    ( ua ub -- ua/ub )  UU/MOD DROP ; zx-inline
\ : UMOD  ( ua ub -- ua%ub )  UU/MOD NIP ; zx-inline
\ : /    ( a b -- a/b )  /MOD NIP ; zx-inline
\ : MOD  ( a b -- a%b )  /MOD DROP ; zx-inline

(* with only 32-bit ops:
: U/   ( ua ub -- ua/ub )  0 SWAP UDU/MOD NIP ;
: UMOD ( ua ub -- ua%ub )  0 SWAP UDU/MOD DROP ;
: *    ( a b -- c )  M* DROP ;
: /MOD ( a b -- a%b a/b )  >R S>D R> M/MOD ;
: /    ( a b -- c )  /MOD NIP ;
: MOD  ( a b -- c )  /MOD DROP ;
*)


;; square root of d between 0 and 268435455
: DSQRT  ( d -- n )
  2DUP D+ 2DUP D+ 0 $8000 $0E FOR
    NIP >R 2DUP R@ UDU/MOD R> + 2U/
  ENDFOR 2U/ >R 3DROP R> ;

: SQRT16 ( +n -- root rem )
  \ 16-bit fast integer square root.
  \ Return root and remainder, or 0 -1 if n is negative
  \ From: Forth Dimensions 14/5
  DUP -IF DROP 0 -1 ELSE
    0 SWAP 16384 ( 2^14 )
    BEGIN
      >R DUP 2 PICK - R@ -
      DUP -IF DROP SWAP 2/
      ELSE NIP SWAP 2/ R@ +
      ENDIF
      SWAP R> 2/
    2/ DUP 0UNTIL
    DROP
  ENDIF ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; numeric printer

: .HEX2  ( u )  HEXC>STR TYPE ; zx-inline
: .HEX4  ( u )  HEXW>STR TYPE ; zx-inline

: .UDEC5 ( u )  DECW>STR5 TYPE ; zx-inline
: .UDEC  ( u )  DECW>STR TYPE ; zx-inline

: .DEC   ( n )  DUP -?< ABS [CHAR] - EMIT >? .UDEC ;
: .+-DEC ( n )  DUP -?< ABS [CHAR] - || [CHAR] + >? EMIT .UDEC ;

: HOLD  ( ch )  HLD @ --C! HLD ! ;
: HOLD$ ( addr count )  TUCK + << UNDER-1 OVER +0?^| --C@ HOLD |? ELSE| 2DROP >> ;
: (SSIGN)  ( n a -- a )  SWAP -?< [CHAR] - HOLD >? ;
: (DSIGN)  ( n d -- d )  ROT -?< [CHAR] - HOLD >? ;
: (DIGIT)  ( n -- char )  DUP 10 - +0?< 7 + >? [CHAR] 0 + HOLD ;

: <#     ( -- ) PAD HLD ! ;
: #>     ( n -- addr count )  DROP HLD @ PAD OVER - ;
: #      ( u1 -- u2 )  BASE@ UU/MOD (DIGIT) ;
: #(10)  ( u1 -- u2 )  10U/MOD (DIGIT) ;
: #S(10) ( u1 -- 0  )  DECW>STR HOLD$ 0 ; zx-inline
: #S     ( u1 -- u2 )  BASE@ 10 = ?< #S(10) || BEGIN # DUP 0UNTIL >? ;
: <#S>   ( u1 -- addr count )  <# #S #> ;
: <-#S>  ( n1 -- addr count )  DUP ABS <# #S (SSIGN) #> ;

: (.R)  ( n wdt -- addr count spaces# )  SWAP <-#S> ROT OVER - ;
: (U.R) ( u wdt -- addr count spaces# )  SWAP <#S> ROT OVER - ;

: .R    ( n wdt )  (.R) SPACES TYPE ;
: U.R   ( u wdt )  (U.R) SPACES TYPE ;
: L.R   ( n wdt )  (.R) NROT TYPE SPACES ;
: LU.R  ( u wdt )  (U.R) NROT TYPE SPACES ;
: 0.R   ( n )  0 .R ; zx-inline
: 0U.R  ( n )  0 U.R ; zx-inline
: U.    ( u )  0U.R SPACE ;
: .     ( n )  0.R SPACE ;

: D#>    ( d -- addr count )  DROP #> ; zx-inline
: D#     ( d1 -- d2 )  BASE@ UM/MOD ROT (DIGIT) ;
: D#S    ( d1 -- d2 )  BEGIN D# 2DUP OR 0UNTIL ;
: <-D#S> ( d -- addr count )  TUCK DABS <# D#S (DSIGN) D#> ;
: (D.R)  ( d n -- addr count spaces# )  >R <-D#S> R> OVER - ;
: D.R    ( d n )  (D.R) SPACES TYPE ;
: 0D.R   ( d n )  0 D.R ; zx-inline
: D.     ( d )    0D.R SPACE ; zx-inline


<zx-done>
