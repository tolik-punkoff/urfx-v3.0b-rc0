;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; "<zx-definitions>" and "<zx-done>" support
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

false quan zx-qv-skip?

extend-module ZX-DEFS

*: sys:  \ name
  parse-name 2dup 2>r
  vocid: system-shadows find-in-vocid not?<
    " unknown ZX word \'" string:>pad 2r> string:pad+cc
    " \'" string:pad+cc  string:pad-cc@ error >?
  2rdrop execute ;

*: asm-label:  ( -- value )  \ name
  parse-name z80-labman:@get
  dup zx-register-addr
  zx-comp? ?< zx-#, >? ;

*: allot  ( size )
  zx-allot0 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; quan/vect mechanics

|: (-zx-qaddr-scfa)  ( -- shadow-cfa )  \ name
  parse-name  \ endcr ." :: " 2dup type cr
  2dup (zx-find-ss-cfa-$-no-forward) not?exit<
    " quan/vect \'" pad$:! pad$:+ " \' not found" pad$:+
    pad$:@ error >?
  dup (-zx-last-find-scfa):!
  dup dart:cfa>pfa shword:zx-begin
  dup -2 = ?exit< zx-qv-skip?:!t drop nrot 2drop >?
  -?exit< drop
    " quan/vect \'" pad$:! pad$:+ " \' is not defined yet" pad$:+
    pad$:@ error >?
  zx-qv-skip?:!f
  nrot 2drop ;

: (zx-quan-action-lit-ir-node)  ( shadow-cfa ir-special-cfa flag )
  >r ir:append-special
  dart:cfa>pfa ir:tail ir:node:spfa-ref:!
  r> ir:tail-set-flag ;
\ ['] (zx-quan-action-lit-ir-node) (zx-quan-action-lit-ir-node)-vect:!


: (q-qaddr-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop 0  zx-comp? ?< zx-#, >? >?
  zx-comp? ?exit<
    ['] ir:ir-specials:(ir-walit) ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2 ;

*: qaddr
  (-zx-qaddr-scfa) (q-qaddr-scfa) ;


|: byte-quan-scfa?  ( scfa -- bool )
  zx-cquan? ;

: (q0c-to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  zx-comp? ?exit< ['] ir:ir-specials:(ir-walit:c!) ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2 zx-c! ;

: (q1c-to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  dup byte-quan-scfa? ?error" invalid byte quan operaion"
  zx-comp? ?exit< ['] ir:ir-specials:(ir-walit:1c!) ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2 1+ zx-c! ;

: (q-to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  dup byte-quan-scfa? >r
  zx-comp? ?exit<
    r> ?< ['] ir:ir-specials:(ir-walit:c!)
       || ['] ir:ir-specials:(ir-walit:!) >?
    ir:nflag-quan (zx-quan-action-lit-ir-node)
  >?
  ss-cfa-zx-addr@-tk2 r> ?< zx-c! || zx-w! >? ;

*: to
  (-zx-qaddr-scfa) (q-to-scfa) ;


: (q-+to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  dup byte-quan-scfa? >r
  zx-comp? ?exit<
    r> ?< ['] ir:ir-specials:(ir-walit:+c!)
       || ['] ir:ir-specials:(ir-walit:+!) >?
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2
  r> ?< dup zx-c@ rot + swap zx-c!
     || dup zx-w@ rot + swap zx-w! >? ;

*: +to
  (-zx-qaddr-scfa) (q-+to-scfa) ;

: (q--to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  dup byte-quan-scfa? >r
  zx-comp? ?exit<
    r> ?< ['] ir:ir-specials:(ir-walit:-c!)
       || ['] ir:ir-specials:(ir-walit:-!) >?
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2
  r> ?< dup zx-c@ rot - swap zx-c!
     || dup zx-w@ rot - swap zx-w! >? ;

*: -to
  (-zx-qaddr-scfa) (q--to-scfa) ;


: (q-c+to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  zx-comp? ?exit<
    ['] ir:ir-specials:(ir-walit:+c!)
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2
  dup zx-c@ rot + swap zx-c! ;

: (q-c-to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  zx-comp? ?exit<
    ['] ir:ir-specials:(ir-walit:-c!)
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2
  dup zx-c@ rot - swap zx-c! ;


: (q-0to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  dup byte-quan-scfa? >r
  zx-comp? ?exit<
    r> ?< ['] ir:ir-specials:(ir-walit:c!0)
       || ['] ir:ir-specials:(ir-walit:!0) >?
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2 0 swap r> ?< zx-c! || zx-w! >? ;

: (q-1to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  dup byte-quan-scfa? >r
  zx-comp? ?exit<
    r> ?< ['] ir:ir-specials:(ir-walit:c!1)
       || ['] ir:ir-specials:(ir-walit:!1) >?
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2 1 swap r> ?< zx-c! || zx-w! >? ;


: (q-1c+to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  zx-comp? ?exit<
    ['] ir:ir-specials:(ir-walit:1+c!)
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2
  dup zx-c@ 1+ swap zx-c! ;

: (q-1+to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  dup byte-quan-scfa? >r
  zx-comp? ?exit<
    r> ?< ['] ir:ir-specials:(ir-walit:1+c!)
       || ['] ir:ir-specials:(ir-walit:1+!) >?
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2
  r> ?< dup zx-c@ 1+ swap zx-c!
     || dup zx-w@ 1+ swap zx-w! >? ;


: (q-1c-to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  zx-comp? ?exit<
    ['] ir:ir-specials:(ir-walit:1-c!)
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2
  dup zx-c@ 1- swap zx-c! ;

: (q-1-to-scfa)  ( scfa )
  zx-qv-skip? ?exit< drop zx-comp? not?< drop >? >?
  dup byte-quan-scfa? >r
  zx-comp? ?exit<
    r> ?< ['] ir:ir-specials:(ir-walit:1-c!)
       || ['] ir:ir-specials:(ir-walit:1-!) >?
    ir:nflag-quan (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2
  r> ?< dup zx-c@ 1- swap zx-c!
     || dup zx-w@ 1- swap zx-w! >? ;


extend-module zx-quan-mth

|: zx-vect?  ( -- flag )
  system:?exec
  ['] ss-vect-doer system:vocobject-this? ;

|: zx-cquan?  ( -- bool )
  ['] ss-cquan-doer system:vocobject-this? ;

|: ?zx-quan-like  ( -- shadow-cfa )
  system:?exec
  ['] ss-quan-doer system:vocobject-this?
  ['] ss-cquan-doer system:vocobject-this?
  ['] ss-vect-doer system:vocobject-this?
  or or not?error" not a quan/vect"
  system:vocobject-this
  shword:self-cfa
  \ dup (-zx-last-find-scfa):!
  dup dart:cfa>pfa shword:zx-begin
  dup -2 = ?exit< zx-qv-skip?:!t drop >?
  -?exit< drop
    " quan/vect \'" pad$:! dart:cfa>nfa idcount pad$:+
    " \' is not defined yet" pad$:+
    pad$:@ error >?
  zx-qv-skip?:!f ;


*: @
  ?zx-quan-like zx-comp? ?exit<
    zx-cquan? ?< ['] ir:ir-specials:(ir-walit:c@)
              || ['] ir:ir-specials:(ir-walit:@) >?
    zx-vect? ?< ir:nflag-vect || ir:nflag-quan >?
    (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2 zx-cquan? ?< zx-c@ || zx-w@ >? ;

*: C@
  ?zx-quan-like zx-comp? ?exit<
    ['] ir:ir-specials:(ir-walit:c@)
    zx-vect? ?< ir:nflag-vect || ir:nflag-quan >?
    (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2 zx-w@ ;
*: 0C@  [\\] C@ ;

*: 1C@
  ?zx-quan-like
  zx-cquan? ?error" invalid byte-quan operation"
  zx-comp? ?exit<
    ['] ir:ir-specials:(ir-walit:1c@)
    zx-vect? ?< ir:nflag-vect || ir:nflag-quan >?
    (zx-quan-action-lit-ir-node) >?
  ss-cfa-zx-addr@-tk2 zx-w@ ;

*: C!   ?zx-quan-like (q0c-to-scfa) ;
*: 0C!  [\\] C! ;
*: 1C!  ?zx-quan-like (q1c-to-scfa) ;
*: !    ?zx-quan-like (q-to-scfa) ;
*: ^    ?zx-quan-like (q-qaddr-scfa) ;
*: !0   ?zx-quan-like (q-0to-scfa) ;
*: !1   ?zx-quan-like (q-1to-scfa) ;
*: !t   ?zx-quan-like (q-1to-scfa) ;
*: !f   ?zx-quan-like (q-0to-scfa) ;
*: +!   ?zx-quan-like (q-+to-scfa) ;
*: -!   ?zx-quan-like (q--to-scfa) ;
*: +c! ?zx-quan-like (q-c+to-scfa) ;
*: -c! ?zx-quan-like (q-c-to-scfa) ;
*: +!c ?zx-quan-like (q-c+to-scfa) ;
*: -!c ?zx-quan-like (q-c-to-scfa) ;
*: 1+!  ?zx-quan-like (q-1+to-scfa) ;
*: 1-!  ?zx-quan-like (q-1-to-scfa) ;
*: 1+c! ?zx-quan-like (q-1c+to-scfa) ;
*: 1-c! ?zx-quan-like (q-1c-to-scfa) ;

end-module zx-quan-mth

|: (['])  ( zx-shadow-vocid -- zx-cfa )  \ name
  system:?exec
  zx-shadow-context >r zx-shadow-context:!
  (-zx-find-ss-cfa)
  r> zx-shadow-context:!
  dup dart:cfa>pfa shword:tk-flags tkf-primitive and ?exit<
    " cannot take address of primitive \'" pad$:!
    dart:cfa>nfa idcount pad$:+ " \'" pad$:+
    pad$:@ error
  >?
  zx-comp? ?exit< zx-shadow-cfa-#, >?
  turnkey-pass2? not?exit<
    dup >r ss-cfa-zx-addr@
    zx-tick-register-ref turnkey-pass1? forth:land ?<
      r@ dart:cfa>pfa record-ref-spfa
    >?
    rdrop
  >?
  ss-cfa-zx-addr@-tk2 dup -?< drop $4000 >? ;

*: [']  ( -- zx-cfa )  \ name
  forth-shadows ([']) ;

*: ['sys]  ( -- zx-cfa )  \ name
  system-shadows ([']) ;


*: c,  ( byte )
  system:?exec zx-?exec zx-c, ;

*: ,  ( byte )
  system:?exec zx-?exec zx-w, ;

*: bswap,  ( byte )
  system:?exec zx-?exec wbswap zx-w, ;


*: ,"
  zx-?exec
  34 parse-qstr
  zx-bstr, ;


*: mk-hot-item  ( udata x y addr count )
  zx-?exec
  2swap  swap zx-c, zx-c, ;; x and y
  zx-bstr,
  zx-w, ;

*: mk-hot-area  ( udata x y w h )
  zx-?exec
  2swap  swap zx-c, zx-c, ;; x and y
  swap negate zx-c, zx-c, ;; width and height
  zx-w, ;

*: --hot-next-menu--  ( -- zx-addr )
  zx-?exec
  $80 zx-c,
  zx-here ;

*: ;hot-menu
  zx-?exec
  $80 zx-c,
  [\\] zx-create; ;


alias-for zx-constant is constant
alias-for zx-constant-and-label is constant-and-label
alias-for zx-label is label
alias-for zx-quan is quan
alias-for zx-cquan is cquan
alias-for zx-vect is vect
alias-for zx-variable is variable
alias-for zx-2variable is 2variable
alias-for zx-create is create
alias-for zx-create; is create;
alias-for zx-create; is ;create

alias-for zx-code: is code:
alias-for zx-code-raw: is raw-code:
alias-for zx-primitive: is primitive:

alias-for zx: is :
alias-for zx|: is |:
alias-for zx*: is *:

alias-for zx-here is here

alias-for zx-alias-for is alias-for
end-module


extend-module SHADOW-HELPERS
  alias-for zx-defs:sys: is sys:
  alias-for zx-defs:to is to
  alias-for zx-defs:+to is +to
  alias-for zx-defs:-to is -to
  alias-for zx-defs:qaddr is qaddr
  alias-for zx-defs:['] is [']
  alias-for zx-defs:['sys] is ['sys]
  alias-for zx-defs:asm-label: is asm-label:
end-module


end-module

;; publish it
alias-for tcom:<zx-definitions> is <zx-definitions>
