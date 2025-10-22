;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; callback mechanics (creating callbacks for external libs)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
callbacks need their own stacks. we'll alloc 5 pages for each active callback:
  guard, sp, guard, rp, guard
so, 20 kb per callback.

callback pages will be reused if possible. it means that you cannot leave the
callback with `longjmp()` or something like that.

note that you can use created callback several times (i.e. pass it to the
various different callback-requiring external functions).
*)

module CALLBACK
<disable-hash>
<private-words>

$1000 constant sp-start-ofs
$2000 constant sp-end-ofs
$3000 constant rp-start-ofs
$4000 constant rp-end-ofs

|: alloc-stacks  ( -- first-guard^ )
  4096 5 * linux:prot-r/w linux:mmap not?error" cannot allocate callback stacks"
  dup >r
  ;; first guard
  4096 linux:prot-none linux:mprotect ?error" cannot assign first callback stack guard"
  ;; second guard
  r@ 4096 2* + 4096 linux:prot-none linux:mprotect ?error" cannot assign second callback stack guard"
  ;; third guard
  r@ 4096 4* + 4096 linux:prot-none linux:mprotect ?error" cannot assign third callback stack guard"
  r> ;

|: free-stacks  ( first-guard^ )
  4096 5 * linux:munmap drop ;


;; allocated, but yet unused stacks
0 quan free-stacks-list
0 quan current-stacks
0 quan old-esp

;; called on system startup
@: initialise
  free-stacks-list:!0
  current-stacks:!0 ;

;; intended to be called from error handler
@: free-all-stacks
  current-stacks ?< current-stacks free-stacks current-stacks:!0 >?
  free-stacks-list << dup ?^| dup rp-start-ofs + @ swap free-stacks |? else| drop >>
  free-stacks-list:!0 ;

|: get-stacks  ( -- first-guard^ )
  free-stacks-list not?exit< alloc-stacks >?
  free-stacks-list dup rp-start-ofs + @ free-stacks-list:! ;

|: release-stacks  ( first-guard^ )
  free-stacks-list over rp-start-ofs + !
  free-stacks-list:! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; callback struct

;; WARNING! DO NOT EXECUTE THIS DIRECTLY!
;; ECX: #in
;; EDX: cfa
code-naked-no-inline: (CB-MCODE-MAIN)
  ;; save registers required by ABI
  push  ebp
  push  esi
  push  edi
  push  ebx
  push  dword^ # tgt-['pfa] current-stacks
  push  dword^ # tgt-['pfa] old-esp
  ;; reset user area (i.e. switch to "system" task)
  mov   uadr, # ll@ (mt-area-start)
  ;; use CPU stack as temp working area
  lea   ebp, [esp+] # -256  ;; data stack; reserve 64 items for return stack
  ;; save cfa and #in
  push  edx
  push  ecx
  ;; indirect, to avoid fixing the offset
  mov   eax, # tgt-['cfa] get-stacks
  call  eax
  ;; restore #in and cfa
  pop   ecx
  pop   esi
  ;; ECX: #in
  ;; ESI: cfa
  mov   dword^ tgt-['pfa] current-stacks #, utos
  lea   edx, [esp+] # 7 forth:4*  ;; offset to args
  mov   dword^ tgt-['pfa] old-esp #, esp
  lea   ebp, [utos+] # sp-end-ofs
  lea   esp, [utos+] # rp-end-ofs
  ;; copy args
  mov   eax, esp
  mov   esp, ebp
  mov   ebp, eax
  ;; copy loop
  xor   utos, utos
@@1:
  test  ecx, ecx
  jz    @@2
  dec   ecx
  push  utos
  mov   utos, [edx]
  lea   edx, [edx+] # 4
  jmp   @@1
@@2:
  ;; swap stacks again
  mov   eax, esp
  mov   esp, ebp
  mov   ebp, eax
  ;; call main word
  call  esi
  ;; utos is the result
  ;; restore ESP
  mov   esp, dword^ # tgt-['pfa] old-esp
  ;; release stacks
  push  utos
  ;; use CPU stack as temp working area
  lea   ebp, [esp+] # -256  ;; data stack; reserve 64 items for return stack
  mov   utos, dword^ # tgt-['pfa] current-stacks
  ;; indirect, to avoid fixing the offset
  mov   eax, # tgt-['cfa] release-stacks
  call  eax
  ;; pop  result
  pop   eax
  ;; pop old var values
  pop   dword^ tgt-['pfa] old-esp #
  pop   dword^ tgt-['pfa] current-stacks #
  ;; pop other registers
  pop   ebx
  pop   edi
  pop   esi
  pop   ebp
  ;; we're done
  ret
;code-no-next (private)


(*
0 quan CB-MCODE^
0 quan CB-MCODE#
0 quan CB-MCODE-#IN-OFS
0 quan CB-MCODE-CFA-OFS

;; WARNING! DO NOT EXECUTE THIS DIRECTLY!
;; this code will be cloned to create new callback word
code-naked-no-inline: CB-MCODE
flush! $ CB-MCODE^:!
  mov   edx, # $1234_5678   ;; CFA, will be patched
flush! $ CB-MCODE^ forth:- forth:4- CB-MCODE-CFA-OFS:!
  mov   ecx, # $1234_5678   ;; number of args, will be patched
  flush! $ CB-MCODE^ forth:- forth:4- CB-MCODE-#IN-OFS:!
  mov   eax, # tgt-['cfa] (CB-MCODE-MAIN)
  jmp   eax
  nop nop nop
flush! $ CB-MCODE^ forth:- CB-MCODE#:!
;code-no-next (private)

\ @: #cback-mc  ( -- mcode-bytes )  CB-MCODE# ;

;; create new callback. return address which should be passed to external funcs.
@: new  ( #in cfa -- cbcall-addr )
  dup not?error" empty callback CFA"
  over 0 64 within not?error" invalid number of IN arguments for callback"
  << here 3 and ?^| 0 c, |? else| >>
  here >r  CB-MCODE# 3 + 4 ~and (dpallot)
  CB-MCODE^ r@ CB-MCODE# cmove
  r@ CB-MCODE-CFA-OFS + !
  r@ CB-MCODE-#IN-OFS + !
  << here 3 and ?^| 0 c, |? else| >>
  r> ;
*)

;; create new callback. return address which should be passed to external funcs.
;; for cdecl function `(int a, int b, int c)` Forth stack is `( a b c -- res )`.
;; TOS is always returned to the caller in EAX.
;; yes, callback is CDECL (i.e. the caller should clean the stack).
;; internally, the system will copy args, and switch to temporary stacks.
@: new  ( #in cfa -- cbcall-addr )
  dup not?error" empty callback CFA"
  over 0 64 within not?error" invalid number of IN arguments for callback"
  ;; align
  << here 3 and ?^| 0 c, |? else| >>
  here >r
  ;; put machine code
  $BA c, ,  ;; mov  edx, CFA
  $B9 c, ,  ;; mov  ecx, #in
  $B8 c, ['] (CB-MCODE-MAIN) ,  ;; mov eax, tgt-['cfa] (CB-MCODE-MAIN)
  $FF c, $E0 c, ;; jmp  eax
  ;; align
  << here 3 and ?^| 0 c, |? else| >>
  r> ;

seal-module
end-module CALLBACK
