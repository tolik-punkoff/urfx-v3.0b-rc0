;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; vocabulary stacks
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


: CURRENT@  ( -- va )  current @ ;
: CURRENT!  ( -- va )  current ! ;

: CONTEXT@  ( -- va )  context @ ;
: CONTEXT!  ( -- va )  context ! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; custom stack words

module XSTACK
<disable-hash>
(*
"xstack" data structure is:
  dd sp     ;; address of the last pushed item
  dd size   ;; stack size, in bytes
  dd start  ;; start address
stack grows with "4+".
[sp] is the current item.
*)

: >XSP    ( sx^ -- sp^ )     ;
: >SIZE   ( sx^ -- #^ )      4+ ;
: >START  ( sx^ -- start^ )  8 + ;

: SP0!   ( sx^ )  dup >start @ 4- swap >xsp ! ;
: DEPTH  ( sx^ -- depth )  dup >xsp @ swap >start @ - 4+ 4/ ;
: PICK   ( idx sx^ -- val )  >xsp @ swap 4* - @ ;

: PUSH  ( val sx^ )
  dup depth over >size @ 4- u>= ?error" xstack overflow"
  >xsp dup 4+! @ ! ;

: POP  ( sx^ -- val )
  dup depth 0<= ?error" xstack underflow"
  >xsp dup @ @ swap 4-! ;

;; drop everything until the given value hit.
;; the value will be dropped too.
: DROP-UNTIL  ( val sx^ )  << 2dup pop = not?^|| else| 2drop >> ;

;; find the given value, starting from the TOS
: FIND  ( val sx^ -- idx TRUE // FALSE )
  >r 0 swap
  ( idx val | sx^ )
  << over r@ depth = ?v| rdrop 2drop false |?
     over r@ pick over = not?^| 1 under+ |?
  else| rdrop drop true >> ;

end-module XSTACK


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; context wordlist stack management

: VSP0!                     (vsp) xstack:sp0! ;
: VSP-DEPTH ( -- depth )    (vsp) xstack:depth ;
: VSP-PICK  ( idx -- val )  (vsp) xstack:pick ;
: VSP-PUSH  ( val )         (vsp) xstack:push ;
: VSP-POP   ( -- val )      (vsp) xstack:pop ;
: VSP-DROP                  vsp-pop drop ;

;; drop everything until the given value hit.
;; the value will be dropped too.
: VSP-DROP-UNTIL  ( val )  (vsp) xstack:drop-until ;

: PUSH-CTX  context@ vsp-push ;
: POP-CTX   vsp-pop context! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; current wordlist stack management

: NSP0!                     (nsp) xstack:sp0! ;
: NSP-DEPTH ( -- depth )    (nsp) xstack:depth ;
: NSP-PICK  ( idx -- val )  (nsp) xstack:pick ;
: NSP-PUSH  ( val )         (nsp) xstack:push ;
: NSP-POP   ( -- val )      (nsp) xstack:pop ;
: NSP-DROP                  nsp-pop drop ;

;; drop everything until the given value hit.
;; the value will be dropped too.
: NSP-DROP-UNTIL  ( val )  (vsp) xstack:drop-until ;

: PUSH-CUR  current@ nsp-push ;
: POP-CUR   nsp-pop current! ;
