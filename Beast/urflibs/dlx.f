;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple .SO import with C-like syntax
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
dlx:library libsqlite3.so
dlx:import const char *sqlite3_libversion(void) [libversion];
dlx:close-library

endcr ." quering SQLite version...\n"
libversion zcount type cr
*)


module DLX
<disable-hash>
<private-words>

false quan DEBUG  (public)

enum{
  def: ret-none
  def: ret-32
  def: ret-64
}


0 quan taddr
0 quan tcount
0 quan tkid?

|: token-delim  \ delim-char
  tib-cdrop
  tcount:!1 ;

|: id?  ( ch -- flag )
  string:upchar
  dup [char] A [char] Z bounds
  swap dup [char] 0 [char] 9 bounds
  swap [char] _ =
  or or ;

|: token-id  \ id
  tkid?:!t
  << tib-c@ id? ?^| tib-cdrop tcount:1+! |? else| >> ;

|: token-num  \ num
  error" no numbers, please" ;

|: token-sl-comment
  skip-line ;

;; should skip the end
|: ml-comment-end?  ( char -- flag )
  tib-c> [char] * = not?exit&leave
  tib-c@ [char] / = not?exit&leave
  tib-cdrop true ;

|: token-ml-comment
  tib-cdrop
  << skip-spaces tib-c@
     -?< allow-refill? dup ?< drop refill >?
     || ml-comment-end? not >?
  ?^|| else| >> ;

|: token-delim-or-comment  ( -- comment? )
  token-delim
  tib-c@ dup [char] * = ?exit< drop token-ml-comment true >?
  [char] / = ?exit< token-sl-comment true >?
  false ;

: get-token  \ token
  skip-blanks
  (tib-in) taddr:! tcount:!0 tkid?:!f
  tib-c@
  dup -?exit< drop >?
  dup [char] 0 [char] 9 bounds ?exit< drop token-num >?
  string:upchar
  dup [char] A [char] Z bounds ?exit< drop token-id >?
  [char] / = ?exit< token-delim-or-comment ?< recurse-tail >? >?
  token-delim ;

: token  ( -- addr count )
  taddr tcount ;

: token=  ( addr count )
  token string:= ;


;; list of known C types
;; pfa: type size in bytes
module TYPE-LIST
<disable-hash>
<case-sensitive>
end-module TYPE-LIST

|: (register-type)  ( addr count sizeof )
  >r
  dup 1 < ?error" invalid type name"
  2dup vocid: type-list vocid-find ?exit<
    dart:cfa>pfa @ r> = ?exit< 2drop >?
    " conflicting dlx type \'" pad$:! pad$:+ " \'" pad$:+
    pad$:@ error >?
      \ endcr ." NEW TYPE: <" 2dup type ." > (64=" r@ 0.r ." )\n"
  \ current@ >r
  push-cur
  voc-cur: type-list
  r> nrot system:mk-constant-4 (public)
  pop-cur ;

@: register-type  ( addr count )
  4 (register-type) ;

@: register-type64  ( addr count )
  8 (register-type) ;

@: register-typeptr  ( addr count )
  666 (register-type) ;

" char" register-type
" int" register-type
" short" register-type
" int8_t" register-type
" int16_t" register-type
" int32_t" register-type
" int64_t" register-type64
" uint8_t" register-type
" uint16_t" register-type
" uint32_t" register-type
" uint64_t" register-type64
" *" register-typeptr
" void" 0 (register-type)
" const" 0 (register-type)
" unsigned" register-type
" signed" register-type


0 quan #type-tokens
0 quan type-sizeof

|: reset-type-state
  #type-tokens:!0 type-sizeof:!0 ;

|: type-mod  ( -- TRUE )
  4 type-sizeof max type-sizeof:!
  true ;

: type-token?  ( -- flag )
  token vocid: type-list vocid-find not?exit&leave
  dart:cfa>pfa @ type-sizeof max type-sizeof:!
  true ;

|: parse-type  \ type
  reset-type-state
  << type-token? ?^|
      \ endcr ." TTK=<" token type ." >\n"
      #type-tokens:1+! get-token |? else| >>
    \ endcr ." NON-TTK=<" token type ." >\n"
  #type-tokens not?error" type expected"
  type-sizeof 666 = ?< 4 type-sizeof:! >? ;

|: parse-ret-type  ( -- rett )
  parse-type
  type-sizeof <<
    0 of?v| ret-none |?
    4 of?v| ret-32 |?
    8 of?v| ret-64 |?
  else| error" invalid parsed type size" >> ;

|: parse-type-or-void  ( cnt -- newcnt void? )
  parse-type type-sizeof 0 = ?exit&leave
  type-sizeof 3 + 3 ~and 4/ +
  false ;

|: match-)
  " )" token= not?error" \')\' expected in fndef" ;

;; parse C function definition.
;; import name put into PAD$.
: parse-fndef  ( -- return? argc )  \ def
  get-token
  parse-ret-type
  tkid? not?error" invalid fndef"
  token pad$:!
    \ endcr ." FN=<" pad$:@ type ." >\n"
  get-token " (" token= not?error" \'(\' expected in fndef"
  get-token
  0
  ( return? argc )
  << tcount not?error" unfinished fndef"
     " )" token= ?v||
     parse-type-or-void ?v| match-) |?
     tkid? ?< get-token >?
       \ endcr ." 001: tk=<" token type ." > cnt=" dup 0.r cr
     " ," token= ?^| get-token |?
  else| match-) >>
  get-token ;

: parse-wname  ( -- addr count TRUE // FALSE )  \ def
  " [" token= not?exit&leave
  get-token
  tkid? not?error" invalid fndef"
  token true
  get-token
  " ]" token= not?error" invalid fndef"
  get-token ;


;; import word PFA
struct:new iimp
  field: addr
  field: argc
  field: rett
  field: lib-pfa
  field: next-imp-pfa
  c-field: namez
end-struct iimp

;; library word PFA
struct:new ilib
  field: handle
  field: last-imp-pfa
  c-field: namez
end-struct ilib


;; library list (name is library name)
module LIBS
<disable-hash>
<case-sensitive>
end-module LIBS

;; library to register new imports
0 quan curr-lib-pfa


|: (reset-lib-imports)  ( lib-pfa )
  dup ilib:handle:!0
  ilib:last-imp-pfa << ( iimp )
    dup ?^|
        \ endcr ."   IMP: " dup dart:does-pfa>cfa dart:cfa>nfa debug:.id cr
      dup iimp:addr:!0
      iimp:next-imp-pfa |?
  else| drop >> ;

|: (reset-imports-iter)  ( lib-cfa -- 0 )
    \ endcr ." ***RESET LIB: " dup dart:cfa>nfa debug:.id ."  ***\n"
  dart:cfa>pfa (reset-lib-imports)
  0 ;

;; call this on startup
|: (reset-imports)
  vocid: libs ['] (reset-imports-iter) vocid-foreach drop
; (ON-RESET-SYSTEM):!latest


;; start importing from the given .so library.
;; duplicates are allowed and merged.
@: library  \ name
  parse-name
  2dup vocid: libs vocid-find ?< dart:cfa>pfa nrot 2drop
  || current@ >r
     voc-cur: libs 2dup system:mk-builds
     system:latest-pfa nrot
     ( handle) 0 ,
     ( last-imp-pfa) 0 ,
     ;; namez
     for c@++ c, endfor drop 0 c,
     r> current! >?
  curr-lib-pfa:! ;

;; finish importing from the current library.
@: close-library  curr-lib-pfa:!0 ;


|: (resolve-ilib)  ( ilib-pfa -- handle )
  dup ilib:handle dup ?exit< nip >? drop
  dup ilib:namez:^ zcount
  DEBUG ?<
    endcr ." loading so library: " 2dup type cr
  >?
  forth:dl-open dup not?< drop
    " ERROR: cannot open so library \'" pad$:!
    ilib:namez:^ zcount pad$:+
    " \'" pad$:+
    endcr pad$:@ type cr
    error" cannot open so library" >?
  tuck swap ilib:handle:! ;

|: (resolve-iimp)  ( iimp-pfa -- addr )
  dup iimp:lib-pfa (resolve-ilib)
  ( iimp-pfa handle )
  over iimp:namez:^
  DEBUG ?<
    endcr ." importing: " dup zcount type cr
  >?
  zcount rot forth:dl-sym
  \ swap linux:(dlsym)
  ( iimp-pfa addr )
  dup not?< drop
    " ERROR: cannot import \'" pad$:!
    dup iimp:namez:^ zcount pad$:+
    " \' from so library \'" pad$:+
    iimp:lib-pfa ilib:namez:^ zcount pad$:+
    " \'" pad$:+
    endcr pad$:@ type cr
    error" cannot import symbol" >?
  tuck swap iimp:addr:! ;

;; resolve lazy import, execute.
|: (import-doer)  ( ... iimp-pfa -- ... )
  dup >r
  iimp:addr dup not?< drop r@ (resolve-iimp) >?
  r@ iimp:argc swap
  r@ iimp:rett ret-64 = ?< forth:dl-invoke-ret64 || forth:dl-invoke >?
  r> iimp:rett not?< drop >? ;

;; import from the current library using C-like definition.
@: import  \ def
  curr-lib-pfa not?error" import from what?"
  parse-fndef
  ( return? argc )
  parse-wname not?< pad$:@ >?
  tcount ?< " ;" token= not?error" \';\' expected" >?
  ( return? argc wnaddr wncount )
  current@ >r
  ['] (import-doer) system:mk-does
  ( addr) 0 ,
  ( argc) ,
  ( ret?) ,
  curr-lib-pfa ,
  ( next-imp-pfa) curr-lib-pfa ilib:last-imp-pfa ,
  ;; name
  pad$:@ for c@++ c, endfor drop 0 c,
  ;; link to the library
  system:latest-pfa curr-lib-pfa ilib:last-imp-pfa:!
  r> current! ;

seal-module
end-module DLX
