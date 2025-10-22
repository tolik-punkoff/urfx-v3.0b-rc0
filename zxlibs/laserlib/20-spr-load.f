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
  db sprite-number
  dw next-sprite-addr
  db sprite-width     ;; in chars
  db sprite-height    ;; in chars
  then the bitmap, then the attributes
*)

<zx-done>
extend-module TCOM

module laserlib-loader-support
<disable-hash>


0 quan (last-sprite-addr)
0 quan (sprite-width)
0 quan (sprite-height)
0 quan (sprite-row)
0 quan (sprite-attr)
false quan (sprite-in-attrs?)

: ?good-sprite
  (sprite-width) (sprite-height) land 0?error" invalid sprite definition" ;

: ?good-sprite-row
  (sprite-row) (sprite-height) 8 * u< not?error" too many sprite rows" ;

: ?sprite-rows-finished
  (sprite-row) (sprite-height) 8 * = not?error" sprite bitmap is not finished" ;


: sprite-c,  ( byte )
  zx-c,
  zx-here @asm-label: sf_end zx-w! ;

end-module laserlib-loader-support


module laserlib-loader
<disable-hash>
using laserlib-loader-support


module laserlib-loader-def
<disable-hash>

: END-SPRITE
  ?good-sprite
  ?sprite-rows-finished
  (sprite-in-attrs?) ?<
    (sprite-width) (sprite-height) * dup depth 2- > ?error" invalid number of attributes for sprite!"
    dup for 0 sprite-c, endfor
    zx-here swap for 1- dup >r zx-c! r> endfor drop
  ||
    (sprite-attr) -?error" no attributes for the sprite"
    (sprite-width) (sprite-height) * for (sprite-attr) sprite-c, endfor
  >?
  (sprite-width):!0
  (sprite-height):!0
  (sprite-row):!0
  -1 (sprite-attr):!
  (sprite-in-attrs?):!f
  pop-ctx ;

: WIDTH  ( n )
  (sprite-width) ?error" duplicate sprite width"
  dup 1 129 within not?error" invalid sprite width"
  (sprite-width):! ;

: HEIGHT  ( n )
  (sprite-height) ?error" duplicate sprite height"
  dup 1 129 within not?error" invalid sprite height"
  (sprite-height):! ;

: ATTRS:
  ?good-sprite
  ?sprite-rows-finished
  (sprite-in-attrs?) ?error" duplicate sprite attribute map"
  \ depth ?error" extra values on the stack -- cannot start sprite attribute map"
  (sprite-in-attrs?):!t ;

: SET-ATTR
  ?good-sprite
  ?sprite-rows-finished
  (sprite-in-attrs?) ?error" already defining attribute map"
  dup 255 u> ?error" invalid sprite attribute"
  (sprite-attr):! ;

: ROW:  \ row
  ?good-sprite
  ?good-sprite-row
  (sprite-in-attrs?) ?error" already defining attribute map"
  (sprite-row) 0?<
    (sprite-width) sprite-c,
    (sprite-height) sprite-c,
  >?
  parse-name
  dup (sprite-width) 8 * = not?error" invalid sprite row length"
  8 u/ for ( addr )
    0 swap 8 for ( byte addr )
      c@++ <<
        [char] . of?v| 0 |?
        [char] # of?v| 1 |?
        [char] @ of?v| 1 |?
      else| error" invalid sprite definition char" >>
      rot 1 lshift or swap
    endfor
    swap sprite-c,
  endfor drop
  (sprite-row):1+! ;

end-module laserlib-loader-def


;; start new sprite def
: NEW-SPRITE-WITH-INDEX:  ( index )  \ name
  (sprite-width) (sprite-height) or ?error" previous sprite is not finished"
  \ TODO: better check!
  parse-name 2drop \ FIXME: name is not used for now
  (sprite-width):!0
  (sprite-height):!0
  (sprite-row):!0
  -1 (sprite-attr):!
  (sprite-in-attrs?):!f
  push-ctx voc-ctx: laserlib-loader-def
  (last-sprite-addr) ?< zx-here (last-sprite-addr) 1+ zx-w! >?
  zx-here (last-sprite-addr):!
  ( index) sprite-c,
  ( next-spr-addr) 0 sprite-c, 0 sprite-c, ;

end-module laserlib-loader


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

0 quan (laserlib-include-start-addr)

: laserlib-include-sprites  ( addr count )
  (laserlib-include-start-addr) ?error" previous SPR16 include is not finished!"
  zx-here (laserlib-include-start-addr):!
  push-ctx voc-ctx: laserlib-loader
  @asm-label: sfstrt zx-w@ 0?<
    zx-here @asm-label: sfstrt zx-w!
    zx-here @asm-label: sf_end zx-w!
    laserlib-loader-support:(last-sprite-addr):!0
  || ;; sprite file ends with zero byte, remove it
    @asm-label: sf_end zx-w@ 1- @asm-label: sf_end zx-w!
  >?
  false (include) ;

: laserlib-finish-include
  (laserlib-include-start-addr) 0?error" no SPR16 include active!"
  context@ vocid: laserlib-loader = not?error" SPR16 include context imbalance!"
  pop-ctx
  [ TURNKEY-PASS1? ] [IF]
    ;; remove sprite data
    (laserlib-include-start-addr)
    zx-rewind-dp!
  [ELSE]
    laserlib-loader-support:(last-sprite-addr) ?<
      zx-here laserlib-loader-support:(last-sprite-addr):!
    >?
    0 laserlib-loader-support:sprite-c, ;; sprite file should end with zero byte
  [ENDIF]
  zx-here @asm-label: sf_end zx-w!
  (laserlib-include-start-addr):!0 ;

: laserlib-finish-include-msg  ( addr count )
  (laserlib-include-start-addr) 0?error" no SPR16 include active!"
  [ TURNKEY-PASS2? ] [IF]
    endcr type  ."  size: " zx-here (laserlib-include-start-addr) -  .bytes cr
  [ELSE]
    2drop
  [ENDIF]
  laserlib-finish-include ;

end-module TCOM

<zx-definitions>
