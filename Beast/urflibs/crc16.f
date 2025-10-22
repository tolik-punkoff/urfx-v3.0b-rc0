;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CRC16
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module crc16-helper
<disable-hash>
<published-words>
create crc16-table 256 2* allot create;
<private-words>

: (crc16-row)  ( limit poly )
  256 0 do over i + 2* crc16-table +
           over i 2* crc16-table + w@ xor swap w!
  over 2* +loop 2drop ;

: crc16-gen  ( reversed-poly )
  crc16-table !0
  >r 128 ( reg ) 1 ( crc ) begin
    dup 2 u/ swap 1 and ?< r@ xor >?
    2dup (crc16-row)
  swap 2 u/ tuck not-until 2drop rdrop ;

(*
: crc16-dump
  crc16-table 32 for 8 for dup w@ ."  0x" .hex4 ." ," 2+ endfor cr endfor drop ;
*)

0xA001 crc16-gen
\ crc16-dump
seal-module
end-module


extend-module forth
using crc16-helper

: crc16-buf-part  ( addr count crc16 -- crc16 )
  >r begin dup +while swap c@++ r@ xor lo-byte 2* crc16-table + w@
  r> 256 u/ xor >r swap 1- repeat 2drop r> lo-word ;

\ : crc16-buf  ( addr count -- crc16 )  0 crc16-buf-part ;
: crc16-buf  ( addr count -- crc16 )  $FFFF crc16-buf-part bitnot lo-word ;

\ fast self-check
\ " Alice & Miriel" crc16-buf $A626 = " wuta?!" not?error
" Alice & Miriel" crc16-buf $5872 = " wuta?!" not?error
