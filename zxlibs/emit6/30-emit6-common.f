;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 42/64 columns driver, common code
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


: INK@     ( -- n )  SYS: P-FLAG C@ $10 AND IF 9 EXIT ENDIF SYS: ATTR-P C@ 7 AND ;
: PAPER@   ( -- n )  SYS: P-FLAG C@ $40 AND IF 9 EXIT ENDIF SYS: ATTR-P C@ 8u/ 7 AND ;
: BRIGHT@  ( -- n )  SYS: ATTR-P C@ $40 AND 0<> ;
: FLASH@   ( -- n )  SYS: ATTR-P C@ $7F U> ;
: GOVER@   ( -- flag )  SYS: P-FLAG C@ $03 AND 0<> ;
: INVERSE@ ( -- flag )  SYS: P-FLAG C@ $0C AND 0<> ;

: INK     ( n )  DUP 9 U> IF DROP EXIT ENDIF 16 (ROM-EMIT-ATTR) ;
: PAPER   ( n )  DUP 9 U> IF DROP EXIT ENDIF 17 (ROM-EMIT-ATTR) ;
: FLASH   ( n )  18 (ROM-EMIT-ATTR) ;
: BRIGHT  ( n )  19 (ROM-EMIT-ATTR) ;
: INVERSE ( n )  0<> 0<> DUP TINV 20 (ROM-EMIT-ATTR) ;
: GOVER   ( n )  0<> 0<> DUP TOVER 21 (ROM-EMIT-ATTR) ;


;; common "CLS" code
raw-code: (CLS)
  push  hl
  push  iy
  restore-iy
  ;; fix attrs
  ld    hl, () sysvar-attr-p
  ld    sysvar-attr-t (), hl
  ;; reset scroll count
  OPT-EMIT6-SC#? [IF]
  ld    hl, # 0
  ld    zx-['pfa] SC# (), hl
  [ENDIF]
  ;; reset "cursor printed" bit
  OPT-EMIT6-KCUR? [IF]
  ld    hl, # zx-['pfa] KCUR
  res   4, (hl)
  [ENDIF]
  ;; clear scr$
  ld    hl, # $4000
  ld    de, # $4001
  ld    bc, # 6144
  ld    (hl), # 0
  ldir
  ;; set attr$
  ld    bc, # 767
  ld    a, () sysvar-attr-p
  ld    (hl), a
  ldir
 0 ( OPT-CUSTOM-EMIT?) [IFNOT]
  ;; we need to have at least one line in the bottom area for ROM printing
  ld    a, # 1
  ld    sysvar-defsz (), a
  ;; open chan #2
  ld    a, # 2
  call  # $1601
  ;; print whole 24 lines
  xor   a
  ld    sysvar-defsz (), a
  ;; no scroll prompt
  dec   a
  ld    sysvar-scr-ct (), a
  ;; AT 0, 0
  ld    a, # 22
  rst   # $10
  xor   a
  rst   # $10
  xor   a
  rst   # $10
 [ENDIF]
  pop   iy
  pop   hl
;code


;; scroll up
code-raw: (SCROLL)
  push  hl
  push  iy
  restore-iy
  call  # $0DFE ;; CL-SC-ALL
  ;; set attribute for the lower part
  ld    hl, # $5800 23 32 * +
  ld    de, # $5800 23 32 * + 1+
  ld    a, () sysvar-attr-p
  ld    (hl), a
  ld    bc, # 31
  ldir
  OPT-EMIT6-SC#? [IF]
  ld    hl, # zx-['pfa] SC#
  inc   (hl)
  [ENDIF]
  pop   iy
  pop   hl
;code


code: 6Y@  ( -- y )
  push  hl
  ld    hl, () emit6y
  ld    h, # 0
;code

code: 6X@  ( -- y )
  push  hl
  ld    hl, () emit6x
  ld    h, # 0
;code

code: 6Y!  ( y )
  ld    a, l
  ld    emit6y (), a
;code-pop-tos

code: 6X!  ( y )
  ld    a, l
  ld    emit6x (), a
;code-pop-tos


|: (XCLS)  0 6X! 0 6Y! (CLS) ;

: (AT@)  ( -- y x )  6Y@ 6X@ ;

: (AT)  ( y x -- )
  0MAX [ #COLS 1- ] {#,} MIN 6X!
  0MAX 23 MIN 6Y! ;


|: (.CCX)  (EMIT-RAW) SYS: MASK-P C! TINV TOVER [ zx-has-word? OBL? ] [IF] 0 TO OBL? [ENDIF] ;

OPT-EMIT6-KCUR? [IF]
;; draw input cursor
|: (.CUR)
  KCUR C@ 1 AND NOT?EXIT
  TOVER? TINV? SYS: MASK-P C@
  ;; emulate FLASH
  KCUR C@  SYS: FRAMES C@
  ( tover tinv mask-p kcur frames )
  OVER $80 AND IF ;; blinking bar
    OVER XOR $10 AND 0IF 4DROP EXIT ENDIF
    $10 XOR KCUR C!
    1 TOVER 1 TINV
    $FF SYS: MASK-P C!
    BL
  ELSE  ;; C/L
    $10 AND TINV 0 TOVER
    $10 OR KCUR C!
    ;; use L or C (sadly, the difference is 9)
    \ SYS: FLAGS2 C@ 8 AND IF $43 ELSE $4C ENDIF (EMIT-RAW)
    ;; 2 bytes smaller
    $4C SYS: FLAGS2 C@ 8 AND DUP 1 MIN + -
  ENDIF (.CCX) ;

;; erase input cursor
|: (.CUR0)
  KCUR C@ $11 AND $11 - ?EXIT
  $10 KCUR XOR!C
  TOVER? TINV? SYS: MASK-P C@
  KCUR C@ $80 AND DUP IF $FF SYS: MASK-P C! ENDIF
  0<> DUP TOVER TINV
  BL (.CCX) ;
[ENDIF]  \ OPT-EMIT6-KCUR?

|: (CR?)
  6Y@ 6X@ #COLS - 0IF 0 6X! 1+ ENDIF
  DUP 23 U> IF DROP (SCROLL) 23 ENDIF 6Y! ;

|: (.CR)  0 6X! 6Y@ 1+ 6Y! (CR?) ;

|: (.>>)  6X@ 1+ #COLS MIN 6X! ;


|: (.<)
  6X@ DUP IF 1-
  ELSE DROP 6Y@ DUP 1- 0MAX 6Y! IF [ #COLS 1- ] {#,} ELSE 0 ENDIF ENDIF 6X! ;

|: (.>)  6Y@ 23 > IF (CR?) EXIT ENDIF (.>>) ;
|: (.V)  6Y@ 1+ 23 MIN 6Y! ;
|: (.^)  6Y@ 1- 0MAX 6Y! ;

|: (.XX)  (CR?) (EMIT-RAW) (.>>) [ zx-has-word? OUT ] [IF] OUT 1+! [ENDIF] ;
|: (.XY)  0 (.XX) ;

\ |: (.TAB)   BEGIN BL (.XX) 6X@ 3 AND 0UNTIL ;
|: (.TAB)   4 6X@ 3 AND - SPACES ;
|: (.0<<)   0 6X! ;
|: (.ENDCR) 6X@ IF (.CR) ENDIF ;

\ <zx-hidden>
CREATE (CTLS)
  ['] (.ENDCR) zx-w,  ;; 4
  ['] CLS      zx-w,  ;; 5
  ['] (.TAB)   zx-w,  ;; 6
  ['] (.0<<)   zx-w,  ;; 7
  ['] (.<)     zx-w,  ;; 8
  ['] (.>)     zx-w,  ;; 9
  ['] (.V)     zx-w,  ;; 10
  ['] (.^)     zx-w,  ;; 11
  ['] (.XY)    zx-w,  ;; 12
  ['] (.CR)    zx-w,  ;; 13
create;

|: (.INK)    ( ch )  (CEMIT!) INK ;
|: (.PAPER)  ( ch )  (CEMIT!) PAPER ;
|: (.FLASH)  ( ch )  (CEMIT!) FLASH ;
|: (.BRIGHT) ( ch )  (CEMIT!) BRIGHT ;
|: (.INV)    ( ch )  (CEMIT!) INVERSE ;
|: (.OVER)   ( ch )  (CEMIT!) OVER ;

CREATE (X-CTLS)
  ['] (.INK)    zx-w, ;; 16
  ['] (.PAPER)  zx-w, ;; 17
  ['] (.FLASH)  zx-w, ;; 18
  ['] (.BRIGHT) zx-w, ;; 19
  ['] (.INV)    zx-w, ;; 20
  ['] (.OVER)   zx-w, ;; 21
create;

;; low byte: 2nd arg for 2-arg control codes
;; high byte: control code for 2-arg control codes
0 quan EARG

;; AT or TAB
|: (E1A)  ( ch )
  (CEMIT!)
  EARG HI-BYTE 22 - 0IF EARG LO-BYTE SWAP AT EXIT ENDIF ;; AT
  ;; TAB
  DROP 6X@ EARG LO-BYTE - SPACES ;

|: (E2A)  ( ch )  QADDR EARG OR!C ['] (E1A) TO EMIT ;

|: (CEMIT)  ( char )
  LO-BYTE
  DUP 31 U> IF (.XX) EXIT ENDIF  ;; fastest case for normal chars
  DUP 4 14 WITHIN IF 4 - 2* (CTLS) + @ EXECUTE EXIT ENDIF
  DUP 16 22 WITHIN IF 16 - 2* (X-CTLS) + @ TO EMIT EXIT ENDIF
  DUP 22 24 WITHIN IF 256* TO EARG ['] (E2A) TO EMIT EXIT ENDIF
  (.XX) ;

|: (CEMIT!)  ['] (CEMIT) TO EMIT ;

\ <zx-normal>


OPT-EMIT6-KEY? [IF]
|: (KEY-NC)  ( -- code )
  [ OPT-EMIT6-KCUR? ] [IF]
    $EF KCUR AND!C  ;; reset "cursor printed" bit (just in case)
  [ENDIF]
  0 BEGIN DROP
    [ OPT-EMIT6-KCUR? ] [IF] .CUR [ENDIF]
    INKEY? TR-KEY
  DUP UNTIL KEY-BEEP
  [ OPT-EMIT6-KCUR? ] [IF] .CUR0 [ENDIF]
;

|: (KEY)  ( -- code )
  0 SYS: LAST-K C!
  0 SYS: TV-FLAG C!
  KEY-NC ;
[ENDIF]


OPT-EMIT6-AUTOSETUP? [IF]
  ['] (CEMIT) TO EMIT
  ['] (XCLS) TO CLS
  OPT-EMIT6-KCUR? [IF]
    ['] (.CUR) TO .CUR
    ['] (.CUR0) TO .CUR0
  [ENDIF]
  OPT-EMIT6-KEY? [IF]
    ['] (KEY-NC) TO KEY-NC
    ['] (KEY) TO KEY
  [ENDIF]
  ['] (AT) TO AT
  ['] (AT@) TO AT@
[ELSE]
: SETUP-EMIT6-DRIVER
  ['] (CEMIT) TO EMIT
  ['] (XCLS) TO CLS
  [ OPT-EMIT6-KCUR? ] [IF]
    ['] (.CUR) TO .CUR
    ['] (.CUR0) TO .CUR0
  [ENDIF]
  [ OPT-EMIT6-KEY? ] [IF]
    ['] (KEY-NC) TO KEY-NC
    ['] (KEY) TO KEY
  [ENDIF]
  ['] (AT) TO AT
  ['] (AT@) TO AT@
;
[ENDIF]

;; ROM codes:
;;    4 -- endcr
;;    5 -- cls
;;    6 -- next tab stop
;;    7 -- ? (edit) -- move to the line start
;;    8 -- left
;;    9 -- right
;;   10 -- down
;;   11 -- up
;;   12 -- ? (del)
;;   13 -- cr
;;   14 -- ? (nothing)
;;   15 -- ? (nothing)
;;   16 -- INK
;;   17 -- PAPER
;;   18 -- FLASH
;;   19 -- BRIGHT
;;   20 -- INVERSE
;;   21 -- OVER
;;   22 -- AT
;;   23 -- TAB (position in x, but wants 2 args)
