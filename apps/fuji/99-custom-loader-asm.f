;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Invasion Terrestre, built with ZX Spectrum UrF/X Forth System
;; written by Ketmar Dark, graphics by Fransouls
;; Invisible Vector production, 2025
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load-bytes, currently the same as in ROM
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

custom-ld-bytes-entry:
  \ zxemut-bp
  ;; save type byte
  ld    custom-ld-flag-value-patch 1- (), a
  ;; patch in "XOR A"
  ld    a, # @257
  ld    custom-ld-loop (), a

  push  de
  \ call  # custom-ld-setup-counter
  ;; the formula is:
  ;; (len-256*9)/256+1
  ;; `+1` is due how we count things
custom-ld-setup-counter:
  ld    hl, # 256 9 * negate
  add   hl, de
  inc   h
  ;; H now contains the counter we need
  ;; alternative set:
  ;;   HL: scr$
  ;;    B: cld-step-left
  ;;    C: cld-step-init
  ;;    E: cld-step-mask
  ;;    D: border increment
  ld    b, h
  ld    c, h
  ld    de, # $0080
  ld    hl, # $4000
  exx
  pop   de

  \ ld    a, # $0F
  xor   a
  out   $FE (), a
  ;; custom entry code end
  0 [IF]
  jp    # $0562
  [ENDIF]

  in    a, () $FE               ;; Make an initial read of port '254'.
  rra                           ;; Rotate the byte obtained but keep only the EAR bit.
  and   # $20
  or    # $02                   ;; Signal red border.
  ld    c, a                    ;; Store the value in the C register (+22 for 'off' and +02 for 'on' - the present EAR state).

  ;; The first stage of reading a tape involves showing that a pulsing signal
  ;; actually exists (i.e. 'on/off' or 'off/on' edges).
custom-ld-start:
  call  # custom-ld-edge-1
    ;; Return with the carry flag reset if there is no 'edge' within
    ;; approx. 14,000 T states. But if an 'edge' is found the border will go cyan.
  jr    nc, # custom-ld-start
  ;; The next stage involves waiting a while and then showing that the signal is still pulsing.
  ld    hl, # $0415             ;; The length of this waiting period will be almost one second in duration.
custom-ld-wait:
  djnz  # custom-ld-wait
  dec   hl
  ld    a, h
  or    l
  jr    nz, # custom-ld-wait
  call  # custom-ld-edge-2      ;; Continue only if two edges are found within the allowed time period.
  jr    nc, # custom-ld-start
  ;; Now accept only a 'leader signal'.
custom-ld-leader:
  ld    b, # $9C                ;; The timing constant.
  call  # custom-ld-edge-2      ;; Continue only if two edges are found within the allowed time period.
  jr    nc, # custom-ld-start
  ld    a, # $C6                ;; However the edges must have been found within about 3,000 T states of each other.
  ;; (0xC6-0x9C)*60+358*2=3236
  ;; saver: 2168
  cp    b
  jr    nc, # custom-ld-start
  inc   h                       ;; Count the pair of edges in the H register until '256' pairs have been found.
  jr    nz, # custom-ld-leader
  ;; After the leader come the 'off' and 'on' parts of the sync pulse.
custom-ld-sync:
  ld    b, # $C9                ;; The timing constant.
  call  # custom-ld-edge-1      ;; Every edge is considered until two edges are found close together - these will be the start and finishing edges of the 'off' sync pulse.
  jr    nc, # custom-ld-start
  ld    a, b
  cp    # $D4
  ;; (0xD4-0xC9)*60+358=1018
  jr    nc, # custom-ld-sync
  call  # custom-ld-edge-1      ;; The finishing edge of the 'on' pulse must exist. (Return carry flag reset.)
  ;; (0x100-0xD4)*60+358=2998
  ret   nc
  ;; The bytes of the header or the program/data block can now be loaded or verified.
  ;; But the first byte is the type flag.
  ld    a, c                    ;; The border colours from now on will be blue and yellow.
  xor   $03
  ld    c, a
  ld    h, # $00                ;; Initialise the 'parity matching' byte to zero.
  TURBO-LOADER? [IF]
  ld    b, # $E1                ;; Set the timing constant for the flag byte.
  [ELSE]
  ld    b, # $B0                ;; Set the timing constant for the flag byte.
  [ENDIF]
  jr    # custom-ld-marker      ;; Jump forward into the byte loading loop.

  ;; The byte loading loop is used to fetch the bytes one at a time.
  ;; The flag byte is first. This is followed by the data bytes and the last byte is the 'parity' byte.
custom-ld-loop:
  xor   a                       ;; this will be set to "XOR A" or "SCF"
  jr    nc, # custom-ld-flag    ;; Jump forward only when handling the first byte.
  ;; a new byte collected from the tape
  ld    $00 (ix+), l            ;; Make the actual load when required.
  inc   ix                      ;; Increase the 'destination'.

  ;; progress bar code
.cldpbar:
  TURBO-LOADER? [IF]
  ld    b, # $E1                ;; set the timing constant here (we will compensate it).
  [ELSE]
  ld    b, # $B2                ;; set the timing constant here (we will compensate it).
  [ENDIF]
  exx                           ;; (4)
  ;;   HL: scr$
  ;;    B: cld-step-left
  ;;    C: cld-step-init
  ;;    E: cld-step-mask
  ;;    D: border increment
  dec   b                       ;; (4)
  jr    nz, # .cldpbar-done     ;; (12)/(7) -- 7+4+4+12=27 on taken (31 full)
  ;; fix timing constant
  exx                           ;; (4)
  inc   b                       ;; (4)
  inc   b                       ;; (4)
  exx                           ;; (4)
  ;; need to draw the progress bar
  ;; 7+4+4+7+4+4+4+4=38 here
  ld    a, h                    ;; (4)
  cp    # $48                   ;; (7)
  jr    z, # .cldpbar-next-step ;; (12)/(7)
  ;; draw one dot
  ;; 38+4+7+7=56 here
  ld    a, e                    ;; (4)
  xor   (hl)                    ;; (7)
  ld    (hl), a                 ;; (7)
  inc   h                       ;; (4)
  inc   b                       ;; (4) -- restore to zero
  jp    # .cldpbar-done         ;; (10) -- 56+4+7+7+4+4+10+4=96 on taken
.cldpbar-next-step:
  ;; 38+4+7+12=61 here
  ld    b, c                    ;; (4) -- reinit counter
  ld    h, # $40                ;; (7)
  srl   e                       ;; (8)
  jr    nc, # .cldpbar-done     ;; (12)/(7) -- 61+4+7+8+12+4=96 on taken
  ;; 61+4+7+8+7=87 here
  ld    e, # $80                ;; (7) -- restore pixel mask
  inc   l                       ;; (4)
  bit   5, l                    ;; (8)
  jr    z, # .cldpbar-done      ;; (12)/(7) -- 87+7+4+8+12+4=122 on taken
  ;; 87+7+4+8+7=113 here
  ld    h, # 0                  ;; (7)
  ld    e, h                    ;; (4)
  ;; 113+7+4=124 here
.cldpbar-done:
  exx                           ;; (4)
  ;; end of progress bar code
  ;; max timing seems to be 128ts; common is 96ts; smallest is 31ts

  dec   de                      ;; Decrease the 'counter'.
custom-ld-dec-skip:
  \ ld    b, # $B2              ;; Set the timing constant.
custom-ld-marker:
  ld    l, # $01                ;; Clear the 'object' register apart from a 'marker' bit.
  ;; The following loop is used to build up a byte in the L register.
custom-ld-8-bits:
  call  # custom-ld-edge-2      ;; Find the length of the 'off' and 'on' pulses of the next bit.
  ret   nc                      ;; Return if the time period is exceeded. (Carry flag reset.)
  TURBO-LOADER? [IF]
  ld    a, # $ED
  [ELSE]
  ld    a, # $CB                ;; Compare the length against approx. 2,400 T states, resetting the carry flag for a '0' and setting it for a '1'.
  [ENDIF]
  ;; (0xCB-0xB2)*60+358=1858
  cp    b
  rl    l                       ;; Include the new bit in the L register.
  TURBO-LOADER? [IF]
  ld    b, # $E1                ;; Set the timing constant for the next bit.
  [ELSE]
  ld    b, # $B0                ;; Set the timing constant for the next bit.
  [ENDIF]
  jp    nc, # custom-ld-8-bits  ;; Jump back whilst there are still bits to be fetched.
  ;; The 'parity matching' byte has to be updated with each new byte.
  ld    a, h                    ;; Fetch the 'parity matching' byte and include the new byte.
  xor   l
  ld    h, a                    ;; Save it once again.
  ;; Passes round the loop are made until the 'counter' reaches zero.
  ;; At that point the 'parity matching' byte should be holding zero.
  ld    a, d                    ;; Make a further pass if the DE register pair does not hold zero.
  or    e
  jr    nz, # custom-ld-loop
  ld    a, h                    ;; Fetch the 'parity matching' byte.
  cp    # $01                   ;; Return with the carry flag set if the value is zero. (Carry flag reset if in error.)
\ zxemut-bp
  ret

custom-ld-flag:
  ld    a, # $00                ;; patched by the code above
custom-ld-flag-value-patch:
  xor   l                       ;; Return now if the type flag does not match the first byte on the tape. (Carry flag reset.)
  ret   nz
  ;; patch in "SCF"
  ld    a, # @067
  ld    custom-ld-loop (), a
  jr    # custom-ld-dec-skip

(*
Used by the routine at LD_BYTES.

These two subroutines form the most important part of the LOAD/VERIFY
operation.

The subroutines are entered with a timing constant in the B register, and
the previous border colour and 'edge-type' in the C register.

The subroutines return with the carry flag set if the required number of
'edges' have been found in the time allowed, and the change to the value in
the B register shows just how long it took to find the 'edge(s)'.

The carry flag will be reset if there is an error. The zero flag then
signals 'BREAK pressed' by being reset, or 'time-up' by being set.

The entry point custom-ld-edge-2 is used when the length of a complete
pulse is required and custom-ld-edge-1 is used to find the time before the
next 'edge'.

Input
  B   Timing constant
  C   Border colour (bits 0-2) and previous edge-type (bit 5)

sync:
  max wait: 3658
  first: 1028


ld-edge-2:
*)

custom-ld-edge-2:
  TURBO-LOADER? [IF]
  ld    a, # $06                ;; Wait 358 T states before entering the sampling loop.
  call  # custom-ld-edge-11     ;; In effect call custom-ld-edge-1 twice, returning in between if there is an error.
  [ELSE]
  call  # custom-ld-edge-1      ;; In effect call custom-ld-edge-1 twice, returning in between if there is an error.
  [ENDIF]
  ret   nc
  ;; This entry point is used by the routine at LD_BYTES.
custom-ld-edge-1:
  TURBO-LOADER? [IF]
  ld    a, # $0B                ;; Wait 358 T states before entering the sampling loop.
  [ELSE]
  ld    a, # $16                ;; Wait 358 T states before entering the sampling loop.
  [ENDIF]
custom-ld-edge-11:
.delay-loop:
  dec   a
  jr    nz, # .delay-loop
  and   a
  ;; The sampling loop is now entered.
  ;; The value in the B register is incremented for each pass; 'time-up' is given when B reaches zero.
  ;; one loop iteration:
  ;;   4+5+7+12+4+5+4+7+12=60ts
  ;; last loop iteration:
  ;;   4+5+7+12+4+5+4+7+8=56ts
  ;; as B increments, the total max timing is:
  ;;   (256-B)*60+358
.sample-loop:
  inc   b                       ;; (4) Count each pass.
  ret   z                       ;; (5) Return carry reset and zero set if 'time-up'.
  ld    a, # $7F                ;; (7) Read from port +7FFE, i.e. BREAK and EAR.
  in    a, () $FE               ;; (12)
  rra                           ;; (4) Shift the byte.
  nop                           ;; (4)
  \ ret   nc                      ;; (5) Return carry reset and zero reset if BREAK was pressed.
  xor   c                       ;; (4) Now test the byte against the 'last edge-type'; jump back unless it has changed.
  and   # $20                   ;; (7)
  jr    z, # .sample-loop       ;; (12)/(7)
  ;; A new 'edge' has been found within the time period allowed for the search.
  ;; So change the border colour and set the carry flag.
  ld    a, c                    ;; Change the 'last edge-type' and border colour.
  \ cpl -- old
  ;; new border change
  exx
  set   5, d                    ;; always invert EAR bit
  xor   d                       ;; border increment
  inc   d
  exx
  ;; end of new border change
  ld    c, a
  and   # $07                   ;; Keep only the border colour.
  or    # $08                   ;; Signal 'MIC off'.
  out   $FE (), a               ;; Change the border colour.
  scf                           ;; Signal the successful search before returning.
  ret

(*
Note: the custom-ld-edge-1 subroutine takes 465 T states, plus an
additional 58 T states for each unsuccessful pass around the sampling loop.

For example, therefore, when awaiting the sync pulse (see LD_SYNC)
allowance is made for ten additional passes through the sampling loop. The
search is thereby for the next edge to be found within, roughly, 1100 T
states (465+10*58+overhead). This will prove successful for the sync 'off'
pulse that comes after the long 'leader pulses'.
*)
