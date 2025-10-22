;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; very simple REPL
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


: ACCEPT  ( addr count -- addr count TRUE // FALSE )
  dup 1 < ?error" invalid ACCEPT buffer size"
  >r 0 << ( addr count | limit )
    readkey  ( addr count ch | limit )
    10 of?v| true |?
    dup +0?^|  ( addr count ch | limit )
      over r@ >= ?error" ACCEPT buffer overflow"
      rot tuck c! 1+ swap 1+ |?
    else| drop dup ?< true || 2drop false >? >> rdrop
    ?< dup rot swap - swap true || false >? ;

: (EXPECT)  ( -- addr count TRUE // FALSE )
  (expect-buf) @ (#expect) @ accept ;

: EXPECT  ( -- addr count )
  (expect) not?< (expect-buf) @ 0 >? ;


module REPL
<disable-hash>

|: (.BASE)
  base @ 0d10 <> ?exit< [char] [ emit base @ dup decimal 0.r base ! [char] ] emit bl emit >? ;

|: .PROMPT
  endcr system:exec? ?< [char] > emit || ." ..>" >? ;

: OK
  endcr? not?< bl emit >? (.base)
  system:exec? ?< depth dup ?< dup [char] ( emit  0.r [char] ) emit bl emit >? drop ." ok\n" >? ;

: (QUIT)
  << ok .prompt (expect)
     ?^| #tib:! tib:! >in:!0 allow-refill?:!f interpret-hooks:repl?:!t
     interpret-tib interpret-hooks:repl?:!0 |? else| bye >> ; (noreturn)

: RESTART
  (sys-reset-cfa^) @execute
  tcall (quit) ;

end-module REPL

extend-module FORTH
using repl

: QUIT
  ['] repl:restart (segfault):restart-cfa !
  ['] repl:restart debug:abort-restart-cfa:!
  tcall repl:(quit) ; (noreturn)

end-module FORTH
