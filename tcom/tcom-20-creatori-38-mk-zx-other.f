;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create other ZX words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create constants, vars, etc.

;; 0 or 1
0 quan (zx-last-create-kept)

|: (zx-start-create)
  system:?exec zx-?exec
  ir:cgen-flush
  zx-tick-register-ref ?error" missing \'create;\'"
  zx-here zx-tk-rewind-addr:! ;

|: (zx-end-create)
  system:?exec zx-?exec
  zx-tick-register-ref:!f
  zx-tk-rewind-addr
  \ zx-tk-rewind-var-buf
  zx-tk-rewind 0= abs (zx-last-create-kept):!
  ;; statistics
  zx-here swap - zx-stats-data-bytes:+!
  zx-fix-org ;


*: zx-fp:  ( cmd )  \ name
  parse-name
  ['] ss-fp-doer mk-shadow-header
  latest-shadow-pfa shword:calc-opcode:! ;

*: zx-fp-xmem:  ( cmd )  \ name
  parse-name
  ['] ss-fp-xmem-doer mk-shadow-header
  latest-shadow-pfa shword:calc-opcode:! ;


: (zx-mk-constant)  ( value addr count )
  >r over r> swap -32768 65536 within not?exit<
    " invalid value (" pad$:! pad$:#s " ) for ZX constant '" pad$:+
    pad$:+ " '" pad$:+  pad$:@ error >?
  (zx-start-create)
  turnkey-pass2? ?<
    2dup vocid: (zx-used-words) find-in-vocid not?exit<
      OPT-TURNKEY-DEBUG? ?< endcr ." SKIP-CONST-WORD: " 2dup type cr >?
      ir:cgen-flush
      ['] ss-constant-doer mk-shadow-header
      ( const-value) ( lo-word) latest-shadow-pfa shword:const-value:!
      -2 latest-shadow-pfa shword:zx-begin:!  ;; no body
    >? drop
    OPT-TURNKEY-DEBUG? ?< endcr ." ***CONST-WORD: " 2dup type cr >?
  >?
  ir:cgen-flush
  ;; create normal ZX word
  ['] ss-constant-doer mk-shadow-header
  ( const-value -- to shadow) dup ( lo-word) latest-shadow-pfa shword:const-value:!
  zx-here latest-shadow-pfa shword:zx-begin:!
  ( value) zx-w,
  (zx-end-create) ;

: zx-mk-constant  ( value addr count )
  (zx-mk-constant)
  (zx-last-create-kept) zx-stats-const:+! ;

*: zx-constant  ( value )  \ name
  parse-name
  zx-mk-constant ;

*: zx-label  ( value )  \ name
  system:?exec
  parse-name z80-labman:define ;

*: zx-constant-and-label  ( value )  \ const-name label-name
  dup [\\] zx-constant [\\] zx-label ;


|: ?zx-no-fixups  ( addr count )
  2dup has-forward? not?exit< 2drop >?
  ;; error message
  " forward references to \'" pad$:! pad$:+
  " \' are not allowed yet." pad$:+
  pad$:@ error ;


;; if we have a forward, we need to create a dummy word for fixups
|: zx-create-dummy-fixup-word  ( addr count )
  2dup has-forward? not?exit< 2drop >?
  ;; warning message
  nrot endcr ." WARNING: forward access to \'" type ." \' detected!\n"
  ."          try to avoid this situation if you can.\n"
  ."          creating hidden forward thunk now.\n"
  ;; create dummy word
  zx-here
  ( spfa zx-here )
  over shword:zx-begin >r
  2dup swap shword:zx-begin:!
  xasm:pop-ix
  xasm:push-hl
  dup 8 + xasm:#->hl  ;; the thunk is 8 bytes
  xasm:jp-ix
  ( spfa zx-addr )
  ;; now process fixups
  over shword:fwdfix-chain fix-chain
  dup shword:fwdfix-chain:!0
  r> swap shword:zx-begin:!
  zx-here zx-tk-rewind-addr:! ;


|: (-zx-create)  \ name
  (zx-start-create)
  parse-name
  2dup zx-create-dummy-fixup-word
  ['] ss-variable-doer mk-shadow-header
  latest-shadow-cfa zx-tk-curr-word-scfa:!
  zx-here latest-shadow-pfa shword:zx-begin:!
    \ endcr ." CREATE: \'" latest-shadow-cfa dart:cfa>nfa debug:.id ." \' is $" zx-here .hex4 cr
  zx-fix-org
  zx-tick-register-ref:!t ;

*: zx-create  \ name
  (-zx-create) ;

*: zx-create;
  (zx-end-create) ;


|: (mk-quan)  ( value addr count byte? )
  >r 2dup ?zx-no-fixups
  (zx-start-create)
  r@ ?< ['] ss-cquan-doer || ['] ss-quan-doer >? mk-shadow-header
  vocid: zx-quan-mth latest-shadow-cfa dart:cfa>vocid !
  latest-shadow-cfa zx-tk-curr-word-scfa:!
  zx-here latest-shadow-pfa shword:zx-begin:!
  ( value) r> ?< zx-c, || zx-w, >?
  (zx-end-create)
  (zx-last-create-kept) zx-stats-quan:+! ;

*: zx-quan  ( value )  \ name
  parse-name false (mk-quan) ;

;; this usually makes the code bigger and slower, lol
*: zx-cquan  ( value )  \ name
  parse-name true (mk-quan) ;


;; if we have a forward, we need to create a dummy word for fixups
|: zx-vect-dummy-fixup-word  ( addr count )
  has-forward? not?exit<
    ;; still create "jp" instruction
    xasm:jp-opc zx-c,
    zx-here zx-tk-rewind-addr:!
  >?
  ;; create "jp" instruction
  zx-here
  xasm:jp-opc zx-c,
  ( spfa zx-addr )
  ;; now process fixups
  over shword:fwdfix-chain fix-chain
  dup shword:fwdfix-chain:!0
  r> swap shword:zx-begin:!
  zx-here zx-tk-rewind-addr:! ;


*: zx-vect  ( value )  \ name
  (zx-start-create)
  parse-name
  2dup zx-vect-dummy-fixup-word
  ['] ss-vect-doer mk-shadow-header
  vocid: zx-quan-mth latest-shadow-cfa dart:cfa>vocid !
  latest-shadow-cfa zx-tk-curr-word-scfa:!
  zx-here latest-shadow-pfa shword:zx-begin:!
  ( value) zx-w,
  (zx-end-create)
  (zx-last-create-kept) zx-stats-vect:+! ;

*: zx-variable  ( value )  \ name
  (-zx-create) zx-tick-register-ref:!f
  ( value) zx-w,
  (zx-end-create)
  [ 0 ] [IF]
    endcr ." VAR: " latest-shadow-cfa dart:cfa>nfa debug:.id
    (zx-last-create-kept) not?< ."  (dropped)" >?
    cr
  [ENDIF]
  (zx-last-create-kept) zx-stats-var:+! ;

*: zx-ud-buffer  ( size )  \ name
  (-zx-create)
  zx-allot
  (zx-end-create) ;

*: zx-2variable  ( value )  \ name
  (-zx-create) zx-tick-register-ref:!f
  ( value-hi) dup hi-word zx-w,
  ( value-lo) lo-word zx-w,
  (zx-end-create)
  (zx-last-create-kept) zx-stats-var:+! ;


*: zx-has-word?  ( -- bool )  \ name
  parse-name
\ endcr 2dup type cr
  (zx-find-ss-cfa-$-no-forward) dup ?< nip >? ;

*: zx-used-word?  ( -- bool )  \ name
  turnkey? not turnkey-pass1? lor ?exit< [\\] zx-has-word? >?
  parse-name
\ endcr 2dup type cr
  (zx-find-ss-cfa-$-no-forward) not?exit&leave
  dart:cfa>pfa shword:tk-flags tkf-used mask? ;

: zx-register-spfa  ( scfa )
  zx-compile-mode zxc-none <> zx-tick-register-ref or not?exit< drop >?
  OPT-TURNKEY-DEBUG? ?< endcr ." register: " dup shword:self-cfa dart:cfa>nfa debug:.id cr >?
  record-ref-spfa ;

: zx-register-scfa  ( scfa )
  dart:cfa>pfa zx-register-spfa ;

;; used for labels
: zx-register-addr  ( zx-addr )
  zx-compile-mode zxc-none <> zx-tick-register-ref or not?exit< drop >?
  zx-find-scfa-by-addr not?exit
  zx-register-scfa ;


|: (zx-register-last-find)
  turnkey-pass1? not?exit
  zx-compile-mode zxc-none = not?exit<
    OPT-TURNKEY-DEBUG? ?< endcr ." register: " (-zx-last-find-scfa) dart:cfa>nfa debug:.id cr >?
    (-zx-last-find-scfa) dart:cfa>pfa record-ref-spfa
  >?
  zx-tick-register-ref not?exit
  (-zx-last-find-scfa) dart:cfa>pfa record-ref-spfa ;

|: (-zx-[']-find)  ( -- zx-cfa )  \ name
  zx-compile-mode zxc-none = ?< ir:cgen-flush >?
  turnkey-pass2? not?exit< (-zx-find) (zx-register-last-find)  >?
  parse-name
  2dup (zx-find-ss-cfa-$-no-forward) not?exit<
    " zx-[']: '" pad$:! pad$:+ " ' not found" pad$:+ pad$:@ error >?
  nrot 2drop
  dup (-zx-last-find-scfa):!
  ss-cfa-zx-addr@-tk2 dup -?< drop $4000 >?
  (zx-register-last-find) ;

*: zx-[']  ( -- zx-cfa )  \ name
  (-zx-[']-find) [\\] {#,} ;

*: zx-['pfa]  ( -- zx-cfa )  \ name
  [\\] zx-['] ;


;; this is used to force-inline the word.
;; see below: `inline: name` in zx code.
: -zx-inline  \ name
  system:?exec zx-?comp
  zxc-colon zx-compile-mode = not?error" inline is out of colon definition"
  parse-name 2dup (zx-find-ss-cfa-$-no-forward) not?exit<
    " cannot inline unknown word \'" pad$:! pad$:+
    " \'!" pad$:+ pad$:@ error >?
  nrot 2drop
  ( scfa )
  dup zx-forth? not?exit< execute-tail >?
  \ dup dart:cfa>pfa shword:zx-begin -1 = ?< execute-tail >?
  dup dart:cfa>pfa shword:ir-code-clone 0?exit< execute-tail >?
  ;; ok, we can inline it
  [ 0 ] [IF]
    endcr ." REGISTER-FORCE-INLINE: " dup dart:cfa>nfa debug:.id cr
  [ENDIF]
  execute
  ir:nflag-do-inline ir:tail ir:node-set-flag ;


|: (zx-exec-in-system)  ( cfa )
  zx-shadow-current >r zx-shadow-context >r
  <zx-system> execute
  r> zx-shadow-context:! r> zx-shadow-current:! ;


0 quan (zals-scfa)

|: (zx-alias-for-tk-pass2)
  (-zx-find-ss-cfa)
  ( orig-scfa )
  dup dart:cfa>pfa shword:zx-begin
  ( orig-scfa orig-zx-cfa )
  parse-name 2 = swap w@ $20_20 or $73_69 = and not?error" `IS` expected"
  ;; note that we need to create the alias even for unused words.
  ;; this is because the optimiser might need them for optimisation. ;-)
  ;; do not create ZX alias word, we need only shadow one, for routing.
  ( orig-scfa orig-zx-cfa ) swap (zals-scfa):!
  ( orig-zx-cfa )
  ;; create shadow word
  (* -- no, this doesn't work
  dup >r parse-name
  ;; skip aliases to unused words
  r> -?exit< 3drop >?
  *)
  parse-name
  OPT-TURNKEY-DEBUG? ?< endcr ." ALIAS-NEW: " (zals-scfa) dart:cfa>nfa debug:.id
                        ."  <- " 2dup type ."  -- ZX:$" 2>r dup .hex4 2r>  cr >?
  ( orig-zx-cfa addr count ) rot drop
  ['] ss-alias-doer mk-shadow-header
  -2 latest-shadow-pfa shword:zx-begin:!  ;; no body
  ;; set routing address
  (zals-scfa) latest-shadow-pfa shword:zx-alias-scfa:! ;

;; WARNING! doesn't copy "immediate" bit!
*: zx-alias-for  \ oldname IS newname
  system:?exec zx-?exec
  ir:cgen-flush
  turnkey-pass2? ?exit< (zx-alias-for-tk-pass2) >?
  (-zx-find-ss-cfa)
  dup (zals-scfa):!
  dup zx-alias? ?error" cannot create alias to alias yet (FIXME)"
  ( orig-scfa )
  parse-name 2 = swap w@ $20_20 or $73_69 = and not?error" `IS` expected"
  parse-name
  [ 0 ] [IF]
    endcr ." NEW ZX ALIAS FOR \'" (zals-scfa) dart:cfa>nfa debug:.id ." \'"
    (zals-scfa) zx-code? ?< ."  [CODE]" || ."  [FORTH]" >?
    ."  is \'" 2dup type ." \'\n"
  [ENDIF]
  zx-here zx-tk-rewind-addr:!
  ['] ss-alias-doer mk-shadow-header
  -2 latest-shadow-pfa shword:zx-begin:!  ;; no body
  ;; fix alias field
  latest-shadow-pfa shword:zx-alias-scfa:!
  zx-stats-alias:1+! ;


vect-empty ref-mark-trace

;; mark last defined word as "always used"
*: zx-mark-as-used
  curr-word-scfa ref-mark-trace ;

;; note that the last defined word requires other words
*: zx-required:  \ word*
  << opt-name-parse:parse-optional-name ?^|
      (zx-find-ss-cfa-$) dart:cfa>pfa record-ref-spfa |?
  else| >> ;

*: zx-no-tco-for-this
  tkf-no-tco  curr-word-spfa shword:tk-flags:^ or! ;


extend-module SHADOW-HELPERS
*: inline:
  -zx-inline ;
end-module

end-module
