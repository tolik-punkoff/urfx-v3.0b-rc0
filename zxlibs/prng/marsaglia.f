zxlib-begin" Marsaglia PRNG"

true constant URND-32-BIT-SEED?
false constant URND-CMWC?


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; generate a random number.
;; period of 2^32-1, and passes most of the diehard tests.
;; this is the preferred PRNG, it is fast, small and good.
;; it is one of the fastest PRNGs out there with good distribution.
;;
;; IN:
;;   mr16-prng-seed0, mr16-prng-seed1: 32 bits of the initial seed
;;   WARNING! initial seed must not be zero!
;; OUT:
;;   HL: 16-bit random
;;    A: weak 8-bit random (the same as L); use `add a, h` to get better result
;;   DE: dead
;;   flags: CARRY reset, others dead
;;
;;  taken from http://www.worldofspectrum.org/forums/showthread.php?t=23070
;;  original code by Patrik Rak (2012, based on Einar Saukas version)
;;
raw-code: (*URND16-DON'T-CALL*)
  ret
mr16-prng:
  ld    hl, # $A29A ;; yw -> zt
$here 2- @def: mr16-prng-seed0
  ld    de, # $C0DE ;; xz -> yw
$here 2- @def: mr16-prng-seed1
  ld    mr16-prng-seed1 (), hl  ;; x = y, z = w
  ld    a, l        ;; w = w^(w<<3)
  add   a, a
  add   a, a
  add   a, a
  xor   l
  ld    l, a
  ld    a, d        ;; t = x^(x<<1)
  add   a, a
  xor   d
  ld    h, a
  rra               ;; t = t^(t>>1)^w
  xor   h
  xor   l
  ld    h, e        ;; y = z
  ld    l, a        ;; w = t
  ld    mr16-prng-seed0 (), hl
;; 10+10+16+4*15+16=112
  ret
;code-no-next

primitive: URND16  ( -- u16 )
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole-restore-tos-hl
  @label: mr16-prng call-# ;

primitive: URND8  ( -- u8 )
Succubus:setters:out-8bit
zx-required: (*URND16-DON'T-CALL*)
:codegen-xasm
  push-tos-peephole-restore-tos-hl
  @label: mr16-prng call-#
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
  ld    hl, # $C0DE
.seed-ok1:
  ld    (mr16-prng-seed1), hl
  ex    de, hl
  ld    a, l
  or    h
  jr    nz, # .seed-ok0
  ld    hl, # $A29A
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
  @label: mr16-prng-seed0 (nn)->hl
  push-hl
  @label: mr16-prng-seed1 (nn)->tos ;


zxlib-end
