;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler: instruction emitter
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; current instruction, used in matcher
0 quan <instr-table>

module emit

256 constant first-user-label-id

vect here -- used for jumps
vect c,
vect c@
vect c!
vect @
vect !

;; this is used just before some label reference is going to be emited
;; not called for reserved indicies: [1..255]
;; it can be used to record fixup info
;; also, you can change the value of the label
vect <label-addr>  ( val size-in-bytes idx -- val )
;; this is for jumps and calls
;; note that label value will be converted to branch displacement before emiting
vect <label-rel>   ( val size-in-bytes idx -- val )
;; called by matcher to know if the label value is known
;; for unknown labels, short command forms will not be used
;; (i.e. no short jumps, and imm/disp will be 4 bytes)
vect label-known?  ( idx -- bool )
;; this is called by operand combiner when it needs to get label value
;; if you implemented labels like "@ name", and "@" already leaves
;; label value on the stack, you can simply put DROP here
vect label@  ( idx -- val )

;; for all the following callback, you can use "emit:here" to get the current location
;; called before and after instruction emiting (all bytes)
;; you can use "instr-rdisp?", "instr-addr?" and "instr-opcode" in the following handlers
;; opcode format: bits 24..31: length; other bits: opcode (lowest byte first in memory)
vect-empty <instr  ( -- )
vect-empty instr>  ( -- )
;; called *before* emiting the corresponding value
;; do not try to use internal emitter API to check the presence
;; of the corresponding parts, use the callbacks!
['] drop vectored <disp>   ( disp size-in-bytes -- disp )
['] drop vectored <imm>    ( ival size-in-bytes -- ival )
['] drop vectored <rel>    ( addr size-in-bytes -- addr )

;; prefixes in the following order (bytes, from the LSB):
;; note that address prefix($67) is never generated!
;;   data($66), segment($smth)
0 quan prefix
;; MSB is # of bytes to emit
0 quan opcode
;; negative means "none"; high byte is SIB
;; it's easy to tell if we need to emit SIB by looking at R/M: it should be 4
;; it is possible to determina disp size from MOD.
0 quan mrm/sib
0 quan disp

;; special constants for "*mrm/sib*"
0x0001_0000 constant disp-rel8
0x0002_0000 constant disp-rel32
0x0003_0000 constant disp-addr

0 quan imm#  ;; in bytes; 0 means "none"
0 quan imm

;; address of the first byte of the currenly building instruction
;; this can be used in label management code
0 quan dollar

;; label ids
0 quan label-disp
0 quan label-imm

vect-empty builder
vect-empty post-build
vect-empty reset-args

vect-empty init-ifthen
vect-empty finish-ifthen

vect-empty init-loc-labels
vect-empty finish-loc-labels

vect loc-label-known?  ( idx -- bool )
vect <loc-label-addr>  ( val size-in-bytes idx -- val )
vect <loc-label-rel>  ( val size-in-bytes idx -- val )
vect loc-label@  ( idx -- val )


: label-call  ( val size idx -- val )
  dup ?< dup first-user-label-id < ?< <loc-label-addr> || <label-addr> >? || 2drop >? ;

: label-disp? ( val size -- val )  label-disp label-call ;
: label-imm?  ( val size -- val )  label-imm label-call ;
: label-rel?  ( val size -- val )
  label-disp dup ?< dup first-user-label-id < ?< <loc-label-rel> || <label-rel> >?
                 || 2drop >? ;

;; called by matcher
: known-value?  ( lbl-idx -- bool )
  dup ?< dup first-user-label-id < ?< loc-label-known? || label-known? >? || 0= >? ;

;; called by operand combiner, and by matcher
: value@  ( lbl-idx -- val )
  dup first-user-label-id < ?< loc-label@ || label@ >? ;

: reset
  prefix:!0 opcode:!0 imm#:!0
  label-disp:!0 label-imm:!0
  <instr-table>:!0
  -1 mrm/sib:!
  reset-args ;

: opcode#  ( -- len )  opcode 24 rshift ;
: mod@  ( -- value )  mrm/sib 64 u/ 3 and ;
: r/m@  ( -- value )  mrm/sib 7 and ;
: reg!  ( value )  8 * mrm/sib 0o070 ~and or mrm/sib:! ;

: emit-#  ( value size )  for dup lo-byte c, 256 u/ endfor drop ;
: w, ( v )  2 emit-# ;
: ,  ( v )  4 emit-# ;

: ?emit-b  ( byte )  dup ?< dup c, >? drop ;
: +0?emit-b  ( byte )  1+ dup ?< dup 1- c, >? drop ;
: emit-prefix  prefix << dup ?^| dup lo-byte c, 256 u/ |? else| drop >> ;

: emit-imm  imm imm# prefix lo-byte $66 = ?< 2 min >?
            dup >r label-imm? r@ <imm> r> emit-# ;

: emit-opcode  opcode opcode# emit-# ;
: emit-mrm/sib mrm/sib lo-byte c,
               mod@ 3 < r/m@ 4 = and ?< mrm/sib hi-byte c, >? ;
: emit-disp-1  ( unused-value ) drop disp 1 label-disp? 1 <disp> c, ;
: emit-disp-4  ( unused-value ) drop disp 4 label-disp? 4 <disp> , ;
: emit-sib-disp? ( mrm/sib )
  hi-byte 7 and 5 = ?exit< 0 emit-disp-4 >? ;
: emit-sib/addr-disp?  ( mrm/sib )
  dup 7 and dup 4 = ?exit< drop emit-sib-disp? >?
  5 = ?exit< emit-disp-4 >? drop ;

create emit-mds
['] emit-sib/addr-disp? forth:,
['] emit-disp-1 forth:,
['] emit-disp-4 forth:,
['] drop forth:, create;

: emit-disp-mod  ( mrm )
  dup lo-byte 64 u/ 4* emit-mds + @execute-tail ;

: calc-rel  ( disp size -- rel )  here swap + - ;

: emit-rel-4  disp 4 label-rel? 4 <rel> 4 calc-rel , ;
: emit-rel-1  disp 1 label-rel? 1 <rel> 1 calc-rel dup -128 128 within not?error" bad rel" c, ;

: emit-disp
  ;; start with the most common case
  << mrm/sib dup hi-word not?v| emit-disp-mod |?
     disp-rel32 of?v| emit-rel-4 |?
     disp-rel8 of?v| emit-rel-1 |?
     disp-addr of?v| 0 ( unused value) emit-disp-4 |?
     else| drop >> ;


;; utilities for "<instr" and "instr>"
;; size of "relative disp" for the current instruction; 0, 1, 4
: instr-rdisp?  ( -- size )
  mrm/sib
  dup disp-rel32 = 4*
  swap disp-rel8 =
  + negate ;

: instr-addr?  ( -- size )
  mrm/sib disp-addr = 4* negate ;

: instr-opcode  ( -- byte )
  opcode ;


;; WARNING! you should NOT leave your data on the data stack before calling FLUSH!
;;          this is because operand combiner may need to read immediate values.
: flush
  builder opcode# ?<
    <instr here dollar:! emit-prefix emit-opcode
    mrm/sib hi-word not?< emit-mrm/sib >?
    emit-disp emit-imm instr> post-build
  >? reset ;


;; called when initing an assembler chunk
: init
  reset init-loc-labels init-ifthen ;

;; called when finishing an assembler chunk
: finish
  flush finish-ifthen finish-loc-labels ;

reset
clean-module
end-module emit

(*
our prefix order:
address size, operand size, lock(?), segment override

general x86 instruction format
┌────────┬─────────────┬─────┬──────────────┬───────────┐
│ opcode │ MOD|REG|R/M │ SIB │ displacement │ immediate │
├────────┼─────────────┼─────┼──────────────┼───────────┤
│  1,2   │     0,1     │ 0,1 │   0,1,2,4    │  0,1,2,4  │
└────────┴─────────────┴─────┴──────────────┴───────────┘
max length: 16 bytes

mod|r/m format:
  7  6  5  4  3  2  1  0
┌──┬──┬──┬──┬──┬──┬──┬──┐
│ MOD │ R  E  G│ R /  M │
└──┴──┴──┴──┴──┴──┴──┴──┘

32-bit addressing modes:
    MOD║     00     │    01    │    10     │    11
  R/M  ║            │          │           │w=0 │ w=1
═══════╬════════════╪══════════╪═══════════╪════╪═════
  000  ║   [EAX]    │ [EAX]+d8 │ [EAX]+d32 │ AL │ EAX
  001  ║   [ECX]    │ [ECX]+d8 │ [ECX]+d32 │ CL │ ECX
  010  ║   [EDX]    │ [EDX]+d8 │ [EDX]+d32 │ DL │ EDX
  011  ║   [EBX]    │ [EBX]+d8 │ [EBX]+d32 │ BL │ EBX
  100  ║    SIB     │  SIB +d8 │  SIB +d32 │ AH │ ESP
  101  ║ [offset32] │ [EBP]+d8 │ [EBP]+d32 │ CH │ EBP
  110  ║   [ESI]    │ [ESI]+d8 │ [ESI]+d32 │ DH │ ESI
  111  ║   [EDI]    │ [EDI]+d8 │ [EDI]+d32 │ BH │ EDI

sib format:
  7  6  5  4  3  2  1  0
┌──┬──┬──┬──┬──┬──┬──┬──┐
│ S  S│ I  I  I│ B  B  B│
└──┴──┴──┴──┴──┴──┴──┴──┘
scale:
  0 (00): *1
  1 (01): *2
  2 (10): *4
  3 (11): *8
base:
  5 (101): (EBP): special for MOD=00 -- no base, 32-bit displacement
index:
  4 (100): (ESP): no index, scale must be "00".
*)
