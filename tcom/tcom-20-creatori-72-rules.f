;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IR code superinstruction optimiser patterns
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
more constant folding -- add constant folders for all (most) math words.

2DUP cmpBRANCH -> remove 2DUP, special branch kind (ND-ND)
*)

extend-module TCOM
extend-module IR
extend-module OPT

: (prev-node-bool?)  ( -- bool )
  prev-node dup 0?exit
  [ 0 ] [IF]
    endcr ." *** BOOL? \'" dup node:spfa shword:self-cfa dart:cfa>nfa debug:.id
    ." \' is " dup node-out-bool? 0.r
    cr
  [ENDIF]
  node-out-bool? ;

: (prev-node-byte?)  ( -- bool )
  prev-node dup 0?exit
  [ 0 ] [IF]
    endcr ." *** 8-BIT? \'" dup node:spfa shword:self-cfa dart:cfa>nfa debug:.id
    ." \' is " dup node-out-8bit? 0.r
    cr
  [ENDIF]
  node-out-8bit? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; LIT optimisers

;; always leave DROP before LIT, for peephole optimiser.
;; do not use special "DROP:LIT" primitive, as it adds more cases to patterns.
;; WARNING! this has to be special-cased in "DROP" folder too.
pattern:[[ (DROP<n>) {n} {? 1 = ?} LIT {a} --> DROP LIT {a} ]]
pattern:[[ (DROP<n>) {n} {? 2 = ?} LIT {a} --> DROP DROP LIT {a} ]]
pattern:[[ (DROP<n>) {n} {? 2 > ?} LIT {a} --> (DROP<n>) {[ n 1 - ]} DROP LIT {a} ]]

;; LIT:!
;; the order matters!
pattern:[[ LIT {v} {? 0 = ?} LIT:! {a} --> LIT:!0 {a} ]]
pattern:[[ LIT {v} {? 1 = ?} LIT:! {a} --> LIT:!1 {a} ]]

;; LIT:C!
;; the order matters!
pattern:[[ LIT {v} {? 0 = ?} LIT:C! {a} --> LIT:C!0 {a} ]]
pattern:[[ LIT {v} {? 1 = ?} LIT:C! {a} --> LIT:C!1 {a} ]]

;; LIT:+!
pattern:[[ NEGATE  LIT:+! {a} --> LIT:-! {a} ]]
pattern:[[ LIT {v} LIT:+! {a} --> LIT:VAL2:+! {a} {v} ]]

;; LIT:-!
pattern:[[ LIT {v} LIT:-! {a} --> LIT:VAL2:+! {a} {[ v negate ]} ]]

;; LIT:VAL2:+!
;; convert to LIT:1+! or LIT:1-!
pattern:[[ LIT:VAL2:+! {a} {v} {?  0 = ?} --> ]]
pattern:[[ LIT:VAL2:+! {a} {v} {? -1 = ?} --> LIT:1-! {a} ]]
pattern:[[ LIT:VAL2:+! {a} {v} {?  1 = ?} --> LIT:1+! {a} ]]

;; LIT:C@
;; LIT:1C@ LIT:C@ -> LIT:@-HI-LO (for the same address)
pattern:[[ LIT:1C@ {a0} LIT:C@ {a1} {: a0 a1 = :} --> LIT:@-HI-LO {a0} ]]

;; LIT:1C@
;; LIT:C@ LIT:1C@ -> LIT:@-LO-HI (for the same address)
pattern:[[ LIT:C@ {a0} LIT:1C@ {a1} {: a0 a1 = :} --> LIT:@-LO-HI {a0} ]]

;; LIT:+
pattern:[[ LIT:+ {v} {? 0= ?}    --> ]]
pattern:[[ LIT:+ {v0} LIT:+ {v1} --> LIT:+ {[ v0 v1 + ]} ]]

;; EXECUTE
pattern:[[ @         EXECUTE --> @EXECUTE ]]
pattern:[[ LIT:@ {a} EXECUTE --> LIT:@EXECUTE {a} ]]

;; @EXECUTE
pattern:[[ LIT {a} @EXECUTE --> LIT:@EXECUTE {a} ]]


: (.poke-0-warning)  ( value addr count )
  rot dup lo-word 0 256 within ?<
    endcr ." WARNING: \'" . type
    ." \' -- did you messed the address and the value in '"
    curr-word-snfa idcount type ." '?\n"
  || 3drop
  >? ;

;; !
;; the order matters!
pattern:[[ LIT {v} {? 0 = ?} SWAP ! --> !0 ]]
pattern:[[ LIT {v} {? 1 = ?} SWAP ! --> !1 ]]
pattern:[[ LIT {v} SWAP           ! --> LIT:SWAP:! {v} ]]
pattern:[[ LIT {v} ! {: v " !" tcom:ir:opt:(.poke-0-warning) true :} --> LIT:! {v} ]]
pattern:[[ SWAP                   ! --> SWAP! ]]
pattern:[[ LIT:+ {v}              ! --> LIT:+:! {v} ]]

;; C!
;; the order matters!
pattern:[[ LIT {v} {? 0 = ?} SWAP C! --> C!0 ]]
pattern:[[ LIT {v} {? 1 = ?} SWAP C! --> C!1 ]]
pattern:[[ LIT {v} SWAP           C! --> LIT:SWAP:C! {v} ]]
pattern:[[ LIT {v} C! {: v " C!" tcom:ir:opt:(.poke-0-warning) true :} --> LIT:C! {v} ]]
pattern:[[ SWAP                   C! --> SWAP!C ]]
pattern:[[ LIT:+ {v}              C! --> LIT:+:C! {v} ]]

;; C!++
pattern:[[ SWAP C!++ --> SWAP-C!++ ]]

;; @
pattern:[[ LIT {a}   @ --> LIT:@ {a} ]]
pattern:[[ LIT:+ {a} @ --> LIT:+:@ {a} ]]

;; C@
pattern:[[ LIT {a}   C@ --> LIT:C@ {a} ]]
pattern:[[ LIT:+ {a} C@ --> LIT:+:C@ {a} ]]

;; +!
;; the order matters!
pattern:[[ LIT {v} {?  0 = ?} LIT {a} +! --> ]]
pattern:[[ LIT {v} {?  1 = ?} LIT {a} +! --> LIT:1+! {a} ]]
pattern:[[ LIT {v} {? -1 = ?} LIT {a} +! --> LIT:1-! {a} ]]
pattern:[[ LIT {a}                    +! --> LIT:+! {a} ]]

;; -!
;; the order matters!
pattern:[[ LIT {v} {?  0 = ?} LIT {a} -! --> ]]
pattern:[[ LIT {v} {?  1 = ?} LIT {a} -! --> LIT:1-! {a} ]]
pattern:[[ LIT {v} {? -1 = ?} LIT {a} -! --> LIT:1+! {a} ]]
pattern:[[ LIT {a}                    -! --> LIT:-! {a} ]]

;; C!0
pattern:[[ LIT:+ {v} C!0 --> LIT:+:C!0 {v} ]]
pattern:[[ LIT {a}   C!0 --> LIT:C!0 {a} ]]

;; C!1
pattern:[[ LIT:+ {v} C!1 --> LIT:+:C!1 {v} ]]
pattern:[[ LIT {a}   C!1 --> LIT:C!1 {a} ]]

;; !0
pattern:[[ LIT:+ {v} !0 --> LIT:+:!0 {v} ]]
pattern:[[ LIT {a}   !0 --> LIT:!0 {a} ]]

;; !1
pattern:[[ LIT:+ {v} !1 --> LIT:+:!1 {v} ]]
pattern:[[ LIT {a}   !1 --> LIT:!1 {a} ]]

;; 1+!
pattern:[[ LIT {a} 1+! --> LIT:1+! {a} ]]

;; 1-!
pattern:[[ LIT {a} 1-! --> LIT:1-! {a} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MASK optimisers

;; MASK8?
pattern:[[ LIT {a} LIT {b}           MASK8? --> LIT {[ a b and lo-byte ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {b} {? lo-byte 0 = ?} MASK8? --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b}                   MASK8? --> MASK8:LIT {[ b lo-byte ]} ]]

;; MASK?
pattern:[[ LIT {a} LIT {b}           MASK? --> LIT {[ a b and lo-word ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {b} {?  0 = ?}        MASK? --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {? -1 = ?}        MASK? --> 0<> ]]
pattern:[[ LIT {b} {? hi-byte 0 = ?} MASK? --> MASK8:LIT {[ b ]} ]]
pattern:[[ LIT {b} {? lo-byte 0 = ?} MASK? --> MASK8-HI:LIT {[ b hi-byte ]} ]]
pattern:[[ LIT {b}                   MASK? --> MASK:LIT {[ b ]} ]]
;; and this
pattern:[[ MASK? {: tcom:ir:opt:(prev-node-byte?) :} --> MASK8? ]]


: (opt-next-node-0/T-BRANCH?)  ( -- bool )
  next-node-spfa dup -0?exit< drop false >?
  dup (opt-zx-"0BRANCH") =
  swap (opt-zx-"TBRANCH") = or ;

;; if next instriction is "0BRANCH" or "TBRANCH", replace with "AND8".
;; this is ok, because those branches don't need strict boolean value.
pattern:[[ MASK8? {: tcom:ir:opt:(opt-next-node-0/T-BRANCH?) :} --> AND8 ]]
pattern:[[ MASK8:LIT {n} {: tcom:ir:opt:(opt-next-node-0/T-BRANCH?) :} --> LIT {[ n lo-byte ]} AND8 ]]
pattern:[[ MASK8-HI:LIT {n} {: tcom:ir:opt:(opt-next-node-0/T-BRANCH?) :} --> LIT {[ n lo-byte ]} AND8-HI ]]

;; if next instriction is "0BRANCH" or "TBRANCH", replace with "AND".
;; this is ok, because those branches don't need strict boolean value.
pattern:[[ MASK? {: tcom:ir:opt:(opt-next-node-0/T-BRANCH?) :} --> AND ]]
pattern:[[ MASK:LIT {n} {: tcom:ir:opt:(opt-next-node-0/T-BRANCH?) :} --> LIT {[ n ]} AND ]]

;; if we are checking bit 15, we want to know if the number is negative.
;; "0<" is faster in this case.
pattern:[[ LIT {b} {? lo-word $8000 = ?}  MASK? --> 0< ]]
pattern:[[ MASK:LIT {b} {? lo-word $8000 = ?}   --> 0< ]]
pattern:[[ MASK-HI:LIT {b} {? lo-byte $80 = ?}  --> 0< ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BIT optimisers

;; BIT8?
pattern:[[ LIT {a} LIT {b} BIT8? --> LIT {[ 1 b 7 and lshift a and ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {b}         BIT8? --> LIT {[ 1 b 7 and lshift ]} MASK8? ]]

;; BIT?
pattern:[[ LIT {a} LIT {b}     BIT? --> LIT {[ b dup 15 u> ?exit< drop 0 >? 1 swap lshift a and ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {b} {? 15 u> ?} BIT? --> DROP LIT {[ 0 ]} ]]
;; if we are checking bit 15, we want to know if the number is negative.
;; "0<" is faster in this case.
pattern:[[ LIT {b} {? 15 = ?}  BIT? --> 0< ]]
pattern:[[ LIT {b}             BIT? --> LIT {[ 1 b 15 and lshift ]} MASK? ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bitwise operators optimisers

;; "pot" is "1 << value"
: (pot-16?) ( n -- pot TRUE // FALSE )
  lo-word
  dup 1 < ?exit< drop false >?
  pot dup -?exit< drop false >?
  true ;

: (is-pot-16?) ( n -- bool )  (pot-16?) ?< drop true || false >? ;
: (is-pot-15?) ( n -- bool )  (pot-16?) ?< 15 < || false >? ;
: (pot-16)     ( n -- pot )   (pot-16?) not?error" ICE: not a pot (16)!" ;

;; "pot" is "1 << value"
;; WARNING! only low byte of `n` is checked!
: (pot-8?) ( n -- pot TRUE // FALSE )
  lo-byte
  dup 1 < ?exit< drop false >?
  dup 255 > ?exit< drop false >?
  pot dup -?exit< drop false >?
  true ;

: (is-pot-8?) ( n -- bool )  (pot-8?) ?< drop true || false >? ;
: (pot-8)     ( n -- pot )   (pot-8?) not?error" ICE: not a pot (8)!" ;

;; AND
;; the order matters!
pattern:[[ DUP                        AND --> ]]
pattern:[[ SWAP                       AND --> AND ]]
pattern:[[ LO-BYTE                    AND --> AND8 ]]
pattern:[[ HI-BYTE                    AND --> HI-BYTE AND8 ]]
pattern:[[ LIT {a} LIT {b}            AND --> LIT {[ a b and ]} ]]
pattern:[[ LIT {b} {?   0 = ?}        AND --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {?  -1 = ?}        AND --> ]]
pattern:[[ LIT {b} {? hi-byte 0= ?}   AND --> LIT {b} AND8 ]]
pattern:[[ LIT {b} {? lo-byte 0= ?}   AND --> LIT {[ b hi-byte ]} AND8-HI ]]
;; if the previous node is byte, we can safely use AND8
pattern:[[                            AND {: tcom:ir:opt:(prev-node-byte?) :} --> AND8 ]]
pattern:[[ LIT {b}                    AND --> AND:LIT {b} ]]

;; AND8
pattern:[[ LO-BYTE                     AND8 --> AND8 ]]
pattern:[[ LIT {a} LIT {b}             AND8 --> LIT {[ a b and lo-byte ]} ]]
;; if the previous node is boolean, we can optimise known literals
pattern:[[ LIT {b} {? $01 and 0 = ?}   AND8 {: tcom:ir:opt:(prev-node-bool?) :} --> DROP LIT {[ 0 ]} ]]
;; if prev is boolean, and we are masking bit 0, this is noop
pattern:[[ LIT {b} {? $01 and 0 <> ?}  AND8 {: tcom:ir:opt:(prev-node-bool?) :} --> DROP ]]
pattern:[[ LIT {b} {? lo-byte   0 = ?} AND8 --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {? lo-byte $FF = ?} AND8 --> LO-BYTE ]]
pattern:[[ LIT {b}                     AND8 --> AND8:LIT {b} ]]

;; AND8-HI
;; if the previous node is byte, the result is known
pattern:[[                           AND8-HI {: tcom:ir:opt:(prev-node-byte?) :} --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ HI-BYTE                   AND8-HI --> AND8-HI ]]
pattern:[[ LO-BYTE                   AND8-HI --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {a} LIT {b}           AND8-HI --> LIT {[ a b lo-byte 256 * and ]} ]]
pattern:[[ LIT {b} {? lo-byte 0 = ?} AND8-HI --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b}                   AND8-HI --> AND8-HI:LIT {b} ]]


;; ~AND
;; the order matters!
pattern:[[ LIT {a} LIT {b}                        ~AND --> LIT {[ a b ~and ]} ]]
pattern:[[ LIT {b} {?   0 = ?}                    ~AND --> ]]
pattern:[[ LIT {b} {?  -1 = ?}                    ~AND --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {? lo-word $FF00 = ?}          ~AND --> LO-BYTE ]]
pattern:[[ LIT {b} {? tcom:ir:opt:(is-pot-16?) ?} ~AND --> RES-BIT:LIT {[ b tcom:ir:opt:(pot-16) ]} ]]
pattern:[[ LIT {b} {? hi-byte 0= ?}               ~AND --> LIT {b} ~AND8 ]]
pattern:[[ LIT {b} {? lo-byte 0= ?}               ~AND --> LIT {[ b hi-byte ]} ~AND8-HI ]]
;; if the previous node is boolean, we can optimise known literals
pattern:[[ LIT {b} {? $01 and 0 <> ?}             ~AND {: tcom:ir:opt:(prev-node-bool?) :} --> DROP LIT {[ 0 ]} ]]
;; if prev is boolean, and we are masking bit 0, this is noop
pattern:[[ LIT {b} {? $01 and 0 = ?}              ~AND {: tcom:ir:opt:(prev-node-bool?) :} --> DROP ]]
pattern:[[ LIT {b}                                ~AND --> AND:LIT {[ b -1 xor ]} ]]

;; ~AND8
pattern:[[ LIT {a} LIT {b}                       ~AND8 --> LIT {[ a b lo-byte ~and ]} ]]
pattern:[[ LIT {b} {? lo-byte   0 = ?}           ~AND8 --> LO-BYTE ]]
pattern:[[ LIT {b} {? lo-byte $FF = ?}           ~AND8 --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {? tcom:ir:opt:(is-pot-8?) ?} ~AND8 --> RES-BIT:LIT {[ b tcom:ir:opt:(pot-8) ]} ]]
;; if the previous node is boolean, we can optimise known literals
pattern:[[ LIT {b} {? $01 and 0 <> ?}            ~AND8 {: tcom:ir:opt:(prev-node-bool?) :} --> DROP LIT {[ 0 ]} ]]
;; if prev is boolean, and we are masking bit 0, this is noop
pattern:[[ LIT {b} {? $01 and 0 = ?}             ~AND8 {: tcom:ir:opt:(prev-node-bool?) :} --> DROP ]]
pattern:[[ LIT {b}                               ~AND8 --> ~AND8:LIT {b} ]]

;; ~AND8-HI
pattern:[[ LIT {a} LIT {b}                       ~AND8-HI --> LIT {[ a b lo-byte 256 * ~and ]} ]]
pattern:[[ LIT {b} {? lo-byte $FF = ?}           ~AND8-HI --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {? tcom:ir:opt:(is-pot-8?) ?} ~AND8-HI --> RES-BIT:LIT {[ b tcom:ir:opt:(pot-8) 8 + ]} ]]
pattern:[[ LIT {b}                               ~AND8-HI --> ~AND8-HI:LIT {b} ]]


;; OR
;; the order matters!
pattern:[[ DUP                                    OR --> ]]
pattern:[[ SWAP                                   OR --> OR ]]
pattern:[[ LO-BYTE                                OR --> OR8 ]]
pattern:[[ LIT {a} LIT {b}                        OR --> LIT {[ a b or ]} ]]
pattern:[[ LIT {b} {?   0 = ?}                    OR --> ]]
pattern:[[ LIT {b} {?  -1 = ?}                    OR --> DROP LIT {[ -1 ]} ]]
pattern:[[ LIT {b} {? tcom:ir:opt:(is-pot-16?) ?} OR --> SET-BIT:LIT {[ b tcom:ir:opt:(pot-16) ]} ]]
pattern:[[ LIT {b} {? hi-byte 0= ?}               OR --> LIT {b} OR8 ]]
pattern:[[ LIT {b} {? lo-byte 0= ?}               OR --> LIT {[ b hi-byte ]} OR8-HI ]]
pattern:[[ LIT {b}                                OR --> OR:LIT {b} ]]

;; OR8
pattern:[[ LO-BYTE                               OR8 --> OR8 ]]
pattern:[[ HI-BYTE                               OR8 --> DROP ]]
pattern:[[ LIT {a} LIT {b}                       OR8 --> LIT {[ a b lo-byte or ]} ]]
pattern:[[ LIT {b} {? lo-byte   0 = ?}           OR8 --> ]]
pattern:[[ LIT {b} {? tcom:ir:opt:(is-pot-8?) ?} OR8 --> SET-BIT:LIT {[ b tcom:ir:opt:(pot-8) ]} ]]
pattern:[[ LIT {b}                               OR8 --> OR8:LIT {b} ]]

;; OR8-HI
pattern:[[ LO-BYTE                               OR8-HI --> OR8-HI ]]
pattern:[[ HI-BYTE                               OR8-HI --> DROP ]]
pattern:[[ LIT {a} LIT {b}                       OR8-HI --> LIT {[ a b lo-byte 256 * or ]} ]]
pattern:[[ LIT {b} {? lo-byte 0 = ?}             OR8-HI --> ]]
pattern:[[ LIT {b} {? tcom:ir:opt:(is-pot-8?) ?} OR8-HI --> SET-BIT:LIT {[ b tcom:ir:opt:(pot-8) 8 + ]} ]]
pattern:[[ LIT {b}                               OR8-HI --> OR8-HI:LIT {b} ]]


;; XOR
;; the order matters!
pattern:[[ DUP                           XOR --> DROP LIT {[ 0 ]} ]]
pattern:[[ SWAP                          XOR --> XOR ]]
pattern:[[ LO-BYTE                       XOR --> XOR8 ]]
pattern:[[ LIT {a} LIT {b}               XOR --> LIT {[ a b xor ]} ]]
pattern:[[ LIT {b} {?   0 = ?}           XOR --> ]]
pattern:[[ LIT {b} {?  -1 = ?}           XOR --> CPL ]]
pattern:[[ LIT {b} {?  $FF = ?}          XOR --> CPL8 ]]
pattern:[[ LIT {b} {? lo-word $FF00 = ?} XOR --> CPL8-HI ]]
pattern:[[ LIT {b} {? hi-byte 0= ?}      XOR --> LIT {b} XOR8 ]]
pattern:[[ LIT {b} {? lo-byte 0= ?}      XOR --> LIT {[ b hi-byte ]} XOR8-HI ]]
pattern:[[ LIT {b}                       XOR --> XOR:LIT {b} ]]

;; XOR8
pattern:[[ LO-BYTE                     XOR8 --> XOR8 ]]
pattern:[[ HI-BYTE                     XOR8 --> DROP ]]
pattern:[[ LIT {a} LIT {b}             XOR8 --> LIT {[ a b lo-byte xor ]} ]]
pattern:[[ LIT {b} {? lo-byte   0 = ?} XOR8 --> ]]
pattern:[[ LIT {b} {? lo-byte $FF = ?} XOR8 --> CPL8 ]]
pattern:[[ LIT {b}                     XOR8 --> XOR8:LIT {b} ]]

;; XOR8-HI
pattern:[[ LO-BYTE                     XOR8-HI --> XOR8-HI ]]
pattern:[[ HI-BYTE                     XOR8-HI --> DROP ]]
pattern:[[ LIT {a} LIT {b}             XOR8-HI --> LIT {[ a b lo-byte 256 * xor ]} ]]
pattern:[[ LIT {b} {? lo-byte 0 = ?}   XOR8-HI --> ]]
pattern:[[ LIT {b} {? lo-byte $FF = ?} XOR8-HI --> CPL8-HI ]]
pattern:[[ LIT {b}                     XOR8-HI --> XOR8-HI:LIT {b} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; JOIN-BYTES and SPLIT-BYTES optimisers

;; JOIN-BYTES  ( n-lo n-hi -- n )
pattern:[[ LIT {a} LIT {b}   JOIN-BYTES --> LIT {[ a lo-byte b lo-byte 256 * + ]} ]]
pattern:[[ LIT {b} {? 0 = ?} JOIN-BYTES --> LO-BYTE ]]

;; JOIN-BYTES-HI-LO  ( n-hi n-lo -- n )
pattern:[[ LIT {a} LIT {b}   JOIN-BYTES-HI-LO --> LIT {[ b lo-byte a lo-byte 256 * + ]} ]]
pattern:[[ LIT {b} {? 0 = ?} JOIN-BYTES-HI-LO --> 256* ]]

;; SPLIT-BYTES  ( n -- n-lo n-hi )
pattern:[[ LIT {a} SPLIT-BYTES --> LIT {[ a lo-byte ]} LIT {[ a hi-byte ]} ]]

;; SPLIT-BYTES-HI-LO  ( n -- n-hi n-lo )
pattern:[[ LIT {a} SPLIT-BYTES-HI-LO --> LIT {[ a hi-byte ]} LIT {[ a lo-byte ]} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; one-operand constant folders

;; BSWAP  ( n -- n-bswapped )
pattern:[[ LIT {a} BSWAP --> LIT {[ a wbswap ]} ]]

;; LO-BYTE
pattern:[[ LIT {a}     LO-BYTE --> LIT {[ a lo-byte ]} ]]
pattern:[[ LIT:@ {a}   LO-BYTE --> LIT:C@ {a} ]]
pattern:[[ LIT:C@ {a}  LO-BYTE --> LIT:C@ {a} ]]
pattern:[[ LIT:1C@ {a} LO-BYTE --> LIT:1C@ {a} ]]
;; if the previous node is byte, this does nothing
pattern:[[ LO-BYTE {: tcom:ir:opt:(prev-node-byte?) :} --> ]]

;; HI-BYTE
pattern:[[ LIT {a}     HI-BYTE --> LIT {[ a hi-byte ]} ]]
pattern:[[ LIT:@ {a}   HI-BYTE --> LIT:1C@ {a} ]]
pattern:[[ LIT:C@ {a}  HI-BYTE --> LIT {[ 0 ]} ]]
pattern:[[ LIT:1C@ {a} HI-BYTE --> LIT {[ 0 ]} ]]
;; if the previous node is byte, this does nothing
pattern:[[ HI-BYTE {: tcom:ir:opt:(prev-node-byte?) :} --> DROP LIT {[ 0 ]} ]]

pattern:[[ DUP LO-BYTE SWAP HI-BYTE --> SPLIT-BYTES ]]
pattern:[[ DUP HI-BYTE SWAP LO-BYTE --> SPLIT-BYTES-HI-LO ]]


;; ABS
pattern:[[ LIT {a}                          ABS --> LIT {[ a abs lo-word ]} ]]
pattern:[[ LO-BYTE                          ABS --> LO-BYTE ]]
pattern:[[ HI-BYTE                          ABS --> HI-BYTE ]]
pattern:[[ AND:LIT {a} {? $8000 and 0= ?}   ABS --> AND:LIT {a} ]]
pattern:[[ AND8:LIT {a}                     ABS --> AND8:LIT {a} ]]
pattern:[[ AND8-HI:LIT {a} {? $80 and 0= ?} ABS --> AND8-HI:LIT {a} ]]
pattern:[[ RES-BIT:LIT {a} {? 15 = ?}       ABS --> RES-BIT:LIT {a} ]]
pattern:[[ LIT:C@ {a}                       ABS --> LIT:C@ {a} ]]
pattern:[[ LIT:1C@ {a}                      ABS --> LIT:1C@ {a} ]]
;; if the previous node is byte, this does nothing
pattern:[[ ABS {: tcom:ir:opt:(prev-node-byte?) :} --> ]]

;; NEGATE
pattern:[[ LIT {a} NEGATE --> LIT {[ a negate lo-word ]} ]]

;; C>S
pattern:[[ LIT {a} C>S --> LIT {[ a c>s ]} ]]
;; if the previous node is boolean, this does nothing
pattern:[[ C>S {: tcom:ir:opt:(prev-node-bool?) :} --> ]]

;; 0MAX
pattern:[[ LIT {a}                          0MAX --> LIT {[ a 0 max ]} ]]
pattern:[[ LO-BYTE                          0MAX --> LO-BYTE ]]
pattern:[[ HI-BYTE                          0MAX --> HI-BYTE ]]
pattern:[[ AND:LIT {a} {? $8000 and 0= ?}   0MAX --> AND:LIT {a} ]]
pattern:[[ AND8:LIT {a}                     0MAX --> AND8:LIT {a} ]]
pattern:[[ AND8-HI:LIT {a} {? $80 and 0= ?} 0MAX --> AND8-HI:LIT {a} ]]
pattern:[[ RES-BIT:LIT {a} {? 15 = ?}       0MAX --> RES-BIT:LIT {a} ]]
pattern:[[ LIT:C@ {a}                       0MAX --> LIT:C@ {a} ]]
pattern:[[ LIT:1C@ {a}                      0MAX --> LIT:1C@ {a} ]]
;; if the previous node is byte, this does nothing
pattern:[[ 0MAX {: tcom:ir:opt:(prev-node-byte?) :} --> ]]

;; 1MAX
pattern:[[ LIT {a} 1MAX --> LIT {[ a 1 max ]} ]]
;; if the previous node is byte, use faster code
pattern:[[         1MAX {: tcom:ir:opt:(prev-node-byte?) :} --> 1MAX:BYTE ]]

;; CPL
pattern:[[ LIT {a} CPL --> LIT {[ a -1 xor ]} ]]

;; CPL8
pattern:[[ LIT {a} CPL8 --> LIT {[ a $00FF xor ]} ]]

;; CPL8-HI
pattern:[[ LIT {a} CPL8 --> LIT {[ a $FF00 xor ]} ]]

: (rev-x)  ( value count )
  0 swap  ( old-val new-val count )
  for 1 lshift over 1 and or  swap 1 rshift swap endfor nip ;

;; REV8
pattern:[[ LIT {a} REV8 --> LIT {[ a 8 tcom:ir:opt:(rev-x) lo-byte  a hi-byte 256 * or ]} ]]

;; REV16
pattern:[[ LIT {a} REV16 --> LIT {[ a 16 tcom:ir:opt:(rev-x) ]} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; div and mul folders

pattern:[[ LIT {a}   2*C --> LIT {[ a lo-byte   2 u*  a $FF00 and or ]} ]]
pattern:[[ LIT {a}   4*C --> LIT {[ a lo-byte   4 u*  a $FF00 and or ]} ]]
pattern:[[ LIT {a}   8*C --> LIT {[ a lo-byte   8 u*  a $FF00 and or ]} ]]
pattern:[[ LIT {a}  16*C --> LIT {[ a lo-byte  16 u*  a $FF00 and or ]} ]]
pattern:[[ LIT {a}  32*C --> LIT {[ a lo-byte  32 u*  a $FF00 and or ]} ]]
pattern:[[ LIT {a}  64*C --> LIT {[ a lo-byte  64 u*  a $FF00 and or ]} ]]
pattern:[[ LIT {a} 128*C --> LIT {[ a lo-byte 128 u*  a $FF00 and or ]} ]]

pattern:[[ LIT {a}   2* --> LIT {[ a lo-word   2 u* ]} ]]
pattern:[[ LIT {a}   3* --> LIT {[ a lo-word   3 u* ]} ]]
pattern:[[ LIT {a}   4* --> LIT {[ a lo-word   4 u* ]} ]]
pattern:[[ LIT {a}   8* --> LIT {[ a lo-word   8 u* ]} ]]
pattern:[[ LIT {a}  16* --> LIT {[ a lo-word  16 u* ]} ]]
pattern:[[ LIT {a}  32* --> LIT {[ a lo-word  32 u* ]} ]]
pattern:[[ LIT {a}  64* --> LIT {[ a lo-word  64 u* ]} ]]
pattern:[[ LIT {a} 128* --> LIT {[ a lo-word 128 u* ]} ]]

;; U*
;; note that "*" is just the alias for "U*", because if we
;; will ignore overflow, they are the same.
pattern:[[ SWAP                U* --> U* ]] -- as multiplication is commutative, we can do this
pattern:[[ LIT {a} LIT {b}     U* --> LIT {[ a lo-word b lo-word u* ]} ]]
pattern:[[ LIT {b} {?   0 = ?} U* --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {?   1 = ?} U* --> ]]
pattern:[[ LIT {b} {?  -1 = ?} U* --> NEGATE ]]
pattern:[[ LIT {b} {?   2 = ?} U* -->   2* ]]
pattern:[[ LIT {b} {?   3 = ?} U* -->   3* ]]
pattern:[[ LIT {b} {?   4 = ?} U* -->   4* ]]
pattern:[[ LIT {b} {?   8 = ?} U* -->   8* ]]
pattern:[[ LIT {b} {?  16 = ?} U* -->  16* ]]
pattern:[[ LIT {b} {?  32 = ?} U* -->  32* ]]
pattern:[[ LIT {b} {?  64 = ?} U* -->  64* ]]
pattern:[[ LIT {b} {? 128 = ?} U* --> 128* ]]
pattern:[[ LIT {b} {? 256 = ?} U* --> 256* ]]


: (.div0-warning)
  endcr ." WARNING: division by zero in '"
  curr-word-snfa idcount type ." '?\n" ;

pattern:[[ LIT {a}   2U/ --> LIT {[ a lo-word   2 u/ ]} ]]
pattern:[[ LIT {a}   4U/ --> LIT {[ a lo-word   4 u/ ]} ]]
pattern:[[ LIT {a}   8U/ --> LIT {[ a lo-word   8 u/ ]} ]]
pattern:[[ LIT {a}  16U/ --> LIT {[ a lo-word  16 u/ ]} ]]
pattern:[[ LIT {a}  32U/ --> LIT {[ a lo-word  32 u/ ]} ]]
pattern:[[ LIT {a}  64U/ --> LIT {[ a lo-word  64 u/ ]} ]]
pattern:[[ LIT {a} 128U/ --> LIT {[ a lo-word 128 u/ ]} ]]
pattern:[[ LIT {a} 256U/ --> HI-BYTE ]]

;; U/
;; division by zero returns zero. oops.
pattern:[[ LIT {b} {? 0 = ?}   U/ --> DROP LIT {[ 0  tcom:ir:opt:(.div0-warning) ]} ]]
pattern:[[ LIT {a} LIT {b}     U/ --> LIT {[ a lo-word b lo-word u/ ]} ]]
pattern:[[ LIT {b} {?   1 = ?} U/ --> ]]
pattern:[[ LIT {b} {?   2 = ?} U/ -->   2U/ ]]
pattern:[[ LIT {b} {?   4 = ?} U/ -->   4U/ ]]
pattern:[[ LIT {b} {?   8 = ?} U/ -->   8U/ ]]
pattern:[[ LIT {b} {?  16 = ?} U/ -->  16U/ ]]
pattern:[[ LIT {b} {?  32 = ?} U/ -->  32U/ ]]
pattern:[[ LIT {b} {?  64 = ?} U/ -->  64U/ ]]
pattern:[[ LIT {b} {? 128 = ?} U/ --> 128U/ ]]
pattern:[[ LIT {b} {? 256 = ?} U/ --> HI-BYTE ]]
pattern:[[ LIT {b} {?  10 = ?} U/ --> 10U/MOD DROP ]]

;; /
;; division by zero returns zero. oops.
pattern:[[ LIT {b} {? 0 = ?}   / --> DROP LIT {[ 0  tcom:ir:opt:(.div0-warning) ]} ]]
pattern:[[ LIT {a} LIT {b}     / --> LIT {[ a b / ]} ]]
pattern:[[ LIT {b} {?  -1 = ?} / --> NEGATE ]]
pattern:[[ LIT {b} {?   1 = ?} / --> ]]
pattern:[[ LIT {b} {?   2 = ?} / -->   2/ ]]
pattern:[[ LIT {b} {?   4 = ?} / -->   4/ ]]
pattern:[[ LIT {b} {?   8 = ?} / -->   8/ ]]
pattern:[[ LIT {b} {?  16 = ?} / -->  16/ ]]
pattern:[[ LIT {b} {?  32 = ?} / -->  32/ ]]
pattern:[[ LIT {b} {?  64 = ?} / -->  64/ ]]
pattern:[[ LIT {b} {? 128 = ?} / --> 128/ ]]
pattern:[[ LIT {b} {? 256 = ?} / --> 256/ ]]

;; UMOD
pattern:[[ LIT {b} {? 0 = ?}                      UMOD --> DROP LIT {[ 0  tcom:ir:opt:(.div0-warning) ]} ]]
pattern:[[ LIT {a} LIT {b}                        UMOD --> LIT {[ a lo-word b lo-word umod ]} ]]
pattern:[[ LIT {b} {? 1 = ?}                      UMOD --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {? tcom:ir:opt:(is-pot-16?) ?} UMOD --> LIT {[ b 1 - ]} AND ]]
pattern:[[ LIT {b} {? 10 = ?}                     UMOD --> 10U/MOD NIP ]]

;; MOD
pattern:[[ LIT {b} {? 0 = ?}                      MOD --> DROP LIT {[ 0  tcom:ir:opt:(.div0-warning) ]} ]]
pattern:[[ LIT {a} LIT {b}                        MOD --> LIT {[ a b mod ]} ]]
pattern:[[ LIT {b} {? 1 = ?}                      MOD --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {? tcom:ir:opt:(is-pot-15?) ?} MOD --> LIT {[ b 1 - ]} AND ]]

;; UU/MOD ( ua ub -- ua/ub ua%ub )
pattern:[[ LIT {b} {? 0 = ?}  UU/MOD --> DROP LIT {[ 0 ]} LIT {[ 0  tcom:ir:opt:(.div0-warning) ]} ]]
pattern:[[ LIT {a} LIT {b}    UU/MOD --> LIT {[ a lo-word b lo-word u/mod drop ]} LIT {[ a lo-word b lo-word u/mod nip ]} ]]
pattern:[[ LIT {b} {? 1 = ?}  UU/MOD --> LIT {[ 0 ]} ]]
pattern:[[ LIT {b} {? 10 = ?} UU/MOD --> 10U/MOD ]]
\ primitive: 10U/MOD  ( u -- quot rem )

;; U/MOD ( ua ub -- ua%ub ua/ub )
pattern:[[ LIT {b} {? 0 = ?}  U/MOD --> DROP LIT {[ 0 ]} LIT {[ 0  tcom:ir:opt:(.div0-warning) ]} ]]
pattern:[[ LIT {a} LIT {b}    U/MOD --> LIT {[ a lo-word b lo-word u/mod nip ]} LIT {[ a lo-word b lo-word u/mod drop ]} ]]
pattern:[[ LIT {b} {? 1 = ?}  U/MOD --> LIT {[ 0 ]} SWAP ]]
pattern:[[ LIT {b} {? 10 = ?} U/MOD --> 10U/MOD SWAP ]]

;; /MOD ( a b -- a%b a/b )
pattern:[[ LIT {b} {? 0 = ?} /MOD --> DROP LIT {[ 0 ]} LIT {[ 0  tcom:ir:opt:(.div0-warning) ]} ]]
pattern:[[ LIT {a} LIT {b}   /MOD --> LIT {[ a b /mod nip ]} LIT {[ a b /mod drop ]} ]]
pattern:[[ LIT {b} {? 1 = ?} /MOD --> LIT {[ 0 ]} SWAP ]]

;; /MOD-REV ( a b -- a/b a%b )
pattern:[[ LIT {b} {? 0 = ?} /MOD-REV --> DROP LIT {[ 0 ]} LIT {[ 0  tcom:ir:opt:(.div0-warning) ]} ]]
pattern:[[ LIT {a} LIT {b}   /MOD-REV --> LIT {[ a b /mod drop ]} LIT {[ a b /mod nip ]} ]]
pattern:[[ LIT {b} {? 1 = ?} /MOD-REV --> LIT {[ 0 ]} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; + and - optimisers

;; +
pattern:[[ SWAP              + --> + ]] -- as addition is commutative, we can do this
pattern:[[ LIT {a} LIT {b}   + --> LIT {[ a b + ]} ]]
pattern:[[ LIT {b} {? 0 = ?} + --> ]]
pattern:[[ LIT {b} DUP       + --> LIT {[ b 2* ]} ]]
pattern:[[ LIT {b}           + --> LIT:+ {b} ]]
pattern:[[ DUP               + --> 2* ]]

;; -
pattern:[[ DUP               - --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {a} LIT {b}   - --> LIT {[ a b - ]} ]]
pattern:[[ LIT {b} {? 0 = ?} - --> ]]
pattern:[[ LIT {b}           - --> LIT:+ {[ b negate ]} ]]
pattern:[[ SWAP              - --> SWAP- ]]


;; SWAP-
pattern:[[ DUP               SWAP- --> DROP LIT {[ 0 ]} ]]
pattern:[[ LIT {a} LIT {b}   SWAP- --> LIT {[ b a - ]} ]]
pattern:[[ LIT {b} {? 0 = ?} SWAP- --> NEGATE ]]
pattern:[[ LIT {b}           SWAP- --> LIT:SWAP- {b} ]]
pattern:[[ SWAP              SWAP- --> - ]]


;; UNDER+
pattern:[[ LIT {a} {? 0 = ?} UNDER+ --> ]]
pattern:[[ LIT {a}           UNDER+ --> LIT:UNDER+ {a} ]]


;; UNDER-
pattern:[[ LIT {a} {? 0 = ?} UNDER- --> ]]
pattern:[[ LIT {a}           UNDER- --> LIT:UNDER+ {[ a negate ]} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; shift optimisers

;; SHL
pattern:[[ LIT {c} {? 15 and 0 = ?} SHL --> ]]
pattern:[[ LIT {c} {? 15 and 1 = ?} SHL -->  2* ]]
pattern:[[ LIT {c} {? 15 and 2 = ?} SHL -->  4* ]]
pattern:[[ LIT {c} {? 15 and 3 = ?} SHL -->  8* ]]
pattern:[[ LIT {c} {? 15 and 4 = ?} SHL -->  16* ]]
pattern:[[ LIT {c} {? 15 and 5 = ?} SHL -->  32* ]]
pattern:[[ LIT {c} {? 15 and 6 = ?} SHL -->  64* ]]
pattern:[[ LIT {c} {? 15 and 7 = ?} SHL --> 128* ]]
pattern:[[ LIT {c} {? 15 and 8 = ?} SHL --> 256* ]]
pattern:[[ LIT {n} LIT {c}          SHL --> LIT {[ n c 15 and lshift ]} ]]

;; SHR
pattern:[[ LIT {c} {? 15 and  0 = ?} SHR --> ]]
pattern:[[ LIT {c} {? 15 and  1 = ?} SHR -->  2U/ ]]
pattern:[[ LIT {c} {? 15 and  2 = ?} SHR -->  4U/ ]]
pattern:[[ LIT {c} {? 15 and  3 = ?} SHR -->  8U/ ]]
pattern:[[ LIT {c} {? 15 and  4 = ?} SHR -->  16U/ ]]
pattern:[[ LIT {c} {? 15 and  5 = ?} SHR -->  32U/ ]]
pattern:[[ LIT {c} {? 15 and  6 = ?} SHR -->  64U/ ]]
pattern:[[ LIT {c} {? 15 and  7 = ?} SHR --> 128U/ ]]
pattern:[[ LIT {c} {? 15 and  8 = ?} SHR --> HI-BYTE ]]
pattern:[[ LIT {c} {? 15 and  9 = ?} SHR --> HI-BYTE   2U/ ]]
pattern:[[ LIT {c} {? 15 and 10 = ?} SHR --> HI-BYTE   4U/ ]]
pattern:[[ LIT {c} {? 15 and 11 = ?} SHR --> HI-BYTE   8U/ ]]
pattern:[[ LIT {c} {? 15 and 12 = ?} SHR --> HI-BYTE  16U/ ]]
pattern:[[ LIT {c} {? 15 and 13 = ?} SHR --> HI-BYTE  32U/ ]]
pattern:[[ LIT {c} {? 15 and 14 = ?} SHR --> HI-BYTE  64U/ ]]
pattern:[[ LIT {c} {? 15 and 15 = ?} SHR --> HI-BYTE 128U/ ]]
pattern:[[ LIT {n} LIT {c}           SHR --> LIT {[ n c 15 and rshift ]} ]]

;; SAR
pattern:[[ LIT {c} {? 15 and 0 = ?} SAR --> ]]
pattern:[[ LIT {c} {? 15 and 1 = ?} SAR -->  2/ ]]
pattern:[[ LIT {c} {? 15 and 2 = ?} SAR -->  4/ ]]
pattern:[[ LIT {c} {? 15 and 3 = ?} SAR -->  8/ ]]
pattern:[[ LIT {c} {? 15 and 4 = ?} SAR -->  16/ ]]
pattern:[[ LIT {c} {? 15 and 5 = ?} SAR -->  32/ ]]
pattern:[[ LIT {c} {? 15 and 6 = ?} SAR -->  64/ ]]
pattern:[[ LIT {c} {? 15 and 7 = ?} SAR --> 128/ ]]
pattern:[[ LIT {c} {? 15 and 8 = ?} SAR --> 256/ ]]
pattern:[[ LIT {n} LIT {c}          SAR --> LIT {[ n c 15 and arshift ]} ]]

;; ROL
pattern:[[ LIT {c} {? 15 and 0 = ?} ROL --> ]]
pattern:[[ LIT {n} LIT {c}          ROL --> LIT {[ n c 15 and rol16 ]} ]]
pattern:[[ LIT {c} {? 15 and 8 = ?} ROL --> BSWAP ]]

;; ROR
pattern:[[ LIT {c} {? 15 and 0 = ?} ROR --> ]]
pattern:[[ LIT {n} LIT {c}          ROR --> LIT {[ n c 15 and ror16 ]} ]]
pattern:[[ LIT {c} {? 15 and 8 = ?} ROR --> BSWAP ]]

;; ROL8
pattern:[[ LIT {c} {? 7 and 0 = ?} ROL8 --> ]]
pattern:[[ LIT {n} LIT {c}         ROL8 --> LIT {[ n c 7 and rol8 ]} ]]

;; ROR8
pattern:[[ LIT {c} {? 7 and 0 = ?} ROR8 --> ]]
pattern:[[ LIT {n} LIT {c}         ROR8 --> LIT {[ n c 7 and ror8 ]} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MIN/MAX optimisers

;; MAX
pattern:[[ LIT {a} LIT {b}   MAX --> LIT {[ a b max ]} ]]
pattern:[[ LIT {b} {? 0 = ?} MAX --> 0MAX ]]
pattern:[[ LIT {b} {? 1 = ?} MAX --> 1MAX ]]

;; MIN
pattern:[[ LIT {a} LIT {b} MIN --> LIT {[ a b min ]} ]]
;; if the previous node is byte, the result is known
pattern:[[ LIT {b} {? 0 <= ?} MIN {: tcom:ir:opt:(prev-node-byte?) :} --> LIT {b} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; comparison optimisers
;; note that ZX `TRUE` is `1`

;; 0=
pattern:[[ LIT {a} 0= --> LIT {[ a 0 = ?< 1 || 0 >? ]} ]]
;; invert conditions
pattern:[[ 0=  0= --> 0<> ]]
pattern:[[ 0<> 0= --> 0= ]]
pattern:[[ 0<  0= --> 0>= ]]
pattern:[[ 0>  0= --> 0<= ]]
pattern:[[ 0<= 0= --> 0> ]]
pattern:[[ 0>= 0= --> 0< ]]
pattern:[[ =   0= --> <> ]]
pattern:[[ <>  0= --> = ]]
pattern:[[ <   0= --> >= ]]
pattern:[[ >   0= --> <= ]]
pattern:[[ <=  0= --> > ]]
pattern:[[ >=  0= --> < ]]
pattern:[[ U<  0= --> U>= ]]
pattern:[[ U>  0= --> U<= ]]
pattern:[[ U<= 0= --> U> ]]
pattern:[[ U>= 0= --> U< ]]


;; 0<>
pattern:[[ LIT {a} 0<> --> LIT {[ a 0 <> ?< 1 || 0 >? ]} ]]
;; if previous is any boolean, we can drop this one (general check)
pattern:[[         0<> {: tcom:ir:opt:(prev-node-bool?) :} --> ]]
;; if previous is any boolean, we can drop this one
(* they are all marked as returning boolean now
pattern:[[ 0=               0<> --> 0= ]]
pattern:[[ 0<>              0<> --> 0<> ]]
pattern:[[ 0<               0<> --> 0< ]]
pattern:[[ 0>               0<> --> 0> ]]
pattern:[[ 0<=              0<> --> 0<= ]]
pattern:[[ 0>=              0<> --> 0>= ]]
pattern:[[ =                0<> --> = ]]
pattern:[[ <>               0<> --> <> ]]
pattern:[[ <                0<> --> < ]]
pattern:[[ >                0<> --> > ]]
pattern:[[ <=               0<> --> <= ]]
pattern:[[ >=               0<> --> >= ]]
pattern:[[ U<               0<> --> U< ]]
pattern:[[ U>               0<> --> U> ]]
pattern:[[ U<=              0<> --> U<= ]]
pattern:[[ U>=              0<> --> U>= ]]
pattern:[[ BIT8?            0<> --> BIT8? ]]
pattern:[[ BIT?             0<> --> BIT? ]]
pattern:[[ MASK8?           0<> --> MASK8? ]]
pattern:[[ MASK?            0<> --> MASK? ]]
pattern:[[ MASK8:LIT {a}    0<> --> MASK8:LIT {a} ]]
pattern:[[ MASK8-HI:LIT {a} 0<> --> MASK8-HI:LIT {a} ]]
pattern:[[ MASK:LIT {a}     0<> --> MASK:LIT {a} ]]
*)
pattern:[[ AND              0<> --> MASK? ]]
pattern:[[ AND8             0<> --> MASK8? ]]
;; convert to non-lit versions, so the optimiser could optimise them further
pattern:[[ AND:LIT {a}      0<> --> LIT {a} MASK? ]]
pattern:[[ AND8:LIT {a}     0<> --> LIT {[ a lo-byte ]} MASK8? ]]
pattern:[[ AND8-HI:LIT {a}  0<> --> LIT {[ a lo-byte 256 * ]} MASK? ]]
pattern:[[ ~AND8:LIT {a}    0<> --> LIT {[ a -1 xor lo-byte ]} MASK8? ]]
pattern:[[ ~AND8-HI:LIT {a} 0<> --> LIT {[ a -1 xor lo-byte 256 * ]} MASK? ]]


;; 0<
pattern:[[ LIT {a}       0< --> LIT {[ a 0 < ?< 1 || 0 >? ]} ]]
(*
;; prev is 1-op bool, so this cannot be true; replace with `false`
pattern:[[ 0=            0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ 0<>           0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ 0<            0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ 0>            0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ 0<=           0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ 0>=           0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ MASK8:LIT {a} 0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ MASK:LIT {a}  0< --> DROP LIT {[ 0 ]} ]]
*)
;; prev is 2-op bool, so this cannot be true; replace with `false`
pattern:[[ =             0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ <>            0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ <             0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ >             0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ <=            0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ >=            0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ U<            0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ U>            0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ U<=           0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ U>=           0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ BIT8?         0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ BIT?          0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ MASK8?        0< --> 2DROP LIT {[ 0 ]} ]]
pattern:[[ MASK?         0< --> 2DROP LIT {[ 0 ]} ]]
;; is previous is any byte (including boolean)? (general check)
pattern:[[               0< {: tcom:ir:opt:(prev-node-byte?) :} --> DROP LIT {[ 0 ]} ]]
;; more known results.
;; note that ABS is not fit, due to $8000.
pattern:[[ OR:LIT {a} {? lo-word $8000 and ?}      0< --> DROP LIT {[ 1 ]} ]]
pattern:[[ OR8-HI:LIT {a} {? lo-byte $80 and ?}    0< --> DROP LIT {[ 1 ]} ]]
pattern:[[ AND8                                    0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ AND:LIT {a} {? lo-word $8000 and 0 = ?} 0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ AND8:LIT {a}                            0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ SET-BIT:LIT {a} {? 15 = ?}              0< --> DROP LIT {[ 1 ]} ]]
pattern:[[ RES-BIT:LIT {a} {? 15 = ?}              0< --> DROP LIT {[ 0 ]} ]]
pattern:[[   2U/                                   0< --> DROP LIT {[ 0 ]} ]]
pattern:[[   4U/                                   0< --> DROP LIT {[ 0 ]} ]]
pattern:[[   8U/                                   0< --> DROP LIT {[ 0 ]} ]]
pattern:[[  16U/                                   0< --> DROP LIT {[ 0 ]} ]]
pattern:[[  32U/                                   0< --> DROP LIT {[ 0 ]} ]]
pattern:[[  64U/                                   0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ 128U/                                   0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ LO-BYTE                                 0< --> DROP LIT {[ 0 ]} ]]
pattern:[[ HI-BYTE                                 0< --> DROP LIT {[ 0 ]} ]]


;; 0>
pattern:[[ LIT {a}       0> --> LIT {[ a 0 > ?< 1 || 0 >? ]} ]]
;; is previous is any byte (including boolean)? (general check)
;; byte is never negative, and "0<>" is faster
pattern:[[               0> {: tcom:ir:opt:(prev-node-byte?) :} --> 0<> ]]
(* they are all marked as returning boolean now
;; prev is 1-op bool, so this can be dropped
pattern:[[ 0=            0> --> 0= ]]
pattern:[[ 0<>           0> --> 0<> ]]
pattern:[[ 0<            0> --> 0< ]]
pattern:[[ 0>            0> --> 0> ]]
pattern:[[ 0<=           0> --> 0<= ]]
pattern:[[ 0>=           0> --> 0>= ]]
;; prev is 2-op bool, so this can be dropped
pattern:[[ =             0> --> = ]]
pattern:[[ <>            0> --> <> ]]
pattern:[[ <             0> --> < ]]
pattern:[[ >             0> --> > ]]
pattern:[[ <=            0> --> <= ]]
pattern:[[ >=            0> --> >= ]]
pattern:[[ U<            0> --> U< ]]
pattern:[[ U>            0> --> U> ]]
pattern:[[ U<=           0> --> U<= ]]
pattern:[[ U>=           0> --> U>= ]]
pattern:[[ BIT8?         0> --> BIT8? ]]
pattern:[[ BIT?          0> --> BIT? ]]
pattern:[[ MASK8?        0> --> MASK8? ]]
pattern:[[ MASK?         0> --> MASK? ]]
pattern:[[ MASK8:LIT {a} 0> --> MASK8:LIT {a} ]]
pattern:[[ MASK:LIT {a}  0> --> MASK:LIT {a} ]]
*)
;; more known results
pattern:[[ OR:LIT {a} {? lo-word 1 $8000 within ?}   0> --> DROP LIT {[ 1 ]} ]]
pattern:[[ OR8-HI:LIT {a} {? lo-byte 1 $80 within ?} 0> --> DROP LIT {[ 1 ]} ]]


;; 0<=
pattern:[[ LIT {a}       0<= --> LIT {[ a 0 <= ?< 1 || 0 >? ]} ]]
;; invert conditions
pattern:[[ 0=            0<= --> 0<> ]]
pattern:[[ 0<>           0<= --> 0= ]]
pattern:[[ 0<            0<= --> 0>= ]]
pattern:[[ 0>            0<= --> 0<= ]]
pattern:[[ 0<=           0<= --> 0> ]]
pattern:[[ 0>=           0<= --> 0< ]]
pattern:[[ =             0<= --> <> ]]
pattern:[[ <>            0<= --> = ]]
pattern:[[ <             0<= --> >= ]]
pattern:[[ >             0<= --> <= ]]
pattern:[[ <=            0<= --> > ]]
pattern:[[ >=            0<= --> < ]]
pattern:[[ U<            0<= --> U>= ]]
pattern:[[ U>            0<= --> U<= ]]
pattern:[[ U<=           0<= --> U> ]]
pattern:[[ U>=           0<= --> U< ]]
(* they are marked as booleans
pattern:[[ BIT8?         0<= --> BIT8? 0= ]]
pattern:[[ BIT?          0<= --> BIT? 0= ]]
pattern:[[ MASK8?        0<= --> MASK8? 0= ]]
pattern:[[ MASK?         0<= --> MASK? 0= ]]
pattern:[[ MASK8:LIT {a} 0<= --> MASK8:LIT {a} 0= ]]
pattern:[[ MASK:LIT {a}  0<= --> MASK:LIT {a} 0= ]]
*)
;; is previous is any byte (including boolean)? (general check)
;; byte is never negative, and "0=" is faster
pattern:[[               0<= {: tcom:ir:opt:(prev-node-byte?) :} --> 0= ]]


;; 0>=
pattern:[[ LIT {a}       0>= --> LIT {[ a 0 >= ?< 1 || 0 >? ]} ]]
;; prev is 1-op bool, so this cannot be false; replace with `true`
pattern:[[ 0=            0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ 0<>           0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ 0<            0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ 0>            0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ 0<=           0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ 0>=           0>= --> DROP LIT {[ 1 ]} ]]
;; prev is 2-op bool, so this cannot be false; replace with `true`
pattern:[[ =             0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ <>            0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ <             0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ >             0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ <=            0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ >=            0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ U<            0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ U>            0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ U<=           0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ U>=           0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ BIT8?         0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ BIT?          0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ MASK8?        0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ MASK?         0>= --> 2DROP LIT {[ 1 ]} ]]
pattern:[[ MASK8:LIT {a} 0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ MASK:LIT {a}  0>= --> DROP LIT {[ 1 ]} ]]
;; more known results.
;; note that ABS is not fit, due to $8000.
pattern:[[ OR:LIT {a} {? lo-word $8000 and ?}      0>= --> DROP LIT {[ 0 ]} ]]
pattern:[[ OR8-HI:LIT {a} {? lo-byte $80 and ?}    0>= --> DROP LIT {[ 0 ]} ]]
pattern:[[ AND8                                    0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ AND:LIT {a} {? lo-word $8000 and 0 = ?} 0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ AND8:LIT {a}                            0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ SET-BIT:LIT {a} {? 15 = ?}              0>= --> DROP LIT {[ 0 ]} ]]
pattern:[[ RES-BIT:LIT {a} {? 15 = ?}              0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[   2U/                                   0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[   4U/                                   0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[   8U/                                   0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[  16U/                                   0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[  32U/                                   0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[  64U/                                   0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ 128U/                                   0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ LO-BYTE                                 0>= --> DROP LIT {[ 1 ]} ]]
pattern:[[ HI-BYTE                                 0>= --> DROP LIT {[ 1 ]} ]]
;; if previous is any byte (including boolean), this is always true
pattern:[[ 0>= {: tcom:ir:opt:(prev-node-byte?) :} --> DROP LIT {[ 1 ]} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; cmp optimisers

pattern:[[ LIT {a} LIT {b}  = --> LIT {[ a b = ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {a} LIT {b} <> --> LIT {[ a b <> ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {a} LIT {b}  < --> LIT {[ a b < ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {a} LIT {b}  > --> LIT {[ a b > ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {a} LIT {b} <= --> LIT {[ a b <= ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {a} LIT {b} >= --> LIT {[ a b >= ?< 1 || 0 >? ]} ]]

pattern:[[ LIT {a} {? 0 = ?}  = --> 0= ]]
pattern:[[ LIT {a} {? 0 = ?} <> --> 0<> ]]
pattern:[[ LIT {a} {? 0 = ?}  < --> 0< ]]
pattern:[[ LIT {a} {? 0 = ?}  > --> 0> ]]
pattern:[[ LIT {a} {? 0 = ?} <= --> 0<= ]]
pattern:[[ LIT {a} {? 0 = ?} >= --> 0>= ]]


;; U<
pattern:[[ LIT {a} LIT {b}              U< --> LIT {[ a lo-word b lo-word u< ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {a} {? 0 = ?}            U< --> LIT {[ 0 ]} ]]
pattern:[[ LIT {a} {? 1 = ?}            U< --> 0= ]]
;; if previous is any boolean, we can drop some comparisons
;; boolean is always "0" or "1", so "2 U<" and more is always true
pattern:[[ LIT {a} {? lo-word 2 >= ?}   U< {: tcom:ir:opt:(prev-node-bool?) :} --> DROP LIT {[ 1 ]} ]]
;; if previous is any byte, we can drop some comparisons
;; "256 U<" and more is always true
pattern:[[ LIT {a} {? lo-word 256 >= ?} U< {: tcom:ir:opt:(prev-node-byte?) :} --> DROP LIT {[ 1 ]} ]]


;; U>
pattern:[[ LIT {a} LIT {b}              U> --> LIT {[ a lo-word b lo-word u> ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {a} {? 0 = ?}            U> --> 0<> ]]
;; if previous is any boolean, we can drop some comparisons
;; boolean is always "0" or "1", so "1 U>" and more is always false
pattern:[[ LIT {a} {? lo-word 1 >= ?}   U> {: tcom:ir:opt:(prev-node-bool?) :} --> DROP LIT {[ 0 ]} ]]
;; if previous is any byte, we can drop some comparisons
;; "255 U>" and more is always false
pattern:[[ LIT {a} {? lo-word 255 >= ?} U> {: tcom:ir:opt:(prev-node-byte?) :} --> DROP LIT {[ 0 ]} ]]


;; U<=
pattern:[[ LIT {a} LIT {b}              U<= --> LIT {[ a lo-word b lo-word u<= ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {a} {? 0 = ?}            U<= --> 0= ]]
;; if previous is any boolean, we can drop some comparisons
;; boolean is always "0" or "1", so "1 U<=" and more is always true
pattern:[[ LIT {a} {? lo-word 1 >= ?}   U<= {: tcom:ir:opt:(prev-node-bool?) :} --> DROP LIT {[ 1 ]} ]]
;; if previous is any byte, we can drop some comparisons
;; "255 U<=" and more is always true
pattern:[[ LIT {a} {? lo-word 255 >= ?} U<= {: tcom:ir:opt:(prev-node-byte?) :} --> DROP LIT {[ 1 ]} ]]


;; U>=
pattern:[[ LIT {a} LIT {b}              U>= --> LIT {[ a lo-word b lo-word u>= ?< 1 || 0 >? ]} ]]
pattern:[[ LIT {a} {? 0 = ?}            U>= --> LIT {[ 1 ]} ]]
;; if previous is any boolean, we can drop some comparisons
;; boolean is always "0" or "1", so "2 U>=" and more is always false
pattern:[[ LIT {a} {? lo-word 2 >= ?}   U>= {: tcom:ir:opt:(prev-node-bool?) :} --> DROP LIT {[ 0 ]} ]]
;; if previous is any byte, we can drop some comparisons
;; "256 U>=" and more is always false
pattern:[[ LIT {a} {? lo-word 256 >= ?} U>= {: tcom:ir:opt:(prev-node-byte?) :} --> DROP LIT {[ 0 ]} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DROP optimisers

;; special case for LIT
: (opt-next-node-LIT?)  ( -- bool )
  next-node node-lit? ?< drop true || false >? ;

;; (DROP<n>) special case
;; always leave DROP before LIT, for peephole optimiser.
;; do not use special "DROP:LIT" primitive, as it adds more cases to patterns.
;; sorry for this hack.
pattern:[[ (DROP<n>) {n} {? 2 = ?} {: tcom:ir:opt:(opt-next-node-LIT?) :} --> DROP DROP ]]
pattern:[[ (DROP<n>) {n} {? 2 > ?} {: tcom:ir:opt:(opt-next-node-LIT?) :} --> (DROP<n>) {[ n 1 - ]} DROP ]]


;; DROP
pattern:[[ UU/MOD        DROP --> U/ ]]
pattern:[[ UU/MOD SWAP   DROP --> UMOD ]]
pattern:[[ U/MOD         DROP --> UMOD ]]
pattern:[[ U/MOD SWAP    DROP --> U/ ]]
pattern:[[ /MOD          DROP --> MOD ]]
pattern:[[ /MOD SWAP     DROP --> / ]]
pattern:[[ /MOD-REV      DROP --> / ]]
pattern:[[ /MOD-REV SWAP DROP --> MOD ]]
pattern:[[ SWAP          DROP --> NIP ]]
pattern:[[ R>            DROP --> RDROP ]]
pattern:[[ LIT           DROP --> ]]
pattern:[[ DUP           DROP --> ]]
pattern:[[ OVER          DROP --> ]]
pattern:[[ R0:@          DROP --> ]]
pattern:[[ R1:@          DROP --> ]]
pattern:[[ R2:@          DROP --> ]]
pattern:[[ R3:@          DROP --> ]]
pattern:[[ PICK          DROP --> DROP ]]
pattern:[[ RPICK         DROP --> DROP ]]
;; DROP specials (for LIT)
pattern:[[ DROP          DROP {: tcom:ir:opt:(opt-next-node-LIT?) not :} --> (DROP<n>) {[ 2 ]} ]]
pattern:[[ (DROP<n>) {n} DROP {: tcom:ir:opt:(opt-next-node-LIT?) not :} --> (DROP<n>) {[ n 1 + ]} ]]

;; nDROP
pattern:[[ 2DROP --> (DROP<n>) {[ 2 ]} ]]
pattern:[[ 3DROP --> (DROP<n>) {[ 3 ]} ]]
pattern:[[ 4DROP --> (DROP<n>) {[ 4 ]} ]]


;; (DROP<n>)
pattern:[[ (DROP<n>) {n1} (DROP<n>) {n2} --> (DROP<n>) {[ n1 n2 + ]} ]]

pattern:[[      (DROP<n>) {n} {? 0 = ?} --> ]]
pattern:[[ LIT  (DROP<n>) {n}           --> (DROP<n>) {[ n 1 + ]} ]]
pattern:[[ DUP  (DROP<n>) {n} {? 1 = ?} --> ]]
pattern:[[ DUP  (DROP<n>) {n} {? 2 = ?} --> DROP ]]
pattern:[[ DUP  (DROP<n>) {n} {? 2 > ?} --> (DROP<n>) {[ n 1 - ]} ]]
pattern:[[      (DROP<n>) {n} {? 1 = ?} --> DROP ]] -- this should be here!
pattern:[[ DROP (DROP<n>) {n}           --> (DROP<n>) {[ n 1 + ]} ]]

pattern:[[ R> R>       (DROP<n>) {n} {? 2 = ?} --> (RDROP<n>) {[ 2 ]} ]]
pattern:[[ R> R>       (DROP<n>) {n} {? 3 = ?} --> (RDROP<n>) {[ 2 ]} DROP ]]
pattern:[[ R> R>       (DROP<n>) {n} {? 3 > ?} --> (RDROP<n>) {[ 2 ]} (DROP<n>) {[ n 2 - ]} ]]

pattern:[[ R> R> R>    (DROP<n>) {n} {? 3 = ?} --> (RDROP<n>) {[ 3 ]} ]]
pattern:[[ R> R> R>    (DROP<n>) {n} {? 4 = ?} --> (RDROP<n>) {[ 3 ]} DROP ]]
pattern:[[ R> R> R>    (DROP<n>) {n} {? 4 > ?} --> (RDROP<n>) {[ 3 ]} (DROP<n>) {[ n 3 - ]} ]]

pattern:[[ R> R> R> R> (DROP<n>) {n} {? 4 = ?} --> (RDROP<n>) {[ 4 ]} ]]
pattern:[[ R> R> R> R> (DROP<n>) {n} {? 5 = ?} --> (RDROP<n>) {[ 4 ]} DROP ]]
pattern:[[ R> R> R> R> (DROP<n>) {n} {? 5 > ?} --> (RDROP<n>) {[ 4 ]} (DROP<n>) {[ n 4 - ]} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RDROP optimisers

;; RDROP specials
pattern:[[ RDROP          RDROP --> (RDROP<n>) {[ 2 ]} ]]
pattern:[[ (RDROP<n>) {n} RDROP --> (RDROP<n>) {[ n 1 + ]} ]]

;; (RDROP<n>)
pattern:[[ (RDROP<n>) {n1} (RDROP<n>) {n2} --> (RDROP<n>) {[ n1 n2 + ]} ]]

pattern:[[       (RDROP<n>) {n} {? 0 = ?} --> ]]
pattern:[[       (RDROP<n>) {n} {? 1 = ?} --> RDROP ]]
pattern:[[ RDROP (RDROP<n>) {n}           --> (RDROP<n>) {[ n 1 + ]} ]]

;; nRDROP
pattern:[[ 2RDROP --> (RDROP<n>) {[ 2 ]} ]]
pattern:[[ 3RDROP --> (RDROP<n>) {[ 3 ]} ]]
pattern:[[ 4RDROP --> (RDROP<n>) {[ 4 ]} ]]

: (.n-rdrop-warning)  ( n )
  endcr ." WARNING: invalid \' " . ." N-RDROP\' in '"
  curr-word-snfa idcount type ." '?\n" ;

;; N-RDROP
pattern:[[ LIT {a} {? 0 < ?} N-RDROP --> (RDROP<n>) {[ a dup tcom:ir:opt:(.n-rdrop-warning) ]} ]]
pattern:[[ LIT {a} {? 0 = ?} N-RDROP --> ]]
pattern:[[ LIT {a} {? 1 = ?} N-RDROP --> RDROP ]]
pattern:[[ LIT {a} {? 1 > ?} N-RDROP --> (RDROP<n>) {a} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RPICK/RTOSS optimisers

;; RPICK
pattern:[[ LIT {a} {? 0 = ?} RPICK --> R0:@ ]]
pattern:[[ LIT {a} {? 1 = ?} RPICK --> R1:@ ]]
pattern:[[ LIT {a} {? 2 = ?} RPICK --> R2:@ ]]
pattern:[[ LIT {a} {? 3 = ?} RPICK --> R3:@ ]]

;; RTOSS
pattern:[[ LIT {a} {? 0 = ?} RTOSS --> R0:! ]]
pattern:[[ LIT {a} {? 1 = ?} RTOSS --> R1:! ]]
pattern:[[ LIT {a} {? 2 = ?} RTOSS --> R2:! ]]
pattern:[[ LIT {a} {? 3 = ?} RTOSS --> R3:! ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; stack shufflint optimisers

;; SWAP
pattern:[[ SWAP            SWAP --> ]]
pattern:[[ OVER            SWAP --> UNDER ]]
pattern:[[ UU/MOD          SWAP --> U/MOD ]]
pattern:[[ U/MOD           SWAP --> UU/MOD ]]
pattern:[[ /MOD            SWAP --> /MOD-REV ]]
pattern:[[ /MOD-REV        SWAP --> /MOD ]]
pattern:[[ LIT:@-HI-LO {a} SWAP --> LIT:@-LO-HI {a} ]]
pattern:[[ LIT:@-LO-HI {a} SWAP --> LIT:@-HI-LO {a} ]]
pattern:[[ SWAP LIT:+ {a}  SWAP --> LIT:UNDER+ {a} ]]
pattern:[[ C@++            SWAP --> C@++/SWAP ]]

;; OVER
pattern:[[ SWAP OVER --> TUCK ]]
pattern:[[ OVER OVER --> 2DUP ]]
pattern:[[ OVER DROP --> 2DUP ]]

;; ROT
pattern:[[ NROT    ROT --> ]]
pattern:[[ ROT ROT ROT --> ]]
pattern:[[ ROT     ROT --> NROT ]]

;; NROT
pattern:[[ ROT       NROT --> ]]
pattern:[[ NROT NROT NROT --> ]]
pattern:[[ NROT      NROT --> ROT ]]
pattern:[[ DUP       NROT --> TUCK ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CMOVE optimisers

;; CMOVE
pattern:[[ LIT {c} {? 0 = ?} CMOVE --> 3DROP ]]
pattern:[[ LIT {c}           CMOVE --> CMOVE:LIT {c} ]]

;; CMOVE-NC
pattern:[[ LIT {c} CMOVE-NC --> CMOVE:LIT {c} ]]

;; CMOVE:LIT
pattern:[[ LIT {a} CMOVE:LIT {c} --> CMOVE:LIT:LIT {c} {a} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FILL optimisers

;; FILL
pattern:[[ LIT {v} FILL --> FILL:LIT {v} ]]

;; FILL:LIT
pattern:[[ LIT {c} {? 0 = ?} FILL:LIT {v} --> DROP ]]
pattern:[[ LIT {c}           FILL:LIT {v} --> FILL-NC:LIT:LIT {v} {c} ]]

;; FILL-NC:LIT
pattern:[[ LIT {c} FILL-NC:LIT {v} --> FILL-NC:LIT:LIT {v} {c} ]]

;; FILL-NC:LIT:LIT
pattern:[[ LIT {a} FILL-NC:LIT:LIT {v} {c} --> FILL-NC:LIT:LIT:LIT {v} {c} {a} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CFILL optimisers

;; CFILL
\ pattern:[[ LIT {c} {? 0 = ?} LIT {v} CFILL --> 3DROP ]]
pattern:[[ LIT {v} CFILL --> CFILL:LIT {v} ]]

;; CFILL:LIT
pattern:[[ LIT {c} {? 0 = ?} CFILL:LIT {v} --> DROP ]]
pattern:[[ LIT {c}           CFILL:LIT {v} --> CFILL-NC:LIT:LIT {v} {c} ]]

;; CFILL-NC
pattern:[[ LIT {v} CFILL-NC --> CFILL-NC:LIT {v} ]]

;; CFILL-NC:LIT
pattern:[[ LIT {c} CFILL-NC:LIT {v} --> CFILL-NC:LIT:LIT {v} {c} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ERASE optimisers

;; ERASE
pattern:[[ LIT {c} {? 0 = ?} ERASE --> 2DROP ]]
pattern:[[ LIT {c}           ERASE --> ERASE-NC:LIT {c} ]]

;; ERASE-NC
pattern:[[ LIT {c} ERASE-NC --> ERASE-NC:LIT {c} ]]

;; ERASE-NC:LIT
pattern:[[ LIT {a} ERASE-NC:LIT {c} --> ERASE-NC:LIT:LIT {c} {a} ]]

;; CERASE
pattern:[[ LIT {c} {? 0 = ?} CERASE --> 2DROP ]]
pattern:[[ LIT {c}           CERASE --> ERASE-NC:LIT {c} ]]

;; CERASE-NC
pattern:[[ LIT {c} CERASE-NC --> ERASE-NC:LIT {c} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; branch optimisers
;; compare nBRANCH -> cmpBRANCH
;; another optim:
;;   DUP lit cmpBRANCH -> lit cmpBRANCH-ND

;; 0BRANCH : cmp 0BRANCH -> cmpBRANCH
pattern:[[ 0=  0BRANCH {@l} -->   TBRANCH {@l} ]]
pattern:[[ 0<  0BRANCH {@l} -->  +0BRANCH {@l} ]]
pattern:[[ 0>  0BRANCH {@l} -->  -0BRANCH {@l} ]]
pattern:[[ 0<= 0BRANCH {@l} -->   +BRANCH {@l} ]]
pattern:[[ 0>= 0BRANCH {@l} -->   -BRANCH {@l} ]]
pattern:[[ -   0BRANCH {@l} -->   =BRANCH {@l} ]]
pattern:[[ =   0BRANCH {@l} -->  <>BRANCH {@l} ]]
pattern:[[ <>  0BRANCH {@l} -->   =BRANCH {@l} ]]
pattern:[[ <   0BRANCH {@l} -->  >=BRANCH {@l} ]]
pattern:[[ >   0BRANCH {@l} -->  <=BRANCH {@l} ]]
pattern:[[ <=  0BRANCH {@l} -->   >BRANCH {@l} ]]
pattern:[[ >=  0BRANCH {@l} -->   <BRANCH {@l} ]]
pattern:[[ U<  0BRANCH {@l} --> U>=BRANCH {@l} ]]
pattern:[[ U>  0BRANCH {@l} --> U<=BRANCH {@l} ]]
pattern:[[ U<= 0BRANCH {@l} -->  U>BRANCH {@l} ]]
pattern:[[ U>= 0BRANCH {@l} -->  U<BRANCH {@l} ]]
;; 0BRANCH : DUP 0BRANCH -> 0BRANCH-ND
pattern:[[ DUP 0BRANCH {@l} --> 0BRANCH-ND {@l} ]]

pattern:[[ DUP AND8:LIT {n}   0BRANCH {@l} --> AND8/0BRANCH:LIT-ND {@l} {n} ]]
pattern:[[ DUP ~AND8:LIT {n}  0BRANCH {@l} --> ~AND8/0BRANCH:LIT-ND {@l} {n} ]]

pattern:[[ AND8:LIT {n}       0BRANCH {@l} --> AND8/0BRANCH:LIT {@l} {n} ]]
pattern:[[ ~AND8:LIT {n}      0BRANCH {@l} --> ~AND8/0BRANCH:LIT {@l} {n} ]]

;; TBRANCH : cmp TBRANCH -> cmpBRANCH
pattern:[[ 0=  TBRANCH {@l} -->   0BRANCH {@l} ]]
pattern:[[ 0<  TBRANCH {@l} -->   -BRANCH {@l} ]]
pattern:[[ 0>  TBRANCH {@l} -->   +BRANCH {@l} ]]
pattern:[[ 0<= TBRANCH {@l} -->  -0BRANCH {@l} ]]
pattern:[[ 0>= TBRANCH {@l} -->  +0BRANCH {@l} ]]
pattern:[[ -   TBRANCH {@l} -->  <>BRANCH {@l} ]]
pattern:[[ =   TBRANCH {@l} -->   =BRANCH {@l} ]]
pattern:[[ <>  TBRANCH {@l} -->  <>BRANCH {@l} ]]
pattern:[[ <   TBRANCH {@l} -->   <BRANCH {@l} ]]
pattern:[[ >   TBRANCH {@l} -->   >BRANCH {@l} ]]
pattern:[[ <=  TBRANCH {@l} -->  <=BRANCH {@l} ]]
pattern:[[ >=  TBRANCH {@l} -->  >=BRANCH {@l} ]]
pattern:[[ U<  TBRANCH {@l} -->  U<BRANCH {@l} ]]
pattern:[[ U>  TBRANCH {@l} -->  U>BRANCH {@l} ]]
pattern:[[ U<= TBRANCH {@l} --> U<=BRANCH {@l} ]]
pattern:[[ U>= TBRANCH {@l} --> U>=BRANCH {@l} ]]
;; TBRANCH : DUP TBRANCH -> TBRANCH-ND
pattern:[[ DUP TBRANCH {@l} --> TBRANCH-ND {@l} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; more branch optimisers
;; there is no need to check for comparisons for the following branches.
;; this is because no sane person would write the code like that. ;-)

;; -BRANCH : DUP -BRANCH -> -BRANCH-ND
pattern:[[ DUP -BRANCH {@l} --> -BRANCH-ND {@l} ]]

;; +BRANCH : DUP +BRANCH -> +BRANCH-ND
pattern:[[ DUP +BRANCH {@l} --> +BRANCH-ND {@l} ]]

;; +0BRANCH : DUP +0BRANCH -> +0BRANCH-ND
pattern:[[ DUP +0BRANCH {@l} --> +0BRANCH-ND {@l} ]]

;; -0BRANCH : DUP -0BRANCH -> -0BRANCH-ND
pattern:[[ DUP -0BRANCH {@l} --> -0BRANCH-ND {@l} ]]


pattern:[[ 2DUP OR  0BRANCH {@l} --> 2DUP/OR/0BRANCH {@l} ]]
pattern:[[ 2DUP OR  TBRANCH {@l} --> 2DUP/OR/TBRANCH {@l} ]]
pattern:[[ 2DUP OR +0BRANCH {@l} --> 2DUP/OR/+0BRANCH {@l} ]]
pattern:[[ 2DUP OR -BRANCH {@l} --> 2DUP/OR/-BRANCH {@l} ]]

pattern:[[ R>  0BRANCH {@l} --> R>/0BRANCH {@l} ]]
pattern:[[ R>  TBRANCH {@l} --> R>/TBRANCH {@l} ]]
pattern:[[ R> +0BRANCH {@l} --> R>/+0BRANCH {@l} ]]
pattern:[[ R>  -BRANCH {@l} --> R>/-BRANCH {@l} ]]

pattern:[[ LIT:@ {addr}  0BRANCH {@l} --> LIT:@/0BRANCH {@l} {addr} ]]
pattern:[[ LIT:@ {addr}  TBRANCH {@l} --> LIT:@/TBRANCH {@l} {addr} ]]
pattern:[[ LIT:@ {addr} +0BRANCH {@l} --> LIT:@/+0BRANCH {@l} {addr} ]]
pattern:[[ LIT:@ {addr}  -BRANCH {@l} --> LIT:@/-BRANCH {@l} {addr} ]]

pattern:[[ LIT:C@ {addr}  0BRANCH {@l} --> LIT:C@/0BRANCH {@l} {addr} ]]
pattern:[[ LIT:C@ {addr}  TBRANCH {@l} --> LIT:C@/TBRANCH {@l} {addr} ]]
pattern:[[ LIT:C@ {addr} +0BRANCH {@l} --> BRANCH {@l} ]]
pattern:[[ LIT:C@ {addr}  -BRANCH {@l} --> ]]

pattern:[[ LIT:1C@ {addr}  0BRANCH {@l} --> LIT:C@/0BRANCH {@l} {[ addr 1+ lo-word ]} ]]
pattern:[[ LIT:1C@ {addr}  TBRANCH {@l} --> LIT:C@/TBRANCH {@l} {[ addr 1+ lo-word ]} ]]
pattern:[[ LIT:1C@ {addr} +0BRANCH {@l} --> BRANCH {@l} ]]
pattern:[[ LIT:1C@ {addr}  -BRANCH {@l} --> ]]


;; the order matters!
;; DUP lit xBRANCH -> lit xBRANCH-ND
;; lit xBRANCH -> xBRANCH:LIT

;; =BRANCH
pattern:[[ DUP LIT {n} =BRANCH {@l} --> LIT {n} =BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     =BRANCH {@l} -->         =BRANCH:LIT {@l} {n} ]]

;; <>BRANCH
pattern:[[ DUP LIT {n} <>BRANCH {@l} --> LIT {n} <>BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     <>BRANCH {@l} -->         <>BRANCH:LIT {@l} {n} ]]

;; <BRANCH
pattern:[[ DUP LIT {n} <BRANCH {@l} --> LIT {n} <BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     <BRANCH {@l} -->         <BRANCH:LIT {@l} {n} ]]

;; >BRANCH
pattern:[[ DUP LIT {n} >BRANCH {@l} --> LIT {n} >BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     >BRANCH {@l} -->         >BRANCH:LIT {@l} {n} ]]

;; >=BRANCH
pattern:[[ DUP LIT {n} >=BRANCH {@l} --> LIT {n} >=BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     >=BRANCH {@l} -->         >=BRANCH:LIT {@l} {n} ]]

;; <=BRANCH
pattern:[[ DUP LIT {n} <=BRANCH {@l} --> LIT {n} <=BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     <=BRANCH {@l} -->         <=BRANCH:LIT {@l} {n} ]]

;; U<BRANCH
pattern:[[ DUP LIT {n} U<BRANCH {@l} --> LIT {n} U<BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     U<BRANCH {@l} -->         U<BRANCH:LIT {@l} {n} ]]

;; U>BRANCH
pattern:[[ DUP LIT {n} U>BRANCH {@l} --> LIT {n} U>BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     U>BRANCH {@l} -->         U>BRANCH:LIT {@l} {n} ]]

;; U>=BRANCH
pattern:[[ DUP LIT {n} U>=BRANCH {@l} --> LIT {n} U>=BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     U>=BRANCH {@l} -->         U>=BRANCH:LIT {@l} {n} ]]

;; U<=BRANCH
pattern:[[ DUP LIT {n} U<=BRANCH {@l} --> LIT {n} U<=BRANCH-ND {@l} ]]
pattern:[[ LIT {n}     U<=BRANCH {@l} -->         U<=BRANCH:LIT {@l} {n} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; fold ND branches with literals
;; lit xBRANCH-ND -> xBRANCH-ND:LIT

pattern:[[ LIT {n}   =BRANCH-ND {@l} -->   =BRANCH-ND:LIT {@l} {n} ]]
pattern:[[ LIT {n}  <>BRANCH-ND {@l} -->  <>BRANCH-ND:LIT {@l} {n} ]]
pattern:[[ LIT {n}   <BRANCH-ND {@l} -->   <BRANCH-ND:LIT {@l} {n} ]]
pattern:[[ LIT {n}   >BRANCH-ND {@l} -->   >BRANCH-ND:LIT {@l} {n} ]]
pattern:[[ LIT {n}  >=BRANCH-ND {@l} -->  >=BRANCH-ND:LIT {@l} {n} ]]
pattern:[[ LIT {n}  <=BRANCH-ND {@l} -->  <=BRANCH-ND:LIT {@l} {n} ]]
pattern:[[ LIT {n}  U<BRANCH-ND {@l} -->  U<BRANCH-ND:LIT {@l} {n} ]]
pattern:[[ LIT {n}  U>BRANCH-ND {@l} -->  U>BRANCH-ND:LIT {@l} {n} ]]
pattern:[[ LIT {n} U>=BRANCH-ND {@l} --> U>=BRANCH-ND:LIT {@l} {n} ]]
pattern:[[ LIT {n} U<=BRANCH-ND {@l} --> U<=BRANCH-ND:LIT {@l} {n} ]]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; INP/OUTP optimisers

;; INP
pattern:[[ LIT {port} INP --> LIT:INP {port} ]]

;; OUTP
pattern:[[ LIT {port} OUTP --> LIT:OUTP {port} ]]


end-module OPT
end-module IR
end-module TCOM

