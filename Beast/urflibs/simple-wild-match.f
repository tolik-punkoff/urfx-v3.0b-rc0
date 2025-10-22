;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; very simple and "explosive" wildcard matcher
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module string
;; "." matches any char; "\" screens next char
: WILD-MATCH  ( saddr scount paddr pcount -- matched-flag )
  dup -?exit< 4drop false >?
  2>r dup -?exit< 2rdrop 2drop false >?
  << ( saddr scount | paddr pcount )
     r@ not?exit< 2rdrop 0= nip >?
     r1:@ c@ r1:1+! r0:1-!
     [char] * of?^| 2dup 2r@ recurse ?exit< 2rdrop 2drop true >?
                    dup ?< r1:1-! r0:1+! >? 1 under+ 1- 0 max |?
     [char] ? of?^| 2dup 2r@ recurse ?exit< 2rdrop 2drop true >?
                    1 under+ 1- 0 max |?
     [char] . of?^| dup -0?exit< 2rdrop 2drop false >? 1 under+ 1- |?
     dup [char] \ forth:= ?< r@ not?exit< 2rdrop 3drop false >?
                             drop r1:@ c@ r1:1+! r0:1-! >?
     dup not?exit< 2rdrop 3drop false >?
     >r over c@ r> of?^| 1 under+ 1- |?
  else| 2rdrop 3drop false >> ;
end-module
