;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple CLI arguments parsing
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
$use <getarg>

getarg:arg: --arg1  endcr ." ARG1!\n" ;
getarg:help:  ." some argument" ;

getarg:arg: --do-arg2  " arg?" getarg:next-arg endcr ." ARG2! " type ;
getarg:help:  ." some other argument" ;
getarg:last-need-arg

getarg:last-alias: -a2

;; optional
getarg:usage: ." usage: runme [args] fname\nargs:\n" ;

;; optional
getarg:file: ( addr count )
  endcr ." file: \'" type ." \'\n" ;

getarg:parse-args


n getarg:last-need-#args

*)

module getarg
<disable-hash>
<published-words>

\ [HAS-WORD] argv# [IFNOT]
\ alias-for #arg is argv#
\ [ENDIF]

;; current arg#, used in "parse-args".
;; it will be advanced before calling an argument handler.
0 quan cur-arg#

;; set in parser, can be used in handler.
;; also set for help calls.
0 quan cur-arg-pfa

;; used in "parse-args"
false quan seen-ddash?

;; vocab with CLI arg words
0 quan args-vocid

;; called for unknown argument; default is abort
vect file-arg  ( addr count )

;; show usage (with type)
vect-empty usage

;; add arg words there
module args
<disable-hash>
end-module args
vocid: args args-vocid:!

0
new-field nfo>proc-cfa  ( -- )
new-field nfo>help-cfa  ( -- ) -- print help text; no last cr!
new-field nfo>help?-cfa ( -- flag ) -- called to determine if help should be printed
new-field nfo>need-arg? -- counter
new-field nfo>arg-addr-count?
constant #arg-info

;; arg word pfa:
;;   processor-cfa  ( -- )
;;   help-cfa       ( -- ) -- print help text; no last cr!
;;   need-arg?

|: arg-doer  ( pfa )  dup cur-arg-pfa:! @execute-tail ;

|: arg-word?  ( cfa -- flag )
  dup system:does? not?exit< drop false >?
  system:doer@ ['] arg-doer = ;

|: a-help@  ( cfa -- help-cfa )
  dup arg-word? not?exit< drop 0 >?
  dart:cfa>pfa nfo>help-cfa:@ ;

|: a-help?  ( cfa -- print-help-flag )
  dup arg-word? not?exit< drop false >?
  dart:cfa>pfa
  dup nfo>help-cfa:@ not?exit< drop false >?
  dup nfo>help?-cfa:@ dup not?exit< 2drop true >?
  swap cur-arg-pfa:! execute ;

|: a-need-arg@  ( cfa -- need-arg? )
  dup arg-word? not?exit< drop false >?
  dart:cfa>pfa nfo>need-arg?:@ ;

: mk-arg  ( proc-cfa addr count )
  2dup args-vocid find-in-vocid ?< drop
    " duplicate CLI arg: \'" pad$:! pad$:+ [char] " pad$:c+
    (sp0!) pad$:@ error >?
  push-cur args-vocid current!
  system:mk-builds
  ( proc-cfa) ,
  ( help-cfa) 0 ,
  ( help?-cfa) 0 ,
  ( need-arg) 0 ,
  ( arg-addr-count?) 0 ,
  system:latest-cfa ['] arg-doer system:!doer
  pop-cur ;

: last-arg-pfa  ( -- pfa )  push-cur args-vocid current! system:latest-pfa pop-cur ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; argument definition words

: arg:  \ name
  0 parse-name mk-arg
  last-arg-pfa [\\] :noname >r swap ! r> ;

;; help for the last argument
: help:
  last-arg-pfa [\\] :noname >r swap nfo>help-cfa:! r> ;

: last-need-#args ( n )
  last-arg-pfa nfo>need-arg?:!
  false last-arg-pfa nfo>arg-addr-count?:! ;

: last-need-arg
  1 last-arg-pfa nfo>need-arg?:!
  true last-arg-pfa nfo>arg-addr-count?:! ;


: last-alias:  \ name
  last-arg-pfa dup >r @ parse-name mk-arg
  ( copy needarg flag) r> 8 + @ last-arg-pfa 8 + ! ;

: usage:  [\\] :noname swap usage:! ;
: file:   [\\] :noname swap file-arg:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; help helpers

0 quan max-alen (private)


|: one-arg-len  ( cfa -- res )
  \ endcr dup dart:cfa>nfa debug:.id cr
  dup a-help? not?exit< drop false >?
  dup a-need-arg@ 6 * >r
  dart:cfa>nfa idcount r> + max-alen max max-alen:!
  drop false ;

|: collect-one-help  ( cfa -- cfa res )
  dup a-help? not?< drop >? false ;

|: print-one-help  ( cfa )
  dup a-help? not?< drop
  || dup dart:cfa>pfa cur-arg-pfa:!
     dup a-help@
     swap dup a-need-arg@ >r dart:cfa>nfa idcount dup nrot type r>
     ( help-cfa nlen need-arg? )
     for ."  <arg>" 6 + endfor
     max-alen swap - bl #emit
     ."  -- " execute ( type) endcr >? ;

|: calc-max-arg-len  max-alen:!0 args-vocid ['] one-arg-len vocid-foreach drop ;
|: collect-args  ( -- 0 ... )  0 args-vocid ['] collect-one-help vocid-foreach drop ;

: show-args-help
  calc-max-arg-len
  collect-args
  << dup ?^| print-one-help |? else| drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; default "unknown argument" word

: bad-arg  ( addr count )
  " unknown CLI arg: \'" pad$:! pad$:+ [char] " pad$:c+
  (sp0!) pad$:@ error ;
['] bad-arg file-arg:!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; default CLI arg parser

;; no checks!
|: (next-arg)  ( -- addr count )  cur-arg# cur-arg#:1+! argv@ ;

|: get-next-arg  ( aaddr acount -- addr count )
  cur-arg# argv# >= ?<
    " missing argument for \'" pad$:! pad$:+ [char] " pad$:c+
    pad$:@ error >?
  2drop (next-arg) ;

|: check-arg-#  ( aaddr acount #args )
  dup not?exit< 3drop >?
  argv# cur-arg# - > ?<
    " missing argument for \'" pad$:! pad$:+ [char] " pad$:c+
    pad$:@ error >?
  2drop ;

|: do-arg-one-arg  ( addr count cfa )
  >r
  r@ dart:cfa>pfa nfo>arg-addr-count?:@ ?exit< get-next-arg r> execute-tail >?
  r@ a-need-arg@ check-arg-#
  r> execute-tail ;
\   dup a-need-arg@  ( addr count cfa need-arg? )
\   1 = ?exit< >r get-next-arg r> execute-tail >?
\   nrot 2drop execute-tail ;
  \ ?< >r get-next-arg r> || nrot 2drop >?
  \ execute-tail ;

: one-arg  ( addr count )
  2dup args-vocid find-in-vocid not?exit< file-arg >?
  dup arg-word? ?< do-arg-one-arg || nrot 2drop execute-tail >? ;

|: parse-files
  << cur-arg# argv# < ?^| (next-arg) file-arg |? else| >> ;

: parse-args
  cur-arg#:!0 seen-ddash?:!f
  << cur-arg# argv# < ?^| (next-arg) one-arg seen-ddash? ?exit< parse-files >? |? else| >> ;

;; use this word in args which require more args ;-)
;; like "--out <name>"
: next-arg  ( errmsg-addr errmsg-count -- addr count )
  cur-arg# argv# < not?error (next-arg) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some predefined arguments

arg: --
  seen-ddash?:!t ;

arg: --help  usage show-args-help (sp0!) bye ;
help: ." show this help" ;
last-alias: -h


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; argument creation helpers

#arg-info
new-field nfo>e/d-quan-pfa
new-field nfo>e/d-help-ccstr
drop

|: e/d-value      ( -- value ) cur-arg-pfa nfo>e/d-quan-pfa:@ @ ;
|: e/d-has-help?  ( -- flag )  cur-arg-pfa nfo>e/d-help-ccstr:@ 0<> ;

|: e/d-proc-on  cur-arg-pfa nfo>e/d-quan-pfa:@ !t ;
|: e/d-proc-off cur-arg-pfa nfo>e/d-quan-pfa:@ !f ;

|: e/d-help?-on  ( -- flag )  e/d-has-help? not?exit&leave e/d-value 0= ;
|: e/d-help?-off ( -- flag )  e/d-has-help? not?exit&leave e/d-value 0<> ;

|: e/d-help-type  cur-arg-pfa nfo>e/d-help-ccstr:@ count type ;
|: e/d-help-on  ." enable " e/d-help-type ;
|: e/d-help-off ." disable " e/d-help-type ;

;; 0 enable/disable-arg: quan opt-name
;; " help text" enable/disable-arg: quan opt-name
: enable/disable-arg:  ( haddr hcount // 0 )  \ quan-name arg-name
  dup not?< >r
  || system:Succubus:slc-unescape
     dup 4+ n-allot  ( addr count dest )
     2dup ! dup >r
     4+ swap cmove >?
  [\\] ['] dup quan-support:xquan? not?error" quan expected"
  dart:cfa>pfa >r >in >r ( | help-cc quan-pfa old-in )
  " --enable-" pad$:! parse-name pad$:+
  ['] e/d-proc-on pad$:@ mk-arg
  ( quan-pfa) r1:@ ,
  ( help-cc) r2:@ ,
  ['] e/d-help-on last-arg-pfa nfo>help-cfa:!
  ['] e/d-help?-on last-arg-pfa nfo>help?-cfa:!
  r@ >in:!
  " --" pad$:! parse-name pad$:+
  ['] e/d-proc-on pad$:@ mk-arg
  ( quan-pfa) r1:@ ,
  ( help-cc) 0 ,
  r@ >in:!
  " --disable-" pad$:! parse-name pad$:+
  ['] e/d-proc-off pad$:@ mk-arg
  ( quan-pfa) r1:@ ,
  ( help-cc) r2:@ ,
  ['] e/d-help-off last-arg-pfa nfo>help-cfa:!
  ['] e/d-help?-off last-arg-pfa nfo>help?-cfa:!
  r> >in:!
  " --no-" pad$:! parse-name pad$:+
  ['] e/d-proc-off pad$:@ mk-arg
  ( quan-pfa) r> ,
  ( help-cc) 0 ,
  rdrop ;


seal-module
end-module getarg
