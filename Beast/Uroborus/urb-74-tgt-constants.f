;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target system constants
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


ll@ (uptable)  tgt-constant (SYS-UPTABLE)
ll@ (lotable)  tgt-constant (SYS-LOTABLE)


ll@ (uarea#^) tgt-constant (#USER)
;; one page
tgt-UAREA-SIZE tgt-constant (#USER-MAX)

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; USER offsets

;; set by "mtask:switch"
\ ll@ (switched-from^) tgt-uservar (PREV-TASK-USER)

ll@ (saved-sp^) tgt-uservar (SP-SAVED)
ll@ (saved-rp^) tgt-uservar (RP-SAVED)

ll@ (dssize^)   tgt-uservar (#DSTACK-BYTES^)
ll@ (sp-start^) tgt-uservar (SP-START^)
ll@ (sp0^)      tgt-uservar (SP0^)

ll@ (rssize^)   tgt-uservar (#RSTACK-BYTES^)
ll@ (rp-start^) tgt-uservar (RP-START^)
ll@ (rp0^)      tgt-uservar (RP0^)

;; this represents XSTACK structure, so field order matters!
ll@ (vsp^)    tgt-uservar (VSP)
ll@ (vssize^) tgt-uservar (#VSTACK-BYTES)
ll@ (vp0^)    tgt-uservar (VP-START)

;; this represents XSTACK structure, so field order matters!
ll@ (nsp^)    tgt-uservar (NSP)
ll@ (nssize^) tgt-uservar (#NSTACK-BYTES)
ll@ (np0^)    tgt-uservar (NP-START)

ll@ (lbp^)    tgt-uservar (LBP)
ll@ (lsp^)    tgt-uservar (LSP)
ll@ (lssize^) tgt-uservar (#LSTACK-BYTES)
ll@ (lp0^)    tgt-uservar (LP-START)

ll@ (padsize^) tgt-uservalue #PAD
ll@ (pad^)     tgt-uservalue PAD

ll@ (fpadsize^) tgt-uservalue #FPAD
ll@ (fpad^)     tgt-uservalue FPAD

ll@ (errmsgsize^) tgt-uservalue #ERRMSG-BUF
ll@ (errmsg^)     tgt-uservalue ERRMSG-BUF

ll@ (buf#-pos^) tgt-uservalue (BUF#-POS)
ll@ (fhld^) tgt-uservalue (FHLD)

ll@ (base^)    tgt-uservar BASE
ll@ (current^) tgt-uservar CURRENT
ll@ (context^) tgt-uservar CONTEXT

\ ll@ (ws-allow-pseudo^) tgt-uservalue WS-ALLOW-PSEUDO
ll@ (ws-vocab-cfa^) tgt-uservalue WS-VOCAB-CFA
ll@ (ws-vocid-hit^) tgt-uservalue WS-VOCID-HIT

;; the two following uservars are not used by the system
ll@ (this^) tgt-uservalue (THIS)
ll@ (excf^) tgt-uservalue (EXCF)

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


ll@ (expect-addr)     tgt-constant (EXPECT-BUF)
ll@ (expectsize-addr) tgt-constant (#EXPECT)

ll@ (dp-addr)     tgt-constant (DP)
ll@ (hdr-dp-addr) tgt-constant (HDR-DP)

ll@ (emit-addr)   tgt-constant (EMIT^)
ll@ (type-addr)   tgt-constant (TYPE^)
ll@ (cr-addr)     tgt-constant (CR^)
ll@ (endcr?-addr) tgt-constant (ENDCR?^)
ll@ (endcr!-addr) tgt-constant (ENDCR!^)
ll@ (endcr-addr)  tgt-constant (ENDCR^)
ll@ (getch-addr)  tgt-constant (GETCH^)

tgt-voc-link-va  tgt-constant VOC-LINK
tgt-xfa-va       tgt-constant (LAST-XFA) -- should be hidden

ll@ (sys-reset-cfa^) tgt-constant (SYS-RESET-CFA^)
ll@ (sys-reset-cfa^) constant tgt-(reset-system)-cfa-va
tgt-(abort)-cfa  tgt-constant (ABORT^)

tcom:base-va      tgt-constant (ELF-BASE-ADDR)
tcom:hdr-base-va  tgt-constant (ELF-HDR-BASE-ADDR)
tcom:codesize-va  tgt-constant (ELF-CODE-SIZE)
tcom:imagesize-va tgt-constant (ELF-IMAGE-SIZE)
tcom:hdr-foffset-va   tgt-constant (ELF-HDR-FOFFSET-SIZE)
tcom:hdr-codesize-va  tgt-constant (ELF-HDR-CODE-SIZE)
tcom:hdr-imagesize-va tgt-constant (ELF-HDR-IMAGE-SIZE)

tcom:dlopen-va    tgt-constant (ELF-DLOPEN^)
tcom:dlclose-va   tgt-constant (ELF-DLCOLOSE^)
tcom:dlsym-va     tgt-constant (ELF-DLSYM^)
BEAST-PE [IF]
tgt-dynamic-binary " oops" not?error
tcom:dynamic-binary " oops" not?error
tcom:exitproc-va  tgt-constant (PE-EXITPROC^)
true tgt-constant (DYNAMIC-BINARY)
[ELSE]
tcom:imptable-va    tgt-constant (ELF-IMPTABLE-ADDR)
tcom:imptable-size  tgt-constant (ELF-IMPTABLE-SIZE)
tcom:dynamic-binary tgt-constant (DYNAMIC-BINARY)
[ENDIF]

tgt-mtask-support [IF]
ll@ (mt-area-start) tgt-constant (MT-AREA-START)
ll@ (mt-area-end) ll@ (mt-area-start) - tgt-constant (MT-AREA#)
[ENDIF]

ll@ (build-ts-utc^) tgt-constant (BUILD-TS-UTC^)
ll@ (build-ts-utc-strz^) tgt-constant (BUILD-TS-UTC-STRZ^)


;; for x86asm
\ BEAST-IP-REG tgt-constant (BEAST-IP-REG)
BEAST-RP-REG tgt-constant (BEAST-RP-REG)
BEAST-SP-REG tgt-constant (BEAST-SP-REG)
BEAST-TOS-REG tgt-constant (BEAST-TOS-REG)
BEAST-ADR-REG tgt-constant (BEAST-ADR-REG)

true tgt-constant BEAST-DEVASTATOR
