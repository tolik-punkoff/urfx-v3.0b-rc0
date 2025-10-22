;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; input ("stick") scanner
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


zxlib-begin" stick library"


raw-code: (*DETECT-KJOY-DON'T-USE*)
  ret
;; AF, E: dead; HL: result
stick-detect-kjoy:  ;; for mouse driver
  ;; save old IM2 routine
  ld    hl, () zx-im2-userproc-addr
  push  hl
  ld    hl, # .im2-proc-dummy
  ld    zx-im2-userproc-addr (), hl
  ;; wait for the interrupt to avoid floating bus issue
  halt
  ;; restore interrupt routine
  pop   hl
  ld    zx-im2-userproc-addr (), hl

  ;; high byte of the port number
  xor   a
  ;; 2 bytes, 8ts vs 3 bytes, 10ts
  ld    h, a
  ld    l, a
  in    a, () $1F
  ;; $FF? nothing's here
  cp    # $FF
  ret   z
  ;; test for some invalid values
  ld    e, a
  ;; bits 5-7 should be reset
  and   # $E0
  ret   nz
  ld    a, e
  ;; check if left & right pressed simultaneously
  and   # $03
  cp    # $03
  ret   z
  ld    a, e
  ;; check if up & down pressed simultaneously
  and   # $0C
  cp    # $0C
  ret   z
  inc   l   ;; hl=1
.im2-proc-dummy:
  ret
;code-no-next

;; detect kempston joystick.
;; interrupts must be enabled.
primitive: DETECT-KJOY ( -- bool )
Succubus:setters:out-bool
zx-required: (*DETECT-KJOY-DON'T-USE*)
:codegen-xasm
  push-tos
  TOS-in-HL!
  @label: stick-detect-kjoy call-# ;


;; use "MASK?" or "MASK8?" to check
$01 constant SMASK-LEFT
$02 constant SMASK-RIGHT
$04 constant SMASK-UP
$08 constant SMASK-DOWN
$10 constant SMASK-FIRE
$20 constant SMASK-FIRE2

;; use "BIT?" or "BIT8?" to check
0 constant SBIT-LEFT
1 constant SBIT-RIGHT
2 constant SBIT-UP
3 constant SBIT-DOWN
4 constant SBIT-FIRE
5 constant SBIT-FIRE2

;; size of table
6 constant INP-TBL-BYTES

;; any scancode higher than this is kempston joystick pseudocode.
;; this could be useful in key table dumping.
64 constant MAX-SCANCODE


;; booleans; rely on the optimiser to remove unnecessary boolean normalisation
: STICK-LEFT?  ( readval -- flag )  SMASK-LEFT mask? ; zx-inline
: STICK-RIGHT?  ( -- flag )  SMASK-RIGHT mask? ; zx-inline
: STICK-UP?  ( readval -- flag )  SMASK-UP mask? ; zx-inline
: STICK-DOWN?  ( readval -- flag )  SMASK-DOWN mask? ; zx-inline
: STICK-FIRE?  ( readval -- flag )  SMASK-FIRE mask? ; zx-inline
: STICK-FIRE2?  ( readval -- flag )  SMASK-FIRE2 mask? ; zx-inline


;; various predefined sets
;; fire,down,up,right,left
;; scancode format:
;;   bits 0-2: bit index (0 is LSB), counting from 1
;;   bits 3-6: index in `input-port-table`

create INP-TBL-OPQAM
  7 8 *  0 1+  +  c,   ;; space
  7 8 *  2 1+  +  c,   ;; "m"
  1 8 *  0 1+  +  c,   ;; "a"
  2 8 *  0 1+  +  c,   ;; "q"
  5 8 *  0 1+  +  c,   ;; "p"
  5 8 *  1 1+  +  c,   ;; "o"
create;

create INP-TBL-KJOY
  7 8 *  0 1+  +  c,   ;; space
  8 8 *  4 1+  +  c,   ;; fire
  8 8 *  2 1+  +  c,   ;; down
  8 8 *  3 1+  +  c,   ;; up
  8 8 *  0 1+  +  c,   ;; right
  8 8 *  1 1+  +  c,   ;; left
create;

create INP-TBL-CURSOR
  7 8 *  0 1+  +  c,   ;; space
  4 8 *  0 1+  +  c,   ;; "0"
  4 8 *  4 1+  +  c,   ;; "6"
  4 8 *  3 1+  +  c,   ;; "7"
  4 8 *  2 1+  +  c,   ;; "8"
  3 8 *  4 1+  +  c,   ;; "5"
create;

create INP-TBL-SCL1
  7 8 *  0 1+  +  c,   ;; space
  4 8 *  0 1+  +  c,   ;; "0"
  4 8 *  2 1+  +  c,   ;; "8"
  4 8 *  1 1+  +  c,   ;; "9"
  4 8 *  3 1+  +  c,   ;; "7"
  4 8 *  4 1+  +  c,   ;; "6"
create;

create INP-TBL-SCL2
  7 8 *  0 1+  +  c,   ;; space
  3 8 *  4 1+  +  c,   ;; "5"
  3 8 *  2 1+  +  c,   ;; "3"
  3 8 *  3 1+  +  c,   ;; "4"
  3 8 *  1 1+  +  c,   ;; "2"
  3 8 *  0 1+  +  c,   ;; "1"
create;


;; read table format:
;;   db mask
;;   db port-hi  (0 for kempston)
;; starting from FIRE2, and going to LEFT (6 items)

;; opqam and space
create INP-PREPARED
  $01 c, $7F c,   ;; FIRE2
  $04 c, $7F c,   ;; FIRE
  $01 c, $FD c,   ;; DOWN
  $01 c, $FB c,   ;; UP
  $01 c, $DF c,   ;; RIGHT
  $02 c, $DF c,   ;; LEFT
create;
zx-['] INP-PREPARED zxa:@def: stick-inp-prepared

;; kempston and space
create INP-PREPARED-1
  $01 c, $7F c,   ;; FIRE2
  $10 c, $00 c,   ;; FIRE
  $04 c, $00 c,   ;; DOWN
  $08 c, $00 c,   ;; UP
  $01 c, $00 c,   ;; RIGHT
  $02 c, $00 c,   ;; LEFT
create;


;; scancode format:
;;   bits 0-2: bit index (0 is LSB), counting from 1
;;   bits 3-6: index in `input-port-table`
code: PREPARE-STICK-TBL  ( srcaddr destaddr )
  pop   de
  call  # scan-prepare-stick-tbl
  pop   hl
  next
scan-prepare-stick-tbl:
  ;; HL: dest
  ;; DE: src
  ld    b, # 6
.key-loop:
  ld    a, (de)
  inc   de
  or    a
  jr    z, # .no-key
  cp    # 70
  jr    nc, # .no-key
  push  bc
  ld    c, a
  ;; calculate mask
  and   # $07
  jr    z, # .no-key
  ld    b, a
  ld    a, # $80
.mask-loop:
  rlca
  djnz  # .mask-loop
  ;; store mask
  ld    (hl), a
  ;; calculate port
  ld    a, c
  rrca
  rrca
  rrca
  and   # $0F
  cp    # 9
  jr    nc, # .no-key
  inc   hl
  and   # $07
  jr    z, # .kempston
  ;; calculate port
  inc   a
  ld    c, a
  ld    a, # $7F
.rotate-port:
  rlca
  dec   c
  jr    nz, # .rotate-port
.kempston:
  ;; A is the port high byte
  ld    (hl), a
  pop   bc
.loop-cont:
  inc   hl
  djnz  # .key-loop
  ret
.no-key:
  ;; just read the keyboard and mask everything away
  ;; A is 0 here
  ld    (hl), # $00   ;; mask
  inc   hl
  ld    (hl), # $7F   ;; port
  jr    # .loop-cont
;code-no-next


: STICK-TBL!  ( srcaddr )  inp-prepared prepare-stick-tbl ; zx-inline

: STICK-KJOY!   inp-tbl-kjoy stick-tbl! ; zx-inline
: STICK-OPQAM!  inp-tbl-opqam stick-tbl! ; zx-inline
: STICK-CURSOR! inp-tbl-cursor stick-tbl! ; zx-inline
: STICK-SCL1!   inp-tbl-scl1 stick-tbl! ; zx-inline
: STICK-SCL2!   inp-tbl-scl2 stick-tbl! ; zx-inline


;; read input key, return "scancode" suitable for using in stick table.
;; do not wait for keypress, return 0 if nothing was pressed.
code: STICK-INKEY  ( -- scancode // 0 )
  push  hl
  call  # stick-input-inkey-scancode
zx-stick-inkey-finish:
  ld    h, # 0
  next

;; check for a pressed key, return scancode.
;; returned scancode can be used to built the table for `read-stick`.
;;
;; IN:
;;   none
;; OUT:
;;   L: key scancode, or 0
;;   H: dead
;;   A: dead
;;   F: dead
;;   CARRY: set if a key was pressed
;;
stick-input-inkey-scancode:
  ld    hl, # $FE00     ;; B is keyboard port, C will contain scancode
.nextrow:
  ;; two-byte IN
  ld    a, h            ;; high byte of the keyboard port
  in    a, () $FE       ;; read keyboard
  cpl                   ;; invert (because for keyboard, "0" means "pressed")
  and   # $1F           ;; throw away non-keyboard bits
  jr    nz, # .gotkey
  ;; no key pressed, move to the next port
  ;; increment keyboard port bit index
  ld    a, l
  add   a, # 8
  ld    l, a
  ;; modify keyboard port
  sll   h               ;; sets bit 0 to 1, moves bit 7 to carry
  jr    c, # .nextrow
  ;; alas, nothing was pressed at all
  xor   a               ;; set result, reset carry flag
  ld    l, a
  ret
.gotkey:
  ;; find the number of the first set bit
  ;; C contains high part of the scancode
  inc   l
  rra
  jr    nc, # .gotkey
  ret
;code-no-next

code: STICK-WAITKEY  ( -- scancode )
  push  hl
.loop:
  call  # stick-input-inkey-scancode
  jr    nc, # .loop
  jr    # zx-stick-inkey-finish
;code-no-next

;; wait until all keys released
raw-code: STICK-WAIT-KEYUP
  push  hl
.loop:
  call  # stick-input-inkey-scancode
  jr    c, # .loop
  pop   hl
;code


;; translate *VALID* scancode to ASCII. to use in "redefine keys".
;; on invalid scancode (kempston, 0 or garbage), return 0.
;; this could be useful in key table dumping.
raw-code: SCAN>ASCII  ( scancode -- ascii // 0 )
  \ pop   hl
  ld    a, l
  call  # stick-input-scancode-to-ascii
  ld    l, a
  ld    h, # 0
  ret

;; this is used to convert the result of `xte_input_inkey_scancode`
;; to ASCII via `xte_input_inkey_ascii`
;; 13: enter
;; 30: caps shift
;; 31: symbol shift
input-keynames:
        30 db, [CHAR] Z db, [CHAR] X db, [CHAR] C db, [CHAR] V db, 0 dw, 0 db,
  [CHAR] A db, [CHAR] S db, [CHAR] D db, [CHAR] F db, [CHAR] G db, 0 dw, 0 db,
  [CHAR] Q db, [CHAR] W db, [CHAR] E db, [CHAR] R db, [CHAR] T db, 0 dw, 0 db,
  [CHAR] 1 db, [CHAR] 2 db, [CHAR] 3 db, [CHAR] 4 db, [CHAR] 5 db, 0 dw, 0 db,
  [CHAR] 0 db, [CHAR] 9 db, [CHAR] 8 db, [CHAR] 7 db, [CHAR] 6 db, 0 dw, 0 db,
  [CHAR] P db, [CHAR] O db, [CHAR] I db, [CHAR] U db, [CHAR] Y db, 0 dw, 0 db,
        13 db, [CHAR] L db, [CHAR] K db, [CHAR] J db, [CHAR] H db, 0 dw, 0 db,
        32 db,       31 db, [CHAR] M db, [CHAR] N db, [CHAR] B db, 0 dw, 0 db,

;; translate *VALID* scancode to ASCII
;;
;; IN:
;;   A: *VALID* scancode from `stick-input-inkey-scancode`
;; OUT:
;;   A: ASCII code or 0 if A is 0 or invalid on enter
;;  HL: dead
;;   F: dead
stick-input-scancode-to-ascii:
  ;; just in case, check for zero scancode (it means "no key")
  or    a
  ret   z
  cp    # 64
  jr    nc, # .bad-scancode
  dec   a               ;; we are indexing from 1
  add   a, # input-keynames lo-byte
  ld    l, a
  [@@] input-keynames lo-byte 0= [IF]
    ;; it is page-aligned
    ld    h, # input-keynames hi-byte
  [ELSE]
    ;; not page-aligned
    [@@] input-keynames lo-byte 60 + 255 > [IF]
      ;; need to fix high byte
      ld    a, # input-keynames hi-byte
      adc   a, # 0
      ld    h, a
    [ELSE]
      ld    h, # input-keynames hi-byte
    [ENDIF]
  [ENDIF]
  ld    a, (hl)
  ret
.bad-scancode:
  xor   a
  ret
;code-no-next


;; read table format:
;;   db mask
;;   db port-hi  (0 for kempston)
;;
;; IN:
;;   DE: table above
;; OUT:
;;   AF: destroyed
;;   DE: next table start
;;   B: destroyed
;;   C: stick state (XFDURL; F is $10)
raw-code: (*STICK-READ-DONT-USE*)
  ret
read-stick-de:
  ;; 6 keys
  push  hl
  ld    bc, # $0600
.read-loop:
  ;; mask
  ld    a, (de)
  inc   de
  ld    read-stick-patch-mask (), a
  ;; port-hi
  ld    a, (de)
  inc   de
  ld    hl, # $2F1F
  or    a
  jr    z, # .kempston-port
  ld    hl, # $00FE
.kempston-port:
  ld    read-stick-patch-port-lo (), hl
  ;; read one
  ;; A contains port-hi here
  in    a, () $FE
$here 1- @def: read-stick-patch-port-lo
  cpl   ;; CPL for kempston (CPL: $2F)
  ld    l, # $00  ;; patch mask
$here 1- @def: read-stick-patch-mask
  and   l
  sub   a, l
  rl    c
  djnz  # .read-loop
  ;; done
  pop   hl
  ret
;code-no-next


;; read stick input using input table (see `input_table_XXX` above).
;; stick state: XFDURL; F is $10.
;; "X" is "space pressed".
primitive: STICK-READ  ( -- stick-state )
Succubus:setters:out-8bit
:codegen-xasm
  restore-tos-hl
  push-tos-peephole ;; this will automatically optimise out "DROP"
  @label: stick-inp-prepared #->de
  @label: read-stick-de call-#
  c->l
  $00 c#->h ;
zx-required: (*STICK-READ-DONT-USE*) INP-PREPARED


zxlib-end
