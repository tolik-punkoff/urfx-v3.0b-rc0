;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; startup code for ELF
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(*
syscall:
  eax -- number
  args: ebx, ecx, edx, esi, edi, ebp
*)

x86-label: xccx
10 tcom:c, 10 tcom:c,
" " tcom:cstr, 10 tcom:c,
"  CCCCCCC   XX     XX" tcom:cstr, 10 tcom:c,
" CC     CC   XX   XX" tcom:cstr, 10 tcom:c,
" CC           XX XX" tcom:cstr, 10 tcom:c,
" CC   CCCCCCC  XXX" tcom:cstr, 10 tcom:c,
" CC  CC     CC XXX" tcom:cstr, 10 tcom:c,
" CC  CC       XX XX" tcom:cstr, 10 tcom:c,
" CC  CC CC   XX   XX" tcom:cstr, 10 tcom:c,
"  CCCCCCC   XX     XX" tcom:cstr, 10 tcom:c,
"     CC" tcom:cstr, 10 tcom:c,
"     CC     CC" tcom:cstr, 10 tcom:c,
"      CCCCCCC" tcom:cstr, 10 tcom:c,
" " tcom:cstr, 10 tcom:c,
10 tcom:c,

x86-label: ensure-env
x86-start
  push  esi
  mov   esi, eax
@@0:
  movzx eax, byte^ [esi]
  or    eax, eax
  jz    @@9
  cmp   eax, # $4C
  jnz   @@1
  cmp   byte^ [esi+] 1 #, ah
  jz    @@9
  cmp   byte^ [esi+] 2 #, ah
  jz    @@9
  cmp   byte^ [esi+] 3 #, ah
  jz    @@9
  cmp   byte^ [esi+] 4 #, ah
  jz    @@9
  mov   eax, [esi]
  xor   eax, # $B8_69_45_AF
  cmp   eax, # $47_4E_41_4C $B8_69_45_AF forth:xor
  jz    @@2
  and   eax, # $00FF_FFFF
  cmp   eax, # $00_5F_43_4C $00_69_45_AF forth:xor
  jz    @@3
@@1:
  movzx eax, byte^ [esi]
  inc   esi
  or    eax, eax
  jnz   @@1
  jmp   @@0
@@2:
  add   esi, # 4
  cmp   byte^ [esi], # $3D
  jnz   @@1
  inc   esi
  jmp   @@5
@@3:
  add   esi, # 3
@@4:
  movzx eax, byte^ [esi]
  inc   esi
  cmp   eax, # $3D
  jz    @@5
  or    eax, eax
  jnz   @@4
  jmp   @@0
@@5:
  cmp   byte^ [esi], # 0
  jz    @@1
  cmp   byte^ [esi+] 1 #, # 0
  jz    @@1
  cmp   byte^ [esi+] 2 #, # 0
  jz    @@1
  mov   eax, [esi]
  and   eax, # $00FF_FFFF
  xor   eax, # $67_23_A8_D6
  cmp   eax, # $00_5F_61_75 $67_23_A8_D6 forth:xor
  jz    @@8
@@6: ;; scan
  cmp   byte^ [esi], # 0
  jz    @@1
  cmp   byte^ [esi+] 1 #, # 0
  jz    @@1
  cmp   byte^ [esi+] 2 #, # 0
  jz    @@1
  mov   eax, [esi]
  inc   esi
  and   eax, # $00FF_FFFF
  xor   eax, # $C3_A5_D7_69
  cmp   eax, # $00_41_55_5F $C3_A5_D7_69 forth:xor
  jnz   @@6
@@8:
  mov   eax, # 4     ;; write
  mov   ebx, # 2     ;; stderr
  mov   ecx, @@7
  mov   edx, # 4
  sys-call
  mov   eax, # 1     ;; exit
  mov   ebx, # 1
  sys-call
@@9:
  pop   esi
  ret
@@7:
  " NO." tcom:cstr, 10 tcom:c,
x86-end

x86-label: compat-test
x86-start
  ;; EBX: addr
  ;; ECX: flags
  ;; EDX: crperm
  mov   ebx, @@0
  mov   ecx, # linux:o-rdonly
  mov   edx, # 0o644
  mov   eax, # 5
  sys-call
  test  eax, eax
  js    @@8
@@1:
  ;; EBX: fd
  ;; ECX: addr
  ;; EDX: count
  mov   ebx, eax
  mov   ecx, # ll@ (elf-base-start)
  add   ecx, dword^ # ll@ (elf-image-size)
  sub   ecx, # 8192
  mov   esi, ecx
  mov   edx, # 256
  mov   eax, # 3
  sys-call
  cmp   eax, # 4
  jle   @@8
  push  eax
  ;; close
  mov   eax, # 6
  sys-call
  pop   ecx
  push  esi
  dec   esi
  inc   ecx
@@2:
  inc   esi
  dec   ecx
  cmp   ecx, # 9
  jl    @@7
  mov   eax, [esi]
  or    eax, # $20202020
  xor   eax, # $49DFCA62
  cmp   eax, # $72_63_69_6D $49DFCA62 forth:xor
  jnz   @@2
  mov   eax, [esi+] # 4
  or    eax, # $20202020
  xor   eax, # $4856AB3F
  cmp   eax, # $66_6F_73_6F $4856AB3F forth:xor
  jnz   @@2
  movzx eax, byte^ [esi+] # 8
  or    al, # $20
  cmp   al, # $74
  jnz   @@2
@@8:
  mov   eax, # 4     ;; write
  mov   ebx, # 2     ;; stderr
  mov   ecx, @@9
  mov   edx, # 6
  sys-call
  mov   eax, # 1     ;; exit
  mov   ebx, # 1
  sys-call
  mov   ebx, # -1
@@9:
  " OOPS." tcom:cstr, 10 tcom:c,
@@0:
  " /proc/version" tcom:cstr, 0 tcom:c,
@@7:
  pop   esi
  ret
x86-end
x86-label: xcce

\ " <STARTUP-CODE>" tcom:cstrz,
x86-label: boot-startup
x86-start
  jmp   @@f
  ;; current allocation address; variable
@@0:
  $1_0000 tcom:,
@@:
  mov   dword^ @@3, # 0
  cld   ;; just in case

  ;; restore allocation address.
  ;; this is requred for SAVEd images.
  mov   dword^ @@0, # $1_0000

  ;; save argc
  mov   ecx, [esp]
  mov   dword^ ll@ (argc-addr) #, ecx
  ;; save argv
  mov   eax, esp
  add   eax, # 4
  mov   dword^ ll@ (argv-addr) #, eax
  ;; calc envp address
  inc   ecx    ;; skip final 0 argument
  shl   ecx, # 2
  add   eax, ecx
  mov   eax, [eax]
  ;; store envp
  mov   dword^ ll@ (envp-addr) #, eax

  ;; save system ESP.
  ;; there is no reason to do it for static binaries, though,
  ;; because system-provided stack is only used in INVOKE.
  tcom:dynamic-binary [IF]
  and   esp, # 15 bitnot  ;; align it to 16 bytes, to make idiotic GCC happy
  mov   dword^ ll@ (xsp-addr) #, esp
  [ENDIF]

x86-label: xccs1
  call  # ll@ ensure-env
  call  # ll@ compat-test
x86-label: xcce1

  ;; mark last code segment page as PROT-NONE
  mov   eax, # 125  ;; MPROTECT
  mov   ebx, # ll@ (elf-base-start)
  add   ebx, dword^ # ll@ (elf-image-size)
  add   ebx, # 4095
  and   ebx, # 4095 bitnot
  sub   ebx, # 4096
  mov   ecx, # 4096
  xor   edx, edx
  sys-call

  ;; mark last headers segment page as PROT-NONE
  mov   eax, # 125  ;; MPROTECT
  mov   ebx, # ll@ (elf-hdr-base-start)
  add   ebx, dword^ # ll@ (elf-hdr-image-size)
  add   ebx, # 4095
  and   ebx, # 4095 bitnot
  sub   ebx, # 4096
  sys-call

  ;; allocate data stack
  mov   ecx, dword^ # ll@ (dssize^)
  call  @@7
  mov   dword^ ll@ (sp-start^) #, eax
  add   eax, ecx
  mov   dword^ ll@ (sp0^) #, eax

  ;; allocate return stack
  mov   ecx, dword^ # ll@ (rssize^)
  call  @@7
  mov   dword^ ll@ (rp-start^) #, eax
  add   eax, ecx
  mov   dword^ ll@ (rp0^) #, eax

  ;; allocate vocab stacks
  (*
  mov   ecx, dword^ # ll@ (vssize^)
  add   ecx, dword^ # ll@ (nssize^)
  call  @@7
  mov   dword^ ll@ (vp0^) #, eax
  add   eax, dword^ # ll@ (vssize^)
  mov   dword^ ll@ (np0^) #, eax
  *)
  mov   ecx, dword^ # ll@ (vssize^)
  call  @@7
  mov   dword^ ll@ (vp0^) #, eax
  add   ecx, dword^ # ll@ (nssize^)
  call  @@7
  mov   dword^ ll@ (np0^) #, eax

  ;; allocate loop/locals stack
  mov   ecx, dword^ # ll@ (lssize^)
  call  @@7
  mov   dword^ ll@ (lp0^) #, eax

  ;; allocate PAD buffer
  mov   ecx, dword^ # ll@ (padsize^)
  call  @@7
  mov   dword^ ll@ (pad^) #, eax

  ;; allocate FPAD buffer
  mov   ecx, dword^ # ll@ (fpadsize^)
  call  @@7
  mov   dword^ ll@ (fpad^) #, eax

  ;; allocate error message buffer
  mov   ecx, dword^ # ll@ (errmsgsize^)
  call  @@7
  mov   dword^ ll@ (errmsg^) #, eax

  ;; allocate EXPECT buffer
  mov   ecx, dword^ # ll@ (expectsize-addr)
  call  @@7
  mov   dword^ ll@ (expect-addr) #, eax

  ;; allocate segfault handler stack page
  mov   ecx, # 4096
  call  @@7
  mov   dword^ ll@ (sigstack-addr) #, eax

  ;; allocate segfault PAD buffer
  mov   ecx, dword^ # ll@ (padsize^)
  call  @@7
  mov   dword^ ll@ (sigpad-addr) #, eax

  ;; setup stacks
  mov   USP, dword^ ll@ (sp0^) #
  mov   URP, dword^ ll@ (rp0^) #

  ;; turn off idiotic "spectre mitigation".
  ;; this whole public panic is bullshit.
  ;; also, insult idiots who removed the ability to turn it off.
  mov   eax, # 172
  mov   ebx, # 53   ;; PR_SET_SPECULATION_CTRL
  mov   ecx, # 0    ;; PR_SPEC_STORE_BYPASS
  mov   ecx, # 2    ;; PR_SPEC_ENABLE
  sys-call
  call  @@4

  mov   eax, # 172
  mov   ebx, # 53   ;; PR_SET_SPECULATION_CTRL
  mov   ecx, # 1    ;; PR_SPEC_INDIRECT_BRANCH
  mov   ecx, # 2    ;; PR_SPEC_ENABLE
  sys-call
  call  @@4

  ;;mov   eax, # 172
  ;;mov   ebx, # 53   ;; PR_SET_SPECULATION_CTRL
  ;;mov   ecx, # 2    ;; PR_SPEC_L1D_FLUSH
  ;;mov   ecx, # 2    ;; PR_SPEC_ENABLE
  ;;sys-call
  ;;call  @@4

  ;; reset user area
  mov   uadr, # ll@ (mt-area-start)

  ;; perform EXECUTE
  jmp   dword^ # ll@ (cold-cfa-addr)

  mov   eax, # 1  ;; exit
  xor   ebx, ebx
  sys-call

;; allocate memory via mmap2; ECX: size.
;; return address in EAX, allocated (rounded) size in ECX.
@@7:
  ;; 192: mmap2
  ;;   ebx: addr
  ;;   ecx: size
  ;;   edx: prot
  ;;   esi: flags
  ;;   edi: fd
  ;;   ebp: offset
  ;; 124: mprotect
  ;;   ebx: addr
  ;;   ecx: size
  ;;   edx: prot
  add   ecx, # 4095
  and   ecx, # 4095 bitnot
  ;; two more pages -- guards
  add   ecx, # 4096 2 *
  push  ecx             ;; save size
  mov   ebx, dword^ @@0 ;; preferred address
  mov   eax, # 192
  mov   edx, # 3        ;; r/w
  mov   esi, # 0x22     ;; private alloc
  mov   edi, # -1
  xor   ebp, ebp
  sys-call
  cmp   eax, # 0xffff_f000
  jnc   @@9   ;; oom
  push  eax   ;; save starting address
  ;; [esp]: starting address
  ;; [esp+] # 4: full rounded size
  ;; mark first guard page as unreadable
  mov   ebx, eax
  mov   eax, # 125
  mov   ecx, # 4096
  xor   edx, edx        ;; prot-none
  sys-call
  test  eax, eax
  jnz   @@9
  ;; mark last guard page as unreadable
  ;; all registers except EAX are guaranteed to be unchanged
  mov   eax, # 125
  add   ebx, [esp+] # 4
  sub   ebx, ecx
  sys-call
  test  eax, eax
  jnz   @@9
  pop   eax             ;; address
  add   eax, # 4096     ;; skip first guard page
  pop   ecx             ;; saved size
  add   dword^ @@0, ecx ;; advance address
  sub   ecx, # 4096 2 * ;; skip guards
  ret

@@3:
  0 tcom:,  ;; already warned?
  " NOTICE: your OS was compiled by morons; 'speculation mitigation' is a total bullshit." tcom:cstr,
   10 tcom:c,
@@4:
  cmp   eax, # 6  ;; ENXIO
  jz    @@f
  cmp   eax, # 1  ;; EPERM
  nz? do-when ret
@@:
  cmp   dword^ @@3, # 0
  nz? do-when ret
  inc   dword^ @@3
  ;; print notice
  mov   eax, # 4     ;; write
  mov   ebx, # 2     ;; stderr
  mov   ecx, @@3 4+
  mov   edx, # @@4-get @@3-get - 4+
  sys-call
  ret

@@8:
  " URFORTH FATAL: out of memory!" tcom:cstr, 10 tcom:c,

@@9:
  ;; print error and exit
  mov   eax, # 4     ;; write
  mov   ebx, # 2     ;; stderr
  mov   ecx, @@8
  mov   edx, # @@9-get @@8-get -
  sys-call

  mov   eax, # 1     ;; exit
  mov   ebx, # 1
  sys-call
x86-end

x86-label@ boot-startup tcom:ep!


