;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target compiler basics
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; need to have it here :-(

;; latest shadow word created by `mk-shadow-header`
;; note that this might change when the compiler had to create a
;; new forward reference; it might even change if already created
;; forward ref was used. so it cannot be used to detect the word
;; we are compiling right now. use `zx-tk-curr-word-scfa` for this.
;; `zx-tk-curr-word-scfa` is set in colon or code definition word.
;; `zx-tk-curr-word-scfa` also valid after semicolon.
0 quan latest-shadow-cfa

: latest-shadow-pfa  ( -- pfa )  latest-shadow-cfa dart:cfa>pfa ;
: latest-shadow-nfa  ( -- nfa )  latest-shadow-cfa dart:cfa>nfa ;


;; current word we are compiling, because we might create forwards
0 quan zx-tk-curr-word-scfa

: curr-word-scfa  ( -- shadow-cfa )
  zx-tk-curr-word-scfa dup 0?error" internal TCOM error" ;

: curr-word-spfa  ( -- shadow-pfa ) curr-word-scfa dart:cfa>pfa ;
: curr-word-snfa  ( -- shadow-nfa ) curr-word-scfa dart:cfa>nfa ;


0 quan latest-defined-shadow-cfa


;; set by ZX "create", reset by "create;"
false quan zx-tick-register-ref


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; addresses of important ZX variables

0 quan zx-dp^
0 quan zx-p3dos-flag^
0 quan zx-128k-flag^


: .round-1000  ( kb kb-mod )
  100 /mod 10 mod 5 >= -
  dup 9 > ?< swap 1+ swap 10 - >? ;

: .bytes  ( n )
  dup ., ." bytes (~"
  1024 /mod .round-1000 swap 0.r, [char] . emit . ." kb)" ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; labman callack test
0 [IF]
|: (labman-new-label-test)  ( addr count )
  endcr ." NEW LABEL in '"
  zx-tk-curr-word-scfa dup ?< drop latest-shadow-cfa >?
  dup ?< dart:cfa>nfa debug:.id || drop ." <NOWHERE>" >?
  ." ' (around $" zxa:org@ .hex4 ." ): "
  type cr ;
['] (labman-new-label-test) z80-labman:new-label-cb:!

|: (labman-ref-label-test)  ( addr count )
  endcr ." LABEL REFERENCED in '"
  zx-tk-curr-word-scfa dup ?< drop latest-shadow-cfa >?
  dup ?< dart:cfa>nfa debug:.id || drop ." <NOWHERE>" >?
  ." ' (around $" zxa:org@ .hex4 ." ): "
  type cr ;
['] (labman-ref-label-test) z80-labman:ref-label-cb:!
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; memory traces, to detect memory changes
0 [IF]
: mem-tracer  ( byte addr -- byte addr )
  \ dup 10 < ?error" WUT?!"
  \ dup $765D $765F within not?exit
  turnkey-pass2? not?exit
  \ dup $8131 = not?exit
  dup $4000 >= ?exit
  \ over lo-byte $80 >= ?exit
  endcr ." WRITING BYTE $" over .hex2 ."  to $" dup .hex4
  zx-tk-curr-word-scfa dup ?< drop latest-shadow-cfa >?
  dup ?< ."  in '" dart:cfa>nfa debug:.id ." '\n" || drop cr >?
  abort
;
['] mem-tracer zxa:mem:trace-c!:!
[ENDIF]

: zx>real  ( zx-addr -- addr )  zxa:mem:ram^ ;

: zx-c@  ( zx-addr -- byte )  zxa:mem:c@ ;
: zx-c!  ( val zx-addr )  zxa:mem:c! ;

: zx-w@  ( zx-addr -- word )  zxa:mem:w@ ;
: zx-w!  ( val zx-addr )  zxa:mem:w! ;

;; set zxasm ORG to DP
: zx-fix-org  zx-dp^ zx-w@ zxa:org! ;

;; set DP to zxasm ORG
: zx-fix-dp  zxa:org@ zx-dp^ zx-w! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX dictionary allocation and data compile

: zx-here  ( -- zx-addr )  zx-dp^ zx-w@ ;

: zx-nallot ( n -- zx-start-address )
  dup 0< ?error" negative zx-allot"
  zx-dp^ zx-w@ dup >r
  + dup hi-word ?error" out of ZX memory"
  zx-dp^ zx-w! r> ;

: zx-here!  ( zx-addr )
  lo-word zx-dp^ zx-w!  zx-fix-org ;

: zx-rewind-dp!  ( zx-addr )
  dup zx-dp^ zx-w@ > ?error" invalid rewind address"
  dup 0< ?error" negative rewind address"
  zx-dp^ zx-w!  zx-fix-org ;

: zx-allot ( n )  zx-nallot drop ;

: zx-unallot ( n )
  dup 0< ?error" negative zx-unallot"
  zx-dp^ zx-w@
  swap - dup hi-word ?error" out of ZX memory"
  zx-dp^ zx-w! ;

: zx-c,  ( byte )  1 zx-nallot zx-c! ;
: zx-w,  ( word )  2 zx-nallot zx-w! ;

\ : zx-call,  ( zx-addr )  xasm:call-opc zx-c, zx-w, ;
\ : zx-jp,    ( zx-addr )  xasm:jp-opc zx-c, zx-w, ;

: zx-allot0 ( n )  << dup +?^| 0 zx-c, 1- |? else| drop >> ;

: zx-align-256  << zx-here lo-byte ?^| 0 zx-c, |? else| >> ;

: zx-align-256-asm  z80asm:instr:flush! << z80asm:emit:here lo-byte ?^| 0 z80asm:emit:c, |? else| >> ;

: zx-asm-zallot ( n )
  dup 0< ?error" negative zx-asm-allot"
  dup 65000 > ?error" zx-asm-allot size too big"
  for 0 z80asm:emit:c, endfor ;

: zx-align-odd   zx-here 1 and 0?< 0 zx-c, >? ;
: zx-align-even  zx-here 1 and ?< 0 zx-c, >? ;

: zx-asm-align-odd   z80asm:instr:flush! z80asm:emit:here 1 and 0?< 0 z80asm:emit:c, >? ;
: zx-asm-align-even  z80asm:instr:flush! z80asm:emit:here 1 and ?< 0 zx-c, >? ;

: zx-asm-align-page-fit  ( addr count n )
  dup 1 256 bounds not?error" invalid buffer size"
  >r 2>r z80asm:instr:flush! 2r> r>
  z80asm:emit:here hi-byte
  over z80asm:emit:here + 1- hi-byte
  = ?exit< 3drop >?
  drop
  [ COMPILING-FOR-REAL? ] [IF]
    endcr type ." align waste: " 256 z80asm:emit:here lo-byte .bytes cr
  [ELSE]
    2drop
  [ENDIF]
  << z80asm:emit:here lo-byte ?^| 0 z80asm:emit:c, |? else| >> ;

;; compile byte-counted string
: zx-raw-bstr,  ( addr count )
  dup 0 256 within not?error" invalid zx string length"
  dup zx-c, swap
  << over ?^| c@++ zx-c, 1 under- |? else| 2drop >> ;

;; make sure that the buffer of size `n` is completely inside one 256-byte page.
;; fill unused bytes with 0.
: zx-ensure-page  ( n )
  dup 1 256 bounds not?error" invalid buffer size"
  zx-here  dup rot + 1- hi-byte  swap hi-byte = ?exit
  ;; need to align
  zx-here dup $FF or 1+ swap - zx-allot0 ;


: zx-can-fit-into-page?  ( n )
  dup 1 256 bounds not?error" invalid buffer size"
  zx-here + 1- hi-byte  zx-here hi-byte =
;

: zx-page-bytes-left  ( n )
  zx-here hi-byte 1+ 256 * zx-here - ;

: zx-ensure-page-with-report  ( addr count n )
  dup 1 256 bounds not?error" invalid buffer size"
  zx-here  dup rot + 1- hi-byte  swap hi-byte = ?exit< 2drop >?
  ;; need to align
  2>r zx-here dup $FF or 1+ swap -
  2r>
  [ COMPILING-FOR-REAL? ] [IF]
    type ."  align: " dup .bytes ."  wasted.\n"
  [ELSE]
    2drop
  [ENDIF]
  zx-allot0 ;

: zx-ensure-new-page-with-report  ( addr count )
  zx-here lo-byte 0?exit< 2drop >?
  zx-here zx-align-256 zx-here swap -
  [ COMPILING-FOR-REAL? ] [IF]
    nrot type ."  align: " .bytes ."  wasted.\n"
  [ELSE]
    3drop
  [ENDIF] ;

;; return number of bytes left in the current page
: zx-page-left  ( -- n )  $100 zx-here lo-byte - ;


module str-unescaper
<disable-hash>

: c,  ( ch )  zx-c, ;
: asm-c,  ( ch )  z80asm:emit:c, ;

;; string literals
: ?hex-digit  ( ch -- digit )
  dup [char] 0 [char] 9 bounds ?exit< [char] 0 - >?
  dup [char] A [char] F bounds ?exit< [char] A - 10 + >?
  dup [char] a [char] f bounds ?exit< [char] a - 10 + >?
  error" invalid hex escape" ;

;; addr and count already advanced past the escaped char
: decode-hex-escape  ( count addr -- count addr ch )
  over 2 < ?error" invalid hex escape" 2 under-
  c@++ ?hex-digit 16 * swap c@++ ?hex-digit rot + ;

: decode-escape  ( count addr ch -- count addr ch )
  << [char] r of?v|  7 |? ;; ROM wants it this way
     [char] n of?v| 13 |? ;; ROM wants it this way
     [char] t of?v|  6 |? ;; ROM wants it this way
     [char] c of?v|  4 |? ;; ENDCR
     \ [char] e of?v| 27 |?
     \ [char] a of?v|  7 |?
     [char] b of?v|  8 |?
     [char] W of?v|  5 |? ;; CLS
     \ [char] z of?v|  0 |?
     [char] \ of?v| [char] \ |?
     [char] ` of?v| [char] " |?
     [char] ' of?v| [char] " |?
     [char] I of?v| 16 |? ;; INK
     [char] P of?v| 17 |? ;; PAPER
     [char] F of?v| 18 |? ;; FLASH
     [char] B of?v| 19 |? ;; BRIGHT
     [char] V of?v| 20 |? ;; INVERSE
     [char] O of?v| 21 |? ;; OVER
     [char] R of?v| 20 |? ;; INVERSE
     [char] X of?v| 21 |? ;; OVER
     ;; one-char codes, useful for attributes
     [char] 0 of?v| 0 |?
     [char] 1 of?v| 1 |?
     [char] 2 of?v| 2 |?
     [char] 3 of?v| 3 |?
     [char] 4 of?v| 4 |?
     [char] 5 of?v| 5 |?
     [char] 6 of?v| 6 |?
     [char] 7 of?v| 7 |?
     [char] 8 of?v| 8 |?
     [char] 9 of?v| 9 |?
     [char] x of?v| decode-hex-escape |?
  else| error" invalid escape" >> ;

vect u-c,

;; decode to sl-dpos
: unescape  ( addr count )
  << dup +?^|
      1- swap c@++ dup 92 = ?< drop
        over not?error" invalid escape"
        1 under- c@++ decode-escape
      >? u-c, swap
  |? else| 2drop >> ;

end-module

;; compile raw string, no counters
: (zx-raw-str-asm)  ( addr count )
  ['] str-unescaper:asm-c, str-unescaper:u-c,:!
  str-unescaper:unescape ;


;; compile byte-counted string (and unescape it)
: zx-bstr,  ( addr count )
  \ dup 0 256 within not?error" invalid zx string length"
  ( reserve length byte) 0 zx-c,
  zx-here >r
  ['] str-unescaper:c, str-unescaper:u-c,:!
  str-unescaper:unescape
  zx-here r@ -
  dup 255 u> ?error" invalid zx string length"
  r> 1- zx-c! ;


;; dynalloc the string
: zx-bstr-$new  ( addr count -- str$ )
  ['] pad$:c+ str-unescaper:u-c,:!
  pad$:!0
  str-unescaper:unescape
  pad$:@ string:$new ;


;; include binary file; no path transformations
;; FIXME: make it relative!
: zx-incbin  ( addr count )
  file:open-r/o >r
  << here 1 r@ file:read 1 = ?^| here c@ zx-c, |?
  else| r> file:close >> ;

: <zx-asm>  zx-fix-org [\\] <asm> ;

;; setup miniasm
['] zx-c, xasm:byte,:!
['] zx-c! xasm:byte!:!
['] zx-c@ xasm:byte@:!
['] zx-here xasm:$here:!
;; this will be set later
\ ['] zx-unallot xasm:rewind:!

;; setup disasm
['] zx-c@ z80dis:zx-c@:!

end-module
