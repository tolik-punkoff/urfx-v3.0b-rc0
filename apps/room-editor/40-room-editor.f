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


zxlib-begin" room editor"

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; room editor

;; current room we are working with
1 quan re-room#

false quan re-close?
false quan re-popup-closed?
false quan re-undo-valid?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple undo

;; to free-buf-start
: re-save-undo
  true re-undo-valid?:!
  tile-map free-buf-start 768 cmove
  attr-map free-buf-start 768 + 768 cmove
  prop-map free-buf-start 768 2* + 768 cmove ;

: re-restore-undo
  re-undo-valid? not?exit< 200 400 beep >?
  free-buf-start tile-map 768 cmove
  free-buf-start 768 + attr-map 768 cmove
  free-buf-start 768 2* + prop-map 768 cmove ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; popup window handlers

|: re-close-popup
  re-popup-closed? ?exit
  \ close-window
  arrow-hide
  unshrink-window erase-window fs-win
  true re-popup-closed?:! ;

|: re-run-tile-editor
  re-close-popup
  false re-undo-valid?:!
  tile-editor ;


|: re-save-room
  " SAVING ROOM" show-info-window
  re-room# save-wk-to-room
  re-room# 1+ #rooms max #rooms:!
  close-window
  re-close-popup ;

|: re-load-room
  " LOADING ROOM" show-info-window
  re-room# load-room-to-wk
  fix-wk-all-tile-attrs
  close-window
  re-close-popup
  draw-wk-room ;


|: re-save-wk-room
  " SAVING ROOM" show-info-window
  save-wk-room
  close-window
  re-close-popup ;

|: re-load-wk-room
  " LOADING ROOM" show-info-window
  load-wk-room
  fix-wk-all-tile-attrs
  close-window
  re-close-popup
  draw-wk-room ;


|: re-fill-toom-with-tile  ( tidx )
  tile-map over 768 fill
  tile-attr@ attr-map swap 768 fill
  prop-map 768 erase ;

|: re-fill-room
  bbar-ctile re-fill-toom-with-tile
  re-close-popup
  draw-wk-room ;

|: re-clear-room
  0 re-fill-toom-with-tile
  re-close-popup
  draw-wk-room ;

|: re-reset-attrs
  prop-map dup 768 + swap do $7F i and!c loop
  768 for
    i tile-map@  tile-attr@  i attr-map!
    i tile-map@  tile-prop@  i prop-map!
  endfor
  re-close-popup
  draw-wk-room ;

|: re-undo-room
  re-restore-undo
  re-close-popup
  draw-wk-room ;


|: re-popup-draw-room#
  e8-attr $40 or e8-attr:!
  0 18 at re-room# .#3
  e8-attr $40 ~and e8-attr:! ;

|: (re-inc/dec-factor)  ( -- n )
  CS/SS? ?< 10 || 1 >? ;

|: re-dec-room#
  re-room# (re-inc/dec-factor) -
  1 max re-room#:!
  re-popup-draw-room# ;

|: re-inc-room#
  re-room# (re-inc/dec-factor) +
  #rooms min re-room#:!
  re-popup-draw-room# ;


create hot-re-popup
  ['] re-run-tile-editor 0 0 " TILE EDITOR" mk-hot-item
  ['] re-save-room    0 2 " A:SAVE" mk-hot-item
  ['] re-load-room    9 2 " A:LOAD" mk-hot-item
  ['] re-fill-room    0 4 " FILL" mk-hot-item
  ['] re-clear-room   7 4 " CLEAR" mk-hot-item
  ['] re-undo-room   15 4 " UNDO" mk-hot-item
  ['] re-reset-attrs  0 6 " RESET CUSTOM ATTRS" mk-hot-item

  ['] re-dec-room#   -8 0 " \x02" mk-hot-item
  ['] re-inc-room#   -3 2 " \x03" mk-hot-item

  ['] re-load-wk-room    0 8 " A:WKLOAD" mk-hot-item
  ['] re-save-wk-room   11 8 " A:WKSAVE" mk-hot-item
;hot-menu


;; this destroys undo buffer (for now)
: re-popup-menu
  arrow-hide
  4 2 24 11 @050 make-window
  false re-popup-closed?:!
  set-esc-arrow-cb >r
  re-popup-draw-room#
  hot-re-popup hot-setup
  << hot-bt01!  ;; we want both buttons
     hot-menu-loop
     wait-loop-exit? ?v| re-close-popup |?
     hot-loop-bt1? ?v| re-close-popup |?
     hcur-udata ?< hcur-udata execute >?
  re-popup-closed? not?^|| else| >>
  r> restore-arrow-cb ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; process tile bar clicks

;; if right click, copy through undo buffer
|: re-proc-tbar  ( action-code )
  drop
  draw-bbar
  \ 1+ ?exit  ;; not a tile click? do nothing
; zx-inline


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; track main tile coords with changed paper

-1 quan re-last-arr-tile-xy

|: re-track-toggle
  re-last-arr-tile-xy dup 1+ not?exit< drop >?
  xy/wh-split cxy>attr @010 toggle ; zx-inline

|: re-track-hide
  re-track-toggle
  -1 re-last-arr-tile-xy:! ; zx-inline

|: (re-arrow-track-coord)  ( pk-xy )
  dup re-last-arr-tile-xy - not?exit< drop >?
  re-track-toggle
  dup hi-byte 21 u> ?< drop -1 >?
  re-last-arr-tile-xy:!
  re-track-toggle ; zx-inline

|: re-arrow-track
  km-pk-cxy@ (re-arrow-track-coord) ; zx-inline


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; tile drawing

false quan re-tdraw-erase?
false quan re-tdraw-16?
-1 quan re-tdraw-last-xy
-1 quan re-tdraw-last-set-xy

: re-put-tile-at  ( x y tidx )
  >r
  dup 0 22 within not?exit< 2drop rdrop >?
  over 0 32 within not?exit< 2drop rdrop >?
  2dup
  32* + ( x y mapofs | tidx )
  r@ over tile-map!
  r@ tile-attr@  over attr-map!
  r> tile-prop@  swap prop-map!
  1 draw-wk-tile-row ;

|: re-can-tdraw?  ( -- flag )
  re-tdraw-16? not?exit< true >?
  re-tdraw-last-xy
  re-tdraw-last-set-xy
  xor $0101 and 0= ;

|: re-tdraw-fill16  ( tidx tinc )
  >r >r
  re-tdraw-last-xy xy/wh-split
  ( x y | tinc tidx )
  2dup r@ re-put-tile-at  r> r@ + >r
  2dup 1+ r@ re-put-tile-at  r> r@ + >r
  under+1
  2dup r@ re-put-tile-at  r> r@ + >r
  1+ r> re-put-tile-at
  rdrop ;

|: re-tdraw-erase16  0 0 re-tdraw-fill16 ;
|: re-tdraw-set16    bbar-ctile 1 re-tdraw-fill16 ;

|: re-do-draw-16
  re-tdraw-erase? ?< re-tdraw-erase16 || re-tdraw-set16 >? ;

|: re-do-draw-8
  re-tdraw-last-xy xy/wh-split
  re-tdraw-erase? ?< 0 || bbar-ctile >?
  re-put-tile-at ;

|: re-handle-tdraw
  arrow-hide re-track-hide
  re-tdraw-last-xy xy/wh-split nip 21 u> ?exit
  re-can-tdraw? not?exit
  re-tdraw-last-xy re-tdraw-last-set-xy:!
  re-tdraw-16? ?< re-do-draw-16 || re-do-draw-8 >? ;

|: re-peek-tile
  km-cxy@ dup 21 > ?exit< 2drop >?
  32* + tile-map@
  tbar-set-tidx
  hot-loop-bt1? not?exit
  \ false re-undo-valid?:!
  bbar-ctile tile-prop@ prop-editor
  bbar-ctile tile-prop!
  \ arrow-show
  bbar-ctile fix-wk-tile-attrs draw-wk-room ;


: re-handle-butt
  cs/ss? 2 and ?exit< re-peek-tile >?
  re-save-undo
  hot-loop-bt1? re-tdraw-erase?:!
  cs/ss? 1 and re-tdraw-16?:!  ;; CS: 2x2 tile
  km-pk-cxy@ dup re-tdraw-last-xy:! re-tdraw-last-set-xy:!
  re-handle-tdraw re-arrow-track
  << arrow-show halt re-arrow-track
     km-butt hot-loop-butt!
     hot-loop-bt0|1? not?v||
     km-pk-cxy@ re-tdraw-last-xy - 0?^||
     km-pk-cxy@ re-tdraw-last-xy:!
     re-handle-tdraw
     re-tdraw-last-xy (re-arrow-track-coord)
  ^|| >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main mouse loop for room editor

: re-menu-loop
  wait-butt-release
  hot-menu-loop-reset-exits 0 hot-setup
  << arrow-show halt re-arrow-track
     km-butt hot-loop-butt!
     \ terminal? ?< quit >?
     lastk@ 7 = ?^|
       re-track-hide re-popup-menu wait-butt-release
       hot-menu-loop-reset-exits 0 hot-setup |?
     hot-loop-bt0|1? not?^||
  else| >>
  re-track-hide
  arrow-hide ;


: re-full-refresh
  fs-win
  arrow-hide
  draw-bbar
  draw-wk-room
  0 hot-setup ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; room editor entry point
\ <zx-normal>

: room-editor
  false re-close?:!
  false re-undo-valid?:!
  -1 re-last-arr-tile-xy:!
  re-full-refresh
  << ?ed-depth0
     hot-bt01!  ;; we want both buttons
     re-menu-loop
     km-tbar? dup ?^| re-proc-tbar |? drop
     hot-loop-bt0|1? ?< re-handle-butt >?
  re-close? not?^|| else| >>
  fs-win ;


zxlib-end
