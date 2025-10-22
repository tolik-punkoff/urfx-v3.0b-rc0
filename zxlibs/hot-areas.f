;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; hot areas (to use with the arrow)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
first, include arrow library and win8 base library:
  $zx-use <arrow-mouse>
  $zx-use <win8/win-base>

init arrow:
  init-kmouse

create some hot areas.
  create hot-abort-dialog
    ( udata) 0  ( x) 0  ( y) 2  " NO"  mk-hot-item
    ( udata) 1  ( x) 6  ( y) 2  " YES"  mk-hot-item
    ( udata) 2  ( x) 1  ( y) 3  ( width) 4  ( height) 2 mk-hot-area
  ;hot-menu -- it is necessary to call this!
WARNING! hot area size cannot be less than one char!
         but zero height means "skip this area".

you can call the following word to start the new menu:
  --hot-next-menu--  ( -- zx-addr )
it returns the starting address of the new menu definition.
note that you should not call `constant` immediately, because it will
disrupt the new menu!

setup hot areas:
  hot-abort-dialog hot-setup
note that calling `hot-setup` will print all textual items.
this sets `hcur-list`

run arrow selection:
  hot-menu-loop
on exit, the set of `hcur-*` will hold the selected item (if there was any).
   `hcur-udata` -- udata of the selected item, or 0
   `hcur-item^` -- the address of the selected item, or 0
note that the item will not be "uninverted" before exiting.

look at the bottom of the source code to learn more.

NOTE: this library expects "win8" print driver! hot menu coords are relative
      to the window. negative coords are allowed, and interpreted as coords
      from window right/bottom side.

TODO: add hooks to use other drivers.

textual items will have spaces added on both sides. you can control this
with the corresponding option.
*)

$zx-use <gfx/scradr>
$zx-use <win8/win-base>

;; set to `true` if you want to automatically add left and right space
true zx-lib-option OPT-HOT-SPACED-TEXT?
;; print two automatic spaces? useful for attr change
true zx-lib-option OPT-HOT-SPACED-TEXT-FULL-PRINT?
;; frame areas without text?
true zx-lib-option OPT-HOT-FRAME-RECT-AREAS?
;; frame areas with text?
true zx-lib-option OPT-HOT-FRAME-TEXT-AREAS?

;; draw somewhat rounded frame corners?
true zx-lib-option OPT-HOT-ROUNDED-FRAME?


zxlib-begin" hot-menu library"

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; hot areas (maybe with text)

(*
  hot area format:
    db x, y   ;; in window; negative means "from the right / bottom"
    db count, text...   ;; text to print
      special case: negative count means "length in chars", and
      height in chars follows
    dw udata
  end with $80
*)


 0 quan HCUR-LIST   ;; current active list
-1 quan HCUR-XY     ;; current char abs coords (init to impossible)
 0 quan HCUR-WH     ;; current width and height (in chars)
 0 quan HCUR-UDATA  ;; current udata
 0 quan HCUR-ITEM^  ;; current item


;; reset current item (but not list)
: HOT-RESET
  -1 to hcur-xy
  0 to hcur-wh
  0 to hcur-udata
  0 to hcur-item^
;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; item accessors

\ : HOT-END?  ( item^ -- end-flag )
\   dup ?exit< c@ $80 = >? drop true ;
;; it is used on each iteration, let's make it slightly faster
raw-code: HOT-END?  ( item^ -- end-flag )
  ld    a, h
  or    l
  ret   z
  ld    a, (hl)
  ld    hl, # 0
  cp    # $80
  ret   nz
  inc   l
;code
1 1 Succubus:setters:in-out-args
Succubus:setters:out-bool


;; move to the next hot item
\ : HOT-NEXT  ( item^ -- item^ )
\   2+ c@++ dup $80 and ?< drop 3 || 2+ >? + ;
;; it is used on each iteration, let's make it slightly faster
raw-code: HOT-NEXT  ( item^ -- item^ )
  inc   hl        ;; skip x
  inc   hl        ;; skip y
  ld    a, (hl)   ;; get count
  inc   hl        ;; skip count
  ld    d, # 0
  ld    e, a
  rla
  jr    nc, # .not-a-bar
  ld    e, # 1    ;; byte: height
.not-a-bar:
  ;; skip udata
  inc   e
  inc   e
  add   hl, de
;code
1 1 Succubus:setters:in-out-args


;; assembler code is both smaller and faster
0 [IF]
;; Forth code
|: HOT-X>ABS  ( x -- x )  dup $80 >= ?< c>s win-x1 || win-x0 >? + ; zx-inline
|: HOT-Y>ABS  ( y -- y )  dup $80 >= ?< c>s win-y1 || win-y0 >? + ; zx-inline

;; WARNING: no sanity check for `item^`!
: HOT-XY-ABS  ( item^ -- xabs yabs )
  c@++ hot-x>abs swap c@ hot-y>abs ; zx-inline

;; WARNING: no sanity check for `item^`!
: HOT-WH  ( item^ -- w h )
  2+ c@++ dup $80 < ?exit< nip [ OPT-HOT-SPACED-TEXT? ] [IF] 2+ [ENDIF] 1 >?
  c>s negate swap c@ ; zx-inline

;; this is used in the code
;; WARNING: no sanity check for `item^`!
: HOT-TEXT?  ( item^ -- bar? )
  2+ c@ $80 u< ; zx-inline

;; and this is not used
;; WARNING: no sanity check for `item^`!
: HOT-BAR?  ( item^ -- bar? )
  hot-text? not ; zx-inline

;; for bars, "random-addr 0"
;; WARNING: no sanity check for `item^`!
: HOT-TEXT  ( item^ -- addr count )
  2+ c@++ c>s 0max ; zx-inline

[ELSE]
;; asm code, faster and smaller

;; WARNING: no sanity check for `item^`!
code: HOT-XY-ABS  ( item^ -- xabs yabs )
  ex    de, hl
  ;; x
  ld    a, (de)
  inc   de
  ld    hl, # zx-['pfa] e8win-xy0
  or    a
  jp    p, # .x-positive
  ld    hl, # zx-['pfa] e8win-xy1
.x-positive:
  add   (hl)
  ld    l, a
  ld    h, # 0
  push  hl
  ;; y
  ld    a, (de)
  ld    hl, # zx-['pfa] e8win-xy0 1+
  or    a
  jp    p, # .y-positive
  ld    hl, # zx-['pfa] e8win-xy1 1+
.y-positive:
  add   (hl)
  ld    l, a
  ld    h, # 0
;code

;; WARNING: no sanity check for `item^`!
code: HOT-WH  ( item^ -- w h )
  inc   hl
  inc   hl
  ld    a, (hl)
  or    a
  jp    m, # .rect-area
  ;; text
  OPT-HOT-SPACED-TEXT? [IF]
  inc   a
  inc   a
  [ENDIF]
  ld    hl, # 1   ;; height
  ld    e, a
.done:
  ld    d, h      ;; zero D
  push  de
  next
.rect-area:
  neg
  ld    e, a
  inc   hl
  ld    l, (hl)
  ld    h, # 0
  jr    # .done
;code-no-next

;; this is used in the code
;; WARNING: no sanity check for `item^`!
raw-code: HOT-TEXT?  ( item^ -- bar? )
  inc   hl
  inc   hl
  ld    a, (hl)
  rla
  ccf
zx-hot-text-word-done:
  ld    a, # 0
  ld    h, a
  adc   a, a
  ld    l, a
;code

;; and this is not used
;; WARNING: no sanity check for `item^`!
raw-code: HOT-BAR?  ( item^ -- bar? )
  inc   hl
  inc   hl
  ld    a, (hl)
  rla
  jr    # zx-hot-text-word-done
;code-no-next

;; for bars, "random-addr 0"
;; WARNING: no sanity check for `item^`!
code: HOT-TEXT  ( item^ -- addr count )
  ex    de, hl
  inc   de
  inc   de
  ld    a, (de)
  ld    hl, # 0
  or    a
  jp    m, # .rect-area
  ld    l, a
.rect-area:
  inc   de
  push  de
;code
[ENDIF]

;; leave this in Forth, it is not speed-sensitive
;; WARNING: no sanity check for `item^`!
: HOT-UDATA  ( item^ -- udata )
  2+ c@++ dup $7F u> ?< drop 1+ || + >? @ ;

;; coords are absolute char coords.
;; WARNING: no sanity check for `item^`!
: HOT-INSIDE?  ( cx cy item^ -- inside? )
  \ dup 0?exit< 3drop false >?
  dup >r hot-xy-abs ( cx cy ix iy | item^ )
  rot swap -  nrot -  ( dy dx | item^ )
  2dup or -?exit< rdrop 2drop false >?
  r> hot-wh ( dy dx w h )
  nrot u< nrot u< and ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utilities

;; print item text, if there is any
;; WARNING: no sanity check for `item^`!
: HOT-ITEM-PRINT  ( item^ )
  \ dup hot-end? ?exit< drop >?
\ z:." hot-item-print: item=$" dup z:.hex4
\ z:."  text=" dup hot-text? z:0.r z:cr
  dup hot-text? not?exit< drop >?
  dup >r hot-xy-abs
  [ OPT-HOT-SPACED-TEXT? OPT-HOT-SPACED-TEXT-FULL-PRINT? forth:not forth:land ] [IF]
    under+1
  [ENDIF]
  xy/wh-join to e8-xy
  [ OPT-HOT-SPACED-TEXT? OPT-HOT-SPACED-TEXT-FULL-PRINT? forth:land ] [IF]
    bl wemit
  [ENDIF]
  r> hot-text wtype
  [ OPT-HOT-SPACED-TEXT? OPT-HOT-SPACED-TEXT-FULL-PRINT? forth:land ] [IF]
    bl wemit
  [ENDIF] ;

;; fill item rect with the given attribute
: HOT-ITEM-FILL-ATTR  ( attr item^ )
  dup hot-end? ?exit< 2drop >?
  swap >r
  ( item^ | attr )
  dup hot-xy-abs cxy>attr
  ( item^ attr$ | attr )
  swap hot-wh
  ( attr$ w h | attr )
  over -0?exit< 3drop rdrop >?
  ( attr$ w h | attr )
  cfor 2dup ( cfor:) r1:@ cfill 32+ endfor
  2drop rdrop ;


;; proc-cfa ( item^ -- res )
;; it is ok to pass additional args on the stack.
;; return non-zero to stop.
: HOT-FOREACH-EX  ( hot-list^ proc-cfa -- res//0 )
  >r  ( hot-list^ | proc-cfa )
  << dup hot-end? not?^|
       ;; this is so we could pass args on the stack
       dup r@ swap >r ( item^ proc-cfa | proc-cfa item^ )
       execute dup ?exit< 2rdrop >? drop
       r> hot-next |?
  else| rdrop drop 0 >> ;

;; proc-cfa ( item^ )
;; it is ok to pass additional args on the stack.
: HOT-FOREACH  ( hot-list^ proc-cfa )
  >r  ( hot-list^ | proc-cfa )
  << dup hot-end? not?^|
       ;; this is so we could pass args on the stack
       dup r@ swap >r ( item^ proc-cfa | proc-cfa item^ )
       execute
       r> hot-next |?
  else| rdrop drop >> ;


;; print text of all items
: HOT-PRINT  ( hot-list^ )
  hot-reset ['] hot-item-print hot-foreach ;

;; find item by index
: HOT-FIND-BY-INDEX  ( idx hot-list^ -- item^ TRUE // FALSE )
  << dup hot-end? not?^| over 0?exit< nip true >? under-1 hot-next |? else| 2drop 0 >> ;


|: (hot-find-at-cb)  ( cx cy item^ -- cx cy item^//0 )
  >r 2dup r@ hot-inside? negate r> and ;

;; find item at the given absolute char coords
: HOT-FIND-AT  ( cx cy hot-list^ -- item^ TRUE // FALSE )
  ['] (hot-find-at-cb) hot-foreach-ex ( cx cy item^//0 )
  nrot 2drop dup ?< true >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; draw frames around items

|: (hbar-or-lr)  ( scr$ w )
  ( left) over 1- $01 swap or!c  ( right) + $80 swap or!c ;

|: (frame-hbar)  ( absx absy w h )
  dup 0?exit< 4drop >?  ;; skip 0-height rects
  swap >r >r cxy>scr$  ( scr$ | w h )
  ;; top frame
  dup scr$^ r1:@
    [ OPT-HOT-ROUNDED-FRAME? ] [IFNOT] 2dup (hbar-or-lr) [ENDIF]
    $FF cfill
  ;; mid frame
  r> 8* cfor ( scr$ | w ) dup ( cfor:) r1:@ (hbar-or-lr) scr$v endfor
  ;; bottom frame
  r> [ OPT-HOT-ROUNDED-FRAME? ] [IFNOT] 2dup (hbar-or-lr) [ENDIF]
    $FF cfill ;


opt-hot-frame-text-areas? opt-hot-frame-rect-areas? forth:land [IF]
|: (need-frame?)  ( item^ -- flag )  drop true ; zx-inline
[ELSE]
  opt-hot-frame-text-areas? opt-hot-frame-rect-areas? forth:lor [IFNOT]
  |: (need-frame?)  ( item^ -- flag )  drop false ; zx-inline
  [ELSE]
  ;; only one is set
    opt-hot-frame-text-areas? [IF]
      opt-hot-frame-rect-areas? [IF] " wtf?!" error [ENDIF]
      |: (need-frame?)  ( item^ -- flag )  hot-text? ; zx-inline
    [ELSE]
      opt-hot-frame-text-areas? [IF] " wtf?!" error [ENDIF]
      |: (need-frame?)  ( item^ -- flag )  hot-bar? ; zx-inline
    [ENDIF]
  [ENDIF]
[ENDIF]

opt-hot-frame-text-areas? opt-hot-frame-rect-areas? forth:lor [IF]
|: (hot-draw-frames-cb)  ( item^ )
  [ opt-hot-frame-text-areas? opt-hot-frame-rect-areas? forth:land ] [IFNOT]
    dup (need-frame?) not?exit< drop >?
  [ENDIF]
  dup hot-xy-abs  rot hot-wh (frame-hbar) ;

: HOT-DRAW-FRAMES  ( hot-list^ )
  ['] (hot-draw-frames-cb) hot-foreach ;
[ELSE] \ no frames, no need for those words
: HOT-DRAW-FRAMES  ( hot-list^ )  drop ; zx-inline
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; check if the arrow is inside any item, and mark it

: (hot-inv-hbar)  ( absxy abswh )
  over 1+ not?exit< 2drop >?
  swap xy/wh-split
  cxy>scr$
  swap xy/wh-split
  dup 0?exit< 2drop >?
  cfor ( scr$ w )
    8 cfor 2dup cinv-mem-nc under+256 endfor
  swap 256- cscr$v swap endfor
  2drop ;

: (hot-inv-hbar-xarrow)  ( absxy abswh )
  arrow-save-hide >r (hot-inv-hbar) r> arrow-restore-state ;


;; hide selection (if there is any), and reset current item.
: HCUR-HIDE
  hcur-xy 1+ not?exit
  hcur-xy hcur-wh (hot-inv-hbar-xarrow) hot-reset ;

;; reset previous item mark, and mark current item
: HCUR-MARK-ITEM  ( item^ )
  dup hot-end? ?exit< drop hcur-hide >?
  dup hcur-item^ = ?exit< drop >? ;; just in case
  hcur-hide
  dup hot-wh dup 0?exit< 3drop >? ;; skip 0-height rects
  xy/wh-join to hcur-wh
  dup hot-xy-abs xy/wh-join to hcur-xy
  dup hot-udata to hcur-udata
  to hcur-item^
  hcur-xy hcur-wh (hot-inv-hbar-xarrow) ;


|: (HCUR-CHECK)
  km-cxy@
  hcur-item^ ?< 2dup hcur-item^ hot-inside? ?exit< 2drop >? >?
  hcur-list hot-find-at not?exit< hcur-hide >?
  hcur-mark-item ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main loop

;; called after each "halt" by waiters and loop
;; set "WAIT-LOOP-EXIT?" to exit
;; use "lastk@" to get key code
['] noop vect ARROW-IDLE
false quan WAIT-LOOP-EXIT?

;; mask for mouse buttons (on which buttons we should react)
1 quan hot-loop-bmask
;; acutally pressed buttons
0 quan (hot-loop-butt)

: HOT-LOOP-BUTT!0  (hot-loop-butt):!0 ; zx-inline
: HOT-LOOP-BUTT!  ( n )  (hot-loop-butt):c! ; zx-inline
: HOT-LOOP-BUTT   ( -- n )  (hot-loop-butt):c@ ; zx-inline


: WAIT-BUTT-RELEASE-NO-IDLE
  km-butt ?<
    arrow-pressed!
    arrow-show-force << halt km-butt ?^|| else| >>
  >?
  arrow-default! arrow-show-force ;


;; WARNING! this will not autoreset `WAIT-LOOP-EXIT?`!
: WAIT-BUTT-RELEASE
  km-butt ?<
    arrow-pressed!
    arrow-show-force << halt arrow-idle wait-loop-exit? ?v|| km-butt ?^|| else| >>
  >?
  arrow-default! arrow-show-force ;

;; WARNING! this will not autoreset `WAIT-LOOP-EXIT?`!
: WAIT-BUTT-PRESS
  wait-butt-release
  arrow-default! arrow-show-force
  << halt arrow-idle wait-loop-exit? ?v|| km-butt dup hot-loop-butt! 0?^||
  else| >> ;

: HOT-LOOP-BT0?   ( -- flag )  hot-loop-butt 1 mask8? ; zx-inline
: HOT-LOOP-BT1?   ( -- flag )  hot-loop-butt 2 mask8? ; zx-inline
: HOT-LOOP-BT0|1? ( -- flag )  hot-loop-butt 3 mask8? ; zx-inline

;; exit on which button?
: HOT-BT-NONE!  $00 hot-loop-bmask:c! ; zx-inline
: HOT-BT0!      $01 hot-loop-bmask:c! ; zx-inline
: HOT-BT1!      $02 hot-loop-bmask:c! ; zx-inline
: HOT-BT01!     $03 hot-loop-bmask:c! ; zx-inline

: HOT-MENU-LOOP-RESET-EXITS
  lastk-off wait-loop-exit?:!f
; zx-inline

: HOT-MENU-LOOP
  arrow-save-show >r
  wait-butt-release
  hot-menu-loop-reset-exits
  (hcur-check)
  << halt arrow-idle
     km-butt hot-loop-butt!
     (hcur-check)
     wait-loop-exit? ?v||
     hot-loop-butt hot-loop-bmask:c@ and 0?^||
  else| >>
  r> arrow-restore-state ;


;; will not call idle processor, and ignore `wait-loop-exit?`
: WAIT-BUTTON-OR-KEY
  arrow-visible? >r
  lastk-off
  wait-butt-release-no-idle
  ;; wait for press
  << halt lastk@ km-butt or8 0?^|| else| >>
  wait-butt-release-no-idle
  arrow-default!
  r> ?< arrow-show-force || arrow-hide >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; setup new hotlist

: HOT-SETUP  ( hot-list^ )
  hot-reset
  dup to hcur-list
  dup not?exit< drop >?
  dup hot-print hot-draw-frames ;


zxlib-end
