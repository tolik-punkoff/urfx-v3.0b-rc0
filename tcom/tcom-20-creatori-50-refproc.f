;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; word reference list
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

TCX-ONLY-OPTION-LOADER? [IFNOT]

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; recursive reference tracer

false constant DEBUG-TRACER?
false constant DEBUG-TRACER-EXTRA?

false constant ref-dump-marked
0 quan ref-dump-col


: (.ref-scfa)  ( shadow-cfa )
  ref-dump-marked 0?exit< drop >?
  dart:cfa>nfa
  dup idcount 1+ ref-dump-col:+! drop
  ref-dump-col 80 >= ?< cr ref-dump-col:!0 >?
  bl emit debug:.id ;


: ref-traced?  ( shadow-cfa -- flag )
  dart:cfa>pfa shword:tk-flags tkf-traced mask? ;

\ : ref-marked?  ( shadow-cfa -- flag )
\   dart:cfa>pfa shword:tk-flags tkf-used mask? ;

: (ref-mark-trace)  ( shadow-cfa )
  dup add-zx-used-word-scfa
  \ dup (.ref-scfa)
  \ #traced-refs:1+!
\ dup dart:cfa>nfa debug:.id cr
  dart:cfa>pfa shword:tk-flags:^  tkf-used  swap or! ;
['] (ref-mark-trace) to ref-mark-trace

: ref-mark  ( shadow-cfa )
\ endcr ."   RM0\n"
  dup add-zx-used-word-scfa
\ endcr ."   RM1\n"
  dup (.ref-scfa)
\ endcr ."   RM2\n"
  #traced-refs:1+!
  dart:cfa>pfa shword:tk-flags:^  tkf-used tkf-traced or  swap or! ;


: (trace-scfa)  ( shadow-cfa )
  [ DEBUG-TRACER? DEBUG-TRACER-EXTRA? or ] [IF]
    endcr dup .hex8 ."  XX-TR: $" dup .hex8 bl emit dup dart:cfa>nfa debug:.id
    dup ref-traced? ?< ."  (already traced)" >? cr
  [ENDIF]
  dup ref-traced? ?exit< drop >?
  [ 0 ] [IF]
    endcr dup .hex8 ."  TR: " dup dart:cfa>nfa debug:.id cr
    \ endcr ."  *** TR1 ***\n" debug:.s
  [ENDIF]
  dup ref-mark
  [ 0 ] [IF]
    endcr ."  *** TR2 ***\n" debug:.s
  [ENDIF]
\ dup >r
  [ DEBUG-TRACER-EXTRA? ] [IF]
    dup dart:cfa>pfa shword:ref-list
    dup ?<
      endcr ."  WORD LIST for \'" over dart:cfa>nfa debug:.id ." \'\n"
      << dup ?^| dup refrec:shadow-cfa
                 endcr ."   " dart:cfa>nfa debug:.id cr
                 refrec:next |?
      else| >>
    >? drop
  [ENDIF]
  dart:cfa>pfa shword:ref-list
  << dup ?^| dup refrec:shadow-cfa recurse  refrec:next |?
  else| drop >>
\ endcr ." TR-DONE: " r> dart:cfa>nfa debug:.id cr
;


|: ref-need-trace?  ( shadow-shadow-cfa -- flag )
  dart:cfa>pfa shword:tk-flags
  tkf-used tkf-traced or and  tkf-used = ;

|: (check-word)  ( cfa -- res )
  \ dup system:private? over system:smudged? or ?exit< drop false >?
  dup dart:cfa>pfa @ dup not?exit<
    drop endcr ." ERROR (no scfa): " dart:cfa>nfa debug:.id cr abort >?
  nip ;; we don't need the original CFA
  dup ref-need-trace? not?exit<
\ ."  SKIP-TRACE: " dup dart:cfa>nfa debug:.id  dup dart:cfa>pfa shword:tk-flags bl emit 0.r cr
    drop false >?
  ;; new used, but untraced word
\ ."  TRACE: " dup dart:cfa>nfa debug:.id cr
  dup (trace-scfa)
\ ."  DONE-TRACE: " dup dart:cfa>nfa debug:.id cr
\ debug:.s
  drop true ;

: (trace-used)
  << vocid: (zx-used-words) ['] (check-word) vocid-foreach ?^|| else| >> ;


: zx-trace  \ zx-name
  (trace-used)
  (-zx-find-ss-cfa)
  ref-dump-marked ?< endcr ." === ZX: " dup dart:cfa>nfa debug:.id ."  ===\n" >?
  (trace-scfa)
  ref-dump-marked ?< endcr ." referenced words: " #traced-refs 0.r, cr >? ;


: zx-show-traced-words
  ." ============ TRACED (" #traced-refs 0.r, ." ) ============\n"
  vocid: (zx-used-words) vocid-words
  ." --------------------------------\n" ;


|: (zx-word-type-str)  ( scfa -- addr count )
  dup zx-forth? ?exit< drop " FORTH" >?
  dup zx-code? ?exit< drop " CODE" >?
  dup zx-constant? ?exit< drop " CONST" >?
  dup zx-quan? ?exit< drop " QUAN" >?
  dup zx-vect? ?exit< drop " VECT" >?
  dup zx-variable? ?exit< drop " VAR" >?
  dup zx-does? ?exit< drop " DOES" >?
  dup zx-alias? ?exit< drop " ALIAS" >?
  \ [ OPT-ENABLE-FP? ] [IF]
  \ dup zx-fp? ?exit< drop " FP" >?
  \ dup zx-fp-xmem? ?exit< drop " FP-XMEM" >?
  \ [ENDIF]
  drop " <OTHER>" ;

|: (zx-show-traced-vars)  ( cfa -- 0 )
  endcr dup dart:cfa>nfa debug:.id
  dup dart:cfa>pfa @ (zx-word-type-str) ."  -- " type
  cr
  drop 0 ;

: zx-show-traced-vars
  vocid: (zx-used-words) ['] (zx-show-traced-vars) vocid-foreach drop ;

|: (zx-qvv?)  ( scfa -- flag )
  dup zx-quan? ?exit< drop true >?
  dup zx-vect? ?exit< drop true >?
  dup zx-variable? ?exit< drop true >?
  drop false ;

: zx-show-skipped-vars
  latest-defined-shadow-cfa << dup ?^|
    dup (zx-qvv?) ?<
      dup dart:cfa>pfa shword:tk-flags tkf-used and not?<
        endcr ." V-SKIP: " dup dart:cfa>nfa debug:.id cr
      \ || endcr ." V-USED: " dup dart:cfa>nfa debug:.id cr
      >?
    >?
    dart:cfa>pfa shword:prev-scfa
  |? else| drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; save list of used words

0 quan trace-fd

|: (wr-word)  ( cfa -- res )
  \ dup system:private? over system:smudged? or ?exit< drop false >?
  dart:cfa>nfa idcount  ( cols addr count )
  " REF: " trace-fd file:write
  trace-fd file:write
  " \n" trace-fd file:write
  0 ;

|: (wr-option)  ( addr count )
  2dup vocid: forth find-in-vocid not?exit<
    " cannot find option \'" pad$:!
    pad$:+ " \'" pad$:+
    pad$:@ error >?
  execute ;; get option value
  pad$:!0 pad$:#s bl pad$:c+
  pad$:+ " :!\n" pad$:+
  pad$:@ trace-fd file:write ;

|: (wr-all-options)
  " \\ compiler options\n" trace-fd file:write
  tcom:zx-init-code-size pad$:!0 pad$:#s
  "  tcom:zx-init-code-size:!\n" pad$:+
  pad$:@ trace-fd file:write
  " OPT-16BIT-MUL/DIV-UNROLLED?" (wr-option)
  \ " OPT-ENABLE-FP?" (wr-option)
  " OPT-RSTACK-BYTES" (wr-option)
  " OPT-ALLOW-INLINING?" (wr-option)
  " OPT-BASE-ADDRESS" (wr-option)
  \ " OPT-USE-UDG?" (wr-option)
  " OPT-BASIC-ERR-HANDLER?" (wr-option)
  ;; optimisers should be in the exactly same state too
  " OPT-OPTIMIZE-PEEPHOLE?" (wr-option)
  " OPT-OPTIMIZE-SUPER?" (wr-option)
  " OPT-OPTIMIZE-BRANCHES?" (wr-option)
  " OPT-RSTACK-ALWAYS-ALIGNED?" (wr-option)
  " OPT-SIMPLIFIED-IM?" (wr-option)
  " END-OPTS\n" trace-fd file:write
;

: write-trace-result  ( addr count )
  file:create trace-fd:!
  " \\ trace information for '" trace-fd file:write
  app-name count trace-fd file:write
  " '\n" trace-fd file:write
  vocid: (zx-used-words) ['] (wr-word) vocid-foreach drop
  " END-REFS\n" trace-fd file:write
  (wr-all-options)
  trace-fd file:close ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load list of used words

module trace-refs-loader-support
<disable-hash>

: REF:  \ word
  parse-name
\ endcr ." REF: " 2dup type cr
  0 nrot (add-zx-used-word) #traced-refs:1+! ;

: END-REFS
  pop-ctx
  #traced-refs ., ." words read.\n"
  \ zx-show-traced-words
  #traced-refs:!0 [\\] \eof ;

: END-OPTS
  abort ;
end-module

: include-trace-refs  ( addr count )
  (include-file)
  push-ctx voc-ctx: trace-refs-loader-support ;

[ELSE]  \ NOT TCX-ONLY-OPTION-LOADER?

module trace-opts-loader-support
<disable-hash>

: REF:  \ word
  parse-name 2drop ;

: END-REFS  ;

: END-OPTS
  pop-ctx [\\] \eof ;
end-module


: include-trace-options  ( addr count )
  (include-file)
  push-ctx voc-ctx: trace-opts-loader-support ;
[ENDIF]  \ NOT TCX-ONLY-OPTION-LOADER?


TCX-ONLY-OPTION-LOADER? [IFNOT]
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; debug words

: (dump-refs)  ( shadow-cfa )
  ." === ZX: " dup dart:cfa>nfa debug:.id ."  ===\n"
  dart:cfa>pfa shword:ref-list
  << dup ?^|
      ."  " dup refrec:shadow-cfa dart:cfa>nfa debug:.id cr
      refrec:next |?
  else| drop >> ;

: dump-refs  \ zx-name
  (-zx-find-ss-cfa) (dump-refs) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; labman label recording

false constant asm-lbl-record-debug

|: (local-label?)  ( addr count -- bool )
  [char] . string:find-ch dup ?< nip >? ;

;; record declared labels
|: (labman-new-label)  ( addr count )
  turnkey? not?exit< 2drop >? turnkey-pass2? ?exit< 2drop >?
  2dup (local-label?) ?exit< 2drop >?
  zx-compile-mode zxc-none = ?exit<
    ;; non-word label, mark as "ignore it"
    0 mk-lbl-word >?
  asm-lbl-record-debug ?<
    endcr ." NEW LABEL in '"
    zx-tk-curr-word-scfa dart:cfa>nfa debug:.id
    ." ' (around $" zxa:org@ .hex4 ." ): "
    2dup type cr >?
  2dup curr-word-scfa mk-lbl-word
  curr-word-scfa nrot ( udata) curr-word-spfa shword:def-labels:^ mk-lblrec ;
['] (labman-new-label) z80-labman:new-label-cb:!

;; record referenced labels
|: (labman-ref-label)  ( addr count )
  turnkey? not?exit< 2drop >? turnkey-pass2? ?exit< 2drop >?
  2dup (local-label?) ?exit< 2drop >?
  zx-compile-mode zxc-none = ?exit< 2drop >?
    \ 2dup find-lbl-word-pfa ?exit< 3drop >?
    \ ;; new forward
    \ -1 mk-lbl-word >?
  asm-lbl-record-debug ?<
    endcr ." LABEL REFERENCED in '"
    zx-tk-curr-word-scfa dart:cfa>nfa debug:.id
    ." ' (around $" zxa:org@ .hex4 ." ): "
    2dup type cr >?
  2dup -666 mk-lbl-word
  -666 nrot ( udata) curr-word-spfa shword:ref-labels:^ mk-lblrec ;
['] (labman-ref-label) z80-labman:ref-label-cb:!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; label reference resolving

;; this should be called after compiling the image. it will fix recorded
;; labels info, and add proper word references. after doing this, reference
;; tracer will properly mark asm words.
;; iterate all words, and make refs.

: (#HEXN)  ( u n -- addr count )
  base @ >r hex >r <# << r@ ?^| # r0:1-! |? else| rdrop >> #> r> base ! ;


|: (check-asm-lbl)  ( cfa -- 0 )
  dup dart:cfa>pfa @ -?exit<
    " wtf asm label '" pad$:! dup dart:cfa>nfa idcount pad$:+
    " ': " pad$:+  dart:cfa>pfa @ <#signed> pad$:+
     pad$:@ error >?
  drop 0 ;

false constant asm-ref-debug
false quan asm-ref-debug-fnx

|: (fix-asm-lbl-ref)  ( spfa )
  dup shword:ref-labels not?exit< drop >?
  \ asm-ref-debug ?< endcr dup shword:self-cfa dart:cfa>nfa debug:.id cr >?
  asm-ref-debug-fnx:!f
  dup shword:ref-labels << dup ?^|
    dup lblrec:name$ count find-lbl-word-pfa not?error" fuck!"
    @  ( spfa lbl^ lbl-scfa )
    dup ?<
      >r over r@ dart:cfa>pfa = ?<
        rdrop
        (*
        asm-ref-debug ?<
          asm-ref-debug-fnx not?< asm-ref-debug-fnx:!t endcr over shword:self-cfa dart:cfa>nfa debug:.id cr >?
          ."  lbl: " dup lblrec:name$ count type
          ."  -- self\n" >?
        *)
      ||
        asm-ref-debug ?<
          asm-ref-debug-fnx not?< asm-ref-debug-fnx:!t endcr over shword:self-cfa dart:cfa>nfa debug:.id cr >?
          ."  lbl: " dup lblrec:name$ count type
          ."  from '" r@ dart:cfa>nfa debug:.id ." '\n" >?
        ( spfa lbl^ | lbl-scfa )
        over r> swap shword:ref-list:^ mk-refrec
      >?
    || drop asm-ref-debug ?< asm-ref-debug-fnx not?< asm-ref-debug-fnx:!t endcr over shword:self-cfa dart:cfa>nfa debug:.id cr >?
                             ."  lbl: " dup lblrec:name$ count type
                             ."  -- global\n" >? >?
  lblrec:next |? else| >>
  2drop ;


: create-label-refs
  ;; just in case
  vocid: (zx-used-labels) ['] (check-asm-lbl) vocid-foreach drop
  ;; now loop over all shadow words
  latest-defined-shadow-cfa << dup ?^|
    dart:cfa>pfa dup (fix-asm-lbl-ref)
    shword:prev-scfa
  |? else| drop >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; quan processing

: zx-dump-zx-addrs
  endcr ." === ZX WORD LIST ===\n"
  latest-defined-shadow-cfa << dup ?^|
    dup dart:cfa>pfa dup shword:zx-begin swap shword:zx-end
    over 0>= over 0>= land ?<
      endcr ."   $" swap .hex4 ." :$" .hex4
      ."  is " dup dart:cfa>nfa debug:.id cr
    || 2drop >?
  dart:cfa>pfa shword:prev-scfa |? else| >> drop ;


|: (qref-mark-vect)  ( scfa )
  dup zx-vect? not?exit< drop >?
  dup dart:cfa>pfa shword:zx-begin dup -?exit< 2drop >?
  zx-w@
  [ OPT-TURNKEY-DEBUG? ] [IF] dup >r [ENDIF]
  zx-find-scfa-by-addr not?exit<
    [ OPT-TURNKEY-DEBUG? ] [IF] rdrop [ENDIF]
    drop >?
  ( quan-scfa val-scfa )
  [ OPT-TURNKEY-DEBUG? ] [IF]
    endcr ." VECT '" over dart:cfa>nfa debug:.id
    ." ' is '" dup dart:cfa>nfa debug:.id
    ." ' zx-addr: $" r> .hex4
    cr
  [ENDIF]
  swap dart:cfa>pfa shword:ref-list:^ mk-refrec ;


: create-quan-refs
  \ [ OPT-TURNKEY-DEBUG? ] [IF] zx-dump-zx-addrs [ENDIF]
  latest-defined-shadow-cfa << dup ?^|
    dup (qref-mark-vect)
    dart:cfa>pfa shword:prev-scfa |? else| >>
  drop ;

[ENDIF]  \ NOT TCX-ONLY-OPTION-LOADER?


end-module
