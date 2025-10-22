;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16x16 XOR sprites, no runtime shifting
;; spriter loader, directly included from "spr16.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(*
16x16 sprite loader.
sprite format:
  db mask    ;; mask for the first byte ($FF -- put full first byte)
  32 bytes of data, upside down

sprite definition:
  db attr
  dw gfx-addr
  db reserved
*)

extend-module TCOM

module spr16-loader-support
<disable-hash>

module spr-list
<disable-hash>
end-module


;; current sprite row
-1 quan sp-row#
;; cyclically shift the sprite by this
-1 quan sp-rshift
;; sprite attributes
-1 quan sp-attr

;; collected sprite data
create sp-data  16 2 * allot create;

;; current sprite word
0 quan row-word


;; reset sprite line
: row-reset   row-word:!1 ;

: row-char  ( addr -- addr+1 )
  row-word hi-word ?error" too much sprite data in the row"
  c@++ <<
    [char] . of?v| 0 |?
    [char] # of?v| 1 |?
    [char] @ of?v| 1 |?
    [char] : of?v| 0 ( error" masks are not supported yet") |?
    [char] * of?v| 1 ( error" fill-no-masks are not supported yet") |?
    [char] = of?v| exit |?
    [char] | of?v| exit |?
  else| error" wut?!" >>
  row-word 2* + row-word:! ;

;; the state is reset, and ready for the new line
: row-finish
  sp-row# 0 16 within not?error" oops!"
  row-word << dup hi-word not?^| 2* |? else| >>
  sp-rshift 0 max ror16
  15 sp-row# - sp-data dw-nth w!
  sp-row#:1+!
  row-reset ;


: find-spr  ( addr count -- zx-addr TRUE // FALSE )
  vocid: spr-list find-in-vocid ?< dart:cfa>pfa @ true || false >? ;

: find-spr-req  ( addr count -- zx-addr )
  2dup find-spr not?<
    " sprite \'" string:>pad string:pad+cc
    " \' not found!" string:pad+cc
    string:pad-cc@ error >?
  nrot 2drop ;

: -find-spr  ( -- zx-addr )  parse-name find-spr-req ;


: mask,  $FF sp-rshift 0 max rshift zx-c, ;

;; put collected sprite
: sprite,
  mask,
  sp-data << dup w@ 8 ror16 zx-w, 2+ dup sp-data - 32 = not?^||
  else| drop >> ;


0 quan old-shift

: mask>shift  ( mask -- shift )
  0 >r lo-byte $FF <<  ( mask cur-mask | count )
    2dup = ?v||
    1 rshift dup not?error" invalid sprite mask"
  ^| r> 1+ >r | >>
  2drop r> ;

: load-old-shift  ( zx-addr -- zx-addr+1 )
  dup zx-c@ mask>shift old-shift:! 1+ ;

: set-new-shift
  sp-rshift -?< old-shift sp-rshift:! >? ;


0 quan row-dir

: copy-data  ( zx-addr-src process-cfa )
  >r 16 swap << over ?^| ( count zx-addr-src )
    dup zx-w@ 8 rol16 old-shift rol16
    r@ ?execute $1_0000 or
    row-word:!
    sp-row# row-finish row-dir + sp-row#:!
  2+ 1 under- |? else| 2drop >>
  rdrop ;

;; process-cfa  ( spword -- spword )
: process-sprite  ( zx-addr-src process-cfa )
  swap
  load-old-shift set-new-shift
  swap copy-data
  16 sp-row#:! ;


: mirror-word  ( w -- w )
  lo-word $1_0000 or 0 ( old-word new-word )
  << 2* over 1 and or
     swap 2/ swap
  over 1 <> ?^|| else| nip >> ;

: set-normal-dir       -1 row-dir:! 15 sp-row#:! ;
: set-upside-down-dir   1 row-dir:!  0 sp-row#:! ;

: do-copy   ( zx-addr-src )  set-normal-dir 0 process-sprite ;
: do-mirror ( zx-addr-src )  set-normal-dir ['] mirror-word process-sprite ;

: do-copy-upside-down   ( zx-addr-src )  set-upside-down-dir 0 process-sprite ;
: do-mirror-upside-down ( zx-addr-src )  set-upside-down-dir ['] mirror-word process-sprite ;

end-module  \ spr16-loader-support


module spr16-loader
<disable-hash>
using spr16-loader-support


module spr16-loader-gfx
<disable-hash>

;; finish the sprite
: end-sprite-gfx
  sp-row# 0< ?error" no sprite started"
  sprite,
  sp-row#:!t
  pop-ctx ;

: rshift  ( n )
  dup 15 u> ?error" invalid sprite rshift"
  sp-row# 0< ?error" no sprite started"
  sp-row# ?error" shift command must precede any row"
  sp-rshift:! ;

: lshift  ( n )
  dup 15 u> ?error" invalid sprite lshift"
  16 swap - 15 and rshift ;

: row
  sp-row# 0< ?error" no sprite started"
  sp-row# 15 > ?error" too many sprite rows"
  parse-name
  row-reset swap << over ?^| row-char 1 under- |? else| 2drop >>
  row-finish ;

: copy  \ name
  sp-row# 0< ?error" no sprite started"
  sp-row# ?error" cannot copy over the (partially) defined sprite"
  -find-spr do-copy ;

: v-mirror  \ name
  sp-row# 0< ?error" no sprite started"
  sp-row# ?error" cannot copy over the (partially) defined sprite"
  -find-spr do-copy-upside-down ;

: h-mirror  \ name
  sp-row# 0< ?error" no sprite started"
  sp-row# ?error" cannot copy over the (partially) defined sprite"
  -find-spr do-mirror ;

: hv-mirror  \ name
  sp-row# 0< ?error" no sprite started"
  sp-row# ?error" cannot copy over the (partially) defined sprite"
  -find-spr do-mirror-upside-down ;

: vh-mirror  \ name
  hv-mirror ;

end-module  \ spr16-loader-gfx

;; start new sprite gfx
: sprite-gfx  \ label-name
  sp-row# 0>= ?error" previous sprite is not finished"
  parse-name
  2>r zx-here 2r@ z80-labman:@set
  push-cur voc-cur: spr-list 2r> system:mk-create zx-here , pop-cur
  sp-row#:!0 sp-rshift:!f
  sp-data 16 2 * erase
  push-ctx voc-ctx: spr16-loader-gfx ;


module spr16-loader-def
<disable-hash>

0 quan (sprite-name-dstr)
0 quan (sprite-start^)

: end-sprite-def
  (sprite-name-dstr) 0?error" no sprite name!"
  (sprite-start^)  (sprite-name-dstr) count  zx-mk-constant
  (sprite-name-dstr) string:$free (sprite-name-dstr):!0
  pop-ctx ;

: attr  ( n )
  dup 255 u> ?error" invalid sprite rshift"
  sp-attr:! ;

: gfx:  \ name
  -find-spr
  ( attrs) sp-attr zx-c,
  ( gfx-addr) zx-w,
  ( reserved) 0 zx-c, ;

end-module  \ spr16-loader-def

(*
;; start new sprite def
: sprite-def  \ const-name
  sp-row# 0>= ?error" previous sprite is not finished"
  0 parse-name zx-mk-constant
  zx-here dup 2- zx-w!  ;; fix constant
  sp-attr:!t
  push-ctx voc-ctx: spr16-loader-def ;
*)

;; start new sprite def
: sprite-def  \ const-name
  sp-row# 0>= ?error" previous sprite is not finished"
  parse-name string:$new spr16-loader-def:(sprite-name-dstr):!
  zx-here spr16-loader-def:(sprite-start^):!
  sp-attr:!t
  push-ctx voc-ctx: spr16-loader-def
  \ endcr ." new sprite: " spr16-loader-def:(sprite-name-dstr) count type cr
;


end-module  \ spr16-loader


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

0 quan (spr16-include-start-addr)

: spr16-include-sprites  ( addr count )
  (spr16-include-start-addr) ?error" previous SPR16 include is not finished!"
  zx-here (spr16-include-start-addr):!
  push-ctx voc-ctx: spr16-loader
  false (include) ;

: spr16-finish-include
  (spr16-include-start-addr) 0?error" no SPR16 include active!"
  context@ vocid: spr16-loader = not?error" SPR16 include context imbalance!"
  pop-ctx
  [ TURNKEY-PASS1? ] [IF]
    ;; remove sprite data
    (spr16-include-start-addr)
    zx-rewind-dp!
  [ENDIF]
  (spr16-include-start-addr):!0 ;

: spr16-finish-include-msg  ( addr count )
  (spr16-include-start-addr) 0?error" no SPR16 include active!"
  [ TURNKEY-PASS2? ] [IF]
    endcr type  ."  size: " zx-here (spr16-include-start-addr) -  .bytes cr
  [ELSE]
    2drop
  [ENDIF]
  spr16-finish-include ;

end-module  \ TCOM
