;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; host forwards for ZX words; used by TCOM control flow code
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

: (zx-forward)  ( addr count doer )
  >r -1 nrot r> (mk-shadow-header) ;

: zx-forward
  parse-name ['] ss-forth-doer (zx-forward) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; define some forwards

<zx-system>
zx-forward LIT
zx-forward LIT:@EXECUTE
zx-forward LIT:@
zx-forward LIT:C@
zx-forward LIT:1C@
zx-forward LIT:!
zx-forward LIT:C!
zx-forward LIT:1C!
zx-forward LIT:SWAP:!
zx-forward LIT:SWAP:C!
zx-forward LIT:!0
zx-forward LIT:!1
zx-forward LIT:C!0
zx-forward LIT:C!1
zx-forward LIT:+!
zx-forward LIT:-!
zx-forward LIT:+C!
zx-forward LIT:-C!
zx-forward LIT:1+!
zx-forward LIT:1-!
zx-forward LIT:1+C!
zx-forward LIT:1-C!
zx-forward LIT:+
zx-forward LIT:+:@
zx-forward LIT:+:C@
zx-forward LIT:+:!
zx-forward LIT:+:C!
zx-forward LIT:+:!0
zx-forward LIT:+:C!0
zx-forward LIT:+:!1
zx-forward LIT:+:C!1

zx-forward BRANCH
zx-forward 0BRANCH
zx-forward TBRANCH
zx-forward +0BRANCH
zx-forward -0BRANCH
zx-forward +BRANCH
zx-forward -BRANCH
zx-forward =BRANCH
zx-forward <>BRANCH
zx-forward <BRANCH
zx-forward >BRANCH
zx-forward <=BRANCH
zx-forward >=BRANCH

zx-forward <>BRANCH-ND
zx-forward =BRANCH-ND

zx-forward (DO)
zx-forward (+LOOP)
zx-forward (LOOP+1)
zx-forward (LOOP-1)
zx-forward (FOR)
zx-forward (FOR8)
zx-forward (FOR8:LIT)
\ zx-forward (ENDFOR)
\ zx-forward (ENDFOR8)
zx-forward (ENDFORX)
zx-forward (I)
zx-forward (I')
zx-forward (J)
zx-forward (J')
zx-forward (UNLOOP)
zx-forward (LEAVE)

zx-forward (<n>R@)
zx-forward (<n>RC@)
zx-forward (<n>R1C@)
zx-forward (<n>FOR8-I)
zx-forward (<n>FOR-I)
zx-forward (<n>FOR8-IREV)
zx-forward (<n>FOR-IREV)
zx-forward (RDROP<n>)

zx-forward (")
\ zx-forward (.")
\ zx-forward (Z:.")

\ OPT-ENABLE-FP? [IF]
zx-forward FP0!
zx-forward (FP-OP)
zx-forward (FP-OP-XMEM)
\ [ENDIF]

<zx-forth>
zx-forward (BP)
zx-forward RDROP
zx-forward 2RDROP
zx-forward DROP
zx-forward OVER
zx-forward DUP
zx-forward -
zx-forward EXIT
zx-forward ?EXIT
zx-forward NOT?EXIT

zx-forward 0>
zx-forward 0>=
zx-forward 0<
zx-forward 0<=

zx-forward @
zx-forward !
zx-forward +!
zx-forward -!
zx-forward !0
zx-forward !1

zx-forward TYPE
zx-forward Z:TYPE


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compile zx literals

;; compile zx-cfa literal, take care of forwards
: zx-shadow-cfa-#,  ( shadow-cfa )
  ['] ir:ir-specials:(ir-walit) ir:append-special
  dart:cfa>pfa ir:tail ir:node:spfa-ref:! ;

: zx-#,  ( n )
  dup -32768 65536 within not?error" ZX literal out of bounds"
  zsys: LIT ir:append-zxword
  ir:tail ir:node:value:! ;

;; for shadow constant code
['] zx-#, zx-lit,:!


end-module
