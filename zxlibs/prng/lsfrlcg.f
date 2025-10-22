zxlib-begin" LSFR PRNG"

true constant URND-32-BIT-SEED?
false constant URND-CMWC?


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; generate random number
;; this is quite fast, quality pseudo-random number generator
;; it combines a 16-bit Linear Feedback Shift Register and a 16-bit LCG
;; cycle: 4,294,901,760 (almost 4.3 billion)
;; IN:
;;   rndSeed: 4 bytes of shit (second word should not be zero!)
;; OUT:
;;   HL: 16-bit random
;;   DE: dead (result of the LCG, so not that great of quality)
;;   AF: dead
;; WARNING:
;;  be careful to not have all zeroes in rndSeed!
raw-code: (*URND16-DON'T-CALL*)
  ret
lsfr16-prng:
  ld    hl, # $6B_38
$here 2- @def: lsfr16-prng-seed0
  ld    d, h
  ld    e, l
  add   hl, hl
  add   hl, hl
  inc   l
  add   hl, de
  ld    lsfr16-prng-seed0 (), hl
  ld    hl, # $74_68
$here 2- @def: lsfr16-prng-seed1
  add   hl, hl
  sbc   a, a
  and   # %00101101
  xor   l
  ld    l, a
  ld    lsfr16-prng-seed1 (), hl
  add   hl, de
;; 10+4+4+11+11+4+11+16+10+11+4+7+4+4+16+11=138
  ret
;code-no-next

primitive: URND16  ( -- u16 )
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole-restore-tos-hl
  @label: lsfr16-prng call-# ;

primitive: URND8  ( -- u8 )
Succubus:setters:out-8bit
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole-restore-tos-hl
  @label: lsfr16-prng call-#
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
  ld    hl, # $74_68
.seed-ok1:
  ld    (lsfr16-prng-seed1), hl
  ex    de, hl
  ld    a, l
  or    h
  jr    nz, # .seed-ok0
  ld    hl, # $6B_38
.seed-ok0:
  ld    (lsfr16-prng-seed0), hl
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
  @label: lsfr16-prng-seed0 (nn)->hl
  push-hl
  @label: lsfr16-prng-seed1 (nn)->tos ;


zxlib-end
