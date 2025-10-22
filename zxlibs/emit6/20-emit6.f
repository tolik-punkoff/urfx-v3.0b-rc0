;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 42-column print driver
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-done>
extend-module TCOM

module font-loader-support
<disable-hash>

|: xchar  ( byte addr -- byte addr+1 )
  c@++ <<
    [char] . of?v| 0 |?
    [char] # of?v| 1 |?
  else| error" wut?!" >>
  rot 2* + swap ;

@: row
  parse-name 6 = not?error" invalid row"
  0 swap
  xchar xchar xchar xchar xchar xchar
  drop 4*
  zx-c, ;

seal-module
end-module

<zx-asm>
zxf-font-6x7:
<end-asm>

push-ctx voc-ctx: font-loader-support
" 10-font6x7.f" false (include)
pop-ctx

end-module \ TCOM


<zx-definitions>

42 constant #COLS

code: (*MASK-TABLES*)  ( -- addr )
  push  hl
  ld    hl, # Draw6NormMaskTable
  next

  flush!

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; masks for 42-column print driver
  \ FIXME: better align
  Draw6NormMaskTable 5 2* + 1- hi-byte Draw6NormMaskTable hi-byte = [IFNOT]
    0 dw, 0 dw, 0 dw, 0 dw, 0 dw, 0 dw,
  [ENDIF]

Draw6NormMaskTable:
  ( $FF03 dw,)
  $FFFF dw, ( no mask -- for non-masked output )
  $FC0F dw, $F03F dw, $C0FF dw, $03FF dw,
code-no-next


code: (EMIT-RAW)  ( ch )
  ex    de, hl
  call  # Draw6Char
  pop   hl
  next

  ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; print char
  ;; in: E=code
@Draw6Char:
  ;; 96 chars
  ld    a, e
  and   # $7F
  cp    # 32
  jr    nc, # .okchar
  ld    a, # [char] ?
.okchar:

  zx-has-word? OBL? [IF]
  ld    hl, # zx-['pfa] OBL?
  ld    (hl), # 0
  [ENDIF]
  cp    # 32
  jr    nz, # .not-a-space
  zx-has-word? OBL? [IF]
  inc   (hl)
  [ENDIF]
  ld    hl, # $3D00 ;; ROM space
  jr    # .font-addr-done
.not-a-space:

 OPT-EMIT6-UGLY? [IF]
  cp    # 91
  jr    c, # .use-custom-font
  ;; calculate ROM font address
  ld    l, a
  add   hl, hl
  ld    h, # 15
  add   hl, hl
  add   hl, hl
  inc   hl
  ;; patch shift instruction
  ld    a, # $17    ;; RLA
  ld    .font-bmp-shift (), a
  jr    # .font-addr-done
.use-custom-font:
 [ENDIF]
  ;; 6x7
  ld    e, a
  ld    d, # 0
  add   a, a    ;; first shift is guaranteed to not overflow
  ld    l, a
  ld    h, d
  add   hl, hl
  add   hl, hl
  ;; there should be no overflow, so don't put your font
  ;; exactly at the end of RAM. minimum address is `65535-96*8`
  sbc   hl, de
  ld    de, # zxf-font-6x7 33 7 * -
$here 2- @def: font6x8-addr
  add   hl, de
 OPT-EMIT6-UGLY? [IF]
  ;; patch shift instruction
  xor   a           ;; NOP
  ld    .font-bmp-shift (), a
 [ENDIF]
.font-addr-done:
  ;; HL: source address

  ;;  E: inverse mask
  ld    e, # 0
$here 1- @def: Draw6InvMask
  exx
  ;; HL' is source address
  ;;  E' is inverse mask

  ;; calc screen address
  ld    a, # 00   ;; y
$here 1- @def: emit6y
  rlca
  rlca
  rlca
  ld    e, a
  ld    d, # 00   ;; x
$here 1- @def: emit6x
  rlc   d
  ld    a, d
  rlc   d
  add   a, d
  ld    d, a
  ld    a, e
  or    a       ;; reset carry
  rra
  scf
  rra
  or    a
  rra
  xor   e
  and   # $F8
  xor   e
  ld    h, a
  ld    a, d
  rlca
  rlca
  rlca
  xor   e
  and   # $C7
  xor   e
  rlca
  rlca
  ld    l, a

  ;; possible shifts: 0, 2, 4, 6  (converted to: 0, 1, 2, 3).
  ;; we will shift the bitmap to the *left* (because "add hl, hl" is faster).
  ;; so we need to use "3-shift".
  ;; (3-a)&3 = ~a&3
  ld    a, d
  rra
  cpl
  and   # $03
  ;; shift amount is [1..4], that's how the code expects it
  ;; (due to shift direction)
  inc   a
  ld    Draw6Shift (), a

  ex    de, hl
  ;; DE: screen address

Draw6NormMaskTable 5 2* + 1- hi-byte Draw6NormMaskTable hi-byte =
" Draw6NormMaskTable is not properly aligned" not?error
  ld    hl, # Draw6NormMaskTable    ;; 10
  add   a, a                        ;; 4
  ;; or XOR A for non-masked output; $87 is ADD, $AF is XOR
$here 1- @def: Draw6MaskTblAdd
  add   a, l                        ;; 4
  ld    l, a                        ;; 4
  ld    a, (hl)                     ;; 7
  ld    draw6CharMask_right (), a   ;; 13
  inc   l                           ;; 4
  ld    a, (hl)                     ;; 7
  ld    draw6CharMask_left (), a    ;; 13

  ;; use "C" as "0" value
  ld    bc, # $0800
  ;; first bitmap line is always empty
  ld    a, c
  exx
  jr    # .bitmap-skip-1st-load
.bitmap-line-loop:
  ;; HL: bitmap (shifted right, i.e. starts in L)
  exx
  ld    a, (hl)
  inc   hl
 OPT-EMIT6-UGLY? [IF]
  ;; shift and mask ROM chars
.font-bmp-shift:
  rla   ;; self-modifying code!
  and   # %11111100
 [ENDIF]
.bitmap-skip-1st-load:
  xor   e         ;; invert it
  exx
  ld    l, a
  ld    h, c
  ;; Z flag is set by the "xor e" above
  ;; most bitmaps have at least 2 zero bytes (one zero byte is guaranteed)
  jr    z, # .no-bitmap-shift
  ;; shift amount (will never be 0)
  ld    a, # $00
$here 1- @def: Draw6Shift
.bitmap-shift-loop:
  add   hl, hl
  add   hl, hl
  dec   a
  ;; the loop is repeated at least once; JP is faster
  jp    nz, # .bitmap-shift-loop
.no-bitmap-shift:
  ;; print masked bitmap
  ;; left part
  ld    a, (de)
  and   # $00
$here 1- @def: draw6CharMask_left
  or    h
$here 1- @def: draw6PutALU0
  ld    (de), a
  ;; right part
  inc   e
  ld    a, (de)
  and   # $00
$here 1- @def: draw6CharMask_right
  or    l
$here 1- @def: draw6PutALU1
  ld    (de), a
  dec   e
  ;; next bitmap row
  inc   d
  djnz  # .bitmap-line-loop

  ;; attrs
.do-attrs:
  ;; set attr
  ;; convert to attribute address
  ld    a, d
  dec   a       ;; because high scr$ byte overflowed
  or    # $87
  rra
  rra
  srl   a
  ld    h, a
  ld    l, e
  ;; possible shifts: 0, 2, 4, 6  (converted to 1, 2, 3, 4, and reversed)
  ;; converted (and inverted):
  ;;   1..2: set both
  ;;   3..4: set only the first
  ;; we will need A, so prepare the flag
  ld    a, () Draw6Shift   ;; [1..4]
  cp    # 3
  ;; set attrs
  ex    af, afx
  ld    de, () sysvar-attr-t
  ;; E=attr
  ;; D=mask
  ld    a, (hl)
  xor   e
  and   d
  xor   e
  ld    (hl), a
  ex    af, afx
  \ jr    nc, # .done
  ret   nc
  inc   l         ;; it will never overflow
  ld    a, (hl)
  xor   e
  and   d
  xor   e
  ld    (hl), a
\ .done:
  ret
;code-no-next


;; should not print beyond the right screen edge.
code: XTYPE  ( addr count )
  \ pop   hl
  pop   de
  \ push  bc
  ld    bc, hl
  ;; BC=count
  ;; DE=addr
  ld    a, () Draw6InvMask
  push  af
.loop:
  ld    a, b
  or    c
  jr    z, # .done
  ld    hl, # Draw6InvMask
  ld    (hl), # 0
  ld    a, (de)
  cp    # $80
  jr    c, # .not-high
  ld    (hl), # $FC
.not-high:
  and   # $7F
  cp    # 32
  jr    nc, # .not-low
  ld    a, # [char] ?
  ld    (hl), # $FC
.not-low:
  push  de
  push  bc
  ld    e, a
  call  # Draw6Char
  pop   bc
  pop   de
  ld    a, () emit6x
  inc   a
  ld    emit6x (), a
  inc   de
  dec   bc
  jp    # .loop
.done:
  pop   af
  ld    Draw6InvMask (), a
  \ pop   bc
  pop   hl
;code


\ FIXME: convert to primitives!

code: TOVER?  ( -- flag )
  push  hl
  ld    hl, # 0
  ld    a, Draw6MaskTblAdd ()
  cp    # $87 ;; add?
  jr    z, # .done
  ;; either XOR (1), or OR (2)
  inc   l
  ld    a, draw6PutALU0 ()
  cp    # $AC ;; xor?
@z-push-hl-inc-l-push-hl:
  jr    z, # .done
  inc   l
.done:
;code

code: TINV?  ( -- flag )
  push  hl
  ld    hl, # 0
  ld    a, () Draw6InvMask
  or    a
  jr    # z-push-hl-inc-l-push-hl
;code


;; 0: normal
;; 1: xor
;; 2: or
code: TOVER  ( n -- )
  \ pop   de
  ex    de, hl
  ld    l, # $87  ;; add
  ld    a, e
  or    d
  jr    z, # .tover1
  ld    l, # $AF  ;; xor
  dec   a
  jr    z, # .tover1
;; mode 2 (OR)
  ld    a, # $B4      ;; or h
  jr    # .tover2
.tover1:
;; mode 1 (XOR)
  ld    a, # $AC      ;; xor h
.tover2:
  ld    draw6PutALU0 (), a
  inc   a
  ld    draw6PutALU1 (), a
  ld    a, l
  ld    Draw6MaskTblAdd (), a
\ zx-word-e6-tctl-next:
  pop   hl
;code

code: TINV  ( flag -- )
  \ pop   de
  ex    de, hl
  ld    a, e
  or    d
  ld    a, # $00
  jr    z, # .tinv0
  ld    a, # $FC
.tinv0:
  ld    Draw6InvMask (), a
  \ jr    # zx-word-e6-tctl-next
  pop   hl
;code
