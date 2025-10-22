;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FIXME: not tested as a library yet!
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple sprite routines (kinda like Laser Basic)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; include "SPRX" library: ~420 bytes

;; including both engines costs ~440 bytes
;; including 3 engines costs ~625 bytes

;; include "XOR BLIT"? ~250 bytes
true zx-lib-option OPT-SPRX-XOR-MODE?

;; include "OR BLIT"? ~250 bytes
false zx-lib-option OPT-SPRX-OR-MODE?

;; include "AND BLIT"? ~250 bytes
false zx-lib-option OPT-SPRX-AND-MODE?

;; include SPX demo sprites?
false zx-lib-option OPT-SPRX-DEMO-SPRITES?


;; demo sprites?
OPT-SPRX-DEMO-SPRITES? [IF]
<zx-done>
extend-module TCOM

<zx-asm>
zx-demo-sprites:
<end-asm>

" misc/sprites.wls" zx-incbin 0 zx-w,
@asm-label: zx-demo-sprites zx-constant DEMO-SPRITES

end-module \ TCOM
<zx-definitions>
[ENDIF]


(* buffer/sprite format:
    db  width   ;; in chars
    db  height  ;; in chars
    bitmap-data
*)

\ <zx-definitions>

zxlib-begin" LASER-SPR library"

;; put sprite attributes?
0 quan SPR-ATTRS?

;; calculate buffer size for the given cwdt and chgt (in chars).
;; WARNING! sizes should be valid!
: SPR-BUF#  ( cwdt chgt )  2* 2* 2* * 2+ ;

;; saved screen contains destination address as two first bytes
: SCR-BUF#  ( cwdt chgt )  SPR-BUF# 2+ ;


code: (SCR-CRDX-NORUN)
;; IN:
;;   D: y
;;   E: x
;; OUT:
;;   HL: scr$addr
;;   DE: dead
;;   AF: dead
;;   carry flag: reset
zx-scr-char-coord-de-laz:
  ld    a, d
  and   # $18
  or    # $40
  ld    h, a
  ld    a, d
  rrca
  rrca
  rrca
  and   # $E0
  or    e
  ld    l, a
  ret
;code-no-next

;; read screen contents into buffer (without attrs)
;; WARNING! coords and sizes should be valid!
code: SCR$-READ  ( x y cwdt chgt destaddr )
  exx
  pop   hl    ;; destaddr
  pop   de    ;; chgt
  pop   bc    ;; cwdt
  ld    b, e  ;; B=chgt; C=cwdt; DE: free
  exx
  pop   hl    ;; y
  pop   de    ;; x
  ;; TODO: error checks
  ld    d, l
  call  # zx-scr-char-coord-de-laz
  push  hl    ;; save scr$ address
  exx
  pop   de
  ;; HL: destination
  ;; DE: source
  ;; B: char height
  ;; C: char width
  ;; save source address and dimensions
  ld    (hl), e
  inc   hl
  ld    (hl), d
  inc   hl
  ld    (hl), c
  inc   hl
  ld    (hl), b
  inc   hl
  ;; setup dimensions
  ld    a, b      ;; height
  ex    af, af'   ;; remember it
  ld    a, c      ;; width
  exx             ;; temp register save (we are at normal regs now)
  ;; calculate blitter address
  ld    hl, # blit-32-bytes-end
  add   a, a      ;; LDI is 2 bytes
  ld    e, a
  ld    d, # 0
  sbc   hl, de    ;; carry is resed by "add a, a"
  ;; patch blit code
  ld    ssave-blit-bmp-addr (), hl
  ld    ssave-blit-attr-addr (), hl
  exx             ;; restore registers
  ex    af, af'   ;; restore height
  ex    de, hl    ;; we are copying from scr$
  ;; DE: destination (buffer)
  ;; HL: source (scr$)
  push  af        ;; for attrs
  push  hl        ;; for attrs
.vcharloop:
  ex    af, af' ;; save height to A'
  ld    a, # 8  ;; 8 lines
.vlineloop:
  push  hl
  call  # 0     ;; self-modifying code
$here 2- @def: ssave-blit-bmp-addr
  pop   hl
  inc   h
  dec   a
  jp    nz, # .vlineloop
  ;; downhl
  ;; inc   h
  ;; this is always true
  ;; ld    a, h
  ;; and   #07
  ;; jp    nz, # .downok
  ld    a, l
  add   a, # 32
  ld    l, a
  jp    c, # .downok
  ld    a, h
  sub   # 8
  ld    h, a
.downok:
  ex    af, af' ;; restore height to A
  dec   a
  jp    nz, # .vcharloop

  ;; attrs
  ld    a, () zx-['pfa] SPR-ATTRS?
  or    a
  jr    z, # .ssave-no-attrs

  ;; calculate attr address
  pop   hl    ;; source scr$
  ld    a, h
  or    # $87
  rra
  rra
  srl   a     ;; rra for #C000 screen
  ld    h, a

  ;; restore height
  pop   af

.vattrloop:
  ex    af, af'
  push  hl
  call  # 0       ;; self-modifying code
$here 2- @def: ssave-blit-attr-addr
  ;; HL: source (attrs)
  ;; DE: destination (buffer)
  ;; go down one attr line
  pop   hl
  ld    bc, # 32
  add   hl, bc
  ;; loop over vertical lines
  ex    af, af' ;; restore height to A
  dec   a
  jp    nz, # .vattrloop
.ssave-done:
  exx
  next

.ssave-no-attrs:
  pop   af
  pop   af
  jr    # .ssave-done
;code-no-next


;; restores buffer saved by SCR$-READ
;; WARNING! coords and sizes should be valid!
code: SCR$-WRITE  ( bufaddr )
  exx
  pop   hl      ;; bufaddr
  ;; load destination
  ld    e, (hl)
  inc   hl
  ld    d, (hl)
  inc   hl
  ;; load dimensions
  push  de      ;; save destination
  ex    de, hl  ;; we need buffer address in DE
  call  # spr-setup-blitter-from-buf-in-de
  pop   de      ;; restore destination
  ;; HL: source (buffer)
  ;; DE: destination (scr$)
  ;;  A: height
  jp    # sprputbuf
;code-no-next


;; put sprite with or without attrs.
;; sprite format:
;;  byte-cwdt, byte-chgt, bitmap data, attributes
;; WARNING! coords and dimensions must be valid!
code: SPR-PUT  ( x y spraddr -- )
  exx
  pop   de      ;; spraddr
  call  # spr-setup-blitter-from-buf-in-de
$here 2- @def: spr-blitter-setup-addr
  ex    af, af' ;; temp save
  exx
  pop   hl    ;; y
  pop   de    ;; x
  ;; TODO: error checks
  ld    d, l
  call  # zx-scr-char-coord-de-laz
  push  hl
  exx
  pop   de
  ex    af, af'   ;; restore height
  ;; HL: source
  ;; DE: destination
  ;;  A: height in chars
@sprputbuf:
  push  af        ;; for attrs
  push  de        ;; for attrs
.vcharloop:
  ex    af, af'   ;; save height to A'
  ld    b, # 8    ;; 8 lines
.vlineloop:
  push  de
  ld    c, d      ;; for LDI; for others doesn't matter
  call  # 0       ;; self-modifying code
$here 2- @def: spr-blit-bmp-addr
  pop   de
  inc   d
  djnz  # .vlineloop
  ;; downde
  ;; inc   d
  ;; this is always true
  ;; ld    a, d
  ;; and   #07
  ;; jp    nz, # .downok
  ld    a, e
  add   a, # 32
  ld    e, a
  jp    c, # .downok
  ld    a, d
  sub   # 8
  ld    d, a
.downok:
  ex    af, af'   ;; restore height to A
  dec   a
  jp    nz, # .vcharloop

  ;; attrs
  ld    a, () zx-['pfa] SPR-ATTRS?
  or    a
  jr    z, # .blit-no-attrs

  ;; calculate attr address
  pop   de
  ld    a, d
  or    # $87
  rra
  rra
  srl   a     ;; rra for #C000 screen
  ld    d, a

  ;; restore height
  pop   af

.vattrloop:
  ex    af, af'
  push  de
  call  # 0       ;; self-modifying code
$here 2- @def: spr-blit-attr-addr
  ;; HL: source (buffer)
  ;; DE: destination (attrs)
  ;; go down one attr line
  ex    de, hl    ;; DE=buffer, HL is free
  pop   hl
  ld    bc, # 32
  add   hl, bc    ;; DE=buffer, HL=destination
  ex    de, hl    ;; HL=buffer, DE=destination
  ;; loop over sprite attr lines
  ex    af, af'   ;; restore height to A
  dec   a
  jp    nz, # .vattrloop
.blit-done:
  exx
  next
.blit-no-attrs:
  pop   af
  pop   af
  jr    # .blit-done

;; copy line blitter
blit-32-bytes:
  ldi ldi ldi ldi ldi ldi ldi ldi
  ldi ldi ldi ldi ldi ldi ldi ldi
  ldi ldi ldi ldi ldi ldi ldi ldi
  ldi ldi ldi ldi ldi ldi ldi ldi
blit-32-bytes-end:
  ret

OPT-SPRX-XOR-MODE? [IF]
;; xor line blitter
;; scr$ addr will never wrap
blit-32-bytes-xor:
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) xor (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
blit-32-bytes-xor-end:
  ret
[ENDIF]

OPT-SPRX-OR-MODE? [IF]
;; or line blitter
;; scr$ addr will never wrap
blit-32-bytes-or:
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) or (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
blit-32-bytes-or-end:
  ret
[ENDIF]

OPT-SPRX-AND-MODE? [IF]
;; and line blitter
;; scr$ addr will never wrap
blit-32-bytes-and:
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
  ld a, (de) ( ) and (hl) ( ) ld (de), a ( ) inc hl ( ) inc e
blit-32-bytes-and-end:
  ret
[ENDIF]

;; IN:
;;  DE: bufaddr (at dimensions)
;; OUT:
;;  HL: bufaddr (at data)
;;   A: height (in chars)
spr-setup-blitter-from-buf-in-de:
  ;; load dimensions, patch the code
  ld    a, (de) ;; width
  add   a, a    ;; one LDI is 2 bytes
  ;; calculate blitter address
  ld    hl, # blit-32-bytes-end
  ld    c, a
  ld    b, # 0
  sbc   hl, bc    ;; carry is resed by "add a, a"
  ;; patch blit code
  ld    spr-blit-bmp-addr (), hl
  ld    spr-blit-attr-addr (), hl
  ex    de, hl
  inc   hl
  ld    a, (hl) ;; height
  inc   hl
  ret

OPT-SPRX-XOR-MODE? OPT-SPRX-OR-MODE? forth:or OPT-SPRX-AND-MODE? forth:or [IF]
;; IN:
;;  DE: bufaddr (at dimensions)
;; OUT:
;;  HL: bufaddr (at data)
;;   A: height (in chars)
spr-setup-blitter-from-buf-in-de-xor:
  ;; load dimensions, patch the code
  ;; one snippet is 5 bytes.
  ld    a, (de) ;; width
  ld    c, a
  ;; A will never overflow
  add   a, a    ;; *2
  add   a, a    ;; *4
  add   a, c    ;; *5
  ;; calculate blitter address
  ld    hl, # 0
$here 2- @def: spr-blitter-xxx-addr
  ld    c, a
  ld    b, # 0
  sbc   hl, bc    ;; carry is resed by "add a, a"
  ;; patch blit code
  ld    spr-blit-bmp-addr (), hl
  ;; but attr blitter should use "copy"
  ld    a, (de) ;; width
  add   a, a    ;; one LDI is 2 bytes
  ;; calculate blitter address
  ld    hl, # blit-32-bytes-end
  ld    c, a
  \ ld    b, # 0  ;; it is still 0 here
  sbc   hl, bc    ;; carry is resed by "add a, a"
  ;; patch blit code
  ld    spr-blit-attr-addr (), hl
  ;; done
  ex    de, hl
  inc   hl
  ld    a, (hl)   ;; height
  inc   hl
  ret
[ENDIF]
;code-no-next


OPT-SPRX-XOR-MODE? OPT-SPRX-OR-MODE? forth:or OPT-SPRX-AND-MODE? forth:or [IF]
;; set sprite mode to "copy" (overwrite)
code: SMODE-COPY
  ld    hl, # spr-setup-blitter-from-buf-in-de
  ld    spr-blitter-setup-addr (), hl
;code
[ENDIF]

OPT-SPRX-XOR-MODE? [IF]
;; set sprite mode to "xor"
code: SMODE-XOR
  ld    hl, # blit-32-bytes-xor-end
  ld    spr-blitter-xxx-addr (), hl
  ld    hl, # spr-setup-blitter-from-buf-in-de-xor
  ld    spr-blitter-setup-addr (), hl
;code
[ENDIF]

OPT-SPRX-OR-MODE? [IF]
;; set sprite mode to "or"
code: SMODE-OR
  ld    hl, # blit-32-bytes-or-end
  ld    spr-blitter-xxx-addr (), hl
  ld    hl, # spr-setup-blitter-from-buf-in-de-xor
  ld    spr-blitter-setup-addr (), hl
;code
[ENDIF]

OPT-SPRX-AND-MODE? [IF]
;; set sprite mode to "and"
code: SMODE-AND
  ld    hl, # blit-32-bytes-and-end
  ld    spr-blitter-xxx-addr (), hl
  ld    hl, # spr-setup-blitter-from-buf-in-de-xor
  ld    spr-blitter-setup-addr (), hl
;code
[ENDIF]


zxlib-end


OPT-DEMO-SPRITES? [IF]
: SPR-FIND  ( idx -- addr // 0 )
  DEMO-SPRITES BEGIN OVER WHILE
    DUP @ DUP 0IF 3DROP 0 EXIT ENDIF
  + UNDER-1 REPEAT NIP
  DUP @ IF 2+ ELSE DROP 0 ENDIF ;

: .hex4  base @ hex swap 0 <# # # # # #> type base ! ;

: xs
  endcr
  0 spr-find ." addr=$" dup .hex4 c@++ ."  width=" . c@ ." height=" . cr
  1 spr-find ." addr=$" dup .hex4 c@++ ."  width=" . c@ ." height=" . cr
  2 spr-find ." addr=$" dup .hex4 c@++ ."  width=" . c@ ." height=" . cr
  59 spr-find ." addr=$" dup .hex4 c@++ ."  width=" . c@ ." height=" . cr
  59 spr-find 2- @ .hex4 cr
  60 spr-find ." addr=$" dup .hex4 c@++ ."  width=" . c@ ." height=" . cr
  61 spr-find ." addr=$" .hex4 cr
;

: xx
  true to SPR-ATTRS?
  at@
  \ SMODE-COPY
  \ SMODE-OR
  \ SMODE-XOR
  \ SMODE-AND
  0 >r begin
    r@ spr-find dup while >r ( | idx spr^ )
    0 0 r@ c@++ 10 max swap c@ 1+ 23 min ( x y cwdt chgt | idx spr^ )
    pad SCR$-READ
    0 0 at ." SPR #" r1:@ .
    0 1 r> spr-put
    key
    pad SCR$-WRITE
    7 = if rdrop at exit endif
  r> 1+ >r repeat drop rdrop at ;

[ENDIF]

\ <zx-done>
