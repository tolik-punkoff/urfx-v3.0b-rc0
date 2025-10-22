( for debugging )
true constant START-AS-MAX?
true constant BENCHMARK-INIT?

( field size )
12 quan fld-width
10 quan fld-height

( used to select easy/normal/hard games )
10 quan mines-divisor

( cell types: [0..8] is open cell with the corresponding number )
( `9` is mine )
9 constant mine-value

( mask to get cell value only )
$0F constant value-mask ( `AND` with this to get the value w/o flags )
$F0 constant flags-mask ( `AND` with this to get the flags only )
$80 constant open-flag  ( flag at bit 7 )
$40 constant mark-flag  ( flag at bit 6 )

( playfield position on the screen )
0 quan fld-x-ofs
0 quan fld-y-ofs

( our code starts at $8000, so use unallocated space )
$6200 constant field^
field^ 32 - constant lchgf^  ( line-was-changed flag )
$6500 constant free-cells^
0 quan #free-cells


zx-has-word? TSFX-PLAY [IF]
alias-for tsfx-play is sfx-play
[ELSE]
alias-for drop is sfx-play
[ENDIF]


( ***************************************** )
( * various helpers                       * )
( ***************************************** )

(* check if the number is in [0..max) range *)
\ : IN-RANGE?  ( index max -- bool )
  \ 0 swap within ;
\ alias-for U< is IN-RANGE?
: IN-RANGE?  ( index max -- bool )
  u< ; zx-inline

: X-IN-RANGE?  ( x -- bool )
  fld-width in-range? ; zx-inline

: Y-IN-RANGE?  ( y -- bool )
  fld-height in-range? ; zx-inline

: XY-IN-RANGE?  ( x y -- bool )
  y-in-range? swap x-in-range? and ; zx-inline


( ***************************************** )
( * line-was-changed array access         * )
( ***************************************** )

: LCG-CLEAR-ALL
  lchgf^ 24 0 fill ; zx-inline

: LCG-SET-ALL
  lchgf^ 24 1 fill ; zx-inline

: (LCG!)  ( y value )
  over y-in-range? if  swap lchgf^ + c! exit endif
  2drop ;

: LCG-CHANGED!  ( y )
  dup 1- 1 (lcg!)
  dup 1+ 1 (lcg!)
  1 (lcg!) ; zx-inline

: LCG-UNCHANGED!  ( y )
  0 (lcg!) ; zx-inline

: LCG?  ( y -- flag )
  dup y-in-range? ifnot drop false exit endif
  lchgf^ + c@ ;


( ***************************************** )
( * field array access                    * )
( ***************************************** )

( calculate address of the given field position byte; no range checks! )
: (FLD)  ( x y -- addr )
  fld-width * + field^ + ; zx-inline

( get field cell value; out-of-bounds cells are considered empty and open )
: FLD@  ( x y -- value )
  2dup xy-in-range? if (fld) c@ else 2drop open-flag endif ; zx-inline

( set field cell value; ignore out-of-bounds cells )
: FLD!  ( value x y )
  2dup xy-in-range? if (fld) c! else 3drop endif ; zx-inline

( useful to avoid `rot rot fld!` copypasta )
: !FLD  ( x y value )
  nrot
  2dup xy-in-range? if (fld) c! else 3drop endif ; zx-inline


( ***************************************** )
( * initialise field and free cells list  * )
( ***************************************** )

: (FC)  ( idx -- addr )  2* free-cells^ + ; zx-inline
: FC@  ( idx -- value )  (fc) @ ; zx-inline
: FC!  ( value idx )     (fc) ! ; zx-inline

: ADD-FC  ( x y )
  join-bytes #free-cells fc!
  1 +to #free-cells ; zx-inline

: GET-FC  ( idx )
  fc@ split-bytes ; zx-inline


( shuffle free cells list )
: SHUFFLE-FREE-CELLS
  #free-cells 2 < ?exit
  0 #free-cells do
\  z:." iter: i=" i z:. z:." lim=" i' z:0.r z:cr
    urnd16  i umod  ( j )
    dup fc@      ( j [j] )
    i 1- fc@ rot fc!
    i 1- fc!
   loop-1 ;
\   -1 +loop ;

: sd
  #free-cells for i fc@ . endfor cr ;

( clear playing field )
: FLD-CLEAR
  fld-height fld-width *
  field^ over erase  ;; zero array
  ;; setup the number of the free cells
  dup to #free-cells
  ;; write cell offsets
  for i dup fc! endfor
  shuffle-free-cells ;

( debug field print )
: .FDP
  fld-height cfor
    fld-width cfor
      i j fld@ value-mask and 48 + emit
    endfor cr
  endfor ;


: ?0THROW  ( flag addr count )
  rot ifnot cr ." ERROR: " type cr ( abort) (dihalt) endif
  2drop ;

( set/change field size )
: SET-FIELD-SIZE  ( width height )
  over 0 33 within " invalid width" ?0throw
  dup 0 24 within " invalid height" ?0throw
  to fld-height to fld-width
  ( fld-clear) ;


( ***************************************** )
( * cell helpers                          * )
( ***************************************** )

( get rid of "opened" flag )
: CELL-VALUE  ( value -- bool )
  value-mask and ; zx-inline

: CELL-FLAGS  ( value -- flags-only )
  flags-mask and ; zx-inline

: CELL-EMPTY?  ( value -- bool )
  value-mask and 0= ; zx-inline

: CELL-MINE?  ( value -- bool )
  cell-value mine-value = ; zx-inline

: CELL-OPEN?  ( value -- bool )
  open-flag mask? ; zx-inline

: CELL-MARKED?  ( value -- bool )
  mark-flag mask? ; zx-inline


( ***************************************** )
( * generate new playing field            * )
( ***************************************** )

( increment cell value, if not a mine )
: INC-CELL  ( x y )
  2dup fld@ cell-value dup mine-value < if  ( x y value )
    1+ !fld
  else ( mine! ) 3drop
  endif ; zx-inline

( set new mine, increment neighbour numbers )
: PUT-MINE-THERE  ( x y )
  2dup mine-value !fld  ( set mine )
  ( increment neighbour values )
  under-1 1-
  3 for
    3 for
      2dup inc-cell
      1+
    endfor
    3 - under+1
  endfor
  2drop ;

( check if there are some free cells left )
: ?HAVE-CELLS
  #free-cells " out of free cells" ?0throw ; zx-inline

( get random free cell )
: FIND-RANDOM-CELL  ( -- x y )
  ?have-cells
  #free-cells 1- dup to #free-cells
  fc@ fld-width /mod ;

( put new random mine )
: NEW-RANDOM-MINE
  find-random-cell put-mine-there ; zx-inline

: N-RANDOM-MINES  ( n )
  for new-random-mine endfor ; zx-inline

(*
: TEST0
  cls
  fld-clear 12 n-random-mines
  .fdp ;
*)


( ***************************************** )
0 quan GAME-OVER?
0 quan TOTAL-MINES
0 quan MARKED-MINES
0 quan OPENED-CELLS

: CALC-MINES-NUMBER  ( -- value )
  fld-width fld-height * mines-divisor / 1 max ;

: NEW-FIELD
  fld-clear
  calc-mines-number to total-mines
  0 to marked-mines
  0 to opened-cells
  false to game-over?
  total-mines n-random-mines ;


( ***************************************** )
( * proper field printing                 * )
( ***************************************** )

( restore attributes *)
: NORM-ATTR
  0o070 e8-attr:! ; zx-inline

( print marked cell )
: .MARKED
  0o036 e8-attr:! 33 emit norm-attr ; zx-inline

( print mine cell )
: .MINE
  0o127 e8-attr:! 42 emit norm-attr ; zx-inline

( print closed cell )
: .CLOSED
  0o170 e8-attr:! 35 emit norm-attr ; zx-inline

( print empty cell )
: .EMPTY
  0o060 e8-attr:! 46 emit norm-attr ; zx-inline

( print digit cell )
: .DIGIT  ( value )
  cell-value dup 2 u/ e8-ink!  48 + emit  norm-attr ; zx-inline

( print cell )
: .CELL  ( value )
  dup cell-marked? if drop .marked exit endif
  dup cell-open? ifnot drop .closed exit endif
  dup cell-empty? if drop .empty exit endif
  dup cell-mine? if drop .mine exit endif
  .digit ;

: .CELL-AT  ( x y )
  2dup xy-in-range? ifnot 2drop exit endif
  2dup fld-y-ofs + swap fld-x-ofs + at
  fld@ .cell ;


( debug field print )
: .FIELD
  fld-height cfor
    i fld-y-ofs + fld-x-ofs at
    fld-width cfor
      i j fld@ .cell
    endfor cr
  endfor ;


( ***************************************** )
( * debug                                 * )
( ***************************************** )

( ***************************************** )
( * cell utilities                        * )
( ***************************************** )

( this will also print the new cell )
: (OPENED-AT!)  ( x y )
  2dup fld@ cell-open? if 2drop exit endif
  ( x y )
  dup lcg-changed!
  2dup
  2dup fld@ open-flag or !fld
  .cell-at
  ( adjust counter )
  1 +to opened-cells ;

: OPEN-ALL
  fld-height cfor
    fld-width cfor
      i j (opened-at!)
    endfor
  endfor ;

: OPEN-ALL-MINES
  fld-height cfor
    fld-width cfor
      i j fld@ cell-mine? ?< i j (opened-at!) >?
    endfor
  endfor ;

: FLDMAX
  32 23 set-field-size ;

: TEST1
  cls ." initialising..."
  new-field
  cls open-all ;


( **************************************************************************** )

( ***************************************** )
( * open cell with floodfill              * )
( ***************************************** )

( empty, closed, not marked )
: EMPTY-AT?  ( x y -- flag )
  fld@ 0= ; zx-inline

( scan line in the given direction )
: SCAN-LINE-IN-DIR  ( x y dir -- xs )
  >r  ( save direction )
  begin  ( x y | dir )
    r@ under+
    2dup empty-at?
  0until
  ( x y | dir )
  ( check if stopped on the mark, and backup )
  2dup fld@ cell-marked? if r@ under- endif
  r> 2drop ( drop direction and y ) ;

( open line )
: OPEN-SPAN  ( x0 x1 y )
  nrot  ( y x0 x1 )
  1+ swap do
    i over (opened-at!)
  loop drop ; zx-inline

( find line edges and make it open )
: SCAN-AND-FILL-LINE  ( x y -- x0 x1 )
  tuck  ( y x y )
  2dup -1 scan-line-in-dir  ( y x y x0 )
  nrot 1 scan-line-in-dir  ( y x0 x1 )
  rot  ( x0 x1 y )
  >r 2dup r> open-span  ( x0 x1 ) ;

( main algo )
: FLOOD-FILL  ( x y )
  2dup fld@ dup cell-open? if 3drop exit endif
  dup cell-marked? if 3drop exit endif
  cell-value if (opened-at!) exit endif
  ( recurse )
  dup >r  ( x y | y )
  scan-and-fill-line  ( x0 x1 | y )
  2dup r@ 1- nrot  ( x0 x1 y-1 x0 x1 )
  1+ swap do i over recurse loop drop
  ( x0 x1 | y )
  r> 1+ nrot
  1+ swap do i over recurse loop drop ;

false quan auto-mode?

( high-level "open cell" word )
: OPEN-AT  ( x y )
  2dup fld@  ( x y value )
  dup cell-marked? ?exit<
    auto-mode? not?< 14 sfx-play >?
    3drop >?
  dup cell-open? ?exit<
    auto-mode? not?< 14 sfx-play >?
    3drop >?
  cell-mine? if (opened-at!) true to game-over? exit endif
  auto-mode? not?<
    \ 2dup fld@ cell-value 0?< 11 sfx-play >?
    11 sfx-play
  >?
  \ (mspd-on)
  flood-fill
  \ (mspd-off)
;


( ***************************************** )
( * cell mark management                  * )
( ***************************************** )

( this will also print the modified cell )
: TOGGLE-MARK-AT  ( x y )
  2dup fld@  ( x y value )
  dup cell-open? if 3drop exit endif
  over lcg-changed!
  mark-flag xor
  ( fix mark counter )
  dup mark-flag and if 1 else -1 endif +to marked-mines
  ( x y newvalue )
  >r 2dup r> !fld
  .cell-at ;

: SET-MARK-AT  ( x y )
  2dup fld@  ( x y value )
  dup cell-open? if 3drop exit endif
  cell-marked? if 2drop exit endif
  toggle-mark-at ; zx-inline


( ***************************************** )
( * QoL utilities                         * )
( ***************************************** )

0 quan cc-count
0 vect cc-pred

( count neighbours with the given predicate )
: CELL-COUNT-NGB  ( x y pred-cfa )
  to cc-pred  cc-count:!0
  under-1 1-
  3 for
    3 for
      2dup cc-pred ?< cc-count:1+c! >?
      1+
    endfor
    3 - under+1
  endfor 2drop ;


( a mine or a mark )
: CC-PRED-MINE?  ( x y -- flag )
  fld@ dup cell-marked? swap mine-value = or ;

: CC-PRED-MARK?  ( x y -- flag )
  fld@ cell-marked? ;

: CC-PRED-CLOSED?  ( x y -- flag )
  fld@ cell-open? not ;

( check if the given cell has correct number of mines around )
: CELL-OK-MINES?  ( x y -- flag )
  2dup ['] cc-pred-mine? cell-count-ngb
  fld@ cell-value cc-count = ;

( is number of closed cells equal to number of mines? )
: CELL-OK-CLOSED?  ( x y -- flag )
  2dup ['] cc-pred-closed? cell-count-ngb
  fld@ cell-value cc-count = ;

: CELL-OK-MARKS?  ( x y -- flag )
  2dup ['] cc-pred-mark? cell-count-ngb
  fld@ cell-value cc-count = ;


: CC-PRED-OPEN-IT  ( x y -- false )
  open-at 0 ;

: CC-PRED-MARK-IT  ( x y -- false )
  set-mark-at 0 ;

: OPEN-AROUND  ( x y )
  ['] cc-pred-open-it cell-count-ngb ; zx-inline

: MARK-AROUND  ( x y )
  ['] cc-pred-mark-it cell-count-ngb ; zx-inline


( ***************************************** )
( * cell selection                        * )
( ***************************************** )

0 quan CURSOR-X
0 quan CURSOR-Y
0 quan ABORT-GAME?

: CUR-SCR-X  ( -- x )  cursor-x fld-x-ofs + ; zx-inline
: CUR-SCR-Y  ( -- y )  cursor-y fld-y-ofs + ; zx-inline

: .CURSOR  ( on )
  \ inverse
  \ cursor-x cursor-y .cell-at
  \ 0 inverse ;
  ?< cur-scr-x cur-scr-y cxy>attr dup c@ 0o077 xor swap c!
  || cursor-x cursor-y .cell-at >? ;

: WAIT-KEY  ( -- key )
  arrow-save-show
  0 begin drop inkey? dup until
  swap arrow-restore-state
  upchar ;

: WAIT-MOUSE-PRESS
  hot-bt01! 0 hot-setup wait-butt-press ; zx-inline

: SELECT-CELL-OLD  ( -- exit-char )
  begin
    true .cursor
    wait-key
    false .cursor
    case
      [char] Q of 0 -1 true endof
      [char] A of 0  1 true endof
      [char] O of -1 0 true endof
      [char] P of 1  0 true endof
    otherwise drop false ( exit flag ) endcase
  while
    cursor-y + fld-height + fld-height mod to cursor-y
    cursor-x + fld-width + fld-width mod to cursor-x
  repeat ;


false quan was-at-abort-button?

: (INV-ABORT-BUTTON)
  12 23 256 * + $0107 (hot-inv-hbar-xarrow) ; zx-inline

: AT-ABORT-BUTTON?  ( -- flag )
  km-cxy@ 23 =
  swap 12 19 within
  and ;

: (INV-CELL)
  was-at-abort-button? ?exit< (inv-abort-button) >?
  cursor-x +0?< cur-scr-x cur-scr-y xy/wh-join $0101 (hot-inv-hbar-xarrow) >? ;

: KM-FLD-XY@  ( -- x y )
  km-cxy@ swap fld-x-ofs -  swap fld-y-ofs - ; zx-inline


\ : ABORT-DIALOG-OK  abort-game:!t ;
\ : ABORT-DIALOG-NO  abort-game:!f ;

create hot-abort-dialog
  0  0 2 " NO" mk-hot-item
  1 -5 2 " YES" mk-hot-item
;hot-menu

\ ABORT GAME?
\ NO      YES

: ABORT-DIALOG-ARROW-CB
  lastk@ <<
    7 of?v| 1 |?
    13 of?v| 2 |?
  else| drop 0 >>
  dup ?exit< wait-loop-exit?:! >? drop
  [ zx-has-word? default-arrow-cb ] [IF] default-arrow-cb [ENDIF]
;

: SHOW-ABORT-DIALOG
  12 sfx-play
  arrow-idle:@ >r
  \ [ zx-has-word? default-arrow-cb ] [IF] ['] default-arrow-cb [ELSE] ['] noop [ENDIF]
  ['] abort-dialog-arrow-cb arrow-idle:!
  10 10 13 5 0o017 open-window
  ." ABORT GAME?"
  hot-abort-dialog
  0o117 e8-attr:!
  hot-setup
  hot-menu-loop
  wait-loop-exit? ?< wait-loop-exit? 2 = || hcur-udata >?
  dup wait-loop-exit?:! abort-game?:!
  close-window
  wait-butt-release hot-loop-butt!0
  hot-reset hcur-list:!0
  lastk-off r> arrow-idle:! ;


: ARROW-IDLE-CB
  ;; "ESC" means "ABORT GAME"
  [ zx-has-word? default-arrow-cb ] [IF] default-arrow-cb [ENDIF]
  lastk@ 7 =  terminal? or ?< show-abort-dialog >?
  km-fld-xy@ 2dup xy-in-range? ?<
    was-at-abort-button? not?<
      over cursor-x -  over cursor-y -  or 0?exit< 2drop >? >?
    (inv-cell) was-at-abort-button?:!f
    cursor-y:! cursor-x:!
    (inv-cell)
  || 2drop
     at-abort-button? ?exit<
      was-at-abort-button? ?exit
      (inv-cell) -1 cursor-x:!
      was-at-abort-button?:!t (inv-cell) >?
    (inv-cell) -1 cursor-x:!
    was-at-abort-button?:!f >? ;

: SELECT-CELL  ( -- exit-char )
  hot-bt01!
  0 hot-setup
  arrow-show
  lastk-off
  -1 cursor-x:! was-at-abort-button?:!f
  arrow-idle:@ >r ['] arrow-idle-cb arrow-idle:!
  arrow-idle-cb
  <<
    abort-game? ?exit< r> arrow-idle:! 7 >?
    wait-loop-exit?:!f
    wait-butt-press
    ;; hack!
    hot-loop-bt1? ?<
      km-cxy@ 23 = swap 31 = and ?exit<
        (inv-cell) arrow-hide 12
        r> arrow-idle:! >?
    >?
    was-at-abort-button? ?^|
      show-abort-dialog abort-game? ?exit< r> arrow-idle:! 7 >? |?
    km-fld-xy@ xy-in-range? not?^| 9 sfx-play |?
  else| >>
  r> arrow-idle:! arrow-hide
  (inv-cell)
  km-fld-xy@ cursor-y:! cursor-x:!
  hot-loop-bt0? ?< 13 || 32 >? ;


: ALL-CELLS-OPENED?  ( -- flag )
  fld-width fld-height * total-mines -  opened-cells = ; zx-inline

( print current game status )
: .STATUS
  23 0 at
  0o050 e8-attr:!
  ." MARKS:" marked-mines 3 .r
  \ 11 spaces
  0o052 e8-attr:!
  ."    <ABORT>  "
  0o051 e8-attr:!
  ."   MINES:" total-mines 3 .r
  norm-attr ;

alias-for ?ED-DEPTH0 IS DEBUG-CHECK-STACK

( ***************************************** )
( * cell open and autoplay                * )
( ***************************************** )

(*
: CAN-AUTOPLAY-CELL?  ( x y -- flag )
  under-1 1-
  3 for
    3 for
      2dup fld@ cell-open? not?exit< unloop unloop 2drop true >?
      1+
    endfor
    3 - under+1
  endfor
  2drop false ;
*)

: DO-OPEN
  ( open closed cell )
  cursor-x cursor-y fld@ cell-open? not?exit<
    cursor-x cursor-y open-at
  >?
  ( the cell is already open, check if we can auto-open )
  auto-mode? not?< 5 sfx-play >?
  \ cursor-x cursor-y can-autoplay-cell? not?exit
  auto-mode?:!t
  cursor-x cursor-y cell-ok-closed? if
    cursor-x cursor-y mark-around
  endif
  cursor-x cursor-y cell-ok-marks? if
    cursor-x cursor-y open-around
  endif
  auto-mode?:!f ;

open-flag 1+ constant da-lo
open-flag mine-value + constant da-hi

: DBG-ONE-AUTO
  cursor-x cursor-y
  fld-height cfor
    i lcg? if
      0 to cursor-x i to cursor-y 1 .cursor
      begin
        i lcg-unchanged!
        fld-width cfor
          i j fld@ da-lo da-hi within if
            auto-mode?:!t
            i to cursor-x  j to cursor-y  do-open
            [ maxspeed-autoopen? ] [IF] (mspd-on) [ENDIF]
          endif
        endfor
        .status
      i lcg? 0until
      \ 0 0 at i lcg? .
      0 to cursor-x i to cursor-y 0 .cursor
    endif
  endfor
  to cursor-y to cursor-x ;

: DBG-ALL-AUTO
  [ maxspeed-autoopen? ] [IF] (mspd-on) [ENDIF]
  lcg-set-all
  begin
    opened-cells marked-mines
    dbg-one-auto
    marked-mines =  swap opened-cells =  and
  until
  auto-mode?:!f
  [ maxspeed-autoopen? ] [IF] (mspd-off) [ENDIF] ;


( ***************************************** )
( * main game loop                        * )
( ***************************************** )

: GAME-LOOP
  abort-game?:!f
  begin
    .status
    debug-check-stack
    game-over? all-cells-opened? or
  0while
    select-cell
    case
      32 of 3 sfx-play cursor-x cursor-y toggle-mark-at endof  ( cell selector will update the cell )
      13 of do-open endof
      \ [char] ! of quit endof
      \ [char] @ of cls .field endof
      12 of dbg-all-auto endof
       7 of exit endof
    endcase
  repeat ;


( ***************************************** )
( * game startup -- initialisation        * )
( ***************************************** )

( collect cells using the given predicate into free-cells )
( pred-cfa: x y -- ok-flag )
: COLLECT-CELLS  ( pred-cfa )
  0 to #free-cells
  fld-height cfor
    fld-width cfor
      dup i j rot execute if i j add-fc endif
    endfor
  endfor drop ;

: PRED-EMPTY  ( x y -- ok-flag )
  fld@ 0= ;

: PRED-ANY  ( x y -- ok-flag )
  fld@ 9 < ;

( find random empty cell )
: FIND-EMPTY-CELL  ( -- x y )
  ['] pred-empty collect-cells #free-cells ifnot
    ['] pred-any collect-cells #free-cells ifnot
      cr ." ERROR: no free cells!" (dihalt)
    endif
  endif
  urnd16 #free-cells umod
  get-fc ;

( open random empty cell )
: OPEN-EMPTY-CELL
  find-empty-cell
  over to cursor-x dup to cursor-y
    \ 2dup 1- toggle-mark-at  ( debug )
  open-at ;


( ***************************************** )
( * main menu and other UIs               * )
( ***************************************** )

: .GAME-RESULT-OLD
  fld-height 0 at
  game-over? if
    0o327 e8-attr:!
    ."   *** GAME OVER ***  "
  else
    all-cells-opened? if
      0o141 e8-attr:!
      ." THE WINNER IS YOU! ;-)"
    endif
  endif
  norm-attr ;

: .GAME-RESULT
  \ info-window-centered?:!t
  game-over? if
    13 sfx-play
    open-all-mines
    wait-mouse-press
    0o127 0o126 info-window-attrs!
    "   GAME OVER  " print-info-window
  else
    all-cells-opened? if
      13 sfx-play
      0o140 0o141 info-window-attrs!
      "  THE WINNER IS YOU! ;-) " print-info-window
    endif
  endif
  norm-attr ;

1 quan DIFFICULTY
create difdivs
  13 c,
  10 c,
  7 c,
create;

: .DIFFICULTY
  0o170 e8-attr:!
  difficulty case
    0 of ."   EASY  " endof
    1 of ."  NORMAL " endof
    2 of ."   HARD  " endof
  otherwise drop ."  <BAD>  " endcase
  0o070 e8-attr:!
  difficulty difdivs + c@ to mines-divisor ;

: .MENU-TEXT
  3 8 at ." FIELD WIDTH: "
  5 8 at ." FIELD HEIGHT:"
  7 8 at ." DIFFICULTY:" ;

: .MENU-UPDATE
  3 21 at fld-width 2 .r
  5 21 at fld-height 2 .r
  7 20 at .difficulty
  9 12 at ."  ("
  calc-mines-number 0.r ."  mines)   " ;

: FIX-FIELD-DIMENSIONS
  fld-width 8 max 32 min to fld-width
  fld-height 8 max 23 min to fld-height ;


: MMENU-DEC-WIDTH  1 -to fld-width ;
: MMENU-INC-WIDTH  1 +to fld-width ;
: MMENU-DEC-HEIGHT  1 -to fld-height ;
: MMENU-INC-HEIGHT  1 +to fld-height ;
: MMENU-DIFF-CLICK  difficulty 1+ 3 umod to difficulty ;

: MMENU-MIN-WIDTH  1 fld-width:! ;
: MMENU-MAX-WIDTH  99 fld-width:! ;
: MMENU-MIN-HEIGHT  1 fld-height:! ;
: MMENU-MAX-HEIGHT  99 fld-height:! ;

create hot-main-menu
  ['] mmenu-dec-width 24 3 " \x02" mk-hot-item
  ['] mmenu-inc-width 28 3 " \x03" mk-hot-item

  ['] mmenu-dec-height 24 5 " \x02" mk-hot-item
  ['] mmenu-inc-height 28 5 " \x03" mk-hot-item

  ['] mmenu-diff-click 20 7 8 1 mk-hot-area

  \ ['] mmenu-min-width  1 3 " MIN" mk-hot-item
  ['] mmenu-max-width 1 3 " MAX" mk-hot-item
  \ ['] mmenu-min-height 1 5 " MIN" mk-hot-item
  ['] mmenu-max-height 1 5 " MAX" mk-hot-item

  -1 12 12 " START GAME" mk-hot-item
;hot-menu


: MENU-ARROW-CB
  lastk@ 13 = ?exit< wait-loop-exit?:!t >?
  [ zx-has-word? default-arrow-cb ] [IF] default-arrow-cb [ENDIF]
;

: MENU
  cls
  .menu-text
  0o170 e8-attr:!
  hot-main-menu hot-setup
  0o070 e8-attr:!
  \ [ zx-has-word? default-arrow-cb ] [IF] ['] default-arrow-cb [ELSE] ['] noop [ENDIF]
  ['] menu-arrow-cb arrow-idle:!
  true  ;; redraw flag
  <<
    fix-field-dimensions
    >r debug-check-stack r>
    ?<
      arrow-hide
      hcur-hide
      .menu-update
      arrow-show
    >?
    debug-check-stack
    hot-menu-loop
      \ hot-loop-bt1? ?< 10 sfx-play >?
    wait-loop-exit? ?v||
    hcur-udata 1+ 0?v||
    hcur-udata ?^| 2 sfx-play hcur-udata execute true |?
  ^| false | >>
  5 sfx-play
  [ zx-has-word? default-arrow-cb ] [IF] ['] default-arrow-cb [ELSE] ['] noop [ENDIF]
  arrow-idle:!
  arrow-hide ;

: (RUN)
  [ START-AS-MAX? ] [IF]
    99 to fld-width
    99 to fld-height
    2 to difficulty
  [ENDIF]
  hot-bt01!
  arrow-hide
  norm-attr
  7 dup tsfx-border! border
  cls
  menu
  \ cls
  \ ." initializing..."
  \ info-window-centered?:!t
  0o117 0o116 info-window-attrs!
  " INITIALISING" print-info-window
  [ 1 ] [IF]
    sys: frames @ urandomize
  [ENDIF]
  [ BENCHMARK-INIT? ] [IF]
    BENCH-START
  [ENDIF]
  new-field
  [ BENCHMARK-INIT? ] [IF]
    BENCH-END
    FS-WIN
    ." \ctime: " .BENCH-TIME cr
    \ (dihalt)
    wait-button-or-key
  [ENDIF]
  32 fld-width - 2/ fld-x-ofs:!
  23 fld-height - 2/ fld-y-ofs:!
  cls .field
    open-empty-cell  ( open one random empty space )
  game-loop
  arrow-hide
  abort-game? 0?<
    .game-result
    arrow-show
    wait-mouse-press >?
  recurse-tail ;
zx-no-return

: RUN
  \ fs-win setup-e8-driver
  \ $4000 @ drop
  sys: rom-im1-last
  init-tsfx  ;; must be the first, the arrow library will call it
  init-kmouse arrow-default!
  info-window-centered?:!t  ;; global setting
  (run) ;
