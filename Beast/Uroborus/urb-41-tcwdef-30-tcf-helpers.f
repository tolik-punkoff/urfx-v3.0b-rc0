;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; some TCF helper words
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


tcf: >in-origin  system:?exec >in-origin ;tcf

tcf: (  [\\] ( ;tcf  ;; )
tcf: \  [\\] \ ;tcf
tcf: --  [\\] -- ;tcf
tcf: //  [\\] // ;tcf
tcf: (*  [\\] (* ;tcf  ;; *)
tcf: (+  [\\] (+ ;tcf  ;; +)

tcf: $INCLUDE  [\\] $include ;tcf

tcf: [IF]    [\\] forth:[IF] ;tcf
tcf: [IFNOT] [\\] forth:[IFNOT] ;tcf
tcf: [ELSE]  [\\] forth:[ELSE] ;tcf
tcf: [ENDIF] [\\] forth:[ENDIF] ;tcf
tcf: [HAS-WORD]
  ?in-target parse-name
  push-ctx (tc-forth-vocid) context!
  find pop-ctx ?< drop true || false >? ;tcf

tcf: [CHAR]
  ?comp-target parse-name 1 <> ?error" [CHAR] expects a char"
  c@ tgt-#, ;tcf


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; word flags

tcf: (arg-branch!)    ?exec-target tgt-wtype-branch tgt-latest-ffa-or! ;tcf
tcf: (arg-literal!)   ?exec-target tgt-wtype-literal tgt-latest-ffa-or! ;tcf

tcf: (private)   ?exec-target tgt-wflag-private tgt-latest-ffa-or!
                              tgt-wflag-published tgt-latest-ffa-~and! ;tcf
tcf: (public)    ?exec-target tgt-wflag-private tgt-latest-ffa-~and!
                              tgt-wflag-published tgt-latest-ffa-~and! ;tcf
tcf: (published) ?exec-target tgt-wflag-private tgt-latest-ffa-~and!
                              tgt-wflag-published tgt-latest-ffa-or! ;tcf
tcf: (noreturn)  ?exec-target tgt-wflag-noreturn tgt-latest-ffa-or! ;tcf

tcf: (inline-blocker)
  ?exec-target tgt-wflag-inline-blocker tgt-latest-ffa-or! ;tcf

\ tcf: (no-inline)
\   ?exec-target tgt-wflag-inline-allowed tgt-latest-ffa-~and! ;tcf

\ tcf: (allow-inline)
\   ?exec-target tgt-wflag-inline-allowed tgt-latest-ffa-or! ;tcf

tcf: (force-inline)
  ?exec-target
  tgt-latest-ffa tcom:@ tgt-wflag-inline-allowed and
  not?error" cannot set force-inline flag for non-inlineable word"
  tgt-wflag-inline-force tgt-latest-ffa-or! ;tcf

;; this word doesn't use stacks
tcf: (no-stacks)
  ?exec-target
  tgt-wflag-no-stacks tgt-latest-ffa-or! ;tcf

;; allow it to be compiled too
tcf: immediate
  ?in-target system:exec? ?exit< tgt-wflag-immediate tgt-latest-ffa-or! >?
  tgt-forwards:tgt-(immediate) dup not?error" `IMMEDIATE` is not defined yet" tgt-cc\, ;tcf


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utilities

: tgt-\\-prepare  ( -- shadow-pfa was-in-target )  \ name
  system:?comp in-target? dup >r not?< >in-target >?
  -find-required dup ?tgt-good-shadow
  dart:cfa>pfa r> ;

*: tgt-cc[\\]
  tgt-\\-prepare >r (shadow-tgt-cfa@) tgt-cc\, r> not?exit< >in-origin >? ;

*: tgt-[']
  tgt-\\-prepare >r (shadow-tgt-cfa@) tgt-#, r> not?exit< >in-origin >? ;

: tgt-xfind  ( -- pfa )  \ name
  ?in-target -find-required dup ?tgt-good-shadow dart:cfa>pfa ;

\ hack!
\ tcf: [[{#,}]]    ?comp-target tgt-#, ;tcf
tcfx: {#,}    ?comp-target tgt-#, ;tcf

\ tcf: {str#,} ?comp-target tgt-str#, ;tcf
\ tcf: #,     tgt-#, ;tcf
\ tcf: str#,  tgt-str#, ;tcf
;; "\\" is "(#) \,"
tcf: \\      ?comp-target tgt-xfind (shadow-tgt-cfa@) tgt-#, tgt-forwards:tgt-\,-ccfa tgt-cc\, ;tcf
tcf: [\\]    ?comp-target tgt-xfind (shadow-tgt-cfa@) tgt-cc\, ;tcf
tcf: [']     tgt-xfind (shadow-tgt-cfa@) tgt-#, ;tcf
tcf: ['PFA]  tgt-xfind (shadow-tgt-cfa@) tgt-cfa>pfa tgt-#, ;tcf
tcf: ['CCX]  tgt-xfind (shadow-tgt-cfa@) tgt-#, ;tcf

: tgt-cfa/pfa-prepare  ( -- shadow-pfa )
  ?in-target push-ctx (tc-forth-vocid) context!
  -find-required dup ?tgt-good-shadow dart:cfa>pfa ;

;; FIXME: vocab search doesn't work
;; use this in assembler code to get variable PFA
*: tgt-['pfa]  tgt-cfa/pfa-prepare (shadow-tgt-cfa@) tgt-cfa>pfa pop-ctx ;

;; FIXME: vocab search doesn't work
;; use this in assembler code to get word CFA
*: tgt-['cfa]  tgt-cfa/pfa-prepare (shadow-tgt-cfa@) pop-ctx ;

*: tgt-cstr,  ( addr count )  ?in-target tcom:cstr, ;


tcf: error"
  ?comp-target
  34 parse-qstr tgt-str#, tgt-forwards:tgt-(error) tgt-cc\, ;tcf
tcf: ?error"
  ?comp-target
  34 parse-qstr tgt-str#, tgt-forwards:tgt-(?error) tgt-cc\, ;tcf
tcf: not?error"
  ?comp-target
  34 parse-qstr tgt-str#, tgt-forwards:tgt-(not?error) tgt-cc\, ;tcf


tcf: vocid:
  ?in-target -find-required
  dup tgt-vocab? not?error" vocabulary name expected"
  dart:cfa>pfa (shadow-tgt-voc@) tgt-#, ;tcf

;; create allot
tcf: mk-buffer ( size )  \ name
  ?exec-target
  dup 4 < ?error" invalid buffer size" >r
  0 tgt-variable r> 4- tcom:reserve ;tcf

tcf: create  \ name
  ?exec-target tgt-create ;tcf

tcf: create;  ( tcom:forth-align-here) 4 tcom:xalign ;tcf

tcf: allot  ( n )
  ?exec-target dup 0< ?error" wut?!" tcom:allot ;tcf


: tgt-rectail,  ( brn )
  system:?comp tgt-latest-cfa swap Succubus:branch-to ;

;; it still can be inlined if it contains no "EXIT"s
tcf: recurse  system:?comp Succubus:cannot-inline
                           tgt-latest-cfa Succubus:high:call ;tcf
tcf: recurse-tail      Succubus:(branch) tgt-rectail, ;tcf
tcf: ?recurse-tail     Succubus:(tbranch) tgt-rectail, ;tcf
tcf: not?recurse-tail  Succubus:(0branch) tgt-rectail, ;tcf
tcf: +?recurse-tail    Succubus:(+branch) tgt-rectail, ;tcf
tcf: -?recurse-tail    Succubus:(-branch) tgt-rectail, ;tcf
tcf: +0?recurse-tail   Succubus:(+0branch) tgt-rectail, ;tcf
tcf: -0?recurse-tail   Succubus:(-0branch) tgt-rectail, ;tcf

;; compile string literal
tcf: "  34 parse-qstr tgt-str#, ;tcf

tcf: ."  34 parse-qstr tgt-str#,  tgt-forwards:tgt-(type) tgt-cc\, ;tcf


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; code words

false quan tgt-flag-code-disable-inline?
\ 0 quan tgt-code-word-start^
0 quan tgt-code-word-type


: tgt-code-word-reset-inlineable
  tgt-wflag-inline-allowed tgt-latest-ffa-~and! ;

: tgt-code-word-set-inlineable
  tgt-wflag-inline-allowed tgt-latest-ffa-or! ;

: tgt-start-code-word  \ name
  ?exec-target tgt-prim-count:1+!
  parse-name
  tgt-prim-listing ?< 2dup endcr ." PRIMITIVE #" tgt-prim-count 0.r ." : " type cr >?
  tgt-create-code-word
  tgt-debug-record-comment
  tgt-code-pair x86-start
  x86asm:in-swapped?:!0
  tgt-flag-code-disable-inline?:!f
  x86asm-no-reg-jumps?:!f
  Succubus:start-code-word ;

: tgt-finish-code-word  \ name
  ?exec-target x86-end tgt-code-pair system:?pairs
  tgt-code-word-type ?error" unfinished cw type"
  tgt-flag-code-disable-inline? ?<
    Succubus:can-inline?:!f
    tgt-flag-code-disable-inline?:!f >?
  Succubus:can-inline? not?<
    Succubus:not-inlineable-word
    tgt-code-word-reset-inlineable
  || tgt-code-word-set-inlineable >?
  Succubus:finish-code-word ;

: tgt-create-dummy-word  ( addr count )
  ?exec-target
  dup 1 tgt-#wname-max bounds not?error" invalid word name"
  tgt-prim-listing ?< 2dup endcr ." DUMMY PRIMITIVE #" tgt-prim-count 0.r ." : " type cr >?
  true tgt-align-dict \ 4 tgt-align-code
  2dup (tgt-mk-header-ex)
  tgt-wflag-dummy-word tgt-latest-ffa-or!
  ['] (tgt-does-dummy) (tgt-mk-rest2)
  $CC tcom:c, ( trap opcode, just in case) ;


: tgt-start-typed-code-chunk  ( type )
  tgt-code-word-type ?error" duplicate cw type"
  x86asm:emit:flush
  Succubus:ilendb:cg-begin
  tgt-code-word-type:! tgt-cword-ilendb-skip:!t ;

: tgt-finish-typed-code-chunk
  tgt-code-word-type ?<
    x86asm:emit:flush
\ endcr ." special len=" tcom:here Succubus:ilendb:cg-begin-here - .
\       ." at $" Succubus:ilendb:cg-begin-here .hex8
\       ."  up to $" tcom:here .hex8
\       ."  type=" tgt-code-word-type 0.r cr
    tgt-code-word-type Succubus:ilendb:cg-end-typed
    tgt-code-word-type:!0
    tgt-cword-ilendb-skip:!f >? ;


;; define new "dummy" asm word without any action
;; there is no need to align it at all.
tcf: code-dummy:  \ name
  parse-name tgt-create-dummy-word ;tcf


tcf: [[code-type-idiv]]   Succubus:ilendb:it-prim-idiv tgt-start-typed-code-chunk ;tcf
tcf: [[code-type-imod]]   Succubus:ilendb:it-prim-imod tgt-start-typed-code-chunk ;tcf
tcf: [[code-type-max]]    Succubus:ilendb:it-prim-max tgt-start-typed-code-chunk ;tcf
tcf: [[code-type-umod]]   Succubus:ilendb:it-prim-umod tgt-start-typed-code-chunk ;tcf
tcf: [[code-type-ndrop]]  Succubus:ilendb:it-prim-ndrop tgt-start-typed-code-chunk ;tcf
tcf: [[code-type-nrdrop]] Succubus:ilendb:it-prim-nrdrop tgt-start-typed-code-chunk ;tcf
tcf: [[code-type-rpush]]  Succubus:ilendb:it-prim-rpush tgt-start-typed-code-chunk ;tcf
tcf: [[code-type-rpop]]   Succubus:ilendb:it-prim-rpop tgt-start-typed-code-chunk ;tcf

tcf: [[code-type-finish]] tgt-finish-typed-code-chunk ;tcf


;; define new code words
tcf: code-naked-inline:  \ name
  tgt-start-code-word ;tcf

tcf: code-swap-inline:  \ name
  tgt-start-code-word
  x86asm:instructions:swap-stacks ;tcf

tcf: code-swap-inline-no-reg-jumps:  \ name
  tgt-start-code-word
  x86asm-no-reg-jumps?:!t
  x86asm:instructions:swap-stacks ;tcf


;; define new code words
tcf: code-naked-no-inline:  \ name
  tgt-start-code-word
  tgt-flag-code-disable-inline?:!t ;tcf

tcf: code-swap-no-inline:  \ name
  tgt-start-code-word
  tgt-flag-code-disable-inline?:!t
  x86asm:instructions:swap-stacks ;tcf


\ tcf: ;code-no-inline
\   x86asm:instructions:beast-nextjmp
\   tgt-flag-code-disable-inline?:!t
\   tgt-finish-code-word ;tcf

tcf: ;code-no-next
  tgt-finish-typed-code-chunk
  tgt-finish-code-word ;tcf

tcf: ;code-next
  tgt-finish-typed-code-chunk
  x86asm:instructions:beast-nextjmp
  tgt-finish-code-word ;tcf

tcf: ;code-no-stacks
  tgt-finish-typed-code-chunk
  x86asm:instructions:beast-nextjmp
  tgt-finish-code-word ;tcf

tcf: ;code-swap-next
  tgt-finish-typed-code-chunk
  x86asm:instructions:swap-stacks
  x86asm:instructions:beast-nextjmp
  tgt-finish-code-word
  tgt-wflag-end-swap-next tgt-latest-ffa-or! ;tcf


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; enums

module (tgt-enum-internal)
<disable-hash>

;; etypes
0 constant (bit) (private)
1 constant (inc) (private)

|: (advance)  ( etype evalue -- etype enextvalue )
  over not?< dup ?< 2* || drop 1 >? || 1+ >? ;

: def:  ( etype evalue -- etype enextvalue )  \ name
  system:?exec
  dup tgt-constant
  (advance) ;

: }  ( etype evalue )
  2drop pop-ctx ;

: set      ( etype evalue newvalue -- etype newvalue )  nip ;
: set-bit  ( etype evalue newbit -- etype 1<<newbit )   nip 1 swap lshift ;
: -set     ( etype evalue delta -- etype evalue-delta ) - ;
: +set     ( etype evalue delta -- etype evalue+delta ) + ;

|: (activate)  push-ctx vocid: (tgt-enum-internal) context! ;

end-module (tgt-enum-internal)


extend-module FORTH

tcf: enum{  ( -- etype enextvalue )
  (tgt-enum-internal)::(inc) 0 (tgt-enum-internal)::(activate) ;tcf
tcf: enum-from{  ( start-value -- etype enextvalue )
  (tgt-enum-internal)::(inc) swap (tgt-enum-internal)::(activate) ;tcf
tcf: bitmask-enum{  ( -- etype enextvalue )
  (tgt-enum-internal)::(bit) 1 (tgt-enum-internal)::(activate) ;tcf

end-module FORTH
