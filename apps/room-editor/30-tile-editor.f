;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Z80 Abersoft fig-FORTH recompiled
;; Copyright (C) 2024 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; room (and tile) editor
;; tile bitmap editor
;; included directly from "zx-90-apps-20-room-edit.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


zxlib-begin" tile editor"

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tile editor

create te-undo-buf  9 allot create;

;; index of the tile we are editing right now
0 quan te-ctile-idx

;; gfx address for the current tile
|: te-tgfx  ( -- addr )  te-ctile-idx 8* tile-gfx + ; zx-inline
;; afft address for the current tile
|: te-tattr ( -- addr )  te-ctile-idx tile-attr + ; zx-inline


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 4x magnified tile rendering

create te-pix4-pat
  $00 c, $44 c, $00 c, $00 c, ;; $00
  $0E c, $4A c, $0E c, $00 c, ;; $40
  $E0 c, $A4 c, $E0 c, $00 c, ;; $80
  $EE c, $AA c, $EE c, $00 c, ;; $C0
create;

;; x is [0..3]
;; lrbits: bit 7 set for left, bit 6 set for right; others MUST be reset
|: te-pix4-2  ( lrbits x y )
  4* win-y0 8* +
  swap win-x0 + 8*
  swap xy>scr$ drop ( lrbits scr$ )
  swap 16u/ $0F and te-pix4-pat + ( scr$ ppat )
  dup 4 + swap do i c@ over c! scr$v loop
  drop ; zx-inline

;; draw magnified tile
: te-draw-mag-tile-4
  te-tgfx 8 cfor ( tgfx^ )
    c@++ 4 cfor
      dup $C0 and
      i j te-pix4-2
    4* endfor drop
  endfor drop ;

;; paint magnified tile to its attrs
: te-draw-mag-attrs
  te-tattr c@ >r
  win-x0 win-y0 cxy>attr
  4 cfor dup 4 ( cfor:) r1:@ fill 32 + endfor
  drop rdrop ;


;; actually, 2 pixels.
;; used in pixel editor.
;; WARNING! coords must be valid!
: te-tile-pix4  ( x y )
  dup te-tgfx + c@ >r
  swap 2u/ swap
  ( x y | [tgfx] )
  over r> swap cfor 4* endfor  ;; shift bitmap data
  ( x y bmp )
  $C0 and nrot te-pix4-2 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tile number rendering

: te-draw-tile#
  base@ 0 17 at
  e8-attr dup $40 or e8-attr:!
  te-ctile-idx .#3
  e8-attr:!
  base! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; color stripes rendering

|: te-mga>paper  ( ink -- paper )
  dup >r
  7 and 8* r@ $07 and 4 < ?< 7 + >?
  r> $F8 and ?< $40 or >? ;

: te-draw-cstripe  ( x y )
  win-y0 + swap win-x0 + swap cxy>attr
  8 cfor
    dup 2 i te-mga>paper fill
    dup 32 + 2 i 8 + te-mga>paper fill
  2+ endfor drop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mark tile attrs at the color stripes

|: (te-mark-tattr)  ( attr cy on? )
  >r
  win-y0 +
  swap 7 and 2* win-x0 + 5 + swap
  cxy>scr$  scr$v scr$v scr$v
  ( scr$ | on? )
  r> ?< $F00F || $0000 >? swap
  2dup ! scr$v ! ;

: te-mark-tattr  ( on? )
  >r te-tattr c@
  ( attr | on? )
  dup  over $40 and 0<> 1+  r@ (te-mark-tattr)
  dup 8u/  swap $40 and 0<> 5 +  r> (te-mark-tattr) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; remove all marks from all color stripes

: te-wipe-cstripe  ( paper? )
  ?< 5 || 1 >? win-y0 +  5 win-x0 +  swap cxy>scr$
  16 cfor dup 16 cerase scr$v endfor drop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw color stripes and their labels

: te-draw-ink-paper
  0 5 at ." INK:"
  5 1 te-draw-cstripe
  4 5 at ." PAPER:"
  5 5 te-draw-cstripe ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw small tile (preview)

: te-draw-tile-preview
  win-x0 win-y0 5 + cxy>attr
  dup 3 7 fill
  32 + dup 3 7 fill
  32 + 3 7 fill
  win-x0 1+ win-y0 6 + te-ctile-idx print-def-tile ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; copy current tile to or from the undo buffer

: te->undo
  te-tgfx te-undo-buf 8 cmove
  te-tattr te-undo-buf 8 + 1 cmove ;

: te-undo>  ( tidx )
  te-undo-buf te-tgfx 8 cmove
  te-undo-buf 8 + te-tattr 1 cmove ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; refresh everything related to the current tile
;; (magnified bitmap, colors, preview; but not tile number)

|: te-refresh-tile
  arrow-hide
  draw-bbar
  false te-wipe-cstripe
  true te-wipe-cstripe
  true te-mark-tattr
  te-draw-tile-preview
  te-draw-mag-attrs
  te-draw-mag-tile-4 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; recreate and repaing the editor window

|: te-full-refresh
  arrow-hide
  draw-bbar
  4 2 24 14 @017 make-window
  te->undo  ;; save undo info
  te-draw-tile#
  te-draw-ink-paper
  te-refresh-tile
  hot-tile-editor hot-setup ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; hot-menu actions

|: te-do-undo
  te-undo>
  draw-bbar
  te-refresh-tile ;


0 quan te-close?

|: te-do-close  true te-close?:! ;


|: te-disk-load
  " LOADING TILE GFX" show-info-window
  load-tile-gfx-attrs
  fix-wk-all-tile-attrs
  close-window
  draw-wk-room te-full-refresh ;

|: te-disk-save
  " SAVING TILE GFX" show-info-window
  save-tile-gfx-attrs
  close-window ;

|: te-prop-edit
  te-ctile-idx tile-prop@
  prop-editor
  te-ctile-idx tile-prop!
  te-ctile-idx fix-wk-tile-attrs
  draw-wk-room te-full-refresh ;


create hot-tile-editor
  ['] te-do-undo -6 -3 " UNDO" mk-hot-item
  ['] te-do-close  -7 -1 " CLOSE" mk-hot-item
  ['] te-disk-load 0 -3 " A:LOAD" mk-hot-item
  ['] te-disk-save 0 -1 " A:SAVE" mk-hot-item
  ['] te-prop-edit -13 -3 " PROP" mk-hot-item
;hot-menu

(*
|: te-full-refresh
  arrow-hide
  draw-bbar
  4 2 24 14 @017 make-window
  te->undo  ;; save undo info
  te-draw-tile#
  te-draw-ink-paper
  te-refresh-tile
  hot-tile-editor hot-setup ;
*)

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; drawing on the magnified tile bitmap

|: te-pix-addr  ( x y -- addr mask )
  te-tgfx +  $80 rot cfor 2u/ endfor ; zx-inline

|: te-get-pix    ( x y -- on? )  te-pix-addr swap c@ and 0<> ; zx-inline
\ |: te-toggle-pix ( x y )  te-pix-addr toggle ; zx-inline
|: te-reset-pix  ( x y )  te-pix-addr swap ~and!c ; zx-inline
|: te-set-pix    ( x y )  te-pix-addr swap or!c ; zx-inline

|: te-km-pix4-xy  ( -- x/y TRUE // FALSE )
  km-win-xy@ 2/ 2/
  dup 0 8 within not?exit< 2drop 0 >?
  swap 2/ 2/
  dup 0 8 within not?exit< 2drop 0 >?
  swap xy/wh-join true ;

|: te-km-do-pixel  ( px/py action-cfa )
  >r xy/wh-split
  2dup r> arrow-hide execute te-tile-pix4
  te-draw-tile-preview
  draw-bbar ;

;; track mouse in magnified pixels.
;; button 0 draws, button 1 erases.
;; button 0 takes the value from the inverted current pixel
|: te-proc-pixel?  ( -- done-flag )
  te-km-pix4-xy dup not?exit drop
  hot-loop-bt1? ?< ['] te-reset-pix
  || dup xy/wh-split te-get-pix ?< ['] te-reset-pix || ['] te-set-pix >? >?
  >r ( x/y | action-cfa )
  dup r@ te-km-do-pixel ;; first call
  arrow-pressed!
  << arrow-show halt
     km-butt 3 and 0?v||
     te-km-pix4-xy 0?^||
     tuck - ?< dup r@ te-km-do-pixel >?
  ^|| >> drop rdrop
  arrow-hide arrow-default!
  true ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; processing clicks on the color stripes

|: te-proc-attrs?  ( -- done-flag )
  km-win-cxy@
  swap 5 - dup 15 u> ?exit< 2drop false >?
  2/ swap 1- dup 1 ~and not?< false
  || 4 - dup 1 ~and ?exit< 2drop false >? true >?
  >r ( clr bright? | paper? )
  false te-mark-tattr
  $40 * swap
  ( bright clr | paper? )
  r@ ?< @007 || @070 >? te-tattr and!c
  r> ?< 8* >? +
  ( clr )
  te-tattr or!c
  true te-mark-tattr
  te-draw-tile-preview
  te-draw-mag-attrs
  draw-bbar
  te-ctile-idx fix-wk-tile-attrs
  true ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; process clicks out of the hot-menu

|: te-proc-mouse
  te-proc-pixel? ?exit
  te-proc-attrs? ?exit
;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; process click on the bottom tile bar

;; if right click, copy through undo buffer
|: te-proc-tbar  ( action-code )
  1+ ?exit  ;; not a tile click? do nothing
  hot-loop-bt1? ?< te->undo >?
  bbar-ctile te-ctile-idx:!
  hot-loop-bt1? ?< te-undo> || te->undo >?
  te-draw-tile#
  te-refresh-tile ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main tile editor driver
\ <zx-normal>

: tile-editor
  arrow-hide
  false te-close?:!
  bbar-ctile te-ctile-idx:!
  set-esc-arrow-cb >r
  te-full-refresh
  << ?ed-depth0
     hot-bt01!  ;; we want both buttons
     hot-menu-loop
     wait-loop-exit? ?v||
     arrow-hide
     hcur-udata ?< hcur-udata execute
     || km-tbar? dup ?< te-proc-tbar || drop te-proc-mouse >? >?
  te-close? not?^|| else| >>
  unshrink-window arrow-hide \ erase-window
  r> restore-arrow-cb
  fs-win 0 hot-setup
  draw-wk-room ;


zxlib-end
