;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; x86 32-bit prefix assembler: high-level conditions and loops
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

0 quan (macro-saved-curr)

|: (m/i-narg)  ( argc )
  current@ >r voc-cur: instructions
  >r [\\] : r@ for \\ >r endfor \\ emit:flush r> for \\ r> endfor r> ;

*: instr-narg:  ( argc )  (m/i-narg) 0xc0de_b0de ;
*: instr:  0 [\\] instr-narg: ;
*: ;instr  0xc0de_b0de system:?pairs >r [\\] ; r> current! ;

*: macro-narg:  ( argc )  (m/i-narg) push-ctx voc-ctx: instructions 0xc0de_b0d1 ;
*: macro:  0 [\\] macro-narg: ;
*: ;macro  0xc0de_b0d1 system:?pairs >r [\\] ; pop-ctx r> current! ;


;; condition codes, can be used to build some instructions
instr: O? 0 ;instr
instr: NO? 1 ;instr
instr: B? 2 ;instr
instr: C? 2 ;instr
instr: NAE? 2 ;instr
instr: U<? 2 ;instr
instr: AE? 3 ;instr
instr: NB? 3 ;instr
instr: NC? 3 ;instr
instr: U>=? 3 ;instr
instr: E? 4 ;instr
instr: Z? 4 ;instr
\ instr: =? 4 ;instr
instr: NE? 5 ;instr
instr: NZ? 5 ;instr
\ instr: <>? 5 ;instr
instr: BE? 6 ;instr
instr: NA? 6 ;instr
instr: U<=? 6 ;instr
instr: A? 7 ;instr
instr: NBE? 7 ;instr
instr: U>? 7 ;instr
instr: S? 8 ;instr
\ instr: -? 8 ;instr
instr: NS? 9 ;instr
\ instr: +0? 9 ;instr
instr: P? 10 ;instr
instr: PE? 10 ;instr
instr: NP? 11 ;instr
instr: PO? 11 ;instr
instr: L? 12 ;instr
instr: NGE? 12 ;instr
\ instr: <? 12 ;instr
instr: GE? 13 ;instr
instr: NL? 13 ;instr
\ instr: >=? 13 ;instr
instr: LE? 14 ;instr
instr: NG? 14 ;instr
\ instr: <=? 14 ;instr
instr: G? 15 ;instr
instr: NLE? 15 ;instr
\ instr: >? 15 ;instr

: ?cond  ( cc )  15 u> ?error" invalid condition" ;

extend-module instructions
: $  emit:here ;
: -not  ( cc -- cc-inverted )  dup ?cond 1 forth:xor ;
: flush!  emit:flush ;
end-module instructions

0 quan <jover-rel8> (private)

|: (skipper)
  <jover-rel8> emit:here over 1+ - swap emit:c!
  ['] noop emit:post-build:! ;

1 instr-narg: skip-when  ( cc )
  emit:<instr
  dup ?cond $70 or emit:c, emit:here x86asm::<jover-rel8>:! $00 emit:c,
  emit:instr>
  ['] x86asm::(skipper) emit:post-build:! ;instr

1 instr-narg: do-when  ( cc )
  1 xor instructions:skip-when ;instr


;; write "branch to destaddr" address to addr
|: (BRANCH-ADDR!)  ( destaddr addr )  tuck 4+ - swap emit:! ;

;; read branch address
|: (BRANCH-ADDR@)  ( addr -- dest )  dup emit:@ + 4+ ;

|: (:J-BRN)  ( cond -- addr )  dup +0?< $0F emit:c, $80 or || drop $E9 >? emit:c, ;
|: (:J-RESV)  0 dup emit:c, dup emit:c, dup emit:c, emit:c, ;

;; marks place for backward branches.
;; return addr suitable for "(<J-RESOLVE)".
|: (<J-MARK)  ( -- addr )  emit:here ;

;; patch "forward jump" address to HERE
;; addr is the result of "(<J-MARK)"
|: (<J-RESOLVE-BRN)  ( addr cond )
  (:j-brn) emit:here (:j-resv) (branch-addr!) ;

;; reserve room for branch address, return addr suitable for "(RESOLVE-J>)"
|: (MARK-J>-BRN)  ( cond -- addr )  (:j-brn) emit:here (:j-resv) ;

;; use after "(MARK-J>)" to reserve jump and append it to jump chain
|: (CHAIN-J>-BRN)  ( addr cond -- addr )
  (:j-brn) emit:here (:j-resv) 2dup emit:! nip ;

;; compile "forward jump" (possibly chain) from address to HERE
;; addr is the result of "(MARK-J>)"
|: (RESOLVE-J>)  ( addr )
  begin dup while
    dup emit:@   ( addr prevaddr )
    emit:here rot (branch-addr!)  ( prevaddr )
  repeat drop ;


0 quan (chain-break) (private)
0 quan (chain-cont) (private)
0 quan (in-begin) (private)

|: init-ifthen  (chain-break):!0 (chain-cont):!0 (in-begin):!0 ;
init-ifthen ['] init-ifthen emit:init-ifthen:!
['] noop emit:finish-ifthen:!

|: (COMPILE-WHILE)
  swap system:pair-begin system:?pairs
  (chain-break) swap (chain-j>-brn) (chain-break):! system:pair-begin ;

|: (COMPILE-UNTIL)
  swap system:pair-begin system:?pairs
  (chain-cont) swap (<j-resolve-brn) (chain-break) (resolve-j>)
  (chain-cont):! (chain-break):! (in-begin):! ;

1 instr-narg: if,    ( cc )  dup ?cond 1 xor x86asm::(mark-j>-brn) system:pair-if ;instr
instr: else,  system:pair-if system:?pairs -1 x86asm::(mark-j>-brn)
              swap x86asm::(resolve-j>) system:pair-ifelse ;instr
instr: endif, system:pair-if system:pair-ifelse system:?2pairs x86asm::(resolve-j>) ;instr

instr: begin,
  x86asm::(in-begin) x86asm::(chain-break) x86asm::(chain-cont) system:pair-begin
  x86asm::(chain-break):!0 x86asm::(<j-mark)
  x86asm::(chain-cont):! x86asm::(in-begin):!1 ;instr

;; all failed whiles will terminate the loop
1 instr-narg: while,  dup ?cond 1 xor x86asm::(compile-while) ;instr
1 instr-narg: until,  dup ?cond 1 xor x86asm::(compile-until) ;instr
instr: repeat, -1 x86asm::(compile-until) ;instr

instr: break,
  x86asm::(in-begin) not?error" 'BREAK' out of loop"
  x86asm::(chain-break) -1 x86asm::(chain-j>-brn)
  x86asm::(chain-break):! ;instr

instr: continue,
  x86asm::(in-begin) not?error" 'CONTINUE' out of loop"
  x86asm::(chain-cont) -1 x86asm::(<j-resolve-brn) ;instr
