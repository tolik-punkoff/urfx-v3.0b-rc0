;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; helper vocab with TCOM words
;; this also compiles literals (the handler will be set later)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; there helpers will be used instead of the corresponding shadows.
;; they should be immediate (because otherwise there is no reason for them to exist).
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

module SHADOW-HELPERS
\ <disable-hash>
<separate-hash>

*: (  [\\] forth:( ;
*: \  [\\] forth:\ ;
*: -- [\\] forth:-- ;
*: // [\\] forth:// ;
*: (* [\\] forth:(* ;
*: (+ [\\] forth:(+ ;

*: [IF]     [\\] forth:[IF] ;
*: [IFNOT]  [\\] forth:[IFNOT] ;
*: [ELSE]   [\\] forth:[ELSE] ;
*: [ENDIF]  [\\] forth:[ENDIF] ;

;; no need to mark the word as recursive
*: RECURSE-TAIL
  zx-?in-colon
  ;; insert direct branch, why not
  ;; check if we have the label at the beginning of the word
  ir:head dup ?< ir:node:spfa ir:ir-label? >?
  ;; insert label, if necessary
  not?< ['] ir:ir-specials:(ir-label) ir:prepend-special >?
  ir:head dup ir:node:spfa ir:ir-label? 0?error" REC-TAIL: ICE!"
  zsys-run: BRANCH
  ir:tail ir:node:ir-dest:! ;

;; codegen will mark the word for us
*: RECURSE
  zx-?in-colon
  ['] ir:ir-specials:(ir-recurse) ir:append-special
  curr-word-spfa ir:tail ir:node:spfa-ref:! ;

\ *: FALSE  zx-?in-colon  0 zx-#, ;
\ *: TRUE   zx-?in-colon  1 zx-#, ;


*: ?EXIT&LEAVE
  zx-?in-colon
  zforth-run: DUP
  zforth-run: ?EXIT
  zforth-run: DROP ;

*: NOT?EXIT&LEAVE
  zx-?in-colon
  zforth-run: DUP
  zforth-run: NOT?EXIT
  zforth-run: DROP ;

*: 0?EXIT&LEAVE
  [\\] NOT?EXIT&LEAVE ;


*: [CHAR]
  zx-?in-colon
  parse-name 1 <> ?error" [CHAR] expects a char"
  c@ zx-#, ;

*: "
  zx-?in-colon
  34 parse-qstr
  zsys-run: (") \ zx-bstr, ;
  zx-bstr-$new ir:tail ir:node:str$:! ;

*: ."
  [\\] "  ;; "
  zforth-run: TYPE ;

*: Z:."
  [\\] "  ;; "
  zforth-run: Z:TYPE ;

*: ,"
  zx-?exec
  34 parse-qstr
  zx-bstr, ;

|: (mk#)  ( value )
  zx-?in-colon zx-#, ;


end-module SHADOW-HELPERS
end-module TCOM
