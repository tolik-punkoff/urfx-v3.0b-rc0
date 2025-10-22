;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create shadow words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; each ZX word will have the corresponding "shadow" word, which
;; keeps the info for TC, like ZX address and such.
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; forwards support

;; register fixup chain address at "zx-here", if necessary.
: spfa-with-ofs->zx-addr  ( shadow-pfa ofs fix-type -- zx-addr )
  >r >r dup shword:zx-begin dup +0?exit< nip r> + rdrop >?
  ( shadow-pfa zx-addr | fix-type ofs )
  drop
  ( shadow-pfa | fix-type ofs )
  ;; on the second pass fixups to or in uninteresing words should be ignored
  turnkey-pass2? ?<
    curr-word-spfa shword:tk-flags tkf-used and 0?exit<
      OPT-TURNKEY-DEBUG? ?<
        endcr ." SKIP FWD in '" curr-word-snfa debug:.id
        ." ' for '" dup shword:self-cfa dart:cfa>nfa debug:.id
        ." '\n" >?
      drop 0 2rdrop >?
    ;; sanity check
    dup shword:tk-flags tkf-used and 0?exit<
      " forward reference to unused ZX word \'" pad$:!
      shword:self-cfa dart:cfa>nfa idcount pad$:+
      " \'!" pad$:+
      pad$:@ error >?
  >?
  zx-stats-forwards:1+!
  dup
  ( shadow-pfa shadow-pfa | fix-type ofs )
  zx-here swap shword:fwdfix-chain:^ r> r> swap >r mk-fixup
  ( shadow-pfa fixrec^ | ofs )
  tuck fixrec:spfa:!
  curr-word-spfa swap fixrec:curr-spfa:!
  r> ;

: spfa-with-ofs->zx-addr-w,  ( shadow-pfa ofs fix-type )
  spfa-with-ofs->zx-addr zx-w, ;

: spfa->zx-addr  ( shadow-pfa fix-type -- zx-addr )
  0 swap spfa-with-ofs->zx-addr ;

: spfa->zx-addr-w,  ( shadow-pfa fix-type )
  0 swap spfa-with-ofs->zx-addr-w, ;


: shadow-resolve-alias-scfa  ( shadow-cfa -- shadow-cfa )
  dup dart:cfa>pfa shword:zx-alias-scfa dup 0?exit< drop >?
\ endcr ." ZX alias '" over dart:cfa>nfa debug:.id ." ' routed to "
  \ dup 0?exit< ." <NOTHING!>" abort >?
  nip << dup dart:cfa>pfa shword:zx-alias-scfa dup ?^| nip |? else| drop >>
\ ." '" dup dart:cfa>nfa debug:.id ." '\n"
;

: shadow-resolve-alias-spfa  ( shadow-pfa -- shadow-pfa )
  shword:self-cfa shadow-resolve-alias-scfa dart:cfa>pfa ;


: record-ref-spfa  ( shadow-pfa )
  dup 0?error" record-ref-spfa: zero pfa!"
  ;; do not bother recording primitives, they have no body anyway
  ;; nope, primitives may require other words
  \ dup shword:tk-flags tkf-primitive and ?exit< drop >?
  shword:self-cfa dup 0?error" record-ref-spfa: zero self-cfa!"
  [ 0 ] [IF]
    endcr ." RECORDING in \'" curr-word-snfa debug:.id
    ." \' -- " dup dart:cfa>nfa debug:.id
    cr
  [ENDIF]
  curr-word-spfa shword:ref-list:^
\ turnkey-pass1? ?< dup @ 0?< ." === " curr-word-scfa debug:.id ."  ===\n" >? >?
  mk-refrec ;

|: ir-append-spfa  ( shadow-pfa )
  shadow-resolve-alias-spfa
  ir:new-node 2dup ir:node:spfa:! nip
  ir:append ;


;; compile call to shadow word zx-addr.
;; takes care of forward fixup chain.
: ss-call,  ( shadow-pfa )
  ;; inlining will be done in the codegen
  ir-append-spfa ;

;; fail on forwards
: ss-cfa-zx-addr@  ( shadow-cfa -- zx-addr )
  dup dart:cfa>pfa shword:zx-begin dup -?< drop
    " cannot use undefined ZX forward word \'" string:>pad
    dart:cfa>nfa idcount string:pad+cc
    " \'!" string:pad+cc
    string:pad-cc@ error >?
  nip ;

: ss-cfa-zx-addr@-tk2  ( shadow-cfa -- zx-addr // negative )
  dart:cfa>pfa shword:zx-begin ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; shadow words support
;; see "tcom-20-creatori.f" for shadow word PFA format (`shword` struct).

: (z-find-not-found-error)  ( addr count )
  " cannot find ZX word \'" pad$:!
  pad$:+ " \'!" pad$:+
  pad$:@ error ;

: (z-find-forward)  ( addr count in-sys? -- shadow-cfa )
  ?< 2dup vocid: system-shadows find-in-vocid ?< true
     || 2dup vocid: forth-shadows find-in-vocid >?
  || 2dup vocid: forth-shadows find-in-vocid >?
  ( addr count shadow-cfa TRUE // addr count FALSE )
  not?exit< (z-find-not-found-error) >?
  nrot 2drop
  shadow-resolve-alias-scfa ;


: compile-zx-call-spfa-with-ofs-noreg  ( shadow-pfa ofs )
  >r
  dup shword:tk-flags tkf-primitive and ?exit<
    " cannot call primitive word \'" pad$:!
    shword:self-cfa dart:cfa>nfa pad$:+
    " \'!" pad$:+
    pad$:@ error >?
  ;; we need to restore TOS
  xasm:restore-tos-hl
  xasm:i-begin
  xasm:call-opc zx-c, ;; CALL
  fixup-call spfa->zx-addr
  ;; call offset
  r> + zx-w,
  xasm:i-end ;

;; compile machine code call
: compile-zx-call-scfa  ( shadow-cfa )
\ endcr ." compile-zx-call: $" dup .hex8 bl emit dup dart:cfa>nfa debug:.id cr
  dart:cfa>pfa
  turnkey-pass2? not?< dup record-ref-spfa >?
  0 compile-zx-call-spfa-with-ofs-noreg ;

*: zforth:  ( -- shadow-cfa ) \ name
  parse-name false (z-find-forward)
  [\\] {#,} ;

*: zforth-run:  \ name
  parse-name false (z-find-forward) \, ;

*: zforth-compile-call:  \ name
  system:?comp
  parse-name false (z-find-forward)
  [\\] {#,} \\ compile-zx-call-scfa ;

*: zsys:  ( -- shadow-cfa ) \ name
  parse-name true (z-find-forward)
  [\\] {#,} ;

*: zsys-run:  \ name
  parse-name true (z-find-forward) \, ;

*: zsys-compile-call:  \ name
  system:?comp
  parse-name true (z-find-forward)
  [\\] {#,} \\ compile-zx-call-scfa ;

*: zsys-execute-primitive-codegen:  \ name
  system:?comp
  parse-name true (z-find-forward)
  dart:cfa>pfa [\\] {#,} [\\] shword:ir-compile
  \\ execute ;

;; doers are used to check word kind
: ss-forth-doer     ( pfa )  system:?exec zx-?comp ss-call, ;
: ss-code-doer      ( pfa )  system:?exec zx-?comp ss-call, ;
: ss-variable-doer  ( pfa )
  zx-comp? ?exit< system:?exec
    ['] ir:ir-specials:(ir-walit) ir:append-special
    ir:tail ir:node:spfa-ref:!
  >?
  ir:cgen-flush
  shword:zx-begin
  << -1 of?v| error" cannot use undefined variable" |?
     -2 of?v| error" cannot use unused variable" |?
     -666 of?v| error" variable is a primitive? wtf?!" |?
  else| >>
  dup -?error" variable is not a variable!"
  [\\] {#,} ;
: ss-does-doer      ( pfa )
  error" DOES> is not here yet"
  system:?exec zx-?comp ss-call, ;
: ss-alias-doer     ( pfa )
\ endcr ." ALIAS-DOER: " dup shword:self-cfa dart:cfa>nfa debug:.id cr
  system:?exec zx-?comp
  shword:self-cfa shadow-resolve-alias-scfa
  execute-tail ;
  \ dart:cfa>pfa ss-call, ;


;; for shadow constant code
vect zx-lit,

;; compile constant value as numeric literal
;; (it is faster to execute this way)
: ss-constant-doer ( pfa )
\ endcr ." ZX CONST '" dup shword:self-cfa dart:cfa>nfa debug:.id ." ' is " dup shword:const-value 0.r cr
  zx-comp? ?exit< system:?exec shword:const-value zx-lit, >?
  ir:cgen-flush
  shword:const-value [\\] {#,}
;

|: (ss-quan/vect-ir-special)  ( spfa ir-cfa flag )
  >r ir:append-special
  ir:tail ir:node:spfa-ref:!
  r> ir:tail-set-flag ;

|: (ss-quan-doer-exec)  ( pfa )
  \ zx-latest-cfa zx-w@ [\\] {#,} ;
  shword:zx-begin
  << -1 of?v| error" cannot use undefined quan" |?
     -2 of?v| error" cannot use unused quan" |?
     -666 of?v| error" quan is a primitive? wtf?!" |?
  else| >>
  dup -?error" quan is not a quan!"
  zx-w@
  [\\] {#,} ;

: ss-quan-doer ( pfa )
  zx-comp? ?exit< system:?exec
    ['] ir:ir-specials:(ir-walit:@) ir:nflag-quan (ss-quan/vect-ir-special)
  >?
  ir:cgen-flush
  (ss-quan-doer-exec) ;

: ss-cquan-doer ( pfa )
  zx-comp? ?exit< system:?exec
    ['] ir:ir-specials:(ir-walit:c@) ir:nflag-quan (ss-quan/vect-ir-special)
  >?
  ir:cgen-flush
  (ss-quan-doer-exec) ;

;; all vectors has "JP" opcode as the -1 byte
: ss-vect-doer ( pfa )
  system:?exec zx-?comp
  \ ['] ir:ir-specials:(ir-walit:@execute) ir:nflag-vect (ss-quan/vect-ir-special) ;
  ['] ir:ir-specials:(ir-walit:exec-vect) ir:nflag-vect (ss-quan/vect-ir-special) ;


module zx-quan-mth
<disable-hash>
end-module


: zx-checker:  ( shadow-cfa )  \ name
  <builds ,
 does> ( scfa mypfa )
  over system:does? not?exit< 2drop false >?
  @ swap system:doer@ = ;

['] ss-forth-doer zx-checker: zx-forth?
['] ss-code-doer zx-checker: zx-code?
['] ss-constant-doer zx-checker: zx-constant?
['] ss-quan-doer zx-checker: zx-quan?
['] ss-cquan-doer zx-checker: zx-cquan?
['] ss-vect-doer zx-checker: zx-vect?
['] ss-variable-doer zx-checker: zx-variable?
['] ss-does-doer zx-checker: zx-does?
['] ss-alias-doer zx-checker: zx-alias?

: zx-forward?  ( shadow-cfa -- flag )
  dup system:does? not?exit< drop false >?
  \ FIXME: better checks!
  dart:cfa>pfa shword:zx-begin 0< ;


*: zx-const:  ( -- value ) \ name
  parse-name false (z-find-forward)
  dup zx-constant? not?error" not a constant!"
  dart:cfa>pfa shword:const-value
  [\\] {#,} ;


\ hack!
false quan mk-shadow-as-primitive?

|: (set-prim-flags)  ( spfa )
  mk-shadow-as-primitive? not?exit< drop >?
  tkf-no-tco tkf-primitive or  swap shword:tk-flags:^ or!
  mk-shadow-as-primitive?:!f ;

;; define undefined forward value
|: ss-define-forward  ( zx-addr shadow-cfa )
  over hi-word ?error" wut?!"  -- just in case
  dup dart:cfa>pfa shword:zx-begin +0?<
    " duplicate definition of forward \'" string:>pad
    dart:cfa>nfa idcount string:pad+cc
    " \'!" string:pad+cc
    string:pad-cc@ error >?
\ endcr ." *** FIX FORWARD \'" dup dart:cfa>nfa debug:.id ." \'\n"
  dart:cfa>pfa
  2dup shword:zx-begin:!
  dup >r
  shword:fwdfix-chain fix-chain
  r> shword:fwdfix-chain:!0 ;

|: check-existing-shadow  ( zx-addr addr count -- zx-addr addr count FALSE // TRUE )
  2dup zx-shadow-current find-in-vocid not?exit&leave
  dup dart:cfa>pfa shword:zx-begin +0?< drop
    " duplicate definition of forward \'" string:>pad
    string:pad+cc " \'!" string:pad+cc
    string:pad-cc@ error >?
  nrot 2drop  ;; drop addr and count
  dup latest-shadow-cfa:!
  dup dart:cfa>pfa (set-prim-flags)
  over +0?< ss-define-forward || 2drop >?
  true ;

: has-forward?  ( addr count -- spfa TRUE // FALSE )
  2dup zx-shadow-current find-in-vocid not?exit< 2drop false >?
  dart:cfa>pfa dup shword:zx-begin +0?< drop
    " duplicate definition of forward \'" string:>pad
    string:pad+cc " \'!" string:pad+cc
    string:pad-cc@ error >?
  nrot 2drop true ;

: (mk-shadow-header)  ( zx-addr addr count tc-doer )
  >r check-existing-shadow ?exit<
    ;; fix doer for shadows
    latest-shadow-cfa dart:cfa>pfa shword:zx-begin +0?<
      latest-shadow-cfa r@ system:!doer >?
    rdrop >?
  zx-stats-words:1+!
  mk-shadow-as-primitive? ?< zx-stats-prims:1+! >?
  ( zx-addr addr count | tc-doer )
  r> zx-shadow-current (mk-shadow-word)
    ( zx-addr latest-cfa )
  dup latest-shadow-cfa:!
  ( zx-addr) dup >r dart:cfa>pfa shword:zx-begin:!
    ( | latest-cfa )
  ( prev-scfa) latest-defined-shadow-cfa r@ dart:cfa>pfa shword:prev-scfa:!
  r@ latest-defined-shadow-cfa:!
  latest-shadow-pfa (set-prim-flags)
  r> fix-used-word-cfa ;

;; set `zx-tk-curr-word-scfa`
: mk-shadow-header  ( addr count tc-doer )
  >r zx-here nrot r> (mk-shadow-header)
  latest-shadow-cfa zx-tk-curr-word-scfa:!
  ir:reset ;


;; create forward reference to Forth word
: ss-mk-forth-forward  ( addr count -- shadow-cfa )
  -1 nrot ['] ss-forth-doer (mk-shadow-header)
  latest-shadow-cfa ;


0 quan (-zx-last-find-scfa)

: (zx-process-"sys:"-prefix)  ( addr count -- addr count vocid TRUE // addr count FALSE )
  dup 4 > not?exit&leave
  over 3 + c@ [char] : = not?exit&leave
  2dup " SYS:" string:starts-with-ci not?exit&leave
  4 string:/string vocid: system-shadows true ;

: (zx-process-"forth:"-prefix)  ( addr count -- addr count vocid TRUE // addr count FALSE )
  dup 4 > not?exit&leave
  over 3 + c@ [char] : = not?exit&leave
  2dup " FTH:" string:starts-with-ci not?exit&leave
  4 string:/string vocid: forth-shadows true ;

: (zx-process-prefix)  ( addr count -- addr count vocid )
  (zx-process-"sys:"-prefix) ?exit
  (zx-process-"forth:"-prefix) ?exit
  zx-shadow-context ;

: (zx-find-ss-cfa-$-no-forward)  ( addr count -- shadow-cfa TRUE // FALSE )
  (zx-process-prefix)
  >r 2dup r> find-in-vocid ?< nrot 2drop true
                           || vocid: forth-shadows find-in-vocid >?
  dup ?< drop shadow-resolve-alias-scfa true >? ;

;; automatically creates Forth forward if necessary
: (zx-find-ss-cfa-$)  ( addr count -- shadow-cfa )
  2dup (zx-find-ss-cfa-$-no-forward) ?exit< nrot 2drop >?
  ss-mk-forth-forward ;

: (-zx-find-ss-cfa)  ( -- shadow-cfa )
  parse-name (zx-find-ss-cfa-$)
  dup (-zx-last-find-scfa):! ;

;; FIXME: this is wrong -- doesn't allow forwards
: (-zx-find-ss)  ( -- shadow-cfa zx-addr )
  (-zx-find-ss-cfa) dup ss-cfa-zx-addr@ ;

;; FIXME: this is wrong -- doesn't allow forwards
: (-zx-find)  ( -- zx-addr )
  (-zx-find-ss) nip ;


;; module `zx-const` should be already declared. this is used to search for ZX constants.
;; i.e. this is used to get constant values.

|: (voc-good-const-like?)  ( shadow-cfa -- bool )
  dup zx-constant? ?exit< drop true >?
  zx-exec? not?exit< drop false >?
  dup zx-quan? ?exit< drop true >?
  dup zx-variable? ?exit< drop true >?
  drop false ;

|: (voc-zx-const-finder)  ( addr count skip-hidden? vocid -- cfa TRUE // FALSE )
  2drop (zx-find-ss-cfa-$-no-forward) not?exit&leave
  \ dup zx-constant? over zx-quan? or not?exit< drop false >?
  \ true ;
  dup (voc-good-const-like?) not?exit< drop false >?
  true ;
['] (voc-zx-const-finder) vocid: zx-consts system:vocid-find-cfa!

|: (voc-zx-const-execcomp)  ( cfa -- ... TRUE // cfa FALSE )
  \ dup zx-constant? over zx-quan? or not?error" wut?! (not a ZX constant)"
\ \ endcr dup dart:cfa>nfa debug:.id cr
  \ execute true ;
  dup zx-constant? ?exit< execute true >?
  zx-?exec
  dup zx-quan? ?exit< execute true >?
  dup zx-variable? ?exit< execute true >?
  error" wut?! (not a ZX constant)" ;
['] (voc-zx-const-execcomp) vocid: zx-consts system:vocid-execcomp-cfa!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX word accessor creation

;; created word: ( -- spfa // FALSE )
: opt-mk-zx-waddr  \ name zx-word
  <builds
    ( spfa) 0 ,
    ;; name
    parse-name dup 4+ n-allot ( addr count dest )
    2dup ! 4+
    swap cmove
  does> ( pfa -- scfa TRUE // FALSE )
    dup @ not?<
      dup 4+ count
        \ endcr ." <" 2dup type ." >\n"
      (zx-find-ss-cfa-$-no-forward) not?exit< drop false >?
        \ endcr ."  FOUND!\n"
      ( pfa scfa )
      dart:cfa>pfa over !  ;; save scfa
    >?
    @ ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FP doers

opt-mk-zx-waddr (ss-fp-"(FP-OP)")       SYS:(FP-OP)
opt-mk-zx-waddr (ss-fp-"(FP-OP-XMEM)")  SYS:(FP-OP-XMEM)

: ss-fp-doer ( pfa )
  system:?exec zx-?comp
  (*
  dup ir-append-spfa
  shword:calc-opcode ir:tail ir:node:value:!
  ;; mark (FP-OP) as used
  (ss-fp-"(FP-OP)") ir:tail ir:node:spfa-ref:! ;
  *)
  ir:tail dup ?< ir:node:spfa ir:ir-fp-end? >?
  ?<
    ir:tail dup ir:remove ir:free-node
  ||
    ['] ir:ir-specials:(ir-fp-start) ir:append-special
  >?
  ['] ir:ir-specials:(ir-fp-opcode) ir:append-special
  shword:calc-opcode ir:tail ir:node:value:!
  ['] ir:ir-specials:(ir-fp-end) ir:append-special ;

: ss-fp-xmem-doer ( pfa )
  dup ir-append-spfa
  shword:calc-opcode ir:tail ir:node:value:!
  ;; mark (FP-OP-XMEM) as used
  (ss-fp-"(FP-OP-XMEM)") ir:tail ir:node:spfa-ref:! ;

['] ss-fp-doer zx-checker: zx-fp?
['] ss-fp-xmem-doer zx-checker: zx-fp-xmem?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; turnkey support

0 quan zx-tk-curr-colon-scfa  ;; current colon word, because we might create forwards
0 quan zx-tk-rewind-addr
0 quan zx-unused-words


|: (zx-force-fix-asm-labels)  ( scfa zx-addr )
  over dart:cfa>pfa shword:def-labels not?exit< 2drop >?
  false ?< endcr ." DBG: asm-fix '" over dart:cfa>nfa debug:.id ." '...\n" >?
  swap dart:cfa>pfa shword:def-labels <<  ( zx-addr lbl-ref^ )
    dup ?^|
      false ?< endcr ."  lbl: " dup lblrec:name$ count type cr >?
      2dup lblrec:name$ count z80-labman:force-set
    lblrec:next |?
  else| 2drop >> ;


;; WARNING! do not clear "zx-tk-curr-word-scfa" here, it is used in "zx-required:" and such!
;; note that this word rewinds everything on turnkey pass 1, leaving only 1-2 bytes of
;; useless trash. this is for `zx-find-scfa-by-addr` to work. but otherwise we don't need
;; any generated code, and rewinding allows us to compile programs which wouldn't fuly fit
;; in ZX RAM. pass 2 will throw away most of the unused code.
: zx-tk-rewind  ( -- rewound-flag )
  zx-tk-rewind-addr 0?error" TCOM internal error: no rewind address"
  zx-tk-curr-word-scfa 0?error" TCOM internal error: no shadow colon CFA"
  zx-here curr-word-spfa shword:zx-end:!
  ;; don't bother with primitives
  curr-word-spfa shword:tk-flags tkf-primitive mask? ?exit&leave
  (*
  turnkey-pass1? ?<
    endcr ."  ZX: $" curr-word-spfa shword:zx-begin .hex4
    ."  - $" curr-word-spfa shword:zx-end .hex4
    ."  is '" curr-word-snfa debug:.id
    ." '\n" >?
  *)
  turnkey-pass1? ?exit<
    ;; rewind on pass 1
    ;; leave CFA and 2 bytes of data. it is possible to leave less,
    ;; the size is arbitrary. i believe than ~5k words are more than enough, tho.
    ;; do not crop vectors, we need their full contents for tracing.
    ;; TODO: fix asm labels: instead of wiping, change their addresses.
    ;;       that is, all labels declared in the code word should be forced
    ;;       to point on that code word. otherwise the tracer might miss the word.
    zx-here zx-tk-rewind-addr - 2 > ?<
      OPT-TURNKEY-DEBUG? ?< endcr ." ZX-REWIND: " curr-word-snfa debug:.id cr >?
        \ endcr ."   REWIND from " zx-here zx-tk-rewind-addr - . ." bytes -- " curr-word-snfa debug:.id cr
      zx-tk-rewind-addr 2 + zx-here z80-labman:wipe-range ;; wipe fixups
      zx-tk-curr-word-scfa zx-tk-rewind-addr (zx-force-fix-asm-labels)
      ;; rewind
      zx-tk-rewind-addr 2 + zx-rewind-dp!
      zx-here curr-word-spfa shword:zx-end:!
    ||
      OPT-TURNKEY-DEBUG? ?< endcr ." ZX-REWIND-SKIP: " curr-word-snfa debug:.id cr >?
    >?
    zx-tk-rewind-addr:!0 false
  >?
  curr-word-scfa tk-zx-word-used? not?<
    OPT-TURNKEY-DEBUG? ?< endcr ." ZX-UNUSED: " curr-word-snfa debug:.id cr >?
    zx-tk-rewind-addr zx-here z80-labman:wipe-range ;; wipe fixups
    zx-tk-rewind-addr zx-rewind-dp!
    zx-unused-words:1+!
    curr-word-spfa -2 swap shword:zx-begin:!
    true
  || OPT-TURNKEY-DEBUG? ?<
       endcr ." ZX-USED: LFA=$" zx-tk-rewind-addr .hex4
       ."  CFA=$" curr-word-spfa shword:zx-begin .hex4
       bl emit curr-word-snfa debug:.id
       cr >?
     false >?
  zx-tk-rewind-addr:!0 ;


: zx-tk-rewind-var-buf  zx-tk-rewind drop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; find shadow word by zx CFA

: zx-find-scfa-by-addr  ( zx-addr -- scfa TRUE // FALSE )
  dup 0 65535 bounds not?exit< drop false >?
  >r latest-defined-shadow-cfa << dup ?^|
    r@ over dart:cfa>pfa dup shword:zx-begin swap shword:zx-end
    over 0>= over 0>= and ?<
      within ?exit<
        [ OPT-TURNKEY-DEBUG? ] [IF]
          endcr ." ZX-ADDR $" r@ .hex4 ."  is " dup dart:cfa>nfa debug:.id cr
        [ENDIF]
        rdrop true >?
    || 3drop >?
  dart:cfa>pfa shword:prev-scfa |? else| >>
  rdrop ;


end-module
