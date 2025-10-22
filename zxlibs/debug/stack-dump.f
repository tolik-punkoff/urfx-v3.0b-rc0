;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Z80 Abersoft fig-FORTH recompiled
;; Copyright (C) 2024 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; various other words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


: .S
  SYS: ?STACK
  BASE @ >R DECIMAL ." \cDEPTH=" SYS: DEPTH . CR
  SYS: DEPTH 16 MIN FOR
    I 0 .R ." : "
    SYS: SP@ I 2* + @
    DUP 6 .R 2 SPACES
    DUP 6 U.R 2 SPACES
    HEX 4 U.R DECIMAL CR
  LOOP R> BASE ! ;
