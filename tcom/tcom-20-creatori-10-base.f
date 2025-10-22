;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some basic words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX statistics

;; number of corresponding words
0 quan zx-stats-code
0 quan zx-stats-colon
0 quan zx-stats-var
0 quan zx-stats-const
0 quan zx-stats-quan
0 quan zx-stats-vect
0 quan zx-stats-alias

;; number of words created
0 quan zx-stats-words
0 quan zx-stats-prims

;; bytes wasted on machine code
0 quan zx-stats-mcode-bytes
;; bytes wasted on threaded code
0 quan zx-stats-tcode-bytes
;; data bytes
0 quan zx-stats-data-bytes

;; number of forward references
0 quan zx-stats-forwards

0 quan zx-stats-peepbranch
0 quan zx-stats-peephole-addsub


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX utilities

 0 constant zxc-none
-1 constant zxc-code
 1 constant zxc-colon
zxc-none quan zx-compile-mode
enum{
  def: zxcode-bad
  def: zxcode-raw
  def: zxcode-cooked
}
0 quan zx-code-word-type

$C3 constant zx-jp-opcode
$CD constant zx-call-opcode

;; used in "RECURSE"
0 quan zx-latest-cfa  ;; always valid (but may point to the actual code for code words in DTC mode)

;; use separate variable for "zx compiler is active" state.
;; this is because in the future there could be no ZX `STATE` variable.
0 quan (zx-compiling?)

: zx-comp!  (zx-compiling?):!t ;
: zx-exec!  (zx-compiling?):!f ;

: zx-comp?  ( -- flag )  (zx-compiling?) 0<> ;
: zx-exec?  ( -- flag )  (zx-compiling?) 0= ;

: zx-?comp  zx-comp? not?error" ZX compilation mode expected" ;
: zx-?exec  zx-exec? not?error" ZX execution mode expected" ;

: zx-?in-colon
  system:?exec zx-?comp
  zx-compile-mode zxc-colon = not?error" ZX colon word was not started yet" ;


*: @asm-label:  ( -- value )  \ name
  parse-name z80-labman:@get
  [\\] {#,} ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; shadow words (creation, doers, etc.)

;; new shadows will be created here
0 quan zx-shadow-current
;; new shadows will be searched here
0 quan zx-shadow-context

: <zx-current-forth>   vocid: forth-shadows zx-shadow-current:! ;
: <zx-current-system>  vocid: system-shadows zx-shadow-current:! ;

: <zx-context-forth>   vocid: forth-shadows zx-shadow-context:! ;
: <zx-context-system>  vocid: system-shadows zx-shadow-context:! ;

: <zx-forth>   <zx-current-forth> <zx-context-forth> ;
: <zx-system>  <zx-current-system> <zx-context-system> ;


end-module
