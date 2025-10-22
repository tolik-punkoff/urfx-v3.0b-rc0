;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Z80 assembler with .TAP format output
;; coded by Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main module
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$use <mk-cpcdsk>

module ZXA
<disable-hash>
<published-words>
end-module

$include "zx-asm-10-base.f"
$include "zx-asm-20-code.f"


extend-module ZXA

(*
module writers
<disable-hash>
*)
\ $include "zx-asm-60-write-10-sna.f"
$include "zx-asm-60-write-20-tap.f"
$include "zx-asm-60-write-30-dsk.f"
\ $include "zx-asm-60-write-40-pzx.f"
(*
end-module (published)
*)

;; call this after assembling everything
@: finalise
  z80-labman:check-labels
  normalize-blocks ;

seal-module
end-module

\ " z-test.tap" zxa:writers:tap-save
