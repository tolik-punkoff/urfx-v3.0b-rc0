;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple windowing system
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$zx-use <win8/win-base>
$zx-use <gfx/scradr>

zxlib-begin" win8-high library"


;; this is used to save scr$ under windows, if necessary.
;; it goes from "free-buf-end" up.
;; 3,328 bytes.
zx-has-word? FREE-BUF-START [IFNOT]
$7300 constant FREE-BUF-START
[ENDIF]
zx-has-word? FREE-BUF-END [IFNOT]
$8000 constant FREE-BUF-END
[ENDIF]

FREE-BUF-END quan wsave-buf-top


;; set fullscreen window, reset save buffer
: WIN-REINIT
  fs-win
  free-buf-end to wsave-buf-top ;


;; save current window size, position, at-coords, attrs
: SAVE-WSP
  7 -to wsave-buf-top
  e8win-xy0 wsave-buf-top !
  e8win-xy1 wsave-buf-top 2+ !
  e8-xy wsave-buf-top 4+ !
  e8-attr wsave-buf-top 6 + c! ;

;; restore window size, position, at-coords, attrs saved with "SAVE-WSP"
: RESTORE-WSP
  wsave-buf-top @ to e8win-xy0
  wsave-buf-top 2+ @ to e8win-xy1
  wsave-buf-top 4+ @ to e8-xy
  wsave-buf-top 6 + c@ to e8-attr
  7 +to wsave-buf-top ;


;; size of buffer required for saving scr$ under the window
|: SVW-BUF#  ( -- size )
  win-w win-h 2dup 8* *  nrot * + ;

;; save current window area to temporary buffer
: SAVE-WINDOW
  win-w 0?exit win-h 0?exit
  svw-buf# negate +to wsave-buf-top  ;; alloc room
  ;; save screen$ data
  win-xy0 cxy>scr$ wsave-buf-top  ( scr$ dest )
  win-w >r win-h cfor ( scr$ dest | w )
    8 cfor
      2dup ( cfor:) r2:c@ cmove-nc
      ( cfor:) r2:c@ +  under+256
    endfor
    swap 256- cscr$v swap
  endfor nip
  ;; save attr data
  win-xy0 cxy>attr swap
  win-h cfor ( attr dest | w )
    2dup ( cfor:) r1:c@ cmove-nc
    ( cfor:) r1:c@ +  under+32
  endfor
  2drop rdrop ;

;; restore window saved with "SAVE-WINDOW"
: RESTORE-WINDOW
  win-w 0?exit win-h 0?exit
  wsave-buf-top win-xy0 cxy>scr$  ( src scr$ )
  win-w >r win-h cfor ( src scr$ | w )
    8 cfor
      2dup ( cfor:) r2:@ cmove-nc
      ( cfor:) r2:c@ under+  256+
    endfor
    256- cscr$v
  endfor drop
  ;; restore attr data
  win-xy0 cxy>attr
  win-h cfor ( src attr | w )
    2dup ( cfor:) r1:c@ cmove-nc
    ( cfor:) r1:c@ under+  32+
  endfor
  2drop rdrop
  ;; adjsust buffer pointer
  svw-buf# +to wsave-buf-top ;


0o117 quan info-window-attr
0o116 quan info-text-attr
false quan info-window-centered?

: INFO-WINDOW-ATTRS!  ( window text )
  info-text-attr:! info-window-attr:! ;

: (PRINT-INFO-WINDOW)  ( addr count do-save-wsp do-save-scr$ )
  >r ?< save-wsp >?
  0max 30 min
  30 over -  info-window-centered? ?< 2u/ 10 || 0 >?
  2over nip 2+  3
\ endcr >r >r ." x=" swap . ." y=" . r> r> ." w=" swap . ." h=" . cr quit
  mk-window
  arrow-save-hide r> ?< save-window >? >r
  info-window-attr to e8-attr attr-fill-window frame-window shrink-window
  info-text-attr to e8-attr wtype
  r> arrow-restore-state ;


;; automatically restores the previous window WSP (but not scr$)
: PRINT-INFO-WINDOW  ( addr count )
  true false (print-info-window)
  restore-wsp ;


;; use "CLOSE-WINDOW" to close it
: SHOW-INFO-WINDOW  ( addr count )
  true true (print-info-window) ;


;; close window opened by "OPEN-WINDOW" or by "SHOW-INFO-WINDOW"
: CLOSE-WINDOW
  unshrink-window
  arrow-hide
  restore-window
  restore-wsp ;

;; doesn't save anything.
;; FIXME: no checks!
: (MAKE-WINDOW)  ( x y w h attr save? )
  >r to e8-attr mk-window r> ?< save-window >?
  attr-fill-window frame-window shrink-window ;

;; saves previous window size and scr$ occupied by the new window.
;; FIXME: no checks!
: OPEN-WINDOW  ( x y w h attr )
  arrow-hide
  save-wsp
  true (make-window) ;

;; doesn't save anything.
;; FIXME: no checks!
: MAKE-WINDOW  ( x y w h attr )
  false (make-window) ;


: KM-WIN-XY@  ( -- x y )  km-xy@ win-y0 8* - swap win-x0 8* - swap ;
: KM-WIN-CXY@ ( -- x y )  km-cxy@ win-y0 - swap win-x0 - swap ;


zxlib-end
