;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple ZX Spectrum assembler
;; coded by Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; initial loading, system variables
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$use <z80asm>
$use <z80-labman>

extend-module ZXA
<disable-hash>
<published-words>

25000 quan (org) (private)
25000 quan (clr) (private)
25000 quan (ent) (private)

: org@  ( -- org )  (org) ;
: org!  ( org -- )  z80asm:flush lo-word (org):! ;

: clr@  ( -- clr )  (clr) ;
: clr!  ( clr -- )  z80asm:flush lo-word (clr):! ;

: ent@  ( -- ent )  (ent) ;
: ent!  ( ent -- )  z80asm:flush lo-word (ent):! ;

;; move current ORG without flushing Z80ASM
: (zx-allot)  ( bytes )  (org) + lo-word (org):! ;

: zx-allot  ( bytes )  (org) + org! ;


module MEM
<disable-hash>
<published-words>

create ram 65536 allot create;
create flags 65536 allot create;

bitmask-enum{
  def: f-used
}

: init-memory
  ram 65536 erase
  flags 65536 erase ;
init-memory

|: flags^  ( zx-addr -- addr )  lo-word flags + ;
: ram^    ( zx-addr -- addr )  lo-word ram + ;

vect-empty trace-c!  ( byte addr -- byte addr )

: used? ( zx-addr -- flag )  flags^ forth:c@ f-used mask? ;
: used  ( zx-addr )          flags^ dup forth:c@ f-used or swap forth:c! ;
: c@    ( zx-addr -- byte )  ram^ forth:c@ ;
: w@    ( zx-addr -- byte )  dup @@current:c@ swap 1+ @@current:c@ 256 * + ;
: c!    ( byte zx-addr )  trace-c! dup used ram^ forth:c! ;
: w!    ( word zx-addr )  2dup @@current:c! swap hi-byte swap 1+ @@current:c! ;
: db,   ( byte )  org@ @@current:c! 1 (zx-allot) ;
: dw,   ( word )  org@ @@current:w! 2 (zx-allot) ;

['] org@  z80asm:emit:here:!
['] @@current:db, z80asm:emit:c,:!
['] @@current:c@ z80asm:emit:c@:!
['] @@current:c! z80asm:emit:c!:!

;; utils

: unused  ( zx-addr )  flags^ dup forth:c@ f-used ~and swap forth:c! ;

;; mark memory as unused (but keep the contents).
;; unused memory will not be written to disk/tape.
: mark-unused  ( zx-addr count )
  for dup unused 1+ endfor drop ;

z80asm:asm-reset

seal-module
end-module


extend-module z80asm:instr

;; use "flush!", or declare a label before using this!
\ : db,  ( byte )  >r z80asm:flush r> mem:db, ;
\ : dw,  ( word )  >r z80asm:flush r> mem:dw, ;

: lbl-addr:  \ label-name
  parse-name
  z80-labman:ref-label, ;

: lbl-addr-ofs:  ( ofs )  \ label-name
  parse-name
  rot z80-labman:ref-label-ofs, ;

end-module


128 constant max-block-gap (private)

: next-block-from  ( zx-addr -- zx-addr )
  << dup hi-word ?v||
     dup mem:used? not?^| 1+ |?
  else| >> ;

;; after the last block byte; it can be $1_0000
: block-end-from  ( zx-addr -- zx-end-addr )
  << dup hi-word ?v||
     dup mem:used? ?^| 1+ |?
  else| >> ;

;; remove short empty blocks (up to max-block-gap bytes)
: normalize-blocks
  0 next-block-from << ( zx-addr )
    dup hi-word ?v||
    block-end-from dup hi-word ?v||
    dup next-block-from ( zx-prev-end zx-new-start )
    dup hi-word ?v| drop |?
\ endcr ." diff=" 2dup - 0.r cr
    2dup - [ max-block-gap negate ] {#,} < ?^| nip |?
\ endcr ." !!! start=$" dup .hex4 ."  end=$" over .hex4 cr
    swap << 0 over mem:c! 1+ 2dup - ?^|| else| drop >>
  ^|| >> drop ;

: count-blocks  ( -- count )
  0 0 << ( counter addr )
    next-block-from dup hi-word ?v||
\ endcr ." counter=" over . ." addr=$" dup .hex4 cr
    ^| 1 under+ block-end-from |
  >> drop ;


;; if no bytes used, return $10000
: first-used-from  ( zx-addr -- zx-addr )
  lo-word
  <<
    dup mem:used? ?v||
    1+ dup $10000 < ?^||
  else| >> ;

;; if no bytes used, return -1
;; search backwards
: last-used-from  ( zx-addr -- zx-addr )
  lo-word
  <<
    dup mem:used? ?v||
    1- dup +0?^||
  else| >> ;

;; calculate total range of used bytes inside the given zx address range
;; (end is exclusive!)
: used-range-from-to  ( addr-start addr-end -- addr-start addr-end )
  swap lo-word swap lo-word
  2dup >= ?exit< drop dup >?
  $10000 -1 2swap
  ( min max start end )
  over - for ( min max addr )
    dup mem:used? ?<
      >r
      swap r@ min
      swap r@ max
      r>
    >?
  1+ endfor
  drop
  dup -?< 2drop 0 0 || 1+ >? ;

seal-module
end-module
