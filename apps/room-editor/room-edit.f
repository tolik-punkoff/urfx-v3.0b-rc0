;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Z80 Abersoft fig-FORTH recompiled
;; Copyright (C) 2024 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16x16 XOR sprites, no runtime shifting
;; room (and tile) editor
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


false constant USE-ASM-WHOLE-ROOM-DRAW?
true constant USE-ASM-DRAW-TILE?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; editor

;; 16 tile types are allowed. kept in the low nibble.

;; if set, attribute of this tile will override sprite attribute
$80 constant PMASK-A-FROZEN
;; if set, it is not allowed to print any sprites over this tile
$40 constant PMASK-S-FROZEN
;; if set, tile type is "frozen"
$20 constant PMASK-T-FROZEN
;; if set, tile attr is overriden
$10 constant PMASK-U-ATTR

;; current tile map (the one we are editing).
;; WARNING! should always come in this order!
$6000 constant PROP-MAP   ;; 768 bytes
$6300 constant TILE-MAP   ;; 768 bytes
$6600 constant ATTR-MAP   ;; 768 bytes

;; tile definitions.
;; first, gfx for 256 tiles (2048 bytes).
;; second, attributes for each tile (256 bytes).
;; third, property flags for each tile (256 bytes).
;; WARNING! should always come in this order!
$6900 constant TILE-GFX
$7100 constant TILE-ATTR
$7200 constant TILE-PROP

;; buffer with the current room.
;; the layout is:
;;   768 bytes of prop map
;;   768 bytes of tile map
;;   768 bytes of attr map
768 3 * constant BYTES/ROOM


: DOS-ERROR-CB
  [ 0 ] [IF]
  DOS-LAST-ERR .
  [ENDIF]
  11 10 11 3 mk-window
  arrow-hide
  0o127 to e8-attr attr-fill-window frame-window shrink-window
  0o126 to e8-attr
  ." DOS ERROR"
  [ENDIF]
  (dihalt) ;

['] DOS-ERROR-CB to DOS-ERROR


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw whole room (32x22)
USE-ASM-WHOLE-ROOM-DRAW? [IF]
raw-code: DRAW-WHOLE-ROOM
  push  hl
  ;; top 1/3
  ld    de, # $4000
  exx
  ld    hl, # TILE-MAP
  call  # .draw-one-third
  ;; mid 1/3
  exx
  ld    de, # $4000 2048 +
  exx
  call  # .draw-one-third
  ;; bottom 1/3
  exx
  ld    de, # $4000 2048 2* +
  exx
  ld    b, # 192
  call  # .loop-third

  ;; now attributes
 0 [IF]
  ;; from tiles
  ld    de, # $4000 6144 +
  exx
  ld    c, # 22
  ld    hl, # TILE-MAP

.loop-attr:
  ld    b, # 32
.loop-attr-line:
  ld    a, (hl)
  inc   hl
  exx
  ld    l, a
  ld    h, # 0
  ld    bc, # TILE-ATTR
  add   hl, bc
  ld    a, (hl)
  cp    # $FF
  jr    z, # .skip-attr
  ld    (de), a
.skip-attr:
  inc   de
  exx
  djnz  # .loop-attr-line
  dec   c
  jr    nz, # .loop-attr
 [ELSE]
  ;; from room attr plane
  ld    hl, # ATTR-MAP
  ld    de, # $4000 6144 +
  ld    c, # 22
.loop-attr:
  ld    b, # 32
.loop-attr-line:
  ld    a, (hl)
  cp    # $FF
  jr    z, # .skip-attr
  ld    (de), a
.skip-attr:
  inc   hl
  inc   de
  djnz  # .loop-attr-line
  dec   c
  jr    nz, # .loop-attr
 [ENDIF]

  pop   hl
  ret

.draw-one-third:
  ld    b, # 0
.loop-third:
  ld    a, (hl)
  inc   hl
  exx
  ld    l, a
  ld    h, # 0
  add   hl, hl    ;; *2
  add   hl, hl    ;; *4
  add   hl, hl    ;; *8
  ld    bc, # TILE-GFX
  add   hl, bc
  ;; blit
  ld    c, d
  ld a, (hl)  inc l  ld (de), a  inc d   ;; 0
  ld a, (hl)  inc l  ld (de), a  inc d   ;; 1
  ld a, (hl)  inc l  ld (de), a  inc d   ;; 2
  ld a, (hl)  inc l  ld (de), a  inc d   ;; 3
  ld a, (hl)  inc l  ld (de), a  inc d   ;; 4
  ld a, (hl)  inc l  ld (de), a  inc d   ;; 5
  ld a, (hl)  inc l  ld (de), a  inc d   ;; 6
  ld a, (hl)         ld (de), a          ;; 7
  ld    d, c
  inc   e
  exx
  djnz  # .loop-third
  ret
;code-no-next
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw one tile

USE-ASM-DRAW-TILE? [IF]
code: (DRAW-TILE)  ( x y attr idx )
  \ pop   hl      ;; tile index
  ld    e, l
  add   hl, hl    ;; *2
  add   hl, hl    ;; *4
  add   hl, hl    ;; *8
  \ ld    d, # 0
  \ add   hl, de    ;; *9

  ld    de, # TILE-GFX
  add   hl, de

  pop   de
  ld    a, e
  ex    af, afx   ;; attr

  pop   de        ;; y
  ld    a, d
  or    a
  jr    nz, # .bad-coord
  ld    a, e
  cp    # 24
  jr    nc, # .bad-coord
  pop   de        ;; x
  push  hl        ;; save tile address
  ld    l, a      ;; L=y
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

  pop   de      ;; tile address

  ;; blit
  ld a, (de)  inc e  ld (hl), a  inc h   ;; 0
  ld a, (de)  inc e  ld (hl), a  inc h   ;; 1
  ld a, (de)  inc e  ld (hl), a  inc h   ;; 2
  ld a, (de)  inc e  ld (hl), a  inc h   ;; 3
  ld a, (de)  inc e  ld (hl), a  inc h   ;; 4
  ld a, (de)  inc e  ld (hl), a  inc h   ;; 5
  ld a, (de)  inc e  ld (hl), a  inc h   ;; 6
  ld a, (de)         ld (hl), a          ;; 7

  ;; move to attrs
  ld    a, h
  or    # $87
  rra
  rra
  srl   a     ;; rra for #C000 screen
  ld    h, a

  ex    af, afx   ;; attrs
  cp    # $FF
  jr    z, # .exit
  ld    (hl), a
.exit:
  pop   hl
  next

.bad-coord:
  pop   de    ;; x
  jr    # .exit
;code-no-next

[ELSE]
: (DRAW-TILE)  ( x y attr idx )
  ;; set attribute
  swap 2over cxy>attr c!
  8* TILE-GFX +
  nrot cxy>scr$
  ( gfx^ scr$ )
  [ 0 ] [IF]
  8 cfor
    over c@ over c!
    under+1 256+
  endfor
  2drop
  [ELSE]
  ;; one byte
  over c@ over c!
  under+1 256+
  ;; one byte
  over c@ over c!
  under+1 256+
  ;; one byte
  over c@ over c!
  under+1 256+
  ;; one byte
  over c@ over c!
  under+1 256+
  ;; one byte
  over c@ over c!
  under+1 256+
  ;; one byte
  over c@ over c!
  under+1 256+
  ;; one byte
  over c@ over c!
  under+1 256+
  ;; one byte
  swap c@ swap c!
  [ENDIF]
;
[ENDIF]


: tile-attr@  ( idx -- byte )  tile-attr + c@ ; zx-inline
: tile-map@   ( idx -- byte )  tile-map + c@ ; zx-inline
: tile-prop@  ( idx -- byte )  tile-prop + c@ ; zx-inline

: tile-attr!  ( value idx )  tile-attr + c! ; zx-inline
: tile-map!   ( value idx )  tile-map + c! ; zx-inline
: tile-prop!  ( value idx )  tile-prop + c! ; zx-inline

: prop-map@  ( idx -- byte )  prop-map + c@ ; zx-inline
: attr-map@  ( idx -- byte )  attr-map + c@ ; zx-inline

: prop-map!  ( value idx )  prop-map + c! ; zx-inline
: attr-map!  ( value idx )  attr-map + c! ; zx-inline


;; from the working tilemap. doesn't check coords.
: DRAW-TILE  ( x y )
  2dup  32* +  dup attr-map@  swap tile-map@ (draw-tile) ; zx-inline


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load/save various data

-1 quan #rooms

: calc-#rooms
  " CHECKING ROOMS" show-info-window
  #rooms:!0
  rooms-file-name dos-exists? not?exit< close-window >?
  rooms-file-name dos-open-r/o
  dos-get-size bytes/room um/mod drop 1+ #rooms:! drop
  dos-close
  close-window ;

: wk-room-file-name  ( -- addr count )  " wkroom.tmp" ;
: rooms-file-name  ( -- addr count )  " rooms.dat" ;
: tiles-file-name  ( -- addr count )  " tiles.dat" ;

: load-wk-room
  " LOADING WORK ROOM" show-info-window
  wk-room-file-name dos-exists? not?exit< 200 400 beep close-window clear-wk-room >?
  wk-room-file-name dos-open-r/o
  prop-map bytes/room dos-read
  dos-close
  close-window ;

: save-wk-room
  " SAVING WORK ROOM" show-info-window
  wk-room-file-name dos-open-r/w-create
  prop-map bytes/room dos-write
  dos-close
  close-window ;

: load-tile-gfx-attrs
  " LOADING TILES" show-info-window
  tiles-file-name dos-open-r/o
  tile-gfx 2048 256 2* + dos-read
  dos-close
  close-window ;

: save-tile-gfx-attrs
  " SAVING TILES" show-info-window
  tiles-file-name dos-open-r/w-create
  tile-gfx 2048 256 2* + dos-write
  dos-close
  close-window ;

: load-room-to-wk  ( room# )
  dup 1 128 within not?exit< drop 200 400 beep >?
  " LOADING ROOM" show-info-window
  rooms-file-name dos-exists? not?exit< drop 200 400 beep close-window >?
  rooms-file-name dos-open-r/o
  1- bytes/room UUD*  \ M*
  2dup 1 ds+ dos-get-size d<= not?exit< dos-close 2drop 200 400 beep close-window >?
  dos-seek
  prop-map bytes/room dos-read
  dos-close
  close-window ;

: save-wk-to-room  ( room# )
  dup 1 128 within not?exit< drop 200 400 beep >?
  " SAVING ROOM" show-info-window
  rooms-file-name dos-open-r/w-create
  1- bytes/room M* dos-seek
  prop-map bytes/room dos-write
  dos-close dos-flush
  close-window ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw working room

: draw-wk-tile-row  ( x y len )
  dup 0<= ?exit
  >r
  over 0< over 0< or ?exit< 2drop rdrop >?
  over 31 > over 23 > or ?exit< 2drop rdrop >?
  over 32 swap - r> min cfor 2dup draw-tile under+1 endfor
  2drop ;

USE-ASM-WHOLE-ROOM-DRAW? [IF]
: draw-wk-room
  draw-whole-room ; zx-inline
[ELSE]
: draw-wk-room
  22 cfor 0 i 32 draw-wk-tile-row endfor ;
[ENDIF]


|: fix-tile-attrs/props  ( mapofs )
  dup >r
  tile-map@ dup >r prop-map@ ( prop | mapofs tidx )
  ;; change attr?
  dup pmask-u-attr and 0?< r@ tile-attr@  r1:@ attr-map! >?
  ;; change props?
  pmask-t-frozen and 0?< r@ tile-prop@  r1:@ prop-map! >?
  rdrop rdrop ; zx-inline

;; fix room for the given tile (attrs, props).
;; called from tile editor when tile attrs/props are changed.
: fix-wk-tile-attrs  ( tidx )
  lo-byte 768 for
    dup i tile-map@ - 0?< i fix-tile-attrs/props >?
  endfor drop ;

: fix-wk-all-tile-attrs
  768 for i fix-tile-attrs/props endfor ;


;; erase current window by drawing tiles over it
: erase-window
  [ USE-ASM-WHOLE-ROOM-DRAW? ] [IF]
    draw-wk-room
  [ELSE]
    win-y0 dup win-h + swap do
      win-x0 i win-w draw-wk-tile-row
    loop
  [ENDIF] ;


: clear-wk-room
  prop-map 768 erase
  tile-map 768 erase
  attr-map 768 @007 fill ;


: load-all-wk-data
  load-tile-gfx-attrs
  load-wk-room
  calc-#rooms ;

: init-editor
  \ 1 border 0 paper 7 ink 0 flash 0 bright 0 inverse 0 gover cls
  \ setup-e8-driver
  0o007 e8-attr:! cls 1 border
  win-reinit init-kmouse
  load-all-wk-data ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bottom bar with tiles

0 quan bbar-first-tile
0 quan bbar-cur-tile-xy


|: print-def-tile  ( x y tidx )
  lo-byte dup tile-attr@ swap (draw-tile) ; zx-inline

|: print-bb-tile  ( x y tofs )
  bbar-first-tile + print-def-tile ; zx-inline

|: adv-bbar-first  ( delta )
  bbar-first-tile + bbar-first-tile:c! ; zx-inline


: bbar-up/down  ( -- down? )
  ?< 16 || -16 >? adv-bbar-first ; zx-inline

: bbar-printer
  31 cfor i 1+ 22 i 2* print-bb-tile endfor
  31 cfor i 1+ 23 i 2* 1+ print-bb-tile endfor ;

: bbar-ctile  ( -- tidx )
  bbar-cur-tile-xy xy/wh-split
  swap 2* + lo-byte
  bbar-first-tile + lo-byte ;


: draw-bbar
  save-wsp arrow-hide
  fs-win @005 to e8-attr
  22 0 at $80 (e8) 23 0 at $81 (e8)
  bbar-printer
  bbar-cur-tile-xy xy/wh-split under+1 22 + cxy>attr $80 toggle
  restore-wsp ;


|: tbar-set-xy  ( tidx )
  bbar-first-tile -
  dup 2u/ swap 1 and xy/wh-join bbar-cur-tile-xy:! ;

: tbar-set-tidx  ( tidx )
  lo-byte
  dup bbar-first-tile dup 62 + within not?<
    dup $E0 and bbar-first-tile:!
    bbar-first-tile 15 > ?< 0 bbar-up/down >?
  >? tbar-set-xy draw-bbar ;


;;  0: not on tbar
;;  1: scrolled
;; -1: new tile selected
: km-tbar?  ( -- 0/1/-1 )
  km-cxy@ 22 - dup 0< ?exit< 2drop false >?
  over ?< 256* swap 1- + bbar-cur-tile-xy:! -1 >r || nip bbar-up/down 1 >r >?
  arrow-hide draw-bbar
  r> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; editors

: (esc-arrow-cb)
  lastk@ 7 = ?< wait-loop-exit?:!t >? ;

: set-esc-arrow-cb  ( -- oldcb )
  arrow-idle:@
  ['] (esc-arrow-cb) arrow-idle:! ;

: restore-arrow-cb  ( oldcb )
  arrow-idle:! ;

: .#3  ( u )
  \ base@ decimal re-room# <# # # # [char] # hold #> type base! ;
  [char] # emit decw>str5 drop 2+ 3 type ;


;; property editor
$include "20-prop-editor.f"
;; tile editor
$include "30-tile-editor.f"
;; room editor
$include "40-room-editor.f"


: ee
  init-editor
  false to pe-names-loaded?
  room-editor
  \ tile-editor
  arrow-hide
  fs-win ;
