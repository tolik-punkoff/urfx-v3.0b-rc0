;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Z80 Abersoft fig-FORTH recompiled
;; Copyright (C) 2024 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16x16 XOR sprites, no runtime shifting
;; sprite editor
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$include "10-defs.f"


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
;; load/save various data

\ : load-n-blocks  ( block dest-addr block-count )
\   for 2dup swap block swap 256 cmove  256 + under+1 loop 2drop ;

\ : save-n-blocks  ( block src-addr block-count )
\   for 2dup swap buffer 256 cmove update  256 + under+1 loop 2drop ;

\ : (load-sprites)  1ST-SPR-BUF SPR-MEM #SPR-BUFS load-n-blocks ;
\ : (save-sprites)  empty-buffers 1ST-SPR-BUF SPR-MEM #SPR-BUFS save-n-blocks flush ;

: (sprite-fname)  ( -- addr count )
  " sprites.dat" ;

: (sprite-file-exists?) ( -- bool )
  [ SPR-LOAD-BLK ] [IF]
    " sprites.blk"
  [ELSE]
    (sprite-fname)
  [ENDIF]
  dos-exists? ;

: (open-sprite-file) ( writing? )
  [ SPR-LOAD-BLK ] [IF]
    dup ?< (sprite-fname) || " sprites.blk" >?
  [ELSE]
    (sprite-fname)
  [ENDIF]
  rot not?< dos-open-r/o || dos-open-r/w-create >?
  [ SPR-FILE-OFFSET ] [IF]
  SPR-FILE-OFFSET 0 dos-seek
  [ENDIF] ;

: (close-sprite-file)
  dos-close ;

: (load-sprites)
  (sprite-file-exists?) not?exit< SPR-MEM MAX-SPR# BT/SPR * erase >?
  false (open-sprite-file)
  [ SPR-LOAD-BLK ] [IF]
    1ST-SPR-BUF 256 M* dos-seek
    SPR-MEM  #SPR-BUFS for  ( addr )
      \ 1ST-SPR-BUF i + 256 M* dos-seek
      dup 256 dos-read
      SPR/BUF BT/SPR * +
    endfor drop
  [ELSE]
    SPR-MEM  MAX-SPR# BT/SPR *  dos-read
  [ENDIF]
  (close-sprite-file) ;

: (save-sprites)
  true (open-sprite-file)
  SPR-MEM  MAX-SPR# BT/SPR *  dos-write
  (close-sprite-file) ;


: load-all-sprites
  \ (sprite-file-exists?) not?exit< SPR-MEM MAX-SPR# BT/SPR * erase >?
  " LOADING SPRITES" show-info-window
  (load-sprites)
  close-window ;

: save-all-sprites
  " SAVING SPRITES" show-info-window
  (save-sprites) dos-flush
  close-window ;


: init-editor
  \ 1 border 1 paper 7 ink 0 flash 0 bright 0 inverse 0 gover cls
  \ setup-e8-driver
  @017 e8-attr:! cls 1 border
  win-reinit init-kmouse
  (* TODO: finish this!
  " PREPARING BLK FILE" show-info-window
  true (open-sprite-file)
  " ROOMEDIT.BLK" +3BLK-OPEN
  close-window
  *)
  load-all-sprites ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; drawing horizontal and vertical lines, and rects

true quan se-rect-on?

: se-hline  ( x y w )
  cfor 2dup se-rect-on? pset under+1 endfor 2drop ;

: se-vline  ( x y h )
  cfor 2dup se-rect-on? pset 1+ endfor 2drop ;

: se-rect  ( x y w h )
  >r >r ( x y | h w )
  2dup r@ se-hline  ;; top
  2dup r1:@ + 1- r@ se-hline ;; bottom
  2dup r1:@ se-vline ;; left
  r> 1- under+ r> se-vline ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 4x magnified byte rendering

create se-pix4-pat
  $00 c, $44 c, $00 c, $00 c, ;; $00
  $0E c, $4A c, $0E c, $00 c, ;; $40
  $E0 c, $A4 c, $E0 c, $00 c, ;; $80
  $EE c, $AA c, $EE c, $00 c, ;; $C0
create;

1 quan se-p4-xofs
1 quan se-p4-yofs

;; x is [0..3]
;; lrbits: bit 7 set for left, bit 6 set for right; others MUST be reset
|: se-pix4-2  ( lrbits x y )
  15 swap -
  4* win-y0 se-p4-yofs + 8* +
  swap win-x0 se-p4-xofs + + 8*
  swap xy>scr$ drop ( lrbits scr$ )
  swap 16u/ $0F and se-pix4-pat + ( scr$ ppat )
  dup 4 + swap do i c@ over c! scr$v loop
  drop ;

;; draw magnified sprite
: se-draw-mag-sprite
  wk-spr-buf 16 cfor ( sgfx^ )
    c@++ 4 cfor
      dup $C0 and
      i j se-pix4-2
    4* endfor drop
    c@++ 4 cfor
      dup $C0 and
      i 4 + j se-pix4-2
    4* endfor drop
  endfor drop ;

: se-draw-mag-attrs
  win-x0 se-p4-xofs + win-y0 se-p4-yofs + cxy>attr
  8 cfor dup 8 @006 fill 32 + endfor
  drop ;


;; actually, 2 pixels.
;; used in pixel editor.
;; WARNING! coords must be valid!
: se-spr-pix4  ( x y )
  2dup 2*  swap 7 u> +  wk-spr-buf +  c@ >r
  swap 2u/ swap
  ( x y | [sgfx] )
  over r> swap 3 and 2* rol8  ;; shift bitmap data
  ( x y bmp )
  $C0 and nrot se-pix4-2 ;


: draw-wk-spr-shift
  @017 e8-attr:!
  10 1 at ." RSHIFT:" wk-spr-rshift 10 umod [char] 0 + emit ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load sprite to working buffer, save sprite back to data array

: ?ERROR  ( flag code )
  drop not?exit
  \ FIXME: show error window!
  DOS-ERROR ;

;; calculate sprite address in data array
: spr^  ( spr-idx )
  dup max-spr# u>= 3 ?error ;; "incorrect address mode" error, oops
  \ spr/buf uu/mod  ( buf# spr# )
  \ bt/spr * swap b/buf * +
  bt/spr *
  spr-mem + ;

: mask>shift  ( mask -- shift )
  8 swap ( shift mask )
  << dup $01 and ?^| 2u/c under-1 |? else| drop >>
  7 and ;

: spr-to-wk  ( spr-idx )
  spr^
  c@++ mask>shift wk-spr-rshift:!
  1+ 16 cfor dup @ wk-spr-rshift rol  i 2* wk-spr-buf + ! 2+ endfor
  drop ;

: wk-to-spr  ( spr-idx )
  spr^
  $FF wk-spr-rshift rshift over c!  ;; mask
  2+ 16 cfor
    i 2* wk-spr-buf + @  wk-spr-rshift ror  over !  2+ endfor
  drop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw 1:1 sprite

;; x and y are in chars
: draw-spr-gfx  ( x y gfx-addr rshift )
  2swap 2+ cxy>scr$
  ( gfx-addr shift scr$ )
  16 cfor scr$^ >r over @ over rol r@ !
  2 under+ r> endfor drop 2drop ;

;; x is in chars, y is in pixels
: draw-spr#  ( x y spr# )
  spr^ c@++ mask>shift under+1 draw-spr-gfx ;

;; x is in chars, y is in pixels
: erase-spr  ( x y )
  cxy>scr$ 16 cfor dup off scr$v endfor drop ;

;; x is in chars, y is in pixels
: erase-spr-4  ( x y )
  cxy>scr$ 16 cfor dup off  dup 2+ off scr$v endfor drop ;


;; x and y are in chars.
;; used to draw shifted working image.
: draw-shifted-wk-spr-gfx  ( x y gfx-addr rshift )
  2swap 2+ cxy>scr$
  ( gfx-addr shift scr$ )
  16 cfor scr$^ >r ( gfx-addr shift | scr$ )
    over @ bswap over rshift bswap  r@ !  ;; first 2 bytes
    over 1+ c@  over 8 swap - lshift  r@ 2+ c!  ;; last byte
  2 under+ r> endfor drop 2drop ;

;; x and y are in chars.
;; used to draw preshifted stored images.
: draw-packed-spr-gfx  ( x y gfx-addr lmask )
  2swap 2+ cxy>scr$
  ( gfx-addr lmask scr$ )
  16 cfor scr$^ >r ( gfx-addr lmask | scr$ )
    over @  over $FF00 or and  r@ !  ;; first 2 bytes
    over c@  over ~and  r@ 2+ c!  ;; last byte
  2 under+ r> endfor drop 2drop ;

;; x is in chars, y is in pixels
: draw-packed-spr#  ( x y spr# )
  spr^ c@++ under+1 draw-packed-spr-gfx ;



;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mark helpers

: se-2x2-attr  ( x y attr )
  >r cxy>attr
  dup 2 r@ fill
  32 + 2 r> fill ;

: se-2x3-attr  ( x y attr )
  >r cxy>attr
  dup 3 r@ fill
  32 + 3 r> fill ;

: draw-spr-mark  ( scol srow xofs yofs attr )
  >r
  2swap 3* swap 3* swap 2swap
  >r rot + swap r> +
  2dup r> se-2x2-attr
  swap 8* 2- swap 8* 2- 20 20 se-rect ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw animation row

: erase-anim-row
  4 cfor
    se-anim-xofs      i 3* se-anim-yofs +  2dup erase-spr @017 se-2x2-attr
    se-anim-xofs 3 +  i 3* se-anim-yofs +  2dup erase-spr @017 se-2x2-attr
  endfor ;

;; draw current animation row
: draw-anim-row
  wk-anim-len 4 min cfor
    se-anim-xofs  i 3* se-anim-yofs +
    i wk-anim-base + dup wk-spr# -
    ?< draw-spr#
    || drop wk-spr-buf 0 draw-spr-gfx >?
    @006 se-anim-xofs se-anim-yofs i 3* + rot se-2x2-attr
  endfor
  wk-anim-len 4 - cfor
    se-anim-xofs 3 +  i 3* se-anim-yofs +
    i wk-anim-base + 4 + dup wk-spr# -
    ?< draw-spr#
    || drop wk-spr-buf 0 draw-spr-gfx >?
    @006 se-anim-xofs 3 + se-anim-yofs i 3* + rot se-2x2-attr
  endfor ;

: mark-anim-spr  ( do-mark? )
  dup >r 0<> se-rect-on?:!
  wk-spr# wk-anim-base -  dup wk-anim-len u< ?<
    4 uu/mod ( scol srow )
    se-anim-xofs se-anim-yofs r@ ?< @106 || @006 >? draw-spr-mark
  || drop >?
  rdrop true se-rect-on?:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw sprite selection bar

: draw-spr-bar-idx
  @015 e8-attr:!
  4 cfor
    se-sbar-yofs i 3* +  se-sbar-xofs 4 - at
    i 4* se-bar-first +  3 .r
  endfor ;

: draw-spr-bar
  4 cfor
    4 cfor
      se-sbar-xofs i 3* +  se-sbar-yofs j 3* +
      j 4* i + se-bar-first + draw-spr#
      se-sbar-xofs i 3* +  se-sbar-yofs j 3* +  @007 se-2x2-attr
    endfor
  endfor
  draw-spr-bar-idx ;

: mark-tab-spr  ( do-mark? )
  dup >r 0<> se-rect-on?:!
  wk-spr# se-bar-first -  dup 16 u< ?<
    4 uu/mod ( srow scol )
    swap se-sbar-xofs 1 r@ ?< @107 || @007 >? draw-spr-mark
  || drop >?
  rdrop true se-rect-on?:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mark/unmark selected sprite

: draw-anim-arrows
  @007 e8-attr:!
  0 11 at 2 emit
  0 13 at 3 emit
  @017 e8-attr:! ;

: mark-curr-spr  ( do-mark? )
  dup mark-anim-spr mark-tab-spr
  draw-anim-arrows ;

(*
: se-draw-spr-preview
  wk-spr# wk-anim-base -  dup wk-anim-len u>= ?exit< drop >?
  4 uu/mod  ( col row )
  3* 1+  swap 3* 10 + swap
  wk-spr-buf 0 draw-spr-gfx ;
*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw sprite animation cycle

false quan se-walk-allowed?
true quan se-anim-shift?
1 quan se-anim-dir
0 quan se-anim-idx
;; used for shifted walking
0 quan se-anim-spos


|: se-erase-row  ( cx cy )
  cxy>scr$ 16 cfor 0 over c! scr$v endfor drop ;

|: se-draw-walk-shifted  ( cx cy spr# )
  dup wk-spr# - ?< draw-packed-spr#
  || drop wk-spr-buf wk-spr-rshift draw-shifted-wk-spr-gfx >? ;

|: se-draw-walk-normal  ( cx cy spr# )
  dup wk-spr# - ?< draw-spr# || drop wk-spr-buf 0 draw-spr-gfx >? ;

|: se-draw-walk-spr
  se-walk-xofs se-walk-yofs
  se-anim-idx wk-anim-base +
  se-anim-shift? not?exit< se-draw-walk-normal >?
  >r
  2dup se-anim-spos 0?< 3 under+ >? se-erase-row
  se-anim-spos under+ r> se-draw-walk-shifted ;

;; the arrow is blinking, so no need to hide/show it if we are animating.
|: se-walk-redraw
  se-walk-allowed? ?< false || arrow-visible? arrow-hide >? >r
  se-draw-walk-spr
  r> ?< arrow-show >? ;

|: se-walk-advance
  se-anim-idx se-anim-dir + wk-anim-len umod dup se-anim-idx:!
  se-anim-dir 0< ?< wk-anim-len 1- = || 0= >?
  ?< se-anim-spos se-anim-dir + 1 and se-anim-spos:! >?
  se-walk-redraw ;

: se-do-anim
  \ FRAMES c@ $10 and not?exit
  \ se-anim-idx 1+ wk-anim-len umod se-anim-idx:!
  se-walk-allowed? not?exit
  se-anim-spos ?< se-walk-xofs se-walk-yofs se-erase-row 0 se-anim-spos:! >?
  SYS: FRAMES c@ 8u/ se-anim-dir 0< ?< negate >?
  wk-anim-len umod  dup se-anim-idx - 0?exit< drop >?
  se-anim-idx:!
  se-walk-redraw ;

: se-walk-erase
  se-walk-xofs se-walk-yofs erase-spr-4
  se-walk-xofs se-walk-yofs @017 se-2x3-attr
  se-walk-xofs se-walk-yofs @006
  se-anim-shift? ?< se-2x3-attr || se-2x2-attr >? ;

|: se-hi-walk
  se-walk-xofs 2- se-walk-yofs 3 + cxy>attr
  6 se-walk-allowed? ?< @117 || @016 >? fill ;

|: se-hi-back
  se-walk-xofs 2- se-walk-yofs 5 + cxy>attr
  6 se-anim-dir 0< ?< @117 || @016 >? fill ;

|: se-hi-shift
  se-walk-xofs 5 + se-walk-yofs 5 + cxy>attr
  7 se-anim-shift? ?< @117 || @016 >? fill ;

: se-hi-walk-button
  se-hi-walk se-hi-back se-hi-shift ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; drawing on the magnified sprite bitmap

|: se-pix-addr  ( x y -- addr mask )
  2* over 7 u> + wk-spr-buf + ( x addr )
  swap 7 and $80 swap ror8 ;

|: se-get-pix    ( x y -- on? )  se-pix-addr swap c@ and 0<> ;
\ |: se-toggle-pix ( x y )  se-pix-addr toggle ;
|: se-reset-pix  ( x y )  se-pix-addr swap ~and!c ;
|: se-set-pix    ( x y )  se-pix-addr swap or!c ;

|: se-km-pix4-xy  ( -- x/y TRUE // FALSE )
  km-xy@ 8 - 2/ 2/
  dup 0 16 within not?exit< 2drop false >?
  15 swap -
  swap 8 - 2/ 2/
  dup 0 16 within not?exit< 2drop false >?
  swap xy/wh-join true ;

|: se-km-do-pixel  ( px/py action-cfa )
  >r xy/wh-split
  2dup r> arrow-hide execute se-spr-pix4
  se-draw-walk-spr ;

;; track mouse in magnified pixels.
;; button 0 draws, button 1 erases.
;; button 0 takes the value from the inverted current pixel
|: se-proc-pixel?  ( -- done-flag )
  se-km-pix4-xy not?exit&leave
  CS/SS? dup ?<
    1 and ?< ['] se-set-pix || ['] se-reset-pix >?
  || drop
    hot-loop-bt1? ?< ['] se-reset-pix
    || dup xy/wh-split se-get-pix ?< ['] se-reset-pix || ['] se-set-pix >? >?
  >?
  >r ( x/y | action-cfa )
  dup r@ se-km-do-pixel ;; first call
  arrow-pressed!
  << arrow-show halt
     arrow-idle
     km-butt 3 and 0?v||
     se-km-pix4-xy 0?^||
     tuck - ?< dup r@ se-km-do-pixel >?
  ^|| >> drop rdrop
  arrow-hide arrow-default!
  true ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; buttons

false quan se-close?


: se-full-refresh
  false mark-curr-spr
  se-draw-mag-attrs
  se-draw-mag-sprite
  draw-anim-row
  draw-spr-bar
  draw-wk-spr-shift
  se-walk-erase
  se-walk-allowed? 0?<
    wk-spr# wk-anim-base - se-anim-idx:!
    0 se-anim-spos:!
    se-walk-redraw >?
  true mark-curr-spr
  draw-anim-arrows ;


|: redraw-bar-spr  ( spr-idx )
  se-bar-first -  dup 16 u< ?<
    4 uu/mod ( srow scol )
    3* se-sbar-xofs +  swap 3* 1+  wk-spr# draw-spr#
  || drop >? ;

|: click-save-curr-spr
  hot-loop-bt0? not?exit
  wk-spr# wk-to-spr
  wk-spr# redraw-bar-spr ;

|: click-save-new-spr
  hot-loop-bt1? not?exit
  wk-spr# wk-to-spr
  wk-spr# redraw-bar-spr ;

|: update-anim-row
  wk-spr# wk-anim-base - wk-anim-len u< ?exit
  \ wk-anim-len 4 = ?<
  \   wk-spr# 3 ~and wk-anim-base = ?exit >?
  wk-anim-len 4 - ?< erase-anim-row  4 wk-anim-len:! >?
  wk-spr# 3 ~and wk-anim-base:! ;

|: se-hi-undo-copy  ( attr )
  >r 32 14 - 20 cxy>attr 11 r> fill ;

|: click-update-selected-sprite
  hot-loop-bt1? ?< @117 || @017 >? se-hi-undo-copy
  wk-spr# spr^ undo-spr-buf bt/spr cmove
  click-save-new-spr
  update-anim-row
  wk-spr# spr-to-wk
  se-draw-mag-sprite
  draw-wk-spr-shift
  se-walk-allowed? 0?<
    wk-spr# wk-anim-base - se-anim-idx:!
    0 se-anim-spos:!
    se-walk-redraw >?
  draw-anim-row
  \ draw-spr-bar
  true mark-curr-spr ;

|: click-select-bar-spr  ( spr-ofs )
  false mark-curr-spr
  click-save-curr-spr
  se-bar-first + wk-spr#:!
  click-update-selected-sprite ;

|: click-select-anim  ( anim-ofs )
  false mark-curr-spr
  click-save-curr-spr
  wk-anim-base + wk-spr#:!
  click-update-selected-sprite ;

|: se-click-tbar-00   0 click-select-bar-spr ;
|: se-click-tbar-01   1 click-select-bar-spr ;
|: se-click-tbar-02   2 click-select-bar-spr ;
|: se-click-tbar-03   3 click-select-bar-spr ;
|: se-click-tbar-10   4 click-select-bar-spr ;
|: se-click-tbar-11   5 click-select-bar-spr ;
|: se-click-tbar-12   6 click-select-bar-spr ;
|: se-click-tbar-13   7 click-select-bar-spr ;
|: se-click-tbar-20   8 click-select-bar-spr ;
|: se-click-tbar-21   9 click-select-bar-spr ;
|: se-click-tbar-22  10 click-select-bar-spr ;
|: se-click-tbar-23  11 click-select-bar-spr ;
|: se-click-tbar-30  12 click-select-bar-spr ;
|: se-click-tbar-31  13 click-select-bar-spr ;
|: se-click-tbar-32  14 click-select-bar-spr ;
|: se-click-tbar-33  15 click-select-bar-spr ;

|: se-click-abar-00  0 click-select-anim ;
|: se-click-abar-01  1 click-select-anim ;
|: se-click-abar-02  2 click-select-anim ;
|: se-click-abar-03  3 click-select-anim ;
|: se-click-abar-04  4 click-select-anim ;
|: se-click-abar-05  5 click-select-anim ;
|: se-click-abar-06  6 click-select-anim ;
|: se-click-abar-07  7 click-select-anim ;

|: se-click-toggle-walk
  ;; click with right button when standing: advance frame
  se-walk-allowed? not hot-loop-bt1? and ?exit< se-walk-advance >?
  se-walk-allowed? not se-walk-allowed?:!
  se-hi-walk-button ;

|: se-click-toggle-back
  se-anim-dir negate se-anim-dir:!
  se-hi-walk-button ;

|: se-click-toggle-shift
  se-anim-shift? not se-anim-shift?:!
  se-hi-walk-button
  se-walk-erase
  se-walk-redraw ;

|: se-click-rshift#
  hot-loop-bt0? ?< 1 || -1 >?
  wk-spr-rshift + 7 and wk-spr-rshift:!
  draw-wk-spr-shift
  se-anim-shift? not?exit
  se-walk-allowed? ?exit
  se-walk-redraw ;

|: se-click-chg-bar-page  ( dir )
  false mark-curr-spr
  16* se-bar-first + 0max  max-spr# 16 - min  se-bar-first:!
  draw-spr-bar
  true mark-curr-spr ;

|: se-click-prev-bar-page  -1 se-click-chg-bar-page ;
|: se-click-next-bar-page   1 se-click-chg-bar-page ;

|: se-click-finish-magmod
  se-draw-mag-sprite
  draw-anim-row
  true mark-curr-spr
  se-walk-redraw ;

|: se-click-lrot
  wk-spr-buf 16 cfor dup @ bswap 1 rol bswap over ! 2+ endfor drop
  se-click-finish-magmod ;

|: se-click-rrot
  wk-spr-buf 16 cfor dup @ bswap 1 ror bswap over ! 2+ endfor drop
  se-click-finish-magmod ;

(*
|: w-h-mirror  ( w -- w )
  0 16 for ( wold wnew )
    1 lshift over 1 and or
    swap 2u/ swap
  loop nip ;
*)

|: se-click-spr-h-mirror
  wk-spr-buf 16 cfor dup @ ( w-h-mirror) rev16 over ! 2+ endfor drop
  se-click-finish-magmod ;

|: se-click-spr-v-mirror
  8 cfor
    wk-spr-buf i 2* +
    wk-spr-buf 15 i - 2* +
    ( addr0 addr1 )
    over @ over @ swap
    ( addr0 addr1 [addr1] [addr0] )
    rot ! swap !
  endfor
  se-click-finish-magmod ;

|: se-click-spr-clear
  wk-spr-buf 32 hot-loop-bt1? ?< $FF || $00 >? fill
  se-click-finish-magmod ;

|: se-click-spr-reload
  wk-spr# spr-to-wk
  draw-wk-spr-shift
  se-click-finish-magmod ;

|: se-click-undo-copy
  @017 se-hi-undo-copy
  undo-spr-buf wk-spr# spr^ bt/spr cmove
  draw-spr-bar
  se-click-spr-reload ;

|: se-click-load
  load-all-sprites
  wk-spr# spr-to-wk
  se-full-refresh ;

|: se-click-save
  \ wk-spr# spr^ undo-spr-buf bt/spr cmove
  \ wk-spr# wk-to-spr
  \ draw-spr-bar
  save-all-sprites ;

|: se-click-anim-less
  wk-anim-len 2 = ?exit
  wk-anim-len dup 4 > ?< 4 - || 2- >?
  ( new-len )
  wk-spr# wk-anim-base - over >= ?exit< drop >?
  wk-anim-len:!
  se-fix-hot-anim-bars
  erase-anim-row
  draw-anim-row ;

|: se-click-anim-more
  wk-anim-len 8 = ?exit
  wk-anim-len dup 4 < ?< 2+ || 4 + >? wk-anim-len:!
  se-fix-hot-anim-bars
  \ erase-anim-row
  draw-anim-row ;


create hot-sprite-editor
  ;; sprite bar
  ;; first row
  ['] se-click-tbar-00 se-sbar-xofs 0 + se-sbar-yofs 2 2 mk-hot-area
  ['] se-click-tbar-01 se-sbar-xofs 3 + se-sbar-yofs 2 2 mk-hot-area
  ['] se-click-tbar-02 se-sbar-xofs 6 + se-sbar-yofs 2 2 mk-hot-area
  ['] se-click-tbar-03 se-sbar-xofs 9 + se-sbar-yofs 2 2 mk-hot-area
  ;; second row
  ['] se-click-tbar-10 se-sbar-xofs 0 + se-sbar-yofs 3 +  2 2 mk-hot-area
  ['] se-click-tbar-11 se-sbar-xofs 3 + se-sbar-yofs 3 +  2 2 mk-hot-area
  ['] se-click-tbar-12 se-sbar-xofs 6 + se-sbar-yofs 3 +  2 2 mk-hot-area
  ['] se-click-tbar-13 se-sbar-xofs 9 + se-sbar-yofs 3 +  2 2 mk-hot-area
  ;; third row
  ['] se-click-tbar-20 se-sbar-xofs 0 + se-sbar-yofs 6 +  2 2 mk-hot-area
  ['] se-click-tbar-21 se-sbar-xofs 3 + se-sbar-yofs 6 +  2 2 mk-hot-area
  ['] se-click-tbar-22 se-sbar-xofs 6 + se-sbar-yofs 6 +  2 2 mk-hot-area
  ['] se-click-tbar-23 se-sbar-xofs 9 + se-sbar-yofs 6 +  2 2 mk-hot-area
  ;; fourth row
  ['] se-click-tbar-30 se-sbar-xofs 0 + se-sbar-yofs 9 +  2 2 mk-hot-area
  ['] se-click-tbar-31 se-sbar-xofs 3 + se-sbar-yofs 9 +  2 2 mk-hot-area
  ['] se-click-tbar-32 se-sbar-xofs 6 + se-sbar-yofs 9 +  2 2 mk-hot-area
  ['] se-click-tbar-33 se-sbar-xofs 9 + se-sbar-yofs 9 +  2 2 mk-hot-area
  ;; walking sprite toggle
  ['] se-click-toggle-walk  se-walk-xofs 2-  se-walk-yofs 3 + " WALK" mk-hot-item
  ['] se-click-toggle-back  se-walk-xofs 2-  se-walk-yofs 5 + " BACK" mk-hot-item
  ['] se-click-toggle-shift se-walk-xofs 5 + se-walk-yofs 5 + " SHIFT" mk-hot-item
  ;; rshift button
  ['] se-click-rshift# 1 10 8 1 mk-hot-area
  ;; sprite bar navigation
  ['] se-click-prev-bar-page  se-sbar-xofs 2 -  se-sbar-yofs 12 + " PREV" mk-hot-item
  ['] se-click-next-bar-page  se-sbar-xofs 5 +  se-sbar-yofs 12 + " NEXT" mk-hot-item
  ;; tools
  ['] se-click-lrot    1 12 " \x02" mk-hot-item
  ['] se-click-rrot    6 12 " \x03" mk-hot-item
  \ ['] se-click-anim-less    14 13 " \x00" mk-hot-item
  \ ['] se-click-anim-more    14 15 " \x01" mk-hot-item
  ['] se-click-anim-less    11 0 1 1 mk-hot-area
  ['] se-click-anim-more    13 0 1 1 mk-hot-area
  ['] se-click-spr-clear     -23 16 " CLR/FILL" mk-hot-item
  ['] se-click-spr-reload    -23 18 " RELOAD #" mk-hot-item
  ['] se-click-undo-copy     -14 20 " UNDO COPY" mk-hot-item
  ['] se-click-spr-h-mirror  -11 16 " H-MIRROR" mk-hot-item
  ['] se-click-spr-v-mirror  -11 18 " V-MIRROR" mk-hot-item
  ;; save/load
  ['] se-click-load  -14 -2 " LOAD" mk-hot-item
  ['] se-click-save   -7 -2 " SAVE" mk-hot-item
  ;; anim sequence (directly modified by the code)
zx-here
  ['] se-click-abar-00 se-anim-xofs  se-anim-yofs 0 + 2 2 mk-hot-area
  ['] se-click-abar-01 se-anim-xofs  se-anim-yofs 3 + 2 2 mk-hot-area
  ['] se-click-abar-02 se-anim-xofs  se-anim-yofs 6 + 2 2 mk-hot-area
  ['] se-click-abar-03 se-anim-xofs  se-anim-yofs 9 + 2 2 mk-hot-area
  ['] se-click-abar-04 se-anim-xofs 3 +  se-anim-yofs 0 + 2 2 mk-hot-area
  ['] se-click-abar-05 se-anim-xofs 3 +  se-anim-yofs 3 + 2 2 mk-hot-area
  ['] se-click-abar-06 se-anim-xofs 3 +  se-anim-yofs 6 + 2 2 mk-hot-area
  ['] se-click-abar-07 se-anim-xofs 3 +  se-anim-yofs 9 + 2 2 mk-hot-area
;hot-menu

constant hot-anim-bars^


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main entry point

: se-fix-hot-anim-bars
  hot-anim-bars^ 3 + 8 cfor 0 over c! 6 + endfor drop
  wk-anim-len cfor 2  i 6 * hot-anim-bars^ 3 + + c! endfor ;

: se-mouse-loop
  se-fix-hot-anim-bars
  hot-bt01!  ;; we want both buttons
  hot-menu-loop ;

: sprite-editor
  false se-close?:!
  ['] se-do-anim arrow-idle:!
  arrow-hide
  fs-win
  wk-spr# spr-to-wk
  se-full-refresh
  hot-sprite-editor hot-setup
  se-hi-walk-button
  << ?ed-depth0
     se-mouse-loop
     \ lastk@ 7 = ?v||
     hcur-udata dup ?< arrow-hide hcur-hide execute || drop se-proc-pixel? drop >?
  se-close? not?^|| else| >>
  arrow-hide ;


\ <zx-normal>
: ee
  init-editor
  sprite-editor ;
