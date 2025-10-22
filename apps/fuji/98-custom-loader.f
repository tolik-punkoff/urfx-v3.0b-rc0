;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Invasion Terrestre, built with ZX Spectrum UrF/X Forth System
;; written by Ketmar Dark, graphics by Fransouls
;; Invisible Vector production, 2025
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; custom tape loader and .tap creator
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; `tap-fd` is file descriptor.
;; file is opened for reading and writing, and truncated.
;; do not close the file!

;; create BASIC loader with embedded machine code

true constant TURBO-LOADER?

;; first, create asm code (it will be wiped later)
$4000 constant zx-loader-org  ;; it doesn't matter, the code is relocatable
$FC00 constant zx-main-loader-org  ;; where to copy the loader code
0 quan zx-loader-start-addr
0 quan zx-loader-len-addr
0 quan zx-loader-run-addr
0 quan zx-main-loader-ofs-addr
0 quan zx-main-loader-ofs
0 quan zx-main-loader-len-addr
0 quan zx-main-loader-len

z80asm:emit:here:@ vectored z80asm-orig-here
z80asm:emit:c@:@ vectored z80asm-orig-c@
z80asm:emit:c!:@ vectored z80asm-orig-c!

0 quan cldr-here-base

|: (cldr>zx-addr)  ( addr -- addr )
  cldr-here-base - zx-main-loader-org ;

|: (cldr<zx-addr)  ( addr -- addr )
  zx-main-loader-org - cldr-here-base + ;

: cldr-custom-here  ( -- here )
  z80asm-orig-here (cldr>zx-addr) + ;

: cldr-custom-c@  ( addr -- byte )
  (cldr<zx-addr) z80asm-orig-c@ ;

: cldr-custom-c!  ( byte addr )
  (cldr<zx-addr) z80asm-orig-c! ;

: cldr-set-custom-here
  ['] cldr-custom-here z80asm:emit:here:!
  ['] cldr-custom-c@ z80asm:emit:c@:!
  ['] cldr-custom-c! z80asm:emit:c!:! ;

: cldr-restore-custom-here
  z80asm-orig-here:@ z80asm:emit:here:!
  z80asm-orig-c@:@ z80asm:emit:c@:!
  z80asm-orig-c!:@ z80asm:emit:c!:! ;

: cldr-str-or$80-encoded,  ( addr count )
  2>r z80asm:instr:flush! 2r>
  dup -0?exit< 2drop >?
  1- for c@++ -1 xor z80asm:emit:c, endfor
  c@ $80 forth:or -1 xor z80asm:emit:c, ;

: cldr-cargando-text  ( -- adrr count )
  " \x14\x00\x15\x00\x16\x00\x0a...CARGANDO..." ;


zxa:org@ constant zx-orig-org
zx-loader-org zxa:org!
<asm>
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; basic loader code.
;; it should be relocatable!
zx-basic-loader-start:
  xor   a
  ld    hl, # $5800
  ld    de, # $5801
  ld    bc, # 767
  ld    (hl), a
  ldir
  out   $FE (), a
  halt

  ld    hl, # $4000
  ld    de, # $4001
  ld    bc, # 6144
  ld    (hl), a
  ldir
  ld    (hl), # @117
  ld    bc, # 32
  ldir
  ld    (hl), # @007
  ld    bc, # 31
  ldir
  \ zxemut-bp

  di
  ld    sp, # zx-main-loader-org
  ld    a, # $C9
  ld    $4800 (), a
  call  # $4800
.myaddr:
  dec   sp
  dec   sp
  pop   hl
  ld    de, # 0
$here 2- zx-main-loader-ofs-addr:!
  add   hl, de
  ld    de, # zx-main-loader-org
  ld    bc,  # 0
$here 2- zx-main-loader-len-addr:!
  ldir
  jp    # zx-main-loader-org
  flush!

$here .myaddr - zx-main-loader-ofs:!

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main loader code, at zx-main-loader-org
  $here cldr-here-base:!
  cldr-set-custom-here

main-loader-start:
  ld    hl, # cargando-text 1 -
.print-loop:
  inc   hl
  ld    a, (hl)
  cpl
  and   # $7F
  rst   # $10
  bit   7, (hl)
  jr    nz, # .print-loop

(*
  ;; set flash attrs
  ld    b, # 14 2 /
  ld    hl, # $5800 10 +
  ld    a, # @371
  ld    c, # @317
.flash-loop:
  ld    (hl), c
  inc   l
  ld    (hl), a
  inc   l
  djnz  # .flash-loop
*)
  ;; set attrs
  ld    b, # 32
  ld    hl, # $5800
  ld    a, # @117
.flash-loop:
  ld    (hl), a
  inc   l
  djnz  # .flash-loop

  ;; make the text bold
  ld    hl, # $4000
  ld    e, h
  ld    c, # 32
.bold-loop-outer:
  ld    b, # 8
.bold-loop-inner:
  ld    a, (hl)
  rla
  or    (hl)
  ld    (hl), a
  inc   h
  djnz  .bold-loop-inner
  ld    h, e
  inc   l
  dec   c
  jr    nz, # .bold-loop-outer

  ;; use scr$ for the stack
  \ di
  ld    sp, # $5800

  ;; load bytes
  ld    ix, # $8000   ;; start address
  flush!
  z80asm-orig-here 2- zx-loader-start-addr:!
  ld    de, # $1000   ;; length
  flush!
  z80asm-orig-here 2- zx-loader-len-addr:!
  push  de
  push  ix
  ld    a, # $CB      ;; leading byte
  ;; jump into the loading routine
  0 [IF]
    or    a             ;; reset zero flag
    scf                 ;; carry flag is set -- we need to load bytes
    ex    af, afx
    ld    a, # $0F
    out   $FE (), a
    call  # $0562
  [ELSE]
    call  # custom-ld-bytes-entry
  [ENDIF]
  ;; we will return here
  ;; carry flag is reset on error
  jr    c, # .do-start
  ;; loading error
.error:
  ld    a, # 2
  out   $FE (), a
  halt
.do-start:
  0 [IF]
    ;; check break key
    ld    a, # $7F
    in    a, () $FE
    rra
    jr    nc, # .error
  [ENDIF]

  di
  zxemut-max-speed
  ;; decrypt code
  pop   hl
  pop   bc
  ld    e, # $29
.decrypt-loop:
  ld    a, e
  sub   (hl)
  ld    d, a
  ld    a, (hl)
  xor   # $5A
  xor   e
  rlca
  bit   0, c
  jr    z, # .decrypt-skip
  rrca
  rrca
.decrypt-skip:
  xor   c
  ld    (hl), a
  ld    e, d
  ;; done
  and   # $01
  out   $FE (), a
  inc   hl
  dec   bc
  ld    a, b
  or    c
  jr    nz, # .decrypt-loop
  zxemut-normal-speed

  ;; run it
  ld    sp, # $5D00   ;; relatively safe place
  xor   a
  out   $FE (), a
  ei
  jp    # $8000   ;; start address
  flush!
  z80asm-orig-here 2- zx-loader-run-addr:!

$include "99-custom-loader-asm.f"

cargando-text:
  \ 16 db, 7 db,  ;; INK
  \ 17 db, 1 db,  ;; PAPER
  \ 18 db, 0 db,  ;; FLASH
  \ 19 db, 1 db,  ;; BRIGHT

  \ 20 db, 0 db,  ;; INVERSE
  \ 21 db, 0 db,  ;; OVER
  \ 22 db, 0 db, 10 db,
  cldr-cargando-text cldr-str-or$80-encoded,

main-loader-end:
main-loader-end main-loader-start - zx-main-loader-len:!
<end-asm>
cldr-restore-custom-here
zxa:org@ zx-loader-org - constant zx-loader-size
zx-orig-org zxa:org!


;; BASIC integer number format:
;; 14, 0, 0
;; lo-byte
;; hi-byte
;; 0

: put-zx-byte  ( b )  lo-byte pad$:c+ ;

: put-zx-int  ( w )
  [char] 0 put-zx-byte
  14 put-zx-byte
  0 put-zx-byte
  0 put-zx-byte
  dup lo-byte put-zx-byte
  hi-byte put-zx-byte
  0 put-zx-byte ;



0 quan encrypt-addr-0
0 quan encrypt-bc-0
0 quan encrypt-addr
0 quan encrypt-bc
0 quan encrypt-a
0 quan encrypt-e

;; this made to be as close to the Z80 asm as possible.
: encrypt-zx-code  ( addr count )
  dup -0?exit< 2drop >?
  dup encrypt-bc:! encrypt-bc-0:!
  dup encrypt-addr:! encrypt-addr-0:!
  $29 encrypt-e:!
\ endcr ." FIRST BYTES: $" encrypt-addr-0 c@ .hex2 ."  $" encrypt-addr-0 1+ c@ .hex2 cr
  <<
    encrypt-addr c@
    ;; in backward order
    encrypt-bc xor
    1 ror8
    encrypt-bc 1 and ?<
      2 rol8
    >?
    encrypt-e xor
    $5A xor
    dup encrypt-addr c!
    lo-byte c>s negate encrypt-e:+!
    encrypt-addr:1+!
    encrypt-bc:1-!
  encrypt-bc ?^||
  else| >>
\ endcr ." FIRST BYTES: $" encrypt-addr-0 c@ .hex2 ."  $" encrypt-addr-0 1+ c@ .hex2 cr
;


: custom-tap-writer
  [ TURBO-LOADER? ] [IF]
  zxa:tap:fmt-pzx zxa:tap:tape-format = not?error" use PZX for turbo loader!"
  [ENDIF]

  pad$:!0
  ;; line number
  0 put-zx-byte 0 put-zx-byte
  ;; line length
  0 put-zx-byte 0 put-zx-byte
  \ zx-loader-size 34 +
  \ dup lo-byte put-zx-byte hi-byte put-zx-byte

  ;; 23635: start of the BASIC program
  ;; create run line
  \ 226 put-zx-byte -- STOP
  \  58 put-zx-byte -- :

  245 put-zx-byte -- PRINT
  192 put-zx-byte -- USR
   40 put-zx-byte -- (
  190 put-zx-byte -- PEEK
  23635 put-zx-int
   43 put-zx-byte -- +
  256 put-zx-int
   42 put-zx-byte -- *
  190 put-zx-byte -- PEEK
  23636 put-zx-int
   43 put-zx-byte -- +
  42 put-zx-int
   41 put-zx-byte -- )
   58 put-zx-byte -- :

  ;; fix the loader
  $6000 $FFFF zxa:used-range-from-to
  over - zx-loader-len-addr tcom:zx-w!
  zx-loader-start-addr tcom:zx-w!
  zxa:ent@ zx-loader-run-addr tcom:zx-w!

  zx-main-loader-ofs zx-main-loader-ofs-addr tcom:zx-w!
  zx-main-loader-len zx-main-loader-len-addr tcom:zx-w!

  ;; copy the loader
  zx-loader-size for
    zx-loader-org i + tcom:zx-c@
    put-zx-byte
  endfor
  ;; wipe it
  $0000 $5B00 zxa:mem:mark-unused

  tcom:Succubus-mark-string for c@++ put-zx-byte endfor drop

  ;; save the loader
  ;; header
  \ " cargador" 0 zxa:tap:tap-mk-header
  " FUJInoYAMA" 0 zxa:tap:tap-mk-header
  pad$:@ nip zxa:tap:tap-header-len!
  0 zxa:tap:tap-header-autostart!
  tap-fd zxa:tap:tap-save-header
  ;; BASIC data
  pad$:@
  endcr ." cargador size: " dup tcom:.bytes cr
  tap-fd zxa:tap:tap-save-data

  ;; now headerless code
  [ TURBO-LOADER? ] [IF]
  ;; setup constants
  945 zxa:tap:tail-pulse-length:!
  426 zxa:tap:zero-pulse-length:!
  839 zxa:tap:one-pulse-length:!
  [ENDIF]

  $6000 $FFFF zxa:used-range-from-to
  endcr ." saving code from $" over .hex4 ."  to $" dup .hex4
  ." ; size: " 2dup swap - tcom:.bytes cr
  over -
  swap tcom:zx>real swap
  2dup encrypt-zx-code
  $CB tap-fd zxa:tap:tap-save-data-with-flag-byte
;
