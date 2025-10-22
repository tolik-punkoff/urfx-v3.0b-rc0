;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Succubus
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimising x86 native code compiler
;; inlining native words: post-stitching optimisers
;; directly included from "Succubus-60-inliner.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


|: last-removable-mov-eax-ebx?  ( -- flag )
  2 last-len= not?exit&leave
  code-here 2- code-w@ $C3_8B = not?exit&leave
  low:can-remove-last? ;

(*
|: last-removable-mov-ebx-eax?  ( -- flag )
  2 last-len= not?exit&leave
  code-here 2- code-w@ $D8_8B = not?exit&leave
  low:can-remove-last? ;
*)

|: last-removable-mov-eax-lit?  ( -- value TRUE // FALSE )
  5 last-len= not?exit&leave
  code-here 5 - code-c@ $B8 = not?exit&leave
  low:can-remove-last? not?exit&leave
  code-here 4- code-@ true ;

|: last-removable-mov-ebx-lit?  ( -- value TRUE // FALSE )
  ilendb:it-#-load last-type= not?exit&leave
  low:can-remove-last? not?exit&leave
  5 last-len= ?< code-here 4- code-@ || 0 >? true ;

;; optimise "mov ebx, lit / mov [ebx], eax / pop ebx"
;; replace with: "mov [lit], eax / pop ebx"
: optim-addr-store
  ilendb:it-pop-ebx last-type= not?exit
  2 prev-len= not?exit
  2 ilendb:nth-last-type@ ilendb:it-#-load = not?exit
  code-here 3 - code-w@ $03_89 = not?exit  ;; mov  [ebx], eax
  low:can-remove-last-3? not?exit
\ endcr ." OPTIM-LIT-STORE at $" code-here .hex8 cr
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  true >r ( value | gen-pop-tos? )
  ;; "mov eax, ebx / mov [lit], eax" -> "mov [lit], ebx".
  ;; it should be safe, because this is the optimisation we just made in the inliner itself.
  ;; also, "mov eax, lit / mov [ebx], eax" -- it is done by the inliner too.
  last-removable-mov-eax-ebx? ?<
    low:remove-last-unsafe
    low:last-removable-push-tos? ?< low:remove-last-unsafe 0 r! >?
    low:store-[addr],ebx
  || last-removable-mov-eax-lit? ?<
    low:remove-last-unsafe
    low:last-removable-push-tos? ?< low:remove-last-unsafe 0 r! >?
    low:store-[addr]-value
  || low:store-[addr],eax >? >?
  r> ?< low:ebx low:pop-reg32 >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; the following (rstack) optimiser is almost never used, i believe.
;; i.e. 2 hits in Succubus, 3 hits in current PARASITE. dunno.

|: remove-last-push-imm?  ( -- imm-value TRUE // FALSE )
  ilendb:it-push-imm last-type= not?exit&leave
  low:can-remove-last? not?exit&leave
  code-here 2 last-len= ?< 1- code-c@ c>s || 4- code-@ >?
  low:remove-last-unsafe true ;


;; special case: "push ebx / mov [ebp+n], ebx / pop ebx" (dup r!).
;; "pop" and prev-len already checked.
|: (optim-rstack-dup-store)
  2 ilendb:nth-last-type@ ilendb:it-push-ebx = not?exit
  code-here 4-
  dup 1- bblock-start^ u>= not?exit< drop >?
  code-@
  dup lo-word $5D_89 = not?exit< drop >?
  hi-word lo-byte ;; disp
  dup 128 < not?error" Succubus kicked out negative guest"
  ( disp )
  was-stitch-optim
  low:remove-last-unsafe
  low:remove-last-unsafe
  low:remove-last-unsafe
\ endcr ." RSTACK-SIMPLIFY-LIT at $" code-here .hex8 ."  disp=" dup 0.r cr
  low:store-[ebp+disp]-ebx ;


;; optimise "( push ebx) / mov ebx, lit / mov [ebp+n], ebx / pop ebx"
;; replace with: "mov [ebp+n], lit"
: optim-rstack-store
  ilendb:it-pop-ebx last-type= not?exit
  ;; consider only 8-bit disps, because this is what R primitives are using
  3 prev-len= not?exit
  2 ilendb:nth-last-type@ ilendb:it-#-load = not?exit< (optim-rstack-dup-store) >?
  code-here 4-
  dup bblock-start^ u>= not?exit< drop >?
  code-@
  dup lo-word $5D_89 = not?exit< drop >?
  hi-word lo-byte ;; disp
  dup 128 < not?error" Succubus kicked out negative guest"
  ( disp )
\ endcr ." RSTACK-STORE-LIT at $" code-here 4 - .hex8 ."  disp=" 0.r cr exit
  was-stitch-optim
  low:remove-last-unsafe
  low:remove-last-unsafe
  get-last-lit-value
  low:remove-last-unsafe
  ( disp value )
  low:last-removable-push-tos? dup ?< low:remove-last-unsafe
  || ;; push imm can be replaced with literal load, pop tos dropped
     remove-last-push-imm? ?< low:ebx low:load-reg32-value drop true >?
  >?
\ endcr ." RSTACK-STORE-LIT at $" code-here .hex8 ." : skip-pop=" dup . ." value=" over . ." disp=" >r over 0.r r> cr
  ( disp value skip-pop-tos? )
  nrot low:store-[ebp+disp]-value
  not?< low:ebx low:pop-reg32 >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lit >r

: optim-rstack-push-lit
  ilendb:it-pop-ebx last-type= not?exit
  ilendb:it-prim-rpush prev-type= not?exit
  ilendb:it-#-load prev-prev-type= not?exit
  low:can-remove-last-3? not?exit
  was-stitch-optim
  low:remove-last-unsafe
  low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
\ endcr ." OPTIM-RPUSH-LIT at $" code-here .hex8 ."  value=" dup 0.r cr
  low:rpush-value
  low:ebx low:pop-reg32 ;


;; " mov ebx, [esp] / rpop "
;; remove "mov"
: optim-load-[esp]-rstack-pop
  ilendb:it-prim-rpop last-type= not?exit
  3 prev-len= not?exit
  code-here ilendb:last-len@ - 3 - code-@ $FF_FF_FF and $24_1C_8B = not?exit
  low:can-remove-last-2? not?exit
  was-stitch-optim
  low:remove-last-unsafe
  low:remove-last-unsafe
\ endcr ." OPTIM-[ESP]-RPOP at $" code-here .hex8 cr
  low:rpop-ebx ;

: optim-rstack-pop-drop
  ilendb:it-pop-ebx last-type= not?exit
  ilendb:it-prim-rpop prev-type= not?exit
  ilendb:it-push-ebx prev-prev-type= not?exit
  low:can-remove-last-3? not?exit
  was-stitch-optim
  low:remove-last-unsafe
  low:remove-last-unsafe
  low:remove-last-unsafe
\ endcr ." OPTIM-RPOP-DROP at $" code-here .hex8 cr
  4 low:lea-ebp-[ebp+value] ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; fold add/sub

: optim-add-lit-fold
  2 last-len= not?exit
  ilendb:it-#-load prev-type= not?exit
  low:can-remove-last-2? not?exit
  code-here 2- code-w@ $D8_03 = not?exit ;; add ebx, eax
  was-stitch-optim
  low:remove-last-unsafe
  get-last-lit-value
  low:remove-last-unsafe
  ( value )
  last-removable-mov-eax-lit? ?exit<
    low:remove-last-unsafe
\ endcr ." ADD-OPTIM-LIT-EAX: " over . ." + " dup . ." at $" code-here .hex8 cr
    + low:ebx low:load-reg32-value >?
  last-removable-mov-ebx-lit? ?exit<
    low:remove-last-unsafe
\ endcr ." ADD-OPTIM-LIT-EBX: " over . ." + " dup . ." at $" code-here .hex8 cr
    + low:ebx low:load-reg32-value >?
  ;; it is ok, because "add" flags are never used by the codegen (yet).
  last-removable-mov-eax-ebx? not?exit<
\ endcr ." ADD-OPTIM-LEA: n + " dup . ." at $" code-here .hex8 cr
    dup not?exit< drop >?
    low:lea-ebx-[eax+value] >?
  low:remove-last-unsafe
\ endcr ." ADD-OPTIM-ADD: n + " dup . ." at $" code-here .hex8 cr
  dup not?exit< drop >?
  low:add-ebx-value ;

: optim-sub-lit-fold
  2 last-len= not?exit
  2 prev-len= not?exit
  2 ilendb:nth-last-type@ ilendb:it-#-load = not?exit
  low:can-remove-last-3? not?exit
  code-here 4- code-@ $D8_03_DB_F7 = not?exit
  was-stitch-optim
  low:remove-last-unsafe
  low:remove-last-unsafe
  get-last-lit-value
  low:remove-last-unsafe
  ( value )
  last-removable-mov-eax-lit? ?exit<
    low:remove-last-unsafe
\ endcr ." SUB-OPTIM-LIT: " over . ." - " dup . ." at $" code-here .hex8 cr
    swap - low:ebx low:load-reg32-value >?
  last-removable-mov-ebx-lit? ?exit<
    low:remove-last-unsafe
\ endcr ." SUB-OPTIM-LIT: " over . ." - " dup . ." at $" code-here .hex8 cr
    swap - low:ebx low:load-reg32-value >?
  ;; it is ok, because "sub" flags are never used by the codegen (yet).
  last-removable-mov-eax-ebx? not?exit< drop >?
  low:remove-last-unsafe
\ endcr ." SUB-OPTIM-SUB: n - " dup . ." at $" code-here .hex8 cr
  dup not?exit< drop >?
  \ low:sub-ebx-value ;
  negate low:add-ebx-value ;

;; "lit swap -"?
|: optim-swap-sub-lits?  ( -- flag )
  ilendb:it-#-load last-type= not?exit&leave
  low:can-remove-last-2? not?exit&leave
  ilendb:it-mov-eax-ebx prev-type= ?exit<
    get-last-lit-value
    low:remove-last-unsafe low:remove-last-unsafe
\ endcr ." OPTIM-SWAP-SUB-LIT-X at $" code-here .hex8 ."  value=" dup 0.r cr
    low:ebx low:neg-reg32
    low:add-ebx-value
    true >?
  ilendb:it-#-load-eax prev-type= ?exit<
    get-last-lit-value low:remove-last-unsafe
    get-last-lit-value low:remove-last-unsafe
\ endcr ." OPTIM-SWAP-SUB-LIT-2 at $" code-here .hex8 ."  eax=" dup . ." ebx=" over 0.r cr
    - low:ebx low:load-reg32-value
    true >?
  false ;

: optim-swap-sub
  2 last-len= not?exit
  2 prev-len= not?exit
  2 ilendb:nth-last-type@ ilendb:it-swap-eax-ebx = not?exit
  low:can-remove-last-3? not?exit
  code-here 4- code-@ $D8_03_DB_F7 = not?exit
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe low:remove-last-unsafe
  optim-swap-sub-lits? ?exit
\ endcr ." OPTIM-SWAP-SUB-LIT at $" code-here .hex8 cr
  low:sub-ebx-eax ;


|: add-ebx-lit-at?  ( code-here -- value TRUE // FALSE )
  dup code-w@ <<
    $C3_81 of?v| 2+ code-@ true |?
    $C3_83 of?v| 2+ code-c@ c>s true |?
  else| 2drop false >> ;

|: prev-add-ebx-lit?  ( -- value TRUE // FALSE )
  ilendb:prev-last-len@ dup not?exit
  ilendb:last-len@ + code-here swap - add-ebx-lit-at? ;

: optim-add-lit-inc/dec
  1 last-len= not?exit
  code-here 1- code-c@ dup $43 = ?< drop 1 || $4B = not?exit -1 >?
  prev-add-ebx-lit? not?exit< drop >?
  + ( new-value )
  low:can-remove-last-2? not?exit< drop >?
\ endcr ." XXOPT-ADD at $" code-here .hex8 cr
  was-stitch-optim
  low:remove-last-unsafe
  low:remove-last-unsafe
  low:add-ebx-value ;


|: last-add-ebx-lit?  ( -- value TRUE // FALSE )
  ilendb:last-len@ dup 6 = ?exit< drop
    code-here 6 - dup code-w@ $C3_81 = not?exit< drop false >?
    2+ code-@ true >?
  3 = not?exit&leave
  code-here 3 - dup code-w@ $C3_83 = not?exit< drop false >?
  2+ code-c@ c>s true ;

: optim-add-lit-add-lit
  last-add-ebx-lit? not?exit
  prev-add-ebx-lit? not?exit< drop >?
  + ( new-value )
  low:can-remove-last-2? not?exit< drop >?
\ endcr ." XXOPT-ADD-ADD at $" code-here .hex8 cr
  was-stitch-optim
  low:remove-last-unsafe
  low:remove-last-unsafe
  low:add-ebx-value ;

: optim-mov-lit-add-lit
  ilendb:it-#-load prev-type= not?exit
  last-add-ebx-lit? not?exit
  low:can-remove-last-2? not?exit< drop >?
  ( add-value )
\ endcr ." XXOPT-MOV-ADD at $" code-here .hex8 cr
  was-stitch-optim
  low:remove-last-unsafe
  get-last-lit-value +
  low:remove-last-unsafe
  low:ebx low:load-reg32-value ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimise "lit + @" and "lit + !"
;; this is used in fields

0 quan opt-laload-size (private)

|: optim-last-load-type  ( -- size TRUE // FALSE )
  ilendb:last-len@ dup 2 = ?exit< drop code-here 2- code-w@ $1B_8B = ?< 4 true || false >? >?
  3 = not?exit&leave
  code-here 3 - code-c@ $0F = not?exit&leave
  code-here 2- code-w@ dup $1B_B7 = ?exit< drop 2 true >?
  $1B_B6 = not?exit&leave
  1 true ;

: optim-lit-add-load
  optim-last-load-type not?exit opt-laload-size:!
  low:can-remove-last-2? not?exit
  prev-add-ebx-lit? not?exit
\ endcr ." OPTIM-LIT-ADD-LOAD at $" code-here 8 - .hex8 ."  size=" opt-laload-size 0.r cr
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  opt-laload-size <<
    4 of?v| low:load-ebx-dd[ebx+value] |?
    2 of?v| low:load-ebx-dw[ebx+value] |?
    1 of?v| low:load-ebx-db[ebx+value] |?
  else| error" Succubus doesn't like your size" >> ;


0 quan opt-lastore-size (private)

;; must be followed by "pop ebx"
|: optim-prev-store-type  ( -- size TRUE // FALSE )
  ilendb:prev-last-len@ dup 3 = ?exit< drop
    code-here 4- code-@ $FF_FF_FF and $03_89_66 = ?< 2 true || false >? >?
  2 = not?exit&leave
  code-here 3 - code-w@ dup $03_89 = ?exit< drop 4 true >?
  $03_88 = not?exit&leave
  1 true ;

|: optim-las-push-ebx-mov-ebx-eax?  ( -- flag )
  2 last-len= not?exit&leave
  ilendb:it-push-ebx prev-type= not?exit&leave
  low:can-remove-last-2? not?exit&leave
  code-here 2- code-w@ $D8_8B = ;

|: optim-las-mov-ebx-[addr]?  ( -- flag )
  6 last-len= not?exit&leave
  \ low:can-remove-last? not?exit&leave
  code-here 6 - code-w@ $1D_8B = ;

|: optim-las-mov-ebx-[addr]-mov-eax-ebx?  ( -- flag )
  optim-las-mov-ebx-[addr]? not?exit&leave
  ilendb:it-mov-eax-ebx prev-type= not?exit&leave
  low:can-remove-last-2? ;

|: optim-las-mov-ebx-[addr]-push-ebx?  ( -- flag )
  optim-las-mov-ebx-[addr]? not?exit&leave
  ilendb:it-push-ebx prev-type= not?exit&leave
  low:can-remove-last-2? ;

|: optim-las-store-[eax+ofs]-ebx/sz  ( offset )
  opt-lastore-size <<
    4 of?v| low:store-[eax+value]-ebx |?
    2 of?v| low:store-[eax+value]-bx |?
    1 of?v| low:store-[eax+value]-bl |?
  else| error" Succubus doesn't like your size" >> ;

|: optim-las-store-[ebx+ofs]-eax/sz  ( offset )
  opt-lastore-size <<
    4 of?v| low:store-[ebx+value]-eax |?
    2 of?v| low:store-[ebx+value]-ax |?
    1 of?v| low:store-[ebx+value]-al |?
  else| error" Succubus doesn't like your size" >> ;

: optim-lit-add-store
  ilendb:it-pop-ebx last-type= not?exit
  2 ilendb:nth-last-type@ ilendb:it-pop-eax = not?exit
  low:can-remove-last-4? not?exit
  optim-prev-store-type not?exit opt-lastore-size:!
  code-here ilendb:prev-last-len@ - 2- 3 ilendb:nth-last-len@ -
  add-ebx-lit-at? not?exit
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  low:remove-last-unsafe low:remove-last-unsafe
  ;; check for "push ebx / mov ebx, eax"
  optim-las-push-ebx-mov-ebx-eax? ?exit<
\ endcr ." OPTIM-LIT-ADD-STORE-2 at $" code-here 3 - .hex8 ."  size=" opt-lastore-size . ." value=" dup 0.r cr
    low:remove-last-unsafe low:remove-last-unsafe
    optim-las-mov-ebx-[addr]-mov-eax-ebx? ?<
\ endcr ." OPTIM-LIT-ADD-STORE-4 at $" code-here 8 - .hex8 ."  size=" opt-lastore-size . ." value=" dup 0.r cr
      ;; simple optim: "mov eax, ebx / mov ebx, [addr] // mov [eax+ofs], ebx / pop ebx"
      ;; replacement: "mov  eax, [addr] / mov [ebx+ofs], eax / pop ebx"
      ( offset )
      code-here 4- code-@   ( offset addr )
      low:remove-last-unsafe low:remove-last-unsafe
      low:load-eax-[addr]
      optim-las-store-[ebx+ofs]-eax/sz
    || optim-las-store-[eax+ofs]-ebx/sz >?
    low:ebx low:pop-reg32 >?
\ endcr ." OPTIM-LIT-ADD-STORE at $" code-here .hex8 ."  size=" opt-lastore-size . ." value=" dup 0.r cr
  optim-las-mov-ebx-[addr]-push-ebx? ?<
\ endcr ." OPTIM-LIT-ADD-STORE-3 at $" code-here 7 - .hex8 ."  size=" opt-lastore-size . ." value=" dup 0.r cr
    ;; simple optim: "push ebx / mov ebx, [addr] // pop eax / mov [ebx+ofs], eax / pop ebx"
    ;; replacement: "mov  eax, [addr] / mov [eax+ofs], ebx / pop ebx"
    ( offset )
    code-here 4- code-@   ( offset addr )
    low:remove-last-unsafe low:remove-last-unsafe
    low:load-eax-[addr]
    optim-las-store-[eax+ofs]-ebx/sz
  || low:eax low:pop-reg32
     optim-las-store-[ebx+ofs]-eax/sz >?
  low:ebx low:pop-reg32 ;


0 quan opt-laadd-size (private)
0 quan opt-laadd? (private)

;; must be followed by "pop ebx"
|: optim-prev-addmem-type  ( -- size TRUE // FALSE )
  ilendb:prev-last-len@ dup 3 = ?exit< drop
    code-here 4- code-@ $FF_FF_FF and $03_01_66 = ?< 2 true || false >? >?
  2 = not?exit&leave
  code-here 3 - code-w@ dup $03_01 = ?exit< drop 4 true >?
  $03_00 = not?exit&leave
  1 true ;

;; must be followed by "pop ebx"
|: optim-prev-submem-type  ( -- size TRUE // FALSE )
  ilendb:prev-last-len@ dup 3 = ?exit< drop
    code-here 4- code-@ $FF_FF_FF and $03_29_66 = ?< 2 true || false >? >?
  2 = not?exit&leave
  code-here 3 - code-w@ dup $03_29 = ?exit< drop 4 true >?
  $03_28 = not?exit&leave
  1 true ;

: optim-lit-add/sub-[ebx]
  ilendb:it-pop-ebx last-type= not?exit
  2 ilendb:nth-last-type@ ilendb:it-pop-eax = not?exit
  low:can-remove-last-4? not?exit
  optim-prev-addmem-type ?< opt-laadd?:!t || optim-prev-submem-type not?exit opt-laadd?:!f >?
  opt-laadd-size:!
  code-here ilendb:prev-last-len@ - 2- 3 ilendb:nth-last-len@ -
  add-ebx-lit-at? not?exit
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  low:remove-last-unsafe low:remove-last-unsafe
\ endcr ." OPTIM-LIT-ADD-[EBX] at $" code-here .hex8 ."  size=" opt-laadd-size . ." value=" dup 0.r cr
  low:eax low:pop-reg32
  opt-laadd? ?<
    opt-laadd-size <<
      4 of?v| low:[ebx+value]+=eax |?
      2 of?v| low:[ebx+value]+=ax |?
      1 of?v| low:[ebx+value]+=al |?
    else| error" Succubus doesn't like your size" >>
  ||
    opt-laadd-size <<
      4 of?v| low:[ebx+value]-=eax |?
      2 of?v| low:[ebx+value]-=ax |?
      1 of?v| low:[ebx+value]-=al |?
    else| error" Succubus doesn't like your size" >>
  >? low:ebx low:pop-reg32 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; optimise mul, div, mod with POT numbers

|: pot?  ( pos-num -- pot TRUE // num FALSE )
  dup dup 1- and ?exit< false >?
  dup ctz ;; shift amount
  dup 31 > ?exit< drop false >?
  nip true ;

|: (optim-mul/umul-common-lits)  ( lit remove-3? -- lit FALSE // TRUE )
  swap << ( remove-3? lit )
    0 of?v|
      was-stitch-optim
      low:remove-last-unsafe low:remove-last-unsafe ?< low:remove-last-unsafe >?
      last-removable-mov-eax-lit? ?< drop low:remove-last-unsafe
      || last-removable-mov-eax-ebx? not?error" Succubus cannot multiply"
         low:remove-last-unsafe
         last-removable-mov-ebx-lit? ?< drop low:remove-last-unsafe >? >?
      0 low:ebx low:load-reg32-value
      true |?
   -1 of?v|
      was-stitch-optim
      low:remove-last-unsafe low:remove-last-unsafe ?< low:remove-last-unsafe >?
      last-removable-mov-eax-lit? ?exit<
        low:remove-last-unsafe
        negate low:ebx low:load-reg32-value
        true >?
      last-removable-mov-eax-ebx? not?error" Succubus cannot multiply"
      low:remove-last-unsafe
      last-removable-mov-ebx-lit? ?exit<
        low:remove-last-unsafe
        negate low:ebx low:load-reg32-value
        true >?
      low:ebx low:neg-reg32
      true |?
    1 of?v|
      was-stitch-optim
      low:remove-last-unsafe low:remove-last-unsafe ?< low:remove-last-unsafe >?
      last-removable-mov-eax-lit? ?exit<
        low:remove-last-unsafe
        low:ebx low:load-reg32-value
        true >?
      last-removable-mov-eax-ebx? not?error" Succubus cannot i-multiply"
      low:remove-last-unsafe
      true |?
  else| nip false >> ;

|: (optim-mul/umul-common-shift)  ( lit remove-3? )
  swap  ( remove-3? lit )
  pot? not?exit< 2drop >?
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe swap ?< low:remove-last-unsafe >?
  last-removable-mov-eax-lit? ?exit<
    low:remove-last-unsafe
    swap lshift low:ebx low:load-reg32-value >?
  last-removable-mov-eax-ebx? not?error" Succubus cannot multiply"
  low:remove-last-unsafe
  low:shl-ebx-n ;

;; it ends with "mov ebx, eax"
: optim-mov-lit-umul
  2 last-len= not?exit
  2 prev-len= not?exit
  2 ilendb:nth-last-type@ ilendb:it-#-load = not?exit
  code-here 4- code-@ $D8_8B_E3_F7 = not?exit
  low:can-remove-last-3? not?exit
  2 ilendb:nth-last-len@ 5 = ?< code-here 8 - code-@ || 0 >?
  ;; bad negative?
  dup -1 < ?exit< drop >?
\ endcr ." XXOPT-IMUL at $" code-here 4- .hex8 ."  value=" dup 0.r cr
  true (optim-mul/umul-common-lits) ?exit
  true (optim-mul/umul-common-shift) ;

;; "imul ebx, eax"
: optim-mov-lit-imul
  3 last-len= not?exit
  ilendb:it-#-load prev-type= not?exit
  code-here 3 - code-@ $FF_FF_FF and $D8_AF_0F = not?exit
  ;; it always loads first multiplier into eax
  low:can-remove-last-2? not?exit
  5 prev-len= ?< code-here 7 - code-@ || 0 >?
  ;; bad negative?
  dup -1 < ?exit< drop >?
\ endcr ." XXOPT-MUL-CHECK at $" code-here 4- .hex8 ."  value=" dup 0.r cr
  false (optim-mul/umul-common-lits) ?exit
  false (optim-mul/umul-common-shift) ;


|: optim-emit-lit-udiv  ( lit )
  low:ebx low:load-reg32-value
  low:edx low:xor-reg32-reg32
  low:ebx low:div-reg32
  low:eax low:ebx low:reg32->reg32 ;

;; "mov eax, ebx/mov eax, lit / mov ebx, lit / xor edx, edx / div ebx / mov ebx, eax"
;; replace with shift, if possible
: optim-mov-lit-udiv
  2 last-len= not?exit
  2 prev-len= not?exit
  2 ilendb:nth-last-len@ 2 = not?exit
  3 ilendb:nth-last-type@ ilendb:it-#-load = not?exit
  code-here 4- code-@ $D8_8B_F3_F7 = not?exit
  code-here 6 - code-w@ $D2_33 = not?exit
  low:can-remove-last-4? not?exit
  3 ilendb:nth-last-len@ 5 = ?< code-here 10 - code-@ || 0 >?
  ;; bad negative?
  dup 1 < ?exit< drop >?
  low:remove-last-unsafe low:remove-last-unsafe
  low:remove-last-unsafe low:remove-last-unsafe
  last-removable-mov-eax-lit? ?exit< ( by what )
    was-stitch-optim
    low:remove-last-unsafe
    swap u/ low:ebx low:load-reg32-value >?
  last-removable-mov-eax-ebx? not?error" Succubus cannot divide"
  dup 1 = ?exit< drop was-stitch-optim low:remove-last-unsafe >?
  pot? not?exit< optim-emit-lit-udiv >?
  was-stitch-optim
  low:remove-last-unsafe
  low:shr-ebx-n ;


enum{
  def: optim-shl
  def: optim-shr
  def: optim-sar
}

|: last-shift-ebx-1?  ( -- cnt type // FALSE )
  code-here 2- code-w@ <<
    $E3_D1 of?v| 1 optim-shl true |?
    $EB_D1 of?v| 1 optim-shr true |?
    $FB_D1 of?v| 1 optim-sar true |?
  else| drop false >> ;

|: last-shift-ebx?  ( -- cnt type TRUE // FALSE )
  ilendb:last-len@ dup 2 = ?exit< drop last-shift-ebx-1? >?
  3 = not?exit&leave
  code-here 3 - code-w@ <<
    $E3_C1 of?v| optim-shl |?
    $EB_C1 of?v| optim-shr |?
    $FB_C1 of?v| optim-sar |?
  else| drop false exit >>
  code-here 1- code-c@ swap true ;

;; "mov ebx, lit / shr ebx [, n]"
: optim-mov-lit-shift
  ilendb:it-#-load prev-type= not?exit
  low:can-remove-last-2? not?exit
  last-shift-ebx? not?exit
  was-stitch-optim
  low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  ( by kind what )
  nrot <<
    optim-shl of?v| lshift |?
    optim-shr of?v| rshift |?
    optim-sar of?v| arshift |?
  else| error" Succubus cannot shift the bed like this" >>
  low:ebx low:load-reg32-value ;

;; replace with shift, if possible
: optim-mov-lit-idiv
  ilendb:it-prim-idiv last-type= not?exit
  ilendb:it-#-load prev-type= not?exit
  low:can-remove-last-2? not?exit
\ endcr ." OPTIM-IDIV at $" code-here .hex8 cr
  low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  ( by )
  dup 1 < ?exit< low:lit-idiv >?
  last-removable-mov-eax-lit? ?exit< ( by what )
    was-stitch-optim
    low:remove-last-unsafe
    swap / low:ebx low:load-reg32-value >?
  last-removable-mov-eax-ebx? not?error" Succubus cannot divide"
  dup 1 = ?exit< drop was-stitch-optim low:remove-last-unsafe >?
  pot? not?exit< low:lit-idiv >?
  was-stitch-optim
  low:remove-last-unsafe
  low:sar-ebx-n ;

0 quan opt-imod? (private)

|: opt-emit-lit-imod-umod  ( lit )
  opt-imod? ?< low:lit-imod || low:lit-umod >? ;

;; replace with and, if possible
: optim-mov-lit-imod/umod
  ilendb:it-prim-imod last-type= ?< opt-imod?:!t
  || ilendb:it-prim-umod last-type= not?exit opt-imod?:!f >?
  ilendb:it-#-load prev-type= not?exit
  low:can-remove-last-2? not?exit
\ endcr ." OPTIM-IMOD at $" code-here .hex8 cr
  low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  ( by )
  dup 1 < ?exit< opt-emit-lit-imod-umod >?
  last-removable-mov-eax-lit? ?exit< ( by what )
    was-stitch-optim
    low:remove-last-unsafe
    swap mod low:ebx low:load-reg32-value >?
  last-removable-mov-eax-ebx? not?error" Succubus cannot modulate"
  dup 1 = ?exit< drop
    was-stitch-optim
    low:remove-last-unsafe
    0 low:ebx low:load-reg32-value >?
  pot? not?exit< opt-emit-lit-imod-umod >?
  was-stitch-optim
  low:remove-last-unsafe
  1 swap lshift 1-
  low:ebx swap low:and-reg32,value ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lit lshift / lit rshift / lit arshift

|: optim-do-shift  ( shift-type amount value )
  rot <<
    optim-shl of?v| swap lshift |?
    optim-shr of?v| swap rshift |?
    optim-sar of?v| swap arshift |?
  else| error" Succubus cannot shift the bed like this" >> ;

|: optim-lit-shift-ebx  ( shift-type amount )
  swap <<
    optim-shl of?v| low:shl-ebx-n |?
    optim-shr of?v| low:shr-ebx-n |?
    optim-sar of?v| low:sar-ebx-n |?
  else| error" Succubus cannot shift the bed like this" >> ;

|: optim-lit-shift-eax  ( shift-type amount )
  low:eax low:ebx low:reg32->reg32
  optim-lit-shift-ebx ;

;; "mov ebx, lit / mov ecx, ebx / mov ebx, eax / sXX ebx, cl"
: optim-lit-shift
  2 last-len= not?exit
  2 prev-len= not?exit
  2 ilendb:nth-last-len@ 2 = not?exit
  3 ilendb:nth-last-type@ ilendb:it-#-load = not?exit
  low:can-remove-last-4? not?exit
  code-here 6 - code-@ $D8_8B_CB_8B = not?exit  ;; mov ecx, ebx / mov ebx, eax
  code-here 2- code-w@ <<
    $E3_D3 of?v| optim-shl |?
    $EB_D3 of?v| optim-shr |?
    $FB_D3 of?v| optim-sar |?
  else| drop exit >>
  ( shift-type )
  was-stitch-optim
  low:remove-last-unsafe
  low:remove-last-unsafe
  low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  ( shift-type amount )
  dup -?< error" invalid shift amount" >?
  ;; completely shifted out?
  dup 31 > -?< error" invalid shift amount" >?
  ;; zero shift?
  dup not?exit< 2drop
\ endcr ." OPTIM-LIT-SHIFT-0 at $" code-here .hex8 cr
    last-removable-mov-eax-ebx? ?<
      low:remove-last-unsafe
    || last-removable-mov-eax-lit? ?<
         low:remove-last-unsafe
         low:ebx low:load-reg32-value
       || low:eax low:ebx low:reg32->reg32 >? >? >?
  last-removable-mov-eax-ebx? ?exit<
    low:remove-last-unsafe
    ;; shift known constant?
\ endcr ." OPTIM-LIT-SHIFT-MOV at $" code-here .hex8 ."  shift=" dup 0.r cr
    optim-lit-shift-ebx >?
\ endcr ." OPTIM-LIT-SHIFT at $" code-here .hex8 ."  shift=" dup 0.r cr
  last-removable-mov-eax-lit? ?exit<
    low:remove-last-unsafe
\ endcr ." OPTIM-LIT-LIT-SHIFT at $" code-here .hex8 ."  shift=" over . ." const=" dup 0.r cr
    optim-do-shift
    low:ebx low:load-reg32-value >?
  optim-lit-shift-eax ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; why not?

: optim-0max
  ilendb:it-prim-max last-type= not?exit
  ilendb:it-#-load prev-type= not?exit
  2 prev-len= not?exit
  low:can-remove-last-2? not?exit
\ endcr ." OPTIM-0MAX at $" code-here 9 - .hex8 cr
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  low:gen-0max ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bitwise ops

enum{
  def: opt-bitwise-or
  def: opt-bitwise-xor
  def: opt-bitwise-and
}

;; " mov eax, ebx / mov ebx, lit / or|xor|and ebx, eax"
;; replace with "or|xor|and ebx, lit"
: optim-lit-bitwise
  2 last-len= not?exit
  ilendb:it-#-load prev-type= not?exit
  2 ilendb:nth-last-type@ ilendb:it-mov-eax-ebx = not?exit
  low:can-remove-last-3? not?exit
  code-here 2- code-w@ <<
    $D8_0B of?v| opt-bitwise-or |?
    $D8_33 of?v| opt-bitwise-xor |?
    $D8_23 of?v| opt-bitwise-and |?
  else| drop exit >>
\ endcr ." OPTIM-LIT-BITWISE at $" code-here 4- ilendb:prev-last-len@ - .hex8 ."  type=" dup 0.r cr
  ( type )
  was-stitch-optim
  low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  low:remove-last-unsafe
  ( type value )
  swap <<
    opt-bitwise-or of?v| low:ebx swap low:or-reg32,value |?
    opt-bitwise-xor of?v| low:ebx swap low:xor-reg32,value |?
    opt-bitwise-and of?v| low:ebx swap low:and-reg32,value |?
  else| error" Succubus doesn't understand alien logic" >> ;

;; " mov eax, ebx / mov ebx, lit / not ebx / and ebx, eax"
;; replace with "and ebx, ~lit"
: optim-lit-~and
  2 last-len= not?exit
  2 prev-len= not?exit
  code-here 4- code-@ $D8_23_D3_F7 = not?exit
  2 ilendb:nth-last-type@ ilendb:it-#-load = not?exit
  3 ilendb:nth-last-type@ ilendb:it-mov-eax-ebx = not?exit
  low:can-remove-last-4? not?exit
\ endcr ." OPTIM-LIT-~AND at $" code-here 6 - 2 ilendb:nth-last-len@ - .hex8 cr
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  low:remove-last-unsafe
  bitnot low:ebx swap low:and-reg32,value ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; n-drop, n-rdrop

: optim-n-drop
  ilendb:it-prim-ndrop last-type= not?exit
  ilendb:it-#-load prev-type= not?exit
  low:can-remove-last-2? not?exit
\ endcr ." OPTIM-NDROP at $" code-here .hex8 cr
  was-stitch-optim
  low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  ( value )
  dup -0?exit< drop low:ebx low:pop-reg32 >?
  ilendb:it-push-ebx last-type= low:can-remove-last? and ?<
    ;; "push ebx / lea / pop ebx" -- remove push, drop one less
    low:remove-last-unsafe
    1- >?
  << 0 of?v||
     1 of?v| low:eax low:pop-reg32 |?
  else| 4* low:lea-esp-[esp+value] >>
  low:ebx low:pop-reg32 ;

: optim-n-rdrop
  ilendb:it-prim-nrdrop last-type= not?exit
  ilendb:it-#-load prev-type= not?exit
  low:can-remove-last-2? not?exit
\ endcr ." OPTIM-NRDROP at $" code-here .hex8 cr
  was-stitch-optim
  low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  ( value )
  dup +?< dup 4* low:lea-ebp-[ebp+value] >? drop
  low:ebx low:pop-reg32 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lit dd-nth

;; mov ebx, # lit / lea ebx, [ebx+eax*4]
: optim-lit-dd-nth
  3 last-len= not?exit
  ilendb:it-#-load prev-type= not?exit
  code-here 3 - code-@ $FF_FF_FF and $83_1C_8D = not?exit ;; lea ebx, [ebx+eax*4]
  low:can-remove-last-2? not?exit
  was-stitch-optim
  low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  ( value )
  last-removable-mov-eax-ebx? drop 0 ?exit<
    ;; "mov eax, ebx / mov ebx, # lit / lea ebx, [ebx+eax*4]"
    ;; rewrite to: "lea ebx, [ebx*4+lit]"
    low:remove-last-unsafe
\ endcr ." OPTIM-DD-NTH-MOV-EAX at $" code-here .hex8 cr
    low:lea-ebx,[ebx*4+value] >?
  ;; "mov ebx, # lit / lea ebx, [ebx+eax*4]"
  ;; rewrite to: "lea ebx, [eax*4+lit]"
\ endcr ." OPTIM-DD-NTH at $" code-here .hex8 cr
  low:lea-ebx,[eax*4+value] ;

;; "lea ebx, [eax*4+lit] / mov ebx, [ebx]", or
;; "lea ebx, [ebx*4+lit] / mov ebx, [ebx]"
;; replace with direct "mov"
: optim-dd-nth-load
  2 last-len= not?exit
  7 prev-len= not?exit
  low:can-remove-last-2? not?exit
  code-here 2- code-w@ $1B_8B = not?exit  ;; mov ebx, [ebx]
  code-here 9 - code-w@ $1C_8D = not?exit
  code-here 7 - code-c@ dup $85 = ?< drop ( eax) true
  || $9D = not?exit ( ebx) false >?
  code-here 6 - code-@ swap ( value eax? )
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
\ endcr ." OPTIM-DD-NTH-LIT-LOAD at $" code-here .hex8 cr
  ?< low:mov-ebx,[eax*4+value] || low:mov-ebx,[ebx*4+value] >? ;

;; "lea ebx, [eax*4+lit] / pop eax / mov [ebx], eax / pop ebx", or
;; "lea ebx, [ebx*4+lit] / pop eax / mov [ebx], eax / pop ebx"
;; replace with direct "store":
;; " pop eax / mov [...], eax / pop ebx"
: optim-dd-nth-store
  ilendb:it-pop-ebx last-type= not?exit
  2 prev-len= not?exit
  2 ilendb:nth-last-type@ ilendb:it-pop-eax = not?exit
  3 ilendb:nth-last-len@ 7 = not?exit
  low:can-remove-last-4? not?exit
  code-here 3 - code-w@ $03_89 = not?exit  ;; mov [ebx], eax
  code-here 11 - code-w@ $1C_8D = not?exit
  code-here 9 - code-c@ dup $85 = ?< drop ( eax) true
  || $9D = not?exit ( ebx) false >?
  code-here 8 - code-@ swap ( value eax? )
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  low:remove-last-unsafe low:remove-last-unsafe
\ endcr ." OPTIM-DD-NTH-LIT-STORE at $" code-here .hex8 cr
  ?< low:ebx low:pop-reg32
     low:mov-[eax*4+value],ebx
  || low:eax low:pop-reg32
     low:mov-[ebx*4+value],eax >?
  low:ebx low:pop-reg32 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; for some reason two following optimisations makes the code slower

1 [IF]
;; "push ebx / mov ebx, eax / shl ebx, n / pop eax / add ebx, eax"
;; replace with: "lea ebx, [ebx+eax*n]" or "shl eax, n // add ebx, eax"
: optim-dd-nth-addr
  2 last-len= not?exit
  ilendb:it-pop-eax prev-type= not?exit
  2 ilendb:nth-last-len@ 3 = not?exit
  3 ilendb:nth-last-len@ 2 = not?exit
  4 ilendb:nth-last-type@ ilendb:it-push-ebx = not?exit
  code-here 7 - bblock-start^ u>= not?exit
  code-here 2- code-w@ $D8_03 = not?exit  ;; add ebx, eax
  code-here 6 - code-w@ $E3_C1 = not?exit ;; shl ebx, n
  code-here 4- code-c@  ( amount )
\ endcr ." OPTIM-DD-NTH-ADDR at $" code-here 6 - .hex8 ."  amount=" dup 0.r cr
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  low:remove-last-unsafe low:remove-last-unsafe
  low:remove-last-unsafe
  last-removable-mov-ebx-lit? ?exit<
    low:remove-last-unsafe  ( amount base )
\ endcr ." OPTIM-DD-NTH-LIT-LIT at $" code-here 6 - .hex8 cr
    ;; "lea ebx, [eax*n+base]" or "shl eax, n // lea ebx, [eax+base]"
    swap <<
      0 of?v| low:lea-ebx-[eax+value] |?
      1 of?v| low:lea-ebx-[eax*2+value] |?
      2 of?v| low:lea-ebx-[eax*4+value] |?
    else| swap low:shl-eax-n low:lea-ebx-[eax+value] >> >?
  ( amount )
\ endcr ." OPTIM-DD-NTH-LIT at $" code-here 6 - .hex8 cr
  ;; "lea ebx, [ebx+eax*n]" or "shl eax, n // add ebx, eax"
  <<
    0 of?v| low:ebx low:eax low:reg32+=reg32 |?
    1 of?v| low:lea-ebx-[ebx+eax*2] |?
    2 of?v| low:lea-ebx-[ebx+eax*4] |?
  else| low:shl-eax-n low:ebx low:eax low:reg32+=reg32 >> ;


;; "mov eax, ebx / mov ebx, lit / shl eax, n / add ebx, eax"
;; replace with: "lea ebx, [lit+eax*n]" / "shl eax, n / lea ebx, [lit+eax]"
: optim-dd-nth-addr-2
  2 last-len= not?exit
  3 prev-len= not?exit
  2 ilendb:nth-last-type@ ilendb:it-#-load = not?exit
  3 ilendb:nth-last-type@ ilendb:it-mov-eax-ebx = not?exit
  low:can-remove-last-4? not?exit
  code-here 2- code-w@ $D8_03 = not?exit  ;; add ebx, eax
  code-here 5 - code-w@ $E3_C1 = not?exit ;; shl ebx, n
  code-here 3 - code-c@  ( amount )
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  get-last-lit-value low:remove-last-unsafe
  low:remove-last-unsafe
  ( amount base )
\ endcr ." OPTIM-DD-NTH-ADDR-2 at $" code-here .hex8 ."  amount=" over . ." base=" dup .hex8 cr
  swap <<
    1 of?v| low:lea-ebx-[eax*2+value] |?
    2 of?v| low:lea-ebx-[eax*4+value] |?
  else| swap low:shl-eax-n low:lea-ebx-[eax+value] >> ;

;; " mov eax, ebx / mov ebx, [eax*4+lit]"
;; replace with: "mov ebx, [ebx*4+lit]"
;; this VERY rarely occurs whout the previous optimisations
: optim-load-ebx-eax*4-lit
  7 last-len= not?exit
  ilendb:it-mov-eax-ebx prev-type= not?exit
  code-here 7 - code-@ $FF_FF_FF and $85_1C_8B = not?exit
  low:can-remove-last-2? not?exit
\ endcr ." OPTIM-LL-EBX-EAX*4 at $" code-here 9 - .hex8 cr
  code-here 4- code-@ ( base )
  was-stitch-optim
  low:remove-last-unsafe low:remove-last-unsafe
  low:load-ebx-dd[ebx*4+value] ;
[ELSE]
: optim-dd-nth-addr ;
: optim-dd-nth-addr-2 ;
: optim-load-ebx-eax*4-lit ;
[ENDIF]
