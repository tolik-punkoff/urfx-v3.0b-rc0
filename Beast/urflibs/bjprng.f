;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Bob Jenkins' small-and-fast PRNG
;; http://burtleburtle.net/bob/rand/smallprng.html
;; left here for compatibility only
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module bjprng
<disable-hash>
<published-words>

prng:#bj-state constant #state

alias-for prng:bj-next is next-fast
alias-for prng:bj-seed is seed-fast

alias-for prng:bj-next-slow is next
alias-for prng:bj-seed-slow is seed

seal-module
end-module

\ create ctx bjprng:#state allot create;
\ 669 ctx bjprng:seed
\ ctx bjprng:next .hex8 cr
