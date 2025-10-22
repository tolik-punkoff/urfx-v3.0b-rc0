;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 64-column print driver
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-done>
extend-module TCOM

module font-loader-support
<disable-hash>

create xch 8 allot create;
0 quan xnn (published)
false quan do-rol (published)

|: xchar  ( byte addr -- byte addr+1 )
  c@++ <<
    [char] . of?v| 0 |?
    [char] # of?v| 1 |?
  else| error" wut?!" >>
  rot 2* + swap ;

|: cr^  ( -- addr ) xnn 7 mod xch + ;

@: row
  parse-name 4 = not?error" invalid row"
  xnn 0?< xch 8 erase >?
  cr^ c@
  swap xchar xchar xchar xchar drop
  cr^ c!
  xnn:1+!
  xnn 14 = ?<
    7 xch << c@++ do-rol ?< 4 rol8 >?
             zx-c, 1 under- over ?^|| else| 2drop >>
    xnn:!0 >? ;

seal-module
end-module

<zx-asm>
zxf-font-4x7:
<end-asm>

push-ctx voc-ctx: font-loader-support
xnn:!0 do-rol:!f
" 10-font4x7.f" false (include)
pop-ctx

end-module \ TCOM


<zx-definitions>
64 constant #COLS


code: (EMIT-RAW)  ( ch )
  ;; "no scrolled" flag
  ld    a, # $FF
  ld    sysvar-scr-ct (), a

  ;; based on the code by Einar Saukas

  ex    de, hl
  call  # Draw4Char
  pop   hl
  next

  ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@Draw4Main:
  ;; HL: font
  ;; DE: scr$

  xor   a       ;; first font byte is always blank
  ld    b, # 8  ;; execute loop 8 times
.loop-rlc:
  rlca
  rlca
  rlca
  rlca
.loop-simple:

@Draw4InverseOpc:
  nop

.font-mask:
  and   # $F0
  ld    c, a
  ld    a, (de)
.scr-mask:
  and   # $0F
$here 1- @def: Draw4ScrMask
  xor   c
  ld    (de), a
  inc   d
  inc   hl
  ld    a, (hl)
  djnz  # .loop-rlc
.loop-done:

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
  ld    de, () sysvar-attr-t
  ;; E=attr
  ;; D=mask
  ld    a, (hl)
  xor   e
  and   d
  xor   e
  ld    (hl), a

  ret

  ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@Draw4Char:
;; print char
;; in: E=code
  ld    bc, # 0   ;; self-modifying code (do not change!)
$here 2- @def: emit6x

  ld    a, e
  and   # $7F
  cp    # 32
  jr    nc, # .okchar
  ld    a, # [char] ?
.okchar:
  zx-used-word? OBL? [IF]
  ld    hl, # zx-['pfa] OBL?
  ld    (hl), # 0
  jr    nz, # .not-blank
  inc   (hl)
.not-blank:
  [ENDIF]
  ld    e, a

  xor   c
  rra
  ld    a, # 256 .loop-done .loop-simple - -
  jr    nc, # .no-shift
  ld    a, # 256 .loop-done .loop-rlc - -
.no-shift:
  ld    .loop-done 1- (), a

  ;; mask
  srl   c
  ld    a, # $F0
  jr    nc, # .mask-ok
  cpl
.mask-ok:
  ld    .font-mask 1+ (), a
  cpl
  or    # $00   ;; self-modifying code
$here 1- @def: Draw4OverMask
  ld    .scr-mask 1+ (), a

  ;; screen address
  ld    a, # 0    ;; self-modifying code (do not change!)
$here 1- @def: emit6y

  \ call  # $0E9E
  ld    d, a
  rrca
  rrca
  rrca
  and   # $E0
  ld    l, a
  ld    a, d
  and   # $18
  or    # $40
  ld    h, a

  add   hl, bc
  ex    de, hl
  ;; DE=scr$
  ;;  L=char

  ld    h, b
  srl   l
  ld    c, l
  add   hl, hl
  add   hl, hl
  add   hl, hl
  sbc   hl, bc
  ld    bc, # zxf-font-4x7 $71 -
  add   hl, bc
  jp    # Draw4Main
;code-no-next


;; should not print beyond the right screen edge.
(*
code: XTYPE  ( addr count )
  exx
  pop   bc
  pop   de
  ld    hl, # Draw4InverseOpc
  exx
  push  bc
  exx
  ld    a, (hl)
  push  af
.loop:
  ld    a, b
  or    c
  jr    z, # .done
  ld    (hl), # 0
  ld    a, (de)
  cp    # $80
  jr    c, # .not-high
  ld    (hl), # $2F   ;; CPL
.not-high:
  and   # $7F
  cp    # 32
  jr    nc, # .not-low
  ld    a, # [char] ?
  ld    (hl), # $2F   ;; CPL
.not-low:
  exx
  ld    e, a
  call  # Draw4Char
  exx
  ld    a, () emit6x
  inc   a
  ld    emit6x (), a
  inc   de
  dec   bc
  jp    # .loop
.done:
  pop   af
  ld    (hl), a
  exx
  pop   bc
;code
*)


\ FIXME: convert to primitives!

code: TINV?  ( -- n )
  push  hl
  ld    a, () Draw4InverseOpc
zx-word-tinv-finish:
  or    a
  ld    hl, # 0
  jr    z, # .done
  inc   l
.done:
;code

code: TOVER?  ( -- n )
  push  hl
  ld    a, () Draw4OverMask
  jr    # zx-word-tinv-finish
;code-no-next

raw-code: TINV  ( n )
  ld    a, h
  or    l
  ld    a, # $2F    ;; CPL
  jr    nz, # .inverse
  xor   a
.inverse:
  ld    Draw4InverseOpc (), a
  pop   hl
;code

raw-code: TOVER  ( n )
  ld    a, h
  or    l
  ld    a, # $FF
  jr    nz, # .over
  inc   a
.over:
  ld    Draw4OverMask (), a
  pop   hl
;code
