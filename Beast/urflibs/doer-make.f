;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Leo Brodie's DOER/MAKE implementation
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module system

|: (DOER-DOES)  ( pfa )  @execute-tail ;

: DOER?  ( cfa -- flag )
  dup does? not?exit< drop false >?
  doer@ ['] (doer-does) = ;

|: (MAKE)  ( doer-pfa )  system:rr> swap ! ; (noreturn)

|: (<MAKE)  ( doer-pfa )
  system:rr>  @++ ( skip branch ) system:>rr  swap ! ; (noreturn)

end-module


: DOER  \ name
  <builds ['] noop , system:latest-cfa ['] system::(doer-does) system:!doer ;

*: MAKE  \ name
  -find-required dup system:doer? not?error" DOER word expected" dart:cfa>pfa
  system:comp?
  ?< #, ['] system::(make) <\, \> ( it must be done this way to please Succubus)
  || >r [\\] :noname swap dart:cfa>pfa r> ! >? ;

*: <MAKE  \ name
  -find-required dup system:doer? not?error" DOER word expected" dart:cfa>pfa
  system:?comp
  #, ['] system::(<make) <\, here 0 , \>
  ['] system::(doer-does) ( ctlid ) ;

*: MAKE>
  system:?comp
  ['] system::(doer-does) system:?pairs
  \\ exit
  here swap ! ;


\EOF
doer xtest

\ $use <x86dis>

: set-xtest
  ." setting...\n"
  <make xtest ." hey!\n" 666 0.r cr make>
  ." setting complete.\n" ;
\ debug:see set-xtest

xtest
set-xtest
xtest


\ EOF
DOER ANSWER
: RECITAL
   CR ." YOUR DADDY IS STANDING ON THE TABLE.  ASK HIM 'WHY?'\n"
   MAKE ANSWER  ." TO CHANGE THE LIGHT BULB.\n"
   BEGIN
      MAKE ANSWER  ." BECAUSE IT'S BURNED OUT.\n"
      MAKE ANSWER  ." BECAUSE IT WAS OLD.\n"
      MAKE ANSWER  ." BECAUSE WE PUT IT IN THERE A LONG TIME AGO.\n"
      MAKE ANSWER  ." BECAUSE IT WAS DARK!\n"
      MAKE ANSWER  ." BECAUSE IT WAS NIGHT TIME!!\n"
      MAKE ANSWER  ." STOP SAYING WHY?\n"
      MAKE ANSWER  ." BECAUSE IT'S DRIVING ME CRAZY.\n"
      MAKE ANSWER  ." JUST LET ME CHANGE THIS LIGHT BULB!\n"
   REPEAT ;
: WHY?   ANSWER ;

recital
." asking: " why?
." asking: " why?
." asking: " why?
." asking: " why?
." asking: " why?
." asking: " why?
." asking: " why?
." asking: " why?
." asking: " why?
." asking: " why?
." asking: " why?
