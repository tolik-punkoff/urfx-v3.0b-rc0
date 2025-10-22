;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16x16 XOR sprites, no runtime shifting
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

\ false constant AFR-SPR16-IM2-TIMING
\ false constant AFR-SPR16-OR/AND

;; completely replace IM2 handler?
;; this is several TS faster (and still supports chaining).
true zx-lib-option OPT-SPR16-REPLACE-IM2?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main code

\ <zx-definitions>

$zx-use <stick-scan>

zxlib-begin" SPR16 library"


(*
IM2 handler does sprite sorting and rendering.
the code can render ~3 sprites before the scr$ update starts, but w/o sorting.

so, i will do it another way: sort sprites by screen thirds, and
render each third separately.

i will also start rendering from the bottom, so there will be enough time
to do any other processing in IM2 handler.

we'll not draw more than 8 sprites per interrupt, so the list will be
processed in 8-item batches.
*)

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sprite info

(*
sprinfo is (14 bytes):
 db  flags
 db  attr
 dw  new-scraddr  ;; high-endian
 dw  new-propaddr ;; attribute file address; also used as propmap address (high-endian)
 dw  new-bmpdata  ;; pointer to the shift byte, and bitmap data
 dw  old-scraddr  ;; high-endian
 dw  old-propaddr ;; attribute file address; also used as propmap address (high-endian)
 dw  old-bmpdata  ;; pointer to the shift byte, and bitmap data

flags:
  bit 7 is set if the sprite is queued for rendering.
  other bits are unused.

attrs: new sprite attributes.
*)


\ <zx-hidden>
;; 32x24 tile property map.
;; bit 7 set means "do not change attrs at this screen char".
;; bit 6 set means "do not print sprites over this tile".
;; note that bits 6 and 7 are independent, and you need to
;; set both if you want to have a "foreground" tile!
;; WARNING! must be aligned to 256 bytes!
$6000 zxa:@def: zx-spr-prop-map
asm-label: zx-spr-prop-map constant TPROP-MAP

;; keep PAPER color unchanged
@270 zxa:@def: zx-spr-attr-mask-const


;; maximum number of sprites
18 constant #SPRITES

;; size of spr-info struct
14 constant #SPR-INFO

;; number of sprites rendered per interrupt.
8 constant SPR/INTR


;; all tables are completely inside one 256-byte page.
;; the code relies on this!

;; 3 working lists for IM handler.
;; contain pointers to sprinfo.
;; as sprinfo array is guaranteed to be in one page,
;; we can store only low byte of the address.
;; should not be at page start (because zero is used as "end of queue" flag).
zx-here $FF and 0= [IF] 1 allot [ENDIF]
" SPR16 IM2 lists"  SPR/INTR 1+ 3 *  zx-ensure-page-with-report
zx-here $FF and 0= [IF] 1 allot [ENDIF]
zx-here zxa:@def: zx-spr-im2-wk-top  SPR/INTR 1+ allot
zx-here zxa:@def: zx-spr-im2-wk-mid  SPR/INTR 1+ allot
zx-here zxa:@def: zx-spr-im2-wk-bot  SPR/INTR 1+ allot
zxlib-msg? [IF]
endcr ." SPR16 IM2 lists size: "
zx-here asm-label: zx-spr-im2-wk-top - .bytes cr
[ENDIF]


;; list of sprites scheduled for processing.
;; sprinfo will be added to this list if it is not there yet.
;; as sprinfo array is guaranteed to be in one page,
;; we can store only low byte of the address.
" SPR16 sprite queue"  #SPRITES 1+  zx-ensure-page-with-report
zx-here zxa:@def: zx-spr-queue-start
  #SPRITES 1+  allot
zx-here zxa:@def: zx-spr-queue-end

asm-label: zx-spr-queue-start hi-byte zxa:@def: zx-spr-queue-start-hi-byte
asm-label: zx-spr-queue-start lo-byte zxa:@def: zx-spr-queue-start-lo-byte
asm-label: zx-spr-queue-end lo-byte zxa:@def: zx-spr-queue-end-lo-byte
asm-label: zx-spr-queue-end 1- asm-label: zx-spr-queue-start - hi-byte " oops" ?error
asm-label: zx-spr-queue-end asm-label: zx-spr-queue-start - #SPRITES 1+ = " oops" not?error
zxlib-msg? [IF]
endcr ." SPR16 queue size: "
asm-label: zx-spr-queue-end asm-label: zx-spr-queue-start - .bytes cr
[ENDIF]


;; i need them here to perform some code optimisations
" SPR16 IM2 ptrs"  2 3 *  zx-ensure-page-with-report
;; WARNING! counters must ALWAYS come before ptrs!
;;          the code below expects this layout.
;; as work lists are guaranteed to be inside one page,
;; we can skip storing (and loading) high address byte.
zx-here zxa:@def: spr-im2-top-cnt 1 allot
zx-here zxa:@def: spr-im2-top-ptr 1 allot
zx-here zxa:@def: spr-im2-mid-cnt 1 allot
zx-here zxa:@def: spr-im2-mid-ptr 1 allot
zx-here zxa:@def: spr-im2-bot-cnt 1 allot
zx-here zxa:@def: spr-im2-bot-ptr 1 allot

;; queue head points *at* the first item.
;; queue tail points *after* the last item.
;; the queue is empty is head = tail.
;; the list above is circular.
;; if both pointers are equal, the list is empty.
zx-here zxa:@def: zx-spr-queue-head 2 allot
zx-here zxa:@def: zx-spr-queue-tail 2 allot


;; interrupt flags (low byte):
;;   bit 0: blitting enabled
;;   bit 7: interrupt was triggered
zx-here zxa:@def: zx-spr-iff 1 allot

;; low byte -- state
;; high byte -- or-state
zx-here zxa:@def: zx-spr-ctb 2 allot

;; incremented on each interrupt
;; used FRAMES sysvar instead
\ zx-here zxa:@def: zx-spr-frames 2 allot

;; sprinfo for all sprites
0 [IF]
;; use 256-byte printer buffer at $5B00
$5B00 zxa:@def: zx-spr-info-start
$5C00 zxa:@def: zx-spr-info-end
zx-here zxa:@def: spr16-big-align-start
zx-here zxa:@def: spr16-big-align-end
[ELSE]
;; allocate in normal memory
zx-here zxa:@def: spr16-big-align-start
" SPR16 sprite info"  #SPRITES #SPR-INFO *  zx-ensure-page-with-report
zx-here zxa:@def: spr16-big-align-end
zx-here zxa:@def: zx-spr-info-start
  #SPRITES #SPR-INFO *  allot
zx-here zxa:@def: zx-spr-info-end
[ENDIF]

asm-label: zx-spr-info-start hi-byte zxa:@def: zx-spr-info-start-hi-byte
zxlib-msg? [IF]
endcr ." SPR16 sprinfo size: "
asm-label: zx-spr-info-end asm-label: zx-spr-info-start - .bytes cr
[ENDIF]


|: SPR-INIT
  0 asm-label: zx-spr-iff C!
  asm-label: zx-spr-queue-start
  DUP asm-label: zx-spr-queue-head ! asm-label: zx-spr-queue-tail !
  asm-label: zx-spr-info-start
  asm-label: zx-spr-info-end asm-label: zx-spr-info-start - ERASE ;


;; doesn't check arguments!
primitive: SIDX>SINFO  ( spr-idx -- spr-info )
:codegen-xasm
  tos-r16 a<-r16l
  add-a-a    ;; *2
  tos-r16 r16l<-a
  add-a-a    ;; *4
  add-a-a    ;; *8
  add-a-a    ;; *16
  tos-r16 sub-a-r16l  ;; -*2
  tos-r16 r16l<-a
  @label: zx-spr-info-start hi-byte tos-r16 c#->r16h ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; public API

\ <zx-normal>

;; is given sprite number valid?
: SPR-VALID?  ( spr-idx -- bool )  #SPRITES U< ; zx-inline

;; is the sprite with the given index already queued?
: SPR-QUEUED?  ( spr-idx -- bool )
  DUP SPR-VALID? 0IF DROP 0 EXIT ENDIF
  SIDX>SINFO C@ $7F U> ;


;; `x` is in characters, `y` is in pixels.
;; ignores invalid `spr-idx`.
;; passing invalid `x` or `y` will hide the sprite.
;; note that the sprite is not clipped with screen borders;
;; it will simply disappear if clipping is required.
;; spr-data is: (4 bytes, to make everything easier)
;;   db attr
;;   dw gfx-addr
;;   db reserved
code: SPR-UPDATE  ( x y spr-data spr-idx )
  \ push  hl
  \ exx           ;; we are at the "alternate" register set now
  ;; update sprite info.
  ;; note that we don't need to copy "new" data to "old" data
  ;; if the sprite is already processed by blitter.
  ;; we may hit an interrupt here, so mark the sprite as "being updated".
  \ pop   hl    ;; spr-idx

  ;; check index for validity
  ld    a, h
  or    a
  jp    nz, # .fail
  ld    a, l
  cp    # #SPRITES
  jp    nc, # .fail

  ;; calculate spr-info
  add   a, a    ;; *2
  ld    l, a
  add   a, a    ;; *4
  add   a, a    ;; *8
  add   a, a    ;; *16
  sub   a, l    ;; -*2
  ld    l, a
  ld    h, # zx-spr-info-start hi-byte

  pop   de    ;; spr-data
  ;; HL=spr-info
  ;; DE=spr-data

  ;; test sprites in contended memory
  0 [IF]
  ld    d, # $59
  [ENDIF]

  ;; block sprite blitting using the flags
  ;; atomic update
  xor   a       ;; "blitter is disabled" flag
  ld    zx-spr-iff (), a
  ;; after this point, all lists are "stable"
  ;; (i.e. cannot be changed mid-way).

  ;; if the sprite is not queued, copy "new" data to "old" data.
  ;; otherwise don't bother.
  ;; this is because at this stage, "new" data is blitted.
  bit   7, (hl)
  jr    nz, # .skip-data-copy

  push  hl      ;; save spr-info address
  push  de      ;; save spr-data address
  inc   l       ;; skip flags
  inc   l       ;; skip attrs
  ;; this is faster than trying to use registers
  ld    de, hl
  ld    bc, # 6
  add   hl, bc
  ex    de, hl
  ldi ldi ldi ldi ldi ldi
  ;; restore registers
  pop   de      ;; restore spr-data address
  pop   hl      ;; restore spr-info address
.skip-data-copy:

  ;; HL=spr-info
  ;; DE=spr-data

  \ exx           ;; we are at the "normal" register set now
  exx           ;; we are at the "alternate" register set now
  ;; calculate scr$ address
  pop   hl      ;; y
  pop   de      ;; x
  ;; check for invalid coords
  ld    a, d
  or    h
  jp    nz, # .do-hide-sprite
  ;; load sprite mask -- we need it to set maximum x coord
  \ exx           ;; we are at the "alternate" register set now
  exx           ;; we are at the "normal" register set now
  ld    a, (de)
  add   a, # 1  ;; carry set if the mask is $FF
  \ exx           ;; we are at the "normal" register set now
  exx           ;; we are at the "alternate" register set now
  ld    a, # 29
  adc   a, # 0  ;; it is 29 for shifted sprites, 30 for non-shifted
  cp    e
  jr    c, # .do-hide-sprite
  ;; check y coord (we need in in A too)
  ld    a, l    ;; y
  sub   # 15    ;; y is at the bottom
  cp    # 192 15 -
  jr    nc, # .do-hide-sprite
  ;; convert coords to screen$ bitmap address
  ;; L=y (in pixels)
  ;; D=x (in chars)
  ld    a, l    ;; y
  and   a
  rra
  scf
  rra
  and   a
  rra
  xor   l
  and   # $F8
  xor   l
  ld    h, a
  ld    a, e    ;; x
  rrca
  rrca
  xor   l
  and   # $C7
  xor   l
  rlca
  rlca
  ld    l, a
  or    h       ;; reset zero flag, H is never 0 here
.done-with-scr-addr:

  ;; HL -- scr$ (or $1000)
  ;; DE is free, calculate attr addr into it
  ;; zero flag is set if HL is invalid
  ld    a, h
  jr    z, # .skip-attr-calc
  or    # $87
  rra
  rra
  srl   a     ;; rra for #C000 screen
  ;; move to propmap
  add   a, # zx-spr-prop-map hi-byte $58 -
.skip-attr-calc:
  ld    d, a
  ld    e, l
  ;; DE=attr address (from $5800)

  push  de      ;; it need to be put after scr$
  push  hl      ;; so it will be loaded to BCx

  \ exx           ;; we are at the "alternate" register set now
  exx           ;; we are at the "normal" register set now
  inc   l       ;; skip flags
  ld    a, (de) ;; load sprite attr
  ld    (hl), a ;; store sprite attrs
  ld    a, l    ;; save low spr-info address byte
  inc   l       ;; skip spr-info attr
  inc   de      ;; skip sprite attr
  pop   bc      ;; load scr$ to BC
  ;; save scr$ (high-endian)
  ld    (hl), b
  inc   l
  ld    (hl), c
  inc   l
  pop   bc      ;; load propmap address to BC
  ;; save propmap address (high-endian)
  ld    (hl), b
  inc   l
  ld    (hl), c
  inc   l
  ;; save spr-gfx
  ;; load gfx address
  ex    de, hl
  ;; HL=spr-data
  ;; DE=spr-info
  ld    c, (hl)
  inc   hl
  ld    b, (hl)
  ex    de, hl
  ;; BC=spr-gfx
  ;; HL=spr-info
  ld    (hl), c
  inc   l
  ld    (hl), b
  ;; restore spr-info address
  ld    l, a
  dec   l
  ;; HL now points to the spr-info again

  ;; do we need to queue the sprite?
  bit   7, (hl)
  jr    nz, # .queue-complete

.queue-it:
  ;; queue the sprite
  ;; HL points to the spr-info

  ;; set "queued" flag
  set   7, (hl)

  ex    de, hl  ;; DE is spr-data
  ld    hl, () zx-spr-queue-tail
  ;; tail pointer is always valid.
  ;; store the address in the queue (only low byte).
  ld    (hl), e
  inc   l

  ;; wrap the tail, if necessary
  ld    a, l
  cp    # zx-spr-queue-end-lo-byte
  jr    c, # .tail-is-ok
  ld    l, # zx-spr-queue-start-lo-byte
.tail-is-ok:
  ;; save new tail
  ld    zx-spr-queue-tail (), hl

.queue-complete:
  ;; we're done here, and we can enable blitting again.
  ;; the interrupt will set bit 7 of the "(IFF)" if occured.
  \ exx           ;; we are at the "normal" register set now
  \ do not bother switching registers, there's no sense in doing it
  ld    hl, # zx-spr-iff
  ;; atomic update: shift high bit into carry, and set low bit
  \ scf  rl (hl)
  sll   (hl)    ;; undocomented instruction: sets bit 0 to 1, moves bit 7 to carry
  call  c, # spr-blitter-main  ;; corrupts HL and AF
  ;; we're done
  pop   hl      ;; get TOS
  next

.do-hide-sprite:
  ld    hl, # $1000
  xor   a       ;; set zero flag
  jr    # .done-with-scr-addr

.fail:
  pop   bc
  pop   bc
  pop   bc
  pop   hl      ;; get TOS
;code


;; set sprdata to nothing
: SPR-ERASE  ( spr-idx )
  >R 255 255 0 R> SPR-UPDATE ; zx-inline


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IM2 handler

;; AF and HL are already saved
raw-code: SPR-IM2-HANDLER
  jp    # spr-blitter-main

;; IM2 handler entry.
;; HL and AF are saved by the caller.
spr-blitter-im2:
  OPT-SPR16-REPLACE-IM2? [IF]
  push  af
  push  hl
  call  # spr-main-im2-ext
  call  # .spr-call-dummy
  pop   hl
  pop   af
  ei
  ret
.spr-call-dummy:
  ld    hl, () zx-im2-userproc-addr
  jp    hl

spr-main-im2-ext:
  [ENDIF]

  ;; increment frame counter
  \ ld    hl, # zx-spr-frames
  ld    hl, # sysvar-frames
  inc   (hl)
  ;; this jump is almost always taken
  jp    nz, # .frames-no-wrap
  inc   l
  inc   (hl)
  ;; don't bother with the 3rd byte, we don't need it anyway
  0 [IF]
  ;; this jump is almost always taken
  jp    z, # .frames-no-wrap
  inc   l
  inc   (hl)
  [ENDIF]
.frames-no-wrap:

  ;; for Joffa's SFX engine
  zx-has-word? (*SFX-JOFFA*) [IF]
  ld    a, r
  or    # $80
  ld    r, a
  [ENDIF]

  ;; read stick
  push  de
  push  bc
  ld    de, # zx-['pfa] INP-PREPARED
  call  # read-stick-de
  ld    a, c
  ld    hl, # zx-spr-ctb
  ld    (hl), a
  inc   hl
  or    (hl)
  ld    (hl), a
  pop   bc
  pop   de

  ld    hl, # zx-spr-iff
  0 [IF]
  set   7, (hl)     ;; "interrupt triggered" flag
  bit   0, (hl)     ;; check if blitter enabled
  ;; 15+12=27
  ret   z
  [ELSE]
  ld    a, (hl)
  or    # $80
  ld    (hl), a
  rrca
  ;; 7+7+7+4=25
  ret   nc
  [ENDIF]

  \ zxemut-resume-ts-counter
  \ zxemut-reset-ts-counter
  \ zxemut-print-ts-counter
  \ zxemut-bp

spr-blitter-main:
  AFR-SPR16-IM2-TIMING [IF]
    zxemut-resume-ts-counter
    zxemut-reset-ts-counter
  [ENDIF]

  ;; save all registers (except HL and AF).
  ;; even if called from the main code, it is guaranteed
  ;; that the interrupt is just occured, so it is safe
  ;; to use IY here.
  push  ix
  push  iy
  push  de
  push  bc
  ex    af, afx
  push  af
  exx
  push  hl
  push  de
  push  bc

  ;; reset working lists
  ld    hl, # zx-spr-im2-wk-top lo-byte 256 *
  ld    spr-im2-top-cnt (), hl

  ld    h, # zx-spr-im2-wk-mid lo-byte
  ld    spr-im2-mid-cnt (), hl

  ld    h, # zx-spr-im2-wk-bot lo-byte
  ld    spr-im2-bot-cnt (), hl

  ;; set "no more records" flag
  xor   a
  ld    zx-spr-im2-wk-top (), a
  ld    zx-spr-im2-wk-mid (), a
  ld    zx-spr-im2-wk-bot (), a

  ;; H' will never change
  ld    h, # zx-spr-info-start-hi-byte
  exx

  ;; sort one queued sprite batch to 3 draw batches
  ld    hl, () zx-spr-queue-head
  ;; we need only low TAIL byte
  ld    a, () zx-spr-queue-tail
  ld    c, a

  ld    b, # SPR/INTR
  ;; C is TAIL
.sort-loop:
  ;; (the queue is guaranteed to not cross a page boundary)
  ld    a, l
  cp    c
  jr    z, # .sq-no-more-items

  ;; load sprite queue item
  ld    a, (hl)     ;; low byte of sprinfo address
  inc   l
  ;; we'll store the head later

  exx
  ;; H is `zx-spr-info-start-hi-byte`, A is low byte
  ld    l, a
  ;; loaded sprinfo addr to HL
  ;; reset "queued" flag
  res   7, (hl)
  inc   l           ;; skip flags
  inc   l           ;; skip attr
  ;; load high byte of the new scr$ address (it is high-endian)
  ld    a, (hl)
  dec   l           ;; back to attr
  ex    de, hl
  ;; DE=spr-info (after flags)
  ld    hl, # spr-im2-top-cnt
  cp    # $48
  jr    c, # .spr-wk-list-found
  ld    l, # spr-im2-mid-cnt lo-byte
  cp    # $50
  jr    c, # .spr-wk-list-found
  ld    l, # spr-im2-bot-cnt lo-byte
.spr-wk-list-found:
  ;; DE=spr-info
  ;; HL=wk-list-ptr-addr
  ;; it is guaranteed that all counters are on the one page
  ;; increment sprite counter
  inc   (hl)
  inc   l           ;; move to the pointer
  ;; load wk-list-ptr to BC
  ;; all 3 working lists are on the same page
  ld    c, (hl)     ;; load ptr
  ;; advance wk-list-ptr
  inc   c           ;; guaranteed to not cross the page
  ld    (hl), c     ;; store new wk-list-ptr
  ld    l, c        ;; move wk-list-ptr to HL
  ;; all 3 working lists are in the same page
  ld    h, # zx-spr-im2-wk-top hi-byte
  ;; HL=wk-list-pos-ptr (it is incremented by 2 here).
  ;; DE=spr-info, store it (only low byte).
  ld    (hl), # 0   ;; "end of list" flag
  dec   l
  ld    (hl), e
  ;; restore HL (we need H unchanged)
  ex    de, hl

  exx
  ;; normalise head pointer (wrap it if necessary)
  ld    a, l
  cp    # zx-spr-queue-end-lo-byte
  jr    c, # .head-is-ok
  ld    l, # zx-spr-queue-start-lo-byte
.head-is-ok:

  djnz  # .sort-loop
.sq-no-more-items:

  ;; save new SQ-HEAD
  ld    zx-spr-queue-head (), hl

  ;; the sprites are sorted to render batches.
  ;; now render the batches.

(*
estimated tstates per # of sprites:
   9460 -- 1
  17376 -- 2
  25430 -- 3
  33476 -- 4
  41490 -- 5
  49470 -- 6
  57490 -- 7
  65160 -- 8

with sticks: ~66800.
w/o ROM: ~65000

we 69888 tstates per frame for 48K.

first pixel starts at 14336. 224ts per line.
 first half ends at 28672.
second half ends at 43008.
 third half ends at 57344.

sprites can be in contended memory: it adds around 1K tstates
for 8 sprites, which is still acceptable.

with stick scan, it is around 66.5K tstates.

*)

  ;; if bottom list has 4 or more sprites, it is
  ;; guaranteed that the top 1/3 will be done when bottom is finished.
  ;; we can have at max 5 sprites in other screen parts.
  ld    a, () spr-im2-bot-cnt
  cp    # 4
  jp    nc, # .bot-top-mid

  ;; if middle list has 4 or more sprites, it is
  ;; guaranteed that the top 1/3 will be done when middle is finished.
  ld    a, () spr-im2-mid-cnt
  cp    # 4
  jp    nc, # .mid-top-bot

\ .mid-bot-top:
\   ld    hl, # zx-spr-im2-wk-mid
\   call  # spr-im2-render-batch
\   ld    hl, # zx-spr-im2-wk-bot
\   call  # spr-im2-render-batch
\   ld    hl, # zx-spr-im2-wk-top
\   call  # spr-im2-render-batch
\   jp    # spr-im2-quit

.top-bot-mid:
  ld    hl, # zx-spr-im2-wk-top
  call  # spr-im2-render-batch
  ld    hl, # zx-spr-im2-wk-bot
  call  # spr-im2-render-batch
  ld    hl, # zx-spr-im2-wk-mid
  call  # spr-im2-render-batch
  jp    # spr-im2-quit

.bot-top-mid:
  ld    hl, # zx-spr-im2-wk-bot
  call  # spr-im2-render-batch
  ld    hl, # zx-spr-im2-wk-top
  call  # spr-im2-render-batch
  ld    hl, # zx-spr-im2-wk-mid
  call  # spr-im2-render-batch
  jp    # spr-im2-quit

.mid-top-bot:
  ld    hl, # zx-spr-im2-wk-mid
  call  # spr-im2-render-batch
  ld    hl, # zx-spr-im2-wk-top
  call  # spr-im2-render-batch
  ld    hl, # zx-spr-im2-wk-bot
  call  # spr-im2-render-batch
  \ jp    # spr-im2-quit

spr-im2-quit:
  ;; restore all registers
  pop   bc
  pop   de
  pop   hl
  exx
  pop   af
  ex    af, afx
  pop   bc
  pop   de
  pop   iy
  pop   ix

  AFR-SPR16-IM2-TIMING [IF]
    zxemut-print-ts-counter
  [ENDIF]
  \ zxemut-bp
  ret

;; render sprite batch
;; HL=batch list address
;; spr-im2-wk-last=end addres
;; batch items are big-endian, list ends with 0 in high byte.
spr-im2-render-batch:
  ;; load spr-info address (it is high-endian)
  ld    a, (hl)     ;; addr: low byte
  or    a
  ret   z
  ld    e, a
  inc   l           ;; guaranteed to not cross a page
  ld    d, # zx-spr-info-start-hi-byte
  push  hl          ;; save batch list address
  ex    de, hl      ;; HL=spr-info
  ld    a, (hl)     ;; load sprite attribute
  push  af          ;; save attribute, we'll need it later
  inc   l           ;; skip attr (guaranteed to not cross a page)
  ;; load new scr$ address to DE (it is high-endian)
  ld    d, (hl)
  inc   l           ;; guaranteed to not cross a page
  ld    e, (hl)
  inc   l           ;; guaranteed to not cross a page
  ;; load new propmap address to IX
  ld    a, (hl)
  ld    ixh, a
  inc   l           ;; guaranteed to not cross a page
  ld    a, (hl)
  ld    ixl, a
  push  ix          ;; we will use this for attr change
  inc   l           ;; guaranteed to not cross a page
  ;; load new bmp-data address to BC
  ld    c, (hl)
  inc   l           ;; guaranteed to not cross a page
  ld    b, (hl)
  inc   l           ;; guaranteed to not cross a page
  ;; move bmp-data address to HL, and switch registers
  push  hl          ;; save spr-info address
  ld    hl, bc      ;; HL=bmp-data
  ex    de, hl      ;; DE=bmp-data, HL=scr$
  ;; load mask to C, and inverted mask to B
  ld    a, (de)
  inc   de
  ld    c, a
  cpl
  ld    b, a
  ;; fix code which will write the 3rd attr byte
  or    a           ;; Z set if we don't need to write 3rd byte
  jr    z, # .attr-instr-ok
  ld    a, # $12    ;; "ld (de), a"
.attr-instr-ok:
  ld    .attr-smc-3rd (), a
  exx               ;; we are now at "old data" register set
  pop   hl          ;; restore spr-info address
  ;; load old scr$ address to DE (it is high-endian)
  ld    d, (hl)
  inc   l           ;; guaranteed to not cross a page
  ld    e, (hl)
  inc   l           ;; guaranteed to not cross a page
  ;; load old attr address to IY (and move it to property map)
  ld    a, (hl)
  ld    iyh, a
  inc   l           ;; guaranteed to not cross a page
  ld    a, (hl)
  ld    iyl, a
  inc   l           ;; guaranteed to not cross a page
  ;; load old bmp-data address to HL
  ld    a, (hl)
  inc   l           ;; guaranteed to not cross a page
  ld    h, (hl)
  ld    l, a
  ex    de, hl      ;; DE=bmp-data, HL=scr$
  ;; load mask to C, and inverted mask to B
  ld    a, (de)
  inc   de
  ld    c, a
  cpl
  ld    b, a

  ;; now HL and DE (both normal, and alternate) hold bmp and scr$ addresses.
  ;; print sprite lines (alternating them).
  ;; we are now at "old data" register set.
  \ call # spr-im2-print-spr-line  call # spr-im2-print-spr-line  ;; 0
  call # spr-im2-print-spr-line-no-up-old exx
  call # spr-im2-print-spr-line-no-up-new   ;; at "new data" register set

  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 1
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 2
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 3
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 4
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 5
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 6
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 7
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 8
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 9
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 10
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 11
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 12
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 13
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 14
  call # spr-im2-print-spr-line-old  call # spr-im2-print-spr-line-new  ;; 15
  ;; done

  ;; we are now at "new data" register set.
  ;; HL contains "scr$+2" (we are interested only in H).
  ;; set attributes? ($FE, $FF: don't set)
  pop   de        ;; restore propmap address (it was pushed above)
  pop   af        ;; sprite attribute
  cp    # $FE
  jr    nc, # .skip-attr-set

  ;; yes, set attributes
  ld    c, a      ;; save attrs to C
  ld    a, h      ;; high byte of scr$
  cp    # $40     ;; it may be off-screen
  jr    c, # .skip-attr-set
  ld    b, # $FF  ;; we need it to be -1!
  ex    de, hl    ;; HL is propmap address
  exx
  ld    b, # 2    ;; 2 attribute lines
  ;; if low 3 bits of high byte of scr$ addr is not 0, we need to fill 3 lines
  and   # $07
  jr    z, # .yes-2-lines
  inc   b         ;; 3 lines
.yes-2-lines:
  exx             ;; B'=line counter
  ;; HL=propmap address
  ;;  C=attr
  ;; B'=row count
  ;; it is guaranteed that all rows are on-screen (i.e. no clipping).
  ;; DE will be attr addrress
  ld    e, l
  ld    a, h
  sub   # zx-spr-prop-map hi-byte $58 -
  ld    d, a
  ;; DE=attr address (from $5800)
  ;; HL=propmap addr
  ;;  C=attr
  ;;  B=row count
  ;; it is guaranteed that all rows are on-screen (i.e. no clipping).
  jp    # .attr-loop-skip-up
.attr-loop:
  exx
  ;; move to the next attr row
  ld    a, c      ;; save attr temporarily
  ld    c, # -34  ;; prev row
  add   hl, bc    ;; attr up
  ex    de, hl
  add   hl, bc    ;; propmap up
  ex    de, hl
  ld    c, a      ;; restore attr
.attr-loop-skip-up:
  ;; first attr
  ;; check property map
  ;; using "ld+rlca" is 1ts faster than "bit", and of the same size
  ;; check bit 7
  ld    a, (hl)
  rlca
  jr    c, # .skip-1st-attr
  ld    a, (de)
  and   # zx-spr-attr-mask-const
  or    c
  ld    (de), a
.skip-1st-attr:
  inc   e
  inc   l
  ;; second attr
  ;; check property map
  ;; using "ld+rlca" is 1ts faster than "bit", and of the same size
  ;; check bit 7
  ld    a, (hl)
  rlca
  jr    c, # .skip-2nd-attr
  ld    a, (de)
  and   # zx-spr-attr-mask-const
  or    c
  ld    (de), a
.skip-2nd-attr:
  inc   e
  inc   l
  ;; third attr
  ;; check property map
  ;; using "ld+rlca" is 1ts faster than "bit", and of the same size
  ;; check bit 7
  ld    a, (hl)
  rlca
  jr    c, # .skip-3rd-attr
  ld    a, (de)
  and   # zx-spr-attr-mask-const
  or    c
.attr-smc-3rd:
  ld    (de), a
.skip-3rd-attr:

  exx
  djnz  # .attr-loop

.skip-attr-set:
  pop   hl
  jp    # spr-im2-render-batch

;; print one sprite line (old data, no attr change)
;; DE=line-data-addr
;; HL=scr$-addr
;;  C=mask for the left byte
;;  B=mask for the right byte
;; uses AF and AFx
spr-im2-print-spr-line-old:
  exx
  ;; restore horizontal position
  dec   l
  dec   l
  ;; up-hl
  ld    a, h
  dec   h
  and   # $07
  jr    nz, # .do-blit
  ld    a, l
  sub   # 32
  ld    l, a
  jr    c, # .advance-prop-addr
  ld    a, h
  add   # 8
  ld    h, a
.advance-prop-addr:
  ;; advance IY (we are going up)
  push  de
  ld    de, # -32
  add   iy, de
  pop   de
  ;; 11+10+15+10=46 (3ts faster than doing it with A)
@spr-im2-print-spr-line-no-up-old:
  ;; patch the code according to the property map (IY points to it)
  ;; first instruction
  ld    a, # $77    ;; "ld (hl), a"
  bit   6, (iy)
  jr    z, # $ 3 +  ;; skip next instruction
  xor   a
  ld    spr-im2-old-1st-byte-instr (), a
  ;; second instruction
  ld    a, # $77    ;; "ld (hl), a"
  bit   6, (iy+) 1
  jr    z, # $ 3 +  ;; skip next instruction
  xor   a
  ld    spr-im2-old-2nd-byte-instr (), a
  ;; third instruction
  ld    a, # $77    ;; "ld (hl), a"
  bit   6, (iy+) 2
  jr    z, # $ 3 +  ;; skip next instruction
  xor   a
  ld    spr-im2-old-3rd-byte-instr (), a
.do-blit:
  ;; use "ex af, af'" to save the first byte: this is: 7+4+4=15ts
  ;; loading it again: 6+7+6=19ts (dec de / ld a, (de) / inc de)
  ;; first byte
  ld    a, (de)
  ex    af, afx   ;; save for the last blit
  ld    a, (de)
  and   c
  AFR-SPR16-OR/AND [IF]
  cpl
  and   (hl)
  [ELSE]
  xor   (hl)
  [ENDIF]
@spr-im2-old-1st-byte-instr:
  ld    (hl), a
  inc   de
  inc   l
  ;; second byte
  ld    a, (de)
  AFR-SPR16-OR/AND [IF]
  cpl
  and   (hl)
  [ELSE]
  xor   (hl)
  [ENDIF]
@spr-im2-old-2nd-byte-instr:
  ld    (hl), a
  inc   de
  inc   l
  ;; third byte
  ex    af, afx
  and   b
  ;; do not early exit, to keep timings more stable
  \ ret   z
  AFR-SPR16-OR/AND [IF]
  cpl
  and   (hl)
  [ELSE]
  xor   (hl)
  [ENDIF]
@spr-im2-old-3rd-byte-instr:
  ld    (hl), a
  ret

;; print one sprite line (new data, attr change)
;; DE=line-data-addr
;; HL=scr$-addr
;;  C=mask for the left byte
;;  B=mask for the right byte
;; uses AF and AFx
spr-im2-print-spr-line-new:
  exx
  ;; restore horizontal position
  dec   l
  dec   l
  ;; up-hl
  ld    a, h
  dec   h
  and   # $07
  jr    nz, # .do-blit
  ld    a, l
  sub   # 32
  ld    l, a
  jr    c, # .advance-prop-addr
  ld    a, h
  add   # 8
  ld    h, a
.advance-prop-addr:
  ;; advance IX (we are going up)
  push  de
  ld    de, # -32
  add   ix, de
  pop   de
  ;; 11+10+15+10=46 (3ts faster than doing it with A)
@spr-im2-print-spr-line-no-up-new:
  ;; patch the code according to the property map (IX points to it)
  ;; attrs themselves will be fixed later
  ;; first instruction
  ld    a, # $77    ;; "ld (hl), a"
  bit   6, (ix)
  jr    z, # $ 3 +  ;; skip next instruction
  xor   a
  ld    spr-im2-new-1st-byte-instr (), a
  ;; second instruction
  ld    a, # $77    ;; "ld (hl), a"
  bit   6, (ix+) 1
  jr    z, # $ 3 +  ;; skip next instruction
  xor   a
  ld    spr-im2-new-2nd-byte-instr (), a
  ;; third instruction
  ld    a, # $77    ;; "ld (hl), a"
  bit   6, (ix+) 2
  jr    z, # $ 3 +  ;; skip next instruction
  xor   a
  ld    spr-im2-new-3rd-byte-instr (), a
.do-blit:
  ;; first byte
  ld    a, (de)
  ex    af, afx   ;; save for the last blit
  ld    a, (de)
  and   c
  AFR-SPR16-OR/AND [IF]
  or    (hl)
  [ELSE]
  xor   (hl)
  [ENDIF]
@spr-im2-new-1st-byte-instr:
  ld    (hl), a
  inc   de
  inc   l
  ;; second byte
  ld    a, (de)
  AFR-SPR16-OR/AND [IF]
  or    (hl)
  [ELSE]
  xor   (hl)
  [ENDIF]
@spr-im2-new-2nd-byte-instr:
  ld    (hl), a
  inc   de
  inc   l
  ;; third byte
  ex    af, afx
  and   b
  ;; do not early exit, to keep timings more stable
  \ ret   z
  AFR-SPR16-OR/AND [IF]
  or    (hl)
  [ELSE]
  xor   (hl)
  [ENDIF]
@spr-im2-new-3rd-byte-instr:
  ld    (hl), a
  ret

\ spr-saved-7ffd: 0 dw,
\ spr-saved-1ffd: 0 dw,
;code-no-next


: SPR-ON  ( enable blitter)  asm-label: zx-spr-iff C!1 ; zx-inline
: SPR-OFF ( disable blitter) asm-label: zx-spr-iff C!0 ; zx-inline


0 quan (spr-prev-im2)

;; setup IM2 handler
: SPR-SETUP
  \ [ OPT-BLOCK-I/O-TYPE R/W-P3DOS = ] [IF] +3DOS-MOTOR-OFF [ENDIF]
  (spr-prev-im2) ?exit
  DI
  \ asm-label: sysvar-cur-7FFD @ asm-label: spr-saved-7ffd !
  \ asm-label: sysvar-cur-1FFD @ asm-label: spr-saved-1ffd !
  SPR-INIT
  [ OPT-SPR16-REPLACE-IM2? ] [IF]
    $FFF5 @ (spr-prev-im2):!
    asm-label: spr-blitter-im2 $FFF5 !
  [ELSE]
    SYS: IM2-PROC@ (spr-prev-im2):!
    asm-label: spr-blitter-im2 SYS: IM2-PROC!
    SYS: NO-ROM-IM1
  [ENDIF]
  SPR-OFF
  EI ;

: SPR-UNSETUP
  (spr-prev-im2) 0?exit
  DI
  \ asm-label: spr-saved-7ffd @ asm-label: sysvar-cur-7FFD !
  \ asm-label: spr-saved-1ffd @ asm-label: sysvar-cur-1FFD !
  [ OPT-SPR16-REPLACE-IM2? ] [IF]
    (spr-prev-im2) $FFF5 !
  [ELSE]
    (spr-prev-im2) SYS: IM2-PROC!
    SYS: ROM-IM1-LAST
  [ENDIF]
  (spr-prev-im2):!0
  SPR-OFF
  EI ;


;; return "accumulated" stick state. reset accumulator.
primitive: STICK@  ( -- acc-state )
Succubus:setters:out-8bit
:codegen-xasm
  push-tos-peephole
  ;; this code attempts to cope with the possible interrupt
  @label: zx-spr-ctb 1+ #->hl
  xor-a-a
  (hl)->c
  a->(hl)
  (hl)->b
  a->(hl)
  c->a
  or-a-b
  a->tos ;

;; return last read stick state. don't reset anything.
primitive: LAST-STICK@  ( -- state )
Succubus:setters:out-8bit
:codegen-xasm
  push-tos-peephole
  @label: zx-spr-ctb tos-r16 (nn)->r16
  0 tos-r16 c#->r16h ;

zxlib-end
