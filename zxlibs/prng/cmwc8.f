zxlib-begin" CMWC PRNG"

true constant URND-32-BIT-SEED?
true constant URND-CMWC?


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8-bit Complementary-Multiply-With-Carry (CMWC) random number generator.
;; Created by Patrik Rak in 2012, and revised in 2014/2015,
;; with optimization contribution from Einar Saukas and Alan Albrecht.
;; See http://www.worldofspectrum.org/forums/showthread.php?t=39632

code: URND8  ( -- u8 )
  push  hl

  ld    hl, # cmwc-table

  ld    a, (hl)   ;; i = ( i & 7 ) + 1
  and   # $07
  inc   a
  ld    (hl),a

  inc   l         ;; hl = &cy

  ld    d, h      ;; de = &q[i]
  add   a, l
  ld    e, a

  ld    a, (de)   ;; y = q[i]
  ld    b, a
  ld    c, a
  ld    a, (hl)   ;; ba = 256 * y + cy

  sub   c         ;; ba = 255 * y + cy
  jr    nc, # $ 3 +
  dec   b

  sub   c         ;; ba = 254 * y + cy
  jr    nc, # $ 3 +
  dec   b

  sub   c         ;; ba = 253 * y + cy
  jr    nc, # $ 3 +
  dec   b

  ld    (hl), b   ;; cy = ba >> 8, x = ba & 255
  cpl             ;; x = (b-1) - x = -x - 1 = ~x + 1 - 1 = ~x
  ld    (de), a   ;; q[i] = x

  ld    l, a
  ld    h, # 0

  ;; 10+7+7+4+7+4+4+4+4+7+4+4+7+4+12+4+12+4+12+7+4+7=139
  ;; 139+4+7=150
  next

" CMWC table" 10 zx-asm-align-page-fit

@cmwc-table:
  0 db, 0 db,
  82 db,
  97 db,
  120 db,
  111 db,
  102 db,
  116 db,
  20 db,
  15 db,
;code-no-next
Succubus:setters:out-8bit


;; this will NOT fully reset the generator!
primitive: URANDOMIZE  ( u16 )
zx-required: URND8
:codegen-xasm
  @label: cmwc-table tos->(nn)
  pop-tos ;

primitive: USEED16@  ( -- u16 )
zx-required: URND8
:codegen-xasm
  push-tos-peephole
  @label: cmwc-table (nn)->tos ;


zxlib-end
