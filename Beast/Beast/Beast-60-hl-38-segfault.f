;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; segfault handler; will be executed with its own stacks
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module (SEGFAULT)
<disable-hash>

0 variable (.INC-POS)

0 variable in-sighandler?

<private-words>
0 variable (BEAST-SIGARGS)
0 variable (BEAST-SIGUC)
;; signum     : dword [edx+4]
;; siginfoptr : dword [edx+8]
;; ucontextptr: dword [edx+12]

\  0 constant sigcontext_t.gs   ;; word 1, word dummy
\  4 constant sigcontext_t.fs   ;; word 1, word dummy
\  8 constant sigcontext_t.es   ;; word 1, word dummy
\ 12 constant sigcontext_t.ds   ;; word 1, word dummy
16 constant sigcontext_t.edi  ;; dword 1
20 constant sigcontext_t.esi  ;; dword 1
24 constant sigcontext_t.ebp  ;; dword 1
28 constant sigcontext_t.esp  ;; dword 1
32 constant sigcontext_t.ebx  ;; dword 1
36 constant sigcontext_t.edx  ;; dword 1
40 constant sigcontext_t.ecx  ;; dword 1
44 constant sigcontext_t.eax  ;; dword 1
48 constant sigcontext_t.trapno  ;; dword 1
52 constant sigcontext_t.err  ;; dword 1
56 constant sigcontext_t.eip  ;; dword 1
\ 60 constant sigcontext_t.eflags  ;; dword 1
\ 64 constant sigcontext_t.sig-sp  ;; dword 1
\ 68 constant sigcontext_t.ss  ;; word 1, word dummy

0 variable (BEAST-TOS)
0 variable (BEAST-USP)
0 variable (BEAST-URP)
0 variable (BEAST-UIP)

0 variable (BEAST-SIGNUM)
0 variable (BEAST-PAD) -- original PAD
0 variable (BEAST-BASE)

create (SAVED-TIO) 80 allot create;  ;; actually, 60, but who cares


: REG@  ( idx -- val )  (beast-siguc) @ + 20 + @ ;
: .REG  ( addr count idx )  nrot type ." =" reg@ .hex8 ;
: .REGS
  ." === REGISTERS ===\n"
  " EAX" sigcontext_t.eax .reg bl emit
  " EBX" sigcontext_t.ebx .reg bl emit
  " ECX" sigcontext_t.ecx .reg bl emit
  " EDX" sigcontext_t.edx .reg cr
  " ESI" sigcontext_t.esi .reg bl emit
  " EDI" sigcontext_t.edi .reg bl emit
  " EBP" sigcontext_t.ebp .reg bl emit
  " ESP" sigcontext_t.esp .reg cr
  " EIP" sigcontext_t.eip .reg bl emit
  ." TRAP #" sigcontext_t.trapno reg@ .
  ." ERR #" sigcontext_t.err reg@ 0.r cr
  ." =================\n" ;

: USP ( -- usp ) (beast-usp) @ ;
: URP ( -- usp ) (beast-urp) @ ;

: DEPTH  ( -- depth )  (sp0) usp - 4/ 1+ ;
: RDEPTH ( -- depth )  (rp0) urp - 4/ ;

: PICK   ( n -- value )  dup ?< 1- 4* usp + || drop (beast-tos) >? @ ;
: RPICK  ( n -- value )  4* (beast-urp) @ + @ ;

: .STACKS-INFO
  endcr ." Beast S-stack: start=$" (sp-start) .hex8
        ."  end=$" (sp-end) .hex8
        ."  ptr=$" usp .hex8 cr
  endcr ." Beast R-stack: start=$" (rp-start) .hex8
        ."  end=$" (rp-end) .hex8
        ."  ptr=$" urp .hex8 cr ;

: .S  -- dump data stack
  .stacks-info
  usp (sp-end) u>= ?< ." *** STACK UNDERFLOW ***\n" 1
  || usp (sp-start) u< ?< ." *** STACK OVERFLOW ***\n" (sp-start) (beast-usp) !
                       || ." *** STACK DEPTH: " depth . ." ***\n" >?
     depth >?
  32 min >r << r@ +?^| r0:1-! r@ 3 .r ." : "
               r@ pick 12 .l
               r@ pick ." $" .hex8 cr |? else| rdrop >> ;
\ [[ x86-disasm-last bye ]]

: .R  -- dump return stack
  endcr
  urp (rp-end) u>= ?< ." *** RSTACK UNDERFLOW ***\n" 0
  || urp (rp-start) u< ?< ." *** RSTACK OVERFLOW ***\n" (rp-start) (beast-urp) !
                       || ." *** RSTACK DEPTH: " rdepth . ." ***\n" >?
     rdepth >?
  32 min << dup +?^| 1- dup 3 forth:.r ." : "
            dup rpick 12 forth:.l
            dup rpick ." $" .hex8
            debug:named-backtrace? ?<
              dup rpick debug:ip>word ?< ."  -- " dup debug:.idfull
                dart:nfa>lfa dart:lfa>sfa dup @ ?< ."  (" debug:.fref ." )" || drop >?
              >?
            >?
            cr |? else| drop >>
  ." IP: $" (beast-uip) @ dup .hex8 debug:ip>word ?< ."  -- " debug:.idfull >? cr ;


\ hack for standard stacks: they may be swapped due to codegen optimisations
: FIX-SWAPPED-STACKS
  usp (sp-start) 4- (sp-end) 4+ 1- bounds not?<
    ;; swap them
    \ endcr ." SWAPPED STACKS!\n"
    usp urp
    (beast-usp) ! (beast-urp) ! >? ;


: (SETUP)
\ debug:dump-img (bye)
  base @ (beast-base) ! decimal setup-raw-output
  \ (beast-sigargs) @ 12 + @ (beast-siguc) !
  (* ESP -- return stack pointer (URP)
     EBP -- data stack pointer (USP)
     EBX -- data stack TOS (UTOS)
     EDI: reserved for user variables base *)
  sigcontext_t.eip reg@ (beast-uip) !
  sigcontext_t.esp reg@ (beast-urp) !
  sigcontext_t.ebp reg@ (beast-usp) !
  sigcontext_t.ebx reg@ (beast-tos) !
  fix-swapped-stacks
  [ tgt-build-base-binary ] [IFNOT]
    linux:is-tty? ?< linux:tty-restore ." \x1b[0m" >?
  [ENDIF] ;

;; set to non-zero to restart
;; restart word should re-setup stacks and such
0 variable RESTART-CFA

: COMMON-DUMP
  (.inc-pos) @ dup ?< ." ...while processing " execute cr || drop >?
  .regs
  .s .r
\  sigcontext_t.eip reg@ debug:ip>word ?<
\    ." EIP: $" sigcontext_t.eip reg@ .hex8 ."  -- " debug:.idfull cr
\  >?
  restart-cfa @?execute-tail
  1 (nbye) ;
\ [[ x86-disasm-last bye ]]

: SIGSEGFAULT
  (setup)
  endcr ." ************* SEGFAULT! *************\n"
  common-dump ;

: SIGFPE
  (setup)
  endcr ." ************* DIVISION BY ZERO! *************\n"
  common-dump ;

: SIGILL
  (setup)
  endcr ." ************* ILLEGAL INSTRUCTION! *************\n"
  common-dump ;

(*
: SIGTRAP
  (setup)
  endcr ." ****** DEBUG TRAP ******\n"
  common-dump ;
*)

: SIGINT
  (setup)
  endcr ." **USER BREAK**\n"
  common-dump ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;db  2  ;; SIGINT
;; signum, errcode-addr
11 variable SIGLIST
  ( 11 , ) ['] sigsegfault ,  ;; SIGSEGV (segfault)
   8 , ['] sigfpe ,           ;; SIGFPE (division by zero)
   4 , ['] sigill ,           ;; SIGILL (illegal instruction)
\   5 , ['] sigtrap ,          ;; SIGTRAP
   2 , ['] sigint ,           ;; SIGINT (^C)
  ;; no more
  0 ,


;; WARNING! DO NOT EXECUTE THIS DIRECTLY!
code-naked-no-inline: BEAST-SIGHANDLER
  cmp   dword^ tgt-['pfa] in-sighandler? #, # 0
  jnz   @@7
  mov   dword^ tgt-['pfa] in-sighandler? #, # 1

  ;; save arguments address
  mov   edx, esp

  ;; switch to our own stacks
  mov   urp, dword^ # ll@ (sigstack-addr)
  mov   usp, urp
  add   urp, # 4096
  add   usp, # 2048
  cld

  push  edx
  mov   eax, # 54     ;; ioctl
  xor   ebx, ebx      ;; stdin
  mov   ecx, # $5404  ;; TCSETSF (TCSAFLUSH)
  mov   edx, # tgt-['pfa] (saved-tio)
  sys-call
  mov   dword^ tgt-['pfa] forth:raw-emit:cr-crlf? #, # 0
  [[ tgt-build-base-binary ]] [IFNOT]
  mov   dword^ tgt-['pfa] forth:linux:raw-mode? #, # 0
  [ENDIF]
  pop   edx

  mov   dword^ tgt-['pfa] (beast-sigargs) #, edx
  mov   eax, [edx+] # 12
  mov   dword^ tgt-['pfa] (beast-siguc) #, eax
  ;; setup EDI (pointer to the user area)
  mov   uadr, [eax+] # 16 20 +

  ;; switch PAD
  \ mov   eax, dword^ # ll@ (pad-addr)
  mov   eax, [uadr+] uofs@ (pad^) #
  mov   dword^ tgt-['pfa] (beast-pad) #, eax
  mov   eax, dword^ # ll@ (sigpad-addr)
  \ mov   dword^ ll@ (pad-addr) #, eax
  mov   [uadr+] uofs@ (pad^) #, eax

  ;; signum     : dword [edx+4]
  ;; siginfoptr : dword [edx+8]
  ;; ucontextptr: dword [edx+12]

  ;; signal number
  mov   eax, [edx+] # 4
  mov   dword^ tgt-['pfa] (beast-signum) #, eax

  ;; find the handler
  mov   edx, # tgt-['pfa] siglist
@@4:
  cmp   [edx], eax
  jz    @@8
  cmp   dword^ [edx], # 0
  jz    @@7
  add   edx, # 8
  jmp   @@4

@@6:
  13 tcom:c, 10 tcom:c,
  " *** URFORTH FATAL: double fault!" tgt-cstr,
  13 tcom:c, 10 tcom:c,
@@7:
  mov   eax, # 54     ;; ioctl
  xor   ebx, ebx      ;; stdin
  mov   ecx, # $5404  ;; TCSETSF (TCSAFLUSH)
  mov   edx, # tgt-['pfa] (saved-tio)
  sys-call

  ;; print error and exit
  mov   eax, # 4     ;; write
  mov   ebx, # 2     ;; stderr
  mov   ecx, @@6
  mov   edx, # @@7-get @@6-get -
  sys-call
  mov   eax, # 1     ;; exit
  mov   ebx, # 1
  sys-call

@@8:
  ;; run the handler (EXECUTE)
  jmp   dword^ [edx+] # 4
;code-no-next (private)


<published-words>
code-naked-no-inline: SETUP-HANDLERS
  mov   dword^ tgt-['pfa] in-sighandler? #, # 0
  cld   ;; just in case

  push  utos

  mov   eax, # 54     ;; ioctl
  xor   ebx, ebx      ;; stdin
  mov   ecx, # $5401  ;; TCGETS
  mov   edx, # tgt-['pfa] (saved-tio)
  sys-call

  mov   dword^ ll@ ufo_sigact #, # tgt-['cfa] beast-sighandler
  mov   esi, # tgt-['pfa] SIGLIST
@@1:
  mov   ebx, dword^ [esi]  ;; signal number
  test  ebx, ebx
  jz    @@9
  mov   eax, # 67   ;; syscall number
  mov   ecx, # ll@ ufo_sigact
  xor   edx, edx    ;; ignore old info
  sys-call
  test  eax, eax
  jnz   @@8
  add   esi, # 8
  jmp   @@1
@@7:
  " URFORTH FATAL: cannot setup signal handlers!\n" tgt-cstr,
@@8:
  ;; print error and exit
  mov   eax, # 4     ;; write
  mov   ebx, # 2     ;; stderr
  mov   ecx, @@7
  mov   edx, # @@8-get @@7-get -
  sys-call
  mov   eax, # 1     ;; exit
  mov   ebx, # 1
  sys-call
@@9:
  pop   utos
;code-next

end-module (SEGFAULT) (private)
