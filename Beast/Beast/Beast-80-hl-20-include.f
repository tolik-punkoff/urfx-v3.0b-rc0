;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; include sources
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
each include will allocate at least two memory pages.
first page is file info: name, unique id, etc.
second page is read cache.
*)


;; have to do it here, after "interpret"
[[ 6 4* ]] constant TIB-SAVE#

: TIB-SAVE  ( buf^ )
  tib av-!++ #tib av-!++ >in av-!++
  interpret-hooks:repl? av-!++
  interpret-hooks:start-pos av-!++
  allow-refill? av-!++ drop ;

: TIB-RESTORE  ( buf^ )
  @++ tib:! @++ #tib:! @++ >in:!
  @++ interpret-hooks:repl?:!
  @++ interpret-hooks:start-pos:!
  @++ allow-refill?:! drop ;

false quan VERBOSE-$USE?


module INCLUDER
<disable-hash>

\ true quan ALLOW-POP-INCLUDE?

0 quan WAS-REPL?
0 quan OLD-ALLOW-REFILL?
0 quan OLD-REFILL
0 quan OLD-POP-INCLUDE

4096 constant CACHE-SIZE
\ 200 constant CACHE-SIZE
0 quan INCLUDE-HEAD
0 quan UID-COUNTER

: ->prev  ( head -- prev^ )  ;
: ->fd    ( head -- fd^ )    4+ ;
: ->cpos  ( head -- cpos^ )  8 + ; -- current position in cache (next line start) -- address
: ->cread ( head -- cread^ ) 12 + ; -- cache end -- address
: ->line  ( head -- line^ )  16 + ; -- current line number
: ->uid   ( head -- uid^ )   20 + ;
: ->uidx  ( head -- uidx^ )  24 + ; -- 2 dwords, hash accum, name hash
: ->prev->in  ( head -- addr^ )  32 + ; -- saved >in
: ->prev-tib  ( head -- addr^ )  36 + ; -- saved tib
: ->prev-#tib ( head -- addr^ )  40 + ; -- saved #tib
: ->prev-stpos ( head -- addr^ )  44 + ; -- saved #tib
: ->name  ( head -- name^ )  64 + ; -- dd-counted string

: >prev  ( -- prev^ )  include-head ;
: >fd    ( -- fd^ )    >prev ->fd ;
: >uid   ( -- uid^ )   >prev ->uid ;
: >uidx  ( -- uidx^ )  >prev ->uidx ;
: >line  ( -- line^ )  >prev ->line ;
: >cpos  ( -- cpos^ )  >prev ->cpos ;
: >cread ( -- cread^ ) >prev ->cread ;
: >prev->in  ( -- addr^ ) >prev ->prev->in ;
: >prev-tib  ( -- addr^ ) >prev ->prev-tib ;
: >prev-#tib ( -- addr^ ) >prev ->prev-#tib ;
: >prev-stpos ( -- addr^ ) >prev ->prev-stpos ;
: >name  ( -- name^ )  >prev ->name ;
: >cache ( -- addr )   >prev 4096 + ;

: save-prev
  interpret-hooks:repl? was-repl?:!
  allow-refill? old-allow-refill?:!
  (refill) @ old-refill:!
  (pop-include) @ old-pop-include:! ;

: restore-prev
  was-repl? interpret-hooks:repl?:!
  old-allow-refill? allow-refill?:!
  old-refill (refill) !
  old-pop-include (pop-include) ! ;


: mk-include  ( -- addr )
  cache-size 4096 + linux:prot-r/w linux:mmap not?error" cannot create include buffer" ;

: free-include  ( addr )
  cache-size 4096 + linux:munmap drop ;

: gen-uid  ( -- uid ) uid-counter:1+! uid-counter ;
: copy-name  ( addr count )  dup >name ! >name 4+ swap cmove ;
: save-tib  tib >prev-tib ! #tib >prev-#tib ! >in >prev->in !
            interpret-hooks:start-pos >prev-stpos ! ;
: restore-tib  >prev->in @ >in:! >prev-tib @ tib:! >prev-#tib @ #tib:!
               >prev-stpos @ interpret-hooks:start-pos:! ;

: gen-uidx!  >name count string:joaat-2x >uidx va-!++ ! ;

: close
  >fd @ file:close
  restore-tib
  >prev @ include-head free-include include-head:! ;

: open  ( addr count )
  dup 1 4000 within not?error" invalid name length"
  2dup file:open-r/o
  mk-include include-head over ->prev ! include-head:!
  >fd ! >line !0  >cache dup >cpos ! >cread !
  gen-uid >uid ! copy-name gen-uidx!
  save-tib >cache tib:! #tib:!0 >in:!0 ;

;; this actually checks only if the first char of the first line is "#"
: skip-shebang
  >line @ 1- ?exit  ;; only the first line
  tib-c@ [char] # <> ?exit
  skip-line ;

;; this advaces cpos
: queue-line  ( llen )
  >in:!0 dup #tib:! >cpos @ tib:! >cpos +! >line 1+! skip-shebang ;

: get-existing-line  ( -- okflag )
  >cread @ >cpos @ u<= ?exit< false >?
  >cpos @ >cread @ over - string:scan-eol dup ?< swap queue-line >? ;

;; remove processed part of the cache (physically move unprocessed to the start).
;; this is used when we have no more full lines in cache.
: drop-read
  >cpos @ >cread @ 2dup u< ?< ( p r )
    over - ( p left ) >r >cache r@ cmove
    >cache dup >cpos ! r> + >cread !
  || 2drop >cache dup >cpos ! >cread ! >? ;

: ?eof  >fd @ dup file:tell swap file:size <> ?error" line too long" ;

: check-last-line  ( succflag -- true )
  not?< >cread @ >cache cache-size + = ?< ?eof >?
        >cread @ >cpos @ - queue-line >? true ;

: refill  ( -- noneof-flag )
  include-head not?exit&leave
  >cread @ not?exit&leave
  get-existing-line ?exit&leave
  drop-read >cread @ dup >cache - cache-size swap - >fd @ file:read >cread +!
  >cread @ >cache - not?exit< >cread !0 false >?
  get-existing-line check-last-line ;

: in-include?  ( -- flag )  include-head 0<> ;
: ?in-include  in-include? not?error" not loading a file" ;

: pop-include  ( -- not-eof? )
  \ allow-pop-include? not?exit&leave
  include-head ?< close >? in-include? dup not?< restore-prev >? ;

: setup-reader
  in-include? not?< save-prev
    ['] refill (refill) !
    ['] pop-include (pop-include) !
    allow-refill?:!t interpret-hooks:repl?:!0 >? ;

: inc-path  ( -- addr count )
  in-include? not?exit< " ./" >?
  >name count string:extract-path dup not?< 2drop " ./" >? ;

: mk-inc-name  ( addr count -- addr count )
  dup 0< ?error" invalid include name"
  over c@ string:path-delim? ?exit
  inc-path pad$:! pad$:+ pad$:@ ;

: mk-inc-name-pfx  ( pfx-addr pfx-count addr count -- addr count )
  dup 0< ?error" invalid include name"
  over c@ string:path-delim? ?exit< 2swap 2drop >?
  >r over -0?exit< r> 2swap 2drop >? r>
  2swap pad$:! pad$:last-c@ string:path-delim? not?< [char] / pad$:c+ >?
  pad$:+ pad$:@ ;

: mk-sys-inc-name  ( addr count -- addr count )
  dup 0< ?error" invalid include name"
  over c@ string:path-delim? ?exit
  " URFORTH_INCLUDE_DIR" string:getenv ?<
    dup not?< 2drop " ./" >?
    pad$:! pad$:@ string:end-delim?
    not?< [char] / pad$:c+ >?
  || string:binpath string:extract-path dup not?< 2drop " ./" >? pad$:!
     " urflibs/" pad$:+ >?
  pad$:+ pad$:@ ;

: check-dir  ( addr count -- addr count )
  2dup file:dir? ?< pad$:! pad$:@
    " /00-" pad$:+ string:extract-name pad$:+
    " -loader.f" pad$:+ pad$:@
  || 2dup file:exist? not?< pad$:! " .f" pad$:+ pad$:@ >? >? ;

: PARSE-FNAME  ( -- addr count system? )
  skip-spaces tib-c> << 34 of?v| false 34 parse |? 60 of?v| true 62 parse |?
  else| drop false >> not?error" quoted string expected"
  rot ;

: LINE-SEEK  ( lnum fofs )
  ?in-include
  >fd file:seek
  >cache dup >cpos ! >cread !
  >cache tib:! #tib:!0 >in:!0
  >line ! ;

: LINE-OFS  ( -- fofs )
  ?in-include
  >cread @ not?< >fd file:size
  || >fd file:tell >cpos @ >cache - + #tib - >? ;

;; doesn't refill; clears TIB
: REWIND
  ?in-include
  0 >fd file:seek
  >line !0  >cache dup >cpos ! dup >cread !
  tib:! #tib:!0 >in:!0 ;

: REINIT
  include-head:!0 uid-counter:!0
  ['] forth::(no-refill-pop) forth::(refill) !
  ['] forth::(no-refill-pop) forth::(pop-include) ! ;

;; this is called from the system reset word
: CLOSE-ALL  << include-head ?^| pop-include |? v|| >> reinit ;


: (INCLUDE)  ( addr count system? )
  ?< mk-sys-inc-name || mk-inc-name >? check-dir setup-reader open ;

: (INCLUDE-EXIST?)  ( addr count system? -- bool )
  ?< mk-sys-inc-name || mk-inc-name >? check-dir file:exist? ;

: (SOFT-INCLUDE)  ( addr count system? )
  ?< mk-sys-inc-name || mk-inc-name >? check-dir
  2dup file:exist? ?< setup-reader open || 2drop >? ;

;; do not preprocess name
: (INCLUDE-FILE)  ( addr count )
  setup-reader open ;


0 quan USE-LIST-LAST^ -- uidx0 uidx1 next

: USE-UIDX=  ( uidx0 uidx1 use^ -- flag )
  dup >r 4+ @ = swap r> @ = and ;

: (USED?)  ( addr count -- flag )
  string:joaat-2x
  use-list-last^ << dup not?v|| >r 2dup r@ use-uidx= ?exit< 2drop rdrop true >?
  r> 8 + @ ^|| >> 3drop false ;

: (NEW-USED)  ( addr count )
  string:joaat-2x  hdr-align-here hdr-here >r
  swap hdr, hdr, use-list-last^ hdr,  r> use-list-last^:! ;

: (USE)  ( addr count -- )
  2dup (used?) ?exit< 2drop >? 2dup (new-used)
  verbose-$use? ?< endcr ." loading <" 2dup type ." >...\n" >?
  true (include) ;


end-module INCLUDER \ (private)


: INC-LINE#  ( -- linenum )    includer:in-include? ?< includer:>line @ || 0 >? ;
: INC-UID    ( -- uid )        includer:in-include? ?< includer:>uid @ || 0 >? ;
: INC-UIDX   ( -- uid0 uid1 )  includer:in-include? ?< includer:>uidx 2@le || 0 0 >? ;
: INC-FNAME  ( -- addr count ) includer:in-include? ?< includer:>name count || pad 0 >? ;

: .INC-POS
  includer:in-include? ?< inc-fname type ." :" base @ decimal inc-line# 0.r base !
  || ." <somewhere in time>" >? ;

: (INC-SETUP-COMPILER-FREF)
  ['] inc-line# system:(inc-line#^):!
  ['] inc-fname system:(inc-fname^):!
  ['] inc-uidx system:(inc-uidx^):! ;

: (INCLUDE)   ( addr count system? )  includer:(include) ;
: (SOFT-INCLUDE)  ( addr count system? )  includer:(soft-include) ;
: (INCLUDE-EXIST?)  ( addr count system? -- bool )  includer:(include-exist?) ;
;; do not preprocess name
: (INCLUDE-FILE)   ( addr count )  includer:(include-file) ;

: INCLUDE-LINE-SEEK  ( lnum fofs )  includer:line-seek ;
: INCLUDE-LINE-FOFS  ( -- fofs )    includer:line-ofs ;

: IN-INCLUDE?  ( -- flag )  includer:in-include? ;

*: $INCLUDE  \ fname
  includer:parse-fname (include) ;

*: $SOFT-INCLUDE  \ fname
  includer:parse-fname (soft-include) ;

*: $INCLUDE-EXIST?  ( -- flag ) \ fname
  includer:parse-fname (include-exist?) ;

*: $REQUIRE  \ word fname
  system:?exec parse-name vocid: forth find-in-vocid
  ?exit< drop includer:parse-fname 3drop >? includer:parse-fname (include) ;

*: $USE  \ <libname>
  system:?exec includer:parse-fname not?error" system library name expected"
  includer:(use) ;

*: \EOF
  system:?exec includer:?in-include includer:pop-include drop ;

;; use this to read included files. does automatic refill.
: GETCH  ( -- ch // -1 )
  << tib-c> dup +0?v|| drop refill ?^|| else| -1 >> ;


;; this compiles *current* include file name and line.
;; kills PAD
*: $INC$
  system:?comp includer:?in-include
  inc-fname pad$:! [char] : pad$:c+ inc-line# pad$:u#s
  pad$:@ raw-str#, ;


extend-module DEBUG

chained ON-ABORT
0 quan ABORT-RESTART-CFA

{no-inline} : (DEFAULT-ABORT)  ( addr count )
  setup-raw-output
  on-abort not?< endcr ." ***UrForth FATAL: " type ."  in: " .inc-pos cr backtrace >?
  abort-restart-cfa ?execute 1 nbye ;
last-word-cfa-set tgt-(abort)-cfa

end-module DEBUG
