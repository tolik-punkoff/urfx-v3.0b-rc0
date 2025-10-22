;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; various flow control words (only as shadows)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module tcom-support
<disable-hash>
using tgt-forwards

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compiler helpers
;;

: (tgt-if-common)     ( branch-cfa )  system:?comp Succubus:mark-j>-brn system:pair-if ;
: (tgt-ifexit-common) ( branch-cfa )  system:?comp Succubus:mark-j>-brn system:pair-ifexit ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; David Parnas' IT/TI flow control structure support

0 quan pitti-cont
0 quan pitti-break
0 quan pitti-nested
false quan pitti-else?

: ?no-else  pitti-else? ?error" no guards allowed after \'ELSE|\' PITTI branch" ;
: ?no-nest  pitti-nested ?error" unclosed PITTI nesting" ;

: parnas-nest    pitti-nested:1+! ;
: parnas-unnest  pitti-nested:1-! ;
: parnas-else    pitti-nested 0= pitti-else?:+! ;

: resolve-parnas-short  ( short-cont short-break brncfa -- short-break )
  dup ?< Succubus:chain-j>-brn || drop >? swap Succubus:resolve-j> ;

;; this consumes the optional "short" info, and leaves the following:
;; ( short-break-chain over-jump-mark/0 newmark )
: parnas-branch  ( prev-triplet brncfa newmark -- overbrn newmark )
  system:?comp ?no-else >r over system:pair-short = ?< swap drop resolve-parnas-short
  || over system:pair-<< system:pair-?<| system:?2pairs dup ?< Succubus:mark-j>-brn >? >? r> ;

: parnas-cont   pitti-cont Succubus:(branch) Succubus:<j-resolve-brn ;
: parnas-break  pitti-break Succubus:(branch) Succubus:chain-j>-brn pitti-break:! ;

: parnas-end  ( overbrn mark )
  dup system:pair-?^| system:pair-?v| system:?2pairs
  system:pair-?^| = ?< parnas-cont || parnas-break >? Succubus:resolve-j> ;

: parnas-shortinv  ( prev-triplet brncfa newmark -- overbrn newmark )
  swap Succubus:invert-branch swap
  system:pair-?^| = ?< pitti-cont swap Succubus:<j-resolve-brn
  || pitti-break swap Succubus:chain-j>-brn pitti-break:! >? ;

;;TODO: optimise this!
: parnas-branch-empty  ( prev-triplet brncfa newmark -- overbrn newmark )
  system:?comp ?no-else >r over system:pair-short = ?exit< r> parnas-branch parnas-end >?
  r> parnas-shortinv ;

end-module tcom-support


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; if/else/endif

extend-module FORTH
\ using system
using tcom-support
using tgt-forwards

tcf: ?exit<     Succubus:(0branch) (tgt-ifexit-common) ;tcf
tcf: not?exit<  Succubus:(tbranch) (tgt-ifexit-common) ;tcf
tcf: 0?exit<    Succubus:(tbranch) (tgt-ifexit-common) ;tcf
tcf: -?exit<    Succubus:(+0branch) (tgt-ifexit-common) ;tcf
tcf: +?exit<    Succubus:(-0branch) (tgt-ifexit-common) ;tcf
tcf: -0?exit<   Succubus:(+branch) (tgt-ifexit-common) ;tcf
tcf: +0?exit<   Succubus:(-branch) (tgt-ifexit-common) ;tcf

tcf: ?<     Succubus:(0branch) (tgt-if-common) ;tcf
tcf: not?<  Succubus:(tbranch) (tgt-if-common) ;tcf
tcf: 0?<    Succubus:(tbranch) (tgt-if-common) ;tcf
tcf: -?<    Succubus:(+0branch) (tgt-if-common) ;tcf
tcf: +?<    Succubus:(-0branch) (tgt-if-common) ;tcf
tcf: -0?<   Succubus:(+branch) (tgt-if-common) ;tcf
tcf: +0?<   Succubus:(-branch) (tgt-if-common) ;tcf
tcf: >?     system:?comp dup system:pair-ifexit =
            ?< drop system:pair-if tgt-(exit) tgt-cc\, >?
            system:pair-if system:pair-ifelse system:?2pairs Succubus:resolve-j> ;tcf
tcf: ||     system:?comp system:pair-if system:?pairs
            Succubus:(branch) Succubus:mark-j>-brn swap Succubus:resolve-j>
            system:pair-ifelse ;tcf


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; David Parnas' IT/TI flow control structure

tcf: <<
  system:?comp pitti-cont pitti-break pitti-else? pitti-nested
  Succubus:<j-mark pitti-cont:! pitti-break:!0 pitti-else?:!0 pitti-nested:!0
  system:pair-<< ;tcf

tcf: >>
  system:?comp system:pair-<< system:?pairs ?no-nest
  pitti-else? not?error" PITTI requires \'ELSE|\' or non-conditional guard "
  pitti-break Succubus:resolve-j>
  pitti-nested:! pitti-else?:! pitti-break:! pitti-cont:! ;tcf

;; COR/CAND info: cont-chain is after "?.|" or "<|", break-chain is after
tcf: COR  system:?comp ?no-else
  dup system:pair-short = ?< rot Succubus:(tbranch) Succubus:chain-j>-brn nrot
  || dup system:pair-<< system:pair-?<| system:?2pairs
     Succubus:(tbranch) Succubus:mark-j>-brn 0 system:pair-short >? ;tcf

tcf: CAND  system:?comp ?no-else
  dup system:pair-short = ?< swap Succubus:(0branch) Succubus:chain-j>-brn swap
  || dup system:pair-<< system:pair-?<| system:?2pairs
     0 Succubus:(0branch) Succubus:mark-j>-brn system:pair-short >? ;tcf

tcf: ?^|    Succubus:(0branch) system:pair-?^| parnas-branch ;tcf
tcf: ?v|    Succubus:(0branch) system:pair-?v| parnas-branch ;tcf
tcf: not?^| Succubus:(tbranch) system:pair-?^| parnas-branch ;tcf
tcf: not?v| Succubus:(tbranch) system:pair-?v| parnas-branch ;tcf
tcf: 0?^|   Succubus:(tbranch) system:pair-?^| parnas-branch ;tcf
tcf: 0?v|   Succubus:(tbranch) system:pair-?v| parnas-branch ;tcf
tcf: -?^|   Succubus:(+0branch) system:pair-?^| parnas-branch ;tcf
tcf: -?v|   Succubus:(+0branch) system:pair-?v| parnas-branch ;tcf
tcf: +?^|   Succubus:(-0branch) system:pair-?^| parnas-branch ;tcf
tcf: +?v|   Succubus:(-0branch) system:pair-?v| parnas-branch ;tcf
tcf: -0?^|  Succubus:(+branch) system:pair-?^| parnas-branch ;tcf
tcf: -0?v|  Succubus:(+branch) system:pair-?v| parnas-branch ;tcf
tcf: +0?^|  Succubus:(-branch) system:pair-?^| parnas-branch ;tcf
tcf: +0?v|  Succubus:(-branch) system:pair-?v| parnas-branch ;tcf

tcf: of?^|    Succubus:(of<>branch) system:pair-?^| parnas-branch ;tcf
tcf: of?v|    Succubus:(of<>branch) system:pair-?v| parnas-branch ;tcf
tcf: <>of?^|  Succubus:(of=branch) system:pair-?^| parnas-branch ;tcf
tcf: <>of?v|  Succubus:(of=branch) system:pair-?v| parnas-branch ;tcf

;;  on skip: ( n cond -- n )
;; on enter: ( n cond )
;; this is basically a naked "case jump"
tcf: ?of?^|    Succubus:(case-0branch) system:pair-?^| parnas-branch ;tcf
tcf: ?of?v|    Succubus:(case-0branch) system:pair-?v| parnas-branch ;tcf
tcf: not?of?^| Succubus:(case-tbranch) system:pair-?^| parnas-branch ;tcf
tcf: not?of?v| Succubus:(case-tbranch) system:pair-?v| parnas-branch ;tcf
tcf: 0?of?^|   Succubus:(case-tbranch) system:pair-?^| parnas-branch ;tcf
tcf: 0?of?v|   Succubus:(case-tbranch) system:pair-?v| parnas-branch ;tcf

tcf: else|
  system:?comp ?no-else ?no-nest
  dup system:pair-<< system:pair-?<| system:?2pairs parnas-else ;tcf

tcf: |?  ( overbrn mark )  parnas-end ;tcf

tcf: ?^||    Succubus:(0branch) system:pair-?^| parnas-branch-empty ;tcf
tcf: ?v||    Succubus:(0branch) system:pair-?v| parnas-branch-empty ;tcf
tcf: not?^|| Succubus:(tbranch) system:pair-?^| parnas-branch-empty ;tcf
tcf: not?v|| Succubus:(tbranch) system:pair-?v| parnas-branch-empty ;tcf
tcf: 0?^||   Succubus:(tbranch) system:pair-?^| parnas-branch-empty ;tcf
tcf: 0?v||   Succubus:(tbranch) system:pair-?v| parnas-branch-empty ;tcf
tcf: -?^||   Succubus:(+0branch) system:pair-?^| parnas-branch-empty ;tcf
tcf: -?v||   Succubus:(+0branch) system:pair-?v| parnas-branch-empty ;tcf
tcf: +?^||   Succubus:(-0branch) system:pair-?^| parnas-branch-empty ;tcf
tcf: +?v||   Succubus:(-0branch) system:pair-?v| parnas-branch-empty ;tcf
tcf: -0?^||  Succubus:(+branch) system:pair-?^| parnas-branch-empty ;tcf
tcf: -0?v||  Succubus:(+branch) system:pair-?v| parnas-branch-empty ;tcf
tcf: +0?^||  Succubus:(-branch) system:pair-?^| parnas-branch-empty ;tcf
tcf: +0?v||  Succubus:(-branch) system:pair-?v| parnas-branch-empty ;tcf

tcf: of?^||     Succubus:(of<>branch) system:pair-?^| parnas-branch-empty ;tcf
tcf: of?v||     Succubus:(of<>branch) system:pair-?v| parnas-branch-empty ;tcf
tcf: <>of?^||   Succubus:(of=branch) system:pair-?^| parnas-branch-empty ;tcf
tcf: <>of?v||   Succubus:(of=branch) system:pair-?v| parnas-branch-empty ;tcf
tcf: ?of?^||    Succubus:(case-0branch) system:pair-?^| parnas-branch-empty ;tcf
tcf: ?of?v||    Succubus:(case-0branch) system:pair-?v| parnas-branch-empty ;tcf
tcf: not?of?^|| Succubus:(case-tbranch) system:pair-?^| parnas-branch-empty ;tcf
tcf: not?of?v|| Succubus:(case-tbranch) system:pair-?v| parnas-branch-empty ;tcf
tcf: 0?of?^||   Succubus:(case-tbranch) system:pair-?^| parnas-branch-empty ;tcf
tcf: 0?of?v||   Succubus:(case-tbranch) system:pair-?v| parnas-branch-empty ;tcf

tcf: ^|  dup system:pair-<< system:pair-?<| system:?2pairs 0 system:pair-^| parnas-branch parnas-else ;tcf
tcf: v|  dup system:pair-<< system:pair-?<| system:?2pairs 0 system:pair-v| parnas-branch parnas-else ;tcf

;; it is your responsitibility to NOT put any code after "|"
tcf: |  ( overbrn mark )
  dup system:pair-^| system:pair-v| system:?2pairs
  system:pair-^| = ?< parnas-cont || pitti-nested ?< parnas-break >? >?
  Succubus:resolve-j> ;tcf

tcf: ^||  dup system:pair-<< system:pair-?<| system:?2pairs parnas-cont parnas-else ;tcf
tcf: v||  dup system:pair-<< system:pair-?<| system:?2pairs pitti-nested ?< parnas-break >? parnas-else ;tcf

tcf: |>   ( overbrn mark )  system:pair-?<| system:?pairs Succubus:resolve-j> parnas-unnest ;tcf
tcf: ?<|     dup system:pair-<< system:pair-short system:?2pairs Succubus:(0branch) system:pair-?<| parnas-branch parnas-nest ;tcf
tcf: not?<|  dup system:pair-<< system:pair-short system:?2pairs Succubus:(tbranch) system:pair-?<| parnas-branch parnas-nest ;tcf
tcf: 0?<|    dup system:pair-<< system:pair-short system:?2pairs Succubus:(tbranch) system:pair-?<| parnas-branch parnas-nest ;tcf
tcf: -?<|    dup system:pair-<< system:pair-short system:?2pairs Succubus:(+0branch) system:pair-?<| parnas-branch parnas-nest ;tcf
tcf: +?<|    dup system:pair-<< system:pair-short system:?2pairs Succubus:(-0branch) system:pair-?<| parnas-branch parnas-nest ;tcf
tcf: -0?<|   dup system:pair-<< system:pair-short system:?2pairs Succubus:(+branch) system:pair-?<| parnas-branch parnas-nest ;tcf
tcf: +0?<|   dup system:pair-<< system:pair-short system:?2pairs Succubus:(-branch) system:pair-?<| parnas-branch parnas-nest ;tcf

end-module FORTH
