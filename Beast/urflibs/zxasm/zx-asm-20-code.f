;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple ZX Spectrum assembler
;; coded by Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; assembler mode words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module ZXA

@: [@@]  ( -- value )
  parse-name z80-labman:@get ;

@: @def: ( value )  \ label-name
  parse-name z80-labman:@set ;

@: @def-global: ( value )  \ label-name
  parse-name z80-labman:define
  z80-labman:reset-locals ;

module zx-code-def
<disable-hash>
using z80-labman

: [@@]  ( -- value )
  [@@] ;

: @def: ( value )  \ label-name
  @def: ;

: @def-global: ( value )  \ label-name
  @def-global: ;

;; reserve `n` byte with value `value`
: resv-#  ( value n )
  << dup +?^| over z80asm:instr:db, 1- |? else| 2drop >> ;

;; reserve `n` zero bytes
: resv-0  ( n )  0 swap resv-# ;

: <end-asm>
  system:?exec
  z80asm:instr:end-code
  \ pop-ctx pop-ctx pop-ctx pop-ctx ;
  << vsp-pop -60669 = not?^|| else| >> pop-ctx ;

: org  ( value )
  dup 0 65535 bounds not?error" invalid ORG value"
  zxa:org! ;

: ent  ( value )
  dup 0 65535 bounds not?error" invalid ENT value"
  zxa:ent! ;

: clr  ( value )
  dup 24000 65535 bounds not?error" invalid CLR value"
  1- zxa:clr! ;

end-module zx-code-def (published)
end-module zxa


*: <asm>
  system:?exec
  push-ctx
  -60669 vsp-push
           voc-ctx: z80-labman:unk-labels
  push-ctx voc-ctx: z80-labman:zx-labels
  push-ctx voc-ctx: zxa:zx-code-def
  \ push-ctx voc-ctx: zxa:zxa-instr-ex
  z80-code ;
