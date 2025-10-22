;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; line drawing
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$zx-require plot <gfx/plot.f>


zxlib-begin" LINE library"


1 [IF]
0 vect GLINE-steep      \ NOOP or SWAP
0 vect GLINE-ystep      \ 1+ or 1-
0 quan GLINE-ly
0 quan GLINE-deltax
0 quan GLINE-deltay

: GLINE-DEC  1- ;
: GLINE-INC  1+ ;
: GLINE-SWAP  SWAP ;

: GLINE  ( x0 y0 x1 y1 )
  rot       ( x0 x1 y1 y0 )
  2swap     ( y1 y0 x0 x1 )
  swap      ( y1 y0 x1 x0 )
  2swap     ( x1 x0 y1 y0 )
  2dup - abs >r   ( x1 x0 y1 y0 | |dy| )
  2over - abs r>  ( x1 x0 y1 y0 |dx| |dy| )
  < ;; dx<dy?
  ?< ['] GLINE-SWAP ;; swap use of x and y
  || 2SWAP ['] NOOP >?
  GLINE-steep:!    ( x1 x0 y0 y1 )
  ;; ensure x1 > x0
  2dup > ?< SWAP 2SWAP SWAP || 2SWAP >?
  2dup > ?< ['] GLINE-DEC || ['] GLINE-INC >? GLINE-ystep:!
  over - abs GLINE-deltay:! GLINE-ly:!
  swap 2dup - dup GLINE-deltax:!
  2/ rot 1+ rot ( error x1+1 x0 )
  do
    i GLINE-ly GLINE-steep plot
    GLINE-deltay - dup 0< ?< GLINE-ly GLINE-ystep GLINE-ly:!  GLINE-deltax + >?
  loop drop ;

: DRAW  ( ex ey )  asm-label: sysvar-coords C@++ SWAP C@ 2SWAP GLINE ;

: DDRAW  ( dx dy )
  asm-label: sysvar-coords C@++ SWAP C@  ( dx dy x0 y0 )
  ROT OVER +  ( dy x0 y0 ey )
  2OVER + SWAP GLINE
  DROP ;


(*
;; this is mostly direct translation of the above code
;; it is quite fast for the fast case (when coords are in range)
code: GLINE  ( x0 y0 x1 y1 -- )
fword_dlf:
fword_fastline_8:
  ;; check plot mode
  ld    a, () plot_mode
  and   # $03
  jp    z, # fflfast_getout

  ld    hl, # ffline_doplot_or
  dec   a
  jr    z, # .pmode_done
  ld    hl, # ffline_doplot_xor
  dec   a
  jr    z, # .pmode_done
  ld    hl, # ffline_doplot_and
.pmode_done:
  ld    fflfast_pixdispatch_addr (), hl

  ;; use this to save BC
  exx

  pop   hl  ;; y1
  ld    fflfast_ycoord1 (), hl
  pop   hl  ;; x1
  ld    fflfast_xcoord1 (), hl
  pop   de  ;; y0
  ld    fflfast_ycoord0 (), de
  pop   hl  ;; x0
  ld    fflfast_xcoord0 (), hl

  ld    hl, () fflfast_ycoord1

  ;; dy=y1-y0
  \ or    a
  sbc   hl, de
  push  af        ;; we'll need carry flag later
  jp    p, # fflfast_dypos
  ;; negate hl
  xor   a
  sub   l
  ld    l, a
  sbc   a, a
  sub   h
  ld    h, a      ;; neg hl
fflfast_dypos:
  ld    fflfast_dy (), hl

  ;; err=(-dy)/2
  xor   a
  sub   l
  ld    l, a
  sbc   a, a
  sub   h
  ld    h, a      ;; neg hl
  sra   h
  rr    l
  ld    fflfast_err (), hl

  ;; put "DEC (HL)" or "INC (HL)" to sy
  ;; get back flags
  pop   af
  ld    a, # $34  ;; INC HL
  adc   a, # 0    ;; change to DEC HL if carry set (i.e. y0 > y1)
  ld    fflfast_sy (), a
  ;; setup UPHL or DOWNHL address
  ld    hl, # ffline_down_hl
  cp    # $34
  jr    z, # .downhlpatchok
  ld    hl, # ffline_up_hl
.downhlpatchok:
  ld    fflfast_updown_hl_addr (), hl

  ld    de, () fflfast_xcoord0
  ld    hl, () fflfast_xcoord1
  or    a
  sbc   hl, de    ;; hl=x1-x0
  push  af        ;; we'll need carry flag later
  jp    p, # fflfast_dxpos
  ;; negate hl
  xor   a
  sub   l
  ld    l, a
  sbc   a, a
  sub   h
  ld    h, a
fflfast_dxpos:
  ;; store dx to two places where we need it
  ld    dxval0 (), hl
  ld    dxval1 (), hl
  ld    bc, hl    ;; store |dx| to bc (temporarily)

  ;; put "DEC (HL)" or "INC (HL)" to sx
  ;; get back flags
  pop   af
  ld    a, # $34  ;; INC HL
  adc   a, # 0    ;; change to DEC HL if carry set (i.e. x0 > x1)
  ld    fflfast_sx (), a
  ld    fflfast_mask_move_addr (), a
  ;; patch mask shift instruction
  cp    # $34
  ld    a, # $0E  ;; RRC (HL)
  jr    z, # fflfast_xmaskpatch_ok
  ld    a, # $06  ;; RLC (HL)
fflfast_xmaskpatch_ok:
  ld    fflfast_mask_shift_addr (), a

  ld    hl, bc    ;; restore |dx|
  ld    de, () fflfast_dy
  or    a
  sbc   hl, de    ;; hl=dx-dy
  jr    c, # fflfast_dygrt
  ;; dx <= dy, change err to dx/2
  ld    hl, bc
  sra   h
  rr    l
  ld    fflfast_err (), hl  ;; then er=dx/2
fflfast_dygrt:

  ;; check if we need 16-bit coords
  ;; first, check high bytes
  ld    hl, # fflfast_xcoord0 1+
  ld    a, (hl)
  ;; 1
  inc   hl
  inc   hl
  or    (hl)
  ;; 2
  inc   hl
  inc   hl
  or    (hl)
  ;; 3
  inc   hl
  inc   hl
  or    (hl)
  jp    nz, # flslow_16
  ;; next, check if both y coords are in [0..191]
  ld    a, () fflfast_ycoord0
  cp    # 192
  jp    nc, # flslow_16
  ld    a, () fflfast_ycoord1
  cp    # 192
  jp    nc, # flslow_16
  ;; ok, we can use fast drawer
  ;; debug
  ;;jp    # flslow_16

  ;; prepare screen address and mask
  ld    hl, () fflfast_xcoord0
  ld    de, () fflfast_ycoord0 1-
  ld    e, l
  call  # scrpixcoord_de
  ld    fflfast_scraddr (), hl
  ;; create mask
  ld    d, a
  inc   d
  ld    a, # $01
.shift:
  rrca
  dec   d
  jp    nz, # .shift
  ld    fflfast_scrmask (), a

  ;; setup coords for comparisons
  ld    a, () fflfast_xcoord0
  ld    l, a
  ld    a, () fflfast_ycoord0
  ld    h, a
  ld    fflfast_xy0 (), hl

  ld    a, () fflfast_xcoord1
  ld    l, a
  ld    a, () fflfast_ycoord1
  ld    h, a
  ld    fflfast_xy1 (), hl

  ;; main loop
fflfast_loop:
  ;; put pixel
  ld    hl, # 0   ;; patched above
$here 2- @def: fflfast_scraddr
fflfast_loop_skip_hl_load:
  ld    a, # 0    ;; patched above
$here 1- @def: fflfast_scrmask
  call  # 0       ;; patched above
$here 2- @def: fflfast_pixdispatch_addr

  ;; check if we reached the destination
  ld    hl, # 0   ;; patched above
$here 2- @def: fflfast_xy0
  ld    de, # 0   ;; patched above
$here 2- @def: fflfast_xy1
  or    a
  sbc   hl, de
  jr    z, # fflfast_done

  ld    hl, # 0   ;; patched above
$here 2- @def: fflfast_err
  ld    bc, hl    ;; save err, we'll need it later
  ld    de, # 0   ;; will be patched
$here 2- @def: dxval0

  or    a
  adc   hl, de
  ld    de, # 0   ;; patched above
$here 2- @def: fflfast_dy
  jp    m, # fflfast_skipxmove  ;; err+dx>0: err-=dy
  ld    hl, bc
  or    a
  sbc   hl, de
  ld    fflfast_err (), hl
  ld    hl, # fflfast_xy0
  dec   (hl)      ;; patched above
$here 1- @def: fflfast_sx
  ;; move mask
  ld    hl, # fflfast_scrmask
  rrc   (hl)      ;; patched above
$here 1- @def: fflfast_mask_shift_addr
  jr    nc, # fflfast_mask_ok
  ld    hl, # fflfast_scraddr
  inc   (hl)      ;; patched above
$here 1- @def: fflfast_mask_move_addr
fflfast_mask_ok:

fflfast_skipxmove:
  ;; DE holds dy here
  ;; BC holds old err here
  ld    hl, bc
  or    a
  sbc   hl, de
  jp    p, # fflfast_loop     ;; olderr-dy<0: err+=dx
  ld    hl, () fflfast_err
  ld    de, # 0               ;; patched above
$here 2- @def: dxval1
  add   hl, de
  ld    fflfast_err (), hl    ;; er = er+dx
  ld    hl, # fflfast_xy0 1+
  inc   (hl)                  ;; patched above
$here 1- @def: fflfast_sy
  ;; change line address
  ld    hl, () fflfast_scraddr
  call  # 0                   ;;; patched above
$here 2- @def: fflfast_updown_hl_addr
  ld    fflfast_scraddr (), hl
  jp    # fflfast_loop_skip_hl_load

fflfast_done:
  exx
  next

fflfast_getout:
  pop   hl
  pop   hl
  pop   hl
  pop   hl
  next

ffline_down_hl:
  inc   h
  ld    a, h
  and   # $07
  ret   nz
  ld    a, l
  add   a, # 32
  ld    l, a
  ret   c
  ld    a, h
  sub   # 8
  ld    h, a
  ret

ffline_up_hl:
  ld    a, h
  dec   h
  and   # $07
  ret   nz
  ld    a, l
  sub   # 32
  ld    l,  a
  ret   c
  ld    a, h
  add   a, # 8
  ld    h, a
  ret


  ;; slow 16-bit drawer
flslow_16:
  call  # ffline_doplot_setup_mode

  ;; patch slow sx
  ld    a, () fflfast_sx
  cp    # $34         ;; INC (HL)
  ld    a, # $23      ;; INC HL
  jr    z, # flslow_sxpositive
  ld    a, # $2B      ;; DEC HL
flslow_sxpositive:
  ld    flslow_sx (), a
  ld    a, # $2B      ;; DEC HL

  ;; patch slow sy
  ld    a, () fflfast_sy
  cp    # $34         ;; INC (HL)
  ld    a, # $23      ;; INC HL
  jr    z, # flslow_sypositive
  ld    a, # $2B      ;; DEC HL
flslow_sypositive:
  ld    flslow_sy (), a
  ld    a, # $2B      ;; DEC HL

  ;; main loop
flslow_loop:
  ;; put pixel
  ld    hl, # fflfast_xcoord0 1+
  ld    a, (hl)
  inc   hl
  inc   hl
  or    (hl)
  jr    nz, # flslow_out_of_screen
  dec   hl
  ld    d, (hl)
  dec   hl
  dec   hl
  ld    e, (hl)
  call  # ffline_doplot_de
flslow_out_of_screen:

  ;; check if both coord pairs are equal
  ld    hl, () fflfast_xcoord0
  ld    de, () fflfast_xcoord1
  \ or    a
  sbc   hl, de
  jr    nz, # flslow_notdone
  ld    hl, () fflfast_ycoord0
  ld    de, () fflfast_ycoord1
  or    a
  sbc   hl, de
  jr    z, # fflfast_done
flslow_notdone:

  ld    hl, () fflfast_err
  ld    bc, hl      ;; save err, we'll need it later
  ld    de, () dxval0
  or    a
  adc   hl, de
  ld    de, () fflfast_dy
  jp    m, # flslow_skipxmove   ;; err+dx>0: err-=dy
  ld    hl, bc
  or    a
  sbc   hl, de
  ld    fflfast_err (), hl
  ld    hl, () fflfast_xcoord0
  dec   hl        ;; patched above
$here 1- @def: flslow_sx
  ld    fflfast_xcoord0 (), hl

flslow_skipxmove:
  ;; DE holds dy here
  ;; BC holds old err here
  ld    hl, bc
  or    a
  sbc   hl, de
  jp    p, # flslow_loop      ;; olderr-dy<0: err+=dx
  ld    hl, () fflfast_err
  ld    de, () dxval1
  add   hl, de
  ld    fflfast_err (), hl    ;; er = er+dx
  ld    hl, () fflfast_ycoord0
  inc   hl        ;; patched above
$here 1- @def: flslow_sy
  ld    fflfast_ycoord0 (), hl
  jp    # flslow_loop

fflfast_xcoord0: 0 dw,
fflfast_ycoord0: 0 dw,
fflfast_xcoord1: 0 dw,
fflfast_ycoord1: 0 dw,


;; this is shared between line and circle code
ffline_doplot_setup_mode:
  ;; check plot mode
  ld    a, () plot_mode
  and   # $03
  ret   z
  ld    hl, # ffline_doplot_or
  dec   a
  jr    z, # .pmode_done
  ld    hl, # ffline_doplot_xor
  dec   a
  jr    z, # .pmode_done
  ld    hl, # ffline_doplot_and
.pmode_done:
  ld    ffline_doplot_jaddr (), hl
  inc   a         ;; reset z flag
  ret

ffline_doplot_de:
  call  # scrpixcoord_de
  ret   c
  ;; create mask
  ld    d, a
  inc   d
  ld    a, # $01
.shift:
  rrca
  dec   d
  jp    nz, # .shift
ffline_doplot_dispatch:
  jp    # 0     ;; patched above
$here 2- @def: ffline_doplot_jaddr
ffline_doplot_and:
  cpl
  ld    e, a
  ld    a, (hl)
  and   e
  ld    (hl), a
  ret
ffline_doplot_xor:
  xor   (hl)
  ld    (hl), a
  ret
ffline_doplot_or:
  or    (hl)
  ld    (hl), a
  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; convert pixel coords to screen$ bitmap address and shift
;; IN:
;;   D: y
;;   E: x
;; OUT:
;;   A: pixel shift (0: leftmost; i.e. shift for 0x80)
;;   HL: scr$addr
;;   DE: dead
;;   carry flag: set on error (and the result is for 0,0)
scrpixcoord_de:
  ld    a, d
  cp    # 192
  jr    nc, # scr_badcoord
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
  ld    a, e
  and   # $07
  ret
scr_badcoord:
  ld    hl, # $4000
  xor   a
  scf
  ret
;code-no-next
*)


[ELSE]
\ <zx-hidden>
0 2variable INCX
0 2variable INCY
0 2variable X1
0 2variable Y1
\ <zx-normal>

: DRAW  ( ex ey )
  23678 C@ DUP 0 SWAP Y1 2! - DUP ABS ROT 23677 C@ DUP 0 SWAP X1 2! - DUP ABS ROT MAX >R
  DUP 0< IF ABS 0 SWAP R@ UM/MOD DNEGATE ELSE 0 SWAP R@ M/MOD ENDIF
  INCX 2! DROP DUP 0< IF ABS 0 SWAP R@ M/MOD DNEGATE ELSE 0 SWAP R@ M/MOD ENDIF
  INCY 2! DROP
  R> 1+ FOR
    X1 @ Y1 @ PLOT
    X1 2@ INCX 2@ D+ X1 2!
    Y1 2@ INCY 2@ D+ Y1 2!
  ENDFOR ;

: DDRAW  ( dx dy )
  asm-label: sysvar-coords C@++ SWAP C@  ( dx dy x0 y0 )
  ROT OVER +  ( dy x0 y0 ey )
  2OVER + SWAP DRAW 2DROP
  DROP ;
[ENDIF]


zxlib-end
