;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler: operand parsing
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; operand struct
0
new-field a>type  -- taken from operand; changed by finalizer
new-field a>size  -- memory/imm size override
new-field a>srm   -- value, taken from operand; fixed by finalizer
new-field a>imm?  -- should finalizer read immediate?
new-field a>imm   -- immediate value; filled in finalizer
new-field a>label -- label id for immediate value (0: no label)
constant arg-size

create args arg-size 3 * allot create;
args dup       constant arg0
arg-size + dup constant arg1
arg-size +     constant arg2
0 quan arg-addr

module ARG-ACC-SUPPORT
<disable-hash>
|: (aaddr)  system:comp? ?exit< \*\ arg-addr >? arg-addr ;
*: +  ( addr -- addr+ofs )  (aaddr) [\\] field-support:+ ;
*: @  ( addr -- [addr+ofs] )  (aaddr) [\\] field-support:@ ;
*: !  ( value addr )  ( [addr+ofs]=value )  (aaddr) [\\] field-support:! ;
*: !0 ( addr )  ( [addr+ofs]=0 )  (aaddr) [\\] field-support:!0 ;
*: !1 ( addr )  ( [addr+ofs]=0 )  (aaddr) [\\] field-support:!1 ;
*: !t ( addr )  ( [addr+ofs]=0 )  (aaddr) [\\] field-support:!t ;
end-module ARG-ACC-SUPPORT (private)

;; create accessor for the current operand
: (mk-arg-acc)  \ name
  -find-required dart:cfa>pfa
  <builds immediate @++ , @ ,
  vocid: arg-acc-support system:latest-vocid !
  does> error" no wai!" ;

(mk-arg-acc) a>type  aa>type
(mk-arg-acc) a>size  aa>size
(mk-arg-acc) a>srm   aa>srm
(mk-arg-acc) a>imm?  aa>imm?
(mk-arg-acc) a>imm   aa>imm
(mk-arg-acc) a>label aa>label

: >arg-th  ( idx )
  dup 0 3 within not?error" invalid arg index"
  arg-size * args + arg-addr:! ;


module apar
using iop-helpers

enum{
  def: r-slot -- reg/rm
  def: s-slot -- si
  def: ^-slot -- size
  def: #-slot -- imm (value is label id)
}

;; slots
0 quan slot-mask -- used slots (bitmask)
0 quan def-size  -- default operand size (taken from type size info)
-- slot type; we have 4 available slots (see above)
-- first dd is type, second dd is value
create slots 4 2* 4* allot create;
-- slot we're filling now
0 quan slot-addr

: reset  slot-mask:!0 def-size:!0 ;

: smask  ( slot-idx -- mask )  1 swap lshift ;
: used?  ( slot-idx -- flag-non-bool )  smask slot-mask and ;
: used!  ( slot-idx )  smask slot-mask or slot-mask:! ;
: ~used! ( slot-idx )  smask slot-mask swap ~and slot-mask:! ;
: >slot-nth  ( slot-idx )  2* slots dd-nth slot-addr:! ;

: type!  ( type )  slot-addr ! ;
: value! ( val )  slot-addr 4+ ! ;
: fill!  ( opval )  dup op>type type! op>value value! ;
: def-size!  ( opval )  op>size def-size max def-size:! ;

: r-type@  ( -- type )  slots @ ;
: r-value@ ( -- val )   [ 1 slots dd-nth ] {#,} @ ;
: s-type@  ( -- type )  [ 2 slots dd-nth ] {#,} @ ;
: s-value@ ( -- val )   [ 3 slots dd-nth ] {#,} @ ;
: ^-value@  ( -- val )  [ 5 slots dd-nth ] {#,} @ ;
: #-value@  ( -- val )  [ 7 slots dd-nth ] {#,} @ ;

: ?bad-oper  ( fail-flag )  ?error" invalid operand combination" ;

: classify  ( optype -- slot-idx )
  << imm of?v| #-slot |?
     size of?v| ^-slot |?
     dup reg8 rm32+ bounds ?of?v| r-slot |?
     dup si32 si32+ bounds ?of?v| s-slot |?
     else| error" invalid operand type (internal error)" >> ;

: put  ( opval )
  dup op>type classify dup used? ?bad-oper
  dup used! >slot-nth dup fill! def-size! ;


: defined?     aa>label:@ 0>= ;
: 0imm?        aa>imm:@ aa>label:@ or 0= ;
: remove-0imm  0imm? ?< #-slot ~used! aa>imm?:!0 >? ;
: force-imm    aa>imm?:@ not?< #-slot used! aa>imm?:!t aa>imm:!0 aa>label:!0 >? ;

: imm-mod  ( -- mod )
  #-slot used? ?< -- undefined labels assumed to be 4 bytes
    defined? ?< aa>imm:@ -128 128 within ?< 0o100 || 0o200 >? || 0o200 >?
  || 0o000 >? ;

: (rm/i)
  remove-0imm r-value@ dup 0o004 = ?< drop sib32 [ 0o004 0o044 256 * or ] {#,} ( [ESP] )
  || rm32 swap dup 0o005 = ?< force-imm ( [EBP] ) >? >?
  imm-mod or aa>srm:! aa>type:! ;

: (rm/si/i)
  r-value@ 0o005 = ?< force-imm || remove-0imm >? -- [EBP+] allows only displacement
  sib32 aa>type:! r-value@ 256 * s-value@ or 0o004 or imm-mod or aa>srm:! ;

;; combiners for "no immediate" case
: rm   s-slot used? ?bad-oper (rm/i) ;
: rm+  s-slot used? 0= s-type@ si32+ = or ?bad-oper (rm/si/i) ;
: reg  s-slot used? ?bad-oper r-type@ aa>type:! r-value@ aa>srm:! ;

: reg/rm
  r-slot used? 0= ?bad-oper aa>imm?:!0 aa>imm:!0 aa>label:!0
  r-type@ dup rm32 = ?exit< drop rm >?
  rm32+ = ?exit< rm+ >?  reg ;

;; combiners for "with immediate" case
: only-imm
  ^-slot used? ?< addr || imm def-size:!0 >? aa>type:! ;

: rm+/i  (rm/i) ;
: rm+/si+/i  s-type@ si32+ <> ?bad-oper (rm/si/i) ;

: rm+/si+?/i
  aa>imm?:!t #-value@ dup aa>label:! dup ?< emit:value@ || drop >? aa>imm:!
  r-slot used? ?exit< r-type@ rm32+ <> ?bad-oper s-slot used?
                      ?exit< rm+/si+/i >? rm+/i >?
  only-imm ;

: fix-size  ^-slot used? ?< ^-value@ def-size:! ||
            def-size not?< 4 def-size:! >? >? ;

: combine
  fix-size #-slot used? ?< rm+/si+?/i || reg/rm >?
  def-size aa>size:! ;

clean-module
end-module apar


: reset-args
  args arg-addr:! \ args arg-size 3 * erase
  iop-helpers:comma aa>type:! arg1 a>type:!0 arg2 a>type:!0 apar:reset ;
reset-args ['] reset-args emit:reset-args:!

: finish-arg
  << apar:slot-mask ?v|
       aa>type:@ iop-helpers:comma <> ?error" invalid operands" apar:combine
       arg-size arg-addr:+! apar:reset |?
     arg-addr args <> ?v| aa>type:@ ?error" invalid operands" |?
     else| aa>type:@ iop-helpers:comma <> ?error" invalid operands" aa>type:!0 >> ;

: (put-,)
  args arg2 = ?error" too many aruments" finish-arg
  args arg2 u<= ?< iop-helpers:comma aa>type:! >? ( mark next as required ) ;

: (put-arg)  ( argv )
  args arg2 u> ?error" too many aruments" -- just in case
  dup iop-helpers:op>type iop-helpers:comma = ?< drop (put-,) || apar:put >?
; ['] (put-arg) put-arg:!
