;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 32-column print driver
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


zxlib-begin" ROM emit driver"

32 constant #COLS

;; show cursor while waiting a key?
;; bit 0: show cursor?
;; bit 7: simple inverted block, no C/L char.
;; bit 4 is used to tell if the cursor was printed.
;; it is set by ".CUR", and reset by ".CUR0".
\ 1 variable KCUR
1 to ALLOW-G?


OPT-EMIT8-ROM-OBL? [IF]
: ?SPACE OBL? ?EXIT SYS: S-POSN-X C@ 33 - NOT?EXIT SPACE ;
\ : ?SPACE OBL? ?EXIT AT@ DROP NOT?EXIT SPACE ;
[ENDIF]  \ OPT-EMIT8-ROM-OBL?


;; original printer: $094F
;; waiting for one operand printer: $0A87
;; waiting for two operands printer: $0A6D
;; print routine is at 23633


;; k8: removed printer output
;; k8: also, removed channel open on each emit
code: (CEMIT)  ( ch )
  push  iy
  restore-iy
  ld    c, l  ;; save char
  ;; print whole 24 lines
  xor   a
  ld    sysvar-defsz (), a
  ;; no scroll prompt
  dec   a
  ld    sysvar-scr-ct (), a
  ;; load printing routine high address byte
  ld    hl, () sysvar-curchl
  inc   hl
  ld    a, (hl)
  ;; load arguments
  ld    l, c
  \ push  bc
  ;; check if we are printing something special
  ;; (i.e. this is some control code awaiting the argument)
  cp    # $09
  ld    a, l
  jr    nz, # .print-special
  ;; not an arg, just a normal char
  cp    # 4
  jr    c, # .not-my-control
  cp    # 10
  jr    nc, # .not-my-control
  ld    hl, # zx-emit8-jtbl 4 2* -
  add   a, a
  add   a, l
  ld    l, a
  ld    a, h
  adc   a, # 0
  ld    h, a
  ld    a, (hl)
  inc   hl
  ld    h, (hl)
  ld    l, a
  jp    hl
.not-my-control:
.do-it-again:
@zx-emit8-doit:
  OPT-EMIT8-ROM-OBL? [IF]
  ld    hl, # zx-['pfa] OBL?
  ld    (hl), # 0
  cp    # 32
  jr    nz, # .not-bl
  inc   (hl)
.not-bl:
  [ENDIF]
  ;; increment "OUT"?
  OPT-EMIT8-ROM-OUT#? [IF]
  cp    # 32
  jr    c, # .no-out-inc
  ld    hl, # zx-['pfa] OUT#
  inc   (hl)
.no-out-inc:
  [ENDIF]
.print-special:
  rst   # $10
  \ call  # $09F4
  ;; check scroll
  OPT-EMIT8-ROM-SC#? [IF]
  ld    a, () sysvar-scr-ct
  inc   a
  jr    z, # .exit
  ld    hl, # zx-['pfa] SC#
  inc   (hl)
  [ENDIF]
.exit:
  \ pop   bc
  pop   iy
  pop   hl
  next

@zx-emit8-endcr:
  ld    a, () sysvar-s-posn-x
  sub   # 33
  ld    a, # 13
  jr    nz, # .do-it-again
  jr    # .exit

@zx-emit8-col0:
  ;; directly adjust position and coords
  ld    hl, # sysvar-df-cc
  ld    a, (hl)
  and   # $E0
  ld    (hl), a
  ld    a, # 33
  ld    sysvar-s-posn-x (), a
  jr    # .exit

@zx-emit8-left:
  ld    hl, # sysvar-s-posn-x
  ld    a, (hl)     ;; load X
  cp    # 33
  ld    a, # 8
  jr    nz, # .do-it-again
  ;; column #0, use "AT".
  ;; this is because ROM cannot go from row #1 to row #0, and can go up from row #0.
  inc   hl
  ld    a, # 23
  sub   (hl)        ;; load Y
  jp    m, # .exit  ;; top row, do nothing
  ;; use "AT" control code
  push  af
  ld    a, # 22
  rst   # $10
  pop   af
  rst   # $10
  ld    a, # 31
  rst   # $10
  jr    # .exit

@zx-emit8-right:
  ;; ROM doesn't store new position, so emulate it.
  ;; just print a space with "OVER 1", and no attr change.
  ld    hl, # sysvar-p-flag
  ld    a, (hl)
  push  af
  push  hl
  or    # $03   ;; OVER 1
  ld    (hl), a
  ld    hl, # sysvar-mask-t
  ld    a, (hl)
  push  af
  push  hl
  ld    (hl), # $FF
  ld    a, # 32
  rst   # $10
  pop   hl
  pop   af
  ld    (hl), a
  pop   hl
  pop   af
  ld    (hl), a
  jr    # .exit

  ;; jump table for 4..9 opcodes
  ;; we need to handle "left" and "right" ourself,
  ;; to workaround ROM bugs.
flush!
zx-emit8-jtbl:
  zx-emit8-endcr dw,        ;; 4
  zx-word-pr-cls-entry dw,  ;; 5
  zx-emit8-doit dw,         ;; 6
  zx-emit8-col0 dw,         ;; 7
  zx-emit8-left dw,         ;; 8
  zx-emit8-right dw,        ;; 9
;code


;; common "CLS" code
raw-code: (CLS)
  push  iy
  restore-iy
  push  hl
zx-word-pr-cls-entry:
  ;; fix attrs
  ld    hl, () sysvar-attr-p
  ld    sysvar-attr-t (), hl
  ;; reset scroll count
  OPT-EMIT8-ROM-SC#? [IF]
  ld    hl, # 0
  ld    zx-['pfa] SC# (), hl
  [ENDIF]
  ;; reset "cursor printed" bit
  OPT-EMIT8-ROM-KCUR? [IF]
  ld    hl, # zx-['pfa] KCUR
  res   4, (hl)
  [ENDIF]
  ;; clear scr$
  ld    hl, # $4000
  ld    de, # $4001
  ld    bc, # 6144
  ld    (hl), # 0
  ldir
  ;; set attr$
  ld    bc, # 767
  ld    a, () sysvar-attr-p
  ld    (hl), a
  ldir
 0 ( OPT-CUSTOM-EMIT?) [IFNOT]
  ;; we need to have at least one line in the bottom area for ROM printing
  ld    a, # 1
  ld    sysvar-defsz (), a
  ;; open chan #2
  ld    a, # 2
  call  # $1601
  ;; print whole 24 lines
  xor   a
  ld    sysvar-defsz (), a
  ;; no scroll prompt
  dec   a
  ld    sysvar-scr-ct (), a
  ;; AT 0, 0
  ld    a, # 22
  rst   # $10
  xor   a
  rst   # $10
  xor   a
  rst   # $10
 [ENDIF]
  pop   hl
  pop   iy
;code


;; scroll up
raw-code: (SCROLL)
  push  iy
  restore-iy
  push  hl
  call  # $0DFE ;; CL-SC-ALL
  ;; set attribute for the lower part
  ld    hl, # $5800 23 32 * +
  ld    de, # $5800 23 32 * + 1+
  ld    a, () sysvar-attr-p
  ld    (hl), a
  ld    bc, # 31
  ldir
  OPT-EMIT8-ROM-SC#? [IF]
  ld    hl, # zx-['pfa] SC#
  inc   (hl)
  [ENDIF]
  pop   hl
  pop   iy
;code


(* NOT FINISHED!
;; should not print beyond the right screen edge.
code: XTYPE  ( addr count )
  pop   hl
  pop   de
  push  bc
  ld    bc, hl
  ;; BC=count
  ;; DE=addr
  ld    a, () sysvar-p-flag
  push  af
.loop:
  ld    a, b
  or    c
  jr    z, # .done
  ld    hl, () sysvar-p-flag  ;; H doesn't matter
  res   2, l
  ld    a, (de)
  cp    # 165
  jr    c, # .not-high
  set   2, l
  and   # $7F
.not-high:
  cp    # 32
  jr    nc, # .not-low
  ld    a, # [char] ?
  set   2, l
.not-low:
  ld    sysvar-p-flag (), hl
  rst   # $10
  dec   bc
  inc   de
  jp    # .loop
.done:
  pop   af
  ld    sysvar-p-flag (), a
  pop   bc
;code
*)


OPT-EMIT8-ROM-KCUR? [IF]
;; draw input cursor
raw-code: (.CUR)
  push  iy
  restore-iy
  push  hl
  ld    hl, # zx-['pfa] KCUR
  ld    a, (hl)
  bit   0, a
  jr    z, # .done
  bit   7, a
  jr    z, # .cur-c-l
  ;; just an inverted block
  ;; emulate FLASH
  ld    e, a
  ld    a, () sysvar-frames
  xor   e
  and   # $10
  jr    z, # .done
  ld    a, e
  xor   # $10
  ld    (hl), a
@zx-cur-invert:
  ld    hl, () sysvar-df-cc
  ld    b, # 8
.inverse-loop:
  ld    a, (hl)
  cpl
  ld    (hl), a
  inc   h
  djnz  # .inverse-loop
  jr    # .done
.cur-c-l:
  set   4, (hl)
  ;; no scroll prompt
  ld    a, # $FF
  ld    sysvar-scr-ct (), a
  ;; determine cursor char
  ld    a, () sysvar-tv-flag
  \ push  af
  and   # $02
  ld    a, # [char] G
  jr    nz, # .oklow
  ld    a, () sysvar-flags2
  and   # $08
  ld    a, # [char] L
  jr    z, # .oklow
  ld    a, # [char] C
.oklow:
  call  # $18C1   ;; out-flash
  ;; check scroll
  OPT-EMIT8-ROM-SC#? [IF]
  ld    a, () sysvar-scr-ct
  inc   a
  jr    z, # .not-scrolled
  ld    hl, # zx-['pfa] SC#
  inc   (hl)
.not-scrolled:
  [ENDIF]
@zx-word-cur-bs:
  ld    a, # 8
  rst   # $10
@zx-word-cur-done:
.done:
  \ pop   af
  \ ld    sysvar-tv-flag (), a
  pop   hl
  pop   iy
;code


;; erase input cursor
raw-code: (.CUR0)
  push  iy
  restore-iy
  push  hl
  \ ld    a, () sysvar-tv-flag
  \ push  af
  ld    hl, # zx-['pfa] KCUR
  bit   4, (hl)
  jr    z, # zx-word-cur-done
  res   4, (hl)
  bit   7, (hl)
  jr    nz, # zx-cur-invert
.cur-l-c:
  ld    hl, # zx-word-cur-bs
  push  hl
  ld    hl, () sysvar-attr-t
  push  hl
  res   7, h
  res   7, l
  ld    a, # 32
  call  # $18CA   ;; use cursor printing routine
  pop   hl
  pop   iy
;code
[ENDIF]  \ OPT-EMIT8-ROM-KCUR?


;; Returns the ascii value of the character at line n1, column n2 as long as
;; that character is not a user-defined character.
code: SCREEN  ( y x -- char )
  \ pop   hl
  pop   de
  push  iy
  restore-iy
  ld    c, e
  ld    b, l
  call  # $2538
  call  # $2BF1
  ld    a, (de)
  ld    h, # 0
  ld    l, a
  pop   iy
;code


;; this is defined for all drivers, because why not?
code: ATTR  ( y x -- attr )
  (*
  pop   hl
  pop   de
  push  bc
  push  ix
  ld    c, e
  ld    b, l
  call  # $2583
  call  # $1E94
  pop   ix
  pop   bc
  ld    h, # 0
  ld    l, a
  *)
  \ pop   hl
  pop   de
  ;; E=y
  ;; L=x
  ld    a, e    ;; y
  rrca
  rrca
  rrca
  ld    e, a
  and   # $E0
  xor   l       ;; x
  ld    l, a
  ld    a, e    ;; y
  and   # $03
  xor   # $58
  ld    h, a
  ld    l, (hl)
  ld    h, # 0
;code


;; sadly, we cannot set position to line #23 (basic doesn't allow us),
;; so we have to cheat a little.
;; actually, cheat always: set the position at x=0, and adjust the sysvars.
: (AT)  ( y x )
  0MAX 31 MIN SWAP 0MAX
  ;; go to x=0
  22 (ROM-EMIT) DUP 22 MIN (ROM-EMIT) 0 (ROM-EMIT)
  22 > IF 13 (ROM-EMIT) ENDIF ;; for line #23, move down one row
  ;; adjust scr$
  DUP SYS: DF-CC +!
  ;; and X position
  NEGATE SYS: S-POSN-X +! ;

: (AT@)  ( -- y x )  24 SYS: S-POSN-Y C@ -  33 SYS: S-POSN-X C@ - ;


: INK@     ( -- n )  SYS: P-FLAG C@ $10 AND IF 9 EXIT ENDIF SYS: ATTR-P C@ 7 AND ;
: PAPER@   ( -- n )  SYS: P-FLAG C@ $40 AND IF 9 EXIT ENDIF SYS: ATTR-P C@ 8u/ 7 AND ;
: BRIGHT@  ( -- n )  SYS: ATTR-P C@ $40 AND 0<> ;
: FLASH@   ( -- n )  SYS: ATTR-P C@ $7F U> ;
: GOVER@   ( -- flag )  SYS: P-FLAG C@ $03 AND 0<> ;
: INVERSE@ ( -- flag )  SYS: P-FLAG C@ $0C AND 0<> ;

: INK     ( n )  DUP 9 U> IF DROP EXIT ENDIF 16 (ROM-EMIT-ATTR) ;
: PAPER   ( n )  DUP 9 U> IF DROP EXIT ENDIF 17 (ROM-EMIT-ATTR) ;
: FLASH   ( n )  18 (ROM-EMIT-ATTR) ;
: BRIGHT  ( n )  19 (ROM-EMIT-ATTR) ;
: INVERSE ( n )  0<> 0<> 20 (ROM-EMIT-ATTR) ;
: GOVER   ( n )  0<> 0<> 21 (ROM-EMIT-ATTR) ;


OPT-EMIT8-ROM-KEY? [IF]
|: (KEY-NC)  ( -- code )
  [ OPT-EMIT8-ROM-KCUR? ] [IF]
    $EF KCUR AND!C  ;; reset "cursor printed" bit (just in case)
  [ENDIF]
  0 BEGIN DROP
    [ OPT-EMIT8-ROM-KCUR? ] [IF] .CUR [ENDIF]
    INKEY? TR-KEY
  DUP UNTIL KEY-BEEP
  [ OPT-EMIT8-ROM-KCUR? ] [IF] .CUR0 [ENDIF]
;

|: (KEY)  ( -- code )
  0 SYS: LAST-K C!
  0 SYS: TV-FLAG C!
  KEY-NC ;
[ENDIF]


OPT-EMIT8-ROM-AUTOSETUP? [IF]
  ['] (CEMIT) TO EMIT
  \ ['] (ROM-TYPE) TO (TYPE)
  ['] (CLS) TO CLS
  OPT-EMIT8-ROM-KCUR? [IF]
    ['] (.CUR) TO .CUR
    ['] (.CUR0) TO .CUR0
  [ENDIF]
  OPT-EMIT8-ROM-KEY? [IF]
    ['] (KEY-NC) TO KEY-NC
    ['] (KEY) TO KEY
  [ENDIF]
  ['] (AT) TO AT
  ['] (AT@) TO AT@
[ELSE]
: SETUP-EMIT8-ROM-DRIVER
  ['] (CEMIT) TO EMIT
  \ ['] (ROM-TYPE) TO (TYPE)
  ['] (CLS) TO CLS
  [ OPT-EMIT8-ROM-KCUR? ] [IF]
    ['] (.CUR) TO .CUR
    ['] (.CUR0) TO .CUR0
  [ENDIF]
  [ OPT-EMIT8-ROM-KEY? ] [IF]
    ['] (KEY-NC) TO KEY-NC
    ['] (KEY) TO KEY
  [ENDIF]
  ['] (AT) TO AT
  ['] (AT@) TO AT@
;
[ENDIF]

zxlib-end
