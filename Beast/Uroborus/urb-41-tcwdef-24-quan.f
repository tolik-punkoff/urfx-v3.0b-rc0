;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; define target QUAN words
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


: (tgt-does-quan)
  ?in-target (shadow-tgt-cfa@) tgt-cfa>pfa
  system:comp? ?exit< tgt-#, tgt-forwards:tgt-(@) tgt-cc\, >? tcom:@ ;

: tgt-quan-this  ( tgt-quan-pfa )
  ?in-target ['] (tgt-does-quan) vocobj:?this
  (shadow-tgt-cfa@) tgt-cfa>pfa ;


module tgt-quan-methods
<disable-hash>

\ *: @  ?in-target tgt-quan-this (tgt-does-quan) ;
*: ^
  tgt-quan-this system:comp? ?exit< tgt-#, >? ;
*: !   ( value )
  tgt-quan-this system:comp? ?exit< tgt-#, tgt-forwards:tgt-(!) tgt-cc\, >? tcom:! ;
*: +!  ( value )
  tgt-quan-this system:comp? ?exit<
    Succubus:low:dstack>cpu
    Succubus:low:add-[addr]-ebx
    Succubus:high:pop-tos >?
  abort ;
*: -!  ( value )
  tgt-quan-this system:comp? ?exit<
    Succubus:low:dstack>cpu
    Succubus:low:sub-[addr]-ebx
    Succubus:high:pop-tos >?
  abort ;
*: 1+! ( value )
  tgt-quan-this system:comp? ?exit<
    Succubus:low:inc-[addr] >?
  abort ;
*: 1-! ( value )
  tgt-quan-this system:comp? ?exit<
    Succubus:low:dec-[addr] >?
  abort ;
*: 2+!
  tgt-quan-this system:?comp
  2 Succubus:low:add-[addr]-value ;
*: 2-!
  tgt-quan-this system:?comp
  2 Succubus:low:sub-[addr]-value ;
*: 4+!
  tgt-quan-this system:?comp
  4 Succubus:low:add-[addr]-value ;
*: 4-!
  tgt-quan-this system:?comp
  4 Succubus:low:sub-[addr]-value ;
*: 8+!
  tgt-quan-this system:?comp
  8 Succubus:low:add-[addr]-value ;
*: 8-!
  tgt-quan-this system:?comp
  8 Succubus:low:sub-[addr]-value ;
*: !0
  tgt-quan-this system:comp? ?exit<
    0 Succubus:low:store-[addr]-value >?
  0 swap tcom:! ;
*: !1
  tgt-quan-this system:comp? ?exit<
    1 Succubus:low:store-[addr]-value >?
  1 swap tcom:! ;
*: !t
  tgt-quan-this system:comp? ?exit<
    true Succubus:low:store-[addr]-value >?
  true swap tcom:! ;
*: !f
  tgt-quan-this system:comp? ?exit<
    false Succubus:low:store-[addr]-value >?
  false swap tcom:! ;
end-module tgt-quan-methods


: tgt-new-quan  ( initval )  \ name
  \ tgt-forwards:tgt-(quan-doer)-pfa not?error" quan doer is not defined yet"
  >r parse-name
    \ endcr 2dup ." NEW TGT QUAN: " type cr
  2dup tgt-does-cfa (tgt-create-tgt-word-var-align)
  tgt-forwards:tgt-(quan-doer)-doer:tgt-latest-doer!
  tgt-wflag-immediate tgt-latest-ffa-or!
  tgt-(quan-vocid) dup not?< drop
    tgt-quan-vocid-fixups tgt-convert-latest-to-vocobj-future
  || tgt-convert-latest-to-vocobj >?
  r> tcom:,
  ['] (tgt-does-quan) vocid: tgt-quan-methods (tgt-mk-rest-vocid) ;
\ debug:see tgt-new-quan bye


tcf: quan  system:?exec tgt-new-quan ;tcf

;; quan vocid
tcf: (quan-vocid)   ?in-target tgt-(quan-vocid) tgt-#, ;tcf
