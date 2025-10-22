;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; control flow words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
<< cond [COR cond]* [CAND cond]* ?^| ... |?
   cond [COR cond]* [CAND cond]* ?v| ... |?
   else| ...
>>

i omited `init` predicate, because in Forth it is easy to factor it into
separate word (much easier than in other languages), and implementing
`init` efficiently requires extra branch at "<<". actually, several chained
branches, tracking of `init` in conditions, and such.

note that COR and CAND are "short-circuit", jumping directly to the
corresponding "?.|" (or after the respective "|"). this nicely (and
efficiently) solves the problem with short-circuit boolean evaluation
without introducing a new control structure.

the last predicate should be either "else|", or non-conditional arrow
("^|" or "v|"). the compiler will complain if you forget about it.

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


;; FIXME: Uroborus wants it to be here instead of in SYSTEM. :-(
module if/else-syntax
<disable-hash>
end-module if/else-syntax

module parnas-syntax
<disable-hash>
end-module parnas-syntax

module cand-syntax
<disable-hash>
end-module cand-syntax

module cor-syntax
<disable-hash>
end-module cor-syntax


extend-module SYSTEM

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compiler helpers
;;

0xb0de_c001 constant PAIR-IF
0xb0de_c002 constant PAIR-IFELSE
0xb0de_c003 constant PAIR-IFEXIT
;; cand/cor
0xb0de_c006 constant PAIR-CAND/COR
0xb0de_c007 constant PAIR-CAND/COR-CONT
;; Parnas' iterator pairs
0xb0de_c010 constant PAIR-<<
0xb0de_c011 constant PAIR-SHORT -- short-circuit boolean
0xb0de_c012 constant PAIR-?<|
0xb0de_c013 constant PAIR-?^|
0xb0de_c014 constant PAIR-?v|
0xb0de_c015 constant PAIR-^|
0xb0de_c016 constant PAIR-v|


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compiler helpers
;;

: (CAND-ENTER)  push-ctx vocid: cand-syntax context! ;
: (CAND-LEAVE)  context@ vocid: cand-syntax = not?error" unbalanced cand" pop-ctx ;

: (COR-ENTER)  push-ctx vocid: cor-syntax context! ;
: (COR-LEAVE)  context@ vocid: cor-syntax = not?error" unbalanced cor" pop-ctx ;

: (IF/ELSE-ENTER)  push-ctx vocid: if/else-syntax context! ;
: (IF/ELSE-LEAVE)  context@ vocid: if/else-syntax = not?error" unbalanced if/else" pop-ctx ;

;; if/else helper
: (IF-COMMON)     ( branch-cfa )  ?comp Succubus:mark-j>-brn pair-if (if/else-enter) ;
: (IFEXIT-COMMON) ( branch-cfa )  ?comp Succubus:mark-j>-brn pair-ifexit (if/else-enter) ;


module PARNAS-SUPPORT
<disable-hash>

: (PARNAS-ENTER)  push-ctx vocid: parnas-syntax context! ;
: (PARNAS-LEAVE)  context@ vocid: parnas-syntax = not?error" unbalanced control flow" pop-ctx ;

;; Parnas' iterator helpers

0 quan PITTI-CONT
0 quan PITTI-BREAK
0 quan PITTI-NESTED
0 quan PITTI-ELSE?

;; could be called after compilation errors, to reset global state
: SYS-RESET
  pitti-cont:!0 pitti-break:!0
  pitti-nested:!0 pitti-else?:!0 ;

: ?NO-ELSE  pitti-else? ?error" no guards allowed after \'ELSE|\' PITTY branch" ;
: ?NO-NEST  pitti-nested ?error" unclosed PITTI nesting" ;

: PARNAS-NEST    pitti-nested:1+! ;
: PARNAS-UNNEST  pitti-nested:1-! ;
: PARNAS-ELSE    pitti-nested 0= pitti-else?:+! ;

;; short-circuit boolean
: RESOLVE-PARNAS-SHORT  ( short-cont short-break brncfa -- short-break )
  dup ?< Succubus:chain-j>-brn || drop >? swap Succubus:resolve-j> ;

;; this consumes the optional "short" info, and leaves the following:
;; ( short-break-chain over-jump-mark/0 newmark )
: PARNAS-BRANCH  ( prev-triplet brncfa newmark -- overbrn newmark )
  ?comp ?no-else >r over pair-short = ?< swap drop resolve-parnas-short
  || over pair-<< pair-?<| ?2pairs dup ?< Succubus:mark-j>-brn >? >? r> ;

: PARNAS-CONT   pitti-cont Succubus:(branch) Succubus:<j-resolve-brn ;
: PARNAS-BREAK  pitti-break Succubus:(branch) Succubus:chain-j>-brn pitti-break:! ;

: PARNAS-END  ( overbrn mark )
  dup pair-?^| pair-?v| ?2pairs
  pair-?^| = ?< parnas-cont || parnas-break >? Succubus:resolve-j> ;

: PARNAS-SHORTINV  ( prev-triplet brncfa newmark -- overbrn newmark )
  swap Succubus:invert-branch swap
  pair-?^| = ?< pitti-cont swap Succubus:<j-resolve-brn
  || pitti-break swap Succubus:chain-j>-brn pitti-break:! >? ;

;;TODO: optimise this!
: PARNAS-BRANCH-EMPTY  ( prev-triplet brncfa newmark -- overbrn newmark )
  ?comp ?no-else >r over pair-short = ?exit< r> parnas-branch parnas-end >?
  r> parnas-shortinv ;
end-module PARNAS-SUPPORT

end-module SYSTEM


extend-module FORTH
using system
using parnas-support

extend-module if/else-syntax
*: ||  ?comp pair-if ?pairs Succubus:(branch) Succubus:mark-j>-brn
             swap Succubus:resolve-j> pair-ifelse ;
end-module if/else-syntax

*: ?exit<     Succubus:(0branch) (ifexit-common) ;
*: not?exit<  Succubus:(tbranch) (ifexit-common) ;
*: 0?exit<    Succubus:(tbranch) (ifexit-common) ;
*: -?exit<    Succubus:(+0branch) (ifexit-common) ;
*: +?exit<    Succubus:(-0branch) (ifexit-common) ;
*: -0?exit<   Succubus:(+branch) (ifexit-common) ;
*: +0?exit<   Succubus:(-branch) (ifexit-common) ;

*: ?<     Succubus:(0branch) (if-common) ;
*: not?<  Succubus:(tbranch) (if-common) ;
*: 0?<    Succubus:(tbranch) (if-common) ;
*: -?<    Succubus:(+0branch) (if-common) ;
*: +?<    Succubus:(-0branch) (if-common) ;
*: -0?<   Succubus:(+branch) (if-common) ;
*: +0?<   Succubus:(-branch) (if-common) ;

*: >?  ?comp (if/else-leave) dup pair-ifexit = ?< drop pair-if \\ exit >?
             pair-if pair-ifelse ?2pairs Succubus:resolve-j> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; <?cand ... || ... || ... ?>
;; <?cor ... || ... || ... ?>

module cand/cor-support
<disable-hash>
: finish
  dup pair-cand/cor = ?exit< drop >?
  pair-cand/cor-cont ?pairs
  Succubus:resolve-j> ;

: next  ( start-pair brn // chain cont-pair brn -- chain cont-pair )
  ?comp
  \\ dup
  swap dup pair-cand/cor = ?< drop Succubus:mark-j>-brn ||
  pair-cand/cor-cont ?pairs Succubus:chain-j>-brn >?
  \\ drop pair-cand/cor-cont ;
end-module cand/cor-support

extend-module cand-syntax
*: ?>  ?comp (cand-leave) cand/cor-support:finish ;
*: &&  ?comp Succubus:(0branch) cand/cor-support:next ;
end-module cand-syntax

extend-module cor-syntax
*: ?>  ?comp (cor-leave) cand/cor-support:finish ;
*: ||  ?comp Succubus:(tbranch) cand/cor-support:next ;
end-module cor-syntax

*: <?cand  ?comp pair-cand/cor (cand-enter) ;
*: <?cor   ?comp pair-cand/cor (cor-enter) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; David Parnas' IT/TI flow control structure

*: <<  ( -- old-cont old-break old-else? old-nested pair-id )
  ?comp pitti-cont pitti-break pitti-else? pitti-nested
  Succubus:<j-mark
  pitti-cont:! pitti-break:!0 pitti-else?:!0 pitti-nested:!0
  pair-<<
  (parnas-enter) ;

end-module FORTH


extend-module parnas-syntax
using system
using parnas-support

*: >>  ( old-cont old-break old-else? old-nested pair-id )
  (parnas-leave)
  ?comp pair-<< ?pairs ?no-nest
  pitti-else? not?error" PITTI requires \'ELSE|\' or non-conditional guard "
  pitti-break Succubus:resolve-j>
  pitti-nested:! pitti-else?:! pitti-break:! pitti-cont:! ;

;; COR/CAND info: cont-chain is after "?.|" or "<|", break-chain is after
*: COR  ?comp ?no-else
  dup pair-short = ?< rot Succubus:(tbranch) Succubus:chain-j>-brn nrot
  || dup pair-<< pair-?<| ?2pairs Succubus:(tbranch) Succubus:mark-j>-brn 0 pair-short >? ;

*: CAND  ?comp ?no-else
  dup pair-short = ?< swap Succubus:(0branch) Succubus:chain-j>-brn swap
  || dup pair-<< pair-?<| ?2pairs 0 Succubus:(0branch) Succubus:mark-j>-brn pair-short >? ;

*: ?^|    Succubus:(0branch) pair-?^| parnas-branch ;
*: ?v|    Succubus:(0branch) pair-?v| parnas-branch ;
*: not?^| Succubus:(tbranch) pair-?^| parnas-branch ;
*: not?v| Succubus:(tbranch) pair-?v| parnas-branch ;
*: 0?^|   Succubus:(tbranch) pair-?^| parnas-branch ;
*: 0?v|   Succubus:(tbranch) pair-?v| parnas-branch ;
*: -?^|   Succubus:(+0branch) pair-?^| parnas-branch ;
*: -?v|   Succubus:(+0branch) pair-?v| parnas-branch ;
*: +?^|   Succubus:(-0branch) pair-?^| parnas-branch ;
*: +?v|   Succubus:(-0branch) pair-?v| parnas-branch ;
*: -0?^|  Succubus:(+branch) pair-?^| parnas-branch ;
*: -0?v|  Succubus:(+branch) pair-?v| parnas-branch ;
*: +0?^|  Succubus:(-branch) pair-?^| parnas-branch ;
*: +0?v|  Succubus:(-branch) pair-?v| parnas-branch ;

*: of?^|    Succubus:(of<>branch) pair-?^| parnas-branch ;
*: of?v|    Succubus:(of<>branch) pair-?v| parnas-branch ;
*: <>of?^|  Succubus:(of=branch) pair-?^| parnas-branch ;
*: <>of?v|  Succubus:(of=branch) pair-?v| parnas-branch ;

;; on skip: ( n cond -- n )
;; on enter: ( n cond )
;; this is basically a naked "case jump"
*: ?of?^|    Succubus:(case-0branch) pair-?^| parnas-branch ;
*: ?of?v|    Succubus:(case-0branch) pair-?v| parnas-branch ;
*: not?of?^| Succubus:(case-tbranch) pair-?^| parnas-branch ;
*: not?of?v| Succubus:(case-tbranch) pair-?v| parnas-branch ;
*: 0?of?^|   Succubus:(case-tbranch) pair-?^| parnas-branch ;
*: 0?of?v|   Succubus:(case-tbranch) pair-?v| parnas-branch ;

*: else|
  ?comp ?no-else ?no-nest
  dup pair-<< pair-?<| ?2pairs parnas-else ;

*: |?  ( overbrn mark )  parnas-end ;

*: ?^||    Succubus:(0branch) pair-?^| parnas-branch-empty ;
*: ?v||    Succubus:(0branch) pair-?v| parnas-branch-empty ;
*: not?^|| Succubus:(tbranch) pair-?^| parnas-branch-empty ;
*: not?v|| Succubus:(tbranch) pair-?v| parnas-branch-empty ;
*: 0?^||   Succubus:(tbranch) pair-?^| parnas-branch-empty ;
*: 0?v||   Succubus:(tbranch) pair-?v| parnas-branch-empty ;
*: -?^||   Succubus:(+0branch) pair-?^| parnas-branch-empty ;
*: -?v||   Succubus:(+0branch) pair-?v| parnas-branch-empty ;
*: +?^||   Succubus:(-0branch) pair-?^| parnas-branch-empty ;
*: +?v||   Succubus:(-0branch) pair-?v| parnas-branch-empty ;
*: -0?^||  Succubus:(+branch) pair-?^| parnas-branch-empty ;
*: -0?v||  Succubus:(+branch) pair-?v| parnas-branch-empty ;
*: +0?^||  Succubus:(-branch) pair-?^| parnas-branch-empty ;
*: +0?v||  Succubus:(-branch) pair-?v| parnas-branch-empty ;

*: of?^||     Succubus:(of<>branch) pair-?^| parnas-branch-empty ;
*: of?v||     Succubus:(of<>branch) pair-?v| parnas-branch-empty ;
*: <>of?^||   Succubus:(of=branch) pair-?^| parnas-branch-empty ;
*: <>of?v||   Succubus:(of=branch) pair-?v| parnas-branch-empty ;
*: ?of?^||    Succubus:(case-0branch) pair-?^| parnas-branch-empty ;
*: ?of?v||    Succubus:(case-0branch) pair-?v| parnas-branch-empty ;
*: not?of?^|| Succubus:(case-tbranch) pair-?^| parnas-branch-empty ;
*: not?of?v|| Succubus:(case-tbranch) pair-?v| parnas-branch-empty ;
*: 0?of?^||   Succubus:(case-tbranch) pair-?^| parnas-branch-empty ;
*: 0?of?v||   Succubus:(case-tbranch) pair-?v| parnas-branch-empty ;

*: ^|  dup pair-<< pair-?<| ?2pairs 0 pair-^| parnas-branch parnas-else ;
*: v|  dup pair-<< pair-?<| ?2pairs 0 pair-v| parnas-branch parnas-else ;

;; it is your responsitibility to NOT put any code after "|"
*: |  ( overbrn mark )
  dup pair-^| pair-v| ?2pairs
  pair-^| = ?< parnas-cont || pitti-nested ?< parnas-break >? >?
  Succubus:resolve-j> ;

*: ^||  dup pair-<< pair-?<| ?2pairs parnas-cont parnas-else ;
*: v||  dup pair-<< pair-?<| ?2pairs pitti-nested ?< parnas-break >? parnas-else ;

*: |>   ( overbrn mark )  pair-?<| ?pairs Succubus:resolve-j> parnas-unnest ;
*: ?<|     dup pair-<< pair-short ?2pairs Succubus:(0branch) pair-?<| parnas-branch parnas-nest ;
*: not?<|  dup pair-<< pair-short ?2pairs Succubus:(tbranch) pair-?<| parnas-branch parnas-nest ;
*: 0?<|    dup pair-<< pair-short ?2pairs Succubus:(tbranch) pair-?<| parnas-branch parnas-nest ;
*: -?<|    dup pair-<< pair-short ?2pairs Succubus:(+0branch) pair-?<| parnas-branch parnas-nest ;
*: +?<|    dup pair-<< pair-short ?2pairs Succubus:(-0branch) pair-?<| parnas-branch parnas-nest ;
*: -0?<|   dup pair-<< pair-short ?2pairs Succubus:(+branch) pair-?<| parnas-branch parnas-nest ;
*: +0?<|   dup pair-<< pair-short ?2pairs Succubus:(-branch) pair-?<| parnas-branch parnas-nest ;

end-module parnas-syntax
