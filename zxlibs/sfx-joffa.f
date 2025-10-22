;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sound FX Engine, based on Joffa code.
;; thank you, Joffa!
;; modified from Saucer source code.
;; in your IM2 handler you should do:
;;   ld    a, r
;;   or    # $80
;;   ld    r, a
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-done>

;; FX control codes (see FXRout table)
0 constant FXOFF
1 constant FXBEEP
2 constant FXBOOP
3 constant FXHISS
4 constant FXGAP
;; max FX code
FXGAP 1+ constant LASTFXCODE

(*
;; SFX numbers
FXTEST    equ   $01
FXRKON    equ   $02  ; rkeys
FXRKCLICK equ   $03  ; rkeys
FXBANG1   equ   $04
FXBANG2   equ   $05
FXBANG3   equ   $06
FXBANG4   equ   $07
FXFIRE1   equ   $08
FXFIRE2   equ   $09
FXFIRE3   equ   $0A
FXFIRE4   equ   $0B
FXLINK1   equ   $0C
FXUNLINK1 equ   $0D
FXUNLINK2 equ   $0E
FXCOIN:   equ   $0F
*)

<zx-definitions>
zxlib-begin" Joffa's SFX engine"

raw-code: (*SFX-JOFFA*)
  ret

jsfx-im2-proc:
  ;; AF and HL are saved by the caller
  ld    a, r
  or    # $80
  ld    r, a
  jp    # 0  ;; self-modifying code
$here 2- @def: jsfx-prev-im2-proc

sfx-joffa-border-color: 4 db,   ;; #5C48
sfx-joffa-border-color-noplay: 1 db,   ;; #5C48

;; ISR should set bit 7 of R register!

WaitVBlank:
  ld    a, r
  and   # $7F
  ld    r, a
  \ push  bc
  call  # IntrBeeperSFX
  \ pop   bc
  \ ld    a, r
  \ and   # $7F
  \ ld    r, a
  ret

IntrBeeperSFX:
  ;; di
  ld    a, () FXNumber
  or    a
  jr    nz, # Beeper

WaitInt:
  (*
  ;; ei
  ld    a, r
  jp    p, # WaitInt
  ;; di
  *)
  ld    a, () sfx-joffa-border-color-noplay
  out   $FE (), a
  ret

FXNumber:  0 db,  ;; current sound fx number
FXPointer: 0 dw,  ;; pointer to sound data
FXCode:    0 dw,  ;; current beeper routine


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IN GAME BEEPER ROUTINES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Beeper:
  ld    hl, () FXPointer  ;; table pointer

  ld    a, (hl)         ;; frequency + code (1 frame info only)
  inc   hl
  cp    # LASTFXCODE    ;; new control code?
  jr    nc, # PlayFX0

  add   a, a
  jr    nz, # PlayFX
  ld    FXNumber (), a  ;; no more sound
  jr    # WaitInt

PlayFX:
  push  hl
  push  de
  ld    e, a
  ld    d, # 0
  ld    hl, # FXRout
  add   hl, de
  \ add   a, low(FXRout)
  \ ld    l, a
  \ ; old
  \ ;ld    h, high(FXRout)
  \ ; new
  \ ld    a, high(FXRout)
  \ adc   a, 0
  \ ld    h, a
  ld    a, (hl)
  inc   hl
  ld    h, (hl)
  ld    l, a
  ld    FXCode (), hl   ;; change current beeper routine
  pop   de
  pop   hl
  ld    a, (hl)

PlayFX0:
  ld    FXPointer (), hl  ;; ready for next time
  ld    e, a              ;; current frequency
  ld    d, a
  ld    hl, # PlayOut     ;; return address
  push  hl
  ld    hl, () FXCode
  jp    hl

PlayOut:
  ;; SOUNDFX_SET_ASND 0
  ld    a, () sfx-joffa-border-color
  out   $FE (),  a
  ;; di
  ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; normal beep
;;
Beep:
  ;; SOUNDFX_SET_ASND $10
  ld    a, () sfx-joffa-border-color
  or    # $10
  out   $FE (),  a
  ld    b, e
Beep0:
  ld    a, r
  ret   m
  djnz  # Beep0
  jr    # Beep1

Beep1:
  ;; SOUNDFX_SET_ASND 0
  ld    a, () sfx-joffa-border-color
  out   $FE (),  a
  ld    b, d
Beep2:
  ld    a, r
  ret   m
  djnz  # Beep2
  jr    # Beep


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; phase beep
;;
Boop:
  ;;SOUNDFX_SET_ASND $10
  ld    a, () sfx-joffa-border-color
  or    # $10
  out   $FE (),  a
  inc   e
  ld    b, e
Boop0:
  ld    a, r
  ret   m
  djnz  # Boop0
  jr    # Boop1
Boop1:
  ;; SOUNDFX_SET_ASND 0
  ld    a, () sfx-joffa-border-color
  out   $FE (),  a
  dec   d
  ld    b, d
Boop2:
  ld    a, r
  ret   m
  djnz  # Boop2
  jr    # Boop


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; white noise beep
;;
Hiss:
  ld    hl, # 0         ;; rom pointer
Hisso:
  ;; SOUNDFX_SET_ASND $10
  ld    a, () sfx-joffa-border-color
  or    # $10
  out   $FE (),  a
  ld    b, (hl)
  inc   hl
Hiss0:
  ld    a, r
  ret   m
  djnz  # Hiss0
  ;; SOUNDFX_SET_ASND 0
  ld    a, () sfx-joffa-border-color
  out   $FE (),  a
  ld    b, d
  inc   d
Hiss2:
  ld    a, r
  ret   m
  djnz  # Hiss2
  jr    # Hisso

;; FX routing table
FXRout:
  0 dw,             ;; 0
  [@@] Beep dw,     ;; 1 normal beep
  [@@] Boop dw,     ;; 2 phase beep
  [@@] Hiss dw,     ;; 3 white noise
  [@@] WaitInt dw,  ;; 4 no sound


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SFX data
BangFX1:
  FXHISS db,
  10 db, 50 db, 100 db, 200 db, 20 db, 60 db, 150 db, 250 db,
  FXOFF db,

BangFX2:
  FXHISS db,
  250 db, 240 db, 230 db, 220 db, 150 db, 140 db, 130 db, 120 db,
  FXOFF db,

BangFX3:
  FXHISS db,
  10 db, 50 db, 100 db, 50 db, 100 db, 50 db, 30 db, 10 db,
  FXOFF db,

BangFX4:
  FXHISS db,
  200 db, 250 db, 100 db, 150 db, 200 db, 100 db, 250 db, 150 db,
  FXOFF db,

FireFX1: FXBOOP db, 030 db, 050 db, FXOFF db, ;; saucer missiles
FireFX2: FXBOOP db, 010 db, 100 db, FXOFF db,
FireFX3: FXBOOP db, 020 db, 150 db, FXOFF db,
FireFX4: FXBOOP db, 040 db, 250 db, FXOFF db,

LinkFX1: FXBOOP db, 030 db, 020 db, FXOFF db, ;; link to rover

UnLinkFX1: FXBOOP db, 230 db, FXOFF db, ;; lift off from rover - mining ect; was FXHISS
UnLinkFX2: FXHISS db, 220 db, FXOFF db, ;; bubble burst; was FXBOOP

CoinFX: FXBEEP db, 30 db, 20 db, 18 db, 16 db, 15 db, 14 db, 12 db, FXOFF db,

TestFX:
  FXBOOP db, 200 db,
  FXGAP db, 99 db, 99 db, 99 db, 99 db,
  FXBOOP db, 150 db,
  FXGAP db, 99 db, 99 db, 99 db,
  FXBOOP db, 200 db,
  FXGAP db, 99 db, 99 db,
  FXBOOP db, 50 db,
  FXGAP db, 99 db,
  FXBOOP db, 100 db,
  FXOFF db,

RKOnFX:
  FXHISS db,
  10 db, 20 db, 30 db, 40 db,
  FXGAP db,
  99 db, 99 db, 99 db, 99 db,
  FXHISS db,
  10 db, 40 db, 60 db, 80 db,
  FXGAP db,
  99 db, 99 db, 99 db, 99 db,
  FXHISS db,
  10 db, 80 db, 120 db, 160 db,
  FXGAP db,
  99 db, 99 db, 99 db, 99 db,
  FXHISS db,
  10 db, 160 db, 240 db, 255 db,
  FXOFF db,

RKClickFX:
  FXHISS db,
  250 db, 100 db, 50 db, 10 db,
  FXGAP db,
  99 db, 99 db, 99 db, 99 db,
  FXHISS db,
  50 db, 100 db, 250 db,
  100 db, 50 db, 10 db,
  50 db, 100 db, 250 db,
  100 db, 50 db, 10 db,
  50 db, 100 db, 250 db,
  FXOFF db,


;; SFX table
FXTable:
  [@@] TestFX dw,     ;; $01
  [@@] RKOnFX dw,     ;; $02
  [@@] RKClickFX dw,  ;; $03
  [@@] BangFX1 dw,    ;; $04
  [@@] BangFX2 dw,    ;; $05
  [@@] BangFX3 dw,    ;; $06
  [@@] BangFX4 dw,    ;; $07
  [@@] FireFX1 dw,    ;; $08
  [@@] FireFX2 dw,    ;; $09
  [@@] FireFX3 dw,    ;; $0A
  [@@] FireFX4 dw,    ;; $0B
  [@@] LinkFX1 dw,    ;; $0C
  [@@] UnLinkFX1 dw,  ;; $0D
  [@@] UnLinkFX2 dw,  ;; $0E
  [@@] CoinFX dw,     ;; $0F


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; start sound fx...
;; TODO: sound priorities?
;;
;; IN:
;;   A: fx number
;; OUT:
;;   AF: dead
;;   HL: dead
StartSFX:
  or    a
  ret   z
StartSFXForce:
  ld    FXNumber (), a  ;; current FX number
  dec   a
  add   a, a
  (*
  add   a, # FXTable lo-byte
  ld    l, a
  ld    a, # FXTable hi-byte
  adc   a, # 0
  ld    h, a
  *)
  ld    hl, # FXTable
  ld    e, a
  ld    d, # 0
  add   hl, de
  ld    a, (hl)
  inc   hl
  ld    h, (hl)
  ld    l, a
  ld    FXPointer (), hl  ;; current FX data
  ret
;code-no-next


primitive: JSFX-ABORT  ( -- )
zx-required: (*SFX-JOFFA*)
:codegen-xasm
  push-tos
  xor-a
  @label: StartSFX call-#
  pop-tos ;

primitive: JSFX-START  ( n )
Succubus:setters:in-8bit
zx-required: (*SFX-JOFFA*)
:codegen-xasm
  tos-r16 r16l->a
  $0F and-a-c#
  @label: StartSFX call-#
  pop-tos ;

primitive: JSFX-PLAY  ( -- )
zx-required: (*SFX-JOFFA*)
:codegen-xasm
  push-tos
  @label: WaitVBlank call-#
  pop-tos ;


: JSFX-PLAYING?  ( -- sfx-idx // 0 )  asm-label: FXNumber c@ ; zx-inline

: SFX-JOFFA-BORDER@  ( -- color )  asm-label: sfx-joffa-border-color c@ ; zx-inline
: SFX-JOFFA-BORDER!  ( color )  asm-label: sfx-joffa-border-color c! ; zx-inline

: SFX-JOFFA-NOPLAY-BORDER@  ( -- color )  asm-label: sfx-joffa-border-color-noplay c@ ; zx-inline
: SFX-JOFFA-NOPLAY-BORDER!  ( color )  asm-label: sfx-joffa-border-color-noplay c! ; zx-inline


;; you can either set bit 7 of R manually, or use `INIT-JSFX` to set IM2 handler.
raw-code: INIT-JSFX
  ex    de, hl
  ld    hl, () jsfx-prev-im2-proc
  ld    a, h
  or    l
  jr    nz, # .inited

  ;; save previous IM2 routine
  ld    hl, () zx-im2-userproc-addr
  ld    jsfx-prev-im2-proc (), hl

  ;; setup new IM2 routine
  ld    hl, # jsfx-im2-proc
  ld    zx-im2-userproc-addr (), hl
.inited:
  ex    de, hl
;code

raw-code: DEINIT-JSFX
  ex    de, hl
  ld    hl, () jsfx-prev-im2-proc
  ld    a, h
  or    l
  jr    z, # .deinited

  ;; restore previous IM2 routine
  ld    jsfx-prev-im2-proc (), hl

  ld    hl, # 0
  ld    jsfx-prev-im2-proc (), hl
.deinited:
  ex    de, hl
;code


zxlib-end
