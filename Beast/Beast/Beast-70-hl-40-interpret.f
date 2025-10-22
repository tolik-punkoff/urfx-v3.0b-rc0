;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; interpreter
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module INTERPRET-HOOKS
<disable-hash>

0 quan START-POS
0 quan REPL?

;; called after numetic literal was parsed (Uroborus needs this)
\ chained DO-LITERAL  ( lit -- 0:lit // !0: <none>)

end-module INTERPRET-HOOKS


extend-module FORTH
\ using interpret-hooks


module INTERPRETER
<disable-hash>

;; this can be used in "not found" handlers to interpret partial words
: RUN-COMPILE  ( cfa )
  ws-vocid-hit system:run-execcomp ( cfa vocid -- ... TRUE // cfa FALSE ) ?exit
  system:exec? over system:immediate? or ?< execute-tail >?
  \, ;

: DO-LITERAL  ( number )
  find-try-literal ( lit -- lit FALSE // TRUE ) ?exit
  \ interpret-hooks:do-literal ?exit
  [\\] {#,} ;

: NOT-FOUND  ( addr count )
  ;; try notfound handlers
  find-try-notfound ( addr count -- addr count FALSE // TRUE ) ?exit
  ( error )
  bl emit [char] ' emit 2dup type ." ' -- wut?\n"
  " \'" pad$:! pad$:+ " \' what?" pad$:+
  pad$:@ tcall error ;

: PROCESS-WORD  ( addr count )
  2dup 2>r find ?exit< 2rdrop tcall run-compile >?
  2r@ base @ numparse:snumber ?exit< 2rdrop tcall do-literal >?
  2r> tcall not-found ;

end-module INTERPRETER


{no-inline}
: INTERPRET-WORD  ( addr count )
  tcall interpreter:process-word ;

{no-inline}
: INTERPRET-TIB
  << skip-blanks >in interpret-hooks:start-pos:!
     parse-name/none dup ?^| interpret-word |?
  else| 2drop >> ;

{no-inline}
: INTERPRET
  << interpret-tib
     interpret-hooks:repl? not?<
       system:comp? ?error" compiler cannot cross file boundaries" >?
     allow-refill? not?v||
     refill cor pop-include ?^||
  else| >> ;

;; interpret until end of the current include
: INTERPRET-REST
  << interpret-tib
     interpret-hooks:repl? not?<
       system:comp? ?error" compiler cannot cross file boundaries" >?
     allow-refill? not?v||
     refill ?^||
  else| >> ;

end-module FORTH
