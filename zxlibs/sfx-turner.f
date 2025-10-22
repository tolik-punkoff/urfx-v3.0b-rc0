;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FIXME: not tested as a library yet!
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Steve Turner's sfx engine.
;; used in Ranarama, Quazatron, IronMan.
;; you can use this routine in ISR (as the author did),
;; or in the main game loop.
;; found i don't know where, lol.
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


true zx-lib-option OPT-SFX-TURNER-COLORED-BORDER

zxlib-begin" Turner's SFX engine"


raw-code: (*SFX-TURNER*)
  push  hl
  call  # xte_stsfx_process
  pop   hl
  ret

tsfx-im2-proc:
  ;; AF and HL are saved by the caller
  push  bc
  push  de
  call  # xte_stsfx_process
  pop   de
  pop   bc
  jp    # 0  ;; self-modifying code
$here 2- @def: tsfx-prev-im2-proc


;; put non-zero here to request a new sound
;; call to `xte_stsfx_process` will zero it
;; (or will put a linked sound here)
xte_stsfx_newfx: 0 db,

;; border color (used if `ST_SND_COLORED_BORDER_` is non-zero)
xte_stsfx_border: 1 db,


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main entry point
;; should be called from the interrupt routine
;;
;; IN:
;;   none
;; OUT:
;;   AF,BC,DE,HL: dead
;;
xte_stsfx_process:
  ;; check for a new sound
  ld    a, () xte_stsfx_newfx
  and   a
  jr    z, # .not_new
  ;; yep, a new one
  ld    .sonnow (), a
  dec   a
  jr    z, # .noise     ;; #01 is a noise
  ;; get sfx data
  ld    hl, # xte_priv_stsfx_data
  dec   a
  add   a, a
  add   a, a
  add   a, a
  ld    e, a
  xor   a
  ld    xte_stsfx_newfx (), a
  ld    d, a
  add   hl, de
  ld    bc, # $0008
  ld    de, # .sonfrq
  ldir
  jr    # .do_sfx

.not_new:
  ld    a, () .sonnow   ;; have some old sound?
  and   a
  ret   z
  dec   a               ;; is this a noise?
  jr    nz, # .do_sfx
  jr    # .cont_noise

.noise:
  ld    a, # $0A
  ld    .sonlen (), a
  xor   a
  ld    xte_stsfx_newfx (), a

.cont_noise:
  ld    b, # $30

.gain:
  call  # .random
  and   # $10
  ;; border
  OPT-SFX-TURNER-COLORED-BORDER [IF]
  push  hl
  ld    hl, # xte_stsfx_border
  or    (hl)
  pop   hl
  [ENDIF]
  ;; done with border
  out   $FE (), a
  ld    c, # $02

.make:
  dec   c
  jr    nz, # .make
  djnz  # .gain
  ld    hl, # .sonlen
  dec   (hl)
  ret   nz
  xor   a
  ld    .sonnow (), a
  ret

.do_sfx:
  ld    a, () .sonfrq
  ld    h, a
  ld    a, # $10
  ld    d, # $FF

.sonlp:
  ld    e, h
  ;; border
  OPT-SFX-TURNER-COLORED-BORDER [IF]
  push  hl
  ld    hl, # xte_stsfx_border
  or    (hl)
  pop   hl
  [ENDIF]
  ;; done with border
  out   $FE (), a
  xor   # $10

.freq:
  dec   d
  jr    z, # .locmod
  dec   e
  jr    nz, # .freq
  jr    # .sonlp

.locmod:
  ld    a, () .soncfg
  add   a, h
  ld    .sonfrq (), a
  ld    hl, # .sonmod
  dec   (hl)
  ret   nz
  ld    hl, # .sonlen
  dec   (hl)
  jr    nz, # .modify
  xor   a
  ld    .sonnow (), a
  ld    a, () .sonnex
  and   a
  ret   z
  ld    xte_stsfx_newfx (), a
  ret

.modify:
  ld    a, () .sobrsf
  ld    c, a
  ld    a, () .sontyp
  and   a
  jr    z, # .reset
  dec   a
  jr    z, # .typ1
  dec   a
  jr    z, # .typ2

.typoth:
  ld    a, () .soncfg
  neg
  ld    .soncfg (), a
  jr    # .mode

.typ2:
  inc   c
  inc   c
  ld    a, c
  ld    .sobrsf (), a
  jr    # .reset

.typ1:
  dec   c
  dec   c
  ld    a, c
  ld    .sobrsf (), a
  jr    # .reset

.reset:
  ld    a, c
  ld    .sonfrq (), a

.mode:
  ld    a, () .sonrnd
  ld    .sonmod (), a
  ret

.random:
  push  hl
  ld    hl, # $1000
$here 2- @def: xte_priv_stsfx_rnd_seed
  inc   hl
  ld    a, h
  and   # $03
  ld    h, a
  ld    xte_priv_stsfx_rnd_seed (), a
  ld    a, r
  xor   (hl)
  pop   hl
  ret

.sonfrq: $00 db,  ;; start frequency
.soncfg: $00 db,  ;; frequency change
.sonmod: $00 db,  ;; change times
.sonlen: $00 db,  ;; repeat times
.sontyp: $00 db,  ;; modulation: 0=sawtooth; 1=2nd mod down; 2=2nd mod up; 3+=triangle
.sobrsf: $00 db,  ;; reset frequency
.sonrnd: $00 db,  ;; change reset tempo
.sonnex: $00 db,  ;; linked sfx
@xte_stsfx_sonnow:
.sonnow: $00 db,  ;; currently playing sfx



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SFX definition struct:
;;  defb start_freq    ; start frequency
;;  defb freq_change   ; frequency change
;;  defb change_times  ; change times
;;  defb repeat_times  ; repeat times
;;  defb modulation    ; modulation: 0=sawtooth; 1=2nd mod down; 2=2nd mod up; 3+=triangle
;;  defb reset_freq    ; reset frequency
;;  defb change_reset_tempo  ; change reset tempo
;;  defb linked_sfx    ; linked sfx

xte_priv_stsfx_data:
;; here all sounds excepts number 1 reserved for random noise
;; each sfx takes 8 bytes (see above for their meanings)
    0 db,   5 db,   5 db,   1 db,   0 db,   0 db,   0 db,   0 db,   ;; 2
  $28 db,   5 db, $0A db,   1 db,   0 db,   0 db,   0 db,   0 db,   ;; 3
    0 db, $80 db, $1E db,   1 db,   0 db,   0 db,   0 db,   0 db,   ;; 4
    0 db,   2 db, $1E db,   1 db,   0 db,   0 db,   0 db,   0 db,   ;; 5
    0 db, $7D db, $20 db,   1 db,   0 db,   0 db,   0 db,   0 db,   ;; 6
  $FF db, $83 db, $20 db,   1 db,   0 db,   0 db,   0 db,   0 db,   ;; 7
  $FF db, $83 db, $28 db, $20 db,   1 db, $3C db,   1 db,   0 db,   ;; 8
  $F0 db, $F0 db,   8 db,   3 db,   0 db, $3C db,   6 db,   0 db,   ;; 9
    2 db, $80 db, $0A db,   1 db,   0 db,   0 db,   0 db,   0 db,   ;; 10
  $28 db, $FA db,   8 db,   1 db,   0 db,   0 db,   0 db,   0 db,   ;; 11
  $FA db, $2C db,   6 db, $0A db,   1 db, $5A db,   1 db,   0 db,   ;; 12
    0 db, $FC db, $14 db,   8 db,   1 db, $50 db,   8 db,   0 db,   ;; 13
  $E6 db, $E6 db,   4 db,   1 db,   1 db,   0 db,   0 db,   0 db,   ;; 14
  $2D db, $43 db, $14 db,   1 db,   1 db,   0 db,   0 db,   0 db,   ;; 15
;code-no-next


: TSFX-BORDER?  ( -- color )  asm-label: xte_stsfx_border c@ ; zx-inline
: TSFX-BORDER!  ( color )  asm-label: xte_stsfx_border c! ; zx-inline


;; return sfx index, or 0
: TSFX-PLAYING?  ( -- sfx-idx // 0 )  asm-label: xte_stsfx_sonnow c@ ; zx-inline

primitive: TSFX-ABORT  ( -- )
zx-required: (*SFX-TURNER*)
:codegen-xasm
  xor-a
  @label: xte_stsfx_sonnow a->(nn)
  @label: xte_stsfx_newfx a->(nn) ;

primitive: TSFX-PLAY  ( sfx-idx )
Succubus:setters:in-8bit
zx-required: (*SFX-TURNER*)
:codegen-xasm
  tos-r16 r16l->a
  $0F and-a-c#
  @label: xte_stsfx_newfx a->(nn)
  pop-tos ;

raw-code: INIT-TSFX
  ex    de, hl
  ld    hl, () tsfx-prev-im2-proc
  ld    a, h
  or    l
  jr    nz, # .inited

  ;; save previous IM2 routine
  ld    hl, () zx-im2-userproc-addr
  ld    tsfx-prev-im2-proc (), hl

  ;; setup new IM2 routine
  ld    hl, # tsfx-im2-proc
  ld    zx-im2-userproc-addr (), hl
.inited:
  ex    de, hl
;code

raw-code: DEINIT-TSFX
  ex    de, hl
  ld    hl, () tsfx-prev-im2-proc
  ld    a, h
  or    l
  jr    z, # .deinited

  ;; restore previous IM2 routine
  ld    tsfx-prev-im2-proc (), hl

  ld    hl, # 0
  ld    tsfx-prev-im2-proc (), hl
.deinited:
  ex    de, hl
;code


zxlib-end
