;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16x16 XOR sprites, no runtime shifting
;; test code, directly included from "zx-80-libs-30-spr16.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

endcr ." compiling SPR16 demo app..." cr

$zx-use <emit8-rom>
\ $zx-use <emit6>
\ $zx-use <emit4>

$zx-use <stick-scan>
$zx-use <gfx/scradr>

$zx-use <sfx-joffa>
\ $zx-use <sfx-turner>
$zx-use <spr16>


true constant DEPTH-CHECK?

zxlib-begin" application"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprites

" sprite-data.f" spr16-include-sprites
\ spr16-finish-include  ;; this is to rewind the data in pass1
" SPR16 sprites" spr16-finish-include-msg ;; the same, but with size message


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test tile printer

0 quan TILE-BASE

code: PR-TILE  ( x y idx )
  \ pop   hl      ;; tile index
  ld    e, l
  add   hl, hl  ;; *2
  add   hl, hl  ;; *4
  add   hl, hl  ;; *8
  ld    d, # 0
  add   hl, de  ;; *9

  ld    de, () zx-['pfa] TILE-BASE
  add   hl, de

  pop   de      ;; y
  ld    a, d
  or    a
  jr    nz, # .bad-coord
  ld    a, e
  cp    # 24
  jr    nc, # .bad-coord
  pop   de
  push  hl
  ld    l, a    ;; L=y
  ld    a, d
  or    a
  jr    nz, # .bad-coord
  ld    a, e
  cp    # 32
  jr    nc, # .bad-coord

  ;; calculate scr$ address
  ld    a, l
  and   # $18
  or    # $40
  ld    h, a
  ld    a, l
  rrca
  rrca
  rrca
  and   # $E0
  or    e
  ld    l, a
  ;; HL=scr$

  pop   de

  ;; blit
  ld a, (de)  inc de  ld (hl), a  inc h   ;; 0
  ld a, (de)  inc de  ld (hl), a  inc h   ;; 1
  ld a, (de)  inc de  ld (hl), a  inc h   ;; 2
  ld a, (de)  inc de  ld (hl), a  inc h   ;; 3
  ld a, (de)  inc de  ld (hl), a  inc h   ;; 4
  ld a, (de)  inc de  ld (hl), a  inc h   ;; 5
  ld a, (de)  inc de  ld (hl), a  inc h   ;; 6
  ld a, (de)  inc de  ld (hl), a          ;; 7

  ;; move to attrs
  ld    a, h
  or    # $87
  rra
  rra
  srl   a     ;; rra for #C000 screen
  ld    h, a

  ld    a, (de)
  ld    (hl), a
.exit:
  pop   hl
  next

.bad-coord:
  pop   de
  jr    # .exit
;code-no-next


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tiles

\ zx-here
$8000 $1000 - tloader-zx-addr:!
tloader-zx-addr TO TILE-BASE
COMPILING-FOR-REAL? [IF]
push-ctx voc-ctx: tile8-loader
" tile-data.f" false (include)
pop-ctx
\ zx-here
tloader-zx-addr tloader-zx-addr-start -
endcr ." SPR16 tiles size: " .bytes ."  (" tloader-#tiles . ." tiles).\n"
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test code


: MARK-THIRDS
  0 0 CXY>ATTR
  8 FOR DUP 32 @070 CFILL-NC 32 + ENDFOR
  8 FOR DUP 32 @060 CFILL-NC 32 + ENDFOR
  8 FOR DUP 32 @050 CFILL-NC 32 + ENDFOR
  DROP ;


: EMPTY-CHAR?  ( x y -- flag )
  CXY>SCR$ 8 FOR  ( addr )
    DUP C@ ?exit< UNLOOP DROP false >?
  256 + ENDFOR DROP true ;

: FILL-PROP-MAP
  TPROP-MAP 32 24 * ERASE-NC
  24 FOR
    32 FOR
      I J EMPTY-CHAR? not?<
        $80 J 1 AND 0?< $40 OR >?  J 32* I + TPROP-MAP + C!
        $40 I J CXY>ATTR XOR!C
      >?
    ENDFOR
  ENDFOR ;


;; test several sprites
create SPI
  ( x)  0 c, ( y)  17 c, ( phase) 0 c, ( dummy) 0 c,
  ( x)  4 c, ( y)  98 c, ( phase) 1 c, ( dummy) 0 c,
  ( x) 12 c, ( y)  42 c, ( phase) 2 c, ( dummy) 0 c,
  ( x) 16 c, ( y)  21 c, ( phase) 3 c, ( dummy) 0 c,

  ( x)  3 c, ( y)  19 c, ( phase) 0 c, ( dummy) 0 c,
  ( x)  7 c, ( y)  98 c, ( phase) 1 c, ( dummy) 0 c,
  ( x) 15 c, ( y)  42 c, ( phase) 2 c, ( dummy) 0 c,
  ( x) 19 c, ( y)  32 c, ( phase) 3 c, ( dummy) 0 c,

  ( x)  0 c, ( y)  41 c, ( phase) 0 c, ( dummy) 0 c,
  ( x)  4 c, ( y) 118 c, ( phase) 1 c, ( dummy) 0 c,
  ( x) 12 c, ( y)  82 c, ( phase) 2 c, ( dummy) 0 c,
  ( x) 16 c, ( y)  92 c, ( phase) 3 c, ( dummy) 0 c,

  ( x)  3 c, ( y)  51 c, ( phase) 0 c, ( dummy) 0 c,
  ( x)  7 c, ( y)  48 c, ( phase) 1 c, ( dummy) 0 c,
  ( x) 15 c, ( y)  92 c, ( phase) 2 c, ( dummy) 0 c,
  ( x) 19 c, ( y)  62 c, ( phase) 3 c, ( dummy) 0 c,

  ( x) 23 c, ( y) 162 c, ( phase) 2 c, ( dummy) 0 c,
create;

: xz-move  ( spi^ )
  >R  ( | spi^ )
  ;; phase
  R@ 2+ C@ 1+ 3 AND DUP R@ 2+ C!
  ( phase | spi^ )
  0IF ;; x
    R@ C@ 1+ DUP 29 > IF DROP 0 ENDIF R@ C! ;; x
  ENDIF
  ( | spi^ )
  R@ 1+ C@ 1+ DUP 191 > IF DROP 15 ENDIF R@ 1+ C! ;; y
  RDROP ;

: xz-update  ( spi^ sidx )
  >R C@++ SWAP C@++ SWAP C@ 4* ( x y phase | sidx )
  R@ 6 > IF SPR-SOLDIER-WALK ELSE SPR-SKULL ENDIF +
  R> SPR-UPDATE ;

: xz
  1 BORDER
  SPR-INIT
  CLS CR CR CR
  MARK-THIRDS
  BEGIN
    spi 0 xz-update
    spi 4 + 1 xz-update
    HALT HALT
    HALT HALT
    SPR-IM2-HANDLER
    spi xz-move
    spi 4 + xz-move
  TERMINAL? UNTIL ;

;; we can update about 5 sprites per frame
17 constant #XI
true constant xi-player?
true quan xi-moving

1 quan pl-x
3 quan pl-p
75 quan pl-y
true quan pl-left?

;; call to this will be automatically removed when the word is empty
: .pl
  [ 0 ] [IF]
  0 0 AT ." L: PL-P=" PL-P . ." X=" PL-X .
  [ENDIF] ;

: pl-update
  pl-x pl-y
  \ pl-left? IF LREX ELSE RREX ENDIF
  pl-p pl-left? 4* +  4* SPR-REX-WALK +
  #XI SPR-UPDATE ;

: pl-turn
  pl-left? 1 XOR TO pl-left?
  \ 3 pl-p - TO pl-p
; zx-inline

: pl-left
  pl-left? 0IF pl-turn EXIT ENDIF
  pl-p 1- 3 AND DUP TO pl-p 3 - ?EXIT
  pl-x 1- ( 0MAX) TO pl-x ; zx-inline

: pl-right
  pl-left? IF pl-turn EXIT ENDIF
  pl-p 1+ 3 AND DUP TO pl-p ?EXIT
  pl-x 1+ ( 29 MIN) TO pl-x ; zx-inline

: pl-up
  pl-y 2- 15 MAX TO pl-y ; zx-inline

: pl-down
  pl-y 2+ 191 MIN TO pl-y ; zx-inline

1 quan sfx-next
0 quan fire-down

: do-sfx
  fire-down ?EXIT
  JSFX-PLAYING? IF 5 254 OUTP EXIT ENDIF
  sfx-next DUP JSFX-START
  1+ 15 AND DUP 0= + sfx-next:!
  TRUE fire-down:! ;

: player-control
  STICK@
  DUP STICK-LEFT? IF pl-left .pl ( pl-update)
  ELSE DUP STICK-RIGHT? IF pl-right .pl ( pl-update) ENDIF ENDIF
  DUP STICK-UP? IF pl-up
  ELSE DUP STICK-DOWN? IF pl-down ENDIF ENDIF
  STICK-FIRE? IF do-sfx ELSE 0 fire-down:! ENDIF ;

DEPTH-CHECK? [IF]
0 quan (depth)

: SAVE-DEPTH  sys: depth (depth):! ; zx-inline
: (DEPTH-ERROR)  0 0 at ." STACK IMBALANCE!" (dihalt) ;
: ?DEPTH sys: depth (depth) = not?< (depth-error) >? ; zx-inline

[ELSE]
: SAVE-DEPTH ; zx-inline
: ?DEPTH ; zx-inline
[ENDIF]

1 quan border-color

;; with interrupts
: xi
  [ 0 ] [IF]
  4 -3 DO
    I 0.R ." : "
    I -?< ." [-?] " >?
    I -0?< ." [-0?] " >?
    I +?< ." [+?] " >?
    I +0?< ." [+0?] " >?
    CR
  LOOP
  sys: depth ." depth: " . cr
  (DIHALT)
  [ENDIF]

  \ 0 0= ?< ." BOO!" >?

  1 BORDER
  DETECT-KJOY IF
    ." kempston detected" cr
    STICK-KJOY!
  ELSE
    ." no kempston!" cr
  ENDIF
  INIT-JSFX
  SPR-SETUP
  \ CLS CR CR CR
  ." \cXS16 Engine demo.\n"
  ." \cCS/SS to control the animation.\nuse kempston to move.\n"
  #XI . ." sprites, and the player."
  [ xi-player? ] [IFNOT] CLS [ENDIF]
  MARK-THIRDS
  FILL-PROP-MAP
  SPR-ON
  0 SYS: LAST-K C!
  .pl
  \ pl-update
  BEGIN
    \ border-color dup 254 outp 2 xor border-color:!
    \ sys: frames off
    [ xi-player? ] [IF] player-control pl-update [ENDIF]
    #XI FOR I 4* SPI + I xz-update ENDFOR
    [ xi-player? ] [IFNOT]
      HALT HALT
      HALT HALT
    [ENDIF]
    \ halt
    SAVE-DEPTH
    xi-moving IF
      \ SAVE-DEPTH
      SPI DUP #XI 4* + SWAP DO
        I xz-move
      4 +LOOP
      \ ?DEPTH
    ENDIF
    ?DEPTH
    CS/SS? DUP IF DUP 1 AND TO xi-moving ENDIF DROP
    \ sys: frames @ ( Z:.BENCH-TIME) z:.u# z:cr
    JSFX-PLAY
  TERMINAL? UNTIL
  #XI 1+ FOR I SPR-ERASE ENDFOR
  HALT HALT HALT HALT
  \ SPR-OFF
  SPR-UNSETUP
  0 0 at ." ***DONE!***" (DIHALT)
;

\ $include "spr-save.f"

zxlib-end
