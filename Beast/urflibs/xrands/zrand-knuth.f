;; they should not be 0
;; RAND-X does not have problem with low-order bits (why this matters at all?)
1 variable RAND-X
1 variable RAND-Y

: KK-RAND-NEXT  ( -- 1..2147483647 )
  RAND-X @ 48271 2147483647 */MOD ( DROP) NIP DUP RAND-X !  ;; EP-RAND
  RAND-Y @ 40692 2147483399 */MOD ( DROP) NIP DUP RAND-Y !  ;; RP2-RAND
  - DUP -0?< 2147483648 + >? ;

;; why the fuck "2*"?
: CHOOSE  ( u -- n )  2* KK-RAND-NEXT um* nip ;

: test00
  0 ( wow count )
  100_000_000 for
    127 choose dup 0 127 within not?error" fuck"
    126 = ?< ( ." wow!\n") 1+ >?
  endfor
  ., ." wows found.\n" ;
test00

