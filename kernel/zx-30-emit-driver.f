;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; input/output primitives
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>
\ zxlib-begin" print driver"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level emit driver

0 vect EMIT
0 vect (TYPE)
0 vect CLS
\ OPT-EMIT-KCUR? [IF]
0 vect .CUR
0 vect .CUR0
\ [ENDIF]  \ OPT-EMIT-KCUR?
0 vect AT
0 vect AT@
;; "KEY-NC" should not reset keyboard input buffer.
;; it may be the same as "KEY" if no input buffer is used.
0 vect KEY-NC
0 vect KEY


;; special codes for emit driver:
;;   4 -- endcr
;;   5 -- cls
;;   6 -- none -- was: tab (one arg!)
;;   7 -- cursor to the start of the line
;;   8 -- cursor left
;;   9 -- cursor right
;;  10 -- cursor down
;;  11 -- cursor up
;;  12 -- none -- was: at (y, x)
;;  13 -- cr (next line, col 0, scroll if necessary)
;;  16 -- ink (n)
;;  17 -- paper (n)
;;  18 -- flash (n)
;;  19 -- bright (n)
;;  20 -- inverse (n)
;;  21 -- over (n)
;;  22 -- at (y, x)

\ : TYPE  ( addr count )
\   DUP IF OVER + SWAP DO I C@ EMIT LOOP ELSE 2DROP ENDIF ;
;; this is smaller
: (TYPE-FTH)  ( addr count )
  \ DUP IF SWAP COUNT EMIT SWAP 1- RECURSE-TAIL ENDIF 2DROP ;
  \ FOR C@++ EMIT ENDFOR DROP ;
  BEGIN DUP +WHILE SWAP C@++ EMIT SWAP 1- REPEAT 2DROP ;

: TYPE  ( addr count )  (TYPE) ; zx-inline


: (EMIT-AT)  ( y x )  22 EMIT SWAP 0 MAX 31 MIN EMIT 0 MAX 21 MIN EMIT ;
: (DUMMY-AT@) ( -- 0 0 )  0 0 ;
: (DUMMY-KEY) ( -- 0 )  0 ;

['] (ROM-EMIT) TO EMIT
['] (TYPE-FTH) TO (TYPE)
['] (ROM-CLS) TO CLS
['] NOOP TO .CUR
['] NOOP TO .CUR0
['] (EMIT-AT) TO AT
['] (DUMMY-AT@) TO AT@
['] (DUMMY-KEY) TO KEY-NC
['] (DUMMY-KEY) TO KEY

: CR     13 EMIT ; zx-inline
: ENDCR  4 EMIT ; zx-inline
: SPACE  BL EMIT ; zx-inline
: SPACES ( n )  FOR SPACE ENDFOR ;


\ zxlib-end
<zx-done>
