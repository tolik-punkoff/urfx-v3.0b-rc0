;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; analyze compiled word and check if it is suitable for inlining
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module anal
<disable-hash>

: analyze
  has-back-jumps? ?< word-has-back-jumps >?
  can-inline? not?exit< not-inlineable-word >?
  can-inline?:!f  ;; for now
  has-rets? ?exit< not-inlineable-word >?
  allow-forth-inlining-analysis not?exit< not-inlineable-word >?
  noreturn-word? ?exit< not-inlineable-word >?
  ;; do not inline immediates
  immediate-word? ?exit< not-inlineable-word >?
  inline-force-word? not?<
    #inline-bytes dup -0?exit< drop not-inlineable-word >?
    ;; check length
    code-here code-start^ - u< ?exit< not-inlineable-word >? >?
  can-inline?:!t  ;; restore the flag
  stat-words-inlineable:1+!
  inlineable-word ;

end-module anal
