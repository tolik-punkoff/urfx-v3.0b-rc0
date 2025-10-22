;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; peephole pattern compiler and matcher
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
\ $include <z80asm>

(*
  peep-pattern:[[
    push  hl
    ld    hl, () {addr}
  ]] peep-match not?exit&leave
  peep: {addr}
  peep-remove-instructions

  TOS-in-HL? ?<
    peep-pattern:[[
      ld    h, a
    ]]
  || TOS-in-DE? not?error" ICE!"
    peep-pattern:[[
      ld    d, a
    ]]
  >?
  peep-match ;

"{addr}" is a pattern variable.

"peep-match" checks if the generated code matches the pattern.
pattern address is on the stack (left by "peep-pattern:[[ ... ]]]").
leaves boolean value on the stack.

"peep-remove-instructions" removes last matched pattern. it is UB to
call it if "peep-match" failed.

"peep: {addr}" -- get value of the pattern variable. it is UB to call
it if "peep-match" failed.

note that "peep:" is used last compiled pattern to access pattern
variables. i.e. you cannot do this:

  cond ?<
    peep-pattern:[[
      ld    hl, () {addr}
    ]]
  ||
    peep-pattern:[[
      ld    de, () {addr}
    ]]
  >?
  peep-match not?exit&leave
  peep: {addr}

it will NOT work. you have to write it in this way:

  cond ?<
    peep-pattern:[[
      ld    hl, () {addr}
    ]]
    peep-match not?exit&leave
    peep: {addr}
  ||
    peep-pattern:[[
      ld    de, () {addr}
    ]]
    peep-match not?exit&leave
    peep: {addr}
  >?

sorry for inconvenience.
*)


module Z80ASM-PAT
\ <disable-hash>
<public-words>

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; internal pattern compiler words

false constant Z80ASM-PATTERN-DEBUG-DUMP
false constant Z80ASM-PATTERN-DEBUG-MORE

;; 16 slots should be enough, lol
create cb-saved 16 4* allot create;

|: (xput)  ( addr value -- next-addr )  over ! 4+ ;
|: (xget)  ( addr -- next-addr value )  @++ ;

: save-cbs
  cb-saved
  z80asm:emit:c,:@ (xput)
  z80asm:emit:here:@ (xput)
  z80asm:emit:c@:@ (xput)
  z80asm:emit:c!:@ (xput)
  z80asm:emit:<label>:@ (xput)
  z80asm:emit:<instr:@ (xput)
  z80asm:emit:instr>:@ (xput)
  z80asm:emit:<disp8>:@ (xput)
  z80asm:emit:<jrdisp8>:@ (xput)
  z80asm:emit:<val8>:@ (xput)
  z80asm:emit:<val16>:@ (xput)
  drop ;

: restore-cbs
  cb-saved
  (xget) z80asm:emit:c,:!
  (xget) z80asm:emit:here:!
  (xget) z80asm:emit:c@:!
  (xget) z80asm:emit:c!:!
  (xget) z80asm:emit:<label>:!
  (xget) z80asm:emit:<instr:!
  (xget) z80asm:emit:instr>:!
  (xget) z80asm:emit:<disp8>:!
  (xget) z80asm:emit:<jrdisp8>:!
  (xget) z80asm:emit:<val8>:!
  (xget) z80asm:emit:<val16>:!
  drop ;

(*
pattern format:
  db instr-count  ;; # of instructions
instruction format:
  db byte-count   ;; # of bytes in the instruction
    bytes-and-data
byte value:
  255: reference
    db store-slot-index
     255: no store slot, just a byte 255
     0..$7E: store slot index
     bit 7: set for the word reference, otherwise it is a byte
*)
;; WARNING! pattern buffer bounds are not checked!
;; in real code, patterns are only several instructions long, so it doesn't matter.
$FF constant pat-cmd
create pat-buffer 1024 allot create;

struct:new slot-rec
  field: name$  ;; dynalloced
  field: index  ;; slot index
end-struct
16 constant max-slots
0 quan slots-used
create slots max-slots slot-rec:@size-of * allot create;

;; slot management

;; shouild be called once at program startup
: wipe-slots
  slots max-slots slot-rec:@size-of * erase
  slots-used:!0 ;

: free-slots
  slots slots-used for
    dup slot-rec:name$ string:$free
  slot-rec:@size-of + endfor
  drop
  slots-used:!0 ;

: (find-slot-at)  ( addr count slot^ count -- index TRUE // FALSE )
  dup 0?exit< 4drop false >?
  <<  ( addr count slot^ count )
    2over 2over drop slot-rec:name$ count string:=ci
    ?exit< drop nrot 2drop slot-rec:index true >?
    slot-rec:@size-of under+
  1- dup ?^||
  else| 2drop >>
  2drop false ;

: find-slot  ( addr count -- index TRUE // FALSE )
  slots slots-used (find-slot-at) ;

: nth-slot-name  ( index -- addr count )
  dup 0 slots-used within not?error" invalid slot index!"
  slot-rec:@size-of * slots +
  slot-rec:name$ count ;

: new-slot  ( addr count -- index )
  2dup find-slot ?< drop
    " duplicate peep pattern slot: \'" pad$:!
    pad$:+ " \'!" pad$:+
    pad$:@ error
  >?
  slots-used max-slots = ?error" too many peep pattern slots!"
  string:$new
  slots-used slot-rec:@size-of * slots +
  ( str$ slot^ )
  slots-used over slot-rec:index:!
  slot-rec:name$:!
  slots-used slots-used:1+! ;


0 quan pat^
0 quan instr^
0 quan skip-bytes
0 quan resv-slot-count
create resv-slots 2 4* allot create;
-1 quan value-slot
-1 quan disp8-slot

: resv-nth-slot^  ( idx -- addr )
  dup 0 resv-slot-count within not?error" ICE: invalid resv slot index!"
  resv-slots dd-nth ;

: resv-nth-slot@  ( idx -- value )
  dup 0 resv-slot-count within not?exit< drop -1 >?
  resv-nth-slot^ @ ;

: resv-nth-slot!  ( value idx )
  resv-nth-slot^ ! ;

: pattern-size  ( -- bytes )
  pat^ pat-buffer - ;

: dump-pattern
  endcr ." instructions: " pat-buffer c@ 0.r cr
  endcr ." pattern size: " pattern-size 1- . ." bytes" cr
  pat-buffer c@++ for
    ." === INSTRUCTION #" i 0.r ."  -- bytes: " c@++ dup 0.r ."  ===\n"
    swap << ( bytes-left addr )
      c@++ dup pat-cmd = ?< drop
        c@++ dup 255 = ?< drop
          ."   byte: $" pat-cmd .hex2 cr
          1 under-
        ||
          dup $80 and ?< ."   word" 2 || ."   byte" 1 >?
          swap ."  slot #" $7F and dup 0.r
          nth-slot-name ."  " type
          cr
          under-
        >?
      || ."   byte: $" .hex2 cr
         1 under- >?
    over ?^||
    else| nip >>
  endfor
  drop ;


: reset-pattern
  pat-buffer 1+ pat^:!
  pat-buffer !0
  skip-bytes:!0
  resv-slot-count:!0
  -1 value-slot:! -1 disp8-slot:!
  free-slots
;

: count-instruction
  pat-buffer c@ dup 255 = ?error" too many instructions in a pattern"
  1+ pat-buffer c! ;


;; guaranteed to not overflow
|: (raw-c,)  ( byte )
  pat^ c!
  pat^:1+! ;

|: (adv-bytes)  ( delta )
  instr^ c@ + instr^ c! ;

|: (c,)  ( byte )
  skip-bytes ?exit< drop skip-bytes:1-! >?
  1 (adv-bytes)
  dup pat-cmd = ?< (raw-c,) 255 >?
  (raw-c,) ;

|: (here)  ( -- addr )
  pat^ pat-buffer - 1- ;

|: (c@)  ( addr -- byte )
  lo-word 1+ pat-buffer + c@ ;

|: (c!)  ( byte addr )
  lo-word 1+ pat-buffer + c! ;


|: (label-use-slot)  ( idx )
  dup 0 resv-nth-slot@ = ?exit< drop -1 0 resv-nth-slot! >?
  1 resv-nth-slot@ = ?exit< -1 1 resv-nth-slot! >?
  not?error" ICE: used unspecified slot!" ;

|: (label)  ( value type idx -- value )
  1-  ;; because we did "1+" below ;-)
  [ 0 ] [IF]
    endcr ." LABEL #" dup . ." type=" over 0.r cr
  [ENDIF]
  swap <<
    z80asm:ltype-rel8 of?v| not?error" JR slots are not implemented yet!" |?
    z80asm:ltype-disp of?v| -1 |?
    z80asm:ltype-word of?v|  1 |?
  else| drop 0 >>
  ( value idx slot-type )
  -?<
    ;; disp8 slot
    disp8-slot -1 = not?error" ICE: duplicate disp8 slot!"
    dup disp8-slot:!
  ||
    ;; byte/word slot
    value-slot -1 = not?error" ICE: duplicate value slot!"
    dup value-slot:!
  >?
  (label-use-slot) ;

|: (instr-start)
  [ Z80ASM-PATTERN-DEBUG-MORE ] [IF]
    endcr ." ::: NEW INSTRUCTION :::\n"
  [ENDIF]
  pat^ instr^:!
  skip-bytes:!0
  ;; byte count
  0 (raw-c,) ;

|: (instr-end)
  [ Z80ASM-PATTERN-DEBUG-MORE ] [IF]
    endcr ." ::: INSTRUCTION END (len=" instr^ c@ 0.r ." ) :::\n"
  [ENDIF]
  value-slot -1 <> ?<
    " ICE: value slot \'" pad$:! value-slot nth-slot-name pad$:+
    " \' is not used!" pad$:+
    pad$:@ error
  >?
  disp8-slot -1 <> ?<
    " ICE: disp slot \'" pad$:! disp8-slot nth-slot-name pad$:+
    " \' is not used!" pad$:+
    pad$:@ error
  >?
  0 resv-nth-slot@ -1 <> ?<
    " slot \'" pad$:! 0 resv-nth-slot@ nth-slot-name pad$:+
    " \' is not used!" pad$:+
    pad$:@ error
  >?
  1 resv-nth-slot@ -1 <> ?<
    " slot \'" pad$:! 1 resv-nth-slot@ nth-slot-name pad$:+
    " \' is not used!" pad$:+
    pad$:@ error
  >?
  skip-bytes ?<
    " ICE: " pad$:! skip-bytes pad$:#s
    "  bytes is not skiiped. wtf?!" pad$:+
    pad$:@ error
  >?
  resv-slot-count:!0
  count-instruction ;

|: (disp8)  ( val -- val )
  [ Z80ASM-PATTERN-DEBUG-MORE ] [IF]
    endcr ." disp8 slot: " disp8-slot 0.r cr
  [ENDIF]
  disp8-slot +0?exit<
    pat-cmd (raw-c,)
    disp8-slot (raw-c,)
    skip-bytes:1+!
    -1 disp8-slot:!
    1 (adv-bytes)
  >? ;

|: (jrdisp8)  ( val -- val )
  (* nothing *) ;

|: (val8)  ( val -- val )
  [ Z80ASM-PATTERN-DEBUG-MORE ] [IF]
    endcr ." val8 slot: " value-slot 0.r cr
  [ENDIF]
  value-slot +0?exit<
    pat-cmd (raw-c,)
    value-slot (raw-c,)
    skip-bytes:1+!
    -1 value-slot:!
    1 (adv-bytes)
  >? ;

|: (val16)  ( val -- val )
  [ Z80ASM-PATTERN-DEBUG-MORE ] [IF]
    endcr ." val16 slot: " value-slot 0.r cr
  [ENDIF]
  value-slot +0?exit<
    pat-cmd (raw-c,)
    value-slot $80 or (raw-c,)
    2 skip-bytes:+!
    -1 value-slot:!
    2 (adv-bytes)
  >? ;


: take-over
  ['] (c,) z80asm:emit:c,:!
  ['] (here) z80asm:emit:here:!
  ['] (c@) z80asm:emit:c@:!
  ['] (c!) z80asm:emit:c!:!
  ['] (label) z80asm:emit:<label>:!
  ['] (instr-start) z80asm:emit:<instr:!
  ['] (instr-end) z80asm:emit:instr>:!
  ['] (disp8) z80asm:emit:<disp8>:!
  ['] (jrdisp8) z80asm:emit:<jrdisp8>:!
  ['] (val8) z80asm:emit:<val8>:!
  ['] (val16) z80asm:emit:<val16>:! ;

;; used for pattern slot callback
module z80p-slots
<disable-hash>
: slot-handler  ( -- value )  0 ;
end-module z80p-slots

@: good-slot-name?  ( addr count -- bool )
  dup 3 < ?exit< 2drop false >?
  over c@ [char] { = not?exit< 2drop false >?
  + 1- c@ [char] } = ;

:noname  ( addr count skip-hidden? vocid -- cfa TRUE // FALSE )
  system:?exec
  vocid: z80p-slots = not?exit< 3drop false >?
  drop
  2dup good-slot-name? not?exit< 2drop false >?
  [ Z80ASM-PATTERN-DEBUG-MORE ] [IF]
    endcr ." new slot: " 2dup type cr
  [ENDIF]
  z80asm:arg-label ?error" two consecutive slots? why?"
  resv-slot-count 2 = ?error" too many slots!"
  new-slot
  dup 1+ z80asm:arg-label:!
  resv-slot-count resv-slot-count:1+!
  resv-nth-slot!
  ['] z80p-slots:slot-handler  true
; vocid: z80p-slots system:vocid-find-cfa!


;; called when we finished compiling the pattern
vect-empty pattern-finished (published)

module z80p-helpers
<disable-hash>
*: ]]
  system:?exec
  z80asm:a;
  restore-cbs
  vocid: z80p-slots context@ = not?error" module imbalance!"
  pop-ctx
  vocid: z80p-helpers context@ = not?error" module imbalance!"
  pop-ctx
  z80asm:instr:end-code
  [ Z80ASM-PATTERN-DEBUG-DUMP ] [IF]
    dump-pattern
  [ENDIF]
  pattern-finished
;
end-module z80p-helpers


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; initialise and run pattern compiler

;; shouild be called once at program startup
@: initialize
  wipe-slots ;


@: start-pattern
  system:?exec
  reset-pattern
  save-cbs
  take-over
  z80-code
  push-ctx voc-ctx: z80p-helpers
  push-ctx voc-ctx: z80p-slots ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; pattern matcher

<published-words>
struct:new pattern
  field: pat^
  field: slot-count
  field: slot-info^
  field: slots^
end-struct
<public-words>

;; call after the pattern parser complete.
;; this creates dynamically allocated `pattern` structure.
@: make-pattern  ( -- addr^ )
  pattern:@size-of dynmem:?zalloc >r
  ;; copy pattern data
  pattern-size dynmem:?zalloc r@ pattern:pat^:!
  pat-buffer r@ pattern:pat^ pattern-size cmove
  ;; store slot count
  slots-used r@ pattern:slot-count:!
  ;; copy slots
  slots-used ?<
    ;; alloc memory for slotrecs
    slots-used slot-rec:@size-of * dynmem:?zalloc r@ pattern:slot-info^:!
    ;; copy
    slots r@ pattern:slot-info^ slots-used slot-rec:@size-of * cmove
    ;; realloc names
    r@ pattern:slot-info^ slots-used for
      dup dup slot-rec:name$ count string:$new
      ( slot^ slot^ addr count )
      rot slot-rec:name$:!
    slot-rec:@size-of + endfor drop
    ;; alloc memory for slot contents
    slots-used 4* dynmem:?zalloc r@ pattern:slots^:!
  >?
  r> ;

|: ?pat-good-slot  ( index pat^ )
  pattern:slot-count u>= ?error" invalid slot index!" ;

@: pat-nth-slot-name  ( index pat^ -- addr count )
  2dup ?pat-good-slot
  pattern:slot-info^ swap slot-rec:@size-of * +
  slot-rec:name$ count ;

@: pat-nth-slot@  ( index pat^ -- value )
  2dup ?pat-good-slot
  pattern:slots^ dd-nth @ ;

@: pat-nth-slot!  ( value index pat^ -- value )
  2dup ?pat-good-slot
  pattern:slots^ dd-nth ! ;

@: pat-find-slot  ( addr count pat^ -- index TRUE // FALSE )
  dup pattern:slot-count
  swap pattern:slot-info^ swap
  (find-slot-at) ;

@: pat-named-slot-index  ( addr count pat^ -- index )
  >r 2dup r> pat-find-slot not?< drop
    " cannot find peep pattern slot \'" pad$:!
    pad$:+ " \'!" pad$:+
    pad$:@ error
  >?
  nrot 2drop ;

@: pat-named-slot@  ( addr count pat^ -- value )
  dup >r pat-named-slot-index
  r> pat-nth-slot@ ;


@: pat-instr-count  ( pat^ -- count )
  pattern:pat^ c@ ;

|: (pat-skip-instr)  ( pat-instr-addr -- next-pat-instr-addr )
  c@++ swap << ( count addr )
    c@++ pat-cmd = ?< c@++ drop >?
  1 under- over ?^||
  else| nip >> ;

|: (pat-nth-instr^)  ( index pat^ -- pat-instr-addr )
  2dup pat-instr-count dup u< not?error" invalid pattern instruction index!"
  swap pattern:pat^ 1+
  swap 1- for (pat-skip-instr) endfor ;

@: pat-nth-instr-len  ( index pat^ -- len )
  (pat-nth-instr^) c@ ;

<published-words>
;; vectors for the matcher
;; index is in the backwards order! i.e. `0` is the last instruction.
vect mt-has-n-instructions?  ( n -- bool )
vect mt-nth-instr-addr  ( n -- addr )
vect mt-nth-instr-len  ( n -- len )
vect mt-c@  ( addr -- byte )

;; "match" stores pattern address here.
;; note that the address is stored even if the pattern is failed to match.
0 quan last-pattern
<public-words>

0 quan curr-instr
0 quan curr-instr-addr

|: mt-w@  ( addr -- word )
  dup mt-c@ swap 1+ mt-c@ 256 * + ;

|: (do-word-slot)  ( slot-idx )
     \ endcr ." word slot #" dup 0.r ." ; max=" last-pattern pattern:slot-count 0.r cr
  curr-instr-addr mt-w@ swap
  last-pattern pat-nth-slot!
  curr-instr-addr:2+! ;

|: (do-byte-slot)  ( slot-idx )
    \ endcr ." byte slot #" dup 0.r ." ; max=" last-pattern pattern:slot-count 0.r cr
  curr-instr-addr mt-c@ swap
  last-pattern pat-nth-slot!
  curr-instr-addr:1+! ;

|: (match-instr)  ( pat-instr-addr -- next-pat-instr-addr TRUE // FALSE )
  c@++  ( addr instr-bytes )
  dup curr-instr mt-nth-instr-len = not?exit< 2drop false >?
  curr-instr mt-nth-instr-addr curr-instr-addr:!
  swap << ( bytes-left addr )
    c@++ dup pat-cmd = ?< drop
      c@++ dup 255 = ?< drop
        pat-cmd curr-instr-addr mt-c@ = not?exit< 2drop false >?
        curr-instr-addr:1+!
        1 under-
      ||
        dup $80 and ?< $7F and (do-word-slot) 2 || (do-byte-slot) 1 >?
        under-
      >?
    || curr-instr-addr mt-c@ = not?exit< 2drop false >?
       curr-instr-addr:1+!
       1 under-
    >?
  over ?^||
  else| nip >>
  true ;


@: match  ( pat^ -- bool )
  dup last-pattern:!
  pat-instr-count mt-has-n-instructions? not?exit&leave
  last-pattern pattern:pat^ c@++ << ( pat-instr-addr instr-left )
    dup +?^|
      1- curr-instr:!
      (match-instr) not?exit< false >?
    curr-instr |?
  else| 2drop >>
  true ;


0 quan last-compiled-pattern (published)
0 quan in-pattern?
0 quan was-comp?

|: (peep-done)
  in-pattern? not?error" ICE: not compiling a peephole pattern!"
  in-pattern?:!f
  make-pattern dup last-compiled-pattern:!
  was-comp? ?<
    [\\] ] #,
  >? ;

@: peep-pattern:[[
  in-pattern? ?error" already compiling a peephole pattern!"
  system:comp? dup was-comp?:! ?< [\\] [ >?
  ['] (peep-done) pattern-finished:!
  in-pattern?:!t
  z80asm-pat:start-pattern
; immediate

seal-module
end-module Z80ASM-PAT


*: peep-pattern:[[
  [\\] z80asm-pat:peep-pattern:[[ ;

*: peep-match  ( pat^ -- bool )
  system:?comp
  \\ z80asm-pat:match ;

;; can be used only immediately after "peep-pattern:[[ ... ]]".
;; this is because it uses "last-compiled-pattern" variable to resolve names.
*: peep:  ( -- value )  \ name
  system:?comp
  parse-name z80asm-pat:last-compiled-pattern z80asm-pat:pat-named-slot-index
  #, \\ z80asm-pat:last-pattern \\ z80asm-pat:pat-nth-slot@ ;

*: peep#  ( -- #-of-instructions )
  system:?comp
  \\ z80asm-pat:last-pattern \\ z80asm-pat:pat-instr-count ;

*: peep-remove-instructions  ( -- #-of-instructions )
  system:?comp
  [\\] peep#
  \\ tcom:xasm:remove-n-last-instructions ;

;; this automatically blocks matching if peephole optimiser is not enabled.
:noname  ( n -- bool )
  OPT-OPTIMIZE-PEEPHOLE? not?exit< drop false >?
  tcom:xasm:can-remove-n-last?
; z80asm-pat:mt-has-n-instructions?:!
['] tcom:xasm:ilist-nth-addr z80asm-pat:mt-nth-instr-addr:!
['] tcom:xasm:ilist-nth-len z80asm-pat:mt-nth-instr-len:!
['] tcom:zx-c@ z80asm-pat:mt-c@:!

\EOF

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple z80 assembler emitter

gewrgrewg

create instr-buf   1024 allot create;
create instr-lens  256 4* allot create;
create instr-addrs 256 4* allot create;
0 quan instr-count
0 quan instr-addr
0 quan instr-begin-addr

:noname  ( byte )
  \ endcr ." C,: ADDR=$" instr-addr instr-buf - .hex4 ."  BYTE=$" dup .hex2 cr
  instr-addr c!
  instr-addr:1+!
; z80asm:emit:c,:!

:noname  ( -- here )
  instr-addr instr-buf -
; z80asm:emit:here:!

:noname  ( addr -- byte )
  \ endcr ." C@: ADDR=$" dup .hex4 cr
  instr-buf + c@
; z80asm:emit:c@:!

:noname  ( byte addr )
  \ endcr ." C!: ADDR=$" over .hex4 ."  BYTE=$" dup .hex2 cr
  instr-buf + c!
; z80asm:emit:c!:!

:noname  ( value type idx -- value )
  error" no labels!"
; z80asm:emit:<label>:!

:noname
  \ endcr ." === NEW INSTR #" instr-count . ." at $" instr-addr instr-buf - .hex4 cr
  instr-addr instr-begin-addr:!
  instr-addr instr-buf - instr-count instr-addrs dd-nth !
; z80asm:emit:<instr:!

:noname
  \ endcr ." *** INSTR #" instr-count . ." ENDS at $" instr-addr instr-buf - .hex4 cr
  instr-addr instr-begin-addr - instr-count instr-lens dd-nth !
  instr-count:1+!
; z80asm:emit:instr>:!

['] noop z80asm:emit:<disp8>:!
['] noop z80asm:emit:<jrdisp8>:!
['] noop z80asm:emit:<val8>:!
['] noop z80asm:emit:<val16>:!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; peephole matcher tester

:noname  ( n -- bool )
  \ endcr ." HAS-N-INSTR: " dup 0.r cr
  instr-count <=
; z80asm-pat:mt-has-n-instructions?:!

:noname  ( n -- addr )
  \ endcr ." NTH-INSTR-ADDR: " dup 0.r cr
  instr-count swap - 1-
  instr-addrs dd-nth @
  \ endcr ."   addr=$" dup .hex4 cr
; z80asm-pat:mt-nth-instr-addr:!

:noname  ( n -- len )
  \ endcr ." NTH-INSTR-LEN: " dup 0.r cr
  instr-count swap - 1-
  instr-lens dd-nth @
  \ endcr ."   len=" dup 0.r cr
; z80asm-pat:mt-nth-instr-len:!

:noname  ( addr -- byte )
  instr-buf + c@
; z80asm-pat:mt-c@:!


: reset-instr-buffer
  instr-count:!0
  instr-buf instr-addr:!
;


module zasdebug-helpers
<disable-hash>
*: <end-asm>
  z80asm:a;
  vocid: zasdebug-helpers context@ = not?error" module imbalance!"
  pop-ctx ;
end-module zasdebug-helpers

*: <asm>
  system:?exec
  reset-instr-buffer
  z80-code
  push-ctx
  vocid: zasdebug-helpers context! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; peephole pattern debug code

z80asm-pat:initialize


*: peep-pattern:[[
  z80asm-pat:start-pattern ;


peep-pattern:[[
  ld  a, l
  ld  c, # $2f
  ld  hl, # {hl-value}
  ld  {disp0} (ix+), # {store-value}
  ld  sp, () {sp-addr}
  ld  a, # {a-value}
]]
z80asm-pat:make-pattern quan xpat


" {a-value}" xpat z80asm-pat:pat-find-slot
[IFNOT] abort [ENDIF]
endcr ." index=" 0.r cr


: .slot  ( addr count )
  endcr 2dup type ." ="
  xpat z80asm-pat:pat-named-slot-index
  xpat z80asm-pat:pat-nth-slot@
  0.r cr ;

<asm>
  ld  a, l
  ld  c, # $2f
  ld  hl, # 666
  ld  -2 (ix+), # 69
  ld  sp, () 669
  ld  a, # 42
<end-asm>

xpat z80asm-pat:match
[IF]
endcr ." === MATCHED! ===\n"
" {hl-value}" .slot
" {store-value}" .slot
" {disp0}" .slot
" {sp-addr}" .slot
" {a-value}" .slot
[ENDIF]
