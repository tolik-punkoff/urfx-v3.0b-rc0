;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compile varuous CFAs to target image
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; the following words are used both for creating a normal headers

: tgt-xcfalen!  ( ffa-addr )
  tcom:here over - swap tcom:c! ;

;; cfa ids
0 dup constant tgt-does-cfa
2 4* + dup constant tgt-variable-cfa
2 4* + dup constant tgt-constant-cfa
2 4* + dup constant tgt-uservar-cfa
2 4* + dup constant tgt-uservalue-cfa
drop

create tgt-cfa-list
;; format: cfa-xt-va extra-data-size
  ll@ do-does , 4 ,
  ll@ do-variable , 0 ,
  ll@ do-constant , 0 ,
  ll@ do-uservar , 0 ,
  ll@ do-uservalue , 0 ,
create;

: tgt-(doer^)  ( tgt-cfa -- va )  8 + ;

: tgt-doer@  ( tgt-cfa -- va )  tgt-(doer^) tcom:@ ;
: tgt-!doer  ( tgt-cfa doer-cfa )  swap tgt-(doer^) tcom:! ;

: tgt-latest-doer^  ( pfa -- doer^ )  tgt-latest-pfa 4- ;
: tgt-latest-!doer  ( pfa )  tgt-latest-doer^ tcom:! ;

: tgt-cfa,  ( cfaid )
  dup -?exit< drop >?
  tgt-cfa-list + tcom:here 4- ( ffa address ) swap @++
  ( call) $E8 tcom:c, (tgt-branch-addr,)
  ( align to 4 bytes) 0 tcom:w, 0 tcom:c,
  @ tcom:reserve
  tgt-xcfalen! ;
