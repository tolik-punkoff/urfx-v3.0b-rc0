;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; LASER BASIC / WHITE LIGHTNING graphics library

;; use variable for screen$ address?
;; if false, it is hardcoded to $4000.
;; it is slightly faster without a variable.
false zx-lib-option OPT-LASERLIB-USE-VARIABLE-SCR$?

;; use variable for attribute address?
;; if false, it is hardcoded to $5800.
false zx-lib-option OPT-LASERLIB-USE-VARIABLE-ATTR?

;; use sprite address table instead of linear search?
;; the table will be built on demand, you don't have to do anything.
true zx-lib-option OPT-LASERLIB-USE-ADDRESS-TABLE?

;; align sprite address table to 256 bytes?
;; the code is slightly smalled and faster this way.
false zx-lib-option OPT-LASERLIB-ALIGN-ADDRESS-TABLE?


(*
horizontal scroll legend:
  Wxxx -- scroll, with wrapping (cyclic)
  Sxxx -- shift, without wrapping
  x*xx -- direction: "L" or "R"
  xxx@ -- "V" for screen, "M" for sprite
          "V" means "window", "M" means "whole sprite"
          ("V" is "video", if you are interested, and
           "M" is "memory")
so:
  WL8V -- cyclic scroll, left, 8 pixels, screen ("V")

vertical scroll legend:
  WCRV -- vertical scroll, with wrapping (cyclic)
  SCRV -- vertical shift, without wrapping

attribute scroll (screen) legend:
  AT*V -- "L", "R", "U", "D", with wrapping

get and put legend:
  GTop
  PTop
where "op" is: "BL" for "block/blit", "OR", "XR", "ND", "AT".
"AT" is "attributes".
"GT" is "get scr$ to sprite", and "PT" is "put sprite to scr$".
get and put require only (x0, y0) scr$ coords, and sprite number.

to use sprite and screen windows:
  GWop
  PWop

to copy data between sprites, use:
  GMop
  PMop
those routines require sprite window coords, but not window width or height.
"GM" gets "into sprite window". "PM" puts "to sprite window".


.MOVE
Used to provide simple and effective animated or non-animated sprite
movement. This command uses the exclusive OR (XOR) operation to provide non
destructive sprite movement, so if your sprite starts on screen you will
need to .PTXR the sprite onto the screen before you use MOVE. If your
sprite moves "on screen" from a position "off screen" then this will be
catered for automatically. The exclusive OR (XOR) operation works in the
same way as Sinclair's OVER 1 printing.

        Parameters      Use
        COL     The COL of the sprite to be moved.              (0-31)
        ROW     The ROW of the sprite to be moved.              (0-23)
        HGT     The HGT in characters of the movement           (-24-+24)
        LEN     The LEN in characters of the movement.          (-32-+32)
        SP1     The number of the sprite to be moved.           (1-255)
        SP2     The number of the sprite after movement.        (1-255)

MOVE XORs out the previously PUT sprite SP1 that is on the screen at a
position held in ROW and COL and places sprite SP2 on the screen at a
position COL + LEN, HGT + ROW. ROW and COL are then incremented by the
values of HGT and LEN, and SP1 and sP2 are left exchanged.


.INVx -- bitwise inversion ("V", "M")
.MIRx -- horizontal mirror ("V", "M")
.MARx -- horizontal mirror of attributes ("V", "M")

.SPNM -- rotate sprite by 90 degrees clockwise. this includes attribute data.

.DSPM -- scale sprite 2 times. this includes attributes.

.SETx -- set attributes ("V", "M").
.CLSx -- fill bitmap with 0, set attrs ("V", "M").

.ADJM -- adjust sprite window, so the sprite could be safely put or get.
         This command is used to adjust the values in the variables COL, ROW,
         HGT, LEN, SCL, SRW, SPN so that a particular sprite can be
         "partially PUT or GOT" to or from the screen using the group 2 PUTs
         or GETs. The value in the PUT variables COL, ROW, HGT, LEN, SCL and
         SRW may all be changed by the execution of this command. Before
         execution SCL and SRW must be zero, HGT and LEN are ignored and the
         HGT and LEN of the sprite whose number is held in SPN are used.

         SPN     Sprite to be PUT or GOT (1-255)
         COL     Target column           (0-31)
         ROW     Target row              (0-23)
         SCL     Set to 0 before execution
         SRW     Set to 0 before execution

.ADJV -- adjust screen$ window, so it will be "on screen".
         COL     Target column           (0-31)
         ROW     Target row              (0-23)
         HGT     Height of window        (1-24)
         LEN     Length of window        (1-32)

lightning sprite format:
  db sprite-number
  dw next-sprite-addr
  db sprite-width     ;; in chars
  db sprite-height    ;; in chars
  then the bitmap, then the attributes
*)


zxlib-begin" LASERLIB library"

raw-code: (*LASERLIB-CORE*)
  ret

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; system variables


;; buffer address for vertical screen scrolling.
;; size: width * scroll_step
scrl_b:
  $5B00 dw,

;; start address of the sprite file
sfstrt:
  $0000 dw,
;; end address of the sprite file
sf_end:
  $0000 dw,

;; attributes for "SETV" and "SETM"
setv_a:
  $00 db,

;; address of the current screen$
OPT-LASERLIB-USE-VARIABLE-SCR$? [IF]
scr_ac:
  $4000 dw,
[ENDIF]

;; address of the current screen$ attributes
OPT-LASERLIB-USE-VARIABLE-ATTR? [IF]
scra_a:
  $5800 dw,
[ENDIF]


;; FIXME: convert this to proper code offsets!
;; WARNING! the order matters!
lb_wk_params_addr:

var_sp1: 1 db,
var_sp2: 1 db,

var_col: 0 db,
var_row: 0 db,
var_wdt: 32 db,
var_hgt: 24 db,

var_scl: 0 db,
var_srw: 0 db,
var_swd: 1 db,
var_shg: 1 db,

var_len: 0 db,
var_npx: 0 db,


OPT-LASERLIB-USE-ADDRESS-TABLE? [IF]
;; reserve 512 bytes for sprite addresses
OPT-LASERLIB-ALIGN-ADDRESS-TABLE? [IF]
  zx-align-256-asm
[ENDIF]
sprite-start-table:
512 zx-asm-zallot


build-sprite-table:
  ld    a, () sprite-start-table
  or    a
  ret   nz
  inc   a
  ld    sprite-start-table (), a

  exx
  ;; clear the table
  ld    hl, # sprite-start-table
  ld    de, hl
  inc   e
  ld    bc, # 511
  ld    (hl), # 0
  ldir

  ;; build the table
  ld    de, () sfstrt
.build-loop:
  ld    a, (de)   ;; sprite index
  inc   de
  or    a
  jr    z, # .build-done
  OPT-LASERLIB-ALIGN-ADDRESS-TABLE? [IF]
    add   a, a
    ld    l, a
    ld    a, # sprite-start-table hi-byte
    adc   a, # 0
    ld    h, a
  [ELSE]
    ld    l, a
    ld    h, # 0
    add   hl, hl
    ld    bc, # sprite-start-table
    add   hl, bc
  [ENDIF]
  ;; save sprite address (skip the header)
  inc   de
  inc   de
  ld    (hl), e
  inc   l
  ld    (hl), d
  ;; skip the sprite
  ex    de, hl
  dec   hl
  ld    d, (hl)
  dec   hl
  ld    e, (hl)
  jr    # .build-loop

.build-done:
  exx
  ret

invalidate-sprite-table:
  ex    af, afx
  xor   a
  ld    sprite-start-table (), a
  ex    af, afx
  ret
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mirror window attributes
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
marv:
  nop
@lb_001:
  ld    de, # lb_052
  ld    lb_050 2 + (), de
  ld    lb_051 1 + (), de
  ld    de, # lb_049
@lb_002:
  call  # lb_013
  ld    de, # lb_052 2 +
  ld    lb_050 2 + (), de
  ld    lb_051 1 + (), de
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window attrs left (cyclical)
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
awlv:
  call  # lb_check_bc_hl_winxywh_carry_on_success
  ret   nc
  push  hl
  push  bc
  pop   hl
  pop   bc
  push  bc
  call  # lb_105
  pop   bc
@lb_003:
  ld    a, b
  push  bc
  push  af
  push  hl
  ld    b, # 0
@lb_004:
  call  # lb_046
  pop   hl
@lb_005:
  ld    de, # $0020
  or    a
  adc   hl, de
  pop   af
  pop   bc
  dec   a
  ret   z
  jr    # lb_003 1 +


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window attrs up (cyclical)
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
atuv:
  call  # lb_064
  call  # lb_068
  call  # lb_check_bc_hl_winxywh_carry_on_success
  ret   nc
@lb_006:
  call  # lb_007
  ld    de, () scrl_b
  ex    de, hl
  ld    b, # 0
  ldir
  ld    hl, () scrl_b
  ld    (hl), # 0
  ret
@lb_007:
  push  hl
  push  bc
  pop   hl
  pop   bc
  push  bc
  call  # lb_105
  pop   bc
@lb_008:
  call  # lb_012
  ld    a, b
@lb_009:
  dec   a
  ret   z
  push  bc
  push  hl
  ld    b, # 0
@lb_010:
  ld    de, # $0020
  or    a
@lb_011:
  adc   hl, de
  pop   de
  push  hl
  ldir
  pop   hl
  pop   bc
  jr    # lb_009
@lb_012:
  push  hl
  push  bc
  ld    b, # 0
  ld    de, () scrl_b
  ldir
  pop   bc
  pop   hl
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window attrs down (cyclical)
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
atdv:
  call  # lb_064
  call  # lb_068
  call  # lb_check_bc_hl_winxywh_carry_on_success
  ret   nc
  ld    a, h
  dec   a
  ret   z
  add   a, b
  ld    b, a
  ld    a, # $52
  ld    lb_011 1 + (), a
  call  # lb_006
  ld    a, # $5a
  ld    lb_011 1 + (), a
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window attrs right (cyclical)
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
awrv:
  ld    de, # lb_048
@lb_013:
  ld    lb_004 1 + (), de
  call  # awlv
@lb_014:
  ld    de, # lb_046
  ld    lb_004 1 + (), de
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window attrs right
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
asrv:
  ld    de, # lb_047
  ld    lb_004 1 + (), de
  call  # awlv
  ld    de, # lb_046
  ld    lb_004 1 + (), de
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window attrs left
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
aslv:
  ld    de, # lb_045
  ld    lb_004 1 + (), de
  call  # awlv
  ld    de, # lb_046
  ld    lb_004 1 + (), de
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window vertically (cyclical)
;;
;; IN:
;;   A: signed distance
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
wcrv:
  jp    # lb_015 1 +
@lb_015:
  nop
  call  # lb_068
  ld    lb_069_vars (), a
  or    a
  ret   z
  call  # lb_021
  ret   nc
  sla   b
  sla   b
  sla   b
  ld    a, lb_069_vars ()
  bit   7, a
  jr    z, # lb_016
  ld    a, h
  add   a, b
  ld    b, a
  dec   b
  ld    a, () lb_069_vars
  neg
  push  hl
  ld    hl, # $0515
  ld    lb_018 (), hl
  ld    hl, # lb_027
  ld    (hl), # $05
  pop   hl
@lb_016:
  sub   h
  neg
  ld    lb_015 (), a
  push  bc
  push  hl
  call  # lb_023
  pop   hl
  pop   bc
  ld    a, lb_069_vars ()
  ld    e, c
  ld    d, b
  add   a, d
  ld    d, a
  ld    a, lb_015 ()
@lb_017:
  push  bc
  push  de
  push  hl
  push  af
  call  # lb_029
  pop   af
  pop   hl
  pop   de
  pop   bc
@lb_018:
  inc   d
  inc   b
  dec   a
  jr    nz, # lb_017
  ld    a, () lb_069_vars
  bit   7, a
@lb_019:
  jp    z, # lb_032
  push  hl
  ld    hl, # $0414
  ld    lb_018 (), hl
  pop   hl
@lb_020:
  call  # lb_032
  ld    hl, # lb_027
  ld    (hl), # $04
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window vertically
;;
;; IN:
;;   A: signed distance
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
scrv:
  call  # lb_068
  push  hl
  ld    hl, # lb_030
  ld    lb_019 1 + (), hl
  ld    lb_020 1 + (), hl
  pop   hl
  call  # lb_015 1 +
  ld    hl, # lb_032
  ld    lb_019 1 + (), hl
  ld    lb_020 1 + (), hl
  ret
@lb_021:
  call  # lb_check_bc_hl_winxywh_carry_on_success
  ret   nc
  ld    a, () lb_069_vars
  sla   h
  sla   h
  sla   h
  bit   7, a
  jr    z, # lb_022
  neg
@lb_022:
  sub   h
  ret
  ld    e, b
@lb_022_3:
  ld    d, c
  ld    a, # $07
  and   b
  ld    c, a
  ld    a, # $c0
  and   b
  rrca
  rrca
  rrca
  or    c
  set   6, a
  ld    h, a
  ld    a, # $38
  and   b
  rlca
  rlca
  add   a, d
  ld    l, a
  ld    b, e
  ld    c, d
  ret
@lb_023:
  nop
  ld    de, () scrl_b
  ld    a, () lb_069_vars
  bit   7, a
  jr    z, # lb_024
  neg
@lb_024:
  ld    h, # $00
  push  bc
  push  af
  push  de
  push  hl
  call  # lb_022_3
  pop   bc
  pop   de
  push  bc
@lb_025:
  nop
  ldir
@lb_026:
  nop
  pop   hl
  pop   af
  pop   bc
  dec   a
  jr    z, # lb_028
@lb_027:
  inc   b
  jr    # lb_024 2 +
@lb_028:
  ld    hl, () scrl_b
  or    a
  ex    de, hl
  sbc   hl, de
  ld    lb_069_vars 2 + (), hl
  ret
@lb_029:
  push  hl
  push  de
  call  # lb_022_3
  pop   bc
  push  hl
  call  # lb_022_3
  pop   de
  pop   bc
  ld    b, # $00
  ldir
  ret
@lb_030:
  push  hl
  push  bc
  push  de
  ld    hl, () scrl_b
  ld    bc, () lb_069_vars 2 +
  ld    d, h
  ld    e, l
  inc   de
  dec   bc
  ld    (hl), # $00
  ld    a, b
  or    c
  jr    z, # lb_031
  ldir
@lb_031:
  pop   de
  pop   bc
  pop   hl
@lb_032:
  push  hl
  ld    hl, # lb_025
  ld    (hl), # $eb
  ld    hl, # lb_026
  ld    (hl), # $eb
  pop   hl
  call  # lb_023
  xor   a
  ld    lb_023 (), a
  ld    lb_025 (), a
  ld    lb_026 (), a
  ret
@lb_033:
  xor   a
  ld    b, c
  rr    (hl)
  inc   hl
  djnz  # lb_033 2 +
  ret
@lb_034:
  push  hl
  call  # lb_033
  pop   hl
  ret   nc
  set   7, (hl)
  neg
  ret
@lb_035:
  ld    b, # $00
  add   hl, bc
  dec   hl
  xor   a
  push  hl
  ld    b, c
@lb_036:
  rl    (hl)
  dec   hl
  djnz  # lb_036
  pop   hl
  ret
@lb_037:
  call  # lb_035
  ret   nc
  set   0, (hl)
  ret
sr1v:
  ld    de, # lb_033
  jp    # lb_056
sl1v:
  ld    de, # lb_035
  jp    # lb_056
wr1v:
  ld    de, # lb_034
  jp    # lb_056
wl1v:
  ld    de, # lb_037
  jp    # lb_056
sr4v:
  push  hl
  ld    hl, # $67ed
  ld    lb_033 2 + (), hl
  pop   hl
@lb_038:
  call  # sr1v
  ld    hl, # $1ecb
  ld    lb_033 2 + (), hl
  ret
sl4v:
  push  hl
  ld    hl, # $6fed
  ld    lb_036 (), hl
  pop   hl
@lb_039:
  call  # sl1v
  ld    hl, # $16cb
  ld    lb_036 (), hl
  ret
wr4v:
  push  hl
  ld    hl, # $67ed
  ld    lb_033 2 + (), hl
  pop   hl
  ld    de, # lb_041
@lb_040:
  call  # lb_056
  jr    # lb_038 3 +
@lb_041:
  push  hl
  call  # lb_033
  sla   a
  sla   a
  sla   a
  sla   a
  pop   hl
@lb_042:
  or    (hl)
  ld    (hl), a
  ret
wl4v:
  push  hl
  ld    hl, # $6fed
  ld    lb_036 (), hl
  pop   hl
  ld    de, # lb_044
@lb_043:
  call  # lb_056
  jr    # lb_039 3 +
@lb_044:
  call  # lb_035
  jr    # lb_042
sl8v:
  ld    de, # lb_045
  jp    # lb_056
@lb_045:
  ld    d, h
  ld    e, l
  inc   hl
  dec   c
  ret   z
  ldir
  dec   hl
  ld    (hl), # $00
  ret
wl8v:
  ld    de, # lb_046
  jp    # lb_056
@lb_046:
  ld    a, (hl)
  call  # lb_045
  ld    (de), a
  ret
sr8v:
  ld    de, # lb_047
  jp    # lb_056
@lb_047:
  dec   c
  ret   z
  add   hl, bc
  ld    d, h
  ld    e, l
  ld    a, (hl)
  dec   hl
  lddr
  inc   hl
  ld    (hl), # $00
  ret
wr8v:
  ld    de, # lb_048
  jp    # lb_056
@lb_048:
  call  # lb_047
  ld    (de), a
  ret
@lb_049:
  ld    e, l
  ld    d, h
  add   hl, bc
  dec   hl
  ex    de, hl
  srl   c
  jr    nc, # lb_050
  inc   c
@lb_050:
  ld    a, (hl)
  call  # lb_052 2 +
  ld    a, (de)
  push  bc
@lb_051:
  call  # lb_052 2 +
  pop   af
  ld    (de), a
  ld    (hl), b
  dec   de
  inc   hl
  dec   c
  jr    nz, # lb_050
  ret
@lb_052:
  ld    b, a
  ret
  rlc   a
  rr    b
  rlc   a
  rr    b
  rlc   a
  rr    b
  rlc   a
  rr    b
  rlc   a
  rr    b
  rlc   a
  rr    b
  rlc   a
  rr    b
  rlc   a
  rr    b
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mirror window vertically
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
mirv:
  ld    de, # lb_049
  jp    # lb_056


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; invert window
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
invv:
  ld    de, # lb_053
  jp    # lb_056
@lb_053:
  ld    b, c
  ld    a, (hl)
  cpl
  ld    (hl), a
  inc   hl
  djnz  # lb_053 1 +
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; set window attributes
;;
;; IN:
;;   A: attributes
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
;; setv_a: attributes
setv:
  call  # lb_064
  call  # lb_068
  push  hl
  push  bc
  pop   hl
  call  # lb_105
  pop   bc
@lb_054:
  push  bc
  push  hl
  ld    a, () setv_a
  call  # lb_055 1 +
  pop   hl
  ld    de, # $0020
  add   hl, de
  pop   bc
  djnz  # lb_054
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; clear widnow
;;
;; IN:
;;   B: y0
;;   C: x0
;;   H: height
;;   L: width
clsv:
  ld    de, # lb_055
  jp    # lb_056
@lb_055:
  xor   a
  ld    b, # $00
  ld    (hl), a
  dec   c
  ret   z
  ld    d, h
  ld    e, l
  inc   de
  ldir
  ret
@lb_056:
  ld    lb_087 1 + (), de
  call  # lb_064
  call  # lb_068
  xor   a
@lb_057:
  call  # lb_086
  ld    hl, # lb_084
  ld    lb_087 1 + (), hl
  ret

  ;; check screen window coordinates and size
  ;; IN:
  ;;   BC: yx
  ;;   HL: hw
  ;; OUT:
  ;;   AF: destroyed
  ;;   CARRY: set if the coords are ok
  ;; this code is sometimes modified
@lb_check_bc_hl_winxywh_carry_on_success:
  ld    a, h
  add   a, b
  cp    # 25
  ret   nc
  ld    a, l
  add   a, c
  cp    # 33
  ret   nc
  ld    a, b
  cp    # 24
  ret   nc
  ld    a, c
  cp    # 32
  ret   nc
  scf
  ret

@lb_059:
  ld    de, # $0000
  bit   7, c
  jr    z, # lb_060
  ld    a, l
  add   a, c
  bit   7, a
  jr    nz, # lb_063_2
  or    a
  jr    z, # lb_063_2
  ld    l, a
  ld    a, c
  neg
  ld    e, a
  ld    c, # $00
@lb_060:
  bit   7, b
  jr    z, # lb_061
  ld    a, h
  add   a, b
  bit   7, a
  jr    nz, # lb_063_2
  or    a
  jr    z, # lb_063_2
  ld    h, a
  ld    a, b
  neg
  ld    d, a
  ld    b, # $00
@lb_061:
  ld    a, c
  add   a, l
  cp    # $21
  jr    c, # lb_062
  ld    a, # $20
  sub   c
  jr    c, # lb_063_2
  or    a
  jr    z, # lb_063_2
  ld    l, a
@lb_062:
  ld    a, b
  add   a, h
  cp    # $19
  jr    c, # lb_063
  ld    a, # $18
  sub   b
  jr    c, # lb_063_2
  or    a
  jr    z, # lb_063_2
  ld    h, a
@lb_063:
  scf
  ret
@lb_063_2:
  or    a
  ret
@lb_063_4:
  push  bc
  call  # lb_146
  pop   bc
@lb_064:
  call  # lb_check_bc_hl_winxywh_carry_on_success
  jp    nc, # lb_059
  ld    de, # $0000
  scf
  ret
@lb_065:
  push  af
  push  bc
  push  bc
  call  # ltk_find_sprite_from_a_carry_on_failure
  pop   hl
  jr    c, # lb_067
@lb_066:
  pop   hl
  pop   hl
  ret
@lb_067:
  ld    e, h
  ld    d, # $00
  ld    h, # $00
  call  # lb_107
  push  hl
  add   hl, hl
  add   hl, hl
  add   hl, hl
  pop   de
  add   hl, de
  ld    de, # $0005
  add   hl, de
  ex    de, hl
  ld    hl, # $0000
  or    a
  sbc   hl, de
  ld    b, h
  ld    c, l
  call  # rlct
  pop   bc
  pop   af
  jp    # lb_079
@lb_068:
  push  af
  ld    a, h
  or    a
  jp    z, # lb_066
  ld    a, l
  or    a
  jp    z, # lb_066
  pop   af
  ret

@lb_069_vars:
  0 db, 0 db,
  0 db, 0 db,

@ltk_find_sprite_from_a_carry_on_failure:
  ;; k8: new code with address table
  ld    lb_069_vars (), a
  OPT-LASERLIB-USE-ADDRESS-TABLE? [IF]
    or    a
    scf
    ret   z
    ex    af, afx
    call  # build-sprite-table
    ex    af, afx
    OPT-LASERLIB-ALIGN-ADDRESS-TABLE? [IF]
      add   a, a
      ld    l, a
      ld    a, # sprite-start-table hi-byte
      adc   a, # 0
      ld    h, a
    [ELSE]
      ld    l, a
      ld    h, # 0
      add   hl, hl
      ld    bc, # sprite-start-table
      add   hl, bc
    [ENDIF]
    ;; OUT:
    ;;  DE: sprite data address
    ;;  HL: hw
    ld    a, (hl)
    inc   hl
    ld    h, (hl)
    ld    l, a
    or    h
    scf
    ret   z     ;; fail with carry flag
    ;; HL is sprite start (index and next addr are skipped)
    ld    e, (hl)   ;; width
    inc   hl
    ld    d, (hl)   ;; height
    ex    de, hl
    ;; HL: hw
    ;; i don't know if BC is required, but...
    ld    bc, de
    inc   de
    ;; DE: sprite data
    dec   bc
    dec   bc
    dec   bc
    dec   bc
    ;; BC: sprite start address
    ;; DE: sprite data address
    ;; HL: sprite height and width
    ;;  A: sprite number
    ld    a, () lb_069_vars
    or    a
    ret
  [ELSE]
    ld    hl, () sfstrt
    ld    lb_069_vars (), a
.lb_071:
    ld    b, a
    ex    af, afx   ;; k8: new code
    ld    a, (hl)
    or    a   ;; k8: was "cp # 0"
    jr    nz, # .lb_072
    scf
    ret
.lb_072:
    cp    b
    jr    nz, # .lb_073
    push  hl    ;; save sprite start address
    ;; skip index and next sprite address
    inc   hl
    inc   hl
    inc   hl
    ld    c, (hl)   ;; width
    inc   hl
    ld    b, (hl)   ;; height
    inc   hl
    ex    de, hl
    ;; DE: sprite data
    ld    h, b
    ld    l, c
    ;; HL: hw
    or    a
    pop   bc
    ;; BC: sprite start address
    ;; DE: sprite data address
    ;; HL: sprite height and width
    ;;  A: sprite number
    ret
.lb_073:
    \ call  # lb_074
    ;; k8: inlined for speed
    inc   hl
    ld    e, (hl)
    inc   hl
    ld    d, (hl)
    ;; k8: inline ends here
    ex    de, hl
    \ ld    a, () lb_069_vars
    ex    af, afx   ;; k8: new code
    jr    # .lb_071
  [ENDIF]

@lb_074:
  inc   hl
  ld    e, (hl)
  inc   hl
  ld    d, (hl)
  ret

@lb_075_wvar:
  0 dw,

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SPRITE ROUTINES
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create new sprite
;;
;; IN:
;;   H: height
;;   L: width
ispr:
  OPT-LASERLIB-USE-ADDRESS-TABLE? [IF]
  call  # invalidate-sprite-table
  [ENDIF]
  ld    b, h
  ld    c, l
  jp    # lb_065


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create new sprite
;;
;; IN:
;;   H: height
;;   L: width
sprt:
  OPT-LASERLIB-USE-ADDRESS-TABLE? [IF]
  call  # invalidate-sprite-table
  [ENDIF]
  ld    bc, hl
  jp    # lb_079


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; delete sprite
;;
;; IN:
;;   A: sprite index
wspr:
  OPT-LASERLIB-USE-ADDRESS-TABLE? [IF]
  call  # invalidate-sprite-table
  [ENDIF]
  call  # lb_146
  ret   c
  jp    # lb_080


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; delete sprite
;;
;; IN:
;;   A: sprite index
dspr:
  OPT-LASERLIB-USE-ADDRESS-TABLE? [IF]
  call  # invalidate-sprite-table
  [ENDIF]
  push  hl
  push  af
  call  # lb_146
  pop   af
  call  # wspr
  ld    de, () sf_end
  pop   hl
  or    a
  sbc   hl, de
  ld    b, h
  ld    c, l
  jp    # rlct



;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; move sprite file to the new address
;;
;; IN:
;;   HL: new address
rlct:
  OPT-LASERLIB-USE-ADDRESS-TABLE? [IF]
  call  # invalidate-sprite-table
  [ENDIF]
  call  # .lb_076
  ld    hl, () sf_end
  ld    de, () sfstrt
  or    a
  sbc   hl, de
  inc   hl
  push  hl
  bit   7, b
  jr    nz, # .lb_077
  ld    hl, () sf_end
  call  # .lb_078
  ld    sf_end (), de
  pop   bc
  lddr
  inc   de
  ld    sfstrt (), de
  ret
.lb_077:
  ld    hl, () sfstrt
  call  # .lb_078
  ld    sfstrt (), de
  pop   bc
  ldir
  dec   de
  ld    sf_end (), de
  ret
.lb_078:
  push  hl
  add   hl, bc
  ex    de, hl
  pop   hl
  ret
.lb_076:
  ld    hl, () sfstrt
.lb_076_loop:
  ld    a, (hl)
  cp    # $00
  ret   z
  inc   hl
  ld    e, (hl)
  inc   hl
  ld    d, (hl)
  ex    de, hl
  push  hl
  add   hl, bc
  ex    de, hl
  ld    (hl), d
  dec   hl
  ld    (hl), e
  pop   hl
  jr    # .lb_076_loop


@lb_079:
  ld    d, a
  ld    a, b
  or    a
  ret   z
  ld    a, c
  or    a
  ret   z
  ld    a, d
  push  af
  push  bc
  call  # ltk_find_sprite_from_a_carry_on_failure
  call  nc, # lb_080
  pop   bc
  pop   af
  ld    hl, () sf_end
  ld    (hl), a
  inc   hl
  push  bc
  push  hl
  ld    l, b
  ld    h, # $00
  ld    d, h
  ld    e, l
  add   hl, hl
  add   hl, hl
  add   hl, hl
  add   hl, de
  ld    d, # $00
  ld    e, c
  call  # lb_107
  pop   de
  add   hl, de
  inc   hl
  inc   hl
  inc   hl
  inc   hl
  ex    de, hl
  ld    (hl), e
  inc   hl
  ld    (hl), d
  inc   hl
  pop   bc
  ld    (hl), c
  inc   hl
  ld    (hl), b
  ld    sf_end (), de
  xor   a
  ld    (de), a
  ret

@lb_080:
  push  bc
  ld    h, b
  ld    l, c
  call  # lb_074
  pop   hl
  ex    de, hl
  call  # lb_106
  push  hl
  push  de
  ex    de, hl
  jr    # lb_082
@lb_081:
  call  # lb_074
  ex    de, hl
  push  hl
  or    a
  sbc   hl, bc
  ex    de, hl
  ld    (hl), d
  dec   hl
  ld    (hl), e
  pop   hl
@lb_082:
  ld    a, (hl)
  or    a
  jr    nz, # lb_081
  ld    hl, () sf_end
  pop   de
  or    a
  sbc   hl, bc
  ld    sf_end (), hl
  add   hl, bc
  sbc   hl, de
  ld    b, h
  ld    c, l
  ld    a, b
  or    c
  pop   hl
  ex    de, hl
  jr    z, # lb_083
  ldir
@lb_083:
  xor   a
  ld    (de), a
  ret
@lb_084:
  push  af
  ld    b, c
@lb_085:
  ld    a, (de)
  or    (hl)      ;; this instruction is modified elsewhere
  ld    (de), a
  inc   de
  inc   hl
  djnz  # lb_085
  pop   af
  ret
@lb_086:
  ld    lb_088 1 + (), a
  ld    a, # $cd
  ld    lb_096 1 + (), a
  push  hl
@lb_087:
  ld    hl, # lb_084
  ld    lb_096 2 + (), hl
  pop   hl
@lb_088:
  ld    a, # $00
  call  # lb_093
  xor   a
  ld    lb_096 1 + (), a
  ld    lb_096 (), a
  push  hl
  call  # lb_092 3 +
  jp    # lb_090
@lb_089:
  push  hl
  ld    hl, # $B0ED   ;; "ldir"
  ld    lb_096 2 + (), hl
  pop   hl
  scf
  ret
@lb_090:
  pop   hl
  jr    # lb_089

@lb_091:
  ld    hl, # lb_085 1 +
  ld    (hl), # $AE   ;; "xor (hl)"
@lb_092:
  call  # lb_151
  ld    hl, # lb_085 1 +
  ld    (hl), # $B6   ;; "or (hl)"
  ret

@lb_093:
  ld    lb_069_vars (), a
  call  # lb_check_bc_hl_winxywh_carry_on_success
  ret   nc
  ld    a, () lb_069_vars
  ld    lb_096 (), a
  ld    lb_096 4 + (), a
  ld    lb_102 (), a
  ld    lb_103 (), a
  push  hl
  push  bc
  push  hl

  ;;k8: this was the routine, but it seems to be used only once,
  ;;    so i moved it here.
  ;; call  # lb_calc_cscradr_from_bc_to_hl
  ;; calculate scr$ character address
  ;; IN:
  ;;   BC: yx
  ;; OUT:
  ;;   HL: scr$
  ;;   AF: destroyed
  ;;   BC: might be destroyed too (if using variable scr$)
  \ @lb_calc_cscradr_from_bc_to_hl:
  OPT-LASERLIB-USE-VARIABLE-SCR$? [IF]
  ;;k8: old code
    ld    a, # $07
    and   b
    rrca
    rrca
    rrca
    or    c
    ld    c, a
    ld    a, b
    and   # $18
    ld    b, a
    ld    hl, () scr_ac
    add   hl, bc
  [ELSE]
  ;;k8: new code
    ld    a, b
    and   # $18
    or    # $40
    ld    h, a
    ld    a, b
    rrca
    rrca
    rrca
    and   # $E0
    or    c
    ld    l, a
  [ENDIF]
  \ ret

  pop   bc
@lb_094:
  ld    a, #08
  push  hl
  push  bc
  ld    b, #00
@lb_095:
  push  hl
  push  bc
  push  af
@lb_096:
  nop       ;; this instruction is modified elsewhere
  nop       ;; this instruction is modified elsewhere
  ldir      ;; this instruction is modified elsewhere
  nop       ;; this instruction is modified elsewhere
  pop   af
  pop   bc
  pop   hl
  dec   a
  jr    z, # lb_097
  inc   h
  jr    # lb_095
@lb_097:
  pop   bc
  pop   hl
  dec   b
  jr    z, # lb_098
  ld    a, # $20
  add   a, l
  ld    l, a
  jr    nc, # lb_094
  ld    a, h
  and   # $58
  add   a, # $08
  cp    # $58
  jr    z, # lb_098
  ld    h, a
  jr    # lb_094
@lb_098:
  pop   hl
  pop   bc
  scf
  ret

@lb_100:
  call  # lb_093
  ret   nc
  call  # lb_105
@lb_101:
  push  hl
  push  bc
  ld    b, # $00
@lb_102:
  nop
  ldir
@lb_103:
  nop
  pop   bc
  pop   hl
  dec   b
  ret   z
  ld    a, l
  add   a, # $20
  jr    nc, # lb_104
  inc   h
@lb_104:
  ld    l, a
  jr    # lb_101
@lb_105:
  OPT-LASERLIB-USE-VARIABLE-ATTR? [IF]
  ;;k8: old code
    ld    a, l
    ld    l, h
    ld    h, # $00
    add   hl, hl
    add   hl, hl
    add   hl, hl
    add   hl, hl
    add   hl, hl
    add   a, l
    ld    l, a
    push  de
    ld    de, () scra_a
    add   hl, de
    pop   de
  [ELSE]
  ;; k8: new code
    ;; IN:
    ;;   H: y
    ;;   L: x
    ;; OUT:
    ;;   HL: scr$addr
    ;;   AF: dead
    ;;   carry flag: reset
    ld    a, h
    rrca
    rrca
    rrca
    ld    h, a
    ;; low byte
    and   # $E0
    or    l
    ld    l, a
    ;; high byte
    ld    a, h
    and   # $03
    or    # $58
    ld    h, a
  [ENDIF]
  ret
@lb_106:
  and   a
  sbc   hl, de
  ld    b, h
  ld    c, l
  add   hl, de
  ex    de, hl
  ret
@lb_107:
  push  bc
  ld    b, # $10
  ld    a, h
  ld    c, l
  ld    hl, # $0000
@lb_108:
  add   hl, hl
  jr    c, # lb_110
  rl    c
  rla
  jr    nc, # lb_109
  add   hl, de
  jr    c, # lb_110
@lb_109:
  djnz  # lb_108
@lb_110:
  pop   bc
  ret
@lb_111:
  ld    lb_179 (), de
  ld    a, b
  ld    b, c
  push  bc
  call  # lb_189
  ld    bc, () lb_075_wvar
  ld    b, # $00
  ld    lb_212_wvar_0 (), bc
  ld    bc, () lb_075_wvar
  pop   af
  push  bc
  push  af
  ld    de, () lb_179
  jp    # lb_210

(*
@lb_wk_params_addr:
  0 dw, 0 dw,
  0 dw, 0 dw,
*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; internal routine
;;
;; IN:
;;   A: sprite number
;;   B: y0
;;   C: x0
;;   H: height
;;   W: width
;;   D: spr-y0
;;   E: spr-x0
;; TODO: document it!
adjm:
  call  # lb_063_4
  ld    ix, () lb_wk_params_addr
  ld    6 (ix+), d
  ld    7 (ix+), e
@lb_113:
  ld    2 (ix+), b
  ld    3 (ix+), c
  ld    4 (ix+), l
  ld    5 (ix+), h
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; internal routine
;; TODO: document it!
adjv:
  call  # lb_064
  ld    ix, () lb_wk_params_addr
  jr    # lb_113


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; internal routine
;; TODO: document it!
(*
move:
  ld    a, e
  push  de
  push  hl
  push  bc
  call  # ptxr
  pop   bc
  pop   hl
  ld    a, c
  add   a, l
  ld    c, a
  ld    a, b
  add   a, h
  ld    b, a
  pop   de
  ld    a, d
  ld    hl, () lb_wk_params_addr
  inc   hl
  inc   hl
  ld    (hl), b
  inc   hl
  ld    (hl), c
  push  de
  call  # ptxr
  pop   de
  ld    hl, () lb_wk_params_addr
  ld    bc, # 10
  add   hl, bc
  ld    (hl), d
  inc   hl
  ld    (hl), e
  ret
*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get attributes from one sprite to another sprite
;;
;; IN:
;;   B: destinatin sprite index
;;   C: source sprite index
;;   D: y0
;;   E: x0
gmat:
  push  af
  xor   a
@lb_114:
  ld    lb_213 (), a
  ld    lb_214 (), a
  pop   af
  jp    # lb_111


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put attributes from one sprite to another sprite
;;
;; IN:
;;   B: source sprite index
;;   C: destination sprite index
;;   D: y0
;;   E: x0
pmat:
  push  af
  ld    a, # $eb
  jr    # lb_114


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get bitmap from one sprite to another sprite
;;
;; IN:
;;   B: destinatin sprite index
;;   C: source sprite index
;;   D: y0
;;   E: x0
gmbl:
  call  # lb_202
  jp    # lb_187


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get bitmap from one sprite to another sprite using AND
;;
;; IN:
;;   B: destinatin sprite index
;;   C: source sprite index
;;   D: y0
;;   E: x0
gmnd:
  call  # lb_206
  jp    # lb_187


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get bitmap from one sprite to another sprite using OR
;;
;; IN:
;;   B: destinatin sprite index
;;   C: source sprite index
;;   D: y0
;;   E: x0
gmor:
  call  # lb_204
  jp    # lb_187


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get bitmap from one sprite to another sprite using XOR
;;
;; IN:
;;   B: destinatin sprite index
;;   C: source sprite index
;;   D: y0
;;   E: x0
gmxr:
  call  # lb_207
  jp    # lb_187


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put bitmap from one sprite to another sprite
;;
;; IN:
;;   B: source sprite index
;;   C: destination sprite index
;;   D: y0
;;   E: x0
pmbl:
  call  # lb_202
  jp    # lb_164


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put bitmap from one sprite to another sprite using AND
;;
;; IN:
;;   B: source sprite index
;;   C: destination sprite index
;;   D: y0
;;   E: x0
pmnd:
  call  # lb_206
  jp    # lb_164


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put bitmap from one sprite to another sprite using OR
;;
;; IN:
;;   B: source sprite index
;;   C: destination sprite index
;;   D: y0
;;   E: x0
pmor:
  call  # lb_204
  jp    # lb_164


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put bitmap from one sprite to another sprite using XOR
;;
;; IN:
;;   B: source sprite index
;;   C: destination sprite index
;;   D: y0
;;   E: x0
pmxr:
  call  # lb_207
  jp    # lb_164


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite attributes left (cyclical)
;;
;; IN:
;;   A: sprite index
awlm:
  ld    de, # lb_046
  jp    # lb_143


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite attributes right (cyclical)
;;
;; IN:
;;   A: sprite index
awrm:
  ld    de, # lb_048
  jp    # lb_143


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite attributes left
;;
;; IN:
;;   A: sprite index
aslm:
  ld    de, # lb_045
  jp    # lb_143


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite attributes right
;;
;; IN:
;;   A: sprite index
asrm:
  ld    de, # lb_047
  jp    # lb_143


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite attributes up (cyclical)
;;
;; IN:
;;   A: sprite index
atum:
  call  # lb_189
  ld    de, () lb_075_wvar
@lb_115:
  ld    c, e
  ld    b, d
  ld    a, e
  ld    lb_010 1 + (), a
  call  # lb_008
  call  # lb_007 3 +
  ld    hl, # lb_010 1 +
  ld    (hl), # $20
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite attributes down (cyclical)
;;
;; IN:
;;   A: sprite index
atdm:
  call  # lb_146
  push  hl
  ld    l, c
  ld    h, b
  call  # lb_074
  pop   hl
  ex    de, hl
  ld    a, d
  ld    d, # $00
  sbc   hl, de
  ld    d, a
  ld    a, # $52
  ld    lb_011 1 + (), a
  call  # lb_115
  ld    a, # $5a
  ld    lb_011 1 + (), a
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window bitmap left (cyclical?) FIXME
;;
;; IN:
;;   A: sprite index
wl1m:
  ld    de, # lb_037
  jp    # lb_156


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window bitmap right (cyclical?) FIXME
;;
;; IN:
;;   A: sprite index
wr1m:
  ld    de, # lb_034
  jp    # lb_156


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite bitmap left by 8 pixels FIXME
;;
;; IN:
;;   A: sprite index
sl8m:
  ld    de, # lb_045
  jp    # lb_156


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite bitmap right by 8 pixels FIXME
;;
;; IN:
;;   A: sprite index
sr8m:
  ld    de, # lb_047
  jp    # lb_156


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window bitmap left by 8 pixels FIXME
;;
;; IN:
;;   A: sprite index
wl8m:
  ld    de, # lb_046
  jp    # lb_156


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window bitmap right by 8 pixels FIXME
;;
;; IN:
;;   A: sprite index
wr8m:
  ld    de, # lb_048
  jp    # lb_156


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite bitmap right by 4 pixels FIXME
;;
;; IN:
;;   A: sprite index
sr4m:
  ld    hl, # sr1m
  ld    lb_038 1 + (), hl
  jp    # lb_160


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite bitmap left by 4 pixels FIXME
;;
;; IN:
;;   A: sprite index
sl4m:
  ld    hl, # sl1m
  ld    lb_039 1 + (), hl
  jp    # lb_161


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window bitmap right by 4 pixels FIXME
;;
;; IN:
;;   A: sprite index
wr4m:
  ld    hl, # lb_156
  ld    lb_040 1 + (), hl
  jp    # lb_162


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll window bitmap left by 4 pixels FIXME
;;
;; IN:
;;   A: sprite index
wl4m:
  ld    hl, # lb_156
  ld    lb_043 1 + (), hl
  jp    # lb_163


@lb_116_3_db_vars:
  0 db, 0 db, 0 db,


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rotate sprite by 90 degrees
;;
;; IN:
;;   B: destinatin sprite index
;;   C: source sprite index
spnm:
  nop
  ld    a, b
  push  bc
  push  bc
  call  # lb_146
  ld    lb_118_dw_var (), hl
  pop   bc
  ld    a, c
  push  hl
  push  de
  call  # lb_146
  ld    a, () lb_118_dw_var
  cp    h
  jr    nz, # lb_117
  ld    a, () lb_118_dw_var 1 +
  cp    l
  jr    nz, # lb_117
  pop   hl
  pop   bc
  call  # lb_123
  pop   bc
  jr    # lb_118_2
@lb_117:
  pop   hl
  pop   hl
  pop   hl
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; enable attribute transfer
;;
aton:
  push  hl
  ld    hl, # lb_100 3 +
  ld    (hl), # $d0
  pop   hl
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; disable attribute transfer
;;
atof:
  push  hl
  ld    hl, # lb_100 3 +
  ld    (hl), # $c9
  pop   hl
  ret

@lb_118_dw_var:
  0 dw, ;; TODO: document this internal variable!

@lb_118_2:
  ld    a, b
  push  bc
  call  # lb_189
  pop   bc
  ld    a, c
  push  hl
  call  # lb_189
  pop   de
  ex    de, hl
  ld    bc, () lb_118_dw_var
  push  bc
  ld    c, b
  ld    b, # $00
  call  # lb_122
  pop   bc
@lb_119:
  push  de
  call  # lb_120
  pop   de
  dec   de
  djnz  # lb_119
  ret
@lb_120:
  push  bc
  ld    bc, () lb_118_dw_var
  ld    a, b
  ld    b, c
  ld    c, a
@lb_121:
  ld    a, (hl)
  ld    (de), a
  call  # lb_122
  inc   hl
  inc   de
  djnz  # lb_121
  pop   bc
  ret
@lb_122:
  ex    de, hl
  ld    a, b
  ld    b, # $00
  add   hl, bc
  dec   hl
  ld    b, a
  ex    de, hl
  ret
@lb_123:
  push  bc
  ld    c, b
  ld    b, # $00
  call  # lb_122
  pop   bc
  ld    lb_118_dw_var (), bc
@lb_124:
  push  de
  call  # lb_125
  pop   de
  dec   de
  djnz  # lb_124
  ret
@lb_125:
  push  bc
  ld    b, # $08
  ld    a, # $01
@lb_126:
  ld    lb_116_3_db_vars 2 + (), a
  push  de
  call  # lb_127
  pop   de
  inc   hl
  ld    a, lb_116_3_db_vars 2 + ()
  sla   a
  djnz  # lb_126
  pop   bc
  ret
@lb_127:
  ld    a, c
  sla   a
  sla   a
  sla   a
  ld    lb_116_3_db_vars (), a
  dec   hl
  ld    a, # $01
@lb_128:
  rrca
  ld    lb_116_3_db_vars 1 + (), a
  jr    nc, # lb_129
  inc   hl
@lb_129:
  and   (hl)
  ex    de, hl
  jr    z, # lb_130
  ld    a, () lb_116_3_db_vars 2+
  or    (hl)
  ld    (hl), a
@lb_130:
  push  bc
  ld    bc, () lb_118_dw_var
  ld    c, b
  ld    b, # $00
  add   hl, bc
  ex    de, hl
  pop   bc
  ld    a, () lb_116_3_db_vars
  dec   a
  ret   z
  ld    lb_116_3_db_vars (), a
  ld    a, () lb_116_3_db_vars 1 +
  jr    # lb_128


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scale sprite (2x)
;;
;; IN:
;;   B: source sprite index
;;   C: destinatin sprite index
dspm:
  push  bc
  ld    a, b
  call  # lb_146
  ex    (sp), hl
  pop   af
  push  af
  push  af
  push  de
  ld    a, l
  call  # lb_146
  pop   bc
  pop   af
  push  de
  push  bc
  push  af
  pop   de
  ld    a, d
  sla   h
  sub   h
  jr    nz, # lb_137
  ld    a, e
  sla   l
  sub   l
  jr    nz, # lb_137
  srl   l
  srl   h
  ex    (sp), hl
  pop   bc
  push  hl
  ld    h, # $00
  ld    l, b
  add   hl, hl
  add   hl, hl
  add   hl, hl
  push  hl
  ld    a, c
  pop   bc
  pop   hl
  pop   de
@lb_131:
  push  de
  call  # lb_133
  pop   de
  call  # lb_133
  dec   bc
  push  af
  ld    a, b
  or    c
  jr    nz, # lb_132
  pop   af
  jr    # lb_138
@lb_132:
  pop   af
  jr    # lb_131
@lb_133:
  push  af
  push  af
  call  # lb_134
  pop   af
  dec   a
  jr    nz, # lb_133 1 +
  pop   af
  ret
@lb_134:
  ld    a, (de)
  rrc   a
  rrc   a
  rrc   a
  rrc   a
  call  # lb_135
  inc   hl
  call  # lb_135
  inc   hl
  inc   de
  ret
@lb_135:
  call  # lb_136
  call  # lb_136
  call  # lb_136
@lb_136:
  rrca
  rr    (hl)
  sra   (hl)
  ret
@lb_137:
  pop   bc
  pop   bc
  pop   bc
  or    a
  ret
@lb_138:
  pop   bc
  srl   b
  srl   c
@lb_139:
  call  # lb_140
  djnz  # lb_139
  scf
  ret
@lb_140:
  push  de
  call  # lb_141
  pop   de
@lb_141:
  push  bc
  ld    b, c
@lb_142:
  ld    a, (de)
  ld    (hl), a
  inc   hl
  ld    (hl), a
  inc   hl
  inc   de
  djnz  # lb_142
  pop   bc
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mirror sprite attributes
;;
;; IN:
;;   A: sprite index
marm:
  ld    de, # lb_143
  ld    lb_002 1 + (), de
  call  # lb_001
  ld    de, # lb_013
  ld    lb_002 1 + (), de
  ret
@lb_143:
  call  # lb_177
  call  # lb_156
  jp    # lb_159


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mirror sprite bitmap
;;
;; IN:
;;   A: sprite index
mirm:
  ld    de, # lb_049
  jp    # lb_156


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; clear sprite bitmap
;;
;; IN:
;;   A: sprite index
clsm:
  call  # lb_146
  ret   c
  push  de
  call  # lb_145
  xor   a
  ex    (sp), hl
  pop   bc
@lb_144:
  dec   bc
  ld    d, h
  ld    e, l
  inc   de
  ld    (hl), a
  ldir
  ret
@lb_145:
  push  de
  ld    e, h
  ld    h, # $00
  ld    d, # $00
  call  # lb_107
  add   hl, hl
  add   hl, hl
  add   hl, hl
  pop   de
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; set sprite attributes
;;
;; IN:
;;   A: sprite index
;; setv_a: new attributes
setm:
  call  # lb_189
  push  hl
  ld    hl, () lb_075_wvar
  ld    e, h
  ld    h, # $00
  ld    d, # $00
  call  # lb_107
  ex    (sp), hl
  pop   bc
  dec   bc
  ld    a, b
  or    c
  ld    a, () setv_a
  ld    (hl), a
  ret   z
  inc   bc
  jp    # lb_144


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; invert sprite bitmap
;;
;; IN:
;;   A: sprite index
invm:
  ld    de, # lb_053
  jp    # lb_156
@lb_146:
  call  # ltk_find_sprite_from_a_carry_on_failure
  ret   nc
  call  # lb_092 3 +
  call  # lb_150
  call  # lb_152
  call  # lb_155
  call  # lb_157
  call  # lb_158
  call  # lb_165
  call  # lb_159
  call  # lb_160 3 +
  call  # lb_161 3 +
  call  # lb_162 3 +
  call  # lb_163 3 +
  ;; it seems that other registers might be in use, hence this method
  ld    a, # $7C  ;; "ld a, h"
  ld    lb_check_bc_hl_winxywh_carry_on_success (), a
  ld    a, # $80  ;; "add a, b"
  ld    lb_check_bc_hl_winxywh_carry_on_success 1 + (), a
  ld    a, # $E5  ;; "push hl"
  ld    lb_173 (), a
  ret
@lb_147:
  push  bc
  call  # lb_146
  pop   bc
  ret   c
@lb_148:
  ld    a, # $00
  jp    # lb_100
@lb_149:
  ld    hl, # lb_148 1 +
  ld    (hl), # $eb
  call  # lb_147
@lb_150:
  xor   a
  ld    lb_148 1 + (), a
  ret
@lb_151:
  ld    hl, # lb_086
  ld    lb_100 1 + (), hl
  call  # lb_149
@lb_152:
  ld    hl, # lb_093
  ld    lb_100 1 + (), hl
  ret
@lb_153:
  ld    hl, # lb_085 1 +
  ld    (hl), # $a6
  jp    # lb_092
@lb_154:
  ld    hl, # lb_149 4 +
  ld    (hl), # $00
  call  # lb_151
@lb_155:
  ld    a, # $eb
  ld    lb_149 4 + (), a
  ret
sr1m:
  ld    de, # lb_033
@lb_156:
  ld    lb_176 1 + (), de
  call  # sl1m
@lb_157:
  ld    de, # lb_035
  ld    lb_176 1 + (), de
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite vertical (cyclic)
;;
;; IN:
;;   A: sprite index
;;   B: signed distance
wcrm:
  ld    hl, # lb_015 1 +
  ld    lb_181 1 + (), hl
  call  # scrm
@lb_158:
  ld    hl, # scrv
  ld    lb_181 1 + (), hl
  ret
@lb_159:
  push  hl
  ld    hl, # lb_146
  ld    sl1m 1 + (), hl
  ld    hl, # $20cb
  jp    # lb_178
@lb_160:
  call  # sr4v
  ld    hl, # sr1v
  ld    lb_038 1 + (), hl
  ret
@lb_161:
  call  # sl4v
  ld    hl, # sl1v
  ld    lb_039 1 + (), hl
  ret
@lb_162:
  call  # wr4v
  ld    hl, # lb_056
  ld    lb_040 1 + (), hl
  ret
@lb_163:
  call  # wl4v
  ld    hl, # lb_056
  ld    lb_043 1 + (), hl
  ret
@lb_164:
  ld    hl, # lb_174
  ld    lb_188 1 + (), hl
  call  # lb_187
@lb_165:
  ld    hl, # lb_166
  ld    lb_188 1 + (), hl
  ret
@lb_166:
  push  bc
  push  de
  call  # lb_146
  pop   de
  pop   bc
  ld    a, c
@lb_167:
  push  af
  call  # lb_check_bc_hl_winxywh_carry_on_success
  jr    nc, # lb_171
  xor   a
@lb_168:
  ld    lb_183 1 + (), a
  ld    lb_184 (), a
  pop   af
  jr    # lb_170
@lb_169:
  push  af
  call  # lb_check_bc_hl_winxywh_carry_on_success
  jr    nc, # lb_171
  ld    a, # $eb
  jr    # lb_168
@lb_170:
  ld    lb_069_vars 2 + (), hl
  ld    lb_179 (), de
  call  # atof
  push  bc
  call  # lb_146
  push  de
  call  # lb_185
  jr    c, # lb_172
  pop   bc
@lb_171:
  pop   de
  ret
@lb_172:
  ld    a, () lb_179 1 +
  ld    e, a
  ld    d, # $00
  ld    h, # $00
  ld    lb_179 2 + (), hl
  call  # lb_107
  add   hl, hl
  add   hl, hl
  add   hl, hl
  pop   de
  add   hl, de
  ld    d, # $00
  ld    a, () lb_179
  ld    e, a
  add   hl, de
  ld    de, () lb_069_vars 2 +
  ex    de, hl
  pop   bc
@lb_173:
  push  hl      ;; this is modified sometimes to "RET"
  ld    hl, # lb_183
  ld    lb_087 1 + (), hl
  xor   a
  pop   hl
  jp    # lb_057
@lb_174:
  push  bc
  push  de
  call  # lb_146
  pop   de
  pop   bc
  ld    a, c
  jp    # lb_169
sl1m:
  call  # lb_146
  ret   c
  push  de
  push  hl
  pop   bc
  pop   hl
@lb_175:
  sla   b
  sla   b
  sla   b
  ld    a, c
  ld    lb_005 1 + (), a
@lb_176:
  ld    de, # lb_035
  ld    lb_004 1 + (), de
  call  # lb_003
  ld    a, # $20
  ld    lb_005 1 + (), a
  jp    # lb_014
@lb_177:
  push  hl
  ld    hl, # lb_186_2
  ld    sl1m 1 + (), hl
  ld    hl, # $0000
@lb_178:
  ld    lb_175 (), hl
  ld    lb_175 2 + (), hl
  ld    lb_175 4 + (), hl
  pop   hl
  ret
@lb_179:
  nop
  nop
  nop
  nop
  ld    hl, () lb_179 2 +
  ld    h, # $00
  ld    d, # $00
  ld    e, b
  call  # lb_107
  ld    de, () lb_179
  add   hl, de
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scroll sprite vertical
;;
;; IN:
;;   A: sprite index
;;   B: signed distance
scrm:
  push  bc
  call  # lb_146
  pop   bc
  ld    lb_179 (), de
  ld    lb_179 2 + (), hl
  ld    hl, # lb_179 4 +
  ld    lb_022 4 + (), hl
  ld    a, # $c3
  ld    lb_022 3 + (), a
  ld    a, b
  ld    bc, # $0000
  ld    hl, () lb_179 2 +
@lb_181:
  call  # scrv
  ld    a, # $58
  ld    lb_022 3 + (), a
  ld    hl, # $3e51
  ld    lb_022 4 + (), hl
  ret
@lb_182:
  ld    de, () lb_186_dw_var
@lb_183:
  push  de
  ;; FIXME: document this!
  nop
  $ed db, $b0 db,
  nop
@lb_184:
  nop
  pop   de
  ld    hl, () lb_179 2 +
  add   hl, de
  ex    de, hl
  ld    lb_186_dw_var (), de
  ret
@lb_185:
  ld    a, () lb_069_vars 3 +
  ld    c, a
  ld    a, () lb_179 1 +
  add   a, c
  dec   a
  sub   h
  ret   nc
  ld    a, () lb_069_vars 2 +
  ld    c, a
  ld    a, () lb_179
  add   a, c
  dec   a
  sub   l
  ret

@lb_186_dw_var:
  ;; FIXME: document this!
  0 dw,

lb_186_2:
  call  # lb_189
  ld    de, () lb_075_wvar
  ex    de, hl
  ret
@lb_187:
  ld    a, # $C9  ;; "ret"
  ld    lb_173 (), a
  ld    lb_check_bc_hl_winxywh_carry_on_success 1 + (), a
  ld    a, # $37  ;; "scf"
  ld    lb_check_bc_hl_winxywh_carry_on_success (), a
  ld    a, b
  or    a
@lb_188:
  call  # lb_166
  ld    a, # $7C  ;; "ld a, h"
  ld    lb_check_bc_hl_winxywh_carry_on_success (), a
  ld    a, # $80  ;; "add a, b"
  ld    lb_check_bc_hl_winxywh_carry_on_success 1 + (), a
  ld    a, # $E5  ;; "push hl"
  ld    lb_173 (), a
  ld    a, b
  ld    lb_186_dw_var (), de
  ld    de, # lb_182
  jp    # lb_156
@lb_189:
  call  # lb_146
  ld    lb_075_wvar (), hl
  push  de
  ld    d, # $00
  ld    e, h
  ld    h, # $00
  call  # lb_107
  add   hl, hl
  add   hl, hl
  add   hl, hl
  pop   de
  add   hl, de
  ret


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get sprite from the screen
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
gtbl:
  ld    hl, # lb_147
  ld    de, # gwbl
  jp    # lb_196


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get sprite from the screen using OR
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
gtor:
  ld    hl, # lb_154
  ld    de, # gwor
  jp    # lb_196


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get sprite from the screen using XOR
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
gtxr:
  ld    hl, # lb_200
  ld    de, # gwxr
  jp    # lb_196


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get sprite from the screen using AND
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
gtnd:
  ld    hl, # lb_201
  ld    de, # gwnd
  jp    # lb_196


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put sprite to the screen
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
ptbl:
  ld    hl, # lb_149
  ld    de, # pwbl
  jp    # lb_196


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put sprite to the screen using OR
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
ptor:
  ld    hl, # lb_151
  ld    de, # pwor
  jp    # lb_196


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put sprite to the screen using XOR
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
ptxr:
  ld    hl, # lb_091
  ld    de, # pwxr
  jp    # lb_196


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put sprite to the screen using AND
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
ptnd:
  ld    hl, # lb_153
  ld    de, # pwnd
  jp    # lb_196


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get sprite from the screen window
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
gwbl:
  call  # lb_202
  jp    # lb_190


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get sprite from the screen window using OR
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
gwor:
  call  # lb_204
  jp    # lb_190


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get sprite from the screen window using XOR
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
gwxr:
  call  # lb_207
  jp    # lb_190


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get sprite from the screen window using AND
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
gwnd:
  call  # lb_206
  jp    # lb_190


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put sprite to the screen
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
pwbl:
  call  # lb_202
  jp    # lb_195


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put sprite to the screen using OR
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
pwor:
  call  # lb_204
  jp    # lb_195


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put sprite to the screen using XOR
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
pwxr:
  call  # lb_207
  jp    # lb_195


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put sprite to the screen using AND
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
pwnd:
  call  # lb_206
  jp    # lb_195
@lb_190:
  ld    ix, # lb_167
  ld    lb_192 1 + (), ix
  ld    ix, # gwat
@lb_191:
  ld    lb_193 1 + (), ix
  ld    ix, () lb_100 3 +
  push  ix
  push  af
  push  bc
  push  de
  push  hl
  push  ix
@lb_192:
  call  # lb_167
  pop   hl
  ld    lb_100 3 + (), hl
  ld    a, l
  cp    # $d0
  pop   hl
  pop   de
  pop   bc
  jr    nz, # lb_194
  pop   af
@lb_193:
  call  # gwat
  pop   hl
  ld    lb_100 3 + (), hl
  ret
@lb_194:
  pop   af
  jr    # lb_193 3 +
@lb_195:
  ld    ix, # lb_169
  ld    lb_192 1 + (), ix
  ld    ix, # pwat
  jr    # lb_191
@lb_196:
  ld    lb_197 1 + (), hl
  ld    lb_198 1 + (), de
  push  bc
  call  # lb_146
  pop   bc
  ld    d, a
  call  # lb_check_bc_hl_winxywh_carry_on_success
  ld    a, d
@lb_197:
  jp    c, # lb_147
  ld    lb_199_3_db_vars (), a
  call  # lb_059
  ld    a, () lb_199_3_db_vars
  ret   nc
@lb_198:
  jp    # gwbl

@lb_199_3_db_vars: ;; FIXME: document this!
  0 db, 0 db, 0 db,

@lb_200:
  ld    hl, # lb_149 4 +
  ld    (hl), # $00
  call  # lb_091
  jp    # lb_155
@lb_201:
  ld    hl, # lb_149 4 +
  ld    (hl), # $00
  call  # lb_153
  jp    # lb_155
@lb_202:
  push  af
  push  hl
  xor   a
  ld    hl, # $b0ed
@lb_203:
  ld    lb_183 2 + (), a
  ld    lb_183 3 + (), hl
  pop   hl
  pop   af
  ret
@lb_204:
  push  af
  push  hl
  ld    a, # $b6
@lb_205:
  ld    lb_085 1 + (), a
  ld    a, # $cd
  ld    hl, # lb_084
  jr    # lb_203
@lb_206:
  push  af
  push  hl
  ld    a, # $a6
  jr    # lb_205
@lb_207:
  push  af
  push  hl
  ld    a, # $ae
  jr    # lb_205


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get sprite attibutes from the screen
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
gwat:
  push  af
  xor   a
@lb_208:
  ld    lb_213 (), a
  ld    lb_214 (), a
  pop   af
  jr    # lb_209


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; put sprite attibutes to the screen
;;
;; IN:
;;   A: sprite index
;;   B: screen y0
;;   C: screen x0
;;   D: sprite y0
;;   E: sprite x0
;;   H: sprite window height
;;   L: sprite window width
pwat:
  push  af
  ld    a, # $eb
  jr    # lb_208
@lb_209:
  ld    lb_179 (), de
  push  af
  call  # lb_check_bc_hl_winxywh_carry_on_success
  jp    nc, # lb_171
  pop   af
  push  hl
  push  af
  ld    h, b
  ld    l, c
  ld    bc, # $0020
  ld    lb_212_wvar_0 (), bc
  call  # lb_105
@lb_210:
  ex    (sp), hl
  ld    a, h
  call  # lb_217
  pop   de
  ex    de, hl
  ld    bc, () lb_075_wvar
  ld    b, # $00
  ld    lb_212_wvar_1 (), bc
  pop   bc
  call  # lb_215
  ld    a, c
  ret   nc
@lb_211:
  call  # lb_212_4
  djnz  # lb_211
  ret

@lb_212_wvar_0: ;; FIXME: document this!
  0 dw,
@lb_212_wvar_1: ;; FIXME: document this!
  0 dw,

@lb_212_4:
  push  bc
  push  de
  push  hl
  ld    b, # $00
  ld    c, a
@lb_213:
  nop
  ldir
@lb_214:
  nop
  pop   hl
  ld    bc, () lb_212_wvar_0
  add   hl, bc
  ex    (sp), hl
  ld    bc, () lb_212_wvar_1
  add   hl, bc
  pop   de
  pop   bc
  ex    de, hl
  ret
@lb_215:
  push  de
  ld    de, () lb_179
  push  hl
  ld    hl, () lb_075_wvar
  ld    a, d
  add   a, b
  dec   a
  sub   h
  jr    nc, # lb_216
  ld    a, e
  add   a, c
  dec   a
  sub   l
  nop
  nop
@lb_216:
  pop   hl
  pop   de
  ret
@lb_217:
  push  bc
  push  de
  call  # lb_189
  ld    b, h
  ld    c, l
  pop   de
  push  de
  ld    e, d
  ld    d, # $00
  ld    h, # $00
  ld    a, () lb_075_wvar
  ld    l, a
  call  # lb_107
  add   hl, bc
  pop   de
  ld    d, # $00
  add   hl, de
  pop   bc
  ret

@ltk-execute-bc-cw:
  ld    ltk-execute-bc-cw-patch (), bc
  push  hl
  ld    bc, () var_col
  ld    hl, () var_wdt
@ltk-execute-call-pop-hl-ret:
  call  # 0
$here 2- @def: ltk-execute-bc-cw-patch
  pop   hl
  ret

@ltk-execute-bc-sp1-scl:
  ld    ltk-execute-bc-cw-patch (), bc
  push  hl
  ld    bc, () var_sp1
  ld    de, () var_scl
  jp    # ltk-execute-call-pop-hl-ret

@ltk-execute-bc-gwxx:
  ld    ltk-execute-bc-cw-patch (), bc
  push  hl
  ld    a, () var_sp1
  ld    bc, () var_col
  ld    de, () var_scl
  ld    hl, () var_swd
  jp    # ltk-execute-call-pop-hl-ret

@ltk-execute-bc-spra:
  ld    ltk-execute-bc-cw-patch (), bc
  push  hl
  ld    a, () var_sp1
  jp    # ltk-execute-call-pop-hl-ret

@ltk-execute-bc-sp-col:
  ld    ltk-execute-bc-cw-patch (), bc
  push  hl
  ld    a, () var_sp1
  ld    bc, () var_col
  jp    # ltk-execute-call-pop-hl-ret

ltk-do-adjm:
  push  hl
  ld    de, # 0
  ld    var_scl (), de
  ld    bc, () var_col
  ld    hl, () var_wdt
  ld    a, () var_sp1
  call  # adjm
  pop   hl
  ret

ltk-do-adjv:
  push  hl
  ld    bc, () var_col
  ld    hl, () var_wdt
  call  # adjv
  pop   hl
  ret
;code-no-next


;; buffer address for vertical screen scrolling.
;; size: width * scroll_step
: LTK-VSCROLL-BUF-ADDR  ( -- addr )  asm-label: scrl_b ; zx-inline

;; start address of the sprite file
: LTK-SPRFILE-START  ( -- addr )  asm-label: sfstrt ; zx-inline

;; end address of the sprite file
: LTK-SPRFILE-END  ( -- addr )  asm-label: sf_end ; zx-inline

;; attributes for "SETV" and "SETM"
: LTK-SETVM-ATTR@  ( -- attr )  asm-label: setv_a c@ ; zx-inline
: LTK-SETVM-ATTR!  ( attr )  asm-label: setv_a c! ; zx-inline


: LTK-COL@  ( -- val )  asm-label: var_col c@ ; zx-inline
: LTK-ROW@  ( -- val )  asm-label: var_row c@ ; zx-inline
: LTK-HGT@  ( -- val )  asm-label: var_hgt c@ ; zx-inline
: LTK-WDT@  ( -- val )  asm-label: var_wdt c@ ; zx-inline
: LTK-LEN@  ( -- val )  asm-label: var_len c@ ; zx-inline
: LTK-SP1@  ( -- val )  asm-label: var_sp1 c@ ; zx-inline
: LTK-SP2@  ( -- val )  asm-label: var_sp2 c@ ; zx-inline
: LTK-NPX@  ( -- val )  asm-label: var_npx c@ c>s ; zx-inline
: LTK-SCL@  ( -- val )  asm-label: var_scl c@ c>s ; zx-inline
: LTK-SRW@  ( -- val )  asm-label: var_srw c@ c>s ; zx-inline
: LTK-SHG@  ( -- val )  asm-label: var_shg c@ c>s ; zx-inline
: LTK-SWD@  ( -- val )  asm-label: var_swd c@ c>s ; zx-inline

: LTK-COL!  ( val )  asm-label: var_col c! ; zx-inline
: LTK-ROW!  ( val )  asm-label: var_row c! ; zx-inline
: LTK-HGT!  ( val )  asm-label: var_hgt c! ; zx-inline
: LTK-WDT!  ( val )  asm-label: var_wdt c! ; zx-inline
: LTK-LEN!  ( val )  asm-label: var_len c! ; zx-inline
: LTK-SP1!  ( val )  asm-label: var_sp1 c! ; zx-inline
: LTK-SP2!  ( val )  asm-label: var_sp2 c! ; zx-inline
: LTK-NPX!  ( val )  asm-label: var_npx c! c>s ; zx-inline
: LTK-SCL!  ( val )  asm-label: var_scl c! c>s ; zx-inline
: LTK-SRW!  ( val )  asm-label: var_srw c! c>s ; zx-inline
: LTK-SHG!  ( val )  asm-label: var_shg c! c>s ; zx-inline
: LTK-SWD!  ( val )  asm-label: var_swd c! c>s ; zx-inline

: LTK-SPN!  ( val )  asm-label: var_sp1 c! ; zx-inline


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; screen$ manipulation

primitive: MARV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: marv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: AWLV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: awlv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: AWRV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: awrv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: ASLV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: aslv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: ASRV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: asrv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: WCRV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: var_npx (nn)->a
  @label: wcrv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: SCRV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: var_npx (nn)->a
  @label: scrv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: MIRV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: mirv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: INVV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: invv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: SETV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: setv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: CLSV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: clsv #->bc
  @label: ltk-execute-bc-cw call-# ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite file manipulation

primitive: RLCT  ( new-addr )
:codegen-xasm
  restore-tos-hl
  \ push-ix
  @label: rlct call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)

primitive: ISPR  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: var_swd (nn)->hl
  @label: ispr call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)

primitive: SPRT  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: var_swd (nn)->hl
  @label: sprt call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)

primitive: WSPR  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: var_sp1 (nn)->a
  @label: wspr call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)

primitive: DSPR  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: var_sp1 (nn)->a
  @label: dspr call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite attribute control

primitive: ATON  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: aton call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)

primitive: ATOF  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: atof call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite to sprite transfets

primitive: GMAT  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gmat #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PMAT  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: pmat #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GMBL  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gmbl #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GMND  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gmnd #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GMOR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gmor #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GMXR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gmxr #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PMBL  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: pmbl #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PMND  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: pmnd #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PMOR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: pmor #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PMXR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: pmxr #->bc
  @label: ltk-execute-bc-sp1-scl call-# ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite attr scrolling

primitive: AWLM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: awlm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: AWRM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: awrm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: ASLM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: aslm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: ASRM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: asrm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: ATUM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: atum #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: ATDM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: atdm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite bitmap scrolling

primitive: WL1M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: wl1m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: WR1M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: wr1m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: SL8M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: sl8m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: SR8M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: sr8m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: WL8M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: wl8m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: WR8M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: wr8m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: SL4M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: sl4m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: SR4M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: sr4m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: WR4M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: wr4m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: WL4M  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: wl4m #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; comples sprite to sprite operations

primitive: SPNM  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: var_sp1 (nn)->bc
  @label: spnm call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)

primitive: DSPM  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: var_sp1 (nn)->bc
  @label: dspm call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite utilities

primitive: MARM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: marm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: MIRM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: mirm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: CLSM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: clsm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: SETM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: setm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: INVM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: invm #->bc
  @label: ltk-execute-bc-spra call-# ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite vertical scrolling

primitive: WCRM  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: var_sp1 (nn)->a
  @label: var_npx 1- (nn)->bc
  @label: wcrm call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)

primitive: SCRM  ( -- )
:codegen-xasm
  push-tos
  \ push-ix
  @label: var_sp1 (nn)->a
  @label: var_npx 1- (nn)->bc
  @label: scrm call-#
  \ pop-ix
  pop-tos ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite <-> screen$ operations

primitive: GTBL  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gtbl #->bc
  @label: ltk-execute-bc-sp-col call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GTOR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gtor #->bc
  @label: ltk-execute-bc-sp-col call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GTXR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gtxr #->bc
  @label: ltk-execute-bc-sp-col call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GTND  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gtnd #->bc
  @label: ltk-execute-bc-sp-col call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PTBL  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: ptbl #->bc
  @label: ltk-execute-bc-sp-col call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PTOR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: ptor #->bc
  @label: ltk-execute-bc-sp-col call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PTXR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: ptxr #->bc
  @label: ltk-execute-bc-sp-col call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PTND  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: ptnd #->bc
  @label: ltk-execute-bc-sp-col call-# ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite window <-> screen$ window operations

primitive: GWBL  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gwbl #->bc
  @label: ltk-execute-bc-gwxx call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GWOR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gwor #->bc
  @label: ltk-execute-bc-gwxx call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GWXR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gwxr #->bc
  @label: ltk-execute-bc-gwxx call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: GWND  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: gwnd #->bc
  @label: ltk-execute-bc-gwxx call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PWBL  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: pwbl #->bc
  @label: ltk-execute-bc-gwxx call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PWOR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: pwor #->bc
  @label: ltk-execute-bc-gwxx call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PWXR  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: pwxr #->bc
  @label: ltk-execute-bc-gwxx call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: PWND  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: pwnd #->bc
  @label: ltk-execute-bc-gwxx call-# ;
zx-required: (*LASERLIB-CORE*)


primitive: ADJM  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: ltk-do-adjm call-# ;
zx-required: (*LASERLIB-CORE*)

primitive: ADJV  ( -- )
:codegen-xasm
  restore-tos-hl
  @label: ltk-do-adjv call-# ;
zx-required: (*LASERLIB-CORE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; more utilities

code: SPR-FIND  ( index -- addr // 0 )
  ld    a, h
  or    a
  ld    a, l
  jr    nz, # .fail
  call  # ltk_find_sprite_from_a_carry_on_failure
  jr    c, # .fail
  ld    hl, bc
  next
.fail:
  ld    hl, # 0
;code
1 1 Succubus:setters:in-out-args

: SPR-INDEX@  ( addr -- index )  c@ ; zx-inline
: SPR-NEXT@   ( addr -- addr )  1+ c@ ; zx-inline
: SPR-WIDTH@  ( addr -- w )  3 + c@ ; zx-inline
: SPR-HEIGHT@ ( addr -- h )  4 + c@ ; zx-inline
: SPR-DATA^   ( addr -- addr )  5 + ; zx-inline


;; check if the sprite contains only zeroes.
;; non-existing sprite is empty too.
;; the sprite should not be higher than 32 chars.
code: SPR-EMPTY?  ( index -- flag )
  ld    a, h
  or    a
  ld    a, l
  jr    nz, # .empty
  call  # ltk_find_sprite_from_a_carry_on_failure
  jr    c, # .empty
  ;; BC: sprite start address
  ;; DE: sprite data address
  ;; HL: sprite height and width
  ;;  A: sprite number
  ex    de, hl
  ld    a, d
  or    a
  jr    z, # .empty
  add   a, a
  add   a, a
  add   a, a
  ld    d, a
  ld    a, e
  or    a
  jr    z, # .empty
  xor   a
.rows-loop:
  ld    b, e
.cols-loop:
  or    (hl)
  jr    nz, # .non-empty
  inc   hl
  djnz  # .cols-loop
  dec   d
  jp    nz, # .rows-loop
.empty:
  ld    hl, # 1
  next
.non-empty:
  ld    hl, # 0
;code
1 1 Succubus:setters:in-out-args


zxlib-end
