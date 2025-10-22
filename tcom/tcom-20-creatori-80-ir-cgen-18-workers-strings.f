;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; directly included from "tcom-20-creatori-80-ir-cgen.f"
;; strings
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module WORKERS


|: .str$  ( str$ )
  dup 0?exit< drop ." <null>" >?
  34 emit
  count for c@++
    <<  4 of?v| ." \\c" |?
        5 of?v| ." \\W" |?
        7 of?v| ." \\r" |?
        6 of?v| ." \\t" |?
        8 of?v| ." \\b" |?
       13 of?v| ." \\n" |?
       16 of?v| ." \\I" |?
       17 of?v| ." \\P" |?
       18 of?v| ." \\F" |?
       19 of?v| ." \\B" |?
       20 of?v| ." \\R" |?
       21 of?v| ." \\X" |?
       34 of?v| ." \\'" |?
       92 of?v| ." \\\\" |?
      127 of?v| ." \\x7f" |?
      dup 0 10 within ?v| ." \\" 0.r |?
      dup 32 < ?v| ." \\x" .hex2 |?
    else| emit >>
  endfor drop
  34 emit ;


;; compile byte-counted string from `str$`
: (ir-compile-bstr-qq)
  xasm:push-tos-peephole
  xasm:call-somewhere ( .over-str )
  xasm:reset-ilist
  ;; compile the string
  nflag-bstr-compiled curr-node node-set-flag
  xasm:$here curr-node node:bstr-zx-addr:!
  curr-node node:str$
  dup 0?error" IR-ICE: null str$"
  count dup 32700 u> ?error" IR-ICE: invalid str$ length"
  dup >r for c@++ zx-c, endfor drop
  xasm:$here curr-node node:bstr-zx-addr-end:!
  xasm:jp-dest!
  ( count) r> xasm:#->tos ;


end-module WORKERS
