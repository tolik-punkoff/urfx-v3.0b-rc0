zxlib-begin" Marsaglia789 PRNG"

false constant URND-32-BIT-SEED?
false constant URND-CMWC?


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; generate random number
;; 16-bit xorshift pseudorandom number generator by John Metcalf
;; generates 16-bit pseudorandom numbers with a period of 65535
;; using the xorshift method:
;;
;; hl ^= hl << 7
;; hl ^= hl >> 9
;; hl ^= hl << 8
;;
;; some alternative shift triplets which also perform well are:
;; 6, 7, 13; 7, 9, 13; 9, 7, 13.
;;
;; IN:
;;   rndSeed: 2 bytes of shit (must not be 0)
;; OUT:
;;   HL: 16-bit random
;;   AF: dead
;; WARNING:
;;  be careful to not have all zeroes in rndSeed!
;;
;; ketmar's note: this one can be used to "dissolve" (and "ensolve")
;; the screen
raw-code: (*URND16-DON'T-CALL*)
  ret
xs16-prng:
  ld    hl, # $C0DE     ;; seed must not be 0
$here 2- @def: xs-prng-seed
  ld    a, h
  rra
  ld    a, l
  rra
  xor   h
  ld    h, a
  ld    a, l
  rra
  ld    a, h
  rra
  xor   l
  ld    l, a
  xor   h
  ld    h, a
  ld    xs-prng-seed (), hl
;; 10+4*14+16=82
  ret
;code-no-next

primitive: URND16  ( -- u16 )
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole-restore-tos-hl
  @label: xs16-prng call-# ;

primitive: URND8  ( -- u8 )
Succubus:setters:out-8bit
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole-restore-tos-hl
  @label: xs16-prng call-#
  add-a-h
  a->l
  0 c#->h ;


code: URANDOMIZE  ( u16 )
  call  # zx-word-urandomize-entry
  pop   hl
  next
zx-word-urandomize-entry:
  ld    a, h
  or    l
  jr    nz, # .seed-ok
  ld    hl, # $C0DE
.seed-ok:
  ld    (xs-prng-seed), hl
  ret
;code-no-next

primitive: URANDOMIZE2  ( u16 u16 )
zx-required: URANDOMIZE
:codegen-xasm
  pop-non-tos-peephole
  add-hl-de
  restore-tos-hl
  @label: zx-word-urandomize-entry call-# ;

;; suitable for `URANDOMIZE2`
primitive: USEED@  ( -- u16-0 u16-1 )
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole
  @label: xs-prng-seed (nn)->hl
  push-hl
  0 #->tos ;

zxlib-end
