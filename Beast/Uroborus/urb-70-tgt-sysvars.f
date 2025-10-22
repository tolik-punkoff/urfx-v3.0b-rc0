;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target system variables
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; global hash table is at the start of the headers segment
;; this *MUST* be honored, because it is used in image saving.

tcom:hdr-here tgt-ghtable-va:! tgt-#htable tcom:hdr-reserve-dw


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some system variables

tcom:base-va          x86-label-#: (elf-base-start)
tcom:hdr-base-va      x86-label-#: (elf-hdr-base-start)
tcom:imagesize-va     x86-label-#: (elf-image-size)
tcom:hdr-imagesize-va x86-label-#: (elf-hdr-image-size)

x86-label: (argc-addr)  0 tcom:def4
x86-label: (argv-addr)  0 tcom:def4
x86-label: (envp-addr)  0 tcom:def4

;; segfault handler stacks: 2KB for data, 2KB for return (512 items each)
x86-label: (sigstack-addr)  0 tcom:def4
;; signal handler will have a separate PAD
x86-label: (sigpad-addr)    0 tcom:def4

tcom:dynamic-binary [IF]
x86-label: (xsp-addr)  0 tcom:def4  ;; original system ESP
[ENDIF]

tgt-mtask-support [IF]
x86-label: (mtcheck-pfa) 0 tcom:def4
x86-label: (mticount)    0 tcom:def4
[ENDIF]


\ tcom:align-here-64
64 tcom:xalign


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; char uppercase table
x86-label: (uptable)
tcom:here tcom:>real 256 tcom:reserve
dup tgt-(uptable):!
string:build-koi8-uptable

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; char lowercase table
x86-label: (lotable)
tcom:here tcom:>real 256 tcom:reserve
string:build-koi8-lotable


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; default USER area
x86-label: (mt-area-start)

;; set by "mtask:switch"
\ x86-label: (switched-from^)  0 tcom:def4

x86-label: (saved-sp^)  0 tcom:def4
x86-label: (saved-rp^)  0 tcom:def4

;; the order must be exactly like this!
x86-label: (dssize^)  4096 tcom:def4  ;; data stack size
x86-label: (sp-start^)   0 tcom:def4
x86-label: (sp0^)        0 tcom:def4

x86-label: (rssize^)  4096 tcom:def4  ;; return stack size
x86-label: (rp-start^)   0 tcom:def4
x86-label: (rp0^)        0 tcom:def4

x86-label: (vsp^)        0 tcom:def4
x86-label: (vssize^)  4096 tcom:def4  ;; vocab-context stack size
x86-label: (vp0^)        0 tcom:def4  ;; vocab-context stack

x86-label: (nsp^)        0 tcom:def4
x86-label: (nssize^)  4096 tcom:def4  ;; vocab-current stack size
x86-label: (np0^)        0 tcom:def4  ;; vocab-current stack

x86-label: (lbp^)        0 tcom:def4
x86-label: (lsp^)        0 tcom:def4
x86-label: (lssize^)  4096 tcom:def4  ;; loop/locals stack size
x86-label: (lp0^)        0 tcom:def4  ;; loop/locals stack

x86-label: (padsize^) 4096 tcom:def4  ;; PAD buffer size
x86-label: (pad^)        0 tcom:def4  ;; page for PAD (numeric buffer starts from below)

x86-label: (fpadsize^) 4096 tcom:def4  ;; FPAD (floating-point pad) buffer size
x86-label: (fpad^)        0 tcom:def4  ;; page for FPAD

x86-label: (errmsgsize^) 4096 tcom:def4  ;; error message buffer size
x86-label: (errmsg^)        0 tcom:def4  ;; page for error message

x86-label: (base^) 10 tcom:def4  ;; BASE

x86-label: (buf#-pos^) 0 tcom:def4  ;; for numeric conversions
x86-label: (fhld^)     0 tcom:def4  ;; for float conversions

x86-label: (current^) 0 tcom:def4 ;; CURRENT
ll@ (current^) to tgt-current-va  ;; this is wrong, but we're using default user area anyway
x86-label: (context^) 0 tcom:def4 ;; CONTEXT
ll@ (context^) to tgt-context-va  ;; this is wrong, but we're using default user area anyway

\ x86-label: (ws-allow-pseudo^)   -1 tcom:def4
x86-label: (ws-vocab-cfa^)      0 tcom:def4
x86-label: (ws-vocid-hit^)      0 tcom:def4

;; the two following uservars are not used by the system
x86-label: (this^) 0 tcom:def4  ;; (THIS)
x86-label: (excf^) 0 tcom:def4  ;; (EXCF) -- exception frame

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

\ tgt-mtask-support [IF]
x86-label: (mt-area-end)
\ [ENDIF]
ll@ (mt-area-start) constant def-user-area-va
ll@ (mt-area-end) def-user-area-va - constant def-user-area-size
\ ." used user area bytes: " def-user-area-size 0.r, cr

tgt-mtask-support [IF] 4096 [ELSE] 256 [ENDIF]
constant tgt-UAREA-SIZE

;; reserve room for user vars
tgt-UAREA-SIZE def-user-area-size -
dup 64 < " user area too small" ?error
tcom:reserve
64 tcom:xalign \ tcom:align-here-64

;; current user area size
;; used to allocate new user vars
x86-label: (uarea#^) def-user-area-size tcom:def4


x86-label: (expect-addr)        0 tcom:def4
x86-label: (expectsize-addr) 4096 tcom:def4

;; voclink and latest XFA
tcom:here to tgt-voc-link-va 0 tcom:def4
tcom:here to tgt-xfa-va      0 tcom:def4  ;; last XFA address
;; source file reference list tail
x86-label: (finfo-tail-addr) 0 tcom:def4
ll@ (finfo-tail-addr) to tgt-finfo-tail-va
;; dictionary pointer
x86-label: (dp-addr)  0 tcom:def4
;; headers dictionary pointer
x86-label: (hdr-dp-addr)  0 tcom:def4
;; global hash table address
x86-label: (ghtable-addr)  tgt-ghtable-va tcom:def4

;; address of fatal error reporter: ( addr count )
;; ERROR will jump there
tcom:here constant tgt-(abort)-cfa  0 tcom:def4

;; system reset (reinit) word; required by REPL
x86-label: (sys-reset-cfa^)  0 tcom:def4

;; cold start (startup code will execute this word)
x86-label: (cold-cfa-addr)  0 tcom:def4

;; vectored output
x86-label: (emit-addr)   0 tcom:def4
x86-label: (type-addr)   0 tcom:def4
x86-label: (cr-addr)     0 tcom:def4
x86-label: (endcr?-addr) 0 tcom:def4
x86-label: (endcr!-addr) 0 tcom:def4
x86-label: (endcr-addr)  0 tcom:def4
x86-label: (getch-addr)  0 tcom:def4

;; for signal handler
BEAST-PE not [IF]
;; sadly, we cannot return to OS to allow it to reset "signal handled" flag,
;; so we have to use "SA_NODEFER". this is COMPLETELY WRONG, and should never
;; be done like this, but tbh, anything i'll do to return from SEGFAULT is a
;; hackery anyway. it is not supposed to be used like this at all.
;; we can prolly use some "sys_sigreturn" magic, but it is as fragile as any other thing.
x86-label: ufo_sigact
\ urfd_sigact.sa_handler:  ;;dd 0  ;; union with .sa_sigaction
( urfd_sigact.sa_sigaction: ) 0 tcom:,  ;; will be patched later \ dd ufo_sighandler
( urfd_sigact.sa_mask: )      0 tcom:,  ;; 0xffffffff
( urfd_sigact.sa_flags: )     $40000004 tcom:,  ;; "nodefer", because we will never correctly return from here
( urfd_sigact.sa_restorer: )  0 tcom:,
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; build timestamp

x86-label: (build-ts-utc^)  linux:time tcom:def4

x86-label: (build-ts-utc-strz^)

: build-ts  ( unix-time )
  " (build-ts-utc^)" (x86-find-label) tcom:@
  dup utime>dmy
  <# # # # # #> tcom:cstr, [char] / tcom:c,
  <# # # #> tcom:cstr, [char] / tcom:c,
  <# # # #> tcom:cstr, bl tcom:c,
  utime>hms
  <# # # #> tcom:cstr, [char] : tcom:c,
  <# # # #> tcom:cstr, [char] : tcom:c,
  <# # # #> tcom:cstr, 0 tcom:c,
  4 tcom:nalign ;

build-ts

;; get label - (mt-area-start)
*: uofs@  ( -- value )  \ name
  x86-find-label def-user-area-va -
  dup 0 def-user-area-size within not?error" invalid user label"
  [\\] {#,} ;
