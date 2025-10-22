;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some basic words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

;; this is used to search for ZX constants
module ZX-CONSTS
end-module


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; start and finish ZX definitions

module ZX-DEFS
<disable-hash>

*: <zx-done>
  system:?exec zx-?exec
  pop-ctx
  context@ vocid: zx-defs = not?error" unfinished contexts"
  pop-ctx pop-ctx ;

end-module ZX-DEFS

: <zx-definitions>
  push-ctx voc-ctx: tcom
  push-ctx voc-ctx: zx-defs
  push-ctx voc-ctx: zx-consts
  <zx-forth> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utilities

: zx-latest-scfa  ( -- scfa )  curr-word-scfa ;
: zx-latest-spfa  ( -- scfa )  curr-word-spfa ;

(*
: zx-latest-pfa  ( -- zx-pfa )
  curr-word-spfa shword:zx-pfa dup -?exit<
    drop " no ZX PFA for word '" pad$:!
    curr-word-snfa idcount pad$:+
    " '" pad$:+ pad$:@ error
  >? ;
*)


;; mark the last word as "can be called recursively"
: zx-recursive      tkf-allow-recurse zx-latest-spfa shword:tk-flags:^ or! ;
;; reverse of the above
: zx-non-recursive  tkf-allow-recurse zx-latest-spfa shword:tk-flags:^ ~and! ;

;; mark the last word as "should be inlined"
: zx-inline     tkf-allow-inline zx-latest-spfa shword:tk-flags:^ or! ;
;; reverse of the above
: zx-no-inline  tkf-allow-inline zx-latest-spfa shword:tk-flags:^ ~and! ;

: zx-no-return  tkf-no-return zx-latest-spfa shword:tk-flags:^ or! ;

: zx-no-optim  tkf-no-optim zx-latest-spfa shword:tk-flags:^ or! ;


extend-module Succubus

module ncg-compilers
<separate-hash>
end-module

module mk-cgen-inplace
<disable-hash>

0 quan (saved-ctx)
0 quan (saved-cur)
0 quan (saved-zx-ctx)
0 quan (saved-zx-cur)

*: ;
  [\\] forth:;
  ( cfa )
  pop-ctx
  context@ vocid: xasm = ?< pop-ctx >?
  pop-ctx pop-ctx
  context@ (saved-ctx) = not?error" module imbalance!"
  pop-cur
  current@ (saved-cur) = not?error" module imbalance!"
  setters:compiler
  ;; restore ZX mode
  <zx-definitions>
  mk-cgen-inplace:(saved-zx-ctx) zx-shadow-context:!
  mk-cgen-inplace:(saved-zx-cur) zx-shadow-current:!
;

end-module mk-cgen-inplace


;; used in ZX sources to create codegens in-place.
;; create codegen for the last declared primitive
: (:codegen)  ( invite-xasm? )
  system:?exec zx-?exec
  zx-shadow-context mk-cgen-inplace:(saved-zx-ctx):!
  zx-shadow-current mk-cgen-inplace:(saved-zx-cur):!
  [\\] zx-defs:<zx-done>
  context@ mk-cgen-inplace:(saved-ctx):!
  current@ mk-cgen-inplace:(saved-cur):!
  push-ctx voc-ctx: tcom
  push-ctx voc-ctx: IR
  ?< push-ctx voc-ctx: xasm >?
  push-ctx voc-ctx: mk-cgen-inplace ;; for semicolon
  push-cur voc-cur: ncg-compilers
  [\\] :noname ;

end-module Succubus

*: :codegen       false Succubus:(:codegen) ;
*: :codegen-xasm  true Succubus:(:codegen) ;


end-module TCOM
