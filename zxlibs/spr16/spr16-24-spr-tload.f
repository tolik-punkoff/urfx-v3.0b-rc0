;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16x16 XOR sprites, no runtime shifting
;; tileset loader, directly included from "spr16.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(*
tile format: 8 bitmap bytes, 1 attr byte
*)

extend-module TCOM

;; -1: use "zx-c,", otherwise put from this address
-1 quan tloader-zx-addr
-1 quan tloader-zx-addr-start

0 quan tloader-#tiles

module tile8-loader-support
<disable-hash>

;; current tile row
-1 quan tile-row#

;; number of bits processed
0 quan row-#bits
;; current tile byte
0 quan row-byte

-1 quan tile-attr


: tile-c,
  tloader-zx-addr -?exit<
    tloader-zx-addr-start -?< zx-here tloader-zx-addr-start:! >?
    zx-c, >?
  tloader-zx-addr-start -?< tloader-zx-addr tloader-zx-addr-start:! >?
  tloader-zx-addr zx-c!
  tloader-zx-addr:1+! ;


;; reset tile line
: row-reset
  row-#bits:!0
  row-byte:!0 ;

: row-char  ( addr -- addr+1 )
  row-#bits 7 > ?error" too much tile data in the row"
  c@++ <<
    [char] . of?v| 0 |?
    [char] # of?v| 1 |?
    [char] @ of?v| 1 |?
    [char] : of?v| 0 ( error" masks are not supported yet") |?
  else| error" wut?!" >>
  row-#bits:1+!
  row-byte 2* + row-byte:! ;

;; the state is reset, and ready for the new line.
: row-finish  ( -- row-word )
  \ row-#bits 7 <> ?error" invalid tile row"
  row-byte 8 row-#bits - lshift
  row-reset ;

end-module

module tile8-loader
<disable-hash>
using tile8-loader-support

;; start new tile
: tile
  tile-row# 0>= ?error" previous tile is not finished"
  tile-row#:!0
  tile-attr:!t ;

: empty-tile
  tile-row# 0>= ?error" previous tile is not finished"
  0 tile-c, 0 tile-c, 0 tile-c, 0 tile-c,
  0 tile-c, 0 tile-c, 0 tile-c, 0 tile-c,
  @007 tile-c,
  tloader-#tiles:1+! ;

;; finish the tile
: end-tile
  tile-row# 0< ?error" no tile started"
  tile-row# 8 <> ?error" not enough tile rows"
  ;; attr
  tile-attr 0< ?error" no tile attribute"
  tile-attr tile-c,
  tile-row#:!t
  tloader-#tiles:1+! ;

: attr  ( n )
  dup 255 u> ?error" invalid attribute"
  \ tile-row# 0< ?error" no tile started"
  \ tile-row# 8 <> ?error" attr must come last"
  \ zx-c, ;
  tile-attr:! ;

: row
  tile-row# 0< ?error" no tile started"
  tile-row# 7 > ?error" too many tile rows"
  parse-name \ dup 16 > ?error" tile row too long"
  row-reset swap << over ?^| row-char 1 under- |? else| 2drop >>
  row-finish tile-c,
  tile-row#:1+! ;


end-module

end-module \ TCOM
