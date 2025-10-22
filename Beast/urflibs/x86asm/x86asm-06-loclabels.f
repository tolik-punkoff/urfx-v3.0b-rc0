;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler: local labels and such
;; FIXME: this code SMELLS!
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module iop-helpers

 64 constant max-loc-labels
254 constant loc-nameless-bwd
255 constant loc-nameless-fwd

<private-words>

;; defined/referenced?
;; 0: not used yet
;; 1: forward reference (label value is fix chain)
;; 2: known label value
create ll-def max-loc-labels allot create;
create ll-val max-loc-labels 4* allot create;
create ll-rel max-loc-labels 4* allot create;
;; this is for backward and forward labels
;; 0 means "not set/used"
create ll-bwd 4 allot create;
create ll-fwd 4 allot create;
create ll-frel 4 allot create;

: ll-init  ll-def max-loc-labels erase ll-bwd !0 ll-fwd !0 ll-frel !0 ;
ll-init ['] ll-init emit:init-loc-labels:!

: ll-finish
  ll-fwd @ ll-frel @ or ?error" unresolved nameless forward"
  ll-def max-loc-labels for c@++ 1- not?<
  ." undefined label @@" i [char] 0 + 1- forth:emit cr error" undefined label"
  >? endfor drop ;
['] ll-finish emit:finish-loc-labels:!

0 quan lbl-curr-v/r
0 quan lbldef-value

: lbl-rel-ref?  ( -- flag )  ll-rel lbl-curr-v/r = ;

: lbl-fwd-fix-rel  ( addr -- addr )
  lbl-rel-ref? ?< emit:here + 4+ >? ;

: lbl-fwd-ref  ( val size-in-bytes idx -- val )
  nrot 4 <> ?error" invalid local forward reference" drop
  dup ll-def + 1 swap c!  lbl-curr-v/r dd-nth
  dup @ emit:here rot ! lbl-fwd-fix-rel ;

: lbl-ref-bwd  ( val size-in-bytes idx -- val )
  3drop ll-bwd @ ;

: lbl-ref-fwd  ( val size-in-bytes idx -- val )
  3drop lbl-rel-ref? ?< ll-frel || ll-fwd >?
  dup @ emit:here rot ! lbl-fwd-fix-rel ;

: lbl-ref  ( val size-in-bytes idx -- val )
  dup loc-nameless-bwd = ?exit< lbl-ref-bwd >?
  dup loc-nameless-fwd = ?exit< lbl-ref-fwd >?
  dup 1 max-loc-labels bounds not?error" invalid label index"
  dup ll-def + c@ dup not?< over dup ll-val dd-nth !0 ll-rel dd-nth !0 >?
  2 < ?< lbl-fwd-ref || lbl-curr-v/r dd-nth @ >r 2drop r> >? ;

: lbl-ref-addr ( val size-in-bytes idx -- val )  ll-val lbl-curr-v/r:! lbl-ref ;
: lbl-ref-rel  ( val size-in-bytes idx -- val )  ll-rel lbl-curr-v/r:! lbl-ref ;

['] lbl-ref-addr emit:<loc-label-addr>:!
['] lbl-ref-rel  emit:<loc-label-rel>:!

: lbl-fix-addr-chain  ( head value )
  >r begin dup while dup emit:@ r@ rot emit:! repeat drop rdrop ;

: lbl-rel!  ( addr value )  ( emit:here ) over 4+ - swap emit:! ;
: lbl-fix-rel-chain  ( head value )
  >r begin dup while dup emit:@ swap r@ lbl-rel! repeat drop rdrop ;

: lbl-fix-chains  ( value idx )
  swap >r dup ll-val dd-nth @ r@ lbl-fix-addr-chain ll-rel dd-nth @ r> lbl-fix-rel-chain ;

: lbl-known-value?  ( idx -- bool )
  dup loc-nameless-bwd = ?exit< drop ll-bwd @ 0<> >?
  dup loc-nameless-fwd = ?exit< drop false >?
  ll-def + c@ 2 = ;
['] lbl-known-value? emit:loc-label-known?:!

: lbl-value@  ( idx -- val )
  dup loc-nameless-bwd = ?exit< drop ll-bwd @ >?
  dup loc-nameless-fwd = ?exit< drop emit:dollar >?
  dup 1 max-loc-labels bounds not?error" invalid label index"
  dup ll-def + c@ 2 = ?< ll-val dd-nth @ || drop emit:dollar >? ;
['] lbl-value@ emit:loc-label@:!

<public-words>

: lbl-def  ( value idx )
  dup 1 max-loc-labels bounds not?error" invalid label index"
  swap >r  dup ll-def + c@ dup 2 = ?error" redefining local label"
  ?< r@ over lbl-fix-chains >? dup ll-def + 2 swap c!
  dup ll-val dd-nth r@ swap ! ll-rel dd-nth r> swap ! ;

: lbl-get  ( idx -- value )
  dup 1 max-loc-labels bounds not?error" invalid label index"
  dup ll-def + c@ 2 = not?error" cannot get value of forward"
  ll-val dd-nth @ ;

: loc-label-def  ( idx )  >r emit:flush r> emit:here swap lbl-def ;

: loc-nameless-def  emit:flush
  ll-fwd @ emit:here lbl-fix-addr-chain
  ll-frel @ emit:here lbl-fix-rel-chain
  emit:here ll-bwd ! ll-fwd !0 ll-frel !0 ;

end-module iop-helpers

instr: @@0:  1 iop-helpers:loc-label-def ;instr
instr: @@1:  2 iop-helpers:loc-label-def ;instr
instr: @@2:  3 iop-helpers:loc-label-def ;instr
instr: @@3:  4 iop-helpers:loc-label-def ;instr
instr: @@4:  5 iop-helpers:loc-label-def ;instr
instr: @@5:  6 iop-helpers:loc-label-def ;instr
instr: @@6:  7 iop-helpers:loc-label-def ;instr
instr: @@7:  8 iop-helpers:loc-label-def ;instr
instr: @@8:  9 iop-helpers:loc-label-def ;instr
instr: @@9: 10 iop-helpers:loc-label-def ;instr

instr: @@: iop-helpers:loc-nameless-def ;instr

extend-module instructions
: @@n  ( idx )
  dup 0 iop-helpers:max-loc-labels within not?error" invalid local label index"
  1+ [ iop-helpers:imm 65536 * ] {#,} + put-arg ;
: @@n,  ( idx )  @@n , ;

: @@n:  ( idx )
  dup 0 iop-helpers:max-loc-labels within not?error" invalid local label index"
  1+ iop-helpers:loc-label-def ;

;; the following definers will not flush the instruction
;; use "flush!" if you need to flush it
;; WARNING! make sure that there are no extra data on the data stack before flushing!

: @@n-get  ( idx -- value )  1+ iop-helpers:lbl-get ;
: @@n-def  ( value idx )  1+ iop-helpers:lbl-def ;

: @@b-get  ( -- value )  iop-helpers::ll-bwd @ dup not?error" undefined nameless label" ;

: @@0-get  1 iop-helpers:lbl-get ;
: @@1-get  2 iop-helpers:lbl-get ;
: @@2-get  3 iop-helpers:lbl-get ;
: @@3-get  4 iop-helpers:lbl-get ;
: @@4-get  5 iop-helpers:lbl-get ;
: @@5-get  6 iop-helpers:lbl-get ;
: @@6-get  7 iop-helpers:lbl-get ;
: @@7-get  8 iop-helpers:lbl-get ;
: @@8-get  9 iop-helpers:lbl-get ;
: @@9-get 10 iop-helpers:lbl-get ;

: @@0-def  1 iop-helpers:lbl-def ;
: @@1-def  2 iop-helpers:lbl-def ;
: @@2-def  3 iop-helpers:lbl-def ;
: @@3-def  4 iop-helpers:lbl-def ;
: @@4-def  5 iop-helpers:lbl-def ;
: @@5-def  6 iop-helpers:lbl-def ;
: @@6-def  7 iop-helpers:lbl-def ;
: @@7-def  8 iop-helpers:lbl-def ;
: @@8-def  9 iop-helpers:lbl-def ;
: @@9-def 10 iop-helpers:lbl-def ;
end-module instructions
