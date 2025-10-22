;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; minimalistic x86 asm
;; i need to parameterise instructions on the fly, so x86asm doesn't fit
;; the use is like this:
;; <asm arg arg arg , arg arg arg instr asm>
;;   <asm ebx push, asm>
;;   <asm ebx , eax mov, asm> -- "mov ebx, eax"
;;   <asm ebx , [ebp] [+] 42 mov, asm> -- "mov ebx, [ebp+42]"
;;   <asm ebx , [ebp] [eax*8] [+] 42 mov, asm> -- "mov ebx, [ebp+eax*8+42]"


module xasm
<disable-hash>
<published-words>

vect-empty <instr
vect-empty instr>

: db,  ( byte )  code-db, ;
: dw,  ( byte )  code-dw, ;
: dd,  ( byte )  code-dd, ;
0 quan c-$
\ : c-$  ( -- addr )  i-start ;

<public-words>
0 quan op
0 quan op0
0 quan op1
0 quan imm
0 quan disp -- for r/m, jmpc/call, for [addr]

;; set for any 16-bit instruction, even without immediate argument
false quan imm-16?
;; 0: byte
;; 1: dword
1 quan instr-sz-or

0 quan rrr

: rrr!  ( reg )  8 * rrr:! ;

vect-empty op#

: op:or!  ( value )  op forth:or op:! ;

: op#-imm    imm:! ;
: op#-disp   disp:! ;
: op#-disp+  disp:+! ;

|: (xarg)  ( type )
  dup hi-word not?error" miniasm wut?"
  op over and $FFFF_0000 and ?error" miniasm doesn't"
  op:or!  ['] noop op#:! ;

;; operand modes
$8000_0000 constant m-reg32
$4000_0000 constant m-[reg32]
$2000_0000 constant m-[reg32*1]
$2000_4000 constant m-[reg32*2]
$2000_8000 constant m-[reg32*4]
$2000_C000 constant m-[reg32*8]

;; the following 3 takes imm from the data stack
$1000_0000 constant m-#
$0800_0000 constant m-[addr]
$0400_0000 constant m-[+]

<published-words>
;; naked register values
;; WARNING! order matters!
0 constant (eax)
1 constant (ecx)
2 constant (edx)
3 constant (ebx)
4 constant (esp)
5 constant (ebp)
6 constant (esi)
7 constant (edi)

;; this is strictly for "-b," and such
0 constant (al)
1 constant (cl)
2 constant (dl)
3 constant (bl)
4 constant (ah)
5 constant (ch)
6 constant (dh)
7 constant (bh)

$8000_0000 constant (reg32-eax)
$8000_0001 constant (reg32-ecx)

$4000_0000 constant (reg32-[eax])

;; create register operands from naked register values
: reg32      ( naked-reg )  m-reg32 or (xarg) ;
: [reg32]    ( naked-reg )  16 * m-[reg32] or (xarg) ;
: [reg32*1]  ( naked-reg )  256 * m-[reg32*1] or (xarg) ;
: [reg32*2]  ( naked-reg )  256 * m-[reg32*2] or (xarg) ;
: [reg32*4]  ( naked-reg )  256 * m-[reg32*4] or (xarg) ;
: [reg32*8]  ( naked-reg )  256 * m-[reg32*8] or (xarg) ;

: eax  (eax) reg32 ;
: ecx  (ecx) reg32 ;
: edx  (edx) reg32 ;
: ebx  (ebx) reg32 ;
: esp  (esp) reg32 ;
: ebp  (ebp) reg32 ;
: esi  (esi) reg32 ;
: edi  (edi) reg32 ;

;; this means nothing, and used only for clarity
: al  (al) reg32 ;
: cl  (cl) reg32 ;
: dl  (dl) reg32 ;
: bl  (bl) reg32 ;
: ah  (ah) reg32 ;
: ch  (ch) reg32 ;
: dh  (dh) reg32 ;
: bh  (bh) reg32 ;

: [eax]  (eax) [reg32] ;
: [ecx]  (ecx) [reg32] ;
: [edx]  (edx) [reg32] ;
: [ebx]  (ebx) [reg32] ;
: [esp]  (esp) [reg32] ;
: [ebp]  (ebp) [reg32] ;
: [esi]  (esi) [reg32] ;
: [edi]  (edi) [reg32] ;

: [eax*1]  (eax) [reg32*1] ;
: [ecx*1]  (ecx) [reg32*1] ;
: [edx*1]  (edx) [reg32*1] ;
: [ebx*1]  (ebx) [reg32*1] ;
\ : [esp*1]  (esp) [reg32*1] ;
: [ebp*1]  (ebp) [reg32*1] ;
: [esi*1]  (esi) [reg32*1] ;
: [edi*1]  (edi) [reg32*1] ;

: [eax*2]  (eax) [reg32*2] ;
: [ecx*2]  (ecx) [reg32*2] ;
: [edx*2]  (edx) [reg32*2] ;
: [ebx*2]  (ebx) [reg32*2] ;
\ : [esp*2]  (esp) [reg32*2] ;
: [ebp*2]  (ebp) [reg32*2] ;
: [esi*2]  (esi) [reg32*2] ;
: [edi*2]  (edi) [reg32*2] ;

: [eax*4]  (eax) [reg32*4] ;
: [ecx*4]  (ecx) [reg32*4] ;
: [edx*4]  (edx) [reg32*4] ;
: [ebx*4]  (ebx) [reg32*4] ;
\ : [esp*4]  (esp) [reg32*4] ;
: [ebp*4]  (ebp) [reg32*4] ;
: [esi*4]  (esi) [reg32*4] ;
: [edi*4]  (edi) [reg32*4] ;

: [eax*8]  (eax) [reg32*8] ;
: [ecx*8]  (ecx) [reg32*8] ;
: [edx*8]  (edx) [reg32*8] ;
: [ebx*8]  (ebx) [reg32*8] ;
\ : [esp*8]  (esp) [reg32*8] ;
: [ebp*8]  (ebp) [reg32*8] ;
: [esi*8]  (esi) [reg32*8] ;
: [edi*8]  (edi) [reg32*8] ;


: #
  op m-# and ?error" miniasm doesn't" m-# op:or!
  ['] noop op#:@ - ?error" miniasm immdup"
  op 28 rshift 2 8 within ?error" miniasm #"
  ['] op#-imm op#:! ;

: [addr]
  op m-[addr] and ?error" miniasm doesn't" m-[addr] op:or!
  ['] noop op#:@ - ?error" miniasm dispdup"
  ['] op#-disp op#:! ;

: [+]
  ( op m-[+] and ?error" miniasm doesn't") m-[+] op:or!
  ['] noop op#:@ - ?error" miniasm dispdup"
  ['] op#-disp+ op#:! ;

(*
: .ops
  endcr ." === OPS ===\n"
  ."   op: $" op .hex8 cr
  ."  op0: $" op0 .hex8 cr
  ."  op1: $" op1 .hex8 cr
  ."  imm: " imm 0.r cr
  ." disp: " disp 0.r cr ;
*)

: reset-op  op:!0 ['] noop op#:! ;

: reset  op0:!0 op1:!0 disp:!0 imm:!0 imm-16?:!0 instr-sz-or:!1 rrr:!0 reset-op ;

: ,
  op not?error" miniasm oper?"
  op#
  op dup m-[+] = ?error" miniasm stray [+]"
  m-[+] ~and op:!
  \ .op
  op1 ?error" miniasm toomany"
  op op0 not?< op0:! || op1:! >?
  reset-op ;

<public-words>
: instr-end  instr> reset ;


module xasm-support
<disable-hash>
<public-words>

: op-end
  op ?< , >?
  [ 0 ] [IF] .ops [ENDIF]
  code-here c-$:! <instr ;

;; can operand be encoded as "reg"?
: op-reg?     ( op -- flag )  hi-word $8000 = ;
;; can operand be encoded as "r/m"?
: op-imm?     ( op -- flag )  hi-word $1000 = ;
: op-addr?    ( op -- flag )  hi-word $0800 = ;
: op-r/m?     ( op -- flag )  hi-word dup $4000 $6000 bounds op-addr? or ;
: op-[reg]?   ( op -- flag )  hi-word $4000 = ;
: op-[reg*n]? ( op -- flag )  hi-word $2000 = ;

: op-r/m|reg? ( op -- flag )  dup op-r/m? swap op-reg? or ;

: ?op   op0 op1 or not?error" miniasm noopers" ;
: ?0op  op0 ?error" miniasm manyopers" ;
: ?1op  op1 ?error" miniasm manyopers" op0 not?error" miniasm noopers" ;
: ?2op  op1 not?error" miniasm noopers" ;

: imm8?  ( imm -- flag )  -128 128 within ;
: imm32? ( imm -- flag )  imm8? not ;


|: mod-r/m,  ( byte )  rrr or db, ;


|: build-r/m-reg  ( op )  &o300 or mod-r/m, ;
|: build-r/m-addr ( op )  &o005 or mod-r/m, disp dd, ;

|: mk-scale  ( op -- scale-byte )  hi-byte $F0 and ;

|: emit-ofs  ( ofs )  dup imm8? ?< db, || dd, >? ;


|: build-r/m-[esp*1]
  disp dup not?exit< drop &o004 mod-r/m, &o044 db, >?
  imm8? ?< &o104 || &o204 >? mod-r/m, &o044 db,
  disp emit-ofs ;

|: build-r/m-[reg]-nodisp  ( reg )  mod-r/m, ;

|: build-r/m-[reg]  ( op )
  4 rshift 7 and
  dup (esp) = ?exit< drop build-r/m-[esp*1] >?
  disp dup not?< over (ebp) <> ?exit< drop build-r/m-[reg]-nodisp >? >?
  imm8? ?< &o100 or || &o200 or >? mod-r/m,
  disp emit-ofs ;

|: build-r/m-[reg*1]  ( op )
  dup $F00 and $400 = ?exit< build-r/m-[esp*1] >?
  disp not?exit< 4 rshift build-r/m-[reg] >?
  &o004 mod-r/m,
  hi-byte 7 and 8 * 5 or db,
  disp dd, ;

|: build-r/m-[reg*n]  ( op )
  dup $C000 and not?exit< build-r/m-[reg*1] >?
  ;; mod=0, r/m=4, base=5
  &o004 mod-r/m,
  dup hi-byte 7 and 8 * 5 or  swap mk-scale or db,
  disp dd, ;

|: build-r/m-sib  ( op )
  dup 16 u/ 7 and ( base )
  over hi-byte 7 and 8 * or  ( base+index )
  swap mk-scale or  ( base+index+scale )
  disp dup not?< over 7 and (ebp) = not?exit< drop &o004 mod-r/m, db, >? >?
  imm8? ?< &o104 || &o204 >? mod-r/m, db,
  disp emit-ofs ;

: build-r/m  ( op )
  dup op-reg? ?exit< build-r/m-reg >?
  dup op-addr? ?exit< build-r/m-addr >?
  dup op-imm? ?error" miniasm shit"
  dup op-[reg]? ?exit< build-r/m-[reg] >?
  dup op-[reg*n]? ?exit< build-r/m-[reg*n] >?
  build-r/m-sib ;

|: alu-reg,imm
  op0 (reg32-eax) = imm imm32? and ?exit< rrr $04 or instr-sz-or or db, imm dd, >?
  instr-sz-or not?error" this 8-bit ALU is not there yet"
  imm imm8? ?exit<
    $83 db,
    op0 $0F and &o300 or mod-r/m,
    imm db, >?
  $81 db,
  op0 $0F and &o300 or mod-r/m,
  imm dd, ;

|: alu-reg,r/m
  $02 instr-sz-or or rrr or db,
  op0 $0F and rrr!
  op1 build-r/m ;

|: alu-reg,???
  op1 op-imm? ?exit< alu-reg,imm >?
  alu-reg,r/m ;

|: alu-???,reg
  instr-sz-or rrr or db,
  op1 $0F and rrr!
  op0 build-r/m ;

|: alu-r/m8,imm8
  $80 db, op0 build-r/m imm db, ;

|: alu-r/m,imm
  instr-sz-or not?exit< alu-r/m8,imm8 >?
  imm -128 128 within ?exit< $83 db, op0 build-r/m imm db, >?
  $81 db, op0 build-r/m imm imm-16? ?exit< dw, >? dd, ;

|: (alu)
  op-end
  ?2op
  op0 op-reg? ?exit< alu-reg,??? >?
  op1 op-reg? ?exit< alu-???,reg >?
  op1 op-imm? ?exit< alu-r/m,imm >?
  error" miniasm badalu" ;

: alu-dd  (alu) ;
: alu-db  instr-sz-or:!0 (alu) ;
: alu-dw  $66 db, imm-16?:!t (alu) ;


: inc/dec  ( opc-r/m opc-r32 )
  2>r op-end 2r>
  ?1op
  dup +0?< op0 op-reg? ?exit< op0 7 and or db, drop >? || >? drop
  db, op0 build-r/m ;

: div/mul  ( rrr )
  >r op-end r>
  ?1op
  op0 op-r/m|reg? not?error" miniasm badops"
  $F7 db, rrr! op0 build-r/m ;

: jmp/call  ( opc )
  >r op-end r>
  ?1op
  op0 op-imm? ?exit< db, imm c-$ 5 + - dd, >? drop
  $FF db, op0 build-r/m ;


|: mov-imm,
  imm imm-16? ?< dup -32768 65536 within not?error" miniasm badimm16" dw,
  || dd, >? ;

|: mov-eax,[addr]  $A0 instr-sz-or + db, disp dd, ;
|: mov-[addr],eax  $A2 instr-sz-or + db, disp dd, ;

|: mov-reg,imm
  instr-sz-or not?exit<
    imm -128 256 within not?error" miniasm badimm8"
    $B0 op0 7 and or db,  imm db, >?
  $B8 op0 7 and or db,  mov-imm, ;

|: mov-???,imm
  op0 op-reg? ?exit< mov-reg,imm >?
  0 rrr!
  instr-sz-or not?exit<
    imm -128 256 within not?error" miniasm badimm8"
    $C6 db, op0 build-r/m  imm db, >?
  $C7 db, op0 build-r/m  mov-imm, ;

|: mov-reg,???
  $8A instr-sz-or + db, op0 7 and rrr! op1 build-r/m ;

|: mov-???,reg
  $88 instr-sz-or + db, op1 7 and rrr! op0 build-r/m ;

: do-mov
  op0 (reg32-[eax]) = op1 op-addr? and ?exit< mov-eax,[addr] >?
  op1 (reg32-[eax]) = op0 op-addr? and ?exit< mov-[addr],eax >?
  op1 op-imm? ?exit< mov-???,imm >?
  op0 op-reg? ?exit< mov-reg,??? >?
  op1 op-reg? ?exit< mov-???,reg >?
  error" miniasm badops" ;

|: shift-r/m     $D1 db, op0 build-r/m ;
|: shift-r/m,cl  $D3 db, op0 build-r/m ;

: do-shift
  op-end
  ?op
  op1 not?exit< shift-r/m >?
  op1 (reg32-ecx) = ?exit< shift-r/m,cl >?
  op1 op-imm? not?error" miniasm op1 notimm"
  imm dup 0 32 within not?error" miniasm badshift"
  $C1 db, op0 build-r/m db, ;

|: xchg-eax,reg  $90 op1 7 and or db, ;
|: xchg-reg,eax  $90 op0 7 and or db, ;
|: xchg-reg,r/m  $87 db, op0 rrr! op1 build-r/m ;
|: xchg-r/m,reg  $87 db, op1 rrr! op0 build-r/m ;

: do-xchg
  op-end
  ?2op
  op0 (reg32-eax) = op1 op-reg? and ?exit< xchg-eax,reg >?
  op1 (reg32-eax) = op0 op-reg? and ?exit< xchg-reg,eax >?
  op0 op-reg? ?exit< xchg-reg,r/m >?
  op1 op-reg? ?exit< xchg-r/m,reg >?
  error" miniasm badxchg" ;

|: test-eax,imm  $A9 db, imm dd, ;

|: text-???,imm
  op0 (reg32-eax) = ?< $A9 db, || $F7 db, 0 rrr! op0 build-r/m >?
  imm dd, ;

|: test-r/m,reg  $85 db, op1 7 and rrr! op0 build-r/m ;
|: test-reg,r/m  $85 db, op0 7 and rrr! op1 build-r/m ;

: do-test
  op-end
  ?2op
  op1 op-imm? ?exit< text-???,imm >?
  op1 op-reg? ?exit< test-r/m,reg >?
  op0 op-reg? ?exit< test-reg,r/m >?
  error" miniasm badtest" ;

: do-movx  ( opc )
  >r op-end r>
  ?2op
  op0 op-reg? not?error" miniasm notreg"
  $0F db, db,
  op0 7 and rrr! op1 build-r/m ;

: (i-simple)  ( opc )
  >r op-end r>
  ?0op
  dup 24 rshift swap << dup db, 256 u/ 1 under- over ?^|| else| 2drop >>
  instr-end ;

end-module xasm-support


module instr
<disable-hash>
<published-words>
using xasm-support

: cbw,   $02009866 (i-simple) ;
: cwde,  $01000098 (i-simple) ;
: cwd,   $02009966 (i-simple) ;
: cdq,   $01000099 (i-simple) ;
: clc,   $010000F8 (i-simple) ;
: cld,   $010000FC (i-simple) ;
: ccf,   $010000F5 (i-simple) ;
: cmpsb, $010000A6 (i-simple) ;
: cmpsw, $0200A766 (i-simple) ;
: cmpsd, $010000A7 (i-simple) ;
: int3,  $010000CC (i-simple) ;
: lodsb, $010000AC (i-simple) ;
: lodsw, $0200AD66 (i-simple) ;
: lodsd, $010000AD (i-simple) ;
: movsb, $010000A4 (i-simple) ;
: movsw, $0200A566 (i-simple) ;
: movsd, $010000A5 (i-simple) ;
: nop,   $01000090 (i-simple) ;
: ret,   $010000C3 (i-simple) ;
: scasb, $010000AE (i-simple) ;
: scasw, $0200AF66 (i-simple) ;
: scasd, $010000AF (i-simple) ;
: scf,   $010000F9 (i-simple) ;
: std,   $010000FD (i-simple) ;
: stosw, $0200AB66 (i-simple) ;
: stosd, $010000AB (i-simple) ;
: repnz, $010000F2 (i-simple) ;
: repne, $010000F2 (i-simple) ;
: rep,   $010000F3 (i-simple) ;
: repz,  $010000F3 (i-simple) ;
: repe,  $010000F3 (i-simple) ;
: lock,  $010000F0 (i-simple) ;
: rdtsc, $0200310F (i-simple) ;


: add,  0 rrr! alu-dd instr-end ;
: or,   1 rrr! alu-dd instr-end ;
: adc,  2 rrr! alu-dd instr-end ;
: sbb,  3 rrr! alu-dd instr-end ;
: and,  4 rrr! alu-dd instr-end ;
: sub,  5 rrr! alu-dd instr-end ;
: xor,  6 rrr! alu-dd instr-end ;
: cmp,  7 rrr! alu-dd instr-end ;

: add-b,  0 rrr! alu-db instr-end ;
: or-b,   1 rrr! alu-db instr-end ;
: adc-b,  2 rrr! alu-db instr-end ;
: sbb-b,  3 rrr! alu-db instr-end ;
: and-b,  4 rrr! alu-db instr-end ;
: sub-b,  5 rrr! alu-db instr-end ;
: xor-b,  6 rrr! alu-db instr-end ;
: cmp-b,  7 rrr! alu-db instr-end ;

: add-w,  0 rrr! alu-dw instr-end ;
: or-w,   1 rrr! alu-dw instr-end ;
: adc-w,  2 rrr! alu-dw instr-end ;
: sbb-w,  3 rrr! alu-dw instr-end ;
: and-w,  4 rrr! alu-dw instr-end ;
: sub-w,  5 rrr! alu-dw instr-end ;
: xor-w,  6 rrr! alu-dw instr-end ;
: cmp-w,  7 rrr! alu-dw instr-end ;

: rol,  0 rrr! do-shift instr-end ;
: ror,  1 rrr! do-shift instr-end ;
: rcl,  2 rrr! do-shift instr-end ;
: rcr,  3 rrr! do-shift instr-end ;
: sal,  4 rrr! do-shift instr-end ;
: shl,  4 rrr! do-shift instr-end ;
: shr,  5 rrr! do-shift instr-end ;
: sar,  7 rrr! do-shift instr-end ;

;; reg r/m cond-x cmov
: cmov,  ( cc )
  >r op-end r>
  ?2op
  op0 op-reg? op1 op-r/m? and not?error" miniasm badops"
  $0F db, $40 or db,
  op0 7 and rrr! op1 build-r/m
  instr-end ;

;; r/m cond-x cmov
: set-b,  ( cc )
  >r op-end r>
  ?1op
  $0F db, $90 or db,
  0 rrr! op0 build-r/m
  instr-end ;
: setcc-b,  ( cc ) set-b, ;

: inc,    $FF $40 0 rrr! inc/dec instr-end ;
: dec,    $FF $48 1 rrr! inc/dec instr-end ;
: inc-b,  $FE -1 0 rrr! inc/dec instr-end ;
: dec-b,  $FE -1 1 rrr! inc/dec instr-end ;
: inc-w,  $66 db, $FF -1 0 rrr! inc/dec instr-end ;
: dec-w,  $66 db, $FF -1 1 rrr! inc/dec instr-end ;

: bswap,
  op-end
  ?1op
  op0 op-reg? not?error" miniasm badops"
  $0F db, $C8 op0 7 and or db,
  instr-end ;

: div,   6 div/mul instr-end ;
: mul,   4 div/mul instr-end ;
: idiv,  7 div/mul instr-end ;
: imul,  5 div/mul instr-end ;
: neg,   3 div/mul instr-end ;
: not,   2 div/mul instr-end ;

: jmp,   $E9 4 rrr! jmp/call instr-end ;
: call,  $E8 2 rrr! jmp/call instr-end ;

: jmp-short,
  op-end
  ?1op
  op0 op-imm? not?error" miniasm badrel"
  imm c-$ 2+ - dup -128 128 within not?error" miniasm notrel8"
  $EB db, db,
  instr-end ;

: jmp-cond,  ( cond )
  >r op-end r>
  ?1op
  op0 op-imm? not?error" miniasm badrel"
  $0F db, $80 or db,
  imm c-$ 6 + - dd,
  instr-end ;

: jmp-short-cond,  ( cond )
  >r op-end r>
  ?1op
  op0 op-imm? not?error" miniasm badrel"
  imm c-$ 2+ - dup -128 128 within not?error" miniasm notrel8"
  $70 rot or db, db,
  instr-end ;

: lea,
  op-end
  ?2op
  op0 op-reg? not?error" miniasm notreg"
  $8D db,
  op0 7 and rrr! op1 build-r/m
  instr-end ;

: mov,
  op-end
  ?2op
  do-mov
  instr-end ;

: mov-b,
  op-end
  ?2op
  instr-sz-or:!0 do-mov
  instr-end ;

: mov-w,
  op-end
  ?2op
  $66 db, imm-16?:!t do-mov
  instr-end ;

: pop,
  op-end
  ?1op
  op0 op-reg? ?< $58 op0 7 and or db, || $8F db, 0 rrr! op0 build-r/m >?
  instr-end ;

: push,
  op-end
  ?1op
  op0 op-imm? ?<
    imm dup -128 128 within ?< $6A db, db, || $68 db, dd, >?
  || op0 op-reg? ?< $50 op0 7 and or db, || $FF db, 6 rrr! op0 build-r/m >? >?
  instr-end ;

: xchg,  do-xchg instr-end ;
: test,  do-test instr-end ;

: movsx-b, $BE do-movx instr-end ;
: movsx-w, $BF do-movx instr-end ;

: movzx-b, $B6 do-movx instr-end ;
: movzx-w, $B7 do-movx instr-end ;

;; swap stacks
: sswap,
  op-end
  ?0op
  $87 db, $EC db,
  instr-end ;

end-module instr

module cond
<disable-hash>
<published-words>
 0 constant o
 1 constant no
 2 constant b
 2 constant c
 2 constant nae
\  2 constant u<
 3 constant ae
 3 constant nb
 3 constant nc
\  3 constant u>=
 4 constant e
 4 constant z
 5 constant ne
 5 constant nz
 6 constant be
 6 constant na
\  6 constant u<=
 7 constant a
 7 constant nbe
\  7 constant u>
 8 constant s
 9 constant ns
10 constant p
10 constant pe
11 constant np
11 constant po
12 constant l
12 constant nge
13 constant ge
13 constant nl
14 constant le
14 constant ng
15 constant g
15 constant nle

: invert  ( cond -- inv-cond )  1 forth:xor ;

end-module cond

end-module xasm
