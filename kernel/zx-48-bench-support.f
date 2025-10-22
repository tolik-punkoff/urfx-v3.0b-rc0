;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; benchmarking support words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; useful code for various benchmarking

;; this will enable interrupts
primitive: BENCH-START  ( -- )
:codegen-xasm
  restore-tos-de
  0 #->hl
  ei
  halt
  @label: sysvar-frames hl->(nn) ;

;; this will enable interrupts
primitive: BENCH-END  ( -- frames )
:codegen-xasm
  di
  push-tos-peephole
  ei
  @label: sysvar-frames (nn)->tos ;

<zx-system>
raw-code: (*MINIMALISTIC-EIM2*)
benchmark-minimalistic-im2:
  push  hl
  push  af
  \ ld    hl, () sysvar-frames
  \ inc   hl
  \ ld    sysvar-frames (), hl

  ;; this is 31ts 255 times, and 46ts once in a 256 calls.
  ;; the simplier code is always 38ts.
  0 [IF]
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

  pop   af
  pop   hl
  ei
  ret
;code-no-next

0 quan (bench-saved-im2)
<zx-forth>

primitive: BENCH-IM2-SET  ( -- )
:codegen-xasm
  $FFF5 (nn)->non-tos
  zx-['pfa] sys:(bench-saved-im2) non-tos->(nn)
  @label: benchmark-minimalistic-im2 #->non-tos
  $FFF5 non-tos->(nn) ;
zx-required: sys:(*MINIMALISTIC-EIM2*) sys:(bench-saved-im2)

primitive: BENCH-IM2-RESET  ( -- )
:codegen-xasm
  \ @label: urfx-IntrHandler #->non-tos
  \ $FFF5 non-tos->(nn) ;
  zx-['pfa] sys:(bench-saved-im2) (nn)->non-tos
  $FFF5 non-tos->(nn) ;
zx-required: sys:(bench-saved-im2)

: BENCH-TIME-WIDTH  ( frames )
  50 u/ decw>str nip 4 + ;

: .BENCH-TIME  ( frames )
  50 u/mod .UDEC [char] . emit 20 * decw>str5 drop 2+ c@++ emit c@++ emit c@ emit ;


<zx-done>
