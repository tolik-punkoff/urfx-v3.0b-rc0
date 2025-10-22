;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Z80 Abersoft fig-FORTH recompiled
;; Copyright (C) 2024 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; room (and tile) editor
;; tile property editor
;; included directly from "zx-90-apps-20-room-edit.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


zxlib-begin" prop editor"

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; property editor


false quan pe-close?
0 quan pe-props
\ 0 quan pe-saved-hot-list

|: pe-set-attrs  ( high? hidx )
  hcur-list hot-find-by-index not?exit< drop >?
  swap ?< @150 || @040 >?
  swap hot-item-fill-attr ;

|: pe-set-props-attrs
  pe-props PMASK-A-FROZEN and 0 pe-set-attrs
  pe-props PMASK-S-FROZEN and 1 pe-set-attrs
  pe-props $0F and 16 cfor ( propidx )
    dup i =  i 2+ pe-set-attrs
  endfor drop ;

|: pe-toggle
  hcur-udata <<
    -1 of?v| qaddr pe-props PMASK-A-FROZEN toggle |?
    -2 of?v| qaddr pe-props PMASK-S-FROZEN toggle |?
  else| dup 1 17 within not?< drop
        || 1- pe-props $F0 and or pe-props:! >? >>
  pe-set-props-attrs ;

\  pnames-buf block
create hot-prop-editor
  -1  6  0 " ATTR" mk-hot-item
  -2 13  0 " TILE" mk-hot-item
   1  0  2 " PROP #0     " mk-hot-item
   2 16  2 " PROP #1     " mk-hot-item
   3  0  4 " PROP #2     " mk-hot-item
   4 16  4 " PROP #3     " mk-hot-item
   5  0  6 " PROP #4     " mk-hot-item
   6 16  6 " PROP #5     " mk-hot-item
   7  0  8 " PROP #6     " mk-hot-item
   8 16  8 " PROP #7     " mk-hot-item
   9  0 10 " PROP #8     " mk-hot-item
  10 16 10 " PROP #9     " mk-hot-item
  11  0 12 " PROP #A     " mk-hot-item
  12 16 12 " PROP #B     " mk-hot-item
  13  0 14 " PROP #C     " mk-hot-item
  14 16 14 " PROP #D     " mk-hot-item
  15  0 16 " PROP #E     " mk-hot-item
  16 16 16 " PROP #F     " mk-hot-item
;hot-menu

false quan pe-names-loaded?

|: pe-fill-names
  pe-names-loaded? ?exit
  " LOADING TILE PROP NAMES" show-info-window
  " propname.dat" dos-open-r/o
  16 cfor
    \ pnames-buf block i 16 * +
    pad 16 dos-read pad
    ( caddr )
    i 2+ hot-prop-editor hot-find-by-index ?<
      hot-text drop 12 cmove
    || (dihalt) drop >?
  endfor
  dos-close
  close-window
  true to pe-names-loaded? ;


: prop-editor  ( props -- props )
  false pe-close?:! pe-props:!
  hcur-hide
  \ hcur-list pe-saved-hot-list:!
  hot-reset
  set-esc-arrow-cb >r
  arrow-hide
  0 2 32 19 @040 ( save-wsp) make-window
  pe-fill-names
  0 0 at ." MASKS:"
  hot-prop-editor hot-setup
  pe-set-props-attrs
  << ?ed-depth0
     hot-bt01!  ;; we want both buttons
     hot-menu-loop
     wait-loop-exit? ?v||
     hot-loop-bt1? ?v||
     hcur-udata ?< pe-toggle >?
  pe-close? not?^|| else| >>
  arrow-hide
  \ unshrink-window arrow-hide erase-window ( restore-wsp)
  fs-win \ draw-wk-room
  pe-props
  \ pe-saved-hot-list hot-setup
  r> restore-arrow-cb ;


zxlib-end
