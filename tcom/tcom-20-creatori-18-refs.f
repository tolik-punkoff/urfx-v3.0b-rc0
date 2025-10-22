;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; word reference list
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

;; word reference item
struct:new refrec
  field: next       -- 0: no more
  field: shadow-cfa -- obviously
end-struct

;; defined label item
struct:new lblrec
  field: next     -- 0: no more
  field: name$    -- dynamically allocated string
  field: def-scfa -- scfa of the owner word
end-struct


0 quan #traced-refs


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; list of used words for turnkey pass 1 and 2

module (ZX-USED-WORDS)
\ <disable-hash>
<separate-hash>
end-module

: (add-zx-used-word)  ( shadow-cfa addr count )
  2dup vocid: (zx-used-words) find-in-vocid ?exit<
\ >r 2dup ." {DUP: " type ." }" r>
    4drop >?
\ 2dup ." {NEW: " type ." }"
  push-cur vocid: (zx-used-words) current!
  system:mk-create
    ( shadow-cfa) ,
  pop-cur ;


: add-zx-used-word-scfa  ( shadow-cfa )
  turnkey-pass1? not?exit< drop >?
  dup dart:cfa>nfa idcount (add-zx-used-word) ;

: tk-zx-word-used?  ( shadow-cfa -- flag )
  dart:cfa>nfa idcount
  vocid: (zx-used-words) find-in-vocid
  dup ?< swap drop >? ;

;; called by `(mk-shadow-header)`
: fix-used-word-cfa  ( shadow-cfa )
  turnkey-pass2? not?exit< drop >?
  \ dup dart:cfa>pfa shword:tk-flags tkf-recorded and ?exit< drop >?
  dup dart:cfa>nfa idcount vocid: (zx-used-words) find-in-vocid not?exit<
    \ OPT-TURNKEY-DEBUG? ?< endcr ." SKIP-WORD: " dup dart:cfa>nfa debug:.id cr >?
    drop >?
  ( shadow-cfa used-cfa )
  over dart:cfa>pfa tkf-used swap shword:tk-flags:^ or!   ;; pass2 needs this flag
  dart:cfa>pfa ! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; list of word references

;; slow, but ZX Forth words are small.
|: find-refrec  ( shadow-cfa chain-head^ -- rec^ // 0 )
  swap >r @
  << dup 0?v||
     dup refrec:shadow-cfa r@ = ?v||
  ^| refrec:next | >>
  rdrop ;

: mk-refrec  ( shadow-cfa chain-head^ )
  2dup find-refrec ?exit< 2drop >?
  align-here-4 here
  ( scfa chead^ rec^ )
    ( next) over @ ,
    ( shadowcfa) rot ,
  swap ! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; list of label references

module (ZX-USED-LABELS)
\ <disable-hash>
<separate-hash>
end-module

: find-lbl-word-pfa  ( addr count -- pfa TRUE // FALSE )
  vocid: (zx-used-labels) find-in-vocid ?< dart:cfa>pfa true || false >? ;

: mk-lbl-word  ( addr count value )
  \ >r 2dup vocid: (zx-used-labels) find-in-vocid ?exit< rdrop
  \   " duplicate asm label \'" pad$:! pad$:+ " \'!" pad$:+ pad$:@ error >?
  >r 2dup find-lbl-word-pfa ?exit<
    ( addr count pfa | value )
    dup @ r@ = ?exit< rdrop 3drop >?
    r@ +0?< dup @ -?< true || dup @ r@ = >?
         || true >?
    not?exit<
      endcr ." *** rec^:" @ . ." value:" r> 0.r cr
      " duplicate asm label \'" pad$:! pad$:+ " \'!" pad$:+ pad$:@ error >?
    ( addr count pfa | value )
    r@ +0?< r> swap ! || r> 2drop >?
    2drop >?
  ( addr count | value )
  push-cur vocid: (zx-used-labels) current!
  system:mk-create
    ( rec^) r> ,
  pop-cur ;


: mk-lbl-word-rec  ( rec^ )
  dup lblrec:name$ count
  ( rec^ addr count )
  rot mk-lbl-word ;


: find-lbl-record  ( addr count -- rec^ )
  2dup find-lbl-word-pfa not?exit<
    \ " no asm label \'" pad$:! pad$:+ " \'!" pad$:+ pad$:@ error
    false not ?< endcr ." NEW ASM FWD: " 2dup type cr >?
    -1 mk-lbl-word
    -1 >?
  nrot 2drop
  dart:cfa>pfa @ ;


;; slow, but ZX Forth words are small.
: find-lblrec  ( addr count chain-head^ -- rec^ // 0 )
  nrot 2>r @
  << dup 0?v||
\ endcr dup lblrec:name$ count type cr
     dup lblrec:name$ count 2r@ string:=ci ?v||
  ^| lblrec:next | >>
  2rdrop ;

: mk-lblrec  ( def-scfa addr count chain-head^ )
  >r 2dup r@ find-lblrec ?exit< 3drop rdrop >?
  r> align-here-4 here >r
  ( def-scfa addr count chain-head^ | rec^ )
    ( next) dup @ ,
    ( name$) nrot string:$new ,
    ( def-scfa) swap ,
  ( chain-head^ | rec )
  r> swap ! ;


end-module
