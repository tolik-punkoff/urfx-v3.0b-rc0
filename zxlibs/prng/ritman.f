zxlib-begin" Ritman PRNG"

true constant URND-32-BIT-SEED?
false constant URND-CMWC?


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; https://spectrumcomputing.co.uk/entry/24222/ZX-Spectrum/Star_Tip_3
;; generate random number
;; IN:
;;   rit16-prng-seed: 4 bytes of shit
;; OUT:
;;   HL: 16-bit random
;;   DE: either dead or uncomment the line to get 32-bit number
;;   BC: dead
;;   AF: dead
;; WARNING:
;;  be careful to not have all zeroes in rit16-prng-seed!
raw-code: (*URND16-DON'T-CALL*)
  ret
;; not-so-bad initial value
rit16-prng-seed0: $6B_38 dw,
rit16-prng-seed1: $68_74 dw,
rit16-prng:
  ld    hl, () rit16-prng-seed1
  ld    d, l
  add   hl, hl
  add   hl, hl
  ld    c, h
  ld    hl, () rit16-prng-seed0
  ld    b, h
  rl    b
  ld    e, h
  rl    e
  rl    d
  add   hl, bc
  ld    rit16-prng-seed0 (), hl
  ld    hl, () rit16-prng-seed1
  adc   hl, de
  res   7, h
  ld    rit16-prng-seed1 (), hl
  jp    m, # .done
  ld    hl, # rit16-prng-seed0
.gotzero:
  inc   (hl)
  inc   hl
  jr    z, # .gotzero
.done:
  ld    hl, () rit16-prng-seed0
  \ ld   de, (rit16-prng-seed1)
;; 16+4+11+11+4+16+4+4+4+4+4+11+16+16+11+8+16+10+10=180
  ret
;code-no-next

primitive: URND16  ( -- u16 )
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole-restore-tos-hl
  @label: rit16-prng call-# ;

primitive: URND8  ( -- u8 )
Succubus:setters:out-8bit
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole-restore-tos-hl
  @label: rit16-prng call-#
  add-a-h
  a->l
  0 c#->h ;


;; values should not be zero!
code: URANDOMIZE2  ( u16-0 u16-1 )
  pop   de
  call  # zx-word-urandomize2-entry
  pop   hl
  next
zx-word-urandomize2-entry:
  ;; DE: u16-0
  ;; HL: u16-1
  ld    a, l
  or    h
  jr    nz, # .seed-ok1
  ld    hl, # $68_74
.seed-ok1:
  ld    (rit16-prng-seed1), hl
  ex    de, hl
  ld    a, l
  or    h
  jr    nz, # .seed-ok0
  ld    hl, # $6B_38
.seed-ok0:
  ld    (mr16-prng-seed0), hl
  ret
;code-no-next

primitive: URANDOMIZE  ( u16 )
zx-required: URANDOMIZE2
:codegen-xasm
  TOS-in-HL? ?<
    0 #->de
    ex-de-hl
  ||
    0 #->hl
    TOS-in-HL!
  >?
  @label: zx-word-urandomize2-entry call-#
  pop-tos ;

;; suitable for `URANDOMIZE2`
primitive: USEED@  ( -- u16-0 u16-1 )
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole
  @label: rit16-prng-seed0 (nn)->hl
  push-hl
  @label: rit16-prng-seed1 (nn)->tos ;


zxlib-end
