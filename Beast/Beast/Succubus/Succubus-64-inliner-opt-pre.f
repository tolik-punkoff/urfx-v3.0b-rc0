;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; inlining native words: stitching optimisers
;; directly included from "Succubus-60-inliner.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some stitching optimisers

false quan was-any-stitch-optim?

: was-stitch-optim
  was-any-stitch-optim?:!t
  stat-stitch-optim:1+! ;

|: removable-first-typed  ( type -- flag )
  can-remove-iword-first? not?< drop false
  || first-iw@ ilendb:iw-type = >? ;

|: removable-first-pop-eax?  ilendb:it-pop-eax removable-first-typed ;
|: removable-first-pop-ebx?  ilendb:it-pop-ebx removable-first-typed ;
|: removable-first-push-ebx? ilendb:it-push-ebx removable-first-typed ;

|: removable-first-2-bytes?  ( word -- flag )
  ;; complex commands are never 2 bytes long
  \ first-iw@ ilendb:iw-type ilendb:it-normal = not?exit< drop false >?
  can-remove-iword-first? not?< drop false
  || first-iw@ ilendb:iw-len 2 = not?< drop false
  || cci-start^ code-w@ = >? >? ;

|: removable-first-add-ebx-eax?  $D8_03 removable-first-2-bytes? ;

;; "mov ebx, [ebx]"?
|: removable-first-[ebx]-load?  $1B_8B removable-first-2-bytes? ;

;; "mov ebx, [eax]"?
|: removable-first-[ebx]-eax-load?  $03_89 removable-first-2-bytes? ;

;; get literal value from the last instruction.
;; all necessary checks should be done by the caller.
|: get-last-lit-value  ( -- value )
  ilendb:last-len@ 2 = ?< 0 || code-here 4- code-@ >? ;

|: last-len=  ( len -- flag )  ilendb:last-len@ = ;
|: last-type= ( type -- flag ) ilendb:last-type@ = ;

|: prev-len=  ( len -- flag )  ilendb:prev-last-len@ = ;
|: prev-type= ( type -- flag ) ilendb:prev-last-type@ = ;
|: prev-prev-type= ( type -- flag ) 2 ilendb:nth-last-type@ = ;

|: last-push-ebx?  ( -- flag)  ilendb:it-push-ebx last-type= ;
|: prev-push-ebx?  ( -- flag)  ilendb:it-push-ebx prev-type= ;

;; some words ends with "push eax", and iword starts with "pop eax"
: remove-end-push-eax-start-pop-eax
  cci-wlen not?exit
  ilendb:it-push-eax last-type= not?exit
  removable-first-pop-eax? not?exit
  low:can-remove-last? not?exit
\ endcr ." PUSH-EAX/POP-EAX OPTIM at $" code-here .hex8 ."  in " debug-.latest-name ."  from " debug-.current-cfa-name cr
  was-stitch-optim
  chop-first
  low:remove-last-unsafe ;

;; some words ends with "push ebx", and iword starts with "pop eax"
: remove-end-push-ebx-start-pop-eax
  cci-wlen not?exit
  last-push-ebx? not?exit
  removable-first-pop-eax? not?exit
  low:can-remove-last? not?exit
\ endcr ." PUSH-EBX/POP-EAX OPTIM at $" code-here .hex8 ."  in " debug-.latest-name ."  from " debug-.current-cfa-name cr
  was-stitch-optim
  chop-first
  low:remove-last-unsafe
  low:ebx low:eax low:reg32->reg32 ;

;; some words ends with "push [esp+4]", and iword starts with "pop eax" (2DUP ends with this).
;; replace with "mov" (or "add").
: remove-end-push-[esp+4]-start-pop-eax
  cci-wlen not?exit
  4 last-len= not?exit
  removable-first-pop-eax? not?exit
  low:can-remove-last? not?exit
  code-here 4- code-@ $04_24_74_FF - ?exit ;; push [esp+4]?
\ endcr ." [ESP+4] OPTIM at $" code-here .hex8 ."  in " debug-.latest-name ."  from " debug-.current-cfa-name cr
  was-stitch-optim
  chop-first
  low:remove-last-unsafe
  removable-first-add-ebx-eax? ?<
\ endcr ." ADD [ESP+4] OPTIM at $" code-here .hex8 ."  in " debug-.latest-name ."  from " debug-.current-cfa-name cr
     chop-first
     4 low:add-ebx,[esp+value]
  || 4 low:mov-eax,[esp+value] >? ;

|: (dw-opc-mov-ebx-mod-r/m?)  ( dw-opc -- flag )
  dup lo-byte $8B = ?< hi-byte &o070 and &o030 = || drop false >? ;

|: mov-ebx-mod-r/m?  ( code-addr -- flag )
  code-w@ (dw-opc-mov-ebx-mod-r/m?) ;

|: mov-ebx-anything?  ( code-addr -- flag )
  code-w@ dup lo-byte $BB = ?exit< drop true >?
  (dw-opc-mov-ebx-mod-r/m?) ;

;; last: "push ebx / mov ebx, # n (or xor ebx, ebx)"
;; iword: "pop eax"
;; drop iword pop, replace last with:
;;   mov eax, ebx / lit-load
;; WARNING! do not forget to fix instruction type!
: remove-end-push-ebx-mov-ebx-lit-start-pop-eax
  cci-wlen not?exit
  ilendb:it-#-load last-type= not?exit
  prev-push-ebx? not?exit
  removable-first-pop-eax? not?exit
  low:can-remove-last-2? not?exit
  get-last-lit-value
\ endcr ." PUSH-EBX/MOV-EBX,#LIT-POP-EAX OPTIM at $" code-here .hex8 ."  in " debug-.latest-name ."  from " debug-.current-cfa-name cr
  was-stitch-optim
  chop-first
  low:remove-last-unsafe low:remove-last-unsafe
  \ low:xchg-eax,ebx
  \ DO NOT USE XCHG! NEVER EVER! replacing it with "mov eax, ebx"
  \ cut ~30 msecs on benchmark, and ~4 msecs on rebuilds. wutafuck?!
  low:mov-eax,ebx-inliner -- this marks it as special
  low:ebx low:load-reg32-value ;

;; last: "push ebx / mov ebx, eax"
;; iword: "pop eax"
;; replace:
;;   mov  edx, eax
;;   mov  eax, ebx
;;   mov  ebx, edx
: remove-end-push-ebx-mov-ebx-eax-start-pop-eax
  cci-wlen not?exit
  2 last-len= not?exit
  prev-push-ebx? not?exit
  removable-first-pop-eax? not?exit
  low:can-remove-last-2? not?exit
  code-here 2- code-w@ $D8_8B = not?exit
\ endcr ." SWAP-EBX-EAX OPTIM at $" code-here .hex8 ."  in " debug-.latest-name ."  from " debug-.current-cfa-name cr
  was-stitch-optim
  chop-first
  low:remove-last-unsafe low:remove-last-unsafe
  low:swap-eax-ebx-with-edx ;

|: last-add-ebx-eax?  ( -- flag )
  2 last-len= not?exit&leave
  low:can-remove-last? not?exit&leave
  code-here 2- code-w@ $D8_03 = ;

create icmd-buf 16 allot create; (private)
\ 16 mk-buffer icmd-buf
0 quan #icmd-buf (private)

|: mod-r/m-sib-[esp]?     ( code-addr -- flag )  code-w@ $24_1C = ;
|: mod-r/m-sib-[esp+n8]?  ( code-addr -- flag )  code-w@ $24_5C = ;
|: mod-r/m-sib-[esp+n32]? ( code-addr -- flag )  code-w@ $24_9C = ;

|: last-mov-r/m-[espx]?  ( code-addr -- flag )
  1+ code-w@  ;; mod-reg-r/m and SIB
   dup $24_1C =
  over $24_5C = or
  swap $24_9C = or ;

;; mov xxx, [esp] (or vice versa) (maybe [+disp])?
|: last-mov-any-[espx]?  ( -- flag )
  code-here ilendb:last-len@ -
  dup code-c@ ( code-addr opc-byte )
  dup $88 $8B bounds ?exit< drop last-mov-r/m-[espx]? >?
  $C6 $C7 bounds ?exit<
    dup 1+ code-c@ &o070 and ?exit< drop false >? ;; only rrr=0
    last-mov-r/m-[espx]? >?
  drop false ;

|: save-instr-simple  ( code-addr len )
  #icmd-buf:!0
  swap << dup code-c@ #icmd-buf icmd-buf db-nth c!
          #icmd-buf:1+! 1+ 1 under- over ?^|| else| 2drop >> ;

;; copy, but fix "[esp+disp]" to "[esp+disp-4]".
;; we can rely on disp value fitting into byte (due to codegen and primitive coding style).
|: save-fixed-mov-ebx-instr  ( code-addr len )
  ;; check for "[esp+n8]"
  over 1+ mod-r/m-sib-[esp+n8]? ?exit<
    4 - ?error" Succubus is puzzled with \'[esp+n8]\'"
    code-@ dup hi-word hi-byte not?error" Succubus is puzzled with \'[esp+n8#0]\'"
    $0400_0000 - dup $00_24_5C_8B =
    ?< drop $00_24_1C_8B  3 || 4 >? #icmd-buf:! icmd-buf ! >?
  ;; check for "[esp+n32]"
  over 1+ mod-r/m-sib-[esp+n32]? ?exit<
    7 - ?error" Succubus is puzzled with \'[esp+n32]\'"
    3 + code-@ dup not?error" Succubus is puzzled with \'[esp+n32#0]\'"
    $8B icmd-buf c! $24_9C icmd-buf 1+ w!
    4- icmd-buf 3 + !  7 #icmd-buf:! >?
  ;; copy as is
  save-instr-simple ;

|: emit-saved-instr-with-type  ( type )
  ilendb:cg-begin
  #icmd-buf icmd-buf << c@++ code-db, 1 under- over ?^|| else| 2drop >>
  ilendb:cg-end-typed ;

|: emit-saved-instr  ilendb:it-normal emit-saved-instr-with-type ;

;; last: "push ebx / mov ebx, mod-r/m"
;; iword: "pop eax"
;; drop iword pop, replace last with:
;;   mov eax, ebx / copy of ebx move
;; WARNING! do not forget to fix instruction type!
;; this MUST be called after "remove-end-push-ebx-mov-ebx-eax-start-pop-eax"!
: remove-end-push-ebx-mov-ebx-mod-r/m-start-pop-eax
  cci-wlen not?exit
  ilendb:last-len@ 2 >= not?exit
  ilendb:last-type@ ilendb:it-normal = not?exit
  prev-push-ebx? not?exit
  removable-first-pop-eax? not?exit
  code-here ilendb:last-len@ - dup ilendb:prev-last-len@ - bblock-start^ u>= not?exit< drop >?
  dup mov-ebx-mod-r/m? not?exit< drop >?
  dup 1+ mod-r/m-sib-[esp]? ?exit< drop >?  ;; something strange
  ;; save "mov ebx, smth", we need to emit it exactly as it is (almost)
  ilendb:last-len@ save-fixed-mov-ebx-instr
\ endcr ." PUSH-EBX/MOV-EBX,MOD-R/M OPTIM at $" code-here .hex8 cr
(*
endcr ." PUSH-EBX/MOV-EBX,MOD-R/M OPTIM at $" code-here .hex8 ."  in " debug-.latest-name ."  from " debug-.current-cfa-name cr
      ."   INSTR: $" code-here ilendb:last-len@ - @ .hex8
      ."  ILEN=" ilendb:last-len@ 0.r cr
*)
  was-stitch-optim
  chop-first
  low:remove-last-unsafe low:remove-last-unsafe
  ;; replace "add ebx, eax / mov eax, ebx" with "add eax, ebx"
  \ FIXME: nope, this conflicts with other optimisers: eax value could be used later
  \ low:xchg-eax,ebx
  \ DO NOT USE XCHG! NEVER EVER! replacing it with "mov eax, ebx"
  \ cut ~30 msecs on benchmark, and ~4 msecs on rebuilds. wutafuck?!
  low:mov-eax,ebx-inliner -- this marks it as special
\ endcr ." copying " #icmd-buf . ." bytes to $" code-here .hex8 cr
  emit-saved-instr ;


;; optimise "swap drop" to "nip".
;; " push ebx / mov ebx, eax / pop ebx" -> remove "mov".
;; don't bother remove push/pop, they will be removed by another optimiser.
: remove-end-push-ebx-mov-ebx-start-pop-ebx
  cci-wlen not?exit
  removable-first-pop-ebx? not?exit
  low:can-remove-last? not?exit
  first-iw@ ilendb:iw-type ilendb:it-normal = not?exit
  code-here ilendb:last-len@ dup 2 < ?exit< 2drop >? -
  mov-ebx-anything? not?exit
  was-stitch-optim
  low:remove-last-unsafe ;

: remove-end-push-ebx-start-pop-ebx
  cci-wlen not?exit
  removable-first-pop-ebx? not?exit
  last-push-ebx? not?exit
  low:can-remove-last? not?exit
  was-stitch-optim
  chop-first
  low:remove-last-unsafe ;

|: first-mov-ebx-any?  ( -- flag )
  can-remove-iword-first? not?exit&leave
  first-iw@ ilendb:iw-type ilendb:it-normal = not?exit&leave
  first-iw@ ilendb:iw-len 2 >= not?exit&leave
\  cci-start^ code-@ $FF_FF_FF and $24_5C_8B = \ ?exit&leave
\    ?< cci-start^ mov-ebx-anything? not?error" SHIT!" >?
  cci-start^ mov-ebx-anything? ;

|: first-mov-ebx-any-no-r/m-ebx?  ( -- flag )
  first-mov-ebx-any? not?exit&leave
  cci-start^ code-w@
  dup lo-byte $8B = not?exit< drop true >?
  hi-byte &o007 and dup 3 = ?exit< drop false >? ;; r/m is 3
  4 <> ?exit&leave  ;; no sib
  cci-start^ 3 + code-c@  ;; sib byte
  dup &o007 and 3 = swap &o070 and &o030 = or not ;

: remove-end-pop-ebx-start-push-ebx
  cci-wlen not?exit
  removable-first-push-ebx? not?exit
  ilendb:it-pop-ebx last-type= not?exit
  low:can-remove-last? not?exit
  was-stitch-optim
  chop-first
  low:remove-last-unsafe
  ;; "over" may generate "mov ebx, [esp] / mov ebx, [esp+4]"
\  first-mov-ebx-any? ?exit< endcr ." OPTIM-OVER at $" code-here .hex8 cr >?
  first-mov-ebx-any-no-r/m-ebx? ?exit \ < endcr ." OPTIM-OVER at $" code-here .hex8 cr >?
  0 low:mov-ebx,[esp+value] ;

;; "mov ebx, # lit / mov ebx, [ebx]".
;; this does almost nothing on normal code, but allows using "#, \\ @" in quans.
: remove-end-lit-load-start-[ebx]-load
  cci-wlen not?exit
  ilendb:it-#-load last-type= not?exit
  removable-first-[ebx]-load? not?exit
  low:can-remove-last? not?exit
  get-last-lit-value
\ endcr ." (#@) OPTIM at $" code-here .hex8 ."  in " debug-.latest-name ."  from " debug-.current-cfa-name cr
  was-stitch-optim
  chop-first
  low:remove-last-unsafe
  low:load-ebx-[addr] ;


|: last-any-pop?  ( -- flag )
  code-here ilendb:last-len@ -
  code-c@ dup $8F = swap $58 $5F bounds or ;

|: last-any-push?  ( -- flag )
  code-here ilendb:last-len@ -
  code-c@ dup $50 $57 bounds ?exit< drop true >?
  dup $6A = over $68 = or ?exit< drop true >?
  $FF = not?exit&leave
  code-here ilendb:last-len@ - 1+ code-c@ ;; mod-reg-r/m
  &o070 and &o060 = ;

|: load-prev-push-imm-value  ( -- value )
  code-here ilendb:last-len@ - ilendb:prev-last-len@ -
  dup 1+ swap code-c@ $6A = ?< code-c@ c>s || code-@ >? ;

;; and more for quans:
;; " push # lit / anything-except-push-pop / pop eax (from iword)"
;; replace with: "mov eax, # lit / anything-except-pop"
: remove-end-push-lit-nonpop-start-pop-eax
  cci-wlen not?exit
  removable-first-pop-eax? not?exit
  ilendb:it-push-imm prev-type= not?exit
  ilendb:last-type@ ilendb:it-nop-align >= ?exit
  last-any-pop? ?exit
  last-any-push? ?exit
  last-mov-any-[espx]? ?exit
  low:can-remove-last-2? not?exit
  ilendb:last-type@
  ( type )
  load-prev-push-imm-value
  ( type value )
  ilendb:last-len@ code-here over - swap save-instr-simple
  was-stitch-optim
  chop-first
  low:remove-last-unsafe low:remove-last-unsafe
  low:eax low:load-reg32-value
  emit-saved-instr-with-type ;


;; optimise "lit under+" and "lit under-".
;; other oprimisers will turn it into:
;;  "mov eax, ebx / mov ebx, lit / add|sub [esp], ebx / mov ebx, eax".
;; it can be replaced with "add|sub [esp], imm"
: pre-optim-add/sub-under
  cci-wlen 5 >= not?exit
  ilendb:it-#-load last-type= not?exit
  2 prev-len= not?exit
  low:can-remove-last-2? not?exit
  code-here ilendb:last-len@ - 2- code-w@ $C3_8B = not?exit
  lowest-jump cci-start^ 5 + u>= not?exit
  ;; don't bother checking instruction length, check bytes
  cci-start^ code-@ <<
    $8B_24_1C_01 of?v|  1 |?
    $8B_24_1C_29 of?v| -1 |?
  else| drop exit >> ( add-sign )
  cci-start^ 4+ code-c@ $D8 = not?exit< drop >?
\ endcr ." PREOPTIM-UNDER at $" code-here .hex8 ."  dir: " dup 0.r cr
  was-stitch-optim
  chop-first chop-first
  get-last-lit-value
\ endcr ."  value=" dup 0.r cr
  low:remove-last-unsafe low:remove-last-unsafe
  swap -?< low:sub-[esp]-value || low:add-[esp]-value >? ;


;; optimise "swap !". it will start with "it-swap-eax-ebx" followed by "mov [ebx], eax",
;; and then by "pop ebx".
;; replace with "mov [eax], ebx / pop ebx".
: pre-optim-swap-store
  cci-wlen 3 >= not?exit
  ilendb:it-swap-eax-ebx last-type= not?exit
  removable-first-[ebx]-eax-load? not?exit
  lowest-jump cci-start^ 3 + u>= not?exit
  cci-start^ code-@ $FF_FF_FF and $5B_03_89 = not?exit
\ endcr ." PREOPTIM-SWAP-STORE at $" code-here .hex8 cr
  was-stitch-optim
  chop-first
  low:remove-last-unsafe
  ilendb:it-#-load last-type= low:can-remove-last? and ?exit<
    ;; "mov ebx, lit" -- safe to remove, because store follows by "pop ebx"
    ;; seen only 2 times, but why not?
    get-last-lit-value
    low:remove-last-unsafe
    ilendb:it-mov-eax-ebx last-type= low:can-remove-last? and ?exit<
\ endcr ." PREOPTIM-SWAP-STORE-XXX at $" code-here .hex8 cr
      low:remove-last-unsafe
      low:store-[ebx],value >?
    low:store-[eax],value >?
  low:store-[eax],ebx ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lit lshift / lit rshift / lit arshift

enum{
  def: pre-optim-shl
  def: pre-optim-shr
  def: pre-optim-sar
}

(* JOAAT
53                                  push    ebx
C1 EB 06                            shr     ebx, 6
===
58                                  pop     eax
rewrite to:
  mov eax, ebx
  shift
*)
: pre-optim-end-push-ebx-lit-shift-start-pop-eax
  removable-first-pop-eax? not?exit
  3 last-len= not?exit
  ilendb:it-push-ebx prev-type= not?exit
  low:can-remove-last-2? not?exit
  code-here 3 - code-w@ <<
    $E3_C1 of?v| pre-optim-shl |?
    $EB_C1 of?v| pre-optim-shr |?
    $FB_C1 of?v| pre-optim-sar |?
  else| drop exit >>
  code-here 1- code-c@
  ( type amount )
  was-stitch-optim
  chop-first
  low:remove-last-unsafe
  low:remove-last-unsafe
\ endcr ." OPTIM-PUSH-LIT-SHIFT-POP at $" code-here .hex8 ."  shift=" dup 0.r cr
  low:ebx low:eax low:reg32->reg32
  swap <<
    pre-optim-shl of?v| low:shl-ebx-n |?
    pre-optim-shr of?v| low:shr-ebx-n |?
    pre-optim-sar of?v| low:sar-ebx-n |?
  else| error" Succubus cannot shift the bed like this" >> ;


;; >r r@
;; "mov [ebp], ebx / mov ebx, [ebp]"
: pre-optim-end-mov-[ebp],ebx-start-mov-ebx,[ebp]
  ilendb:it-prim-rpush last-type= not?exit
  cci-wlen 3 >= not?exit
  can-remove-iword-first? not?exit
  ;; "mov [ebp], ebx"?
  code-here 3 - code-@ $00_FF_FF_FF and $00_00_5D_89 = not?exit
  ;; "mov ebx, [ebp]"?
  cci-start^ code-@ $00_FF_FF_FF and $00_00_5D_8B = not?exit
\ endcr ." PREOPTIM-RPUSH-RPEEK at $" code-here .hex8 cr
  was-stitch-optim
  chop-first ;

(*
0045A054 8B C3                               mov     eax, ebx
0045A056 BB 02 00 00 00                      mov     ebx, 2
---
0045A05B 3B C3                               cmp     eax, ebx
0045A05D 0F 9C C3                            setl    bl
0045A060 0F B6 DB                            movzx   ebx, bl
0045A063 F7 DB                               neg     ebx
*)

0 quan (pr-opt-lcmp-cond)

;; we cannot optimise this in the normal way,
;; because it interferes with branch optimiser.
: pre-optim-lit-cmp
  low:stacks-swapped? not?exit
  2 last-len= not?exit
  3 prev-len= not?exit
  2 ilendb:nth-last-len@ 3 = not?exit
  3 ilendb:nth-last-len@ 2 = not?exit
  4 ilendb:nth-last-type@ ilendb:it-#-load = not?exit
  low:can-remove-last-5? not?exit
  code-here 10 - code-@ $F0_FF_FF_FF and $90_0F_C3_3B = not?exit
  code-here 6 - code-@ $DB_B6_0F_C3 = not?exit
  code-here 2 - code-w@ $DB_F7 = not?exit
  code-here 7 - code-c@ $90 - dup 15 u> ?exit< drop >? (pr-opt-lcmp-cond):!
\ endcr ." 000: PRE-LIT-< at $" code-here .hex8 cr
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  low:remove-last-unsafe low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  ilendb:it-mov-eax-ebx last-type= low:can-remove-last? and ?<
    low:remove-last-unsafe low:ebx
  || low:eax >?
\ endcr ." 001: PRE-LIT-< at $" code-here .hex8 cr
  swap low:cmp-reg32,value
  ;; FIXME: add this to low!
  ilendb:cg-begin xasm:reset
    xasm:bl ( xasm:cond:l) (pr-opt-lcmp-cond) xasm:instr:set-b,
    ilendb:cg-end
  ilendb:cg-begin xasm:reset
    xasm:ebx xasm:, xasm:bl xasm:instr:movzx-b,
    ilendb:cg-end
  ilendb:cg-begin xasm:reset
    xasm:ebx xasm:instr:neg,
    ilendb:cg-end
;
