;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; structs
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module FORTH

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple struct definitions
;; 0
;;   new-field fld
;;   ...
;; constant struct-size
;;  base fld:@

module FIELD-SUPPORT
<disable-hash>
using system

|: (FLD-OFS)  ( pfa -- size )  forth:@ ;
|: (FLD-SIZE) ( pfa -- size )  4+ forth:@ ;

|: (?FLD-OFS)  ( min-size -- ofs )
  >r vocobj:this dup (fld-size) r> < ?error" field too small"
  (fld-ofs) ;

|: (?FLD-OFS-EXACT)  ( min-size -- ofs )
  >r vocobj:this dup (fld-size) r> <> ?error" field too small"
  (fld-ofs) ;

*: +  ( addr -- addr+ofs )
  vocobj:this (fld-ofs)
  comp? ?exit< Succubus:low:add-ebx-value >?
  forth:+ ;

*: ^  ( addr -- addr+ofs )
  vocobj:this (fld-ofs)
  comp? ?exit< Succubus:low:add-ebx-value >?
  forth:+ ;

*: OFFSET   ( -- ofs )  vocobj:this (fld-ofs) [\\] {#,} ;
*: SIZE     ( -- size ) vocobj:this (fld-size) [\\] {#,} ;
*: @OFFSET  ( -- ofs )  vocobj:this (fld-ofs) [\\] {#,} ;
*: @SIZE-OF ( -- size ) vocobj:this (fld-size) [\\] {#,} ;

|: (DO-@)  ( addr fld-pfa -- [addr+ofs] )
  dup (fld-ofs) swap (fld-size)
  comp? ?exit<
    swap #, \\ forth:+
    << 4 of?v| \\ forth:@ |?
       2 of?v| \\ forth:w@ |?
       1 of?v| \\ forth:c@ |?
    else| error" invalid field size" >> >?
  swap forth:under+
  << 4 of?v| forth:@ |?
     2 of?v| forth:w@ |?
     1 of?v| forth:c@ |?
  else| error" invalid field size" >> ;

*: !  ( value addr )  \ [addr+ofs]=value
  vocobj:this dup (fld-ofs) swap (fld-size)
  comp? ?exit<
    swap #, \\ forth:+
    << 4 of?v| \\ forth:! |?
       2 of?v| \\ forth:w! |?
       1 of?v| \\ forth:c! |?
    else| error" invalid field size" >> >?
  swap forth:under+
  << 4 of?v| forth:! |?
     2 of?v| forth:w! |?
     1 of?v| forth:c! |?
  else| error" invalid field size" >> ;

*: @  ( addr -- [addr+ofs] )
  vocobj:this (do-@) ;

*: +!  ( value addr )  \ [addr+ofs]+=value
  vocobj:this dup (fld-ofs) swap (fld-size)
  comp? ?exit<
    swap #, \\ forth:+
    << 4 of?v| \\ forth:+! |?
       2 of?v| \\ forth:+w! |?
       1 of?v| \\ forth:+c! |?
    else| error" invalid field size" >> >?
  swap forth:under+
  << 4 of?v| forth:+! |?
     2 of?v| forth:+w! |?
     1 of?v| forth:+c! |?
  else| error" invalid field size" >> ;
*: -!  ( value addr )  \ [addr+ofs]-=value
  vocobj:this dup (fld-ofs) swap (fld-size)
  comp? ?exit<
    swap #, \\ forth:+
    << 4 of?v| \\ forth:-! |?
       2 of?v| \\ forth:-w! |?
       1 of?v| \\ forth:-c! |?
    else| error" invalid field size" >> >?
  swap forth:under+
  << 4 of?v| forth:-! |?
     2 of?v| forth:-w! |?
     1 of?v| forth:-c! |?
  else| error" invalid field size" >> ;
*: 1+!  ( addr )  \ [addr+ofs]+=1
  4 (?fld-ofs-exact) comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    1 Succubus:low:[ebx+value]+=value
    Succubus:high:pop-tos >?
  forth:+ forth:1+! ;
*: 1-!  ( addr )  \ [addr+ofs]-=1
  4 (?fld-ofs-exact) comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    1 Succubus:low:[ebx+value]-=value
    Succubus:high:pop-tos >?
  forth:+ forth:1-! ;
*: 2+!  ( addr )  \ [addr+ofs]+=2
  4 (?fld-ofs-exact) comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    2 Succubus:low:[ebx+value]+=value
    Succubus:high:pop-tos >?
  forth:+ forth:2+! ;
*: 2-!  ( addr )  \ [addr+ofs]-=2
  4 (?fld-ofs-exact) comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    2 Succubus:low:[ebx+value]-=value
    Succubus:high:pop-tos >?
  forth:+ forth:2-! ;
*: 4+!  ( addr )  \ [addr+ofs]+=4
  4 (?fld-ofs-exact) comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    4 Succubus:low:[ebx+value]+=value
    Succubus:high:pop-tos >?
  forth:+ forth:4+! ;
*: 4-!  ( addr )  \ [addr+ofs]-=4
  4 (?fld-ofs-exact) comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    4 Succubus:low:[ebx+value]-=value
    Succubus:high:pop-tos >?
  forth:+ forth:4-! ;
*: 8+!  ( addr )  \ [addr+ofs]+=8
  4 (?fld-ofs-exact) comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    8 Succubus:low:[ebx+value]+=value
    Succubus:high:pop-tos >?
  forth:+ forth:8+! ;
*: 8-!  ( addr )  \ [addr+ofs]-=8
  4 (?fld-ofs-exact) comp? ?exit<
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
    8 Succubus:low:[ebx+value]-=value
    Succubus:high:pop-tos >?
  forth:+ forth:8-! ;

*: !0  ( addr )  \ [addr+ofs]=0
  vocobj:this dup >r (fld-ofs)
  comp? ?exit<  ( fldofs | vobj-pfa )
    r> (fld-size)
    ( fldofs fld-size )
    << 4 of?v| Succubus:low:dstack>cpu Succubus:low:eax Succubus:low:xor-reg32-reg32 Succubus:low:store-[ebx+value]-eax |?
       2 of?v| Succubus:low:dstack>cpu Succubus:low:eax Succubus:low:xor-reg32-reg32 Succubus:low:store-[ebx+value]-ax |?
       1 of?v| Succubus:low:dstack>cpu Succubus:low:eax Succubus:low:xor-reg32-reg32 Succubus:low:store-[ebx+value]-al |?
    else| swap Succubus:low:add-ebx-value  #,  \\ forth:erase exit >>
    Succubus:high:pop-tos >?
  forth:+ r> (fld-size) forth:erase ;

*: !F  ( addr )  \ [addr+ofs]=0
  [\\] !0 ;

*: !T  ( addr )  \ [addr+ofs]=-1
  vocobj:this dup >r (fld-ofs)
  comp? ?exit<
    r> (fld-size)
    ( fldofs fld-size )
    dup 4 = ?exit< drop
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
      -1 Succubus:low:eax Succubus:low:load-reg32-value
      Succubus:low:store-[ebx+value]-eax
      Succubus:high:pop-tos >?
    swap Succubus:low:add-ebx-value  #,  -1 #,  \\ forth:fill >?
  forth:+ r> (fld-size) -1 forth:fill ;

*: !1  ( addr )  \ [addr+ofs]=1
  vocobj:this dup >r (fld-ofs)
  comp? ?exit<
    ( fldofs fld-size )
    r> (fld-size)
    dup 4 = ?exit< drop
    Succubus:low:dstack>cpu -- do it early, so swap optimiser could remove it
      1 Succubus:low:eax Succubus:low:load-reg32-value
      Succubus:low:store-[ebx+value]-eax
      Succubus:high:pop-tos >?
    swap Succubus:low:add-ebx-value  #,  1 #,  \\ forth:fill >?
  forth:+ r> (fld-size) -1 forth:fill ;

end-module FIELD-SUPPORT


extend-module SYSTEM

: MK-FIELD  ( ofs size addr count )
  mk-builds immediate swap ( offset) , ( size) ,
  \ does> error" use \'field:offset\' instead!" ;
  does> ( addr fld-pfa )
    dup dart:does-pfa>cfa system:?vocid@
    " (do-@)" rot vocid-find-any not?error" field doesn't have \'(do-@)\'"
    ( addr fld-pfa do-@-cfa )
    execute-tail ;

end-module SYSTEM


;; create accessor
: NEW-N-FIELD  ( ofs size -- ofs+size )  \ name
  dup 0< ?error" invalid field size"
  2dup parse-name system:mk-field
  vocid: field-support system:latest-vocid !
  + ;

: NEW-FIELD  ( ofs -- ofs+4 )  \ name
  4 new-n-field ;


module STRUCT-SUPPORT-UNION
<disable-hash>
: N-FIELD:  ( ofs usize size -- ofs new-usize )  \ name
  swap >r over >r ( ofs size | usize ofs )
  [\\] new-n-field
  ( new-ofs | usize old-ofs )
  r> tuck - r> max ;

: C-FIELD:  ( ofs usize -- ofs new-usize )  \ name
  1 [\\] n-field: ;

: W-FIELD:  ( ofs usize -- ofs new-usize )  \ name
  2 [\\] n-field: ;

: FIELD:  ( ofs usize -- ofs new-usize )  \ name
  4 [\\] n-field: ;

: }  ( ofs usize -- ofs+usize )
  + pop-ctx ;
end-module STRUCT-SUPPORT-UNION (private)


module STRUCT-SUPPORT
<disable-hash>

: UNION{  ( ofs -- ofs usize )
  0 push-ctx vocid: struct-support-union context! ;

|: MAIN-DOER  ( pfa )
  error" struct what?" ;

: N-FIELD:  ( ofs size -- ofs+size )  \ name
  [\\] new-n-field ;

: C-FIELD:  ( ofs size -- ofs+size )  \ name
  1 [\\] n-field: ;

: W-FIELD:  ( ofs size -- ofs+size )  \ name
  2 [\\] n-field: ;

: FIELD:  ( ofs -- ofs+4 )  \ name
  4 [\\] n-field: ;

: END-STRUCT
  ;; parent may already contain "#"
  system:redefine-mode >r system:redefine-mode:!f
  dup " #" system:mk-constant
  " @SIZE-OF" system:mk-constant
  ;; create "@PARENT" field?
  current@ system:vocid-parent@ dup not?< drop
  || " @PARENT-VOCID" system:mk-constant >?
  r> system:redefine-mode:!

  opt-name-parse:parse-optional-name ?<
    ( addr count )
    current@ system:vocid-rfa@ dup not?error" invalid struct name (no rfa field in wordlist)"
    idcount string:=ci not?error" mismatched struct name" >?

  nsp-pop -6969 = not?error" invalid \'END-STRUCT\'"
  pop-cur
  nsp-pop system:default-ffa !
  nsp-pop -6969 = not?error" invalid \'END-STRUCT\'"

  vsp-pop -6969 = not?error" invalid \'END-STRUCT\'"
  pop-ctx
  vsp-pop -6969 = not?error" invalid \'END-STRUCT\'" ;

end-module STRUCT-SUPPORT (private)


module STRUCT
<disable-hash>
\ <published-words>

(*
  struct:new pfx
    field: a
    field: b
  end-struct

create vocab "pfx", with fields "a", "b", and constant "@SIZE-OF".

extend struct:
  pfx:@size-of struct:new-with-ofs new
    field: c
    field: d
  end-struct

this simply starts from the given offset.


extend struct with inheritance:
  struct:extend pfx as new
    field: c
    field: d
  end-struct

links the struct to the parent, start with the parent size.
also, creates "@PARENT-VOCID" constant.
*)

: MK-STRUCT  ( addr count -- wordlist )
  system:mk-wordlist-nohash dup >r system:mk-builds-vocab
  system:latest-cfa ['] struct-support::main-doer system:!doer
  immediate
  ;; push current vocab, setup new current
  -6969 nsp-push
  system:default-ffa @ nsp-push
  push-cur
  -6969 nsp-push
  system:wflag-module-mask system:default-ffa and!
  r@ system:vocid-nohash!
  r@ current!
  ;; setup context
  -6969 vsp-push
  push-ctx
  vocid: struct-support context!
  -6969 vsp-push
  r> ;

: NEW-WITH-OFS  ( ofs )  \ name
  parse-name mk-struct drop ;

: NEW  \ name
  0 new-with-ofs ;

: EXTEND  \ old-name AS new-name
  -find-required
  dup system:doer@ ['] struct-support::main-doer = not?error" cannot extend non-struct"
  system:vocid@ >r  ;; we'll need vocid later
  parse-name 2 = swap w@ $20_20 or $73_61 = and not?error" `AS` expected"
  parse-name mk-struct
  ;; set parent for the new struct
  r@ swap system:vocid-parent!
  ;; get offset
  " @SIZE-OF" r> vocid-find not?error" invalid struct" execute ;

end-module STRUCT

end-module FORTH
