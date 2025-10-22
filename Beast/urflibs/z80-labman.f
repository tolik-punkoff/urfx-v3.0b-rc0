;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; label manager for z80asm
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
usage:

define new label manually:
  value " name" z80-labman:define

such label doesn't reset locals. if you want it to be a new locals start, use:
  z80-labman:reset-locals

set label value (use only for defined labels, otherwise it is UB):
  value " name" z80-labman:@set

get label value (getting value of undefined label is UB):
  " name" z80-labman:@get

check if label is defined (i.e. has known value):
  " name" z80-labman:defined?

check if label is known (i.e. used, but may be still undefined):
  " name" z80-labman:known?

to compile label reference, use:
  " name" offset z80-labman:ref-label-ofs,
or
  " name" z80-labman:ref-label,  -- for 0 offset
this properly handles forward references.

check for undefined labels:
  z80-labman:check-labels

it is possbile to be notified about new labels with:
  new-label-cb  ( addr count )
might be called several times for forwards.

to be notified about referenced label, use:
  ref-label-cb  ( addr count )

this can be used to track introduced and referenced lales in some
parts of the compiled code. note that the destination address is
not passed, it's only for the information.

note that the name passed is the fully qualified label name. i.e.
for local labels the last global label will be prepended. that is,
the name is guaranteed to be unique (but the case is not preserved).


start code definition:
  push-ctx voc-ctx: z80-labman:unk-labels -- to access unknown labels by name
  push-ctx voc-ctx: z80-labman:zx-labels  -- for known labels

end code definition:
  pop-ctx pop-ctx


define new label in source:
:global-name
:.local-name
:@noreset-global

or

global-name:
.local-name:
@noreset-global:

*)

\ $use <z80asm>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; z80asm label manager

module z80-labman
<disable-hash>


<published-words>
;; if `true`, put 0 instead of forward reference
\ false quan ignore-unknown-labels?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; notification callbacks

;; it is possbile to be notified about new labels with:
;;  new-label-cb  ( addr count )
['] 2drop vectored new-label-cb

;; to be notified about referenced label, use:
;;  ref-label-cb  ( addr count )
['] 2drop vectored ref-label-cb


struct:new lbl
new-field chain -- 0: known; otherwise points to fixup record head
new-field value
\ new-field nofix -- ignore fixups
new-field cfa     -- pointer to self CFA
\ constant #lbl-info
end-struct
<private-words>

;; original value is used to allow things like "lbl 2+"
struct:new fix
new-field next      -- next record or -1
2 new-n-field addr  -- z80 address
2 new-n-field type  -- type (see z80asm)
2 new-n-field xval  -- original value, subtracted from the actual
new-field fline     -- source line
new-field fname     -- pointer to file name nfa
\ constant #fix-info
end-struct

;; label words will be created here
<published-words>
module zx-labels
<separate-hash>
end-module zx-labels
<private-words>

;; file names
module zx-files
<case-sensitive>
<separate-hash>
end-module zx-files

0 quan last-used-file-nfa  (private)
0 quan last-used-file-uid0  (private)
0 quan last-used-file-uid1  (private)

|: fname-last?  ( uid0 uid1 -- fname-nfa TRUE // FALSE )
  last-used-file-uid1 = swap last-used-file-uid0 = and not?exit&leave
\ endcr ." KNOWN FILE: $" last-used-file-uid0 .hex8
\ ."  $" last-used-file-uid1 .hex8
\ ."  name=" last-used-file-nfa debug:.id cr
  last-used-file-nfa true ;

|: fname-find  ( addr count -- TRUE // addr count FALSE )
  2dup vocid: zx-files vocid-find not?exit&leave
  nrot 2drop
  inc-uidx last-used-file-uid1:! last-used-file-uid0:!
  dart:cfa>nfa dup last-used-file-nfa:! true ;

|: fname-ptr  ( -- fname-nfa )
  inc-uidx  2dup or not?error" not in include!"
  fname-last? ?exit
  inc-fname fname-find ?exit
  system:default-ffa >r <public-words>
  push-cur voc-cur: zx-files system:mk-create
  r> system:default-ffa !
  inc-uidx swap
  dup last-used-file-uid0:! ,
  dup last-used-file-uid1:! ,
  system:latest-nfa pop-cur
  dup last-used-file-nfa:!
\ endcr ." NEW FILE: $" last-used-file-uid0 .hex8
\ ."  $" last-used-file-uid1 .hex8
\ ."  name=" dup debug:.id cr
  ;

@: label-name  ( data^ -- addr count )
  dart:does-pfa>cfa dart:cfa>nfa idcount ;

@: find-label  ( addr count -- data^ TRUE // FALSE )
  vocid: zx-labels vocid-find not?exit&leave
  dart:cfa>pfa true ;

;; create new fixup record
|: new-fixup  ( type data^ )
  fname-ptr >r
  align-here-4 here >r  ( type data^ | new-fixup )
  ( next) dup lbl:chain ,
  r> swap lbl:chain:!
  ( addr) z80asm:emit:here w,
  ( type) w,
  ( xval) z80asm:emit:$$ w,
  ( file line) inc-line# ,
  ( file name) r> , ;

|: label-doer  ( data^ -- value )
\ endcr ." label doer: |" dup lbl:cfa dart:cfa>nfa debug:.id ." |\n"
  dup lbl:cfa dart:cfa>nfa idcount ref-label-cb
  dup lbl:chain ?< z80asm:arg-label:! z80asm:emit:$$ || lbl:value >? ;

0 quan last-defined-label

|: new-label  ( addr count -- data^ )
\ endcr ." LABEL: \'" 2dup type ." \' skip=" ignore-unknown-labels? 0.r cr
  system:default-ffa >r <public-words>
  push-cur voc-cur: zx-labels system:mk-builds
  system:latest-cfa dup >r ['] label-doer system:!doer pop-cur
  r> r> swap >r system:default-ffa !
  here  ;; data address, and idx
  ( no chain yet) -1 ,
  ( value) 0 ,
  \ ( nofix) ignore-unknown-labels? ,
  ( cfa) r> ,
  dup last-defined-label:! ;

;; this will call the notification callback
|: new-label-always  ( addr count -- data^ )
  \ ignore-unknown-labels? >r ignore-unknown-labels?:!f
  2dup new-label-cb
  new-label
  \ r> ignore-unknown-labels?:!
;


@: wipe-labels
  vocid: zx-labels system:remove-vocid-all ;

@: define  ( value addr count )
\ endcr ." *LBL: |" 2dup type ." | value=$" 2>r dup .hex4 2r> cr
  2dup find-label ?< drop
    " z80asm: duplicate label \'" pad$:! pad$:+ [char] " pad$:c+
    pad$:@ error >?
  new-label-always dup lbl:chain:!0 lbl:value:! ;

@: use-label  ( addr count -- value )
  z80asm:arg-label ?error" cannot use two labels"
  2dup ref-label-cb
  2dup find-label ?< nrot 2drop || new-label >?
  label-doer ;

;; called before emiting a label
|: emit-label  ( value type idx -- value )
\ endcr ." emit-label: |" dup lbl:cfa dart:cfa>nfa debug:.id ." | value=" dup lbl:value:@ 0.r cr
  \ dup lbl:cfa dart:cfa>nfa idcount ref-label-cb
  dup lbl:chain ?< new-fixup || lbl:value nrot 2drop >? ;
['] emit-label z80asm:emit:<label>:!

;; use this to emit reference to the label
@: ref-label-ofs,  ( addr count ofs )
  >r  ( addr count | ofs )
  2>r z80asm:flush 2r>
  2dup ref-label-cb
  2dup find-label ?< nrot 2drop || new-label >?
  ( data^ | ofs )
  z80asm:ltype-word swap
  ( type data^ | ofs )
  dup lbl:chain ?< new-fixup z80asm:emit:$$ || nip lbl:value >?
  r> + z80asm:emit:w, ;

@: ref-label,  ( addr count ) 0 ref-label-ofs, ;


false quan undefined-labels? (private)

@: files-vocid  ( -- vocid )  vocid: zx-files ;

\ |: dump-chain-item  ( chain^ )
\   ." CC=$" dup .hex8
\   ."  NEXT=$" dup fix:next .hex8
\   ."  Z80-ADDR=$" dup fix:addr .hex4
\   ."  Z80-TYPE=$" dup fix:type .hex4
\   ."  Z80-XVAL=$" dup fix:xval .hex4
\   ."  FLINE=" dup fix:fline base @ decimal swap 0.r base !
\   ."  FNFA=$" dup fix:fname .hex8 ;

|: dump-chain-files  ( chain^ )
\ endcr ." CHAIN=$" dup .hex8 cr
  << dup 1+ ?^|
\ endcr dup dump-chain-item cr
    endcr ."   used around "
    dup fix:fname debug:.id
    dup fix:fline [char] : emit 0.r cr
  fix:next |?
  else| drop >> ;

|: check-label  ( cfa -- res )
  dup dart:cfa>pfa lbl:chain not?exit< drop 0 >?
  endcr ." Z80ASM: undefined label \'" dup dart:cfa>nfa debug:.id ." \'\n"
  dart:cfa>pfa lbl:chain dump-chain-files
  undefined-labels?:!t 0 ;

@: check-labels
  undefined-labels?:!f
  vocid: zx-labels ['] check-label vocid-foreach drop
  undefined-labels? ?error" z80asm: found some undefined labels" ;


|: ?signed-byte  ( v )  -128 128 within not?error" signed byte expected" ;
|: ?byte  ( v )  -128 256 within not?error" byte expected" ;
|: ?word  ( v )  -32768 65536 within not?error" word expected" ;


|: lbl-jrdisp!  ( chain addr value -- chain )
  rot >r  ( addr value | chain )
  over dup z80asm:emit:c@ z80asm:jr-disp>addr lo-word
  r@ fix:xval lo-word - lo-word + lo-word
  ( addr dest-addr | chain )
  2dup z80asm:calc-jr-disp
  dup -128 128 within not?error" relative jump too long"
  rot z80asm:emit:c! drop
  r> ;

|: lbl-byte!  ( chain addr value -- chain )
  lo-byte
  rot >r  ( addr value | chain )
  over z80asm:emit:c@ r@ fix:xval lo-byte - lo-byte +
  swap z80asm:emit:c!
  r> ;

|: lbl-word!  ( chain addr value -- chain )
  lo-word
  rot >r  ( addr value | chain )
  over z80asm:emit:w@ r@ fix:xval lo-word - lo-word +
  swap z80asm:emit:w!
  r> ;

|: fix-chain  ( chain fix-addr )
  >r << dup 1+ ?^|
    dup fix:addr over fix:type << ( chain addr type | fix-addr )
\ endcr ." type=" dup . ." addr=$" over .hex8 ."  fix-addr=$" r@ .hex8
\ ."  w[fix]=$" r@ z80asm:emit:w@ .hex4
\ ."  xval=$" 2>r dup fix:xval .hex8 2r> cr
      z80asm:ltype-disp of?v| r@ ?signed-byte r@ lbl-byte! |?
      z80asm:ltype-rel8 of?v| r@ lbl-jrdisp! |?
      z80asm:ltype-byte of?v| r@ ?byte r@ lbl-byte! |?
      z80asm:ltype-word of?v| r@ ?word r@ lbl-word! |?
    else| error" invalid fixup type" >>
    ( chain | fix-addr )
  fix:next |? else| >> drop rdrop ;


false quan (wc-debug)
0 quan (wc-nfa)
0 quan (wc-dbg-header)
0 quan (wc-start)
0 quan (wc-end)

@: enable-wipe-debug  (wc-debug):!f ;
@: disable-wipe-debug  (wc-debug):!f ;

;; remove fixups for addressed [wc-start..wc-end)
|: (wipe-chain)  ( chain^ )
  dup >r @ 0 swap
  ( prev^ curr^ | chain-head^ )
  dup 0?exit< 2drop rdrop >?
  << dup 1+ ?^|
    dup fix:addr  ( prev^ curr^ addr | chain-head^ )
    (wc-start) (wc-end) within ?< ;; remove this label
      (wc-debug) ?<
        (wc-dbg-header) ?< (wc-dbg-header):!f
          endcr ." :wiping range for '" (wc-nfa) debug:.id
          ." ': [$" (wc-start) .hex4 ." ..$" (wc-end) .hex4 ." )\n" >?
        endcr ." :: remove addr $" dup fix:addr .hex4 cr >?
      over 0?<
        ;; fix head
        dup fix:next r@ !
      ||
        ;; fix previous
        2dup fix:next fix:next:!
      >?
      fix:next
    ||
      [ 0 ] [IF]
      (wc-debug) ?<
        (wc-dbg-header) ?< (wc-dbg-header):!f
          endcr ." :wiping range for '" (wc-nfa) debug:.id
          ." ': [$" (wc-start) .hex4 ." ..$" (wc-end) .hex4 ." )\n" >?
        endcr ." :: OK addr $" dup fix:addr .hex4 cr >?
      [ENDIF]
      nip dup fix:next >? |?
  else| >>
  2drop rdrop ;

|: (fix-wipe-range)  ( cfa -- res )
  dup dart:cfa>pfa lbl:chain:^
  over dart:cfa>nfa (wc-nfa):!  (wc-dbg-header):!t
  (wipe-chain)
  drop 0 ;

@: wipe-range  ( start-addr end-addr )
  (wc-end):! (wc-start):!
  vocid: zx-labels ['] (fix-wipe-range) vocid-foreach drop ;


|: good-lbl-start?  ( char -- flag )
  string:upchar
  << dup [char] A [char] Z bounds ?of?v| true |?
     [char] _ of?v| true |?
     [char] . of?v| true |?
  else| drop false >> ;

|: good-lbl-char?  ( char -- flag )
  dup good-lbl-start? ?exit< drop true >?
  << dup [char] 0 [char] 9 bounds ?of?v| true |?
     [char] - of?v| true |?
     [char] $ of?v| true |?
  else| drop false >> ;

|: good-lbl-name?  ( addr count -- flag )
  dup 2 < ?exit< 2drop false >?
  over c@ good-lbl-start? not?exit< 2drop false >?
  swap << c@++ good-lbl-char? not?exit< 2drop false >? 1 under- over ?^||
  else| 2drop true >> ;


;; for ".label"
0 quan last-global-label (private)
false quan was-local-label (private)

;; to the last defined global
@: reset-locals  last-defined-label last-global-label:! ;

|: set-new-global
  was-local-label not?< reset-locals >? ;

;; convert local labels to global
|: fix-label-name  ( addr count -- addr count )
  was-local-label:!f
  over c@ [char] . = not?exit
  last-global-label not?<
    endcr ." z80asm: local label \'" type ." \' without any global!\n" abort >?
  was-local-label:!t
  last-global-label label-name pad$:!
  pad$:+ pad$:@ ;

|: lbl-def?  ( addr count -- addr count FALSE // addr+1 count-1 TRUE )
  ws-vocab-cfa ?< false >?  ;; only top-level
  dup 1 > not?exit&leave
  over c@ [char] : = ?exit< string:/char true >?
  2dup + 1- c@ [char] : = ?exit< 1- true >?
  false ;

@: lbl-new  ( addr count value )
  >r
  dup 1 < ?error" invalid z80asm label name length"
  2>r z80asm:instr:flush!
  2r@ find-label not?exit< 2r> r> nrot define >? 2r@ new-label-cb
  dup lbl:chain dup not?< 2drop
    endcr ." z80asm error: duplicate label \'" 2r> type ." \'\n"
    error" duplicate z80asm label" >? 2rdrop
\ endcr ." CHAIN! label: \'" over label-name type ." \' value=$" r@ .hex4 cr
(*
  over lbl:nofix ?<
endcr ." CHAIN-SKIP! label: \'" over label-name type ." \' value=$" r@ .hex4 cr
    drop
  || r@ fix-chain >?
*)  r@ fix-chain
  dup last-defined-label:!
  dup lbl:chain:!0 r> swap lbl:value:! ;

|: lbl-starts-with-@?  ( addr count -- flag )
  2 < ?exit< drop false >?
  c@ [char] @ = ;

|: ulb-notfound  ( addr count -- value TRUE // FALSE )
  system:?exec
  lbl-def? ?exit<
    2dup lbl-starts-with-@? dup >r ?< string:/char >? ( addr count | @-label? )
    2dup good-lbl-name? not?exit< rdrop 2drop false >?
    fix-label-name
    r> ?< was-local-label:!t >? ;; hack -- avoid setting new global label
    2>r z80asm:instr:flush! z80asm:emit:here 2r> rot
\ endcr ." ***DEF LABEL: |" >r 2dup type r> ." | here=$" dup .hex4 cr
    \ >r 2dup r> nrot find-label ?< drop >r 2dup new-label-cb r> >?
    lbl-new set-new-global
    true >?
  2dup good-lbl-name? not?exit< 2drop false >?
\ endcr ." ***NEW LABEL: |" 2dup type ." |\n"
  fix-label-name
  use-label
  true ;


;; this wordlist is used to detect unknown labels via "notfound"
<published-words>
module unk-labels
<disable-hash>
end-module unk-labels
<private-words>
['] ulb-notfound vocid: unk-labels system:vocid-notfound-cfa!


@: defined?  ( addr count -- bool )
  find-label not?exit&leave
  lbl:chain 0= ;

@: known?  ( addr count -- bool )
  find-label dup ?< nip >? ;

;; the following API will call notification callbacks too.
@: @get  ( addr count -- value )
  2dup find-label not?<
    endcr ." z80asm: unknown label \'" type ." \'\n" abort >?
  dup lbl:chain ?< drop
    endcr ." z80asm: undefined label \'" type ." \'\n" abort >?
  nrot ref-label-cb  \ 2drop
  lbl:value ;

;; the following API will call notification callbacks too.
@: @set  ( value addr count )
  rot lbl-new ;

;; no callbacks called, no new labels created.
;; label name should be already expanded.
@: force-set  ( value addr count )
  2dup find-label not?exit<
    " cannot find label '" pad$:! pad$:+
    " '" pad$:+ pad$:@ error >?
  nrot 2drop
  lbl:value:! ;


seal-module
end-module z80-labman
