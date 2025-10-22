;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CRC32
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module crc32-helper
<disable-hash>
<published-words>
create crc32-table 256 4* allot create;
create crc32c-table 256 4* allot create;
<private-words>

: (crc32-row)  ( limit poly )
  256 0 do over i + 4* crc32-table +
           over i 4* crc32-table + @ xor swap !
  over 2* +loop 2drop ;

: crc32-gen  ( reversed-poly )
  crc32-table !0
  >r 128 ( reg ) 1 ( crc ) begin
    dup 2 u/ swap 1 and ?< r@ xor >?
    2dup (crc32-row)
  swap 2 u/ tuck not-until 2drop rdrop ;

$82F63B78 crc32-gen -- crc32c (Castagnoli)
crc32-table crc32c-table 256 4* cmove
$EDB88320 crc32-gen
seal-module
end-module


extend-module forth
using crc32-helper

: crc32-buf-part  ( addr count crc32 -- crc32 )
  >r begin dup +while swap c@++ r@ xor lo-byte 4* crc32-table + @
  r> 256 u/ xor >r swap 1- repeat 2drop r> ;

: crc32-buf  ( addr count -- crc32 )  -1 crc32-buf-part bitnot ;


: crc32c-buf-part  ( addr count crc32 -- crc32 )
  >r begin dup +while swap c@++ r@ xor lo-byte 4* crc32c-table + @
  r> 256 u/ xor >r swap 1- repeat 2drop r> ;

: crc32c-buf  ( addr count -- crc32 )  -1 crc32c-buf-part bitnot ;

end-module


\ fast self-check
" Alice & Miriel" crc32-buf $5D489338 = " wuta?!" not?error
" Alice & Miriel" crc32c-buf $98205CEC = " wuta?!" not?error
