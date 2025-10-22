;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; fast 8x8 char printer with custom window coords
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; use "distorted" font in char printer?
;; it is slightly ugly, but takes less RAM than the full font.
;; if not set, will use CHARS sysvar.
true zx-lib-option OPT-WIN8-DISTORT-FONT?

;; set to `true` if you want to include vertical pixel-precise printing code
false zx-lib-option OPT-WIN8-YPIXEL?

;; automatically setup the driver?
true zx-lib-option OPT-WIN8-AUTOSETUP?

;; set "OBL?" variable?
false zx-lib-option OPT-WIN8-OBL?

;; set "OUT#" variable?
false zx-lib-option OPT-WIN8-OUT#?

;; install cursor on/off words?
false zx-lib-option OPT-WIN8-KCUR?

;; install "KEY" handler?
false zx-lib-option OPT-WIN8-KEY?


$zx-use <gfx/scradr>

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw text chars
zxlib-begin" win8-base library"

32 constant #COLS

0o070 quan E8-ATTR
0 quan E8-XY  ;; high byte:Y; low byte:X; absolute position
OPT-WIN8-YPIXEL? [IF]
;; so we could print with pixel precision by Y.
;; note that attrs will not be set in this case.
0 quan E8-YOFS
[ENDIF]  \ OPT-WIN8-YPIXEL?

;; window; high byte:Y; low byte:X
;; note that "E8WIN-XY1" is *OUT* of the window!
$0000 quan E8WIN-XY0
$1820 quan E8WIN-XY1


code: (E8)  ( char )
zx-word-win8-e8-emit:
  ;; call screen address
  ld    c, l  ;; char code

  ld    hl, () zx-['pfa] E8-XY
  ld    a, h
  and   # $18
  or    # $40
  ld    d, a
  ld    a, h
  rrca
  rrca
  rrca
  and   # $E0
  or    l
  ld    e, a

  ld    l, c

  xor   a         ;; normal output
  bit   7, l
  jr    z, # .not-inv
  ld    a, # $2F  ;; CPL
.not-inv:
  ld    .inv-mode-instr (), a
  ;; normalize char
  ld    a, l
  and   # $7F
  cp    # 32
  jr    nc, # .char-ok
  cp    # 4
  jr    c, # .special-chars
  ld    a, # 63
.char-ok:

  ;; DE: scr$
  ;;  A: char code
  OPT-WIN8-OBL? [IF]
  ld    hl, # zx-['pfa] OBL?
  ld    (hl), # 0
  cp    # 32
  jr    nz, # .obl-not-bl
  inc   (hl)
.obl-not-bl:
  [ENDIF]

  ;; DE: scr$
  ;;  A: char code
  OPT-WIN8-DISTORT-FONT? [IF]
  ld    l, a       ;; first part of ROM char address calculation
  cp    # 52
  jr    z, # .distortNot
  cp    # 96
  ld    a, # 7
  jr    c, # .distortOk
.distortNot:
  ld    a, # $ff
.distortOk:
  ld    e6-distort-and-oper (), a
  add   hl, hl    ;; *2
  ld    h, # 15
  add   hl, hl    ;; *4
  add   hl, hl    ;; *8
  [ELSE]
  ld    h, # 0
  add   hl, hl    ;; *2
  add   hl, hl    ;; *4
  add   hl, hl    ;; *8
  ld    bc, () sysvar-chars
  add   hl, bc
  [ENDIF]
  ;; DE: scr$
  ;; HL: char-addr
.char-addr-hl-done:
  ex    de, hl
  ;; HL: scr$
  ;; DE: char-addr

  ld    b, # 8

  zx-has-word? E8-YOFS [IF]
  ld    a, () zx-['pfa] E8-YOFS
  and   # $07
  jr    nz, # .pixel-print
  [ENDIF]

.line-loop:
  OPT-WIN8-DISTORT-FONT? [IF]
  call  # .load-char-byte
  [ELSE]
  ld    a, (de)
  inc   de
.inv-mode-instr:
  nop             ;; or CPL ($2F)
  [ENDIF]
  ld    (hl), a
  inc   h
  djnz  # .line-loop

.set-attrs:
  ;; set attr
  ld    a, h
  dec   a
  or    # $87
  rra
  rra
  srl   a     ;; rra for #C000 screen
  ld    h, a

  ld    a, () zx-['pfa] E8-ATTR
  cp    # $FF
  jr    z, # .skip-attr
  ld    (hl), a
.skip-attr:

  pop   hl
  next

  OPT-WIN8-DISTORT-FONT? [IF]
.load-char-byte:
  ld    a, (de)
  inc   de
  ld    c, a
  and   # $7C
  rlca
  or    c
  ;; distort a little
  ld    c, a
  ld    a, b
  cp    # 3
  ld    a, c
  jr    nz, # .dontfuck
  and   # $07
$here 1- @def: e6-distort-and-oper
.dontfuck:
.inv-mode-instr:
  nop             ;; or CPL ($2F)
  ret
  [ENDIF]

  OPT-WIN8-YPIXEL? [IF]
  ;; HL: scr$
  ;; DE: char-addr
.pixel-print:
  add   a, h
  ld    h, a
  jr    # .pixel-print-no-down
.pixel-print-loop:
  inc   h
  ld    a, h
  and   # $07
  jr    nz, # .pixel-print-no-down
  ld    a, l
  sub   # -32
  ld    l, a
  sbc   a, a
  and   # -8
  add   a, h
  ld    h, a
.pixel-print-no-down:
  call  # .load-char-byte
  ld    (hl), a
  djnz  # .pixel-print-loop
  jr    # .skip-attr
  [ENDIF]

  ;;FIXME: implement proper vertical per-pixel printing!
  ;; 0: up arrow
  ;; 1: down arrow
  ;; 2: left arrow
  ;; 3: right arrow
.special-chars:
  ;; DE: scr$
  ;;  A: char code
  add   a, a    ;; *2
  add   a, a    ;; *4
  add   a, a    ;; *8
  ld    hl, # .special-chars-data
  ld    c, a
  ld    b, # 0
  add   hl, bc
  ex    de, hl

  ld    a, () .inv-mode-instr
  ld    .inv-mode-instr-spec (), a
  ld    b, # 8
.line-loop-spec:
  ld    a, (de)
.inv-mode-instr-spec:
  nop             ;; or CPL ($2F)
  ld    (hl), a
  inc   de
  inc   h
  djnz  # .line-loop-spec
  jr    # .set-attrs

.special-chars-data:
;; up arrow
%00000000 db,
%00011000 db,
%00111100 db,
%01111110 db,
%01011010 db,
%00011000 db,
%00011000 db,
%00000000 db,
;; down arrow
%00000000 db,
%00011000 db,
%00011000 db,
%01011010 db,
%01111110 db,
%00111100 db,
%00011000 db,
%00000000 db,
;; left arrow
%00000000 db,
%00011000 db,
%00110000 db,
%01111110 db,
%01111110 db,
%00110000 db,
%00011000 db,
%00000000 db,
;; right arrow
%00000000 db,
%00011000 db,
%00001100 db,
%01111110 db,
%01111110 db,
%00001100 db,
%00011000 db,
%00000000 db,
;code-no-next


raw-code: (E8-ADV)
zx-word-win8-e8-adv:
  exx
  OPT-WIN8-OUT#? [IF]
  ld    hl, () zx-['pfa] OUT#
  inc   hl
  ld    zx-['pfa] OUT# (), hl
  [ENDIF]

  ld    hl, () zx-['pfa] E8-XY
  ld    de, () zx-['pfa] E8WIN-XY1
  ;; L=x
  ;; H=y
  inc   l
  ld    a, l
  cp    e
  jr    c, # .no-x-wrap
  ld    a, () zx-['pfa] E8WIN-XY0
  ld    l, a
  inc   h
  ld    a, h
  cp    d
  jr    c, # .no-y-wrap
  ld    a, () zx-['pfa] E8WIN-XY0 1+
  ld    h, a
.no-y-wrap:
.no-x-wrap:
  ld    zx-['pfa] E8-XY (), hl
  exx
;code

raw-code: (E8-EMIT-ADV)  ( char )
  ld    ix, # .goon
  jp    # zx-word-win8-e8-emit
.goon:
  ;; HL: return address
  ex    (sp), hl
  jr    # zx-word-win8-e8-adv
;code-no-next


\ : XY/WH-SPLIT  ( xy/wh -- x/w y/h )  dup lo-byte swap hi-byte ;
\ : XY/WH-JOIN   ( xy/wh -- x/y-w/h )  256* + ;
alias-for SPLIT-BYTES is XY/WH-SPLIT
alias-for JOIN-BYTES is XY/WH-JOIN


\ : WEMIT  ( ch )  (e8) (e8-adv) ; zx-inline
: WEMIT  ( ch )  (e8-emit-adv) ; zx-inline
: WTYPE  ( addr count )  for c@++ wemit endfor drop ;

: WIN-X0  ( -- x0 )  E8WIN-XY0 lo-byte ; zx-inline
: WIN-Y0  ( -- y0 )  E8WIN-XY0 hi-byte ; zx-inline
: WIN-XY0  ( -- x0 y0 )  win-x0 win-y0 ; zx-inline
;; no checks!
: WIN-XY0!  ( x0 y0 )  xy/wh-join E8WIN-XY0:! ; zx-inline
: WIN-X0!  ( x0 )  win-y0 win-xy0! ; zx-inline
: WIN-Y0!  ( y0 )  win-x0 swap win-xy0! ; zx-inline

;; note that this is *after* the last col/row
: WIN-X1  ( -- x1 )  E8WIN-XY1 lo-byte ; zx-inline
: WIN-Y1  ( -- y1 )  E8WIN-XY1 hi-byte ; zx-inline
: WIN-XY1  ( -- x1 y1 )  win-x1 win-y1 ; zx-inline
;; no checks!
: WIN-XY1!  ( x1 y1 )  xy/wh-join E8WIN-XY1:! ; zx-inline
: WIN-X1!  ( x1 )  win-y1 win-xy1! ; zx-inline
: WIN-Y1!  ( y1 )  win-x1 swap win-xy1! ; zx-inline

: WIN-W  ( -- width )  win-x1 win-x0 - ; zx-inline
: WIN-H  ( -- height)  win-y1 win-y0 - ; zx-inline

;; set fullscreen window, reset print position
: FS-WIN
  0 to e8win-xy0 $1820 to e8win-xy1
  0 to e8-xy [ zx-has-word? e8-yofs ] [IF] 0 to e8-yofs [ENDIF] ;


;; FIXME: too lazy to check args
: MK-WINDOW  ( x y w h )
  \ (normalize-win-coords)
  2over ( x y w h x y )
  rot + 256* nrot + + to e8win-xy1
  ( 256* +) join-bytes dup to e8win-xy0 to e8-xy
  [ zx-has-word? e8-yofs ] [IF] 0 to e8-yofs [ENDIF] ;


;; fill current window with the current attr
: ATTR-FILL-WINDOW
  win-w >r  win-xy0 cxy>attr  win-h
  cfor dup ( cfor:) r1:@ e8-attr cfill 32+ endfor
  drop rdrop ;

;; clear current window, don't set attr
: CLEAR-WINDOW
  win-w win-xy0 cxy>scr$
  win-h cfor ( w scr$ )
    8 cfor 2dup swap cerase 256+ endfor
    256- cscr$v
  endfor
  2drop ;


|: (FR-HLINE-LR)  ( scr$ width fill-byte lbyte rbyte )
  >r >r >r
  2dup r> cfill
  ( left byte) over r> swap c!
  ( right byte) + 1- r> swap c! ;

;; clear current window, draw frame, don't set attr
: FRAME-WINDOW
  win-w >r  win-xy0 cxy>scr$
  dup r@ cerase 256+
  dup r@ $FF $7F $FE (fr-hline-lr) 256+
  dup r@ $00 $70 $0E (fr-hline-lr) 256+
  dup r@ $FF $7F $FE (fr-hline-lr) 256+
  dup r@ $00 $58 $1A (fr-hline-lr) 256+
  win-h 1- 8* 2- cfor dup ( cfor:) r1:@ $00 $50 $0A (fr-hline-lr) scr$v endfor
  dup r@ $00 $58 $1A (fr-hline-lr) 256+
  dup r@ $FF $7F $FE (fr-hline-lr) 256+
  dup r@ $00 $70 $0E (fr-hline-lr) 256+
  dup r@ $FF $7F $FE (fr-hline-lr) 256+
  r> cerase ;


;; shrink current window, so output will not corrupt the frame.
;; also, reset otput position to (0, 0).
;; FIXME: too lazy to check args.
: SHRINK-WINDOW
  $0101 +to e8win-xy0
  $0101 -to e8win-xy1
  e8win-xy0 to e8-xy ;

: UNSHRINK-WINDOW
  $0101 -to e8win-xy0
  $0101 +to e8win-xy1 ;


;; absolute screen position
: E8-ATX@  ( -- x ) e8-xy lo-byte ; zx-inline
: E8-ATY@  ( -- y ) e8-xy hi-byte ; zx-inline


: WIN-AT  ( y x )
  win-w 1- min 0max win-x0 +
  swap win-h 1- min 0max win-y0 +
  ( 256* +) join-bytes to e8-xy ;

: WIN-AT@  ( -- y x )
  e8-xy xy/wh-split  ( x y )
  win-y0 +  swap win-x0 + ;


: WCR      win-x1 E8-XY:c! (e8-adv) ; zx-inline
: WENDCR   e8-atx@ win-x0 - ?< wcr >? ; zx-inline
: WLSTART  win-x0 E8-XY:c! ; zx-inline

: WBACK
  e8-atx@ dup ?exit< 1- e8-xy:c! >? drop
  e8-aty@ dup ?< 1- win-x1 1- || 0 >?
  swap 256* to e8-xy ;

: WDEMIT  ( char )
  [ 0 ] [IF]
    dup z:emit z:flush
  [ENDIF]
  dup $1F ~and ?exit< wemit >?
  lo-byte
  << 4 of?v| wendcr |?
     7 of?v| wlstart |?
     8 of?v| wback |?
    13 of?v| wcr |?
  else| wemit >> ;

\ |: (WCLS)   e8-attr sys: ATTR-P c! (CLS) e8win-xy0 e8-xy:! ;
raw-code: (WCLS)
  exx
  ;; fix attrs
  \ ld    hl, () sysvar-attr-p
  \ ld    sysvar-attr-t (), hl
  ;; reset "cursor printed" bit
  OPT-WIN8-KCUR? [IF]
  ld    hl, # zx-['pfa] KCUR
  res   4, (hl)
  [ENDIF]
  ;; clear scr$
  ld    hl, # $4000
  ld    de, # $4001
  ld    bc, # 6144
  ld    (hl), l
  ldir
  ;; set attr$
  ld    bc, # 767
  \ ld    a, () sysvar-attr-p
  ld    a, () zx-['pfa] E8-ATTR
  ld    (hl), a
  ldir
  ;; fix print position
  ld    hl, () zx-['pfa] e8win-xy0
  ld    zx-['pfa] e8-xy (), hl
  ;; done
  exx
;code


OPT-WIN8-KCUR? [IF]
|: (.WCUR)  KCUR c@ 1 and not?exit [char] _ (e8) ;
|: (.WCUR0) KCUR c@ 1 and not?exit bl (e8) ;
[ENDIF]  \ OPT-WIN8-KCUR?


OPT-WIN8-KEY? [IF]
|: (WKEY-NC)  ( -- code )
  [ OPT-WIN8-KCUR? ] [IF]
    $EF KCUR AND!C  ;; reset "cursor printed" bit (just in case)
  [ENDIF]
  0 BEGIN DROP
    [ OPT-WIN8-KCUR? ] [IF] .CUR [ENDIF]
    INKEY? TR-KEY
  DUP UNTIL KEY-BEEP
  [ OPT-WIN8-KCUR? ] [IF] .CUR0 [ENDIF]
;

|: (WKEY)  ( -- code )
  0 SYS: LAST-K C!
  \ 0 SYS: TV-FLAG C!
  KEY-NC ;
[ENDIF]


OPT-WIN8-AUTOSETUP? [IF]
  ['] WDEMIT TO EMIT
  ['] (WCLS) TO CLS
  OPT-WIN8-KCUR? [IF]
    ['] (.WCUR) TO .CUR
    ['] (.WCUR0) TO .CUR0
  [ENDIF]
  OPT-WIN8-KEY? [IF]
    ['] (WKEY-NC) TO KEY-NC
    ['] (WKEY) TO KEY
  [ENDIF]
  ['] WIN-AT TO AT
  ['] WIN-AT@ TO AT@
[ELSE]
: SETUP-E8-DRIVER
  ['] WDEMIT TO EMIT
  ['] (WCLS) TO CLS
  [ OPT-WIN8-KCUR? ] [IF]
    ['] (.WCUR) TO .CUR
    ['] (.WCUR0) TO .CUR0
  [ENDIF]
  [ OPT-WIN8-KEY? ] [IF]
    ['] (WKEY-NC) TO KEY-NC
    ['] (WKEY) TO KEY
  [ENDIF]
  ['] WIN-AT TO AT
  ['] WIN-AT@ TO AT@ ;
[ENDIF]

;; debug word
: ED-DEPTH0-ERROR
  DI
  sys: depth >r sys: sp0!
  fs-win @127 e8-attr:! 1 0 at ." INVALID DEPTH: " r> . cr
  (DIHALT) ;

: ?ED-DEPTH0 sys: depth ?< ed-depth0-error >? ; zx-inline


;; do not change attributes on printing
: E8-NO-ATTR!  255 e8-attr:! ; zx-inline
: E8-NO-ATTR?  e8-attr:c@ 255 = ; zx-inline

: E8-INK?     ( -- value )  e8-attr:@ 7 and ; zx-inline
: E8-PAPER?   ( -- value )  e8-attr:@ 8u/ 7 and ; zx-inline
: E8-BRIGHT?  ( -- value )  e8-attr:@ $40 mask8? ; zx-inline
: E8-FLASH?   ( -- value )  e8-attr:@ $80 mask8? ; zx-inline

|: (E8-XATTR!)  ( value mask )  e8-attr swap ~and8 or8 e8-attr:c! ; zx-inline

: E8-INK!     ( value )  7 and 7 (e8-xattr!) ; zx-inline
: E8-PAPER!   ( value )  7 and 8* 0o070 (e8-xattr!) ; zx-inline
: E8-BRIGHT!  ( value )  0<> ?< $40 || 0 >? $40 (e8-xattr!) ; zx-inline
: E8-FLASH!   ( value )  0<> ?< $80 || 0 >? $80 (e8-xattr!) ; zx-inline

: E8-ATTR!    ( value )  e8-attr:c! ; zx-inline

zxlib-end
