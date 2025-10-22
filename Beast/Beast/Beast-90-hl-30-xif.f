;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; conditional compilation
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module CONDCOMP-SUPPORT
<disable-hash>

0 quan if-count

1 constant kw-if
2 constant kw-endif
3 constant kw-else
module KEYWORDS
<disable-hash> -- it is ok, because we will check first and last chars anyway
: [IF]     kw-if ;
: [IFNOT]  kw-if ;
: [ENDIF]  kw-endif ;
: [ELSE]   kw-else ;
\ : [IFDEF]  kw-if ;
\ : [IFNDEF] kw-if ;
\ : [THEN]   kw-endif ;
end-module KEYWORDS


: parse-next-word  ( stline -- addr count )
  >r << skip-blanks bl parse not?^|
    refill not?<
      endcr ." unfinished conditional started at: "
      inc-fname type ." :" r> 0.r cr
      error" unexpected end of file" >? |?
  else| rdrop >> ;

: maybe-cond?  ( addr count -- flag )
  dup 4 8 within not?exit< 2drop false >?
  over c@ [char] [ = not?exit< 2drop false >?
  + 1- c@ [char] ] = ;

: skip-conds  ( toelse )
  inc-line# >r 0 >r  ( toelse | stline level )
  << r1:@ parse-next-word  ( toelse addr count | stline level )
     2dup maybe-cond? not?^| 2drop |?
     vocid: keywords find-in-vocid not?^|| execute
     ( toelse kwid | stline level )
     << kw-if of?v| r0:1+! false |?
        kw-endif of?v| r0:1-! r@ 0< |?
        kw-else of?v|
         dup ?< if-count:1+! r@ 0= ;; we're skipping "true" part
         || ;; we're skipping "false" part, there should be no else
           r@ not?error" unexpected [ELSE]" false >? |?
     else| error" forgotten guard in condcomp" >>
  not?^|| v|| >> drop ( `toelse` )
  r> 0> ?error" oops?" rdrop ;

: process-cond  ( cond )  ?exit< if-count:1+! >? true skip-conds ;

end-module CONDCOMP-SUPPORT (private)


extend-module FORTH
using condcomp-support
{no-inline} *: [HAS-WORD]  word? ;

{no-inline} *: [IF]     process-cond ;
{no-inline} *: [IFNOT]  not process-cond ;
{no-inline} *: [ELSE]   if-count not?error" unexpected [ELSE]" false skip-conds ;
{no-inline} *: [ENDIF]  if-count not?error" unexpected [ENDIF]" if-count:1-! ;

\ *: [IFDEF]  word? process-cond ;
\ *: [IFNDEF] word? not process-cond ;
end-module FORTH
