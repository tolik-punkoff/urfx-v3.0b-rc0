;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; debug dumps
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; debug printer

;; 2: endcr
code: Z:EMIT  ( ch )
  ld    a, l
  ld    hl, # zxemut-zemit-was-cr
  cp    # 2
  jr    nz, # .not-endcr
  ld    a, (hl)
  or    a
  jr    nz, # .done
  ld    a, # 10
.not-endcr:
  ld    (hl), # 0
  cp    # 10
  jr    nz, # .not-10
  inc   (hl)
.not-10:
  cp    # 13
  jr    nz, # .not-13
  inc   (hl)
.not-13:
  $03 $00 zxemut-trap-2b
.done:
  pop   hl
  next
flush!
zxemut-zemit-was-cr: 0 db,
;code-no-next
1 0 Succubus:setters:in-out-args

\ : Z:TYPE  ( addr count )  BEGIN DUP +WHILE SWAP C@++ Z:EMIT SWAP 1- REPEAT 2DROP ;
code: Z:TYPE  ( addr count )
  pop   de
  ld    a, h
  or    a
  jp    m, # .done
  or    l
  jr    z, # .done
  ex    de, hl
  ld    bc, de
  zxemut-emit-str-hl-bc
.done:
  pop   hl
;code

: Z:ENDCR  2 Z:EMIT ; zx-inline
: Z:SPACE  BL Z:EMIT ; zx-inline
: Z:CR     10 Z:EMIT ; zx-inline
: Z:FLUSH  $1A Z:EMIT ; zx-inline

: Z:SPACES  ( n ) BEGIN DUP +WHILE Z:SPACE 1- REPEAT DROP ;
: Z:D.R ( d n )  (D.R) Z:SPACES Z:TYPE ;
: Z:D.  ( d )  0 Z:D.R Z:SPACE ;

: Z:.R  ( n1 n2 )  (.R) Z:SPACES Z:TYPE ;
: Z:U.R ( n1 n2 )  (U.R) Z:SPACES Z:TYPE ;
: Z:.   ( n )  0 Z:.R Z:SPACE ; zx-inline
: Z:U.  ( u )  0 Z:U.R Z:SPACE ; zx-inline

: Z:0.R  ( n1 )  0 Z:.R ; zx-inline
: Z:0U.R ( n1 )  0 Z:U.R ; zx-inline

primitive: Z:.HEX2  ( u )
:codegen-xasm
  tos-r16 r16l->a
  $03 $04 zxemut-trap-2b
  pop-tos ;

primitive: Z:.HEX4  ( u )
:codegen-xasm
  restore-tos-hl
  $03 $05 zxemut-trap-2b
  pop-tos ;

primitive: Z:.U#5  ( u )
:codegen-xasm
  restore-tos-hl
  $03 $07 zxemut-trap-2b
  pop-tos ;


primitive: Z:.U#  ( u )
:codegen-xasm
  restore-tos-hl
  $03 $09 zxemut-trap-2b
  pop-tos ;

primitive: Z:.#  ( u )
:codegen-xasm
  restore-tos-hl
  $03 $0B zxemut-trap-2b
  pop-tos ;

primitive: Z:.+-#  ( u )
:codegen-xasm
  restore-tos-hl
  $03 $0D zxemut-trap-2b
  pop-tos ;


: Z:.BENCH-TIME  ( frames )
  50 u/mod z:.u# [char] . z:emit 20 * decw>str5 drop 2+ 3 z:type
  z:flush ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; stack printer

: Z:.STACK
  z:endcr
  z:." DEPTH: " sys: depth z:.# z:cr
  sys: depth for
    2 z:spaces
    sys: depth i - 1- z:.# z:space
    sys: depth i - 1- pick dup z:.# z:space z:.hex4
    z:cr
  endfor ;

<zx-system>
: (DEPTH-REPORT)
  di
  z:endcr
  z:." ***ERROR: DEPTH: " sys: depth z:.# z:cr
  (dihalt) ;

: ?DEPTH-0  sys: depth ?< (depth-report) >? ; zx-inline
: ?DEPTH-1  sys: depth 1- ?< (depth-report) >? ; zx-inline
: ?DEPTH-N  ( n )  sys: depth - ?< (depth-report) >? ; zx-inline
<zx-forth>

<zx-done>
