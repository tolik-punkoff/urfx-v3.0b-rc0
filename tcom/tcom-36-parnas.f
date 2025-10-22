;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TCOM generalized Parnas' iterators
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
<< cond [COR cond]* [CAND cond] ?^| ... |?
   cond [COR cond]* [CAND cond] ?v| ... |?
   else| ...
>>

i omited `init` predicate, because in Forth it is easy to factor it into
separate word (much easier than in other languages), and implementing
`init` efficiently requires extra branch at "<<". actually, several chained
branches, tracking of `init` in conditions, and such.

note that COR and CAND both doing "short-circuiting", jumping directly to
the corresponding "?.|" (or after the respective "|"). this nicely (and
efficiently) solves the problem with short-circuit boolean evaluation
without introducing a new control structure.

the last predicate should be either "else|", or non-conditional arrow ("^|"
or "v|"). the compiler will complain if you'll forget to do it.

you can use "^| ... |", or slightly more optimal "^||" as the last
predicate. of course, down arrow is allowed too. it is your responsbility
to not write any code after an unconditional arrow (you can do it, but it is
completely useless).

one useful extension is "nested checks". it can be used to avoid
unnecessary stack manipulations, and carrying a flag around.

  ?<| some-code |>

this can be used instead of any "?.| ... |", and can be nested. this
"substructure" can contain futher checks, which repeat or exit the parent
"<< ... >>". this allows to factor the common part of several guard
expressions, evaluate it only once, and avoid passing it around (hence
eliminating extra stack manipulation).

  somecond ?<|
    cond1 ?^| ... |?
    cond2 ?v| ... |?
  |>

there is no BREAK/CONTINUE for this control structure.

if your branches have no code, it is slightly more efficient to use "?^||"
and "^v||" words.

it is also possible to use "of?^|", "of?v|" and so on to implement "CASE".
it works as an ordinary "CASE" (i.e. drops the value on successfull check).

there is "?of?.|" construct. it expects the prepared condition. it can be
used to check ranges, or to perform other non-standard tests:

  dup 1 3 within ?of?v| ... |?
  dup 5 > ?of?v| ... |?

note the "DUP" -- you have to keep the value you are testing. basically,
"n of?.|" is just an optimised "dup n = ?of?.|".
*)

extend-module TCOM

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compiler helpers
;;

$b0de_c001 constant PAIR-IF
$b0de_c002 constant PAIR-IFELSE
$b0de_c003 constant PAIR-IFEXIT
;; Parnas' iterator pairs
$b0de_c010 constant PAIR-<<
$b0de_c011 constant PAIR-SHORT -- short-circuit boolean
$b0de_c012 constant PAIR-?<|
$b0de_c013 constant PAIR-?^|
$b0de_c014 constant PAIR-?v|
$b0de_c015 constant PAIR-^|
$b0de_c016 constant PAIR-v|


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compiler helpers
;;

;; the order allows using "1 xor" to invert the branch
enum{
  def: none-0
  def: none-1

  def: 0brn
  def: tbrn
  def: +brn
  def: -0brn
  def: -brn
  def: +0brn
  def: brn
  def: brnn

  def: of=brn
  def: of<>brn

  ;; special ZX branches, used by the optimiser
  def: <>brn
  def: =brn
  def: <brn
  def: >=brn
  def: >brn
  def: <=brn
}

|: zx/0brn,    zsys-run: 0BRANCH ;
|: zx/tbrn,    zsys-run: TBRANCH ;
|: zx/+brn,    zsys-run: +BRANCH ;
|: zx/-0brn,   zsys-run: -0BRANCH ;
|: zx/-brn,    zsys-run: -BRANCH ;
|: zx/+0brn,   zsys-run: +0BRANCH ;
|: zx/brn,     zsys-run: BRANCH ;
|: zx/of=brn,  zsys-run: =BRANCH-ND ; -- the caller should compile DROP after creating a chain!
|: zx/of<>brn, zsys-run: <>BRANCH-ND ; -- the caller should compile DROP after creating a chain!
;; special ZX branches, used by the optimiser
|: zx/<>brn,   zsys-run: <>BRANCH ;
|: zx/=brn,    zsys-run: =BRANCH ;
|: zx/<brn,    zsys-run: <BRANCH ;
|: zx/>=brn,   zsys-run: >=BRANCH ;
|: zx/>brn,    zsys-run: >BRANCH ;
|: zx/<=brn,   zsys-run: <=BRANCH ;

create xbrn
  ['] zx/0brn, ,
  ['] zx/tbrn, ,
  ['] zx/+brn, ,
  ['] zx/-0brn, ,
  ['] zx/-brn, ,
  ['] zx/+0brn, ,
  ['] zx/brn, ,
  ['] zx/brn, ,
  ['] zx/of=brn, ,
  ['] zx/of<>brn, ,
  ;; special ZX branches, used by the optimiser
  ['] zx/<>brn, ,
  ['] zx/=brn, ,
  ['] zx/<brn, ,
  ['] zx/>=brn, ,
  ['] zx/>brn, ,
  ['] zx/<=brn, ,
create;

: zx-brn,  ( brtype )
  0brn - dup ( of<>brn) <=brn u> ?error" invalid zx branch"
  xbrn dd-nth @execute-tail ;


enum{
  def: bropt-if
  def: bropt-if-exit
  def: bropt-loop-again
  def: bropt-loop-exit
  def: bropt-loop-again-nb
  def: bropt-loop-exit-nb
}

0 quan bropt-ptype


: (bropt-do-xbrn)  ( brn -- brn )  ;


: bropt-xbrn-check  ( brn -- brn )
  bropt-if bropt-ptype:! (bropt-do-xbrn) ;

: bropt-xbrn-check-exit  ( brn -- brn )
  bropt-if-exit bropt-ptype:! (bropt-do-xbrn) ;

: bropt-xbrn-loop-again  ( brn -- brn )
  bropt-loop-again bropt-ptype:! (bropt-do-xbrn) ;

: bropt-xbrn-loop-exit  ( brn -- brn )
  bropt-loop-exit bropt-ptype:! (bropt-do-xbrn) ;

: bropt-xbrn-loop-again-nb  ( brn -- brn )
  bropt-loop-again-nb bropt-ptype:! (bropt-do-xbrn) ;

: bropt-xbrn-loop-exit-nb  ( brn -- brn )
  bropt-loop-exit-nb bropt-ptype:! (bropt-do-xbrn) ;

;; if/else helper
: (IF-COMMON)     ( brnid -- chain pair-id )  zx-?comp bropt-xbrn-check zx-brn, zx-mark> pair-if ;
: (IFEXIT-COMMON) ( brnid -- chain pair-id )  zx-?comp bropt-xbrn-check-exit zx-brn, zx-mark> pair-ifexit ;


module PARNAS-SUPPORT
<disable-hash>

;; Parnas' iterator helpers

0 quan PITTI-CONT
0 quan PITTI-BREAK
0 quan PITTI-NESTED
0 quan PITTI-ELSE?

: SYS-RESET
  pitti-cont:!0 pitti-break:!0
  pitti-nested:!0 pitti-else?:!0 ;

: ?NO-ELSE  pitti-else? ?error" no guards allowed after \'ELSE|\' PITTY branch" ;
: ?NO-NEST  pitti-nested ?error" unclosed PITTI nesting" ;

: PARNAS-NEST    pitti-nested:1+! ;
: PARNAS-UNNEST  pitti-nested:1-! ;
: PARNAS-ELSE    pitti-nested 0= pitti-else?:+! ;

: RESOLVE-PARNAS-SHORT  ( short-cont short-break brncfa -- short-break )
  dup ?< zx-brn, zx-chain> || drop >? swap zx-resolve> ;

;; this consumes the optional "short" info, and leaves the following:
;; ( short-break-chain over-jump-mark/0 newmark )
: PARNAS-BRANCH  ( prev-triplet brncfa newmark -- overbrn newmark )
  zx-?comp ?no-else >r over pair-short = ?< swap drop resolve-parnas-short
  || over pair-<< pair-?<| system:?2pairs dup ?< zx-brn, zx-mark> >? >? r> ;

: PARNAS-CONT   pitti-cont brn zx-brn, zx-<resolve ;
: PARNAS-BREAK  pitti-break brn zx-brn, zx-chain> pitti-break:! ;

: PARNAS-END  ( overbrn mark )
  dup pair-?^| pair-?v| system:?2pairs
  pair-?^| = ?< parnas-cont || parnas-break >? zx-resolve> ;

: INVERT-BRANCH  ( brn )  1 xor ;

: PARNAS-SHORTINV  ( prev-triplet brncfa newmark -- overbrn newmark )
  swap invert-branch swap
  pair-?^| = ?< pitti-cont swap zx-brn, zx-<resolve
  || pitti-break swap zx-brn, zx-chain> pitti-break:! >? ;

;;TODO: optimise this!
: PARNAS-BRANCH-EMPTY  ( prev-triplet brncfa newmark -- overbrn newmark )
  zx-?comp ?no-else >r over pair-short = ?exit< r> parnas-branch parnas-end >?
  r> parnas-shortinv ;
end-module


extend-module SHADOW-HELPERS
\ module zx-flowctl
\ using zx-system
using parnas-support
<published-words>


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; David Parnas' IT/TI flow control structure

*: <<
  zx-?comp pitti-cont pitti-break pitti-else? pitti-nested
  zx-<mark
  pitti-cont:! pitti-break:!0 pitti-else?:!0 pitti-nested:!0
  pair-<< ;

*: >>
  zx-?comp pair-<< system:?pairs ?no-nest
  pitti-else? not?error" PITTI requires \'ELSE|\' or non-conditional guard "
  pitti-break zx-resolve>
  pitti-nested:! pitti-else?:! pitti-break:! pitti-cont:! ;

;; COR/CAND info: cont-chain is after "?.|" or "<|", break-chain is after
*: COR  zx-?comp ?no-else
  dup pair-short = ?< rot tbrn zx-brn, zx-chain> nrot
  || dup pair-<< pair-?<| system:?2pairs tbrn zx-brn, zx-mark> 0 pair-short >? ;

*: CAND  zx-?comp ?no-else
  dup pair-short = ?< swap 0brn zx-brn, zx-chain> swap
  || dup pair-<< pair-?<| system:?2pairs 0 0brn zx-brn, zx-mark> pair-short >? ;

*: |?  ( overbrn mark )  parnas-end ;

*: ?^|    0brn bropt-xbrn-loop-again pair-?^| parnas-branch ;
*: ?v|    0brn bropt-xbrn-loop-exit pair-?v| parnas-branch ;
*: not?^| tbrn bropt-xbrn-loop-again pair-?^| parnas-branch ;
*: not?v| tbrn bropt-xbrn-loop-exit pair-?v| parnas-branch ;
*: 0?^|   tbrn bropt-xbrn-loop-again pair-?^| parnas-branch ;
*: 0?v|   tbrn bropt-xbrn-loop-exit pair-?v| parnas-branch ;
*: -?^|   +0brn pair-?^| parnas-branch ;
*: -?v|   +0brn pair-?v| parnas-branch ;
*: +?^|   -0brn pair-?^| parnas-branch ;
*: +?v|   -0brn pair-?v| parnas-branch ;
*: -0?^|  +brn pair-?^| parnas-branch ;
*: -0?v|  +brn pair-?v| parnas-branch ;
*: +0?^|  -brn pair-?^| parnas-branch ;
*: +0?v|  -brn pair-?v| parnas-branch ;

*: of?^|    of<>brn pair-?^| parnas-branch zsys-run: DROP ;
*: of?v|    of<>brn pair-?v| parnas-branch zsys-run: DROP ;
*: <>of?^|  of=brn pair-?^| parnas-branch zsys-run: DROP ;
*: <>of?v|  of=brn pair-?v| parnas-branch zsys-run: DROP ;

*: of?^||    forth:[\\] of?^| forth:[\\] |? ;
*: of?v||    forth:[\\] of?v| forth:[\\] |? ;
*: <>of?^||  forth:[\\] <>of?^| forth:[\\] |? ;
*: <>of?v||  forth:[\\] <>of?v| forth:[\\] |? ;

;;  on skip: ( n cond -- n )
;; on enter: ( n cond -- )
;; this is basically a naked "case jump"
*: ?of?^|    0brn pair-?^| parnas-branch ;
*: ?of?v|    0brn pair-?v| parnas-branch ;
*: not?of?^| tbrn pair-?^| parnas-branch ;
*: not?of?v| tbrn pair-?v| parnas-branch ;
*: 0?of?^|   forth:[\\] not?of?^| ;
*: 0?of?v|   forth:[\\] not?of?v| ;

*: ?of?^||    forth:[\\] ?of?^| forth:[\\] |? ;
*: ?of?v||    forth:[\\] ?of?v| forth:[\\] |? ;
*: not?of?^|| forth:[\\] not?of?^| forth:[\\] |? ;
*: not?of?v|| forth:[\\] not?of?v| forth:[\\] |? ;
*: 0?of?^||   forth:[\\] 0?of?^| forth:[\\] |? ;
*: 0?of?v||   forth:[\\] 0?of?v| forth:[\\] |? ;

*: else|
  zx-?comp ?no-else ?no-nest
  dup pair-<< pair-?<| system:?2pairs parnas-else ;

*: ?^||    0brn bropt-xbrn-loop-again-nb pair-?^| parnas-branch-empty ;
*: ?v||    0brn bropt-xbrn-loop-exit-nb pair-?v| parnas-branch-empty ;
*: not?^|| tbrn bropt-xbrn-loop-again-nb pair-?^| parnas-branch-empty ;
*: not?v|| tbrn bropt-xbrn-loop-exit-nb pair-?v| parnas-branch-empty ;
*: 0?^||   forth:[\\] not?^|| ;
*: 0?v||   forth:[\\] not?v|| ;
*: -?^||   +0brn pair-?^| parnas-branch-empty ;
*: -?v||   +0brn pair-?v| parnas-branch-empty ;
*: +?^||   -0brn pair-?^| parnas-branch-empty ;
*: +?v||   -0brn pair-?v| parnas-branch-empty ;
*: -0?^||  +brn pair-?^| parnas-branch-empty ;
*: -0?v||  +brn pair-?v| parnas-branch-empty ;
*: +0?^||  -brn pair-?^| parnas-branch-empty ;
*: +0?v||  -brn pair-?v| parnas-branch-empty ;

*: ^|  dup pair-<< pair-?<| system:?2pairs 0 pair-^| parnas-branch parnas-else ;
*: v|  dup pair-<< pair-?<| system:?2pairs 0 pair-v| parnas-branch parnas-else ;

;; it is your responsitibility to NOT put any code after "|"
*: |  ( overbrn mark )
  dup pair-^| pair-v| system:?2pairs
  pair-^| = ?< parnas-cont || pitti-nested ?< parnas-break >? >?
  zx-resolve> ;

*: ^||  dup pair-<< pair-?<| system:?2pairs parnas-cont parnas-else ;
*: v||  dup pair-<< pair-?<| system:?2pairs pitti-nested ?< parnas-break >? parnas-else ;

*: |>   ( overbrn mark )  pair-?<| system:?pairs zx-resolve> parnas-unnest ;
*: ?<|     dup pair-<< pair-short system:?2pairs 0brn pair-?<| parnas-branch parnas-nest ;
*: not?<|  dup pair-<< pair-short system:?2pairs tbrn pair-?<| parnas-branch parnas-nest ;
*: 0?<|    forth:[\\] not?<| ;
*: -?<|    dup pair-<< pair-short system:?2pairs +0brn pair-?<| parnas-branch parnas-nest ;
*: +?<|    dup pair-<< pair-short system:?2pairs -0brn pair-?<| parnas-branch parnas-nest ;
*: -0?<|   dup pair-<< pair-short system:?2pairs +brn pair-?<| parnas-branch parnas-nest ;
*: +0?<|   dup pair-<< pair-short system:?2pairs -brn pair-?<| parnas-branch parnas-nest ;


*: >?  zx-?comp dup pair-ifexit = ?< drop pair-if zsys-run: EXIT >?
                pair-if pair-ifelse system:?2pairs zx-resolve> ;

*: ||  zx-?comp pair-if system:?pairs brn zx-brn, zx-mark>
                swap zx-resolve> pair-ifelse ;

*: ?exit<     0brn (ifexit-common) ;
*: not?exit<  tbrn (ifexit-common) ;
*: 0?exit<    forth:[\\] not?exit< ;
*: -?exit<    +0brn (ifexit-common) ;
*: +?exit<    -0brn (ifexit-common) ;
*: -0?exit<   +brn (ifexit-common) ;
*: +0?exit<   -brn (ifexit-common) ;

*: ?<     0brn (if-common) ;
*: not?<  tbrn (if-common) ;
*: 0?<    forth:[\\] not?< ;
*: -?<    +0brn (if-common) ;
*: +?<    -0brn (if-common) ;
*: -0?<   +brn (if-common) ;
*: +0?<   -brn (if-common) ;


(*
VMF-QRET-OPCODES? [IFNOT]
*: ?exit
  zx-?comp
  vm:0branch zx-opc, zx-mark>
    vm:ret zx-opc,
  zx-resolve> ;

*: not?exit
  zx-?comp
  vm:tbranch zx-opc, zx-mark>
    vm:ret zx-opc,
  zx-resolve> ;

*: ?exit&leave
  zx-?comp
  vm:dup zx-opc, vm:0branch zx-opc, zx-mark>
    vm:ret zx-opc,
  zx-resolve>
  vm:drop zx-opc, ;

*: not?exit&leave
  zx-?comp
  vm:dup zx-opc, vm:tbranch zx-opc, zx-mark>
    vm:ret zx-opc,
  zx-resolve>
  vm:drop zx-opc, ;
[ENDIF]
*)

end-module  \ HELPERS
end-module  \ TCOM
