0 variable RAND-X

\ SF-RAND is the random-number generator from Brodie's
\ Starting Forth. Of course, with 16-bit arithmetic, 65535 AND may be omitted.
: SF-RAND-NEXT  ( -- 0..32767 )
  RAND-X @ 31421 * 6927 + 65535 AND
  DUP RAND-X ! ;

\ C-RAND is the default random-number generator for the Standard C Library.
: C-RAND-NEXT  ( -- 0..32767 )
  RAND-X @ 1103515245 * 12345 + DUP RAND-X ! 16 RSHIFT 32767 AND ;

\ Marsaglia (1972)
: EASY-RAND-NEXT  ( -- 0..4294967295 )
  RAND-X @ 69069 * 1+ DUP RAND-X ! ;

\ BS-RAND uses the best spectral primitive root for modulus
\ 2147483647. G.S. Fishman found it by brute force in 1986.
: BS-RAND-NEXT  ( -- 1..2147483646 )
  RAND-X @ 62089911 2147483647 */MOD ( DROP) NIP DUP RAND-X ! ;

\ EP-RAND is an efficiently portable multiplier found by Fishman in 1988.
: EP-RAND-NEXT  ( -- 1..2147483646 )
  RAND-X @ 48271 2147483647 */MOD ( DROP) NIP DUP RAND-X ! ;

\ EP2-RAND is an efficiently portable multiplier found by L'Ecuyer in 1988.
: EP2-RAND-NEXT  ( -- 1..2147483338 )
  RAND-X @ 40692 2147483647 248 - */MOD ( DROP) NIP DUP RAND-X ! ;


: CHOOSE  ( u rnd-xt -- n )  2* execute um* nip ;
