;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some final statistics
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


." used user area bytes: " def-user-area-size 0.r, cr

: .plural  ( n )  1 <> ?exit< [char] s emit >? ;

: .stats
  tgt-word-count ., ." words compiled (" tgt-prim-count ., ." primitives).\n"
  Succubus:stat-words-inlineable ?<
    Succubus:stat-words-inlineable " inlineable word" .$plural ."  found.\n" >?
  Succubus:stat-direct-optim ?<
    Succubus:stat-direct-optim " direct memaccess optimisation" .$plural
    ."  done.\n" >?
  Succubus:stat-tail-optim ?< Succubus:stat-tail-optim " tail call" .$plural ."  patched.\n" >?
  Succubus:stat-stitch-optim ?<
    Succubus:stat-stitch-optim " stitching optimisation" .$plural ."  done.\n" >?
  Succubus:stat-logbranch-optimised ?<
    Succubus:stat-logbranch-optimised " logbranch optimisation" .$plural ."  done.\n" >?
  Succubus:stat-logbranch-litcmp ?<
    Succubus:stat-logbranch-litcmp " logbranch litcmp optimisation" .$plural ."  done.\n" >?
  Succubus:stat-logbranch-push-pop-tos ?<
    Succubus:stat-logbranch-push-pop-tos " logbranch push/pop TOS optimisation" .$plural ."  done.\n" >?
  Succubus:stat-logbranch-blocked ?<
    Succubus:stat-logbranch-blocked " logbranch optimisation" .$plural ."  blocked by \'DUP\'.\n" >?
  Succubus:stat-useless-sswaps ?<
    Succubus:stat-useless-sswaps " useles stack swap" .$plural ."  removed.\n" >?
  Succubus:stat-words-inlined ?<
    Succubus:stat-words-inlined " word" .$plural ."  inlined.\n" >?
  Succubus:stat-instructions-inlined ?<
    Succubus:stat-instructions-inlined " instruction" .$plural ."  inlined.\n" >?
  Succubus:stat-bytes-inlined ?<
    Succubus:stat-bytes-inlined " byte" .$plural ."  inlined.\n" >?
;
.stats

total-stt ., ." msecs spent compiling (Uroborus+UrForth+x86asm).\n"
total-stt-w/o-asm ., ." msecs spent compiling (Uroborus+UrForth).\n"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; hash table statistics

;; for stats
0 variable tht-min
0 variable tht-max
0 variable tht-tbu
0 variable tht-tot

: count-mhash-bucket  ( bva -- count )
  tcom:@ 0 swap << dup ?^| 1 under+ tcom:@ |? else| drop >> ;

: .hashstats
  tht-max !0 tht-tbu !0 tht-tot !0 max-int tht-min !
  tgt-#htable tgt-ghtable-va <<
    over ?^| 1 under- dup count-mhash-bucket
             dup tht-max @ max tht-max !
             dup ?< tht-tbu 1+! >?
             dup ?< dup tht-min @ min tht-min ! >?
             tht-tot +! 4+ |?
    else| 2drop >>
  \ tgt-#htable . ." hash table buckets (" tht-tbu @ . ." used); min="
  \ tht-min @ . ." max=" tht-max @ . ." uav=" tht-tot @ tht-tbu @ / 0.r cr
  tgt-#htable . ." hash table buckets (" tht-tbu @ . ." used)" cr
  ." words in htable: " tht-tot @ 0.r, cr
  ." smallest bucket: " tht-min @ . ." item" tht-min @ .plural cr
  ."  biggest bucket: " tht-max @ . ." item" tht-max @ .plural cr
  ." useless average: " tht-tot @ tht-tbu @ / 0.r cr ;

.hashstats
