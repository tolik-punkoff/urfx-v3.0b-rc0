;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; initial code: startup, variables, etc.
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

zx-base-addr zxa:org!
zx-base-addr zxa:ent!
\ zx-base-addr zxa:clr!
$5F00 1- zxa:clr!


: Succubus-mark-string  ( addr count )
  " \nUrF/X Forth System (Succubus/Z80) v3.0b by Ketmar Dark, 2024-2025\nC.C.X.!\n" ;

: put-Succubus-mark
  ;; copyright string.
  ;; no, you cannot remove it, it is prohibited.
  Succubus-mark-string tcom:(zx-raw-str-asm)
  [ 0 ] [IF]
  "  CCCCCCC   XX     XX\n" tcom:(zx-raw-str-asm)
  " CC     CC   XX   XX\n" tcom:(zx-raw-str-asm)
  " CC           XX XX\n" tcom:(zx-raw-str-asm)
  " CC   CCCCCCC  XXX\n" tcom:(zx-raw-str-asm)
  " CC  CC     CC XXX\n" tcom:(zx-raw-str-asm)
  " CC  CC       XX XX\n" tcom:(zx-raw-str-asm)
  " CC  CC CC   XX   XX\n" tcom:(zx-raw-str-asm)
  "  CCCCCCC   XX     XX\n" tcom:(zx-raw-str-asm)
  "     CC\n" tcom:(zx-raw-str-asm)
  "     CC     CC\n" tcom:(zx-raw-str-asm)
  "      CCCCCCC\n" tcom:(zx-raw-str-asm)
  [ENDIF]
;


<asm>
cold-entry:
  di
  jp    # zx-setup-code
flush!

;; used in "BIT?", should be on the one page
" bit-mask table" 8 zx-asm-align-page-fit
bit-mask-table:
  $01 db,
  $02 db,
  $04 db,
  $08 db,
  $10 db,
  $20 db,
  $40 db,
  $80 db,


<zx-definitions>
$5B5C label sysvar-bankm
$5B67 label sysvar-bank678

$5B5C label sysvar-cur-7FFD
$5B67 label sysvar-cur-1FFD

23613 label sysvar-err-sp
23659 label sysvar-defsz

23658 label sysvar-flags2

23692 label sysvar-scr-ct     ;; scroll count

$5C00 label sysvar-kstate
$5C08 label sysvar-last-k
$5C09 label sysvar-rep-del
$5C0A label sysvar-rep-per

23672 label sysvar-frames

\ 23608 constant-and-label RASP sysvar-rasp
<zx-done>


OPT-SIMPLIFIED-IM? [IF]
;; use ROM IM handler
urfx-IntrHandler:
  push  af
  push  hl

  ;; this is 31ts 255 times, and 46ts once in a 256 calls.
  ;; the simplier code is always 38ts.
  1 [IF]
  ld    hl, # sysvar-frames
  inc   (hl)
  jp    nz, # .no-2nd-frames-byte
  inc   l
  inc   (hl)
.no-2nd-frames-byte:
  [ELSE]
  ;; this is always 38 ts
  ld    hl, () sysvar-frames
  inc   hl
  ld    sysvar-frames (), hl
  [ENDIF]

  ;; call our IM1 handler before user handler?
  ;; 0: no; 1: before; 2: after
  ld    a, # 2    ;; self-modifying code
;; values: 0 -- don't call; 1: before; 2: after
$here 1- @def: zx-im2-rom-im1
  dec   a
  call  z, # .intr-keyboard-handler
  di              ;; because ROM enabled it
  ;; call user handler
  call  # dummy-im2-userproc  ;; self-modifying code
$here 2- @def: zx-im2-userproc-addr
  ;; call ROM IM1 handler after user handler?
  ld    a, () zx-im2-rom-im1
  cp    # 2
  call  z, # .intr-keyboard-handler

  pop   hl
  pop   af
  ei
  ret   ;; it should be reti, but meh

;; this is used instead of ROM interrupt handler
.intr-keyboard-handler:
  push  de
  push  bc

  call  # $028E   ;; ROM keyboard scan
  ;; result:
  ;;  E: pressed key -- [0..39], or $FF (25 is CAPS+SYM)
  ;;  D: shift key, or $FF: 40 for CAPS, 25 for SYM
  ;;  zero flag: reset if more than 2 keys are pressed, or on invalid key combo
  ;; my KSTATE format:
  ;;  +0: key code we are going to repeat or $FF
  ;;  +1: frames until repeat
  jr    nz, # .invalid-key
  ld    a, e
  cp    # 40
  jr    nc, # .invalid-key

  0 [IF]
  push  af
  zxemut-emit-dec-a
  ld    a, # 32
  zxemut-emit-char-a
  ld    a, d
  zxemut-emit-dec-a
  ld    a, # 13
  zxemut-emit-char-a
  [ENDIF]

  ;; CAPS?
  ld    a, d
  cp    # 39
  ld    a, e
  jr    nz, # .no-caps
  cp    # 35
  jr    c, # .no-caps
  cp    # 37
  jr    nc, # .no-caps
  sub   a, # 35
  ld    c, # 12 ;; delete
  jr    z, # .caps-done
  ld    c, # 7  ;; edit
  jp    # .caps-done

.no-caps:
  ld    d, # 0
  ld    hl, # $0205
  add   hl, de
  ld    c, (hl)
.caps-done:
  ;; C is key code
  ld    hl, # sysvar-kstate
  ld    a, (hl)
  cp    c
  jr    z, # .do-autorepeat
  ;; new key
  ld    a, () sysvar-rep-del
  ld    b, a
  ld    sysvar-kstate (), bc
  ld    a, c
  ld    sysvar-last-k (), a
  jp    # .done

.do-autorepeat:
  inc   l
  dec   (hl)
  jr    nz, # .done
  ld    sysvar-last-k (), a
  ld    a, () sysvar-rep-per
  ld    (hl), a

.done:
  pop   bc
  pop   de
  ret

.invalid-key:
  ld    a, # $FF
  ld    sysvar-kstate (), a
  jr    # .done

[ELSE]
;; use ROM IM handler
urfx-IntrHandler:
  push  af
  push  hl
  push  iy
  ;; call ROM IM1 handler before user handler?
  ;; 0: no; 1: before; 2: after
  ld    a, # 2    ;; self-modifying code
;; values: 0 -- don't call; 1: before; 2: after
$here 1- @def: zx-im2-rom-im1
  dec   a
  call  z, # .call-rom-im1
  di              ;; because ROM enabled it
  ;; call user handler
  call  # dummy-im2-userproc  ;; self-modifying code
$here 2- @def: zx-im2-userproc-addr
  ;; call ROM IM1 handler after user handler?
  ld    a, () zx-im2-rom-im1
  cp    # 2
  call  z, # .call-rom-im1
  pop   iy
  pop   hl
  pop   af
  ei
  ret   ;; it should be reti, but meh
.call-rom-im1:
  ld    iy, # $5C3A
  jp    # $0038
[ENDIF]

dummy-im2-userproc:
  ret
flush!

;; non-user global system variables
$here zx-dp^:!
zx-var-dp: 0 dw,

$here zx-p3dos-flag^:!
zx-p3dos-flag: 0 dw,

$here zx-128k-flag^:!
zx-128k-flag: 0 dw,

flush!


0 quan (saved-zx-org)

;; put init code before the main code
zx-init-code-size [IF]
  zxa:org@ (saved-zx-org):!
  zx-base-addr zx-init-code-size - zxa:org!
[ENDIF]

$here
;; copyright string.
;; no, you cannot remove it, it is prohibited.
put-Succubus-mark

zx-setup-code:
  ;; we need to have at least one line in the bottom area
  restore-iy
  ld    a, # 1
  ld    sysvar-defsz (), a
  ;; open ROM channel #2 for i/o
  inc   a
  call  # $1601

  di

  ;; fuck off, ULA+!
  ld    bc, # $BF3B
  ld    a, # $40
  out   (c), a
  ld    bc, # $FF3B
  xor   a
  out   (c), a

  ;; print whole 24 lines
  xor   a
  ld    sysvar-defsz (), a
  ;; no scroll prompt
  dec   a
  ld    sysvar-scr-ct (), a

  ;; turn on CAPS LOCK
  ld    a, # 8
  ld    sysvar-flags2 (), a

  ;; default is no +3DOS
  xor   a
  ld    () zx-p3dos-flag, a

  ;; setup 128K state (it won't hurt 48K)
  ld    bc, # $7FFD
  ld    a, # $10    ;; ROM1 (48K), RAM 520
  out   (c), a

  ;; test for 128K
  ;; map $4000 at $C000, and trash the byte
  ld    hl, # zx-128k-flag
  ld    (hl), # 0   ;; default is 48K
  ;; save byte at $C000 for 48K
  ex    de, hl
  ld    hl, # $C000
  ld    a, (hl)
  ex    af, afx
  ;; trash byte at $C000
  xor   a
  ;; $C000 safeguard
  $here $C000 3 - $C000 3 + forth:within [IF]
    " \'(COLD)\' is at the invalid address!" error
  [ENDIF]
  ld    (hl), a
  ;; switch memory page
  ;;ld    bc, # $7FFD
  ld    a, # $15    ;; ROM1 (48K), RAM 525
  out   (c), a      ;; now $C000 should be the screen page #5
  ld    (hl), a     ;; trash it
  ;; restore RAM mapping (just in case)
  ld    a, # $10    ;; ROM1 (48K), RAM 520
  out   (c), a
  ;; check SCR$ byte
  ld    a, () $4000
  or    a
  ;; restore $C000 byte
  ex    af, afx
  ld    (hl), a
  ex    af, afx
  jr    z, # .model-is-48k
  ;; 128K model
  ex    de, hl
  inc   (hl)
  ;; set 7FFD sysvar
  ld    a, # $10
  ld    sysvar-cur-7FFD (), a

  ;; assume that on +3 we came here from a disk loader,
  ;; so disk motor is on. it is controlled by bit 4 of
  ;; FLAGS sysvar, so let's use it. bit 4 should be reset
  ;; on 48K. dunno about 128K.

  ;; this sysvar is 0 for 48K/128K
  ld    a, () sysvar-cur-1FFD
  or    a
  jr    z, # .not-plus-n

  ;; check if +3DOS ROM is available.
  ;; 128K control port:
  xor   a
  out   (c), a
  ;; set +2A/+3 port #1FFD
  ld    b, # $1F
  ld    a, () sysvar-cur-1FFD
  or    # $04               ;; switch on +3DOS ROM
  out   (c), a

  ;; at $0000 +3DOS ROM has zeroes
  ld    hl, () $0000
  ld    a, l
  or    h
  jr    nz, # .no-plus3dos-rom
  ;; at $0008 +3DOS ROM has "PLUS3DOS" string.
  ;; check "PL" and "3D".
  ld    hl, () $0008
  ld    de, # $4C50
  sbc   hl, de
  jr    nz, # .no-plus3dos-rom
  ld    hl, () $000C
  ld    de, # $4433
  sbc   hl, de
  jr    nz, # .no-plus3dos-rom
  ;; set the flag
  ld    a, # 1
  ld    zx-p3dos-flag (), a
.no-plus3dos-rom:
  ;; switch to 48K BASIC ROM
  ld    a, () sysvar-cur-1FFD
  and   # $F8
  or    # $04       ;; bit 2: BASIC ROM
  out   (c), a
  ld    sysvar-cur-1FFD (), a
  ;; as machines without #1FFD may map this to #7FFD, restore #7FFD value
  ld    b, # $7F
  ld    a, () sysvar-cur-7FFD
  out   (c), a
.not-plus-n:

.model-is-48k:
  ;; interrupts are disabled here

  ;; setup interrupt table
  ;; this is using an old trick:
  ;; 48K ROM has a lot of #FF (more than 256),
  ;; so we can use it as interrupt table.
  ;; this way, the interrupt will jump at #FFFF.
  ;; this is not that useful... but we can put "JR"
  ;; opcode there, and it will jump to #FFF4
  ;; (due to first ROM byte being DI opcode aka #F3).
  ;; and we can put a real jump to our interrupt
  ;; routine at #FFF4.
  ;; so we cannot use last UDG, but meh... not a big deal.

  ;; check if ROM starts with "#F3" (this will be JR disp)
  ld    a, () 0
  cp    # $F3
  jr    nz, # .cannot_use_im2

  ld    hl, # $3BFF
  ld    a, (hl)
  inc   (hl)      ;; smaller than load and compare, and ROM ignores the changes anyway
  jr    nz, # .cannot_use_im2
  inc   hl
  inc   (hl)      ;; smaller than load and compare, and ROM ignores the changes anyway
  jr    nz, # .cannot_use_im2

  \ di
  ld    a, # $3B  ;; ROM contains a lot of #FF there
  ;; I register points to area filled with #FF here
  ld    i, a
  ;; write JR opcode to #FFFF
  ld    a, # $18
  ld    $FFFF (), a   ;; jr
  ;; write JP opcode to #FFF4
  ld    a, # $C3      ;; jp
  ld    $FFF4 (), a
  ;; write interrupt handler address to #FFF5
  ld    hl, # urfx-IntrHandler
  ld    $FFF5 (), hl
  ;; switch to interrupt mode #2
  im    # 2

.im-setup-done:
  ;; setup system beep
  ld    hl, # $0010
  ld    23608 ( sysvar-rasp) (), hl

  ;; setup basic error handler
  OPT-BASIC-ERR-HANDLER? [IF]
  ld    hl, # zx-word-par-baserr
  ld    zx-baserr-stack (), hl
  ld    hl, # zx-baserr-stack
  ld    sysvar-err-sp (), hl
  [ENDIF]

  ld    sp, # zx-s0
  ld    iy, # zx-r0

  OPT-SIMPLIFIED-IM? [IF]
  ld    a, # $FF
  ld    sysvar-kstate (), a
  [ENDIF]
  xor   a
  ld    sysvar-last-k (), a

  ;; we can enable interrupts now.
  ;; even if SP is set to `zx-base-addr`, it is safe,
  ;; because "EI" will not allow interrupt to happen
  ;; before next instruction is executed
  ei
  jp    # zx-word-cold
$here 2- @def: zx-init-ret-addr

  \ call  # zx-['] (INIT-I/O) 1-
  \ call  # zx-['] (MAIN-WORD) 1-

.cannot_use_im2:
  ;; just hang for now, with the border effect
  jp    # zx-word-dihalt
flush!


$here swap -
zx-init-code-size [IF]
  zx-init-code-size = [IFNOT]
    " init code size mismatch" error
  [ENDIF]
  (saved-zx-org) zxa:org!
  endcr ." init handler size: " zx-init-code-size .bytes cr
[ELSE]
zx-init-code-size:!
[ENDIF]


<end-asm>
zx-fix-dp


<zx-definitions>
0 vect (MAIN-WORD)

<zx-system>
;; used in "COLD"
\ 0 vect (INIT-BLOCKS)
0 vect (INIT-I/O)

OPT-BASIC-ERR-HANDLER? [IF]
0 vect (BERR-HANDLER)

;; return from basic error
code: (BASERR)
zx-word-par-baserr:
  di
  jp    # zx-['] SYS:(BERR-HANDLER) 1-
  ;; reserve some room for error stack.
  ;; this in in case we'll get an interrupt here.
  0 28 db-dup-n
zx-baserr-stack:
  0 4 db-dup-n
;code-no-next zx-mark-as-used
[ENDIF]


<zx-forth>
raw-code: (DIHALT)  ( -- )
zx-word-dihalt:
  zxemut-normal-speed
  di
  xor   a
.dihalt-loop:
  out   $fe (), a
  inc   a
  and   # $07
  jp    # .dihalt-loop
;code-no-next zx-no-return zx-mark-as-used


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level "(COLD)" -- first-time initialisation
;; TODO: move to the separate memory area which can be reused,
;; TODO: because this word is not required second time.

<zx-system>
raw-code: (*COLD-INIT-ONETIME*)
zx-word-cold:
  call  # zx-['] (INIT-I/O) 1-
  call  # zx-['] (MAIN-WORD) 1-
  jp    # zx-word-dihalt
;code-no-next zx-no-return zx-mark-as-used
zx-required: (DIHALT)

<zx-done>


end-module
