;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; some helper words
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create target and shadow words

(*
  shadow word format for Forth and code words (PFA):
    target-cfa-xt
    666 (signature)
    (forth-ip/cfa for tcf)
*)

666 constant tgt-shadow-signature

: (shadow-tgt-cfa@)  ( pfa -- tgt-cfa ) @ ;
: (shadow-tgt-cfa!)  ( tgt-cfa pfa )    ! ;

: (?shadow-tgt-sign) ( pfa )
  4+ @ tgt-shadow-signature <> ?error" invalid shadow word" ;

: (shadow-imm?)  ( pfa -- tgt-imm-flag )
  (shadow-tgt-cfa@) tgt-cfa>ffa tcom:@ tgt-wflag-immediate mask? ;

: (?shadow-notimm)  ( pfa )
  dup (shadow-imm?) not?exit< drop >?
  " immediate word \'" pad$:!
  (shadow-tgt-cfa@) tgt-cfa>nfa tcom:>real idcount pad$:+
  " \' cannot be used here" pad$:+
  pad$:@ error ;

|: (tgt-immediate)  tgt-wflag-immediate tgt-latest-ffa-or! ;


: tcf-jump@   ( pfa -- jump-addr  )  [ 2 4* ] {#,} + @ ;

|: (tcf-doer) ( pfa )
  tcf-jump@
  [ BEAST-DEVASTATOR ] [IF] execute-tail [ELSE] forth::(forth-branch) [ENDIF] ;

\ hack! duplicate to have different id
|: (tcfx-doer) ( pfa )  (tcf-doer) ;


0 quan (tgt-mk-rest-vocid-vocid) -- lol

;; sorry for this mess!
;; this creates vocab if "(tgt-mk-rest-vocid-vocid)" is non-zero
|: (tgt-mk-rest-vx)  ( does-cfa addr count tgt-nfa )
  vocs-in-target? >r >r 2>r   ( does-cfa | was-in-tgt? tgt-nfa addr count )
  current@ vocs-in-target? >target-vocs
  not?< (tc-forth-vocid) current! >?
  ( does-cfa old-current@ | was-in-tgt? tgt-nfa addr count )
  ;; sorry for this mess!
  current@ (tc-forth-vocid) = ?<  ;; check if we have a TCF word here
    2r@ (tc-forth-vocid) find-in-vocid ?< dart:cfa>pfa
        \ endcr 2r@ ." TCF: " type cr
      dup (?shadow-tgt-sign)
      dup @ ?error" internal Uroborus error"
      ( drop name) 2rdrop  ( get tgt-nfa) r>  ( save shadow pfa) swap >r
      tgt-nfa>lfa tgt-lfa>cfa r> (shadow-tgt-cfa!)
      r> not?< >orig-vocs >? current!
      ( drop does-cfa) drop
      exit
    >? >?
  2r> (tgt-mk-rest-vocid-vocid) dup ?< system:mk-builds-vocab || drop system:mk-builds >?
  r> tgt-nfa>lfa tgt-lfa>cfa ,  ;; target cfa-xt addresses
  tgt-shadow-signature ,
  swap system:latest-cfa swap system:!doer immediate
  r> not?< >orig-vocs >? current! ;

|: (tgt-mk-rest)  ( does-cfa addr count tgt-nfa )
  (tgt-mk-rest-vocid-vocid):!0 (tgt-mk-rest-vx) ;

;; sorry!
|: (tgt-mk-rest2)  ( addr count tgt-nfa does-cfa )
  swap >r nrot r> (tgt-mk-rest) ;

|: (tgt-mk-rest-vocid)  ( addr count tgt-nfa does-cfa host-vocid )
  (tgt-mk-rest-vocid-vocid):! swap >r nrot r> (tgt-mk-rest-vx)
  (tgt-mk-rest-vocid-vocid):!0 ;


|: (tgt-xcreate-tgt-w)  ( addr count tgt-cfa creatori-cfa -- nfa )
  >r over 1 tgt-#wname-max bounds not?error" invalid word name"
  nrot r> execute swap ( create cfaxt ) tgt-cfa, ;

|: (tgt-create-tgt-forth-word)  ( addr count tgt-cfa -- tgt-nfa )
  ['] tgt-mk-header-forth (tgt-xcreate-tgt-w) ;

|: (tgt-create-tgt-code-word)  ( addr count tgt-cfa -- tgt-nfa )
  ['] tgt-mk-header-mccode (tgt-xcreate-tgt-w) ;

\ |: (tgt-create-tgt-word-4)  ( addr count tgt-cfa -- tgt-nfa )
\   ['] tgt-mk-header-4 (tgt-xcreate-tgt-w) ;

|: (tgt-create-tgt-word-const-align)  ( addr count tgt-cfa -- tgt-nfa )
  ['] tgt-mk-header-const-align (tgt-xcreate-tgt-w) ;

|: (tgt-create-tgt-word-var-align)  ( addr count tgt-cfa -- tgt-nfa )
  ['] tgt-mk-header-var-align (tgt-xcreate-tgt-w) ;

|: (tgt-create-tgt-word-create-align)  ( addr count tgt-cfa -- tgt-nfa )
  ['] tgt-mk-header-create-align (tgt-xcreate-tgt-w) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; define word in target "FORTH"

*: TCF:
  current@ >r (tc-forth-vocid) current!
  ;; save target word name to dictionary
  ;; we cannot save it to PFA, because PFA should be in proper "shadow format"
  parse-name system:mk-builds immediate
  ( cfa-xt) 0 ,  tgt-shadow-signature ,
  ( host exec address) here 4+ ,
  system:latest-cfa ['] (tcf-doer) system:!doer
  [\\] ]
  [ BEAST-DEVASTATOR ] [IF]
    system:Succubus:start-colon
    \ system:Succubus:cannot-inline
  [ENDIF]
  r> 0xb00d_d00d ;

\ HACK! used for immediate words with host actions
*: TCFX:
  [\\] TCF:
  system:latest-cfa ['] (tcfx-doer) system:!doer ;

*: ;TCF
  0xb00d_d00d system:?pairs >r
  [ BEAST-DEVASTATOR ] [IF]
    \ system:Succubus:cannot-inline
    system:Succubus:finish-colon
  [ELSE]
    \\ forth:exit ( don't bother with TCO)
  [ENDIF]
  [\\] [
  r> current! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; used in target code to remember word references

;; used once to set "(default-abort)"
tcf: last-word-cfa-set  \ name
  system:?exec context@ voc-ctx: forth
  tgt-latest-cfa -find-required execute tcom:!
  context! ;tcf

;; used in main to set quan/vector/chain vocids
tcf: tgt-current-vocid-to  \ name
  system:?exec context@ voc-ctx: forth
  tgt-current@ [\\] to
  context! ;tcf


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; hack for "[ ... ]" in BEAST code
0 quan in-target-[?

(*
: }]  in-target-[? ?< in-target-[?:!f ?exec-target pop-ctx >? [\\] ] ;
tcf: [{
  in-target-[? ?error" wut?!" ?comp-target
  push-ctx voc-ctx: forth [\\] [ in-target-[?:!t ;tcf
*)

\ HACK!
module UROBORUS-[]
<disable-hash>
*: ]
  system:?exec
  in-target-[? ?< in-target-[?:!f ?exec-target pop-ctx pop-ctx >? [\\] forth::] ;
end-module UROBORUS-[]

tcfx: [
  in-target-[? ?error" wut?!" ?comp-target
  push-ctx voc-ctx: forth
  push-ctx voc-ctx: uroborus-[]
  [\\] [ in-target-[?:!t ;tcf


tcf: [[  ?exec-target push-ctx voc-ctx: forth ;tcf
tcf: ]]  ?exec-target pop-ctx ;tcf

\ tcf: [[ll@]]  ?in-target x86-find-label ;tcf

tcf: [[dynamic?]]  tcom:dynamic-binary ;tcf
tcf: [[static?]]  tcom:dynamic-binary ;tcf


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BEAST-INCLUDE-DISASM [IF]
: tgt-find-word-by-cfa  ( cfa-xt-va -- nfa-xt-va TRUE // FALSE )
  tgt-xfa-va << tcom:@ dup not?v| 2drop false |?
    2dup tgt-xfa>cfa = not?^||
  else| drop tgt-cfa>nfa true >> ;

: x86-tgt-find-name  ( cfa-xt-va -- addr count // dummy 0 )
  tgt-find-word-by-cfa not?exit< pad 0 >? tcom:>real idcount ;

: (x86-disasm-last)  ( do-ofs? )
  \ tgt-latest-cfa tcom:here disasm-range ;
  >r
  ['] x86-tgt-find-name x86dis:find-name:!
  tgt-latest-nfa tcom:>real endcr ." === DISASM: " debug:.id ."  ===\n"
  tgt-latest-cfa  r> ?< dup negate x86dis:addr-offset:! >?
  dup tgt-latest-wlen tcom:@ + x86dis:disasm-range
  x86dis:addr-offset:!0 ;

: x86-disasm-last
  tgt-asm-listing 0<= (x86-disasm-last) ;

tcf: x86-disasm-last  true (x86-disasm-last) ;tcf
tcf: x86-disasm-last-no-addr-ofs  false (x86-disasm-last) ;tcf
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; helpers for Succubus instruction tables

vect setup-asm-for-Succubus

:noname
  ['] noop x86asm:emit:<instr:!
  ['] noop x86asm:emit:instr>:!
  ['] noop x86asm:sc-cg-begin:!
  ['] noop x86asm:sc-cg-end-sswap:! ;
;; this will be changed later
setup-asm-for-Succubus:!

module itable-support
<disable-hash>

false quan in-table-mode
true quan natural-instruction-order
;; in "natural" byte order, lowest instruction byte is in the lowest dword byte
true quan natural-byte-order

true quan i/b-order-value

256 constant #buffer -- 256 dwords ought to be enough for everyone!
create buffer #buffer 2+ 4* allot create;
0 quan pos
0 quan istart

|: <itbl-nth>  ( idx -- addr )
  dup 0 #buffer within not?error" invalid i-table index (overflow?)"
  buffer db-nth ;

|: <itbl>-here ( -- addr )  pos ;
|: <itbl>-c,   ( byte -- )  pos <itbl-nth> c! pos:1+! ;
|: <itbl>-c@   ( addr -- byte )  <itbl-nth> c@ ;
|: <itbl>-c!   ( byte addr )  <itbl-nth> c! ;
|: <itbl>-@    ( addr -- byte )  <itbl-nth> @ ;
|: <itbl>-!    ( byte addr )  <itbl-nth> ! ;

|: <itbl>-istart  pos istart:! ;

|: #i-bytes  ( -- count )  pos istart - ;

;; doesn't prepend length, doesn't swap
|: collect-bytes-reverse  ( -- opcode )
  #i-bytes >r istart 0 << ( pos accum | len )
    256 *  over <itbl-nth> c@ or  1 under+
    r0:1-! r@ ?^||
  else| nip rdrop >> ;

;; doesn't prepend length, doesn't swap
|: collect-bytes-natural  ( -- opcode )
  collect-bytes-reverse bswap
  4 #i-bytes - 8 * rshift ;

;; build opcode dword
|: <itbl>-iend
  #i-bytes 1 4 within not?error" invalid instruction length for i-table"
  natural-byte-order ?< collect-bytes-natural || collect-bytes-reverse >?
  #i-bytes 24 lshift or
\ endcr ."  new instr: pos=" pos . ." len=" #i-bytes . ." start=" istart . ." opcode=$" dup .hex8 cr
  istart 3 and ?error" invalid alignment in i-table"
  istart <itbl-nth> !
  istart 4+ pos:! ;

: .opcode  ( u )
  [char] $ emit dup hi-word hi-byte .hex2
  [char] _ emit dup hi-word lo-byte .hex2
  [char] _ emit dup hi-byte .hex2
  [char] _ emit dup lo-byte .hex2
  drop ;

: flush
  pos not?error" empty i-table"
\ endcr ." i-table: " pos 4/ dup ., ." instruction" 1 <> ?< ." s" >? ." .\n"
\ endcr ." iorder-natural: " natural-instruction-order 0.r cr
  pos 4/ buffer
  natural-instruction-order not?< pos + 4- >?
  << ( #i-left src-addr )
    dup @
\ endcr ."   opcode: " dup .opcode cr
    in-target? ?< tcom:, || , >?
    1 under- over not?v||
  ^| natural-instruction-order ?< 4+ || 4- >? | >> 2drop ;

: restore-asm
  setup-asm
  setup-asm-for-Succubus ;

: takeover-asm
  pos:!0 istart:!0
  ['] <itbl>-here to x86asm:emit:here
  [']   <itbl>-c, to x86asm:emit:c,
  [']   <itbl>-c@ to x86asm:emit:c@
  [']   <itbl>-c! to x86asm:emit:c!
  [']    <itbl>-@ to x86asm:emit:@
  [']    <itbl>-! to x86asm:emit:!
  ['] <itbl>-istart x86asm:emit:<instr:!
  ['] <itbl>-iend x86asm:emit:instr>:!
  ['] noop x86asm:sc-cg-begin:!
  ['] noop x86asm:sc-cg-end-sswap:! ;


: cmd-<normal>    system:?exec i/b-order-value:!t ;
: cmd-<reversed>  system:?exec i/b-order-value:!f ;

: cmd-<i-order>   system:?exec i/b-order-value natural-instruction-order:! ;
: cmd-<b-order>   system:?exec i/b-order-value natural-byte-order:! ;

: cmd-<i-table>
  system:?exec
  in-table-mode ?error" already in i-table mode"
  takeover-asm
  x86asm:emit:init
  push-ctx voc-ctx: x86asm:instructions
  in-table-mode:!t ;

: cmd-<i-done>
  system:?exec
  in-table-mode not?error" not in i-table mode"
  x86asm:emit:finish
  flush
  pop-ctx restore-asm
  in-table-mode:!f ;

end-module itable-support


;; sorry for this pasta. i'll fix it later. maybe.

*: <normal>    itable-support:cmd-<normal> ;
*: <reversed>  itable-support:cmd-<reversed> ;
*: <i-order>   itable-support:cmd-<i-order> ;
*: <b-order>   itable-support:cmd-<b-order> ;
*: <i-table>   itable-support:cmd-<i-table> ;
*: <i-done>    itable-support:cmd-<i-done> ;

tcf: <normal>    itable-support:cmd-<normal> ;tcf
tcf: <reversed>  itable-support:cmd-<reversed> ;tcf
tcf: <i-order>   itable-support:cmd-<i-order> ;tcf
tcf: <b-order>   itable-support:cmd-<b-order> ;tcf
tcf: <i-table>   itable-support:cmd-<i-table> ;tcf
tcf: <i-done>    itable-support:cmd-<i-done> ;tcf
