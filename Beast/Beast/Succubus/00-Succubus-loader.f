;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module Succubus
\ <disable-hash>

\ $include "Succubus-05-code-api.f"
\ [HAS-WORD] UROBORUS-THE-GREAT-SNAKE [IF]
\ $include "Succubus-08-vm-opc.f"
\ [ENDIF]
$include "Succubus-10-ilendb.f"
$include "Succubus-02-xasm.f"
$include "Succubus-20-cg-low.f"
$include "Succubus-21-cg-cond-detect.f"
$include "Succubus-24-cg-high.f"
$include "Succubus-30-slc.f"
$include "Succubus-80-main.f"

seal-module
end-module Succubus
