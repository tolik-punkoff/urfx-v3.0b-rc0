;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; basic compiler words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module SYSTEM

0xdead_feed constant CTLID-COLON
0xf00d_dead constant CTLID-CBLOCK
0xc0de_f00d constant CTLID-CODE
0xcafe_f00d constant CTLID-SCOLON


uro-constant@ tgt-#htable constant #HTABLE
uro-constant@ tgt-hmask constant HMASK

uro-constant@ tgt-#wname-max constant #WNAME-MAX

;; this flag is kept in name length
uro-constant@ tgt-nflag-case-sens constant NFLAG-CASE-SENS

uro-constant@ tgt-wflag-mask constant WFLAG-MASK

uro-constant@ tgt-wflag-immediate constant WFLAG-IMMEDIATE
uro-constant@ tgt-wflag-protected constant WFLAG-PROTECTED
uro-constant@ tgt-wflag-private constant WFLAG-PRIVATE
uro-constant@ tgt-wflag-published constant WFLAG-PUBLISHED
uro-constant@ tgt-wflag-noreturn constant WFLAG-NORETURN
uro-constant@ tgt-wflag-inline-blocker constant WFLAG-INLINE-BLOCKER
uro-constant@ tgt-wflag-inline-allowed constant WFLAG-INLINE-ALLOWED
uro-constant@ tgt-wflag-inline-force constant WFLAG-INLINE-FORCE
uro-constant@ tgt-wflag-end-swap-next constant WFLAG-END-SWAP-NEXT
uro-constant@ tgt-wflag-no-stacks constant WFLAG-NO-STACKS
uro-constant@ tgt-wflag-dummy-word constant WFLAG-DUMMY-WORD
uro-constant@ tgt-wflag-has-back-jumps constant WFLAG-HAS-BACK-JUMPS

;; flags to leave (via AND) for the new module
uro-constant@ tgt-wflag-module-mask constant WFLAG-MODULE-MASK

uro-constant@ tgt-wtype-mask constant WTYPE-MASK

uro-constant@ tgt-wtype-normal constant WTYPE-NORMAL
uro-constant@ tgt-wtype-branch constant WTYPE-BRANCH
uro-constant@ tgt-wtype-literal constant WTYPE-LITERAL

\ uro-constant@ tcom:code-align constant CODE-ALIGN
\ uro-constant@ tcom:forth-align constant FORTH-ALIGN
\ uro-constant@ tcom:const-align constant CONST-ALIGN
\ uro-constant@ tcom:var-align constant VAR-ALIGN
uro-constant@ tgt-#inline-bytes constant #DEFAULT-INLINE-BYTES
uro-constant@ tgt-#inline-bytes quan #CURRENT-INLINE-BYTES

uro-constant@ tgt-vocflag-temp constant VOCFLAG-TEMP
uro-constant@ tgt-vocflag-nohash constant VOCFLAG-NOHASH

uro-constant@ tgt-voc-latest-lfa-ofs constant VOC-LATEST-LFA-OFS
uro-constant@ tgt-voc-link-ofs constant VOC-LINK-OFS
uro-constant@ tgt-voc-header-nfa-ofs constant VOC-HEADER-NFA-OFS
uro-constant@ tgt-voc-hash-ptr-ofs constant VOC-HASH-PTR-OFS
uro-constant@ tgt-voc-parent-ofs constant VOC-PARENT-OFS
uro-constant@ tgt-voc-find-cfa-ofs constant VOC-FIND-CFA-OFS
uro-constant@ tgt-voc-notfound-cfa-ofs constant VOC-NOTFOUND-CFA-OFS
uro-constant@ tgt-voc-execcomp-cfa-ofs constant VOC-EXECCOMP-CFA-OFS
uro-constant@ tgt-voc-literal-cfa-ofs constant VOC-LITERAL-CFA-OFS
uro-constant@ tgt-voc-vocid-size constant VOC-VOCID-SIZE


0 quan STATE

: COMP?  state 0<> ;
: EXEC?  state 0= ;

: ?COMP  exec? ?error" compilation mode expected" ;
: ?EXEC  comp? ?error" interpretaion mode expected" ;

: ?PAIRS  ( a b )    <> ?error" unbalanced constructs" ;
: ?2PAIRS ( a b c )  >r over <> swap r> <> and ?error" unbalanced constructs" ;

: (CFA@)  ( cfa-xt -- jumpaddr )  1+ @++ + ;

: CFA@  ( cfa-xt -- jumpaddr // 0 )  c@++ $E8 = dup ?< drop @++ + || nip >? ;

: DOES?       ( cfa-xt -- flag )  cfa@ uro-label@ do-does = ;
: VARIABLE?   ( cfa-xt -- flag )  cfa@ uro-label@ do-variable = ;
: CONSTANT?   ( cfa-xt -- flag )  cfa@ uro-label@ do-constant = ;
: USERVAR?    ( cfa-xt -- flag )  cfa@ uro-label@ do-uservar = ;
: USER-VALUE? ( cfa-xt -- flag )  cfa@ uro-label@ do-uservalue = ;
: ALIAS?      ( cfa-xt -- flag )  cfa@ uro-label@ do-alias = ;

: NORMAL-CODE?  ( cfa-xt -- flag )
  c@++ $E8 = not?exit< drop true >? @++ +
  dup uro-label@ do-does <>
  over uro-label@ do-variable <> and
  over uro-label@ do-constant <> and
  over uro-label@ do-uservar <> and
  over uro-label@ do-uservalue <> and
  swap uro-label@ do-alias <> and ;


;; if your word need to work with return addresses, use the
;; following operations. this tells Succubus whan you are
;; intend to do, so she could choose the right strategy.

;; get return address from the return stack.
;; WARNING: this is semantically different from "R>"!
: RR>  ( | addr -- addr )  r> ; (force-inline) (inline-blocker)
;; put return address from the return stack.
;; WARNING: this is semantically different from ">R"!
: >RR  ( addr -- | addr )  >r ; (force-inline) (inline-blocker)

end-module SYSTEM

*: [  system:state:!0 ;
 : ]  system:state:!t ;


;; "Dictionary Article"
module DART
<disable-hash>
;; WARNING! keep in sync with the header in "Beast-60-hl-30-creatori.f"!
: NFAEND>NFA  ( nfaend -- nfa )  dup c@ - ;

: NFA>XFA  ( nfa -- xfa )  dup c@ 127 and + [ 3 4* 2+ ] {#,} + ;
: NFA>LFA  ( nfa -- lfa )  nfa>xfa [ 1 4* ] {#,} + ;
: NFA>WFA  ( nfa -- wfa )  nfa>xfa [ 2 4* ] {#,} + ;

: WFA>NFA     ( wfa -- nfa )    [ 5 4* 1+ ] {#,} - nfaend>nfa ;
: WFA>BFA     ( wfa -- bfa )    [ 4 4* ] {#,} - ;
: WFA>XFA     ( wfa -- bfa )    [ 2 4* ] {#,} - ;
: WFA>LFA     ( wfa -- bfa )    [ 1 4* ] {#,} - ;
: WFA>DFA     ( wfa -- dfa )    @ ;
: WFA>WLEN    ( wfa -- wlen^)   [ 1 4* ] {#,} + ;
: WFA>VOCID   ( wfa -- vocid)   [ 2 4* ] {#,} + ;
: WFA>OPTINFO ( wfa -- optinfo) [ 3 4* ] {#,} + ;

: DFA>WFA  ( dfa -- nfa )  @ ;
: DFA>FFA  ( dfa -- ffa )  [ 1 4* ] {#,} + ;
: DFA>CFA  ( dfa -- cfa )  [ 2 4* ] {#,} + ;
: DFA>NFA  ( dfa -- nfa )  dfa>wfa wfa>nfa ;

: BFA>HFA  ( bfa -- hfa )  [ 1 4* ] {#,} - ;
: BFA>VFA  ( bfa -- vfa )  [ 1 4* ] {#,} + ;
: BFA>XFA  ( bfa -- xfa )  [ 2 4* ] {#,} + ;
: BFA>LFA  ( bfa -- lfa )  [ 3 4* ] {#,} + ;
: BFA>WFA  ( bfa -- wfa )  [ 4 4* ] {#,} + ;
: BFA>SFA  ( bfa -- sfa )  [ 8 4* ] {#,} + ;
: BFA>DFA  ( bfa -- dfa )  bfa>wfa wfa>dfa ;
: BFA>FFA  ( bfa -- ffa )  bfa>dfa dfa>ffa ;
: BFA>CFA  ( bfa -- cfa )  bfa>dfa dfa>cfa ;
: BFA>NFA  ( bfa -- nfa )  bfa>wfa wfa>nfa ;

: FFA>DFA  ( ffa -- dfa )  [ 1 4* ] {#,} - ;
: FFA>CFA  ( ffa -- cfa )  [ 1 4* ] {#,} + ;
: FFA>PFA  ( ffa -- pfa )  dup c@ ( extpfa ) + ;

: LFA>BFA     ( lfa -- bfa )    [ 3 4* ] {#,} - ;
: LFA>HFA     ( lfa -- hfa )    lfa>bfa bfa>hfa ;
: LFA>SFA     ( lfa -- sfa )    lfa>bfa bfa>sfa ;
: LFA>VFA     ( lfa -- vfa )    lfa>bfa bfa>vfa ;
: LFA>XFA     ( lfa -- xfa )    lfa>bfa bfa>xfa ;
: LFA>WFA     ( lfa -- wfa )    lfa>bfa bfa>wfa ;
: LFA>DFA     ( lfa -- dfa )    lfa>wfa wfa>dfa ;
: LFA>FFA     ( lfa -- ffa )    lfa>dfa dfa>ffa ;
: LFA>CFA     ( lfa -- cfa )    lfa>dfa dfa>cfa ;
: LFA>PFA     ( lfa -- pfa )    lfa>ffa ffa>pfa ;
: LFA>NFA     ( lfa -- nfa )    lfa>wfa wfa>nfa ;
: LFA>WLEN    ( lfa -- wlen^ )  lfa>wfa wfa>wlen ;
: LFA>VOCID   ( lfa -- vocid )  lfa>wfa wfa>vocid ;
: LFA>OPTINFO ( lfa -- optinfo) lfa>wfa wfa>optinfo ;

: XFA>LFA  ( xfa -- lfa )  [ 1 4* ] {#,} + ;
: XFA>HFA  ( xfa -- hfa )  xfa>lfa lfa>hfa ;
: XFA>BFA  ( xfa -- bfa )  xfa>lfa lfa>bfa ;
: XFA>SFA  ( xfa -- sfa )  xfa>lfa lfa>sfa ;
: XFA>VFA  ( xfa -- vfa )  xfa>lfa lfa>vfa ;
: XFA>WFA  ( xfa -- wfa )  xfa>lfa lfa>wfa ;
: XFA>FFA  ( xfa -- lfa )  xfa>lfa lfa>ffa ;
: XFA>CFA  ( xfa -- cfa )  xfa>lfa lfa>cfa ;
: XFA>NFA  ( xfa -- nfa )  xfa>lfa lfa>nfa ;
: XFA>DFA  ( xfa -- dfa )  xfa>wfa wfa>dfa ;

: CFA>DFA     ( cfa -- dfa )    [ 2 4* ] {#,} - ;
: CFA>FFA     ( cfa -- ffa )    [ 1 4* ] {#,} - ;
: CFA>PFA     ( cfa -- pfa )    cfa>ffa ffa>pfa ;
: CFA>WFA     ( cfa -- wfa )    cfa>dfa dfa>wfa ;
: CFA>LFA     ( cfa -- lfa )    cfa>wfa wfa>lfa ;
: CFA>BFA     ( cfa -- bfa )    cfa>wfa wfa>bfa ;
: CFA>NFA     ( cfa -- nfa )    cfa>wfa wfa>nfa ;
: CFA>WLEN    ( cfa -- wlen^)   cfa>wfa wfa>wlen ;
: CFA>VOCID   ( cfa -- vocid)   cfa>wfa wfa>vocid ;
: CFA>OPTINFO ( cfa -- optinfo) cfa>wfa wfa>optinfo ;

;; only for "does>" words, no checks
: DOES-PFA>CFA  ( does-pfa -- cfa )  12 - ;
end-module DART


extend-module SYSTEM
using dart

: LATEST-LFA   ( -- lfa )  current@ voc-latest-lfa-ofs + @ ;
: LATEST-HFA   ( -- hfa )  latest-lfa lfa>hfa ;
: LATEST-CFA   ( -- cfa )  latest-lfa lfa>cfa ;
: LATEST-FFA   ( -- ffa )  latest-lfa lfa>ffa ;
: LATEST-PFA   ( -- pfa )  latest-lfa lfa>pfa ;
: LATEST-NFA   ( -- nfa )  latest-lfa lfa>nfa ;
: LATEST-VOCID ( -- vocid) latest-cfa cfa>vocid ;

: UVAR-OFS   ( cfa-xt -- offset )  dup uservar? not?error" not a user var" cfa>pfa @ ;

: CFA>FFA@  ( cfa -- [ffa] )  cfa>ffa @ ;

: (ALIAS@) ( cfa-xt -- alias-cfa )  cfa>pfa @ ;
: ALIAS@   ( cfa-xt -- alias-cfa )  dup alias? not?error" alias expected" (alias@) ;

: RESOLVE-ALIAS  ( cfa-xt -- cfa-xt )  << dup alias? ?^| (alias@) |? v|| >> ;

: SMUDGED?  ( cfa-xt -- flag )  cfa>lfa lfa>hfa @ 1 mask? ;

: IMMEDIATE? ( cfa-xt -- flag )  cfa>ffa@ wflag-immediate mask? ;
: PRIVATE?   ( cfa-xt -- flag )  cfa>ffa@ wflag-private mask? ;
: PROTECTED? ( cfa-xt -- flag )  cfa>ffa@ wflag-protected mask? ;
: NORETURN?  ( cfa-xt -- flag )  cfa>ffa@ wflag-noreturn mask? ;
: PUBLISHED? ( cfa-xt -- flag )  cfa>ffa@ wflag-published mask? ;

end-module SYSTEM


: N-ALLOT  ( n -- addr )  dup 0< ?error" negative allot" here swap (dp+!) ;
: UNALLOT  ( n )  dup 0< ?error" negative unallot" negate (dp+!) ;
: ALLOT    ( n )  n-allot drop ;

;; allot, fill with zeroes
: N-ALLOT-0  ( n -- addr )  dup n-allot tuck swap erase ;
: ALLOT-0    ( n )  n-allot-0 drop ;


: N-ALIGN-HERE  ( size )
  dup 0?exit< drop >?
  here over umod dup not?exit< 2drop >?
  - (dp@) over $90 fill \ erase
  (dp+!) ;

: N-HDR-ALIGN-HERE  ( size )
  dup 0?exit< drop >?
  hdr-here over umod dup not?exit< 2drop >?
  - (hdr-dp@) over erase (hdr-dp+!) ;

\ : ALIGN-HERE    << here [{ system:code-align 1- }] [[{#,}]] and ?^| 0 c, |? v|| >> ;
\ : ALIGN-HERE-4  << here 3 and ?^| 0 c, |? v|| >> ;
\ : ALIGN-HERE    system:code-align n-align-here ;
: ALIGN-HERE-4  4 n-align-here ;

\ : HDR-ALIGN-HERE  << hdr-here 3 and ?^| 0 hdr-c, |? v|| >> ;
: HDR-ALIGN-HERE  4 n-hdr-align-here ;


;; simple peephole optimiser
extend-module SYSTEM

;; negative: aggressive inline
;; positive: no inline
0 quan Succubus-noinline-mark


;; define code access words for Succubus
module Succubus
<disable-hash>
<published-words>

: code-dd,    , ;
: code-dw,    w, ;
: code-db,    c, ;
: code-@      @ ;
: code-w@     w@ ;
: code-c@     c@ ;
: code-!      ! ;
: code-w!     w! ;
: code-c!     c! ;
: code-here   here ;
: code-unallot  unallot ;

: (finish-bblock-hook)  ;

: optinfo-start  ( -- )  hdr-here latest-lfa dart:lfa>optinfo ! ;
: optinfo-dw,  hdr-w, ;
: optinfo-db,  hdr-c, ;
: optinfo-finish ;

end-module Succubus

$include "Succubus/Succubus-05-code-api.f"

extend-module Succubus

: #inline-bytes
  Succubus-noinline-mark dup -?exit< drop 8192 >?
  ?< 0 || #current-inline-bytes >? ;


: debug-inline-started ;
: debug-inline-finished ;
: debug-inliner-failed ;
: debug-.latest-name ;
: debug-.current-cfa-name ;
: debug-colon-started ;
: debug-colon-finished ;
: debug-code-started ;
: debug-code-finished ;

: var-addr  dart:cfa>pfa ;
: const-value  dart:cfa>pfa @ ;
: uvar-offset  dart:cfa>pfa @ ;

: set-last-word-length  here latest-cfa - latest-lfa dart:lfa>wlen ! ;
: cfa-ffa@  ( -- [ffa] )  dart:cfa>ffa @ ;
: cfa>optinfo  ( -- optinfo^ )  dart:cfa>optinfo ;
: cfa-wlen@  ( -- wlen )  dart:cfa>wlen @ ;

: ss-latest-cfa  ( -- cfa )  latest-cfa ;
: ss-cfa>pfa  ( cfa -- pfa )  dart:cfa>pfa ;
;; it is guaranteed to be called only on "DOES>" words
: ss-doer@  ( cfa -- doer-cfa )  8 + @ ;

: immediate-word?  ( -- bool-flag)  Succubus:current-[ffa] wflag-immediate mask? ;
: noreturn-word?  ( -- bool-flag)  Succubus:current-[ffa] wflag-noreturn mask? ;
: inline-blocker-word?  ( -- bool-flag)  Succubus:current-[ffa] wflag-inline-blocker mask? ;
: inline-allowed-word?  ( -- bool-flag)  Succubus:current-[ffa] wflag-inline-allowed mask? ;
: inline-force-word?  ( -- bool-flag)  Succubus:current-[ffa] wflag-inline-force mask? ;
: no-stacks-word?  ( -- bool-flag)  Succubus:current-[ffa] wflag-no-stacks mask? ;

: not-inlineable-word
  [ wflag-inline-allowed wflag-inline-force or ] {#,}
  latest-ffa ~and! ;

: inlineable-word  wflag-inline-allowed latest-ffa or! ;

: word-has-back-jumps  wflag-has-back-jumps latest-ffa or! ;
: has-back-jumps-word?  ( -- bool-flag)  Succubus:current-[ffa] wflag-has-back-jumps mask? ;


: get-special-handler  ( -- exec-cfa-xt // FALSE )
  Succubus:current-cfa cfa@
  dup uro-label@ do-constant - not?exit< drop spw-constant >?
  dup uro-label@ do-variable - not?exit< drop spw-variable >?
  dup uro-label@ do-does - not?exit< drop spw-does >?
  dup uro-label@ do-uservalue - not?exit< drop spw-uservalue >?
  dup uro-label@ do-uservar - not?exit< drop spw-uservar >?
  uro-label@ do-alias - not?error" no aliases yet"
  ;; check other specials
  Succubus:current-[ffa] wflag-dummy-word mask? not?exit&leave
  Succubus:current-cfa ['] forth:exit - not?exit< spw-exit >?
  Succubus:current-cfa ['] forth:?exit - not?exit< spw-?exit >?
  Succubus:current-cfa ['] forth:not?exit - not?exit< spw-not?exit >?
  Succubus:current-cfa ['] forth:?exit&leave - not?exit< spw-?exit&leave >?
  Succubus:current-cfa ['] forth:not?exit&leave - not?exit< spw-not?exit&leave >?
  Succubus:current-cfa ['] forth:0?exit - not?exit< spw-not?exit >?
  Succubus:current-cfa ['] forth:0?exit&leave - not?exit< spw-not?exit&leave >?
  \ HACK!
  " unknown dummy word \'" pad$:!
  Succubus:current-cfa dart:cfa>nfa idcount pad$:+
  " \'!" pad$:+  pad$:@ error ;

end-module Succubus

$include "Succubus/00-Succubus-loader.f"

: INITIAL-CG-SETUP
  Succubus:initialise
  [ tgt-aggressive-inliner not ] {#,} Succubus:disable-aggressive-inliner:!
  [ tgt-forth-inliner ] {#,} Succubus:allow-forth-inlining-analysis:! ;

end-module SYSTEM


;; The Main Compiling Word.
;; this does some attempts at code optimisation and inlining.
: \,  ( cfa-xt )
  system:resolve-alias
  system:Succubus:cc\, ;

;; compile literal
: #,  ( n )  system:Succubus:cc-#, ;

;; compile word which expects non-executable data in code stream.
: <\,  ( cfa-xt )  system:resolve-alias system:Succubus:cc\,-wdata ;
: \>               system:Succubus:cc-finish-wdata ;

;; compile string literal
: STR#,  ( addr count )  system:Succubus:cc-str#, ;
: RAW-STR#,  ( addr count )  system:Succubus:cc-raw-str#, ;

*: {#,}     system:comp? ?exit< #, >? ;
\ *: {STR#,}  system:comp? ?exit< str#, >? ;


: CODE-DICT-USED  ( -- bytes )  here (elf-base-addr) - ;
:  HDR-DICT-USED  ( -- bytes )  hdr-here (elf-hdr-base-addr) - ;
