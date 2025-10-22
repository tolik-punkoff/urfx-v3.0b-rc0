;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; fixup list (used to fix forward references)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

enum{
  def: fixup-literal
  def: fixup-call
}

;; fixup chain item
struct:new fixrec
  field: next   -- 0: no more; should be the first field!
  field: zxaddr -- zx address
  field: spfa   -- shadow word PFA
  field: curr-spfa  -- current word
  field: type   -- lit or call
  field: fline  -- source line
  field: fname  -- pointer to file name nfa
end-struct

;; file names (for forwards)
module FILES
<case-sensitive>
<separate-hash>
end-module (private)

\ 0 quan last-created-fixrec


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; forward references

0 quan last-used-file-nfa   (private)
0 quan last-used-file-uid0  (private)
0 quan last-used-file-uid1  (private)

|: fname-last?  ( uid0 uid1 -- fname-nfa TRUE // FALSE )
  last-used-file-uid1 = swap last-used-file-uid0 = and not?exit&leave
  last-used-file-nfa true ;

|: fname-find  ( addr count -- TRUE // addr count FALSE )
  2dup vocid: files find-in-vocid not?exit&leave
  nrot 2drop
  inc-uidx last-used-file-uid1:! last-used-file-uid0:!
  dart:cfa>nfa dup last-used-file-nfa:! true ;

|: fname-ptr  ( -- fname-nfa )
  inc-uidx  2dup or not?error" not in include!"
  fname-last? ?exit
  inc-fname fname-find ?exit
  system:default-ffa >r <public-words>
  push-cur voc-cur: files system:mk-create
  r> system:default-ffa !
  inc-uidx swap
  dup last-used-file-uid0:! ,
  dup last-used-file-uid1:! ,
  system:latest-nfa pop-cur
  dup last-used-file-nfa:! ;


|: mk-fixup  ( zx-addr chain-head^ type -- chain^ )
  nrot fname-ptr >r
  align-here-4 here >r
  ( next) dup @ , r@ swap !
  ( zx-addr) lo-word ,
  ( spfa) 0 ,
  ( curr-spfa) 0 ,
  ( type) ,
  ( file line) inc-line# ,
  ( file name) r> r> ,
  \ dup last-created-fixrec:!
;


|: dump-chain-item  ( chain^ )
  ." CITEM=$" dup .hex8
  ."  NEXT=$" dup fixrec:next .hex8
  ."  ZXADDR=$" dup fixrec:zxaddr .hex4
  ."  TYPE=" dup fixrec:type base @ decimal swap 0.r base !
  ."  FLINE=" dup fixrec:fline base @ decimal swap 0.r base !
  ."  FNAME=" dup fixrec:fname debug:.id
  drop ;


|: fix-one  ( chain^ zx-addr )
  [ 0 ] [IF]
    endcr ." FIXING: chain=$" over .hex8 ."  zx-addr=$" dup .hex4
    ."  type=" over fixrec:type . ."  [zx-addr]=$" dup zx-c@ .hex2
    ."  spfa=$" over fixrec:spfa .hex8
    ."  curr-spfa=$" over fixrec:curr-spfa .hex8
    ."  dest:" over fixrec:spfa shword:self-cfa dart:cfa>nfa debug:.id
    ."  src:" over fixrec:curr-spfa shword:self-cfa dart:cfa>nfa debug:.id
    ."  dflags: $" over fixrec:spfa shword:tk-flags .hex8
    cr
  [ENDIF]
  over fixrec:spfa dup 0?error" ICE: fixup record without shadow PFA!"
  shword:tk-flags tkf-primitive and ?exit< drop
    endcr ." ERROR: invalid forward call around "
      dup fixrec:fname debug:.id
      dup fixrec:fline [char] : emit 0.r cr
    " cannot call primitive word \'" pad$:!
    dup fixrec:spfa shword:self-cfa dart:cfa>nfa idcount pad$:+
    " \' in \'" pad$:+
    fixrec:curr-spfa shword:self-cfa dart:cfa>nfa idcount pad$:+
    " \'!" pad$:+
    pad$:@ error >?
  >r fixrec:zxaddr dup zx-w@ r> + swap zx-w! ;

: fix-chain  ( zx-addr chain^ )
  dup not?exit< 2drop >?
\ endcr ." FIX-CHAIN: zx-addr=$" over .hex8 ."  chead=$" dup .hex8 cr
  swap >r <<  ( chain | zx-addr )
    dup ?^| \ endcr ."   ITEM:  " dup dump-chain-item cr
            dup r@ fix-one
            fixrec:next |?
  else| drop rdrop >> ;


false quan undefined-forwards? (private)

|: dump-chain-files  ( chain^ )
  << dup ?^|
    endcr ."   used around "
    dup fixrec:fname debug:.id
    dup fixrec:fline [char] : emit 0.r cr
  fixrec:next |?
  else| drop >> ;

|: check-forward  ( shadow-cfa -- res )
\ endcr ." CHECKING: \'" dup dart:cfa>nfa debug:.id
\ ." \': zxbegin=$" dup dart:cfa>pfa shword:zx-begin .hex8
\ ."  chain=$" dup dart:cfa>pfa shword:fwdfix-chain .hex8 cr
  turnkey-pass2? ?<
    dup dart:cfa>pfa shword:zx-begin -2 = ?exit< drop 0 >?
  >?
  dup dart:cfa>pfa shword:zx-begin 1+ ?exit< drop 0 >? ;; not a forward
  dup dart:cfa>pfa shword:fwdfix-chain not?exit< drop 0 >?
  endcr ." TCOM: unresolved forward \'" dup dart:cfa>nfa debug:.id ." \'\n"
  dart:cfa>pfa shword:fwdfix-chain dump-chain-files
  undefined-forwards?:!t 0 ;

@: check-forwards
  undefined-forwards?:!f
  vocid: forth-shadows ['] check-forward vocid-foreach drop
  vocid: system-shadows ['] check-forward vocid-foreach drop
  undefined-forwards? ?error" TCOM: found some unresolved forwards" ;


end-module
