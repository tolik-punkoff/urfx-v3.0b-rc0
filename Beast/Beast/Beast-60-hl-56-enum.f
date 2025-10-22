;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; enums
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
enum{
  def: name
  def: name
}

"n enum-from{" -- start from `n`.

"bitmask-enum{" create bitmasks. after defining a name, enum value
is shifted left by one bit.

inside enum definition:
  n set -- set new current value
  n +set -- increment current value
  n -set -- decrement current value
  n set-bit -- set current value to 1<<n
*)


module (ENUM-INTERNAL)
<disable-hash>
: def:  ( evalue -- enextvalue )  \ name
  dup parse-name system:mk-constant 1+ ;

: }  ( evalue )  drop pop-ctx ;
: }-leave-max  ( evalue -- max-value+1 )  pop-ctx ;

: set   ( evalue newvalue -- newvalue )   nip ;
: -set  ( evalue delta -- evalue-delta )  - ;
: +set  ( evalue delta -- evalue+delta )  + ;

|: (activate)  push-ctx vocid: (enum-internal) context! ;
end-module (ENUM-INTERNAL) (private)

module (BIT-ENUM-INTERNAL)
<disable-hash>
: def:  ( evalue -- enextvalue )  \ name
  dup parse-name system:mk-constant 2* ;

: }  ( evalue )  drop pop-ctx ;
: set  ( evalue newvalue -- newvalue )  nip ;

|: (activate)  push-ctx vocid: (bit-enum-internal) context! ;

end-module (BIT-ENUM-INTERNAL) (private)


extend-module FORTH

: enum-from{  ( start-value -- enextvalue )  (enum-internal)::(activate) ;
: enum{  ( -- enextvalue )  0 (enum-internal)::(activate) ;

: bitmask-enum{  ( -- enextvalue )     1 (bit-enum-internal)::(activate) ;
: bits-enum{  ( -- etype enextvalue )  1 (bit-enum-internal)::(activate) ;
: bit-enum{  ( -- etype enextvalue )   1 (bit-enum-internal)::(activate) ;

end-module FORTH
