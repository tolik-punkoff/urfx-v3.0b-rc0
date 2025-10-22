;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TCOM conditions and loops
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

\ extend-module SHADOW-HELPERS
\ <private-words>

0 quan (DO/FOR-NODE)

0 quan (CSP)

: zx-CSP@  ( -- csp )  (csp) ;
: zx-CSP!  ( value  )  (csp):! ;
: zx-!CSP  forth:(sp@) zx-csp! ;

: zx-?CPAIRS  ( a b )  zx-?comp system:?pairs ;
: zx-?2PAIRS  ( pn n0 n1 )  zx-?comp ROT TUCK ( n0 pn n1 pn) - NROT - AND ?error" imbalance!" ;


;; marks:
;;  1: BEGIN
;;  2: WHILE
;;  3: DO
;;  9: FOR
;;  4: IF
;;  5: ELSE
;;  6: CASE
;;  7: OF
;;  8: OTHERWISE

;; it is important for all loops to be sequential ("BREAK" depends on it)
enum{
  def: CT-NONE
  def: CT-BEGIN
  def: CT-WHILE
  def: CT-DO
  def: CT-FOR
  def: CT-FOR8
  def: CT-IF
  def: CT-ELSE
  def: CT-CASE
  def: CT-OF
  def: CT-OTHERWISE
}

CT-BEGIN constant CT-BREAK-START
CT-FOR8 1+ constant CT-BREAK-FENCE

: (W/U-PROLOGUE)  ( brn-comiple-cfa )  >R CT-BEGIN CT-WHILE zx-?2PAIRS R> execute-tail ;
: (WHILE,)  ( brn-comiple-cfa )  (W/U-PROLOGUE) zx-CHAIN> CT-WHILE ;
: (UNTIL,)  ( brn-comiple-cfa )  (W/U-PROLOGUE) SWAP zx-<RESOLVE zx-RESOLVE> zx-CSP! ;

: (BROPT-0BRANCH)  zsys-run: 0BRANCH ;
: (BROPT-TBRANCH)  zsys-run: TBRANCH ;
: (BROPT-0BRANCH-W)  ( -- brscfa )  zsys: 0BRANCH ;
: (BROPT-TBRANCH-W)  ( -- brscfa )  zsys: TBRANCH ;
: (BROPT-0BRANCH-U)  ( -- brscfa )  zsys: 0BRANCH ;
: (BROPT-TBRANCH-U)  ( -- brscfa )  zsys: TBRANCH ;

(*
: (LOOP,)  ( backjump-chain overjump-chain loop-type brn-compile-cfa )
  \ SWAP CT-DO CT-FOR zx-?2PAIRS execute
  SWAP CT-DO zx-?CPAIRS execute
  SWAP zx-<RESOLVE zx-RESOLVE>
  zx-CSP! ;
*)


: (?GOOD-LOOP-START)  ( node^ )
  dup 0?error" loop operator is used out of the loop"
  ir:node:spfa
  dup zsys: (DO) dart:cfa>pfa = ?exit< drop >?
  dup zsys: (FOR) dart:cfa>pfa = ?exit< drop >?
  dup zsys: (FOR8) dart:cfa>pfa = ?exit< drop >?
  drop error" not a loop node!" ;

: (?GOOD-FOR-NODE)  ( node^ )
  dup 0?exit&leave
  ir:node:spfa
  dup zsys: (FOR) dart:cfa>pfa = ?exit< drop true >?
  dup zsys: (FOR8) dart:cfa>pfa = ?exit< drop true >?
  drop false ;

: (?LOOP#-NODE)  ( index -- node^ )
  (do/for-node)
  swap for dup (?good-loop-start) ir:node:prev-loop endfor
  dup (?good-loop-start) ;

: (?LOOP#)  ( index )
  (?loop#-node) drop ;

: (LOOP-ENTER)
  ir:tail (?good-loop-start)
  (do/for-node) ir:tail ir:node:prev-loop:!
  ir:tail (do/for-node):! ;

: (LOOP-EXIT)
  (do/for-node)
  dup (?good-loop-start)
  ir:node:prev-loop (do/for-node):! ;

: (LOOP,)  ( backjump-chain overjump-chain loop-type brn-compile-cfa pair-code )
  ROT zx-?CPAIRS execute
  (loop-exit)
  SWAP zx-<RESOLVE zx-RESOLVE>
  zx-CSP! ;


extend-module SHADOW-HELPERS
<published-words>

: BEGIN   zx-?COMP zx-CSP@ zx-<MARK ( fwd chain) 0 CT-BEGIN zx-!CSP ;
: AGAIN   zsys: BRANCH (UNTIL,) ;
: REPEAT  forth:[\\] AGAIN ;

: WHILE     (bropt-0branch-w) (WHILE,) ;
: NOT-WHILE (bropt-tbranch-w) (WHILE,) ;
: 0WHILE    (bropt-tbranch-w) (WHILE,) ;
: -WHILE    zsys: +0BRANCH (WHILE,) ;
: +WHILE    zsys: -0BRANCH (WHILE,) ;
: -0WHILE   zsys: +BRANCH (WHILE,) ;
: +0WHILE   zsys: -BRANCH (WHILE,) ;

: UNTIL     (bropt-0branch-u) (UNTIL,) ;
: NOT-UNTIL (bropt-tbranch-u) (UNTIL,) ;
: 0UNTIL    (bropt-tbranch-u) (UNTIL,) ;
: -UNTIL    zsys: +0BRANCH (UNTIL,) ;
: +UNTIL    zsys: -0BRANCH (UNTIL,) ;
: -0UNTIL   zsys: +BRANCH (UNTIL,) ;
: +0UNTIL   zsys: -BRANCH (UNTIL,) ;

: UNLESS      (bropt-0branch-u) (UNTIL,) ;
: 0UNLESS     (bropt-tbranch-u) (UNTIL,) ;
: NOT-UNLESS  (bropt-tbranch-u) (UNTIL,) ;
: -UNLESS     zsys: +0BRANCH (UNTIL,) ;
: +UNLESS     zsys: -0BRANCH (UNTIL,) ;
: -0UNLESS    zsys: +BRANCH (UNTIL,) ;
: +0UNLESS    zsys: -BRANCH (UNTIL,) ;


: IF     zx-?COMP (bropt-0branch) zx-MARK> CT-IF ;
: 0IF    zx-?COMP (bropt-tbranch) zx-MARK> CT-IF ;
: -IF    zx-?COMP zsys-run: +0BRANCH zx-MARK> CT-IF ;
: +IF    zx-?COMP zsys-run: -0BRANCH zx-MARK> CT-IF ;
: -0IF   zx-?COMP zsys-run: +BRANCH zx-MARK> CT-IF ;
: +0IF   zx-?COMP zsys-run: -BRANCH zx-MARK> CT-IF ;
: IFNOT  zx-?COMP zsys-run: TBRANCH zx-MARK> CT-IF ;
: ENDIF  CT-IF CT-ELSE zx-?2PAIRS zx-RESOLVE> ;
: ELSE   CT-IF zx-?CPAIRS zsys-run: BRANCH zx-MARK> SWAP zx-RESOLVE> CT-ELSE ;


: DO      zx-?COMP zsys-run: (DO) (LOOP-ENTER) zx-CSP@ zx-<MARK ( fwd chain) 0 CT-DO zx-!CSP ;
: FOR     zx-?COMP zsys-run: (FOR) (LOOP-ENTER) zx-CSP@ zx-MARK> zx-<MARK SWAP CT-FOR zx-!CSP ;
: CFOR    zx-?COMP zsys-run: (FOR8) (LOOP-ENTER) zx-CSP@ zx-MARK> zx-<MARK SWAP CT-FOR8 zx-!CSP ;
: LOOP    zsys: (LOOP+1) CT-DO (LOOP,) ;
: LOOP-1  zsys: (LOOP-1) CT-DO (LOOP,) ;
: +LOOP   zsys: (+LOOP) CT-DO (LOOP,) ;
: ENDFOR  \ zsys: (ENDFOR) CT-FOR (LOOP,) ;
  \ DUP CT-FOR8 = ?< zsys: (ENDFOR8) CT-FOR8 || zsys: (ENDFOR) CT-FOR >? (LOOP,) ;
  DUP CT-FOR8 = ?< zsys: (ENDFORX) CT-FOR8 || zsys: (ENDFORX) CT-FOR >? (LOOP,) ;
\ : ENDFOR8 zsys: (ENDFOR8) CT-FOR8 (LOOP,) ;

: I
  zx-?COMP
  (do/for-node) dup 0?error" \'I\' out of the loop"
  ir:nflag-i-used swap ir:node-set-flag
  forth:['] ir:ir-specials:(ir-loop-i) ir:append-special
  0 ir:tail ir:node:value:! ;

: I'
  zx-?COMP
  (do/for-node) dup 0?error" \'I'\' out of the loop"
  ir:nflag-i-used swap ir:node-set-flag
  forth:['] ir:ir-specials:(ir-loop-i') ir:append-special
  0 ir:tail ir:node:value:! ;

: J
  zx-?COMP
  (do/for-node) dup 0?error" \'J\' out of the loop"
  1 (?loop#)
  ir:nflag-i-used swap ir:node-set-flag
  forth:['] ir:ir-specials:(ir-loop-i) ir:append-special
  1 ir:tail ir:node:value:! ;

: J'
  zx-?COMP
  (do/for-node) dup 0?error" \'J'\' out of the loop"
  1 (?loop#)
  ir:nflag-i-used swap ir:node-set-flag
  forth:['] ir:ir-specials:(ir-loop-i') ir:append-special
  1 ir:tail ir:node:value:! ;

: IREV
  zx-?COMP
  (do/for-node) dup 0?error" \'IREV\' out of the loop"
  ir:nflag-i-used swap ir:node-set-flag
  forth:['] ir:ir-specials:(ir-loop-irev) ir:append-special
  0 ir:tail ir:node:value:! ;

: JREV
  zx-?COMP
  (do/for-node) dup 0?error" \'JREV\' out of the loop"
  1 (?loop#-node)
  (?good-for-node) 0?error" \'JREV\' out of the \'FOR\' loop"
  ir:nflag-i-used swap ir:node-set-flag
  forth:['] ir:ir-specials:(ir-loop-irev) ir:append-special
  1 ir:tail ir:node:value:! ;


\ TODO: "LEAVE" and "UNLOOP" should not set "I used" flag
(*
: LEAVE
  zx-?COMP
  (do/for-node) dup 0?error" \'LEAVE\' out of the loop"
  ir:nflag-i-used swap ir:node-set-flag
  zsys-run: (LEAVE) ;
*)

: UNLOOP
  zx-?COMP
  (do/for-node) dup 0?error" \'UNLOOP\' out of the loop"
  ir:nflag-i-used swap ir:node-set-flag
  forth:['] ir:ir-specials:(ir-unloop) ir:append-special
  0 ir:tail ir:node:value:! ;


: BREAK
  zx-?COMP zx-CSP@ @ DUP CT-BREAK-START CT-BREAK-FENCE WITHIN 0?error" break of what?"
  CT-DO >= ?< UNLOOP >?  ;; clear stack for loops
  zx-CSP@ 4 + ( chain> addr )
  DUP @ zsys-run: BRANCH zx-CHAIN> SWAP ! ;

: CONTINUE
  zx-?COMP zx-CSP@ @ CT-BEGIN CT-DO WITHIN 0?error" continue what?"
  zx-CSP@ 8 + @ zsys-run: BRANCH zx-<RESOLVE ;


: CASE     zx-?COMP zx-CSP@ ( exit fwd chain) 0 CT-CASE zx-!CSP ;
\ : OF       CT-CASE zx-?CPAIRS zsys-run: OVER zsys-run: - zsys-run: TBRANCH zx-MARK> zsys-run: DROP CT-OF ;
\ : OF       CT-CASE zx-?CPAIRS zsys-run: (of<>) zsys-run: TBRANCH zx-MARK> zsys-run: DROP CT-OF ;
: OF       CT-CASE zx-?CPAIRS zsys-run: <>BRANCH-ND zx-MARK> zsys-run: DROP CT-OF ;
: ENDOF    CT-OF zx-?CPAIRS zsys-run: BRANCH SWAP zx-CHAIN> SWAP zx-RESOLVE> CT-CASE ;
: ENDCASE  DUP CT-CASE CT-OTHERWISE zx-?2PAIRS CT-OTHERWISE <> ?< zsys-run: DROP >? zx-RESOLVE> zx-CSP! ;
;; leaves the value intact, will not drop it
: OTHERWISE  CT-CASE zx-?CPAIRS CT-OTHERWISE ;


end-module \ SHADOW-HELPERS

end-module \ TCOM
