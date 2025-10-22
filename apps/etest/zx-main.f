;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; eratos-test
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$zx-use <emit8-rom>


8192 constant pr-size
\ 8192 zx-ud-buffer pr-flags
$A000 constant pr-flags
\ : pr-flags here ; zx-inline

;; 15.600 with "2 *"
;; 12.440 with "2*"
: do-prime-orig  ( -- count )
  pr-flags pr-size -1 fill
  0 0 begin ( count index )
    dup pr-flags + c@
    if dup 2 * 3 + 2dup +
      begin dup pr-size < while dup pr-flags + 0 swap c! over + repeat drop drop
      swap 1 + swap
    endif
\ endcr ." count=" over .dec ."  index=" dup .dec cr
  1 + dup pr-size >=
\ endcr ."  >=: " dup .dec cr
  unless
  drop ;

;; 11.900 for indirect branches
;; 11.620 for direct branches
;;  9.460 for DTC with indirect branches
;;  9.200 for DTC with direct branches
;;  7.960 for DTC with uncontended memory
;; now:
;;  6.000 for DTC with uncontended memory and optimisations
;;  5.000 for DTC with uncontended memory and optimisations
: do-prime  ( -- count )
  pr-flags pr-size -1 fill
  0 0 begin ( count index )
    dup pr-flags + c@
    if dup 2* 3 + 2dup +
      begin dup pr-size < while dup pr-flags + 0 swap c! over + repeat 2drop
      under+1
    endif
  1+ dup pr-size >= unless
  drop ;


\ : w2 2 ; zx-inline
\ : w3 5 w2 u/ ;


: xtest
\ sys: depth
\ .dec
\ cr
  [ 0 ] [IF]
    ." HERE: " here .udec ."  $" here .hex4 cr
    (dihalt)
  [ENDIF]
  [ 0 ] [IF]
    w3 . cr
    (dihalt)
  [ENDIF]
  \ hex here u.r cr di halt
  (mspd-on)
  BENCH-IM2-SET
  ." \ctesting...\n"
  BENCH-START
  [ 1 ] [IF]
    do-prime-orig
  [ELSE]
    do-prime
  [ENDIF]
  BENCH-END
  BENCH-IM2-RESET
  ." \ccount=" swap 0 .r
  ." \ctime: " .BENCH-TIME cr
  \ (mspd-off)
  (DIHALT) ;
