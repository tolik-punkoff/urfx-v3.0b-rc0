$zx-use <emit8-rom>

$zx-use <gfx/plot>
$zx-use <gfx/line>

\ $zx-use <rom-fp>

: RND
  23670 @ 75 UUD* 75 0 D+ OVER
  OVER U< - - 1 - DUP 23670 !
  UUD* SWAP DROP ;
: RANDOM 23672 @ 23670 ! ;


\ 6 BORDER 5 PAPER CLS
: GR 1 -  8 * UDG 1 - + DUP 8 + DO I C! -1 +LOOP ;

224 CONSTANT X08

: SETUP
  0   3  12  16  46  42  78  64  1 GR
  0 192  48   8 116  84 114   2  2 GR
 65  65  44  39  17  12   3   0  3 GR
130 130  52 228 136  48 192   0  4 GR
  0   0   0   0   0   0   0   1  5 GR
  0  28  54  34  54 124 224 192  6 GR
  3   7  14  28  56  52   8   0  7 GR
128   0   0   0   0   0   0   0  8 GR
255 255 252 248 240 240 248 252  9 GR
255 255  63  31  15  15  31  63  10 GR
254 254 252 252 248 240 255 255  11 GR
127 127  63  63  31  15 255 255  12 GR
  0   7   7   7   7 127 127 127  13 GR
  0 X08 X08 X08 X08 254 254 254  14 GR
127 127 127   7   7   7   7   0  15 GR
254 254 254 X08 X08 X08 X08   0  16 GR
  0   8  28  60 127  63  31  15  17 GR
  0  16  56 124 254 252 248 240  18 GR
 15  31  63 127  60  28   8   0  19 GR
240 248 252 254 124  56  16   0  20 GR
170  85 170  85 170  85 170  85  21 GR
;


0 VARIABLE MX 0 VARIABLE MY
0 VARIABLE DX 0 VARIABLE DY
\ RANDOM

0 VARIABLE KX
0 VARIABLE KY
\ 7 PAPER 7 BORDER CLS
0 VARIABLE KEY?
1 VARIABLE MAZE
0 VARIABLE SCORE
3 VARIABLE LIVES
\ 3 PAPER 4 INK

: PRMAN 1 INK MX @ MY @ OVER 1+ OVER AT ." íì" AT ." êë" ;

: PRBLANK
  7 PAPER 0 INK
  MX @ MY @ OVER 1+ OVER
  AT 2 SPACES AT 2 SPACES ;

: PRMAZE
  3 PAPER 4 INK
  MAZE @ 5 * 5 + FOR
  10 RND 2* 14 RND 2* OVER 1+
  OVER AT ." §§" AT ." §§" ENDFOR 7
  PAPER 10 RND 2* DX ! 30 DY ! DX
  @ DY @ OVER 1+ OVER 2 INK AT
  ." öõ" AT ." òô" 8 RND 2* 4 +
  KX ! 16 KY ! KX @ KY @ OVER 1+
  OVER 3 INK AT ." ñó" AT ." îï"
  57 23695 C! 2 0 AT ."     "
  3 0 AT ."     " ;

: TUNE1 1000 500 DO 10 I BLEEP 50 +LOOP ;
: TUNE2 500 1000 DO 10 I BLEEP I -5 / +LOOP ;

\ PRMAZE PRMAN

: PAUSE 32767 FOR ENDFOR ;

: CLRS 0 INK 7 PAPER 0 BRIGHT 0 FLASH CLS ;

: NMAZE
  5 FOR TUNE1 TUNE2 ENDFOR
  1 MAZE +! PAUSE
  MX OFF MY OFF ;

: TUNE3
 1500 500 DO 50 I BLEEP 100 +LOOP
 400 600 DO 30 I BLEEP -25 +LOOP
 10 FOR TUNE2 ENDFOR ;

\ 6 BORDER TUNE3


0 VARIABLE CX
0 VARIABLE CY
0 VARIABLE SX
0 VARIABLE SY

\ 0 VECT (RESTART)

: FIN
  50 FOR 127 87 PLOT 255 RND 175 RND DRAW ENDFOR
  10 FOR TUNE1 ENDFOR
  CLRS 5 9 AT ." You scored " 2 INK
  SCORE @ . 1 INK 7 7 AT
  ." You reached maze "
  3 INK MAZE @ . 1 INK 9 3 AT
  ." Press SPACE to play again."
  (*
  ." To replay type......."
  235 23695 C!
  11 11 AT ." âÉÇÑÉÜ"
  12 11 AT ." äÑåÖ Ö"
  13 11 AT ." ÜåäÅåâ"
  *)
  0 INK 7 PAPER 0 BRIGHT 0 FLASH
  TUNE3
  [ zx-used-word? KCUR ] [IF] KCUR OFF [ENDIF]
  BEGIN KEY 32 = UNTIL
  (RESTART) ;

: CRASH
  10 FOR 256 FOR I 254
  OUTP ENDFOR ENDFOR 6 BORDER
  -1 LIVES +! LIVES @
  0IF FIN ENDIF MX OFF MY OFF
  18 SX ! 28 SY ! PAUSE CLRS 28
  23695 C! PRMAZE PRMAN TUNE3 ;

: Z 23672 OFF ;

: A
  10000 23672 @ - 75 /
  SCORE +! SCORE @ 0MAX
  SCORE ! ;


: CHECK
  MX @ 20 U> MY @ 30 U>
  OR IF CRASH ENDIF
  MX @ MY @ ATTR CASE
    231 OF CRASH ENDOF
    28 OF CRASH ENDOF
    58 OF KEY? @ 0IF CRASH ELSE
       KEY? OFF 100 SCORE +!
       NMAZE CLRS A 28 23695 C!
       PRMAZE PRMAN Z ENDIF ENDOF
    59 OF KEY? ON TUNE1
    10 SCORE +! ENDOF ENDCASE ;

: DOWN 2 MX +! ;
: UP -2 MX +! ;
: LEFT -2 MY +! ;
: RIGHT 2 MY +! ;

: MOVE
  INKEY
  PRBLANK CASE
  [CHAR] O OF LEFT ENDOF
  [CHAR] P OF RIGHT ENDOF
  [CHAR] Q OF UP ENDOF
  [CHAR] A OF DOWN ENDOF
  \ [CHAR] H OF QUIT ENDOF
  ENDCASE
  CHECK PRMAN TUNE2 ;

: PRSC
  0 23659 C! 15 23695 C!
  21 0 AT CR ." Score:" SCORE @
  5 .r 2 SPACES ." Maze:" MAZE @
  2 .r 2 SPACES ." Lives:" LIVES @
  2 .r 2 SPACES
  57 23695 C! 2 23659 C! ;

: PRBLCS
  57 23695 C! CX @ CY @
  OVER 1+ OVER AT 2 SPACES AT 2
  SPACES SX @ SY @ OVER 1+ OVER
  AT 2 SPACES AT 2 SPACES ;

: >+-2
  > IF 2 ELSE -2 ENDIF ;

: PRSHAPE
  231 23695 C!
  CX @ CY @ OVER 1+ OVER AT
  ." ûü" AT ." úù" SX @ SY @
  OVER 1+ OVER AT ." ¢£" AT
  ." †°" 57 23695 C! ;

: SHMOVE
  KEY? @
  0IF 3 INK KX @ KY @ OVER 1+
    OVER AT ." ñó" AT ." îï" 2
    INK DX @ DY @ OVER 1+ OVER
    AT ." öõ" AT ." òô"
  ENDIF
  PRBLCS MAZE @ 4 < IF
    2 CY ! 28 SY ! 3 RND 1 - 2*
    CX +! 3 RND 1- 2* SX +!
  ELSE MAZE @ 5 > IF 26 CY ! ENDIF
  MAZE 4 = IF 16 CY ENDIF
  MX @ SX @ = IF 20 SX ! ENDIF
  23672 @ 3 MOD 0IF MX @ SX @ >+-2 SX +! ENDIF
  MAZE @ 4 > IF MX @ CX @ >+-2 CX +! ENDIF
  MY @ SY @ >+-2 SY +! MAZE @
  5 > IF MY @ CY @ >+-2 CY +! ENDIF
 ENDIF
 SX @ 0MAX 20 MIN SX !
 SY @ 0MAX 28 MIN SY !
 CX @ 0MAX 20 MIN CX !
 CY @ 0MAX 28 MIN CY !
 PRSHAPE ;

: GAME
  BEGIN CHECK MOVE PRSC SHMOVE AGAIN ;

: INST
  CLRS 1 INK 9 2 AT
  ." Do you want instructions?"
  [ zx-used-word? KCUR ] [IF] KCUR OFF [ENDIF]
  KEY UPCHAR
  [CHAR] Y = IF 2 BORDER 2 PAPER
  7 INK CLS
  ." ãÉàãÉÖÉÜÅáÉÅáÉÖÉÇ" CR
  ." éåÇéàÖåâ Ö  Ö Öå" CR
  ." ä ää ÖÅà Ö  Ö Ö" CR
  ." ÉÉ ÉÉÅ Å Å ÅÉÉÅÉÇ" CR
  CR CR 6 INK
  ."   The object of the "
  ." game is to" CR
  ." gain as many points as" CR
  ." possible by picking up the"
  CR ." key and using it to"
  ."  unlock" CR ." the door. "
  1 BRIGHT ." BUT" 0 BRIGHT
  ."  you must" CR
  ." avoid the shapes which" CR
  ." are trying to catch you."
  CR
  ." At each new maze "
  ." the shapes" CR
  ." become more difficult "
  ." to avoid." CR CR
  ."    Press any key to "
  ." continue" KEY DROP CLS
  CR CR 5 INK ." Controls:"
  7 INK CR CR 4 SPACES
  ." O  Left" 7 SPACES
  ." P  Right" CR CR 4 SPACES
  ." A  Down" 7 SPACES
  ." Q  Up" CR CR CR
  5 INK ." Scores:" CR 7 INK CR
  ."  Picking up the key scores"
  CR 20 SPACES ." 10 points" CR
  CR
  ."  Unlocking the door scores"
  CR 19 SPACES ." 100 points" CR
  CR
  ."  If you complete a maze "
  ." quickly  you will get "
  ." bonus points" CR
  ."  depending on your time" CR
  CR CR 2 SPACES
  ."  Press any key to continue"
  KEY DROP ENDIF 7 PAPER
  6 BORDER 1 INK CLRS
  [ zx-used-word? KCUR ] [IF] KCUR ON [ENDIF]
;

: (RESTART)
  SYS: SP0! SYS: RP0!
  MX OFF MY OFF MAZE ON
  3 LIVES ! SCORE OFF
  10 CX ! 10 SX !
  2 CY ! 28 SY !
  CLRS
  28 23693 C!
  PRMAZE PRMAN
  RANDOM Z GAME ;

: GO
  HERE 128 + UDG!
  SETUP
  INST
  RANDOM
  (RESTART) ;
