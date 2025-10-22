;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; string literal management for colons
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; no more than ~16KB of strings for one colon definition ;-)
16384 constant #sl-buffer
0 quan sl-buffer


;; string literals will be compiled after the colon.
;; list format:
;;   next
;;   fixup-va
;;   cc-str
0 variable colon-strlit-chain

;; current position in sl-buffer
0 quan sl-pos

\ WARNING! fields MUST be in this order! the names are used to make code more readable.
: sn>next   ( addr -- addr )  ;
: sn>fixup  ( addr -- addr )  4+ ;
: sn>cclen  ( addr -- addr )  8 + ;
: sn>ccdata ( addr -- addr )  12 + ;
12 constant #sn-header

module slc-unescaper
<disable-hash>

0 quan sl-start
0 quan sl-dpos

: c,  ( ch ) sl-dpos c! sl-dpos:1+! ;

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
  << [char] r of?v| 13 |?
     [char] n of?v| 10 |?
     [char] t of?v|  9 |?
     [char] e of?v| 27 |?
     [char] a of?v|  7 |?
     [char] b of?v|  8 |?
     [char] z of?v|  0 |?
     [char] \ of?v| [char] \ |?
     [char] ` of?v| [char] " |?
     [char] ' of?v| [char] " |?
     [char] x of?v| decode-hex-escape |?
  else| error" invalid escape" >> ;

;; decode to sl-dpos
: unescape  ( addr count )
  << dup +?^|
      1- swap c@++ dup 92 = ?< drop
        over not?error" invalid escape"
        1 under- c@++ decode-escape
      >? c, swap
  |? else| 2drop >> ;

: cc-str  ( -- addr count )  sl-start sl-dpos over - ;
: #cc  ( -- len )  sl-dpos sl-start - ;

: init  ( staddr )  dup sl-start:! sl-dpos:! ;

end-module slc-unescaper


: sl-bufend  ( -- addr )  sl-buffer #sl-buffer + ;

: ?str-room  ( count )
  dup 0 65536 within not?error" invalid string"
  sl-pos + #sn-header +  sl-bufend u> ?error" too much string data" ;

|: cg-slc-find  ( addr count -- node^ TRUE // FALSE )
  colon-strlit-chain << ( addr count list )
    sn>next @ dup not?v||
    2dup sn>cclen @ - ?^||
    >r 2dup r@ sn>ccdata swap string:mem= not?^| r> |?
  else| 2drop r> true exit >> 3drop false ;

;; compile fixup
|: cg-slc-compile-fixup-here  ( node^ -- new-count )
  dup
  sn>fixup code-here over @ code-dd, swap !
  sn>cclen @ ;

|: slc,  ( value )  sl-pos ! sl-pos:4+! ;

|: cg-slc-append  ( addr count -- node^ )
  ( next) sl-pos colon-strlit-chain @ slc, colon-strlit-chain !
  ( fixup-va) 0 slc,
  ( len) dup slc,
  tuck sl-pos swap cmove  sl-pos:+!
  colon-strlit-chain @ ;

;; put chain address to CODE-HERE
: cg-raw-string-addr,  ( addr count -- new-count )
  dup ?str-room
  2dup cg-slc-find ?< nrot 2drop || cg-slc-append >?
  cg-slc-compile-fixup-here ;

;; put chain address to CODE-HERE; perform unescaping
: cg-string-addr,  ( addr count -- new-count )
  dup ?str-room
  sl-pos #sn-header + slc-unescaper:init
  slc-unescaper:unescape
  slc-unescaper:cc-str cg-slc-find not?<
    ( next) colon-strlit-chain @ sl-pos sn>next !  sl-pos colon-strlit-chain !
    ( fixup) 0 sl-pos sn>fixup !
    ( len) slc-unescaper:#cc sl-pos sn>cclen !
    sl-pos  slc-unescaper:sl-dpos sl-pos:! >?
  cg-slc-compile-fixup-here ;


|: cg-slc-patch-one  ( va fixup-va )
  << dup ?^| dup code-@ >r  2dup code-! drop  r> |? else| 2drop >> ;

|: cg-slc-resolve-one  ( node^ )
  code-here >r
  dup sn>cclen @++
  ;; copy string data
  swap << over ?^| c@++ code-db, 1 under- |? else| 2drop >> 0 code-db,
  sn>fixup @ r> swap cg-slc-patch-one ;

;; align to next dword (why not?)
|: cg-slc-align
  << code-here 7 and ?^| $90 code-db, |? else| >> ;

;; copy and resolve all collected strings
: cg-slc-resolve
  colon-strlit-chain @ 0?exit
  cg-slc-align
  colon-strlit-chain << sn>next @ dup ?^| dup cg-slc-resolve-one |? else| drop >> ;


|: slc-ensure-buffer
  sl-buffer ?exit
  #sl-buffer linux:prot-r/w linux:mmap not?error" out of memory for SLC buffer"
  dup sl-buffer:! sl-pos:! ;

@: slc-unescape  ( addr count -- addr count )
  slc-ensure-buffer
  dup ?str-room
  sl-pos slc-unescaper:init
  slc-unescaper:unescape
  slc-unescaper:cc-str ;


;; call on system reset (done by higher-level initer)
: slc-reset
  colon-strlit-chain !0
  sl-buffer dup sl-pos:! ?exit
  slc-ensure-buffer ;

;; call on system boot (done by higher-level initer)
: slc-initialise
  colon-strlit-chain !0
  sl-buffer:!0 sl-pos:!0 ;
