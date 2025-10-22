;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; kempston mouse with arrow support
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$zx-use <stick-scan>

zxlib-begin" arrow/mouse library"

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; arrow rendering

;; 256 bytes of printer buffer
;; we will fill it from the last byte up to the #5B00
;; WARNING! save buffer must be page-aligned, and the whole 256 bytes will be used!
(*
\ $5B00 zxa:@def: arrow-save-buf-addr
asm-label: spr16-big-align-end asm-label: spr16-big-align-start -  16 4 * 4 + >= [IF]
endcr ." ARROW: reused free spr16 space" cr
asm-label: spr16-big-align-start zxa:@def: arrow-save-buf-addr-start
asm-label: spr16-big-align-start 16 4 * 4 + + zxa:@def: arrow-save-buf-addr-end
[ELSE]
zx-here zxa:@def: arrow-save-buf-addr-start
16 4 * 4 + allot
zx-here zxa:@def: arrow-save-buf-addr-end
[ENDIF]
*)
;; this is the official TSTACK used by BASIC when calling +3DOS.
;; according to the official manual, it can extend to $5B7C (inclusive).
;; we need about 100 bytes for 16x16 arrow, so there is more than
;; enough room there.
;; but note that you should hide the arrow before using +3DOS!
$5B7C 2+ zxa:@def: arrow-save-buf-start
$5C00 zxa:@def: arrow-save-buf-end

;; WARNING! +3DOS code expects it to be there!
$5B7C zxa:@def: arrow-save-buf-top


\ " TILE-EDIT arrow"  #SPRITES #SPR-INFO *  zx-ensure-page-with-report
\ asm-label: zx-spr-prop-map constant ARROW-SPRITE
zx-here zxa:@def: arrow-sprite0
0 [IF]
  12 c,
  %00000000 c, %00000000 c, %00111111 c, %11111111 c,
  %01000000 c, %00000000 c, %00011111 c, %11111111 c,
  %01100000 c, %00000000 c, %00001111 c, %11111111 c,
  %01110000 c, %00000000 c, %00000111 c, %11111111 c,
  %01111000 c, %00000000 c, %00000011 c, %11111111 c,
  %01111100 c, %00000000 c, %00000001 c, %11111111 c,
  %01111110 c, %00000000 c, %00000000 c, %11111111 c,
  %01111111 c, %00000000 c, %00000000 c, %01111111 c,
  %01110000 c, %00000000 c, %00000000 c, %01111111 c,
  %01100000 c, %00000000 c, %00001111 c, %11111111 c,
  %01000000 c, %00000000 c, %00011111 c, %11111111 c,
  %00000000 c, %00000000 c, %00111111 c, %11111111 c,
zx-here zxa:@def: arrow-sprite1
  12 c,
  %00000000 c, %00000000 c, %00111111 c, %11111111 c,
  %01000000 c, %00000000 c, %00011111 c, %11111111 c,
  %01100000 c, %00000000 c, %00001111 c, %11111111 c,
  %01010000 c, %00000000 c, %00000111 c, %11111111 c,
  %01001000 c, %00000000 c, %00000011 c, %11111111 c,
  %01000100 c, %00000000 c, %00000001 c, %11111111 c,
  %01000010 c, %00000000 c, %00000000 c, %11111111 c,
  %01001111 c, %00000000 c, %00000000 c, %01111111 c,
  %01010000 c, %00000000 c, %00000000 c, %01111111 c,
  %01100000 c, %00000000 c, %00001111 c, %11111111 c,
  %01000000 c, %00000000 c, %00011111 c, %11111111 c,
  %00000000 c, %00000000 c, %00111111 c, %11111111 c,
zx-here zxa:@def: arrow-sprite-pressed
  12 c,
  %00000000 c, %00000000 c, %00111111 c, %11111111 c,
  %01000000 c, %00000000 c, %00011111 c, %11111111 c,
  %01100000 c, %00000000 c, %00001111 c, %11111111 c,
  %01010000 c, %00000000 c, %00000111 c, %11111111 c,
  %01101000 c, %00000000 c, %00000011 c, %11111111 c,
  %01010100 c, %00000000 c, %00000001 c, %11111111 c,
  %01101010 c, %00000000 c, %00000000 c, %11111111 c,
  %01011111 c, %00000000 c, %00000000 c, %01111111 c,
  %01110000 c, %00000000 c, %00000000 c, %01111111 c,
  %01100000 c, %00000000 c, %00001111 c, %11111111 c,
  %01000000 c, %00000000 c, %00011111 c, %11111111 c,
  %00000000 c, %00000000 c, %00111111 c, %11111111 c,
[ELSE]
  8 c,
  %11111111 c, %10000000 c, %00000000 c, %01111111 c,
  %01000000 c, %10000000 c, %10000000 c, %01111111 c,
  %00100000 c, %10000000 c, %11000000 c, %01111111 c,
  %00010000 c, %01100000 c, %11100000 c, %00011111 c,
  %00001001 c, %10011000 c, %11110000 c, %00000111 c,
  %00000110 c, %01100110 c, %11111001 c, %10000001 c,
  %00000000 c, %00011001 c, %11111111 c, %11100000 c,
  %00000000 c, %00000110 c, %11111111 c, %11111001 c,
zx-here zxa:@def: arrow-sprite1
  8 c,
  %11111111 c, %10000000 c, %00000000 c, %01111111 c,
  %01010101 c, %10000000 c, %10000000 c, %01111111 c,
  %00101010 c, %10000000 c, %11000000 c, %01111111 c,
  %00010101 c, %01100000 c, %11100000 c, %00011111 c,
  %00001011 c, %10011000 c, %11110000 c, %00000111 c,
  %00000110 c, %01100110 c, %11111001 c, %10000001 c,
  %00000000 c, %00011001 c, %11111111 c, %11100000 c,
  %00000000 c, %00000110 c, %11111111 c, %11111001 c,
zx-here zxa:@def: arrow-sprite-pressed
  8 c,
  %11111111 c, %10000000 c, %00000000 c, %01111111 c,
  %01000000 c, %10000000 c, %10000000 c, %01111111 c,
  %00101110 c, %10000000 c, %11000000 c, %01111111 c,
  %00010110 c, %01100000 c, %11100000 c, %00011111 c,
  %00001001 c, %10011000 c, %11110000 c, %00000111 c,
  %00000110 c, %01100110 c, %11111001 c, %10000001 c,
  %00000000 c, %00011001 c, %11111111 c, %11100000 c,
  %00000000 c, %00000110 c, %11111111 c, %11111001 c,
[ENDIF]

create ARROW-SPRS
  asm-label: arrow-sprite0 ,
  asm-label: arrow-sprite1 ,
create;


raw-code: (*ARROW-DRAW-DON'T-USE*)
  ret

arrow-last-x:   0 db,
arrow-last-y: 255 db,

arrow-draw:
  ;; save all registers (except HL and AF)
  push  de
  push  bc
  ex    af, afx
  push  af
  exx
  push  hl
  push  de
  push  bc

  call  # arrow-check-save-buffer
  jr    z, # .draw-it-now
  ;; check if coords were changed
  ld    hl, () arrow-last-x
  ld    de, () arrow-coord-x
  ld    a, l
  xor   e
  jr    nz, # .draw-it-now
  ld    a, h
  xor   d
  jp    z, # .print-exit

.draw-it-now:
  ;; we cannot use stack properly from now on
  ld    arrow-blitter-saved-sp (), sp
  ;; restore screen using the stack
  ld    sp, () arrow-save-buf-top
.restore_loop:
  ;; pop address
  pop   hl
  ld    a, h
  or    a
  jr    z, # .restore_done
  ;; pop 4 bytes
  pop   de
  pop   bc
  ;; write 3 bytes
  ld    (hl), e
  inc   l
  ld    (hl), d
  inc   l
  ld    (hl), c
  jp    # .restore_loop

.badycoord:
  ld    sp, () arrow-blitter-saved-sp
  call  # arrow-reset-save-buffer
  jp    # .print-done

.restore_done:
  ;; set arrow coordinates
  ld    de, # $3026   ;; coords
$here 2- @def: arrow-coord-x
$here 1- @def: arrow-coord-y
  ;; calculate screen address from DE to HL
  ld    a, d
  cp    # 192
  ;; untaken JR is 3t faster than JP
  jr    nc, # .badycoord
  and   a
  rra
  scf
  rra
  and   a
  rra
  xor   d
  and   # $F8
  xor   d
  ld    h, a
  ld    a, e
  rlca
  rlca
  rlca
  xor   d
  and   # $C7
  xor   d
  rlca
  rlca
  ld    l, a
  ;; HL now contains screen address

  ld    a, e
  and   # $07
  ;; A now contains shift
  ex    af, afx

  ;; save screen address, we'll need it again for drawing the arrow
  ;; sadly, cannot use stack here
  ld    arrow-screen-addr (), hl

  ;; we will use "push" to save data
  ld    sp, # arrow-save-buf-end  ;; move to the end of the buffer

  ;; save address with zero high byte
  xor   a
  push  af
  ;; save screen
  ld    a, () arrow-sprite0 ;; arrow height
$here 2- @def: arrow-sprite-addr
  ld    b, a
  jp    # .arrow-save-skip-one-down
.arrow-save-loop:
  ;; HL: screen address
  ;; SP: save buffer addrress
  ;; down-hl
  inc   h
  ld    a, h
  and   # $07
  jp    nz, # .save-down-hl-ok
  ld    a, l
  sub   # $E0
  ld    l, a
  sbc   a, a
  and   # $F8
  add   a, h
  ld    h, a
  cp    # $58
  jr    nc, # .save-done
.save-down-hl-ok:
.arrow-save-skip-one-down:
  ;; copy 3 bytes of data
  ld    e, (hl)
  inc   l
  ld    d, (hl)
  inc   l
  ld    c, (hl)
  push  bc
  push  de
  ;; save 1t
  dec   l
  dec   l
  ;; save screen address
  push  hl
  djnz  # .arrow-save-loop
.save-done:
  ;; done saving screen pixels
  ld    arrow-save-buf-top (), sp

  ;; restore SP, we'll do our arrow the usual way
  ld    sp, # 0       ;; self-modifying code
$here 2- @def: arrow-blitter-saved-sp

  ld    de, # 0       ;; scr$ address, self-modifying code
$here 2- @def: arrow-screen-addr

  ex    af, afx       ;; restore shift
  neg
  and   # $07
  ld    b, a          ;; shift

  ld    hl, () arrow-sprite-addr
  ld    a, (hl)       ;; arrow height
  inc   hl

  exx
  ld    b, a          ;; line count
  exx
  jp    # .arrow-line-loop-skip-down
  ;; load arrow
.arrow-line-loop:
  exx
  ;; down-de
  inc   d
  ld    a, d
  and   # $07
  jp    nz, # .print-down-hl-ok
  ld    a, e
  sub   # $E0
  ld    e, a
  sbc   a, a
  and   # $F8
  add   a, d
  ld    d, a
  cp    # $58
  jr    nc, # .print-done
.print-down-hl-ok:
.arrow-line-loop-skip-down:
  ;; sprite
  ;; check shift
  ld    c, b          ;; save shift
  ld    a, b
  or    a
  ld    a, (hl)
  inc   hl
  push  hl
  jp    nz, # .print-do-shift
  ld    h, (hl)
  ld    l, # 0
  jp    # .print-shift-done
.print-do-shift:
  ld    l, (hl)
  ld    h, a
  xor   a
.print-shift-bytes:
  add   hl, hl
  rla
  djnz  # .print-shift-bytes
.print-shift-done:
  ;; AHL=arrow
  ld    arrow-print-xor-1st (), a
  ld    a, h
  ld    arrow-print-xor-2nd (), a
  ld    a, l
  ld    arrow-print-xor-3rd (), a

  ;; mask
  pop   hl
  inc   hl

  ld    a, c
  or    a
  ld    a, (hl)
  inc   hl
  push  hl
  jp    nz, # .print-do-shift-mask
  ld    h, (hl)
  ld    l, # $FF
  jp    # .print-shift-done-mask
.print-do-shift-mask:
  ld    l, (hl)
  ld    h, a
  ld    a, # $FF
  ld    b, c
.print-shift-bytes-mask:
  add   hl, hl
  inc   l
  rla
  djnz  # .print-shift-bytes-mask
.print-shift-done-mask:
  ;; AHL=arrow
  ld    arrow-print-and-1st (), a
  ld    a, h
  ld    arrow-print-and-2nd (), a
  ld    a, l
  ld    arrow-print-and-3rd (), a

  ld    b, c          ;; restore shift

  ld    c, e          ;; save E, cheaper than push
  ;; first byte
  ld    a, (de)
  and   # $FF         ;; self-modifying code
$here 1- @def: arrow-print-and-1st
  xor   # $00         ;; self-modifying code
$here 1- @def: arrow-print-xor-1st
  ld    (de), a
  ;; second byte
  inc   e
  ld    a, e
  and   # $1F
  jr    z, # .print-horiz-done
  ld    a, (de)
  and   # $FF         ;; self-modifying code
$here 1- @def: arrow-print-and-2nd
  xor   # $00         ;; self-modifying code
$here 1- @def: arrow-print-xor-2nd
  ld    (de), a
  ;; third byte
  inc   e
  ld    a, e
  and   # $1F
  jr    z, # .print-horiz-done
  ld    a, (de)
  and   # $FF         ;; self-modifying code
$here 1- @def: arrow-print-and-3rd
  xor   # $00         ;; self-modifying code
$here 1- @def: arrow-print-xor-3rd
  ld    (de), a
.print-horiz-done:
  ld    e, c          ;; restore scr$

  pop   hl            ;; restore arrow data address
  inc   hl

  exx
  dec   b
  jp    nz, # .arrow-line-loop
  \ djnz  # .arrow-line-loop

.print-done:
  ld    hl, () arrow-coord-x
  ld    arrow-last-x (), hl

  ;; restore all registers
.print-exit:
  pop   bc
  pop   de
  pop   hl
  exx
  pop   af
  ex    af, afx
  pop   bc
  pop   de

  ret

;; HL is dead
@arrow-reset-save-buffer:
  ld    hl, # arrow-save-buf-end 1-
  ld    (hl), # 0
  dec   hl
  ld    arrow-save-buf-top (), hl
  ret

;; HL is dead, zero flag is set if the arrow is hidden
@arrow-check-save-buffer:
  ld    hl, () arrow-save-buf-top
  inc   hl
  ld    a, (hl)
  or    a
  ret
;code-no-next


;; save pixels under the arrow, draw the arrow.
;; this code sux, but i don't care.
code: ARROW-DRAW  ( x y )
  pop   de
  ld    h, l
  ld    l, e
  ld    arrow-coord-x (), hl
  call  # arrow-draw
  pop   hl
;code
2 0 Succubus:setters:in-out-args
zx-required: (*ARROW-DRAW-DON'T-USE*)


: ARROW-DEFAULT!
  asm-label: arrow-sprite0 ARROW-SPRS !
  asm-label: arrow-sprite1 ARROW-SPRS 2+ ! ;

: ARROW-PRESSED!
  asm-label: arrow-sprite-pressed dup ARROW-SPRS ! ARROW-SPRS 2+ ! ;


;; disable restoring of saved area
raw-code: ARROW-NO-RESTORE
  ex    de, hl
  ld    hl, # arrow-save-buf-end 1-
  ld    (hl), # 0
  dec   hl
  ld    arrow-save-buf-top (), hl
  ex    de, hl
;code
0 0 Succubus:setters:in-out-args

;; is arrow visible (i.e. rendered)?
code: ARROW-VISIBLE?  ( -- bool )
  push  hl
  ld    hl, () arrow-save-buf-top
  inc   hl
  ld    a, (hl)
  or    a
  ld    hl, # 0
  jr    z, # .done
  inc   l
.done:
;code
0 1 Succubus:setters:in-out-args
Succubus:setters:out-bool

code: ARROW-XY@  ( -- x y )
  push  hl
  ld    hl, () arrow-coord-x
  ;; L:x; H:y
  ld    e, l
  ld    d, # 0
  push  de
  ld    l, h
  ld    h, d
;code
0 2 Succubus:setters:in-out-args
Succubus:setters:out-8bit
zx-required: (*ARROW-DRAW-DON'T-USE*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mouse IM2 handler

false quan KMOUSE?
false quan ZXEMUT-MOUSE?
false quan MCUR-ENABLED?
0 quan KM-XY
0 quan (KM-BUTT)

: KM-BUTT  ( -- n )  (km-butt):c@ ; zx-inline

code: KM-XY@  ( -- x y )
  push  hl
  ld    hl, () zx-['pfa] KM-XY
  ;; L:x; H:y
  ld    e, l
  ld    d, # 0
  push  de
  ld    l, h
  ld    h, d
;code
0 2 Succubus:setters:in-out-args
Succubus:setters:out-8bit
zx-required: KM-XY

;; character coords, packed
code: KM-PK-CXY@  ( -- x/y )
  push  hl
  ld    hl, () zx-['pfa] KM-XY
  ;; L:x; H:y
  ld    a, l
  rra
  rra
  rra
  and   a, # $1F
  ld    l, a
  ld    a, h
  rra
  rra
  rra
  and   a, # $1F
  ld    h, a
;code
0 1 Succubus:setters:in-out-args
zx-required: KM-XY

;; character coords
: KM-CXY@  ( -- x y )  KM-PK-CXY@ SPLIT-BYTES ; zx-inline


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; arrow movement with acceleration.
;; used for keyboard/joystick control.

$50 zxa:@def: ARROW-ACCEL-WAIT-INIT
0 zxa:@def: INP-BIT-LEFT
1 zxa:@def: INP-BIT-RIGHT
2 zxa:@def: INP-BIT-UP
3 zxa:@def: INP-BIT-DOWN
4 zxa:@def: INP-BIT-FIRE
5 zxa:@def: INP-BIT-FIRE2   ;; to emulate right mouse button

raw-code: (*AMOVE-ACCEL-DON'T-USE*)
  ret
;; IN:
;;  A: input stick state
;; OUT:
;;  BC, DE, HL, AF: dead
arrow-do-accel-movement:
  ld    c, a
  and   # $0F
  jr    z, # arrow-reset-accel-and-exit

  ld    hl, () arrow-coord-x

  ld    a, () arrow-accel
  and   # $0F
  ld    b, a
  jr    z, # .accel-wait

.do-one-move:
  bit   INP-BIT-RIGHT #, c
  call  nz, # .go-right
  bit   INP-BIT-LEFT #, c
  call  nz, # .go-left
  bit   INP-BIT-DOWN #, c
  call  nz, # .go-down
  bit   INP-BIT-UP #, c
  call  nz, # .go-up

  ld    arrow-coord-x (), hl
  ld    zx-['pfa] KM-XY (), hl

  ld    a, () arrow-accel
  ld    b, a
  and   # $0F
  \ jr    z, # .loop
  ret   z
  ld    a, b
  add   a, # $20
  jp    m, # .accel-next
.accel-done:
  ld    arrow-accel (), a
  \ jr    .loop
  ret
.accel-next:
  inc   a
  and   # $0F
  jr    nz, # .accel-done
  ld    a, # $0F
  jr    # .accel-done

.accel-wait:
  ld    a, () arrow-accel
  sub   a, # $10
  and   # $F0
  jr    nz, # $ 3 +       ;; jump over "inc a"
  inc   a
  ld    arrow-accel (), a
  cp    # ARROW-ACCEL-WAIT-INIT $10 -
  \ jr    nz, # .loop
  ret   nz
  ;; first move
  ld    b, # 1
  jr    # .do-one-move

.go-left:
  ld    a, b
  ld    e, a
  ld    a, l
  sub   e
  ld    l, a
  ret   nc
  ld    l, # 0
  ret

.go-right:
  ld    a, b
  add   a, l
  ld    l, a
  ret   nc
  ld    l, # 255
  ret

.go-up:
  ld    a, b
  ld    e, a
  ld    a, h
  sub   e
  ld    h, a
  ret   nc
  ld    h, # 0
  ret

.go-down:
  ld    a, b
  add   a, h
  ld    h, a
  jr    c, # .go-down-bad
  cp    # 192
  ret   c
.go-down-bad:
  ld    h, # 191
  ret

arrow-reset-accel-and-exit:
  ld    a, # ARROW-ACCEL-WAIT-INIT
  ld    arrow-accel (), a
  ret

arrow-accel: [@@] ARROW-ACCEL-WAIT-INIT db,
;code-no-next

;; perform movement. doesn't reset acceleration if only fire is pressed.
;; changes arrow coords, and kempston mouse coords on movement.
primitive: AMOVE-ACCEL  ( inp-byte )
Succubus:setters:out-8bit
zx-required: (*AMOVE-ACCEL-DON'T-USE*)
:codegen-xasm
  restore-tos-hl
  l->a
  @label: arrow-do-accel-movement call-#
  pop-tos ;

primitive: AMOVE-RESET-ACCEL  ( -- )
zx-required: (*AMOVE-ACCEL-DON'T-USE*)
:codegen-xasm
  push-tos
  @label: arrow-reset-accel-and-exit call-#
  pop-tos ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IM2 handler with kempston mouse support.

raw-code: KMOUSE-IM2
  push  hl
  call  # kmouse-read
  pop   hl
  ret
kmouse-lastval-x: 0 db,
kmouse-lastval-y: 0 db,

kmouse-prev-xy: 0 dw,

kmouse-im2-proc:
  call  # kmouse-read
  jp    # 0  ;; self-modifying code
$here 2- @def: kmouse-prev-im2-proc

kmouse-read:
  push  bc
  push  de

  ;; read kmouse
  ld    a, () zx-['pfa] KMOUSE?
  or    a
  \ ret   z
  jp    nz, # .do-mouse-scan
  ;; reset buttons if we don't have a mouse
  ld    zx-['pfa] (KM-BUTT) (), a
  jr    # .mouse-scan-complete

.do-mouse-scan:
  ld    a, () zx-['pfa] ZXEMUT-MOUSE?
  or    a
  jp    z, # .normal-kmouse

.read-zxemut-kmouse:
  ld    bc, # $FBDF   ;; mouse x
  in    a, (c)
  ld    l, a
  ld    b, # $FF      ;; mouse y
  in    a, (c)
  ld    h, a
  jr    # .mouse-set-new-coords

.normal-kmouse:
  ;; normal kmouse
  ld    de, () kmouse-lastval-x
  ld    hl, () zx-['pfa] KM-XY
  ld    bc, # $FBDF   ;; mouse x
  in    a, (c)
  ld    kmouse-lastval-x (), a
  sub   e
  jr    z, # .doy     ;; no x move
  jp    p, # .right
  ;; mouse moved left
  add   a, l          ;; l is negative
  jr    c, # $ 3 +    ;; skip next instr
  xor   a
  ld    l, a
  jr    # .moved_x
  ;; mouse moved right
.right:
  add   a, l
  jr    nc, # $ 4 +   ;; skip next instr
  ld    a, # 255
  ld    l, a
.moved_x:

.doy:
  ld    b, # $FF      ;; mouse y
  in    a, (c)
  ld    kmouse-lastval-y (), a
  sub   d
  jr    z, # .noy
  neg
  jp    p, # .down
  ;; mouse moved up
  add   a, h        ;; h is negative
  jr    c, # $ 3 +  ;; skip next instr.
  xor   a
  ld    h, a
  jr    # .moved_y
  ;; mouse moved down
.down:
  add   a, h
  jr    c, # .fixdown
  cp    # 192
  jr    c, # $ 4 +  ;; skip next instr.
.fixdown:
  ld    a, # 191
  ld    h, a
.moved_y:
.noy:

  \ ld    zx-['pfa] KM-XY (), hl
  \ jr    # .check-buttons
  \ jp    # .mouse-set-new-coords

.mouse-set-new-coords:
  ;; HL=new coords
  ;; set new coords only if the mouse was moved
  ex    de, hl
  ld    hl, () kmouse-prev-xy
  or    a
  sbc   hl, de
  jr    z, # .check-buttons
  ex    de, hl
  ld    zx-['pfa] KM-XY (), hl
  ld    kmouse-prev-xy (), hl

.check-buttons:
  ld    b, # $FA      ;; buttons
  in    a, (c)
  cpl
  and   # $07
  ld    zx-['pfa] (KM-BUTT) (), a

.mouse-scan-complete:
  ;; read keyboard/joystick input
  ld    de, # zx-['pfa] INP-PREPARED
  call  # read-stick-de
  ld    hl, # zx-['pfa] (KM-BUTT)
  ld    a, c
  ;; shift fire and fire2 to the proper place
  rrca
  rrca
  rrca
  rrca
  and   # $03
  or    (hl)
  ld    (hl), a
  ;; move arrow
  ld    a, c
  call  # arrow-do-accel-movement

  ld    a, () zx-['pfa] MCUR-ENABLED?
  or    a
  jr    z, # .skip-arrow

@arrow-redraw-bc-de-pushed:
.do-arrow-draw:
  ld    hl, () zx-['pfa] arrow-sprs
  ld    a, () sysvar-frames
  and   # $10
  jr    z, # .arrow-ok
  ld    hl, () zx-['pfa] arrow-sprs 2+
.arrow-ok:
  ld    de, () arrow-sprite-addr
  ld    arrow-sprite-addr (), hl  ;; set address anyway
  sbc   hl, de    ;; carry is reset here

  ld    hl, zx-['pfa] KM-XY ()
  ld    a, h
  ld    arrow-coord-y (), a
  ld    a, l
  ld    arrow-coord-x (), a

  ;; force redraw?
  jr    z, # .dont-force-arrow
  inc   a
  ld    arrow-last-x (), a
.dont-force-arrow:
  call  # arrow-draw

.skip-arrow:
  pop   de
  pop   bc
  ret
;code-no-next


;; restore screen under the arrow, disable arrow.
;; can be called several times, but doesn't stack.
;; i.e. calling "ARROW-HIDE" twice will not require
;; two "ARROW-SHOW".
raw-code: ARROW-HIDE
  xor   a
  ld    zx-['pfa] MCUR-ENABLED? (), a

  ld    arrow-hide-saved-sp (), sp
  ld    sp, () arrow-save-buf-top

  exx
.restore_loop:
  ;; pop address
  pop   hl
  ld    a, h
  or    a
  jr    z, # .restore_done
  ;; pop 4 bytes
  pop   de
  pop   bc
  ;; write 3 bytes
  ld    (hl), e
  inc   l
  ld    (hl), d
  inc   l
  ld    (hl), c
  jp    # .restore_loop
.restore_done:

  ld    sp, arrow-hide-saved-sp ()
  call  # arrow-reset-save-buffer

  exx
  ret

arrow-hide-saved-sp: 0 dw,
;code-no-next


;; show the arrow (but don't force-repaint it).
;; allow arrow rendering in the interrupt.
;; can be called several times, but doesn't stack.
;; i.e. calling "ARROW-SHOW" twice will not require two "ARROW-HIDE"s.
raw-code: ARROW-SHOW
  ;; block rendering arrow in the interrupt
  push  hl
  xor   a
  ld    zx-['pfa] MCUR-ENABLED? (), a
  ;; check if the arrow is rendered
  call  # arrow-check-save-buffer
  jr    z, # arrow-force-repaint-do-it
  jr    # arrow-force-repaint-done
;code-no-next


: ARROW-SAVE-HIDE  ( -- prev-state )
  arrow-visible? dup ?< arrow-hide >? ; zx-inline

: ARROW-SAVE-SHOW  ( -- prev-state )
  arrow-visible? dup 0?< arrow-show >? ; zx-inline

: ARROW-RESTORE-STATE  ( prev-state )
  ?< arrow-show >? ; zx-inline


;; show the arrow (or force-repaint it).
;; allow arrow rendering in the interrupt.
;; can be called several times, but doesn't stack.
;; i.e. calling "ARROW-SHOW" twice will not require two "ARROW-HIDE"s.
;; use this after changing arrow sprites.
raw-code: ARROW-SHOW-FORCE
  push  hl
  xor   a
  ld    zx-['pfa] MCUR-ENABLED? (), a

arrow-force-repaint-do-it:
  ld    hl, # 0
  ld    arrow-sprite-addr (), hl  ;; this will force redraw

  ld    hl, # arrow-force-repaint-done
  push  hl
  push  bc
  push  de
  jp    # arrow-redraw-bc-de-pushed

arrow-force-repaint-done:
  ;; (re)enable the arrow
  ld    a, # 1
  ld    zx-['pfa] MCUR-ENABLED? (), a
  pop   hl
;code


;; remove mouse interrupt handler.
;; doesn't hide the arrow, call "ARROW-HIDE" first.
raw-code: DEINIT-KMOUSE
  ex    de, hl
  ld    hl, () kmouse-prev-im2-proc
  ld    a, h
  or    l
  jr    z, # .deinited
  ld    zx-im2-userproc-addr (), hl
  ld    hl, # 0
  ld    kmouse-prev-im2-proc (), hl
  ld    zx-['pfa] KMOUSE? (), hl
  ld    zx-['pfa] ZXEMUT-MOUSE? (), hl
  ld    zx-['pfa] MCUR-ENABLED? (), hl
.deinited:
  ex    de, hl
;code

;; initialise mouse driver and arrow interrupt.
;; the arrow is hidden, call "ARROW-SHOW" to show it.
raw-code: INIT-KMOUSE
  push  hl
  ld    hl, () kmouse-prev-im2-proc
  ld    a, h
  or    l
  jp    nz, # .inited

  di
  \ ld    zx-im2-userproc-addr (), hl
  ld    hl, # 0
  ld    zx-['pfa] KMOUSE? (), hl
  ld    zx-['pfa] ZXEMUT-MOUSE? (), hl
  ld    zx-['pfa] MCUR-ENABLED? (), hl
  ld    zx-['pfa] ZXEMUT-MOUSE? (), hl
  ld    zx-['pfa] KM-XY (), hl
  ld    zx-['pfa] (KM-BUTT) (), hl
  dec   hl
  ld    kmouse-lastval-x (), hl
  ld    kmouse-prev-xy (), hl
  call  # arrow-reset-save-buffer

  ld    de, # zx-['pfa] INP-TBL-OPQAM
  ld    hl, # zx-['pfa] INP-PREPARED
  call  # scan-prepare-stick-tbl

  ei

  ;; check for ZXEmuT mouse
  xor   a
  ld    h, a
  1 [IF]
  $10 $60 zxemut-trap-2b
  ;; a=1: success
  [ENDIF]
  ld    zx-['pfa] ZXEMUT-MOUSE? (), a
  or    a
  jr    nz, # .mouse-check-done

  ;; test for kempston mouse presence
  ;; interrupts must be enabled
  halt
  ld    bc, # $FBDF   ;; mouse x
  in    l, (c)
  ld    b, # $FF      ;; mouse y
  in    a, (c)
  ld    h, a
  ld    kmouse-lastval-x (), hl
  inc   a
  jr    nz, # .msok
  ld    a, l
  inc   a
  jr    nz, # .msok
  ld    bc, # $FADF   ;; mouse buttons
  in    a, (c)
  inc   a
  jr    nz, # .msok
  ;; no mouse
  xor   a
  jr    # .msdone
.msok:
  ld    a, # 1
.msdone:

.mouse-check-done:
  ld    l, a
  ld    h, # 0
  ld    zx-['pfa] KMOUSE? (), hl

  ;; save previous IM2 routine
  ld    hl, () zx-im2-userproc-addr
  ld    kmouse-prev-im2-proc (), hl

  ;; setup new IM2 routine
  ld    hl, # kmouse-im2-proc
  ld    zx-im2-userproc-addr (), hl

  call  # stick-detect-kjoy
  dec   l
  jr    nz, # .no-kjoy
  ld    de, # zx-['pfa] INP-TBL-KJOY
  ld    hl, # zx-['pfa] INP-PREPARED
  call  # scan-prepare-stick-tbl
.no-kjoy:

.inited:
  pop   hl
;code


zxlib-end
