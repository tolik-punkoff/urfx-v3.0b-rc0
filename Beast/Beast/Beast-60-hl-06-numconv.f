;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; numeric conversion
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; moved to USER area
\ 10 variable BASE

: HEX      16 base ! ;
: DECIMAL  10 base ! ;
: OCTAL     8 base ! ;
: BINARY    2 base ! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
: #HOLD  ( ch )  (buf#-pos):1-! (buf#-pos) c! ;
: #HOLDS ( addr count )  << dup +?^| 1- 2dup + c@ #hold |? else| 2drop >> ;
: #SIGN  ( n )  -?< [char] - #hold >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; single numbers

|: (#DIGIT)  ( digit )  48 + dup 57 > ?< 7 + >? #hold ;

: <#  ( n -- n )  (buf#-end) (buf#-pos):! ;
: #>  ( n -- addr count )  drop (buf#-pos) (buf#-end) over - ;
: #   ( n -- n )  base @ u/mod (#digit) ;
: #S  ( n -- 0 )  << # dup ?^|| v|| >> ;
: #SIGNED  ( n -- 0 )  dup abs #s swap #sign ;

: #S,  ( n )
  3 swap << # dup ?^| 1 under- over not?< nip [char] , #hold 3 swap >? |? else| nip >> ;
: #SIGNED,  ( n -- 0 )  dup abs #s, swap #sign ;

: <#S>  ( n -- addr count )  <# #s #> ;
: <#SIGNED>  ( n -- addr count )  <# #signed #> ;
: <#S,>  ( n -- addr count )  <# #s, #> ;
: <#SIGNED,>  ( n -- addr count )  <# #signed, #> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; single printers

|: (.LSPACES)  ( addr count width )  over - bl #emit type ;
|: (.RSPACES)  ( addr count width )  >r dup >r type r> r> swap - bl #emit ;

:  0.R  ( n )  <#signed> type ;
: 0U.R  ( n )  <#s> type ;

:  0.R, ( n )  <#signed,> type ;
: 0U.R, ( n )  <#s,> type ;

:  .  ( n )   0.r  bl emit ;
: U.  ( n )  0u.r  bl emit ;
:  ., ( n )   0.r, bl emit ;
: U., ( n )  0u.r, bl emit ;

|: (.LRX)  ( n width cvtcfa prcfa )  rot 2>r execute 2r> swap execute-tail ;

:  .R  ( n width )  ['] <#signed>  ['] (.lspaces) (.lrx) ;
: U.R  ( n width )  ['] <#s>       ['] (.lspaces) (.lrx) ;
:  .R, ( n width )  ['] <#signed,> ['] (.lspaces) (.lrx) ;
: U.R, ( n width )  ['] <#s,>      ['] (.lspaces) (.lrx) ;
:  .L  ( n width )  ['] <#signed>  ['] (.rspaces) (.lrx) ;
: U.L  ( n width )  ['] <#s>       ['] (.rspaces) (.lrx) ;
:  .L, ( n width )  ['] <#signed,> ['] (.rspaces) (.lrx) ;
: U.L, ( n width )  ['] <#s,>      ['] (.rspaces) (.lrx) ;


[[ tgt-build-base-binary ]] [IFNOT]
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; double numbers

: <#D  ( dlo dhi -- dlo dhi )  <# ;
: #D>  ( dlo dhi -- addr count )  drop #> ;
: #D   ( dlo dhi -- dlo dhi )  base @ uds/mod (#digit) ;
: #DS  ( dlo dhi -- 0 0 )  << #d 2dup or ?^|| v|| >> ;
: #DSIGNED  ( dlo dhi -- 0 0 )  2dup dabs #ds 2swap drop #sign ;

: <#DS>  ( n -- addr count )  <#d #ds #d> ;
: <#DSIGNED>  ( n -- addr count )  <#d #dsigned #d> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; double printers

: 0D.R  ( dlo dhi )  <#dsigned> type ;
: 0UD.R  ( dlo dhi )  <#ds> type ;

:  D.  ( dlo dhi )   0d.r bl emit ;
: UD.  ( dlo dhi )  0ud.r bl emit ;

:  D.R  ( dlo dhi width )  ['] <#dsigned> ['] (.lspaces) (.lrx) ;
: UD.R  ( dlo dhi width )  ['] <#ds>      ['] (.lspaces) (.lrx) ;
:  D.L  ( dlo dhi width )  ['] <#dsigned> ['] (.rspaces) (.lrx) ;
: UD.L  ( dlo dhi width )  ['] <#ds>      ['] (.rspaces) (.lrx) ;
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; single hex printers

: .HEXN  ( u n )
  base @ >r hex >r <# << r@ ?^| # r0:1-! |? else| rdrop >> #> type r> base ! ;

: .HEX2  ( u )  2 .hexn ;
: .HEX4  ( u )  4 .hexn ;
: .HEX8  ( u )  8 .hexn ;

: .OCT2  ( u )
  base @ >r octal lo-byte <# # # # #> type r> base ! ;
: .OCT4  ( u )  dup hi-byte .oct2 bl emit .oct2 ;
: .OCT8  ( u )  dup hi-word .oct4 bl emit .oct4 ;
