;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TCOM high-level utilities
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; `(MAIN-WORD)` management

-1 quan (zx-main-word-scfa)

|: (zx-poke-main)
  ;; find "MAIN" vect
  " (MAIN-WORD)" (zx-find-ss-cfa-$)
  dup zx-forward? ?error" wtf?! \'(MAIN-WORD)\' is declared as forward!"
  dup zx-vect? not?error" vect expected"
  ;; pasta from "40-zx-mode.f"
  ss-cfa-zx-addr@
  (zx-main-word-scfa) ss-cfa-zx-addr@
  swap zx-w! ;

;; utility word, to be called in "zx-main.f"
: zx-set-main  \ word
  zx-?exec
  (-zx-find-ss) drop >r ( | shadow-cfa )
  endcr ." setting main app word to '"
  r@ dart:cfa>pfa shword:self-cfa dart:cfa>nfa debug:.id ." '\n"
  r> (zx-main-word-scfa):!
  (zx-poke-main) ;

: zx-set-main-auto
  turnkey? not?exit
  (zx-main-word-scfa) -?<
    latest-defined-shadow-cfa (zx-main-word-scfa):!
    endcr ." automatically set main app word to '"
    latest-defined-shadow-cfa dart:cfa>nfa debug:.id
    ." '\n"
    (zx-poke-main) >?
;

: (zx-trace-main)
  zx-?exec
  turnkey-pass1? not?exit
  create-label-refs
  create-quan-refs
  (trace-used)
  (zx-main-word-scfa) (trace-scfa)
  \ zx-show-traced-vars
  \ zx-show-skipped-vars
;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; for zx libraries

struct:new zxlib-info
  field: name$    ;; dynstr
  field: zx-dp    ;; start
  field: prev
end-struct

0 quan zxlib-info-last

;; usage:
;;   zxlib-begin" dispname"
;;   ...
;;   zxlib-end
*: zxlib-begin"  \ dispname
  system:?exec zx-?exec
  34 parse-qstr
  ;; use compiler unescaper
  system:Succubus:slc-unescape
  string:$new
  zxlib-info:@size-of dynmem:?alloc
  dup >r
  zxlib-info:name$:!
  zx-here r@ zxlib-info:zx-dp:!
  zxlib-info-last r@ zxlib-info:prev:!
  r> zxlib-info-last:! ;

*: zxlib-msg?
  system:?exec zx-?exec
  turnkey? 0= turnkey-pass2? lor ;

*: zxlib-end
  system:?exec zx-?exec
  zxlib-info-last 0?error" unbalanced zx libs"
  [\\] zxlib-msg? ?<
    endcr zxlib-info-last zxlib-info:name$ count type
    ."  size: " zx-here zxlib-info-last zxlib-info:zx-dp - .bytes cr >?
  zxlib-info-last dup zxlib-info:prev zxlib-info-last:!
  ;; free memory
  [ 1 ] [IF]
    dup zxlib-info:name$ string:$free
    dynmem:free
  [ELSE]
    drop
  [ENDIF]
;

end-module TCOM
