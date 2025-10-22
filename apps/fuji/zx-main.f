$zx-use <emit8-rom>
$zx-use <gfx/plot>
$zx-use <prng>

<zx-done>
extend-module TCOM

: (xor-str)  ( addr count )
  for dup c@ $A5 xor over c! 1+ endfor
  drop
;


shadow-helpers current!
*: X"
  zx-?in-colon
  34 parse-qstr
  zsys-run: (")
  zx-bstr-$new
  dup count (xor-str)
  ir:tail ir:node:str$:! ;
tcom current!


end-module TCOM
<zx-definitions>


code: (ROM-XTYPE)  ( addr count )
  ex    de, hl
  pop   hl
  push  iy
  restore-iy
.loop:
  ld    a, d
  or    a
  jp    m, # .done
  ld    a, e
  or    a
  jr    z, # .done
  ld    a, (hl)
  xor   # $A5
  rst   # $10
  inc   hl
  dec   de
  jr    # .loop
.done:
  pop   iy
  pop   hl
;code
2 0 Succubus:setters:in-out-args

$include "10-beepfx.f"

(*
           #
 #####    # #
#     #    #
#      #   #
 #      #  #
  ######   #
 #############
#             #
 #############
*)


;; horizontal spans
create snail-body
   1 c,  0 c, 13 c,
   0 c,  1 c,  1 c,
  14 c,  1 c,  1 c,
   1 c,  2 c, 13 c,
   2 c,  3 c,  6 c,
   1 c,  4 c,  1 c,
   8 c,  4 c,  1 c,
   0 c,  5 c,  1 c,
   7 c,  5 c,  1 c,
   0 c,  6 c,  1 c,
   6 c,  6 c,  1 c,
   1 c,  7 c,  5 c,
  $80 c,
create;


10 quan snail-x
10 quan snail-new-x

15 constant snail-width

create snail-ypos
  snail-width zx-allot0
create;

create snail-new-ypos
  snail-width zx-allot0
create;


: snail-translate  ( x y )
  negate over snail-x - snail-ypos + c@ +
; zx-inline

: snail-pixel  ( x y )
  snail-translate pxor ; zx-inline

: draw-snail-body
  snail-body << ( addr )
    c@++ dup $80 = ?v||
    ( addr x )
    snail-x +
    swap c@++
    ( x addr y )
    swap c@++
    ( x y addr width )
    swap >r
    cfor 2dup snail-pixel under+1 endfor
    2drop
  r> ^|| >>
  2drop ;

: draw-snail-eyes
  snail-x 11 +  3 snail-translate
  ( xbase ybase )
  4 for 2dup pxor 1- endfor
  2dup 1- pxor
  over 1- over pxor
  under+1 pxor ;

: (draw-snail)
  draw-snail-body
  draw-snail-eyes ; zx-inline



: draw-hill-old
  80 for i 191 pxor endfor
  256 80 - for i 80 + 190 i - pxor endfor
;


: draw-hill
  80 for i 191 pxor endfor
  80 190  ( x y )
  <<
    over 256 < ?^|
      urnd8 16 umod 1+
      for 2dup pxor under+1 1- endfor
      urnd8 6 umod 1+
      for 2dup pxor under+1 endfor
    |?
  else| 2drop >>
;


;; Jet_burst
create fx-lightning
  2 c, ;; noise
    13 , ;; duration 1
    1600 , ;; duration 2
    12 c, ;; pitch
    6 c, ;; slide
  0 c,
create;


0 quan killed-by-lightning?
0 quan dig-x
0 quan dig-y

create lt-xpos
  256 zx-allot0
create;

: find-dig-y
  8 << dig-x over point not?^| 1+ |? else| >>
  dig-y:!
;

: draw-lightning
  dig-y cfor
    dig-x urnd8 3 umod 1- +
    dup lt-xpos i + c!
    i pxor
  endfor
;

: erase-lightning
  dig-y cfor
    lt-xpos i + c@ i pxor
  endfor
;

: dig-down
  dig-x dig-y pxor dig-y:1+! dig-x dig-y pxor
;


: lightning
  urnd8 160 umod 88 + dig-x:!
  find-dig-y

  draw-lightning
  \ dig-down
  $5800 768 @007 fill 0 border
  fx-lightning beepfx
  erase-lightning
  $5800 768 @070 fill 7 border

  dig-x  snail-x 1-  snail-x snail-width + 2 +  within killed-by-lightning?:!
;


: draw-final-hill
  256 for i 191 pxor endfor
;


: init-snail  ( y )
  snail-width for dup i snail-ypos + c! endfor
  drop
  10 snail-x:!
  (draw-snail)
  snail-ypos snail-new-ypos snail-width cmove
  snail-x snail-new-x:!
;


0 quan gravity-count

: snail-pixel-gravity  ( xofs )
  dup snail-ypos + c@
  ( xofs ybase )
  over snail-new-x + over 1+ point
  ?exit< 2drop >?
  over snail-new-x + swap point ?< -1 || 1 gravity-count:1+! >?
  swap snail-new-ypos + +!c
; zx-inline

: snail-gravity
  gravity-count:!0
  snail-width for i snail-pixel-gravity endfor
; zx-inline


: draw-snail
  halt
  \ 0 border
  (draw-snail)
  snail-gravity
  snail-new-ypos snail-ypos snail-width cmove
  snail-new-x snail-x:!
  (draw-snail)
  \ 1 border
; zx-inline


0 quan screens-left
0 quan key-down?

: check-key
  inkey-ex <<
    [char] P of?v| key-down?:!t |?
    \ 32 of?v| lightning |?
  else| drop >>
; zx-inline


: draw-game-state
  X" \x16\x00\x00Miles left: " (rom-xtype)
  screens-left decw>str (rom-type)
;

0 quan screens-left-save

: init-game
  100 screens-left:!
  screens-left $A45A xor screens-left-save:!
  cls
  draw-game-state
  draw-hill
  100 init-snail
  \ 150 snail-new-x:!
  \ draw-snail
;


raw-code: (DIHALT2)
  zxemut-normal-speed
  di
  xor   a
  ld    c, # $AA
.dihalt-loop:
  inc   a
  xor   c
  rlc   c
  out   $fe (), a
  jp    # .dihalt-loop
;code-no-next zx-no-return zx-mark-as-used
0 0 Succubus:setters:in-out-args

: cheater-check
  screens-left-save $A45A xor screens-left = not?<
    cls
    X" CHEATER!!!" (rom-xtype)
    2 border
    (dihalt2) >?
; zx-inline

0 quan lightining-timeout

: new-lightning-timeout
  60 urnd8 2u/c + lightining-timeout:!
;

: check-lightning
  lightining-timeout:1-!
  lightining-timeout -?<
    new-lightning-timeout
    lightning >?
;

: game-loop
  key-down?:!f killed-by-lightning?:!f
  new-lightning-timeout
  <<
    [ 1 ] [IF]
      halt halt halt
    [ENDIF]
    draw-snail
    sys: ?depth-0
  gravity-count snail-width = ?^||
  else| >>
  <<
    [ 1 ] [IF]
    cheater-check halt check-key
    cheater-check halt check-key
    cheater-check halt check-key
    [ENDIF]
    key-down? ?<
      snail-x 1+ snail-new-x:!
      key-down?:!f
      snail-new-x 255 snail-width - > ?<
        screens-left:1-!
        screens-left $A45A xor screens-left-save:!
        cls
        draw-hill
        189 init-snail
        65 snail-new-x:!
        draw-game-state
      >?
    >?
    cheater-check
    draw-snail
    cheater-check
    check-lightning
    sys: ?depth-0
    killed-by-lightning? ?v||
  screens-left ?^||
  else| >>
;

: game-finished
  cls
  draw-final-hill
  190 init-snail
  65 snail-new-x:!
  X" \x16\x08\x08\x12\x01CONGRATURATIONS!" (rom-xtype)
  X" \x16\x09\x08\x12\x01YOU HAVE REACHED" (rom-xtype)
  X" \x16\x0A\x03\x12\x01THE TOP OF THE \x10\x02MOUNT FUJI\x10\x00!" (rom-xtype)

  X" \x16\x0C\x00\x12\x00MEET \x11\x04THE SNAIL\x11\x07 AGAIN IN THE NEXT" (rom-xtype)
  X" \x16\x0D\x02EXITING GAME: \x12\x01\x10\x03DOWN THE FUJI\x12\x00\x10\x00!" (rom-xtype)
;


create logo
  0 c, 0 c, $80 c,
  0 c, 0 c, $80 c,
  0 c, 0 c, $80 c,
  15 c, 1 c,  24 c, 1 c,  48 c, 1 c,  0 c, 0 c, $80 c,
  16 c, 1 c,  23 c, 1 c,  48 c, 1 c,  0 c, 0 c, $80 c,
  7 c, 19 c,  14 c, 1 c,  48 c, 1 c,  0 c, 0 c, $80 c,
  7 c, 1 c,  17 c, 1 c,  14 c, 1 c,  22 c, 6 c,  20 c, 1 c,  0 c, 0 c, $80 c,
  7 c, 1 c,  17 c, 1 c,  14 c, 1 c,  20 c, 2 c,  1 c, 1 c,  4 c, 2 c,  9 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  7 c, 1 c,  1 c, 15 c,  1 c, 1 c,  14 c, 1 c,  18 c, 2 c,  3 c, 2 c,  5 c, 1 c,  8 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  40 c, 1 c,  17 c, 2 c,  4 c, 2 c,  6 c, 1 c,  7 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  9 c, 15 c,  16 c, 1 c,  16 c, 2 c,  5 c, 2 c,  6 c, 1 c,  7 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  9 c, 1 c,  13 c, 1 c,  7 c, 20 c,  6 c, 1 c,  6 c, 1 c,  8 c, 1 c,  6 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  9 c, 1 c,  13 c, 1 c,  16 c, 1 c,  16 c, 1 c,  5 c, 2 c,  8 c, 1 c,  6 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  9 c, 15 c,  16 c, 1 c,  15 c, 1 c,  6 c, 2 c,  8 c, 1 c,  6 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  40 c, 1 c,  15 c, 1 c,  6 c, 2 c,  8 c, 1 c,  6 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  40 c, 1 c,  15 c, 1 c,  6 c, 1 c,  9 c, 1 c,  6 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  8 c, 17 c,  15 c, 1 c,  15 c, 1 c,  5 c, 2 c,  9 c, 1 c,  6 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  8 c, 1 c,  7 c, 1 c,  7 c, 1 c,  15 c, 1 c,  15 c, 1 c,  5 c, 2 c,  8 c, 1 c,  7 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  8 c, 1 c,  7 c, 1 c,  7 c, 1 c,  15 c, 1 c,  15 c, 1 c,  5 c, 1 c,  9 c, 1 c,  7 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  8 c, 17 c,  15 c, 1 c,  16 c, 1 c,  3 c, 2 c,  8 c, 1 c,  8 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  8 c, 1 c,  7 c, 1 c,  7 c, 1 c,  15 c, 1 c,  16 c, 2 c,  2 c, 2 c,  7 c, 1 c,  9 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  8 c, 1 c,  7 c, 1 c,  7 c, 1 c,  15 c, 1 c,  17 c, 4 c,  6 c, 2 c,  10 c, 1 c,  8 c, 1 c,  7 c, 1 c,  0 c, 0 c, $80 c,
  8 c, 17 c,  15 c, 1 c,  25 c, 2 c,  12 c, 18 c,  0 c, 0 c, $80 c,
  8 c, 1 c,  15 c, 1 c,  7 c, 18 c,  47 c, 1 c,  0 c, 0 c, $80 c,
  0 c, 0 c, $80 c,
  0 c, 0 c, $80 c,
  0 c, 0 c, $80 c,
  0 c, 0 c, $80 c,
 $80 c,
create;


83 quan logo-x
30 quan logo-y

50 quan curr-logo-x
50 quan curr-logo-y

: draw-logo-line  ( addr -- next-line-addr )
  logo-x curr-logo-x:!
  <<
    c@++ dup $80 = not?^|
      curr-logo-x:+!
      c@++ for curr-logo-x curr-logo-y pxor curr-logo-x:1+! endfor
    |?
  else| drop >> ;

: draw-logo
  logo-y curr-logo-y:!
  logo <<
    dup c@ $80 = not?^|
      draw-logo-line
      curr-logo-y:1+!
    |?
  else| drop >> ;

: game-menu
  7 border 7 paper 0 ink 0 bright 0 flash 0 inverse 0 gover
  cls
  draw-logo
  X" \x16\x08\x0B\x12\x01Fuji no Yama\x12\x00" (rom-xtype)
  \ X" \x16\x0B\x0BThe game of" (rom-xtype)
  \ X" \x16\x0C\x05patience and meditation." (rom-xtype)
  X" \x16\x0B\x05The thrilling game with" (rom-xtype)
  X" \x16\x0C\x00\x11\x06\x13\x01100\x11\x07\x13\x00 screens of non-stop action!" (rom-xtype)
  X" \x16\x0E\x09CONTROLS: \x10\x02OPQAM\x10\x00" (rom-xtype)
  X" \x16\x10\x06Press \x11\x04SPACE\x11\x07 to play." (rom-xtype)
  X" \x16\x15\x00\x10\x01Epic Incredible Games production\x10\x00" (rom-xtype)
  0
  <<
    halt
    inkey-ex 32 = not?^|
      1- dup -?< 100 100 bleep  drop 30 >?
    |?
  else| drop >>
;


create fx-game-over
  1 c,    10 , 400 , 400 , 65516 , 128 ,
  1 c,    10 , 400 , 0 , 0 , 0 ,
  1 c,    10 , 400 , 350 , 65516 , 96 ,
  1 c,    10 , 400 , 0 , 0 , 0 ,
  1 c,    10 , 400 , 300 , 65516 , 64 ,
  1 c,    10 , 400 , 0 , 0 , 0 ,
  1 c,    10 , 400 , 250 , 65516 , 32 ,
  1 c,    10 , 400 , 0 , 0 , 0 ,
  1 c,    10 , 400 , 200 , 65516 , 16 ,
  0 c,
create;

: game-over
  7 border 7 paper 0 ink 0 bright 0 flash 0 inverse 0 gover
  \ cls

  fx-game-over beepfx
  X" \x16\x07\x08\x12\x01YOU WAS KILLED BY" (rom-xtype)
  X" \x16\x08\x0A\x12\x01\x10\x02THE LIGHTNING\x10\x00" (rom-xtype)

  X" \x16\x0B\x03\x12\x00Not every snail can reach" (rom-xtype)
  X" \x16\x0C\x04the top of \x11\x02\x10\x07MOUNT FUJI\x11\x07\x10\x00." (rom-xtype)

  X" \x16\x10\x03Press \x11\x04SPACE\x11\x07 to try again." (rom-xtype)

  << halt inkey-ex 32 = not?^|| else| >>
  << halt inkey-ex 32 = ?^|| else| >>
;


: RUN
  sys: no-rom-im1
  game-menu
  sys: ?depth-0
  sys: frames @ urandomize
  <<
    init-game
    game-loop
    killed-by-lightning? ?^|
      game-over
      game-menu
      sys: ?depth-0
    |?
  else| >>
  game-finished
  (dihalt)
; zx-no-return


turnkey-pass2? [IF]
<zx-done>
$include "98-custom-loader.f"
<zx-definitions>
[ENDIF]
