;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler: operand definitions
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


[HAS-WORD] BEAST-NO-IP-REG [IFNOT]
true constant BEAST-NO-IP-REG
[ENDIF]

BEAST-NO-IP-REG [IFNOT]
  [HAS-WORD] BEAST-IP-REG [IFNOT] (BEAST-IP-REG) constant BEAST-IP-REG [ENDIF]
[ENDIF]
[HAS-WORD] BEAST-RP-REG [IFNOT] (BEAST-RP-REG) constant BEAST-RP-REG [ENDIF]
[HAS-WORD] BEAST-SP-REG [IFNOT] (BEAST-SP-REG) constant BEAST-SP-REG [ENDIF]
[HAS-WORD] BEAST-TOS-REG [IFNOT] (BEAST-TOS-REG) constant BEAST-TOS-REG [ENDIF]
[HAS-WORD] BEAST-ADR-REG [IFNOT] (BEAST-ADR-REG) constant BEAST-ADR-REG [ENDIF]


[HAS-WORD] BEAST-IP-REG [IF]
dd BEAST-IP-REG reg32 mk-op-, UIP,
BEAST-IP-REG rm32 mk-op-, [UIP],
BEAST-IP-REG rm32+ mk-op-, [UIP+],
[ENDIF]
[HAS-WORD] BEAST-RP-REG [IF]
dd BEAST-RP-REG reg32 mk-op-, URP,
BEAST-RP-REG rm32 mk-op-, [URP],
BEAST-RP-REG rm32+ mk-op-, [URP+],
[ENDIF]
[HAS-WORD] BEAST-SP-REG [IF]
dd BEAST-SP-REG reg32 mk-op-, USP,
BEAST-SP-REG rm32 mk-op-, [USP],
BEAST-SP-REG rm32+ mk-op-, [USP+],
[ENDIF]
[HAS-WORD] BEAST-TOS-REG [IF]
dd BEAST-TOS-REG reg32 mk-op-, UTOS,
BEAST-TOS-REG rm32 mk-op-, [UTOS],
BEAST-TOS-REG rm32+ mk-op-, [UTOS+],
[ENDIF]
[HAS-WORD] BEAST-ADR-REG [IF]
dd BEAST-ADR-REG reg32 mk-op-, UADR,
BEAST-ADR-REG rm32 mk-op-, [UADR],
BEAST-ADR-REG rm32+ mk-op-, [UADR+],
[ENDIF]


[HAS-WORD] BEAST-TOS-REG [IF]
BEAST-TOS-REG 4 <> [IF]
BEAST-TOS-REG 8 * 0o000 + si32 mk-op-, [UTOS*1],
BEAST-TOS-REG 8 * 0o100 + si32 mk-op-, [UTOS*2],
BEAST-TOS-REG 8 * 0o200 + si32 mk-op-, [UTOS*4],
BEAST-TOS-REG 8 * 0o300 + si32 mk-op-, [UTOS*8],
BEAST-TOS-REG 8 * 0o000 + si32+ mk-op-, [UTOS*1+],
BEAST-TOS-REG 8 * 0o100 + si32+ mk-op-, [UTOS*2+],
BEAST-TOS-REG 8 * 0o200 + si32+ mk-op-, [UTOS*4+],
BEAST-TOS-REG 8 * 0o300 + si32+ mk-op-, [UTOS*8+],
[ENDIF] [ENDIF]

[HAS-WORD] BEAST-ADR-REG [IF]
BEAST-ADR-REG 4 <> [IF]
BEAST-ADR-REG 8 * 0o000 + si32 mk-op-, [UADR*1],
BEAST-ADR-REG 8 * 0o100 + si32 mk-op-, [UADR*2],
BEAST-ADR-REG 8 * 0o200 + si32 mk-op-, [UADR*4],
BEAST-ADR-REG 8 * 0o300 + si32 mk-op-, [UADR*8],
BEAST-ADR-REG 8 * 0o000 + si32+ mk-op-, [UADR*1+],
BEAST-ADR-REG 8 * 0o100 + si32+ mk-op-, [UADR*2+],
BEAST-ADR-REG 8 * 0o200 + si32+ mk-op-, [UADR*4+],
BEAST-ADR-REG 8 * 0o300 + si32+ mk-op-, [UADR*8+],
[ENDIF] [ENDIF]

[HAS-WORD] BEAST-IP-REG [IF]
;; sib value; index-scale
BEAST-IP-REG 4 <> [IF]
BEAST-IP-REG 8 * 0o000 + si32 mk-op-, [UIP*1],
BEAST-IP-REG 8 * 0o100 + si32 mk-op-, [UIP*2],
BEAST-IP-REG 8 * 0o200 + si32 mk-op-, [UIP*4],
BEAST-IP-REG 8 * 0o300 + si32 mk-op-, [UIP*8],
BEAST-IP-REG 8 * 0o000 + si32+ mk-op-, [UIP*1+],
BEAST-IP-REG 8 * 0o100 + si32+ mk-op-, [UIP*2+],
BEAST-IP-REG 8 * 0o200 + si32+ mk-op-, [UIP*4+],
BEAST-IP-REG 8 * 0o300 + si32+ mk-op-, [UIP*8+],
[ENDIF] [ENDIF]

[HAS-WORD] BEAST-RP-REG [IF]
BEAST-RP-REG 4 <> [IF]
BEAST-RP-REG 8 * 0o000 + si32 mk-op-, [URP*1],
BEAST-RP-REG 8 * 0o100 + si32 mk-op-, [URP*2],
BEAST-RP-REG 8 * 0o200 + si32 mk-op-, [URP*4],
BEAST-RP-REG 8 * 0o300 + si32 mk-op-, [URP*8],
BEAST-RP-REG 8 * 0o000 + si32+ mk-op-, [URP*1+],
BEAST-RP-REG 8 * 0o100 + si32+ mk-op-, [URP*2+],
BEAST-RP-REG 8 * 0o200 + si32+ mk-op-, [URP*4+],
BEAST-RP-REG 8 * 0o300 + si32+ mk-op-, [URP*8+],
[ENDIF] [ENDIF]

[HAS-WORD] BEAST-SP-REG [IF]
BEAST-SP-REG 4 <> [IF]
BEAST-SP-REG 8 * 0o000 + si32 mk-op-, [USP*1],
BEAST-SP-REG 8 * 0o100 + si32 mk-op-, [USP*2],
BEAST-SP-REG 8 * 0o200 + si32 mk-op-, [USP*4],
BEAST-SP-REG 8 * 0o300 + si32 mk-op-, [USP*8],
BEAST-SP-REG 8 * 0o000 + si32+ mk-op-, [USP*1+],
BEAST-SP-REG 8 * 0o100 + si32+ mk-op-, [USP*2+],
BEAST-SP-REG 8 * 0o200 + si32+ mk-op-, [USP*4+],
BEAST-SP-REG 8 * 0o300 + si32+ mk-op-, [USP*8+],
[ENDIF] [ENDIF]
