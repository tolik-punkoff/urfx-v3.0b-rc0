;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TIB and parsing
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


0 quan TIB
0 quan #TIB
0 quan >IN

;; handy utils; used only by Forth parsing code
: BL?      ( ch -- flag )  bl u<= ;
: BL-EOL?  ( ch -- flag )  bl <= ;
: NOT-BL?  ( ch -- flag )  bl > ( EOL is considered as 'bl' ) ;

: TIB-END?   ( -- flag )  >in #tib u>= ;
: (TIB-IN)   ( -- addr )  tib >in + ;
: (TIB-LEFT) ( -- size )  #tib >in - 0 max ;

: TIB-C@-AHEAD  ( -- char )  >in 1+ dup #tib u< ?< tib + c@ || drop true >? ; -- return -1 on EOT
: TIB-C@  ( -- char )  >in dup #tib u< ?< tib + c@ || drop true >? ; -- return -1 on EOT
: TIB-C>  ( -- char )  tib-c@ dup +0?< >in:1+! >? ;

: TIB-CDROP  tib-c> drop ;

;; parse until any blank/eot.
;; return "false" if called on eot.
;; also, should drop delimiting blank.
|: (PARSE-BL)  ( -- addr count TRUE // FALSE )
  tib-end? not?<
    (tib-in) << tib-c@ not-bl? ?^| tib-cdrop |? else| >>
    (tib-in) over - tib-cdrop true
  || false >? ;

;; parse until delim or EOT.
;; return "false" if called on eot.
;; also, should drop found delim.
;; result is 1 if end delimiter was not found.
|: (PARSE-CH)  ( delim -- addr count TRUE/1 // FALSE )
  tib-end? not?< lo-byte >r
    (tib-in) << tib-c@ dup -?v| drop |? r@ <> ?^| tib-cdrop |? else| >>
    rdrop (tib-in) over - tib-c> -?< 1 || -1 >?
  || drop false >? ;

;; internal API too
: SKIP-LINE  #tib >in:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level parsing API

: SKIP-COMMENT-';;'  ( -- skipped? )
  tib-c@ $3B = not?exit&leave
  tib-c@-ahead $3B = not?exit&leave
  skip-line true ;


: SKIP-SPACES  << tib-c@ bl? ?^| tib-cdrop |? v|| >> ;


|: (no-refill-pop)  false ;
['] (no-refill-pop) variable (REFILL) ( -- not-eof? ) (private)
['] (no-refill-pop) variable (POP-INCLUDE) ( -- not-eof? ) (private)

;; for "SKIP-BLANKS" and "INTERPRET"
false quan ALLOW-REFILL?
;; used to stop "INTERPRET" at the include boundary
\ true quan ALLOW-POP-INCLUDE?

: REFILL  ( -- not-eof? )  (refill) @execute-tail ;
: POP-INCLUDE  ( -- not-eof? )  (pop-include) @execute-tail ;

;; negative delim: parse until EOT.
;; delim in [0..32]: parse until any blank/EOT.
;; otherwise: parse until delim.
;; stopping delim is eaten in any case.
;; "1" is returned if EOT is reached without hitting a non-blank delimiter.
: PARSE  ( delim -- addr count TRUE/1 / FALSE )
  tib-end? not?<
    dup -?exit< (tib-in) #tib >in - true skip-line >?
    dup bl? ?exit< drop (parse-bl) >?
    (parse-ch)
  || drop false >? ;

;; on EOT returns tib address and zero count
: PARSE-NAME/NONE  ( -- addr count )
  skip-spaces (parse-bl) not?< (tib-in) 0 >? ;

;; name must be present; errors on EOT
: PARSE-NAME  ( -- addr count )
  skip-spaces (parse-bl) not?error" name expected" ;

: PARSE-QSTR  ( delim -- addr count )
  (parse-ch) 0>= ?error" unterminated literal" ;

*: "  ( -- addr count ) ;; "
  34 parse-qstr system:comp? ?exit< str#, >? ;

;; skip blanks, including special ";;" comment (with refill, if enabled)
: SKIP-BLANKS
  << skip-spaces tib-c@ -?< allow-refill? dup ?< drop refill >?
                         || skip-comment-';;' >?
  ?^|| else| >> ;
\ x86-disasm-last bye


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; parsing numbers

module NUMPARSE
<disable-hash>

;; sign is skipped
: SIGN?  ( addr count -- addr count negate )
  over c@ <<
    [char] - of?v| string:/char true |?
    [char] + of?v| string:/char false |?
  else| drop false >> ;

: (DIGIT)  ( char -- digit // maxint )
  << dup 48 59 within ?v| 48 - |?
     dup 65 91 within ?v| 55 - |?
     dup 97 123 within ?v| 87 - |?
  else| drop max-int >> ;

: DIGIT  ( char base -- digit TRUE // FALSE )
  swap (digit) ( base digit ) 2dup ( b d f ) swap < ?< nip true || 2drop false >? ;

: FIRST-DIGIT?  ( addr count base -- addr count base bool-flag )
  over +?< >r over c@ (digit) r> dup rot > || false >? ;

: BASED  ( addr count base -- num TRUE // FALSE )
  dup 1 37 within not?exit< 3drop false >?
  first-digit? not?exit< 3drop false >?
  >r 0 >r swap << ( count addr | base num )
    1 under- over -?v| 2drop r> rdrop true |?
    c@++ ( count addr ch | base num ) [char] _ of?^||
    r1:@ digit not?v| 2rdrop 2drop false |?
  ^| r> r@ u* + >r | >> ;

: PREFIX?  ( addr count base//0 -- addr+1 count-1 base//0 )
  ?exit&leave
  dup 2 < ?exit< false >?
  over c@ <<
    [char] $ of?v| 16 |?
    \ [char] # of?v| 16 |?
    [char] % of?v| 2 |?
    [char] @ of?v| 8 |?
  else| drop false exit >> >r 1 under+ 1- r> ;

: 0&-PREFIX?  ( addr count base//0 -- addr+2 count-2 base//0 )
  ?exit&leave
  dup 3 < ?exit< false >?
  over c@ dup [char] 0 <> swap [char] & <> and ?exit< false >?
  over 1+ c@ <<
     [char] x of?v| 16 |? [char] X of?v| 16 |?
     [char] h of?v| 16 |? [char] H of?v| 16 |?  ;; added for "&h"
     [char] o of?v|  8 |? [char] O of?v|  8 |?
     [char] b of?v|  2 |? [char] B of?v|  2 |?
     [char] d of?v| 10 |? [char] D of?v| 10 |?
  else| drop false exit >> >r 2 under+ 2- r> ;

: SUFFIX?  ( addr count base//0 -- addr count-1 base//0 )
  ?exit&leave
  dup 2 < ?exit< false >?
  2dup + 1- c@ <<
    [char] h of?v| 16 |? [char] H of?v| 16 |?
  else| drop false exit >> 1 under- ;


: DEC-PART  ( addr count -- addr+n count-n num TRUE / FALSE )
  dup -0?exit< 2drop false >?
  over c@ 10 digit not?exit< 2drop false >? drop
  0 >r swap << ( count addr | num )
    c@++ ( count addr+1 ch | num )
    10 digit not?v| 1- |?
    r> 10 u* + >r
    1 under- over +?^||
  else| >> swap 0 max r> true ;

: BASE#NUM  ( addr count -- num TRUE / FALSE )
  dec-part not?exit&leave
  over 2 < ?exit< 3drop false >?
  dup 1 37 within not?exit< 3drop false >?
  >r over c@ [char] # = not?exit< rdrop 2drop false >?
  1 under+ 1- r> based ;

@: UNUMBER  ( addr count base -- num TRUE / FALSE )
  >r 2dup r> based ?exit< nrot 2drop true >?
  2dup base#num ?exit< nrot 2drop true >?
  0 prefix? 0&-prefix? suffix? based ;

@: SNUMBER  ( addr count base -- num TRUE / FALSE )
  >r sign? r> swap >r unumber ?< r> ?< negate >? true || rdrop false >? ;

end-module NUMPARSE


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; various words which require input stream parsing

*: ."  \ str  ;; "
  34 parse-qstr
  system:comp? ?< str#, \\ type
  ;; use compiler unescaper
  || system:Succubus:slc-unescape type >? ;

*: [CHAR]  ( -- ch )
  parse-name 1 <> ?error" [CHAR] expects a char"
  c@ system:comp? ?exit< #, >? ;


extend-module SYSTEM
vect (INCLUDE-FNAME)  ( -- addr count )
vect (INCLUDE-LINE#)  ( -- line )

{no-inline}
: (EXTENDED-ERROR)  ( fnline fnaddr fncount msgaddr msgcount )
  >r over r> swap not?< 2>r 3drop r> error >?
  pad >r errmsg-buf pad:!
  pad$:! "  <" pad$:+
  pad$:+ [char] : pad$:c+ pad$:u#s
  " >\n  " pad$:+
  pad$:@
  r> pad:!
  error ;

: QERROR,  ( brn )  \ name
  system:?comp
  system:Succubus:mark-j>-brn
  (include-line#) #,
  (include-fname) raw-str#,
  34 parse-qstr str#,
  \\ (extended-error)
  system:Succubus:resolve-j> ;
end-module SYSTEM

*: ERROR"
  system:?comp
  \ 34 parse-qstr str#, \\ forth:error ;
  system:(include-line#) #,
  system:(include-fname) raw-str#,
  34 parse-qstr str#,
  \\ system:(extended-error) ;

*: ?ERROR"    system:Succubus:(0branch) system:qerror, ;
*: NOT?ERROR" system:Succubus:(tbranch) system:qerror, ;
*: 0?ERROR"   system:Succubus:(tbranch) system:qerror, ;
*: +?ERROR"   system:Succubus:(-0branch) system:qerror, ;
*: -?ERROR"   system:Succubus:(+0branch) system:qerror, ;
*: +0?ERROR"  system:Succubus:(-branch) system:qerror, ;
*: -0?ERROR"  system:Succubus:(+branch) system:qerror, ;


|: (HDOC-END?)  ( -- end-flag? )
    \ endcr ." left=" (tib-left) . cr
  (tib-left) 10 >= not?exit&leave
    \ ." |" (tib-in) (tib-left) type ." |\n"
  (tib-in) " >>>HDOC<<<" string:mem=ci not?exit&leave
  (tib-in) 10 +  (tib-left) 10 - swap ( left addr )
  << over +?^| c@++ bl-eol? not?exit< 2drop false >? 1 under- |?
  else| 2drop >> true ;

;; kind of "heredocs"
;; ends with ">>>HDOC<<<".
;; end marked should begin on the first line char, and followed only by blanks/newlines.
|: (HDOC-COLLECT)  ( -- addr count )
  allow-refill? dup not?error" no reason to try heredoc w/o refill"
  >r allow-refill?:!f
  skip-blanks
  r> allow-refill?:!
  tib-end? not?error" heredoc with some extra crap"
  refill not?error" hdoc cannot cross file boundary"
  pad << ( str-addr )
    (hdoc-end?) ?v| skip-line |?
    (tib-in) over (tib-left) cmove
    (tib-left) +
    \ $0A over c! 1+  ;; nope, EOL is in TIB
    skip-line
    refill not?error" hdoc cannot cross file boundary"
  ^|| >> pad -  pad swap ;

;; kind of "heredocs"
;; ends with ">>>HDOC<<<".
;; end marked should begin on the first line char, and followed only by blanks/newlines.
*: <<<HDOC>>>
  (hdoc-collect) system:comp? ?< raw-str#, >? ;

*: <<<HDOC/ESC>>>
  (hdoc-collect) system:comp? ?< str#, >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dictionary search words with input stream parsing

: -FIND-REQUIRED  ( -- cfa-xt )
  parse-name find-required ;

*: [']  \ name
  -find-required [\\] {#,} ;

\ FIXME: commented out to catch some bugs
\ *: ['PFA]  \ name
\   -find-required dart:cfa>pfa [\\] {#,} ;

: '  \ name
  -find-required ;

: WORD?  \ name
  parse-name find ?< drop true || false >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compiler words with input stream parsing

*: \\  \ name
  system:?comp -find-required system:resolve-alias #, \\ \, ;

*: [\\]  \ name
  system:?comp -find-required
  ws-vocab-cfa not?exit< \, >?
  ws-vocab-cfa system:simple-vocab? ?exit< \, >?
  ;; vocobject method should be immediate
  dup system:immediate? not?error" trying to \'[\\\\]\' non-immediate vocobject method"
  \  endcr ." *** trying to [\\\\] a vocobject\n"
  #, ws-vocab-cfa #, \\ system::(vocobject-call) ;

*: [\!\]  \ name
  system:?comp -find-required \, ;

;; for vocobjects, explicit
*: [\^\]  \ name
  system:?comp -find-required #, ws-vocab-cfa #,
  \\ system::(vocobject-call) ;

;; normal word is compiled with "\\", and immediate with "[\\]".
;; it is useful to write things like: "\*\ IF" without
;; knowing if "IF" is an immediate or not.
*: \*\  \ name
  system:?comp -find-required dup system:immediate?
  ?exit< \, >? system:resolve-alias #, \\ \, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; can be included in context stack to allow comments

module COMMENT-WORDS
<disable-hash>

;; skip multiline comment
|: (SKIP-ML-COMMENT)  ( ech )
  >r << r@ (parse-ch) dup not?^| drop
      allow-refill? dup ?< drop refill >?
      not?error" unfinished comment" |?
    nrot 2drop +?^||  ( hit EOT without a delimiter hit )
    tib-c@ [char] ) = not?^||
  else| rdrop tib-cdrop >> ;

*: .(  \ str
  41 parse-qstr
  ;; use compiler unescaper
  system:Succubus:slc-unescape type ;

\ *: (   ;; supports nested parens )
\   1 << tib-c> dup 0< ?error" unfinished comment"
\        40 of?^| 1+ |? 41 <> ?^|| 1- dup ?^|| else| drop >> ;

;; slightly faster than PARSE
\ !*: (  << tib-c> dup 0< ?error" unfinished comment" 41 <> ?^|| v|| >> ;
*: (  41 (parse-ch) 0>= ?error" unfinished comment" 2drop ;

*: \  skip-line ;
*: -- skip-line ;
*: // skip-line ;

*: (*  [char] * (skip-ml-comment) ;
*: (+  [char] + (skip-ml-comment) ;

end-module COMMENT-WORDS

extend-module FORTH
*: (  [\\] comment-words:( ;
*: \  [\\] comment-words:\ ;
*: -- [\\] comment-words:-- ;
*: // [\\] comment-words:// ;
*: (* [\\] comment-words:(* ;
*: (+ [\\] comment-words:(+ ;
*: .( [\\] comment-words:.( ;
end-module FORTH


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sometimes we need an optional name after
;; "END-MODULE" or "END-STRUCT" (or other such thing).
;; i factored words to parse it out.
;; we need such words to allow things like "(private)", or
;; comments.

module OPT-NAME-PARSE
<disable-hash>

: EOL-COMMENT?  ( addr count -- eol-comment? )
  dup -0?exit< 2drop false >?
  << 1 of?v| c@ [char] \ = |?
     2 of?v| w@ dup $2f2f = swap dup $3b3b = swap $2d2d = or or |?
  else| drop w@ $3b3b = >> ;

: COMMENT?  ( addr count -- comment? )
  dup -0?exit< 2drop false >?
  dup 1 = over [char] ( = and ?exit< 2drop true >?
  eol-comment? ;

: GOOD-NAME?  ( addr count -- addr count good? )
  dup 0> not?exit&leave
  2dup comment? not not?exit&leave
  ;; check for some known words
  over c@ [char] ( <> ?exit&leave
  2dup " (private)" string:=ci not not?exit&leave
  2dup " (public)" string:=ci not not?exit&leave
  2dup " (published)" string:=ci not not?exit&leave
  true ;

: PARSE-OPTIONAL-NAME  ( -- addr count TRUE // FALSE )
  >in >r
  parse-name/none dup not?exit< rdrop 2drop false >?
  good-name? ?exit< rdrop true >?
  2drop r> >in:! false ;

end-module OPT-NAME-PARSE


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utils with input stream parsing

extend-module DEBUG
: SEE  \ name
  -find-required (see) ;

: WHELP  \ name
  -find-required dup dart:cfa>nfa .idfull
  cfa-whelp@ not?exit 2 bl #emit type ;

end-module DEBUG


[[ tgt-build-base-binary ]] [IFNOT]
: FORGET  \ name
  -find-required dart:cfa>nfa forget-support::forget-nfa ;
[ENDIF]
