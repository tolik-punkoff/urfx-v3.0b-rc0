;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; low-level native instruction emitters (used for clarity)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level code generation
;; ALWAYS use this instead of direct byte stuffing!

module low
<disable-hash>
<published-words>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level branch address manipulations
;; DO NOT USE!

;; write "branch to destaddr" address to addr
: branch-addr!  ( destaddr addr )  tuck 4+ - swap code-! ;

;; read branch address
: branch-addr@  ( addr -- dest )  dup code-@ + 4+ ;

;; compile branch address
: branch-addr,  ( addr -- dest )  code-here 0 code-dd, branch-addr! ;

;; read 8-bit branch address
: branch-addr-c@  ( addr -- dest )  dup code-c@ + 1+ ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; for convenience

xasm:(eax) constant eax
xasm:(ecx) constant ecx
xasm:(edx) constant edx
xasm:(ebx) constant ebx
xasm:(esp) constant esp
xasm:(ebp) constant ebp
xasm:(esi) constant esi
xasm:(edi) constant edi


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

: remove-last-unsafe
  ilendb:last-len@ code-unallot ilendb:drop ;

;; check if removing last instruction will not cross bblock boundary
: can-remove-last?  ( -- flag )
  ilendb:last-len@ dup ?< code-here swap - bblock-start^ u>= >? ;

: can-remove-last-2?  ( -- flag )
  ilendb:last-len@ dup not?exit
  ilendb:prev-last-len@ dup not?exit< 2drop false >?
  + code-here swap - bblock-start^ u>= ;

: can-remove-last-3?  ( -- flag )
  ilendb:last-len@ dup not?exit
  ilendb:prev-last-len@ dup not?exit< 2drop false >?
  +  2 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  + code-here swap - bblock-start^ u>= ;

: can-remove-last-4?  ( -- flag )
  ilendb:last-len@ dup not?exit
  ilendb:prev-last-len@ dup not?exit< 2drop false >?
  +  2 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  +  3 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  + code-here swap - bblock-start^ u>= ;

: can-remove-last-5?  ( -- flag )
  ilendb:last-len@ dup not?exit
  ilendb:prev-last-len@ dup not?exit< 2drop false >?
  +  2 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  +  3 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  +  4 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  + code-here swap - bblock-start^ u>= ;

: can-remove-last-6?  ( -- flag )
  ilendb:last-len@ dup not?exit
  ilendb:prev-last-len@ dup not?exit< 2drop false >?
  +  2 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  +  3 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  +  4 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  +  5 ilendb:nth-last-len@ dup not?exit< 2drop false >?
  + code-here swap - bblock-start^ u>= ;

: last-removable-push-tos?  ( -- flag )
  ilendb:last-type@ ilendb:it-push-ebx = dup ?<
    drop can-remove-last? >? ;
\  code-here 1- code-c@ $53 = ;

: last-removable-pop-tos?  ( -- flag )
  ilendb:last-type@ ilendb:it-pop-ebx = dup ?<
    drop can-remove-last? >? ;
\  code-here 1- code-c@ $5B = ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; stack pointer registers tracking

false quan stacks-swapped?


: force-reset-swap-stacks
  stacks-swapped?:!f ;

;; is last compiled instruction "swap-stacks"?
: last-instr-swap-stacks?  ( -- flag )
  [ SC-EXPERIMENTAL-NO-SSWAP-OPT ] [IF] false exit [ENDIF]
  ilendb:last-type@ ilendb:it-sswap = ?<
    code-here ilendb:last-len@ - bblock-start^ u>= || false >? ;

: remove-last-stack-swap
  remove-last-unsafe ;

: swap-stacks,
  ilendb:cg-begin
  xasm:reset
    xasm:edx xasm:, xasm:ebp xasm:instr:mov,
    xasm:ebp xasm:, xasm:esp xasm:instr:mov,
    xasm:esp xasm:, xasm:edx xasm:instr:mov,
    \ old code
    \ xasm:ebp xasm:, xasm:esp xasm:instr:xchg,
  ilendb:cg-end-sswap ;

\ WARNING! do not turn on, this conflicts with loop align/realign code!
0 [IF]
(*
  the idea is this: check previous instructions, stop at
  any stack modify/access operation (or jmp, or call).
  if no such operations were found, and we hit yet another
  stack swap, eliminate it, and don't write a new one.
*)

0 quan ssc-caddr  -- current code address
0 quan ssc-ilen   -- cuurent instruction length
0 quan ssc-iidx   -- current index (from the last) in ilendb
;; how many instructions should be scanned?
16 constant ssc-limit
0 quan ssc-x-limit


: ssc-reg?  ( reg -- flag )  dup ebp = swap esp = or ;

|: mrm-reg   ( mod-r/m -- reg )  &o070 and 8 u/ ;
|: mrm-r/m   ( mod-r/m -- reg )  &o007 and ;
|: sib-index ( mod-r/m -- reg )  &o070 and 8 u/ ;
|: sib-base  ( mod-r/m -- reg )  &o007 and ;

;; check if mod-r/m byte is using [ebp] or ebp or esp.
;; returns false for SIB byte (it should be checked separately).
;; mod=3 already checked, mrm-reg already checked.
|: mod-r/m-stack?  ( mod-r/m -- flag )
  dup &o300 and not?exit< drop false >?
  mrm-r/m ebp = ;

|: mod-r/m-sib?  ( mod-r/m -- has-sib-flag )
  mrm-r/m 4 = ;

|: sib-stack?  ( sib -- flag )
  dup sib-base esp =
  swap sib-index ebp = or ;

|: bad-instr-1-byte?  ( -- flag )
  ssc-caddr code-c@ <<
    dup $50 $5F bounds ?of?v| true |?
    dup $70 $7F bounds ?of?v| true |?
    dup $E8 $EB bounds ?of?v| true |?
    $6A of?v| true |?
    $68 of?v| true |?
    $BC of?v| true |?
    $BD of?v| true |?
    $C3 of?v| true |?
    $8F of?v| true |?
  else| drop false >> ;

|: bad-instr-2-byte?  ( dd -- flag )
  dup lo-byte <<
    $0F of?v| hi-byte $80 $8F bounds |?
    $FF of?v| hi-byte &o070 and &o010 > |?
  else| 2drop false >> ;

;; some instructions use "rrr" as opcode part. fix 'em.
|: fix-known-mrm  ( opc-dd -- opc-dd )
  dup lo-byte <<
    dup $80 $83 bounds ?of?v| &o070 256 u* or |?
    \ dup $B0 $BF bounds ?of?v| &o070 256 u* or |?  -- already checked
    dup $C0 $C1 bounds ?of?v| &o070 256 u* or |?
    dup $D0 $D3 bounds ?of?v| &o070 256 u* or |?
  else| drop >> ;

|: bad-instr?  ( code-addr -- flag )
\ endcr ." BAD-INSTR: addr=$" dup .hex8
  bad-instr-1-byte? ?exit&leave
  ssc-ilen 1 <> not?exit&leave
  ssc-caddr code-@
  dup bad-instr-2-byte? ?exit< drop true >?
  dup lo-byte $B0 $BF bounds ?exit< drop false >?  ;; mov reg, imm
  fix-known-mrm
  dup lo-byte $0F = ?< 256 u/ >?
  ;; don't bother with proper opcode checking, just assume that mod-r/m is always there
  dup hi-byte
  ( opc-dd mod-reg-r/m )
  dup mrm-reg ssc-reg? ?exit< 2drop true >?
  dup &o300 and &o300 = ?exit< nip mrm-r/m ssc-reg? >?
  dup mod-r/m-stack? ?exit< 2drop true >?
  mod-r/m-sib? not?exit< drop false >?
  hi-word lo-byte sib-stack? ;

|: remove-current-instruction
\ endcr ." killing instruction #" ssc-iidx . ." at $" ssc-caddr .hex8 ."  (len=" ssc-ilen 0.r ." )\n"
  ssc-iidx ilendb:remove-last-nth
  code-here ssc-caddr ssc-ilen + << ( end src )
    dup code-c@ over ssc-ilen - code-c!
    1+ 2dup u> ?^||
  else| 2drop >>
  ssc-ilen code-unallot ;

|: ssc-calc-limit  ( -- limit )
  code-here >r 0 << ( cnt | istart )
    dup ilendb:nth-last-len@ r0:-!
    r@ bblock-start^ u< ?v| drop 0 |?
    dup ilendb:nth-last-type@ ilendb:it-sswap of?v||
    ilendb:it-jdisp ilendb:it-ret bounds ?v| drop 0 |?
  1+ dup ssc-limit < ?^||
  else| drop 0 >> rdrop ;

|: ssc-up
  ssc-iidx ilendb:nth-last-len@ dup ssc-ilen:! ssc-caddr:-! ;

;; scan upwards, stop on stack swap or stack access/modify instruction.
;; return true if stopped on stack swap
|: scan-ssc-up  ( -- ok-flag )
  ssc-iidx:!0 code-here ssc-caddr:!
  ssc-calc-limit dup not?exit ssc-x-limit:!
\ endcr ." scan-limit: " ssc-x-limit . ." from $" code-here .hex8 cr
  <<
    ssc-up
    \ ssc-caddr bblock-start^ u>= not?exit&leave
    \ ssc-iidx ilendb:nth-last-type@ ilendb:it-sswap = ?exit&leave
    bad-instr?
\ dup ?< endcr ."   BAD AT $" ssc-caddr .hex8 cr >?
    not not?exit&leave
  ssc-iidx:1+! ssc-iidx ssc-x-limit < ?^||
  else| ssc-up true >> ;

|: swap-stacks
  last-instr-swap-stacks? ?exit< remove-last-stack-swap >?
  can-remove-last? not?exit< swap-stacks, >?
  did-any-align? ?exit< swap-stacks, >?
  scan-ssc-up ?exit<
\ endcr ." SSC: from $" code-here .hex8 ." , found at $" ssc-caddr .hex8
\       ."  iidx=" ssc-iidx . ." ilen=" ssc-ilen 0.r cr
    stat-useless-sswaps:1+!
\    ssc-ilen 6 = not?error" fuck0"
\    ssc-iidx ilendb:nth-last-type@ ilendb:it-sswap = not?error" fuck1"
    remove-current-instruction >?
  swap-stacks, ;

[ELSE]
|: swap-stacks
  last-instr-swap-stacks? ?< remove-last-stack-swap || swap-stacks, >? ;
[ENDIF]

: dstack>cpu
  stacks-swapped? not?< swap-stacks stacks-swapped?:!t >? ;

: restore-stacks
  stacks-swapped? ?< swap-stacks stacks-swapped?:!f >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; this is used internally in branch/ret generator
: finish-ret-bblock
  (finish-bblock-hook)
  code-here bblock-start^:! ;

;; this is used internally in branch/ret generator
: finish-branch-bblock
  (finish-bblock-hook)
  dstack>cpu ;

;; note that inliner can change "bblock-start^" directly.
;; this is done to block removing some required sswaps.
;; it is the only case when basic block can start with swapped stacks.
\ FIXME: this should be done some other way.
;; let's geterate an explicit stack swap. this may help for words
;; like ": a 0= ..." (for all words with "no-stack" primitives).
;; and it doesn't harm, because if we start the word from "CALL" or
;; something, stack swap optimiser will remove this useless thing.
;; used in forward mark, and backward resolve, because i need the proper address.
: finish-bblock-xjmp  ( -- jump-addr )
  dstack>cpu \ restore-stacks
  (finish-bblock-hook)
  code-here dup bblock-start^:!
  ( dstack>cpu) ;

: finish-bblock-xjmp-fwd  ( -- jump-addr )
  dstack>cpu
  (finish-bblock-hook)
  code-here dup bblock-start^:!
  ( dstack>cpu) ;

: finish-bblock
  restore-stacks
  (finish-bblock-hook)
  code-here bblock-start^:!
  dstack>cpu ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; compile call to CFA to the target image; use this for clarity (and for optims)
: (call)  ( cfa-xt )
  \ can-inline?:!f  ;; this is inline blocker for now
  ilendb:cg-begin
  ( call) $E8 code-db, branch-addr,
  ilendb:cg-end-jdisp ;

;; compile call to CFA to the target image; use this for clarity (and for optims)
: (jump)  ( cfa-xt )
  can-inline?:!f  ;; this is inline blocker for now
  ilendb:cg-begin
  ( jmp) $E9 code-db, branch-addr,
  ilendb:cg-end-jdisp ;

: emit-nops  ( count )
  dup 0> ?<
    ilendb:cg-begin
    << $90 code-db, 1- dup ?^|| else| >>
    ilendb:it-nop-align ilendb:cg-end-typed
  >? drop ;

: ret
  has-rets?:!t can-inline?:!f
  ilendb:cg-begin
  xasm:reset
    xasm:instr:ret,
  ilendb:cg-end-ret ;

|: jtiny  ( skip-tiny-jump-opc )
  ilendb:cg-begin
  code-dw,
  ilendb:cg-end-jdisp ;

;; compile "RET NZ"
: ret-nz
  \ 74 01     jz      <past-ret>
  \ C3        ret
  $01_74 jtiny
  ret ;

;; compile "RET Z"
: ret-z
  \ 75 01     jnz     <past-ret>
  \ C3        ret
  $01_75 jtiny
  ret ;


;; compile "RET NZ"
: ret-nz-sswap
  \ 74 01     jz      <past-ret>
  \ C3        ret
  stacks-swapped? not?exit< ret-nz >?
\ endcr ." RET-NZ-SSWAP at $" code-here .hex8 cr
  ilendb:sswap-len 256 * $01_74 + jtiny
  swap-stacks,
  ret ;

;; compile "RET Z"
: ret-z-sswap
  \ 75 01     jnz     <past-ret>
  \ C3        ret
  stacks-swapped? not?exit< ret-z >?
\ endcr ." RET-Z-SSWAP at $" code-here .hex8 cr
  ilendb:sswap-len 256 * $01_75 + jtiny
  swap-stacks,
  ret ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; minimalistic x86 asm
;; i need to parameterise instructions on the fly, so x86asm doesn't fit


: push-reg32  ( ridx )
  ilendb:cg-begin
  dup
  xasm:reset
    xasm:reg32 xasm:instr:push,
  << ebx of?v| ilendb:it-push-ebx |?
     eax of?v| ilendb:it-push-eax |?
  else| drop ilendb:it-normal >>
  ilendb:cg-end-typed ;

: pop-reg32  ( ridx )
  ilendb:cg-begin
  dup
  xasm:reset
    xasm:reg32 xasm:instr:pop,
  << ebx of?v| ilendb:it-pop-ebx |?
     eax of?v| ilendb:it-pop-eax |?
  else| drop ilendb:it-normal >>
  ilendb:cg-end-typed ;

: neg-reg32  ( ridx )
  ilendb:cg-begin
  xasm:reset
    xasm:reg32 xasm:instr:neg,
  ilendb:cg-end ;

: shl-ebx-n  ( count )
  dup not?exit< drop >?
  ilendb:cg-begin
  xasm:reset
    xasm:ebx dup 1- ?< xasm:, xasm:# || drop >?
    xasm:instr:shl,
  ilendb:cg-end ;

: shr-ebx-n  ( count )
  dup not?exit< drop >?
  ilendb:cg-begin
  xasm:reset
    xasm:ebx dup 1- ?< xasm:, xasm:# || drop >?
    xasm:instr:shr,
  ilendb:cg-end ;

: sar-ebx-n  ( count )
  dup not?exit< drop >?
  ilendb:cg-begin
  xasm:reset
    xasm:ebx dup 1- ?< xasm:, xasm:# || drop >?
    xasm:instr:sar,
  ilendb:cg-end ;

: shl-eax-n  ( count )
  dup not?exit< drop >?
  ilendb:cg-begin
  xasm:reset
    xasm:eax dup 1- ?< xasm:, xasm:# || drop >?
    xasm:instr:shl,
  ilendb:cg-end ;

: shr-eax-n  ( count )
  dup not?exit< drop >?
  ilendb:cg-begin
  xasm:reset
    xasm:eax dup 1- ?< xasm:, xasm:# || drop >?
    xasm:instr:shr,
  ilendb:cg-end ;

: sar-eax-n  ( count )
  dup not?exit< drop >?
  ilendb:cg-begin
  xasm:reset
    xasm:eax dup 1- ?< xasm:, xasm:# || drop >?
    xasm:instr:sar,
  ilendb:cg-end ;

: lea-esp-[esp+value]  ( value )
  dup not?exit< drop >?
  ilendb:cg-begin
  xasm:reset
    xasm:esp xasm:, xasm:[esp] xasm:[+] xasm:instr:lea,
  ilendb:cg-end ;

: lea-ebp-[ebp+value]  ( value )
  dup not?exit< drop >?
  ilendb:cg-begin
  xasm:reset
    xasm:ebp xasm:, xasm:[ebp] xasm:[+] xasm:instr:lea,
  ilendb:cg-end ;

: xor-reg32-reg32  ( ridx )
  ilendb:cg-begin
  xasm:reset
    dup xasm:reg32 xasm:, xasm:reg32 xasm:instr:xor,
  ilendb:cg-end ;

: inc-reg32  ( ridx )
  ilendb:cg-begin
  xasm:reset
    xasm:reg32 xasm:instr:inc,
  ilendb:cg-end ;

: dec-reg32  ( ridx )
  ilendb:cg-begin
  xasm:reset
    xasm:reg32 xasm:instr:dec,
  ilendb:cg-end ;

: reg32->reg32  ( rsrc rdest )
  2dup = ?exit< 2drop >?
  ilendb:cg-begin
  xasm:reset
    xasm:reg32 xasm:, xasm:reg32 xasm:instr:mov,
  ilendb:cg-end ;

;; use in inliner ONLY! to optimise literal loads
: mov-eax,ebx-inliner
  ilendb:cg-begin
  xasm:reset
    xasm:eax xasm:, xasm:ebx xasm:instr:mov,
  ilendb:it-mov-eax-ebx ilendb:cg-end-typed ;

;; xchg is FUCKIN' SLOW on fuckin shit86. yes, THAT slow.
: swap-eax,ebx-(use-edx)
  eax edx reg32->reg32
  ebx eax reg32->reg32
  edx ebx reg32->reg32 ;


: mov-eax,[esp+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:eax xasm:, xasm:[esp] xasm:[+] xasm:instr:mov,
  ilendb:cg-end ;

: mov-ebx,[esp+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[esp] xasm:[+] xasm:instr:mov,
  ilendb:cg-end ;

: mov-[esp+value],ebx  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[esp] xasm:[+] xasm:, xasm:ebx xasm:instr:mov,
  ilendb:cg-end ;

: add-ebx,[esp+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[esp] xasm:[+] xasm:instr:add,
  ilendb:cg-end ;

: push-value  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:# xasm:instr:push,
  ilendb:it-push-imm ilendb:cg-end-typed ;

: test-ebx,ebx
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:ebx xasm:instr:test,
  ilendb:cg-end ;

: load-reg32-value  ( value ridx )
  dup >r
  ilendb:cg-begin
  xasm:reset
  over ?<
    xasm:reg32 xasm:, xasm:# xasm:instr:mov,
  || ;; loading zero is better done with "xor reg32, reg32"
     dup xasm:reg32 xasm:, xasm:reg32 xasm:instr:xor,
     drop >?
  r> << ebx of?v| ilendb:it-#-load |?
        eax of?v| ilendb:it-#-load-eax |?
     else| drop ilendb:it-normal >>
  ilendb:cg-end-typed ;

|: xop-reg32,value  ( ridx value gen-cfa )
  ilendb:cg-begin
  xasm:reset
    rot xasm:reg32 xasm:, xasm:# execute
  ilendb:cg-end ;

: and-reg32,value  ( ridx value )
  ['] xasm:instr:and, xop-reg32,value ;

: or-reg32,value  ( ridx value )
  ['] xasm:instr:or, xop-reg32,value ;

: xor-reg32,value  ( ridx value )
  ['] xasm:instr:xor, xop-reg32,value ;

: cmp-reg32,value  ( ridx value )
  ['] xasm:instr:cmp, xop-reg32,value ;

: test-reg32,value  ( ridx value )
  ['] xasm:instr:test, xop-reg32,value ;

: cmp-ebx,value  ( value )
  ebx swap cmp-reg32,value ;

: cmp-ebx,#0
  ebx 0 cmp-reg32,value ;

: cmp-[addr]-value  ( addr value )
  ilendb:cg-begin
  xasm:reset
    swap xasm:[addr] xasm:, xasm:# xasm:instr:cmp,
  ilendb:cg-end ;

: cmp-eax-[addr]  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:eax xasm:, xasm:[addr] xasm:instr:cmp,
  ilendb:cg-end ;

: cmp-ebx-[addr]  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[addr] xasm:instr:cmp,
  ilendb:cg-end ;

: cmp-[esp+value],ebx  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[esp] xasm:[+] xasm:, xasm:ebx xasm:instr:cmp,
  ilendb:cg-end ;

\ : cmp-[ebp/esp+value],ebx  ( value reg )
\   ilendb:cg-begin
\   xasm:reset
\     xasm:[reg32] xasm:[+] xasm:, xasm:ebx xasm:instr:cmp,
\   ilendb:cg-end ;

: cmp-eax,[ebp/esp+value]  ( value reg )
  ilendb:cg-begin
  xasm:reset
    xasm:eax xasm:, xasm:[reg32] xasm:[+] xasm:instr:cmp,
  ilendb:cg-end ;

: cmp-[ebp/esp+value],value  ( disp reg value )
  ilendb:cg-begin
  xasm:reset
    nrot xasm:[reg32] xasm:[+] xasm:, xasm:# xasm:instr:cmp,
  ilendb:cg-end ;

: cmp-[ebp/esp+value],0  ( disp reg )
  0 cmp-[ebp/esp+value],value ;

: test-[esp+value],ebx  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[esp] xasm:[+] xasm:, xasm:ebx xasm:instr:test,
  ilendb:cg-end ;

: cmp-ebx,reg32  ( ridx )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:reg32 xasm:instr:cmp,
  ilendb:cg-end ;

: cmp-ebx,eax
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:eax xasm:instr:cmp,
  ilendb:cg-end ;

: cmp-eax,ebx
  ilendb:cg-begin
  xasm:reset
    xasm:eax xasm:, xasm:ebx xasm:instr:cmp,
  ilendb:cg-end ;

: store-[addr],ebx  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:[addr] xasm:, xasm:ebx xasm:instr:mov,
  ilendb:cg-end ;

: store-[addr],eax  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:[addr] xasm:, xasm:eax xasm:instr:mov,
  ilendb:cg-end ;

: load-eax-[addr]  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:eax xasm:, xasm:[addr] xasm:instr:mov,
  ilendb:cg-end ;

: load-ebx-[addr]  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[addr] xasm:instr:mov,
  ilendb:cg-end ;

: add-[addr]-ebx  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:[addr] xasm:, xasm:ebx xasm:instr:add,
  ilendb:cg-end ;

: sub-ebx-eax
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:eax xasm:instr:sub,
  ilendb:cg-end ;

: sub-[addr]-ebx  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:[addr] xasm:, xasm:ebx xasm:instr:sub,
  ilendb:cg-end ;

: store-[addr]-value  ( addr value )
  ilendb:cg-begin
  xasm:reset
    swap xasm:[addr] xasm:, xasm:# xasm:instr:mov,
  ilendb:cg-end ;

: inc-[addr]  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:[addr] xasm:instr:inc,
  ilendb:cg-end ;

: dec-[addr]  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:[addr] xasm:instr:dec,
  ilendb:cg-end ;

: (call-[addr])  ( addr )
  ilendb:cg-begin
  xasm:reset
    xasm:[addr] xasm:instr:call,
  ilendb:cg-end ;

: call-eax
  ilendb:cg-begin
  xasm:reset
    xasm:eax xasm:instr:call,
  ilendb:cg-end ;

: lea-ebx-[uv-addr]  ( uv-ofs )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[edi] xasm:[+] xasm:instr:lea,
  ilendb:cg-end ;

: load-ebx-[uv-addr]  ( uv-ofs )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[edi] xasm:[+] xasm:instr:mov,
  ilendb:cg-end ;

: store-[uv-addr]-ebx  ( uv-ofs )
  ilendb:cg-begin
  xasm:reset
    xasm:[edi] xasm:[+] xasm:, xasm:ebx xasm:instr:mov,
  ilendb:cg-end ;

: store-[uv-addr]-value  ( uv-ofs value )
  ilendb:cg-begin
  xasm:reset
    swap xasm:[edi] xasm:[+] xasm:, xasm:# xasm:instr:mov,
  ilendb:cg-end ;

: inc-[uv-addr]  ( uv-ofs )
  ilendb:cg-begin
  xasm:reset
    xasm:[edi] xasm:[+] xasm:instr:inc,
  ilendb:cg-end ;

: dec-[uv-addr]  ( uv-ofs )
  ilendb:cg-begin
  xasm:reset
    xasm:[edi] xasm:[+] xasm:instr:dec,
  ilendb:cg-end ;

: add-[addr]-value  ( addr value )
  ilendb:cg-begin
  xasm:reset
  << -1 of?v| xasm:[addr] xasm:instr:dec, |?
      1 of?v| xasm:[addr] xasm:instr:inc, |?
      0 of?v||
  else|
    swap xasm:[addr] xasm:, xasm:# xasm:instr:add, >>
  ilendb:cg-end ;

: sub-[addr]-value  ( addr value )
  ilendb:cg-begin
  xasm:reset
  << -1 of?v| xasm:[addr] xasm:instr:inc, |?
      1 of?v| xasm:[addr] xasm:instr:dec, |?
      0 of?v||
  else|
    swap xasm:[addr] xasm:, xasm:# xasm:instr:sub, >>
  ilendb:cg-end ;

: add-ebx-value  ( value )
  ilendb:cg-begin
  xasm:reset
  [ 1 ] [IF]
  << -1 of?v| xasm:ebx xasm:instr:dec, |?
      1 of?v| xasm:ebx xasm:instr:inc, |?
      0 of?v||
  else|
    xasm:ebx xasm:, xasm:# xasm:instr:add, >>
  [ELSE]
    xasm:ebx xasm:, xasm:# xasm:instr:add,
  [ENDIF]
  ilendb:cg-end ;

: add-eax-ebx
  ilendb:cg-begin
  xasm:reset
    xasm:eax xasm:, xasm:ebx xasm:instr:add,
  ilendb:cg-end ;

: reg32+=reg32  ( rdest rsrc )
  ilendb:cg-begin
  xasm:reset
    swap xasm:reg32 xasm:, xasm:reg32 xasm:instr:add,
  ilendb:cg-end ;

: reg32-=reg32  ( rdest rsrc )
  ilendb:cg-begin
  xasm:reset
    swap xasm:reg32 xasm:, xasm:reg32 xasm:instr:sub,
  ilendb:cg-end ;

: [ebx+value]+=eax  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:, xasm:eax xasm:instr:add,
  ilendb:cg-end ;

: [ebx+value]+=ax  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:, xasm:eax xasm:instr:add-w,
  ilendb:cg-end ;

: [ebx+value]+=al  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:, xasm:eax xasm:instr:add-b,
  ilendb:cg-end ;

: [ebx+value]-=eax  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:, xasm:eax xasm:instr:sub,
  ilendb:cg-end ;

: [ebx+value]-=ax  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:, xasm:eax xasm:instr:sub-w,
  ilendb:cg-end ;

: [ebx+value]-=al  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:, xasm:eax xasm:instr:sub-b,
  ilendb:cg-end ;

: inc-[ebx+value]  ( ofs )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:instr:inc,
  ilendb:cg-end ;

: dec-[ebx+value]  ( ofs )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:instr:dec,
  ilendb:cg-end ;

: [ebx+value]+=value  ( ofs value )
  << -1 of?v| dec-[ebx+value] |?
      1 of?v| inc-[ebx+value] |?
      0 of?v| drop |?
  else|
    ilendb:cg-begin
    xasm:reset
      swap xasm:[ebx] xasm:[+] xasm:, xasm:# xasm:instr:add,
    ilendb:cg-end >> ;

: [ebx+value]-=value  ( ofs value )
  << -1 of?v| inc-[ebx+value] |?
      1 of?v| dec-[ebx+value] |?
      0 of?v| drop |?
  else|
    ilendb:cg-begin
    xasm:reset
      swap xasm:[ebx] xasm:[+] xasm:, xasm:# xasm:instr:sub,
    ilendb:cg-end >> ;

: load-ebx-dd[ebx*4+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx*4] xasm:[+] xasm:instr:mov,
  ilendb:cg-end ;

: load-ebx-dd[ebx+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx] xasm:[+] xasm:instr:mov,
  ilendb:cg-end ;

: load-ebx-dw[ebx+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx] xasm:[+] xasm:instr:movzx-w,
  ilendb:cg-end ;

: load-ebx-db[ebx+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx] xasm:[+] xasm:instr:movzx-b,
  ilendb:cg-end ;

: store-[ebx+value]-eax  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:, xasm:eax xasm:instr:mov,
  ilendb:cg-end ;

: store-[ebx+value]-ax  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:, xasm:eax xasm:instr:mov-w,
  ilendb:cg-end ;

: store-[ebx+value]-al  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:[+] xasm:, xasm:al xasm:instr:mov-b,
  ilendb:cg-end ;

: store-[eax+value]-ebx  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[eax] xasm:[+] xasm:, xasm:ebx xasm:instr:mov,
  ilendb:cg-end ;

: store-[eax+value]-bx  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[eax] xasm:[+] xasm:, xasm:ebx xasm:instr:mov-w,
  ilendb:cg-end ;

: store-[eax+value]-bl  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[eax] xasm:[+] xasm:, xasm:bl xasm:instr:mov-b,
  ilendb:cg-end ;

: store-[ebp+disp]-value  ( disp value )
  ilendb:cg-begin
  xasm:reset
    swap xasm:[ebp] xasm:[+] xasm:, xasm:# xasm:instr:mov,
  ilendb:cg-end ;

: store-[ebp+disp]-ebx  ( disp )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebp] xasm:[+] xasm:, xasm:ebx xasm:instr:mov,
  ilendb:cg-end ;


: lea-ebx-[eax+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    dup not?< drop xasm:ebx xasm:, xasm:eax xasm:instr:mov,
    || xasm:ebx xasm:, xasm:[eax] xasm:[+] xasm:instr:lea, >?
  ilendb:cg-end ;

: lea-ebx-[eax*2+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[eax*2] xasm:[+] xasm:instr:lea,
  ilendb:cg-end ;

: lea-ebx-[eax*4+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[eax*4] xasm:[+] xasm:instr:lea,
  ilendb:cg-end ;

: lea-ebx-[ebx+eax*2]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[eax*2] xasm:instr:lea,
  ilendb:cg-end ;

: lea-ebx-[ebx+eax*4]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx] xasm:[eax*4] xasm:instr:lea,
  ilendb:cg-end ;


: load-ebx-db[ebx+eax*4]
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx] xasm:[eax*4] xasm:instr:movzx-b,
  ilendb:cg-end ;

: load-ebx-dw[ebx+eax*4]
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx] xasm:[eax*4] xasm:instr:movzx-w,
  ilendb:cg-end ;

: load-ebx-dd[ebx+eax*4]
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx] xasm:[eax*4] xasm:instr:mov,
  ilendb:cg-end ;


: div-reg32  ( ridx )
  ilendb:cg-begin
  xasm:reset
    xasm:reg32 xasm:instr:div,
  ilendb:cg-end ;


: lit-idiv  ( lit )
  ebx load-reg32-value
  ilendb:cg-begin xasm:reset
    xasm:instr:cdq,
    xasm:ebx xasm:instr:idiv,
    xasm:edx xasm:, xasm:edx xasm:instr:test,
    ;; jz
    \ $84_0F code-dw, 9 code-dd, ( -jdisp)
    $74 code-db, 5 code-db, ( -jdisp)
    xasm:ebx xasm:, xasm:edx xasm:instr:xor,
    ;; jns
    \ $89_0F code-dw, 1 code-dd, ( -jdisp)
    $79 code-db, 1 code-db, ( -jdisp)
      xasm:eax xasm:, xasm:instr:dec,
    xasm:ebx xasm:, xasm:eax xasm:instr:mov,
  ilendb:it-prim-idiv ilendb:cg-end-typed ;

: lit-imod  ( lit )
  ebx load-reg32-value
  ilendb:cg-begin xasm:reset
    xasm:instr:cdq,
    xasm:ebx xasm:instr:idiv,
    xasm:edx xasm:, xasm:edx xasm:instr:test,
    ;; jz
    \ $84_0F code-dw, 12 code-dd, ( -jdisp)
    $74 code-db, 8 code-db, ( -jdisp)
    xasm:ebx xasm:, xasm:edx xasm:instr:xor,
    ;; jns
    \ $89_0F code-dw, 4 code-dd, ( -jdisp)
    $79 code-db, 4 code-db, ( -jdisp)
      xasm:ebx xasm:, xasm:edx xasm:instr:xor,
      xasm:edx xasm:, xasm:ebx xasm:instr:add,
    xasm:ebx xasm:, xasm:edx xasm:instr:mov,
  ilendb:it-prim-imod ilendb:cg-end-typed ;

: lit-umod  ( lit )
  ebx load-reg32-value
  ilendb:cg-begin xasm:reset
    xasm:edx xasm:, xasm:edx xasm:instr:xor,
    xasm:ebx xasm:instr:div,
    xasm:ebx xasm:, xasm:edx xasm:instr:mov,
  ilendb:it-prim-imod ilendb:cg-end-typed ;

: gen-0max
  ilendb:cg-begin xasm:reset
    xasm:edx xasm:, xasm:ebx xasm:instr:mov,
    xasm:ebx xasm:, 31 xasm:# xasm:instr:sar,
    xasm:ebx xasm:instr:not,
    xasm:ebx xasm:, xasm:edx xasm:instr:and,
  ilendb:it-0max ilendb:cg-end-typed ;


: dec-[esp]
  ilendb:cg-begin
  xasm:reset
    xasm:[esp] xasm:instr:dec,
  ilendb:cg-end ;

: inc-[esp]
  ilendb:cg-begin
  xasm:reset
    xasm:[esp] xasm:instr:inc,
  ilendb:cg-end ;

: add-[esp]-value  ( value )
  << 0 of?v||
    -1 of?v| dec-[esp] |?
     1 of?v| inc-[esp] |?
  else|
    ilendb:cg-begin
    xasm:reset
      xasm:[esp] xasm:, xasm:# xasm:instr:add,
    ilendb:cg-end >> ;

: sub-[esp]-value  ( value )
  << 0 of?v||
    -1 of?v| inc-[esp] |?
     1 of?v| dec-[esp] |?
  else|
    ilendb:cg-begin
    xasm:reset
      xasm:[esp] xasm:, xasm:# xasm:instr:sub,
    ilendb:cg-end >> ;

: swap-eax-ebx-with-edx
  ilendb:cg-begin
  xasm:reset
    xasm:edx xasm:, xasm:eax xasm:instr:mov,
    xasm:eax xasm:, xasm:ebx xasm:instr:mov,
    xasm:ebx xasm:, xasm:edx xasm:instr:mov,
  ilendb:it-swap-eax-ebx ilendb:cg-end-typed ;

: store-[eax],ebx
  ilendb:cg-begin
  xasm:reset
    xasm:[eax] xasm:, xasm:ebx xasm:instr:mov,
  ilendb:cg-end ;

: store-[eax],value  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[eax] xasm:, xasm:# xasm:instr:mov,
  ilendb:cg-end ;

: store-[ebx],value  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx] xasm:, xasm:# xasm:instr:mov,
  ilendb:cg-end ;

: lea-ebx,[ebx*4+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx*4] xasm:[+] xasm:instr:lea,
  ilendb:cg-end ;

: lea-ebx,[eax*4+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[eax*4] xasm:[+] xasm:instr:lea,
  ilendb:cg-end ;

: mov-ebx,[ebx*4+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebx*4] xasm:[+] xasm:instr:mov,
  ilendb:cg-end ;

: mov-ebx,[eax*4+value]  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[eax*4] xasm:[+] xasm:instr:mov,
  ilendb:cg-end ;

: mov-[ebx*4+value],eax  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[ebx*4] xasm:[+] xasm:, xasm:eax xasm:instr:mov,
  ilendb:cg-end ;

: mov-[eax*4+value],ebx  ( value )
  ilendb:cg-begin
  xasm:reset
    xasm:[eax*4] xasm:[+] xasm:, xasm:ebx xasm:instr:mov,
  ilendb:cg-end ;

;; stacks must be swapped!
: rpush-value  ( value )
  -4 lea-ebp-[ebp+value]
  ilendb:cg-begin
  xasm:reset
    xasm:[ebp] xasm:, xasm:# xasm:instr:mov,
  ilendb:cg-end ;

;; stacks must be swapped!
: rpop-ebx
  ilendb:cg-begin
  xasm:reset
    xasm:ebx xasm:, xasm:[ebp] xasm:instr:mov,
  ilendb:cg-end
  4 lea-ebp-[ebp+value] ;

seal-module
end-module low (published)
