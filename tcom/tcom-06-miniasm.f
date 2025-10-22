;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System, featuring Succubus Little Sister
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Succubus native code generator: miniasm
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module TCOM

module XASM
\ <disable-hash>
<separate-hash>

vect byte, (published)
vect byte! (published)
vect byte@ (published)
vect $here (published)
vect rewind (published) -- rewind back by positive number of bytes

vect word-begin (published)

@: at-word-begin?  ( -- bool )
  $here word-begin = ;

@: word@  ( zx-addr )
  dup byte@ swap 1+ byte@ 256 * + ;

;; callbacks
vect-empty instr-begin (published)
vect-empty instr-end (published)

OPT-OPTIMIZE-PEEPHOLE? quan push-pop-peephole? (published)

0 quan stat-push-pop-removed (published)
0 quan stat-pop-push-removed (published)
0 quan stat-push-pop-replaced (published)
0 quan stat-restore-tos-exx (published)
0 quan stat-lit-tos (published)
0 quan stat-8bit-optim (published)
0 quan stat-bool-optim (published)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; generated instructions start addresses

(*
each list item holds the start address of the machine instruction.
this way we can easily calculate length, and check bytes. last
added instruction is assumed to go from the last appended address
to the current $here.

list indices starts from the last added instruction (i.e. it works
like the stack). instruction #0 is always the last added one.
*)

1024 constant ilist-max
;; use 4 bytes for address, because memory doesn't matter here.
create ilist ilist-max 4* allot create;
0 quan ilist-used
;; separate counter for instruction removal
0 quan ilist-remove-counter

@: ilist#  ( -- count )
  ilist-used ;

;; 0 is the last added instruction, 1 is the previous one, and so on.
|: (ilist-nth^)  ( idx -- array-addr )
  dup ilist-used u>= ?exit<
    " invalid ilist instruction index: " pad$:! pad$:#s pad$:@ error >?
  1+ negate ilist-used +
  4* ilist + ;

\ TODO: we can remove half of the instructions instead of crashing.
|: ilist-append  ( zx-addr )
  [ 0 ] [IF]
    endcr ." ilist-append: addr=$" dup .hex4 ."  count=" ilist-used 0.r cr
  [ENDIF]
  ilist-used ilist-max u>= ?<
    endcr ." WARNING! peephole optimiser queue overflow. wiping the queue."
    ilist-used:!0 >?
  ilist-used:1+!
  0 (ilist-nth^) ! ;

@: ilist-start-new-instr
  $here ilist-append
  ilist-remove-counter:1+! ;

;; address of the nth instruction.
;; 0 is the last added instruction, 1 is the previous one, and so on.
@: ilist-nth-addr  ( idx -- zx-addr )
  \ dup ilist-used u>= ?exit< drop $here >?
  (ilist-nth^) @ ;

;; length of the nth instruction.
;; 0 is the last added instruction, 1 is the previous one, and so on.
@: ilist-nth-len  ( idx -- len )
  dup ilist-used u>= ?exit< drop 0 >?
  ;; instruction #0 (last) goes from the last record to $here
  dup 0?exit< $here swap ilist-nth-addr - >?
  ;; other instructions: to record #-1
  ;; as addresses are sequential, we can do this:
  (ilist-nth^) dup 4+ @ swap @ - ;


|: ilist-remove-last-record
  ilist-used 0?error" wtf?! (ilist-remove-last-record)"
  ilist-used:1-! ;

\ @: ilist-replace-last-addr  ( zx-addr )
\   ilist-used 0?error" wtf?! (ilist-replace-last-addr)"
\   0 (ilist-nth^) ! ;

;; this removes last generated instruction, and fixes word start if necessary
@: remove-last-instruction
  push-pop-peephole? not?error" peephole disabled!"
  0 ilist-nth-len dup -0?error" no previous machine instruction!"
  ilist-remove-counter -0?error" no previous machine instruction to remove!"
  rewind
  ilist-remove-last-record
  ilist-remove-counter:1-! ;

@: remove-n-last-instructions  ( n )
  dup -0?error" invalid argument to \'remove-n-last-instructions\'!"
  for remove-last-instruction endfor ;

@: can-remove-n-last?  ( n -- bool )
  dup -0?error" invalid argument to \'can-remove-n-last?\'!"
  ilist-remove-counter <= ;


;; wipe collected instrions list.
;; this effectively blocks peephole optimising.
;; should be called in labels and such.
@: reset-ilist
  ilist-used:!0
  ilist-remove-counter:!0 ;

;; used after branch destination.
;; peephole can look at the instructions, but cannot remove them.
@: reset-ilist-brn
  ilist-remove-counter:!0
  ;;FIXME: but those instructions might be jumped over...
  reset-ilist
;


;; this is called from branch emiters and branch destination fixers.
;; it is always automatically called, just to play safe.
|: xx-reset-ilist-brn
  reset-ilist-brn ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; additional memory access API

@: word!  ( value zx-addr )
  over lo-byte over byte!
  swap hi-byte swap 1+ byte! ;

@: word,  ( value )
  dup lo-byte byte, hi-byte byte, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; common instruction generation code

@: i-begin
  ilist-start-new-instr
  instr-begin ;

@: i-end
  instr-end ;


|: gen-c,  ( byte )
  lo-byte byte, ;

|: gen-w,  ( word )
  dup gen-c, hi-byte gen-c, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; conditions

module cond
<disable-hash>
enum{
  def: nz
  def: z
  def: nc
  def: c
  def: po
  def: pe
  def: p
  def: m
}
end-module cond  (published)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; registers

module reg
<disable-hash>

;; 8-bit registers
$40 constant B
$41 constant C
$42 constant D
$43 constant E
$44 constant H
$45 constant L
$46 constant (HL)
$47 constant A

;; 16-bit registers
$00 constant BC
$01 constant DE
$02 constant HL
$13 constant SP
$23 constant AF
\ $33 constant AFX
\ $33 constant AF'

;; 16-bit memreg
(*
$00 constant (BC)
$01 constant (DE)
$02 constant (SP)
*)

end-module reg  (published)

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; internal utilities

|: r16*2  ( regidx -- cpu-regidx )
  \ dup 3 u> ?< endcr ." FUCK! " dup 0.r cr >?
  dup 3 u> ?error" gen: invalid r16 (r16*2)"
  2* ;

;; convert to the form suitable for @xRx
|: r16->opc  ( regidx )
  r16*2 8 * ;

|: r8->opc  ( regidx )
  8 * ;

|: ?r16-no-sp-af  ( r16 -- r16 )
  dup 2 u> ?error" gen: invalid r16 (?r16-no-sp-af)" ;

|: ?r16-af  ( r16 -- r16 )
  dup reg:AF = ?exit< drop 3 >?
  dup 2 u> ?error" gen: invalid r16 (?r16-af)" ;

|: ?r16-sp  ( r16 -- r16 )
  dup reg:SP = ?exit< drop 3 >?
  dup 2 u> ?error" gen: invalid r16 (?r16-sp)" ;

|: ?r16-mem  ( r16 -- r16 )
  dup 2 u> ?error" gen: invalid r16 (?r16-mem)" ;

|: ?r8  ( r16 -- r8 )
  dup $40 $47 bounds not?error" gen: invalid r8 (?r8)"
  $40 - ;

|: ?r8-no-a  ( r16 -- r8 )
  dup 2 u> ?error" gen: invalid r8 (?r8-no-a)"
  2* ;

|: (disp,)  ( disp )
  dup -128 128 within not?error" invalid disp"
  gen-c, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; code emiters

|: (new-emit)  ( -- patch-addr )  \ name
  <builds (published) here 0 ,
  does> i-begin @execute i-end ;

|: emiter:  \ name
  (new-emit) >r
  [\\] :noname swap r> ! ;

|: (new-emit-brn)  ( -- patch-addr )  \ name
  <builds (published) here 0 ,
  does> i-begin @execute i-end
  xx-reset-ilist-brn ;

|: brn-emiter:  \ name
  (new-emit-brn) >r
  [\\] :noname swap r> ! ;

$DD constant pfx-IX (published)
$FD constant pfx-IY (published)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RST

|: (rst-n)  ( addr )
  dup $38 u> ?error" invalid RST address"
  dup $07 and ?error" invalid RST address"
  8 u/ dup 7 u> ?error" invalid RST address"
  8 * @307 + gen-c, ;

;; this is like "CALL", so it is a branch instruction
brn-emiter: rst-n  ( addr )  (rst-n) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple instructions without arguments

emiter: nop  @000 gen-c, ;
emiter: exx  @331 gen-c, ;
brn-emiter: ret  @311 gen-c, ;
emiter: daa  @047 gen-c, ;
emiter: cpl  @057 gen-c, ;
emiter: scf  @067 gen-c, ;
emiter: ccf  @077 gen-c, ;
emiter: neg  $ED gen-c, @104 gen-c, ;

emiter: halt @166 gen-c, ;
emiter: di   @363 gen-c, ;
emiter: ei   @373 gen-c, ;

emiter: rlca @007 gen-c, ;
emiter: rrca @017 gen-c, ;
emiter: rla  @027 gen-c, ;
emiter: rra  @037 gen-c, ;

emiter: rrd  $ED gen-c, @147 gen-c, ;
emiter: rld  $ED gen-c, @157 gen-c, ;

emiter: ex-af-afx  @010 gen-c, ;
emiter: ex-de-hl   @353 gen-c, ;

emiter: inc-a  @074 gen-c, ;
emiter: dec-a  @075 gen-c, ;

emiter: inc-(hl)  @064 gen-c, ;
emiter: dec-(hl)  @065 gen-c, ;

emiter: ldir  $ED gen-c, @260 gen-c, ;
emiter: lddr  $ED gen-c, @270 gen-c, ;

emiter: ldi  $ED gen-c, @240 gen-c, ;
emiter: ldd  $ED gen-c, @250 gen-c, ;

emiter: a->i  $ED gen-c, @107 gen-c, ;
emiter: i->a  $ED gen-c, @127 gen-c, ;
emiter: a->r  $ED gen-c, @117 gen-c, ;
emiter: r->a  $ED gen-c, @137 gen-c, ;

emiter: i<-a  $ED gen-c, @107 gen-c, ;
emiter: a<-i  $ED gen-c, @127 gen-c, ;
emiter: r<-a  $ED gen-c, @117 gen-c, ;
emiter: a<-r  $ED gen-c, @137 gen-c, ;

emiter: im0   $ED gen-c, @106 gen-c, ;
emiter: im1   $ED gen-c, @126 gen-c, ;
emiter: im2   $ED gen-c, @136 gen-c, ;

emiter: ex-(sp)-hl  @343 gen-c, ;

emiter: sp->(nn)  ( addr )  $ED gen-c, @163 gen-c, ;
emiter: (nn)->sp  ( addr )  $ED gen-c, @173 gen-c, ;

emiter: (nn)<-sp  ( addr )  $ED gen-c, @163 gen-c, ;
emiter: sp<-(nn)  ( addr )  $ED gen-c, @173 gen-c, ;

emiter: #->sp  ( value )  @061 gen-c, gen-w, ;
\ emiter: add-hl-sp         @071 gen-c, ;

emiter: hl->sp ( addr )  @371 gen-c, ;
emiter: sp<-hl ( addr )  @371 gen-c, ;

emiter: inc-sp  @063 gen-c, ;
emiter: dec-sp  @073 gen-c, ;

emiter: out-(c)-b  $ED gen-c, @101 gen-c, ;
emiter: out-(c)-c  $ED gen-c, @111 gen-c, ;
emiter: out-(c)-d  $ED gen-c, @121 gen-c, ;
emiter: out-(c)-e  $ED gen-c, @131 gen-c, ;
emiter: out-(c)-h  $ED gen-c, @141 gen-c, ;
emiter: out-(c)-l  $ED gen-c, @151 gen-c, ;
emiter: out-(c)-a  $ED gen-c, @171 gen-c, ;

emiter: in-b-(c)  $ED gen-c, @100 gen-c, ;
emiter: in-c-(c)  $ED gen-c, @110 gen-c, ;
emiter: in-d-(c)  $ED gen-c, @120 gen-c, ;
emiter: in-e-(c)  $ED gen-c, @130 gen-c, ;
emiter: in-h-(c)  $ED gen-c, @140 gen-c, ;
emiter: in-l-(c)  $ED gen-c, @150 gen-c, ;
emiter: in-a-(c)  $ED gen-c, @170 gen-c, ;

emiter: in-a-(c#)  ( port )  @333 gen-c, gen-c, ;
emiter: out-(c#)-a ( port )  @323 gen-c, gen-c, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; i don't know where to put this ;-)

emiter: inc-(ix+#)  ( disp )  pfx-IX gen-c, @064 gen-c, (disp,) ;
emiter: dec-(ix+#)  ( disp )  pfx-IX gen-c, @065 gen-c, (disp,) ;

emiter: inc-(iy+#)  ( disp )  pfx-IY gen-c, @064 gen-c, (disp,) ;
emiter: dec-(iy+#)  ( disp )  pfx-IY gen-c, @065 gen-c, (disp,) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; branches and calls

@303 constant jp-opc    (published)
@315 constant call-opc  (published)

brn-emiter: jp-hl  @351 gen-c, ;
brn-emiter: jp-ix  pfx-IX gen-c, @351 gen-c, ;
brn-emiter: jp-iy  pfx-IY gen-c, @351 gen-c, ;

brn-emiter: jp-#    ( zx-addr )  jp-opc gen-c, gen-w, ;
brn-emiter: call-#  ( zx-addr )  call-opc gen-c, gen-w, ;

@: mk-jp-cc-opc  ( cond )
  dup 7 u> ?error" invalid cond code for jp"
  8 * @302 + ;

@: mk-call-cc-opc  ( cond )
  dup 7 u> ?error" invalid cond code for call"
  8 * @304 + ;

brn-emiter: jp-#-cc   ( zx-addr cond )  mk-jp-cc-opc gen-c, gen-w, ;
brn-emiter: call-#-cc ( zx-addr cond )  mk-call-cc-opc gen-c, gen-w, ;

@: jp-somewhere   ( -- zx-patch-addr )  0 jp-#  $here 2- ;
@: call-somewhere ( -- zx-patch-addr )  0 call-#  $here 2- ;

@: jp-cc    ( cond -- zx-patch-addr )  0 swap jp-#-cc  $here 2- ;
@: call-cc  ( cond -- zx-patch-addr )  0 swap call-#-cc  $here 2- ;

\ FIXME: turn this into a normal instruction branch instead?
brn-emiter: ret-cc  ( cond )
  dup 7 u> ?error" invalid cc for call"
  8 * @300 + gen-c, ;

brn-emiter: jr-disp-cc  ( disp cond )
  dup 3 u> ?error" invalid cond code for jr"
  8 * @040 + gen-c, lo-byte gen-c, ;

@: jr-somewhere  ( -- zx-patch-addr )
  i-begin
  @030 gen-c, 0 gen-c,
  i-end
  xx-reset-ilist-brn
  $here 1- ;

@: jr-cc  ( cond -- zx-patch-addr )
  0 swap jr-disp-cc
  $here 1- ;

@: djnz-somewhere  ( -- zx-patch-addr )
  i-begin
  @020 gen-c, 0 gen-c,
  i-end
  xx-reset-ilist-brn
  $here 1- ;


@: jr-dest-at!  ( dest-addr patch-addr )
  tuck 1+ - dup -128 128 within not?error" jr destination is too far away"
  swap byte!
  xx-reset-ilist-brn ;

@: jp-dest-at!   ( dest-addr patch-addr )  word! xx-reset-ilist-brn ;
@: call-dest-at! ( dest-addr patch-addr )  jp-dest-at! ;

@: jr-dest!  ( patch-addr )  $here swap jr-dest-at! ;
@: jp-dest!  ( patch-addr )  $here swap jp-dest-at! ;


@: djnz-#  ( zx-dest-addr )  djnz-somewhere jr-dest-at! ;
@: jr-#-cc ( zx-addr cond )  jr-cc jr-dest-at! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; used in peephole optimisers

;; @100 + r8dest*8 + r8src
|: (r16x->r16x)  ( rsrc rdest opc-add-src opc-add-dest )
  r8->opc rot
  ?r16-no-sp-af
  r16->opc +
  ( rsrc asrc r8dest*8 )
  rot
  ?r16-no-sp-af
  r16*2
  ( asrc r8dest*8 r8src )
  + + @100 + gen-c, ;

|: (r16h->r16l)  ( rsrc rdest )  0 1 (r16x->r16x) ;
|: (r16l->r16h)  ( rsrc rdest )  1 0 (r16x->r16x) ;
|: (r16l->r16l)  ( rsrc rdest )  1 1 (r16x->r16x) ;
|: (r16h->r16h)  ( rsrc rdest )  0 0 (r16x->r16x) ;

;; note that r16l MUST be loaded first, to not interfere with peephole optimiser.
|: (r16->r16)  ( rsrc rdest )
  ?r16-no-sp-af
  2dup = ?exit< 2drop >?
  2dup (r16l->r16l) (* i-end i-begin *) (r16h->r16h) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; push/pop

emiter: push-af @365 gen-c, ;
emiter: pop-af  @361 gen-c, ;

;; optimise "push r16 / pop r16" to "r16->r16"

|: (pop-r16)  ( reg-idx )
  ?r16-af
  r16->opc @301 + gen-c, ;

emiter: pop-r16  ( regidx )  (pop-r16) ;
emiter: pop-hl  reg:hl (pop-r16) ;
emiter: pop-de  reg:de (pop-r16) ;
emiter: pop-bc  reg:bc (pop-r16) ;
emiter: pop-ix  pfx-IX gen-c, @341 gen-c, ;
emiter: pop-iy  pfx-IY gen-c, @341 gen-c, ;


|: last-push-r16?  ( -- r16 TRUE // FALSE )
\ endcr ." ::: " ilist-prev-len 0.r cr
  0 ilist-nth-len 1 = not?exit&leave
  0 ilist-nth-addr byte@ <<
    @305 of?v| reg:bc true |?
    @325 of?v| reg:de true |?
    @345 of?v| reg:hl true |?
  else| drop false >> ;

|: (opt-push-pop-r16)  ( regidx -- regidx pushreg TRUE // regidx FALSE )
  push-pop-peephole? not?exit&leave
  dup 3 u< not?exit&leave
  \ dup 3 u< not?exit< endcr ." BAD REG: $" $here .hex4 cr false >?
  at-word-begin? not?exit&leave
  \ at-word-begin? not?exit< endcr ." NOT BEGIN: $" $here .hex4 cr false >?
  last-push-r16?
(*
    dup 0?< endcr ." NOT-PUSH: $" $here .hex4
            ."  last-len=" 0 ilist-nth-len .
            ." last-addr=" 0 ilist-nth-addr .hex4
            cr
         || endcr ." REPL-PUSH: $" $here .hex4
            ."  last-len=" 0 ilist-nth-len 0.r cr
        >?
*)
  ;

;; push r16 / pop r16 -> nothing
;; push r16s / pop r16d -> r16s->r16d
@: pop-r16-peephole  ( regidx )
  (opt-push-pop-r16) not?exit< i-begin (pop-r16) i-end >?
  ;; remove last push
  remove-last-instruction
  ;; check if we have something to do
  2dup = ?exit< 2drop
    ;; replace with nothing
    [ OPT-DEBUG-PEEPHOLE? ] [IF]
      i-begin
      $00 gen-c, @111 gen-c, ;; ld c,c
      i-end
    [ENDIF]
    stat-push-pop-removed:1+!
  >?
  ;; different registers, generate two loads
  ( reg-dest reg-src )
  i-begin
  swap (r16->r16)
  [ OPT-DEBUG-PEEPHOLE? ] [IF]
    $00 gen-c, @100 gen-c, ;; ld b,b
  [ENDIF]
  stat-push-pop-replaced:1+!
  i-end ;

@: pop-hl-peephole  reg:hl pop-r16-peephole ;
@: pop-de-peephole  reg:de pop-r16-peephole ;
@: pop-bc-peephole  reg:bc pop-r16-peephole ;

;; push r16 / pop r16 -> nothing
;; push r16s / pop r16d -> r16s->r16d
@: pop-r16-peephole-ignore  ( regidx )
  (opt-push-pop-r16) not?exit< i-begin (pop-r16) i-end >?
  ;; remove last push
  remove-last-instruction
  2drop
  ;; replace with nothing
  [ OPT-DEBUG-PEEPHOLE? ] [IF]
    i-begin
    $00 gen-c, @122 gen-c, ;; ld d,d
    i-end
  [ENDIF]
  stat-push-pop-removed:1+! ;

@: pop-hl-peephole-ignore  reg:hl pop-r16-peephole-ignore ;
@: pop-de-peephole-ignore  reg:de pop-r16-peephole-ignore ;
@: pop-bc-peephole-ignore  reg:bc pop-r16-peephole-ignore ;


|: (push-r16)  ( regidx )
  ?r16-af
  r16->opc @305 + gen-c, ;

emiter: push-r16  ( regidx )  (push-r16) ;
emiter: push-bc  reg:bc (push-r16) ;
emiter: push-de  reg:de (push-r16) ;
emiter: push-hl  reg:hl (push-r16) ;
emiter: push-ix  pfx-IX gen-c, reg:hl (push-r16) ;
emiter: push-iy  pfx-IY gen-c, reg:hl (push-r16) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; literal loads

|: (#->r16)  ( value regidx )
  ?r16-sp
  r16->opc @001 + gen-c,
  gen-w, ;

emiter: #->r16  ( value regidx )  (#->r16) ;
emiter: #->bc  ( value ) reg:bc (#->r16) ;
emiter: #->de  ( value ) reg:de (#->r16) ;
emiter: #->hl  ( value ) reg:hl (#->r16) ;
emiter: #->ix  ( value ) pfx-IX gen-c, reg:hl (#->r16) ;
emiter: #->iy  ( value ) pfx-IY gen-c, reg:hl (#->r16) ;


|: (c#->r16lh)  ( value regidx high? )
  ?< @006 || @016 >?
  swap ?r16-no-sp-af
  r16->opc + gen-c,
  lo-byte gen-c, ;

emiter: c#->r16l  ( value regidx )  false (c#->r16lh) ;
emiter: c#->r16h  ( value regidx )  true (c#->r16lh) ;
emiter: c#->b  ( value ) reg:bc true (c#->r16lh) ;
emiter: c#->c  ( value ) reg:bc false (c#->r16lh) ;
emiter: c#->d  ( value ) reg:de true (c#->r16lh) ;
emiter: c#->e  ( value ) reg:de false (c#->r16lh) ;
emiter: c#->l  ( value ) reg:hl false (c#->r16lh) ;
emiter: c#->h  ( value ) reg:hl true (c#->r16lh) ;

emiter: c#->a  ( value )
  @076 gen-c,
  lo-byte gen-c, ;

emiter: c#->(hl)  ( value )
  @066 gen-c,
  lo-byte gen-c, ;


|: (c#->(ixy+#))  ( value disp pfx )
  gen-c,
  @066 gen-c,
  gen-c,
  (disp,) ;

emiter: c#->(ix+#)  ( value disp )  pfx-IX (c#->(ixy+#)) ;
emiter: c#->(iy+#)  ( value disp )  pfx-IY (c#->(ixy+#)) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8-bit memory load and store

|: (r16l->(hl))  ( reg-idx )
  ?r16-no-sp-af
  r16*2
  @161 + gen-c, ;

emiter: r16l->(hl)  ( reg-idx )  (r16l->(hl)) ;
emiter: c->(hl)  reg:bc (r16l->(hl)) ;
emiter: e->(hl)  reg:de (r16l->(hl)) ;
emiter: l->(hl)  reg:hl (r16l->(hl)) ;

emiter: r16l->(ix+#)  ( reg disp )  pfx-IX gen-c, swap (r16l->(hl)) (disp,) ;
emiter: r16l->(iy+#)  ( reg disp )  pfx-IY gen-c, swap (r16l->(hl)) (disp,) ;
emiter: c->(ix+#)  ( disp )  pfx-IX gen-c, reg:bc (r16l->(hl)) (disp,) ;
emiter: e->(ix+#)  ( disp )  pfx-IX gen-c, reg:de (r16l->(hl)) (disp,) ;
emiter: l->(ix+#)  ( disp )  pfx-IX gen-c, reg:hl (r16l->(hl)) (disp,) ;
emiter: c->(iy+#)  ( disp )  pfx-IY gen-c, reg:bc (r16l->(hl)) (disp,) ;
emiter: e->(iy+#)  ( disp )  pfx-IY gen-c, reg:de (r16l->(hl)) (disp,) ;
emiter: l->(iy+#)  ( disp )  pfx-IY gen-c, reg:hl (r16l->(hl)) (disp,) ;

emiter: (hl)<-r16l  ( reg-idx )  (r16l->(hl)) ;
emiter: (hl)<-c  reg:bc (r16l->(hl)) ;
emiter: (hl)<-e  reg:de (r16l->(hl)) ;
emiter: (hl)<-l  reg:hl (r16l->(hl)) ;

emiter: (ix+#)<-r16l  ( disp reg )  pfx-IX gen-c, (r16l->(hl)) (disp,) ;
emiter: (iy+#)<-r16l  ( disp reg )  pfx-IY gen-c, (r16l->(hl)) (disp,) ;
emiter: (ix+#)<-c  ( disp )  pfx-IX gen-c, reg:bc (r16l->(hl)) (disp,) ;
emiter: (ix+#)<-e  ( disp )  pfx-IX gen-c, reg:de (r16l->(hl)) (disp,) ;
emiter: (ix+#)<-l  ( disp )  pfx-IX gen-c, reg:hl (r16l->(hl)) (disp,) ;
emiter: (iy+#)<-c  ( disp )  pfx-IY gen-c, reg:bc (r16l->(hl)) (disp,) ;
emiter: (iy+#)<-e  ( disp )  pfx-IY gen-c, reg:de (r16l->(hl)) (disp,) ;
emiter: (iy+#)<-l  ( disp )  pfx-IY gen-c, reg:hl (r16l->(hl)) (disp,) ;


|: (r16h->(hl))  ( reg-idx )
  ?r16-no-sp-af
  r16*2
  @160 + gen-c, ;

emiter: r16h->(hl)  ( reg-idx )  (r16h->(hl)) ;
emiter: b->(hl)  reg:bc (r16h->(hl)) ;
emiter: d->(hl)  reg:de (r16h->(hl)) ;
emiter: h->(hl)  reg:hl (r16h->(hl)) ;

emiter: r16h->(ix+#)  ( reg disp )  pfx-IX gen-c, swap (r16h->(hl)) (disp,) ;
emiter: r16h->(iy+#)  ( reg disp )  pfx-IY gen-c, swap (r16h->(hl)) (disp,) ;
emiter: b->(ix+#)  ( disp )  pfx-IX gen-c, reg:bc (r16h->(hl)) (disp,) ;
emiter: d->(ix+#)  ( disp )  pfx-IX gen-c, reg:de (r16h->(hl)) (disp,) ;
emiter: h->(ix+#)  ( disp )  pfx-IX gen-c, reg:hl (r16h->(hl)) (disp,) ;
emiter: b->(iy+#)  ( disp )  pfx-IY gen-c, reg:bc (r16h->(hl)) (disp,) ;
emiter: d->(iy+#)  ( disp )  pfx-IY gen-c, reg:de (r16h->(hl)) (disp,) ;
emiter: h->(iy+#)  ( disp )  pfx-IY gen-c, reg:hl (r16h->(hl)) (disp,) ;

emiter: a->(hl)  @167 gen-c, ;
emiter: (hl)->a  @176 gen-c, ;

emiter: (hl)<-r16h  ( reg-idx )  (r16h->(hl)) ;
emiter: (hl)<-b  reg:bc (r16h->(hl)) ;
emiter: (hl)<-d  reg:de (r16h->(hl)) ;
emiter: (hl)<-h  reg:hl (r16h->(hl)) ;

emiter: (ix+#)<-r16h  ( disp reg )  pfx-IX gen-c, (r16h->(hl)) (disp,) ;
emiter: (iy+#)<-r16h  ( disp reg )  pfx-IY gen-c, (r16h->(hl)) (disp,) ;
emiter: (ix+#)<-b  ( disp )  pfx-IX gen-c, reg:bc (r16h->(hl)) (disp,) ;
emiter: (ix+#)<-d  ( disp )  pfx-IX gen-c, reg:de (r16h->(hl)) (disp,) ;
emiter: (ix+#)<-h  ( disp )  pfx-IX gen-c, reg:hl (r16h->(hl)) (disp,) ;
emiter: (iy+#)<-b  ( disp )  pfx-IY gen-c, reg:bc (r16h->(hl)) (disp,) ;
emiter: (iy+#)<-d  ( disp )  pfx-IY gen-c, reg:de (r16h->(hl)) (disp,) ;
emiter: (iy+#)<-h  ( disp )  pfx-IY gen-c, reg:hl (r16h->(hl)) (disp,) ;

emiter: (hl)<-a  @167 gen-c, ;
emiter: a<-(hl)  @176 gen-c, ;


|: (aa-iy#)  ( disp pfx opc )
  swap gen-c,
  gen-c, (disp,) ;

emiter: a->(ix+#)  ( disp )  pfx-IX @167 (aa-iy#) ;
emiter: (ix+#)->a  ( disp )  pfx-IX @176 (aa-iy#) ;
emiter: a->(iy+#)  ( disp )  pfx-IY @167 (aa-iy#) ;
emiter: (iy+#)->a  ( disp )  pfx-IY @176 (aa-iy#) ;

emiter: (ix+#)<-a  ( disp )  pfx-IX @167 (aa-iy#) ;
emiter: a<-(ix+#)  ( disp )  pfx-IX @176 (aa-iy#) ;
emiter: (iy+#)<-a  ( disp )  pfx-IY @167 (aa-iy#) ;
emiter: a<-(iy+#)  ( disp )  pfx-IY @176 (aa-iy#) ;


|: ((hl)->r16l)  ( reg-idx )
  ?r16-no-sp-af
  r16->opc
  @116 + gen-c, ;

emiter: (hl)->r16l  ( reg-idx )  ((hl)->r16l) ;
emiter: (hl)->c  reg:bc ((hl)->r16l) ;
emiter: (hl)->e  reg:de ((hl)->r16l) ;
emiter: (hl)->l  reg:hl ((hl)->r16l) ;

emiter: (ix+#)->r16l  ( disp reg )  pfx-IX gen-c, ((hl)->r16l) (disp,) ;
emiter: (iy+#)->r16l  ( disp reg )  pfx-IY gen-c, ((hl)->r16l) (disp,) ;
emiter: (ix+#)->c  ( disp )  pfx-IX gen-c, reg:bc ((hl)->r16l) (disp,) ;
emiter: (ix+#)->e  ( disp )  pfx-IX gen-c, reg:de ((hl)->r16l) (disp,) ;
emiter: (ix+#)->l  ( disp )  pfx-IX gen-c, reg:hl ((hl)->r16l) (disp,) ;
emiter: (iy+#)->c  ( disp )  pfx-IY gen-c, reg:bc ((hl)->r16l) (disp,) ;
emiter: (iy+#)->e  ( disp )  pfx-IY gen-c, reg:de ((hl)->r16l) (disp,) ;
emiter: (iy+#)->l  ( disp )  pfx-IY gen-c, reg:hl ((hl)->r16l) (disp,) ;

emiter: r16l<-(hl)  ( reg-idx )  ((hl)->r16l) ;
emiter: c<-(hl)  reg:bc ((hl)->r16l) ;
emiter: e<-(hl)  reg:de ((hl)->r16l) ;
emiter: l<-(hl)  reg:hl ((hl)->r16l) ;

emiter: r16l<-(ix+#)  ( reg disp )  pfx-IX gen-c, swap ((hl)->r16l) (disp,) ;
emiter: r16l<-(iy+#)  ( reg disp )  pfx-IY gen-c, swap ((hl)->r16l) (disp,) ;
emiter: c<-(ix+#)  ( disp )  pfx-IX gen-c, reg:bc ((hl)->r16l) (disp,) ;
emiter: e<-(ix+#)  ( disp )  pfx-IX gen-c, reg:de ((hl)->r16l) (disp,) ;
emiter: l<-(ix+#)  ( disp )  pfx-IX gen-c, reg:hl ((hl)->r16l) (disp,) ;
emiter: c<-(iy+#)  ( disp )  pfx-IY gen-c, reg:bc ((hl)->r16l) (disp,) ;
emiter: e<-(iy+#)  ( disp )  pfx-IY gen-c, reg:de ((hl)->r16l) (disp,) ;
emiter: l<-(iy+#)  ( disp )  pfx-IY gen-c, reg:hl ((hl)->r16l) (disp,) ;


|: ((hl)->r16h)  ( reg-idx )
  ?r16-no-sp-af
  r16->opc
  @106 + gen-c, ;

emiter: (hl)->r16h  ( reg-idx )  ((hl)->r16h) ;
emiter: (hl)->b  ( value ) reg:bc ((hl)->r16h) ;
emiter: (hl)->d  ( value ) reg:de ((hl)->r16h) ;
emiter: (hl)->h  ( value ) reg:hl ((hl)->r16h) ;

emiter: (ix+#)->r16h  ( disp reg )  pfx-IX gen-c, ((hl)->r16h) (disp,) ;
emiter: (iy+#)->r16h  ( disp reg )  pfx-IY gen-c, ((hl)->r16h) (disp,) ;
emiter: (ix+#)->b  ( disp )  pfx-IX gen-c, reg:bc ((hl)->r16h) (disp,) ;
emiter: (ix+#)->d  ( disp )  pfx-IX gen-c, reg:de ((hl)->r16h) (disp,) ;
emiter: (ix+#)->h  ( disp )  pfx-IX gen-c, reg:hl ((hl)->r16h) (disp,) ;
emiter: (iy+#)->b  ( disp )  pfx-IY gen-c, reg:bc ((hl)->r16h) (disp,) ;
emiter: (iy+#)->d  ( disp )  pfx-IY gen-c, reg:de ((hl)->r16h) (disp,) ;
emiter: (iy+#)->h  ( disp )  pfx-IY gen-c, reg:hl ((hl)->r16h) (disp,) ;

emiter: r16h<-(hl)  ( reg-idx )  ((hl)->r16h) ;
emiter: b<-(hl)  ( value ) reg:bc ((hl)->r16h) ;
emiter: d<-(hl)  ( value ) reg:de ((hl)->r16h) ;
emiter: h<-(hl)  ( value ) reg:hl ((hl)->r16h) ;

emiter: r16h<-(ix+#)  ( reg disp )  pfx-IX gen-c, swap ((hl)->r16h) (disp,) ;
emiter: r16h<-(iy+#)  ( reg disp )  pfx-IY gen-c, swap ((hl)->r16h) (disp,) ;
emiter: b<-(ix+#)  ( disp )  pfx-IX gen-c, reg:bc ((hl)->r16h) (disp,) ;
emiter: d<-(ix+#)  ( disp )  pfx-IX gen-c, reg:de ((hl)->r16h) (disp,) ;
emiter: h<-(ix+#)  ( disp )  pfx-IX gen-c, reg:hl ((hl)->r16h) (disp,) ;
emiter: b<-(iy+#)  ( disp )  pfx-IY gen-c, reg:bc ((hl)->r16h) (disp,) ;
emiter: d<-(iy+#)  ( disp )  pfx-IY gen-c, reg:de ((hl)->r16h) (disp,) ;
emiter: h<-(iy+#)  ( disp )  pfx-IY gen-c, reg:hl ((hl)->r16h) (disp,) ;


|: (r16l->a)  ( reg-idx )
  ?r16-no-sp-af
  r16*2
  @171 + gen-c, ;

emiter: r16l->a  ( reg-idx )  (r16l->a) ;
emiter: c->a  ( value ) reg:bc (r16l->a) ;
emiter: e->a  ( value ) reg:de (r16l->a) ;
emiter: l->a  ( value ) reg:hl (r16l->a) ;

emiter: a<-r16l  ( reg-idx )  (r16l->a) ;
emiter: a<-c  ( value ) reg:bc (r16l->a) ;
emiter: a<-e  ( value ) reg:de (r16l->a) ;
emiter: a<-l  ( value ) reg:hl (r16l->a) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8-bit register-register loads

|: (r16h->a)  ( reg-idx )
  ?r16-no-sp-af
  r16*2
  @170 + gen-c, ;

emiter: r16h->a  ( reg-idx )  (r16h->a) ;
emiter: b->a  ( value ) reg:bc (r16h->a) ;
emiter: d->a  ( value ) reg:de (r16h->a) ;
emiter: h->a  ( value ) reg:hl (r16h->a) ;

emiter: a<-r16h  ( reg-idx )  (r16h->a) ;
emiter: a<-b  ( value ) reg:bc (r16h->a) ;
emiter: a<-d  ( value ) reg:de (r16h->a) ;
emiter: a<-h  ( value ) reg:hl (r16h->a) ;


|: (a->r16l)  ( reg-idx )
  ?r16-no-sp-af
  r16*2
  8 * @117 + gen-c, ;

emiter: a->r16l  ( reg-idx )  (a->r16l) ;
emiter: a->c  ( value ) reg:bc (a->r16l) ;
emiter: a->e  ( value ) reg:de (a->r16l) ;
emiter: a->l  ( value ) reg:hl (a->r16l) ;

emiter: r16l<-a  ( reg-idx )  (a->r16l) ;
emiter: c<-a  ( value ) reg:bc (a->r16l) ;
emiter: e<-a  ( value ) reg:de (a->r16l) ;
emiter: l<-a  ( value ) reg:hl (a->r16l) ;


|: (a->r16h)  ( reg-idx )
  ?r16-no-sp-af
  r16*2
  8 * @107 + gen-c, ;

emiter: a->r16h  ( reg-idx )  (a->r16h) ;
emiter: a->b  ( value ) reg:bc (a->r16h) ;
emiter: a->d  ( value ) reg:de (a->r16h) ;
emiter: a->h  ( value ) reg:hl (a->r16h) ;

emiter: r16h<-a  ( reg-idx )  (a->r16h) ;
emiter: b<-a  ( value ) reg:bc (a->r16h) ;
emiter: d<-a  ( value ) reg:de (a->r16h) ;
emiter: h<-a  ( value ) reg:hl (a->r16h) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; accumulator-memory loads and stores

|: (a->(r16))  ( reg-idx )
  ?r16-mem
  dup reg:HL = ?exit< drop @167 gen-c, >?
  r16*2 8 *
  @002 + gen-c, ;

emiter: a->(r16)  ( reg-idx )  (a->(r16)) ;
emiter: a->(bc)  ( value ) reg:bc (a->(r16)) ;
emiter: a->(de)  ( value ) reg:de (a->(r16)) ;
\ emiter: a->(hl)  ( value ) reg:hl (a->(r16)) ;

emiter: (r16)<-a  ( reg-idx )  (a->(r16)) ;
emiter: (bc)<-a  ( value ) reg:bc (a->(r16)) ;
emiter: (de)<-a  ( value ) reg:de (a->(r16)) ;


|: ((r16)->a)  ( reg-idx )
  ?r16-mem
  dup reg:HL = ?exit< drop @176 gen-c, >?
  r16*2 8 *
  @012 + gen-c, ;

emiter: (r16)->a  ( reg-idx )  ((r16)->a) ;
emiter: (bc)->a  ( value ) reg:bc ((r16)->a) ;
emiter: (de)->a  ( value ) reg:de ((r16)->a) ;
\ emiter: (hl)->a  ( value ) reg:hl ((r16)->a) ;

emiter: a<-(r16)  ( reg-idx )  ((r16)->a) ;
emiter: a<-(bc)  ( value ) reg:bc ((r16)->a) ;
emiter: a<-(de)  ( value ) reg:de ((r16)->a) ;

emiter: a->(nn)  ( addr )  @062 gen-c, gen-w, ;
emiter: (nn)->a  ( addr )  @072 gen-c, gen-w, ;

emiter: (nn)<-a  ( addr )  @062 gen-c, gen-w, ;
emiter: a<-(nn)  ( addr )  @072 gen-c, gen-w, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8-bit arithmetics

|: alu8-a-r8  ( reg-idx alu-opc )
  swap ?r8 + gen-c, ;

emiter: add-a-r16l  ( reg-idx )  ?r8-no-a @201 + gen-c, ;
emiter: add-a-r16h  ( reg-idx )  ?r8-no-a @200 + gen-c, ;
emiter: add-a-b  reg:b @200 alu8-a-r8 ;
emiter: add-a-c  reg:c @200 alu8-a-r8 ;
emiter: add-a-d  reg:d @200 alu8-a-r8 ;
emiter: add-a-e  reg:e @200 alu8-a-r8 ;
emiter: add-a-h  reg:h @200 alu8-a-r8 ;
emiter: add-a-l  reg:l @200 alu8-a-r8 ;

alias-for add-a-b is add-b
alias-for add-a-c is add-c
alias-for add-a-d is add-d
alias-for add-a-e is add-e
alias-for add-a-h is add-h
alias-for add-a-l is add-l

emiter: adc-a-r16l  ( reg-idx )  ?r8-no-a @211 + gen-c, ;
emiter: adc-a-r16h  ( reg-idx )  ?r8-no-a @210 + gen-c, ;
emiter: adc-a-b  reg:b @210 alu8-a-r8 ;
emiter: adc-a-c  reg:c @210 alu8-a-r8 ;
emiter: adc-a-d  reg:d @210 alu8-a-r8 ;
emiter: adc-a-e  reg:e @210 alu8-a-r8 ;
emiter: adc-a-h  reg:h @210 alu8-a-r8 ;
emiter: adc-a-l  reg:l @210 alu8-a-r8 ;

alias-for adc-a-b is adc-b
alias-for adc-a-c is adc-c
alias-for adc-a-d is adc-d
alias-for adc-a-e is adc-e
alias-for adc-a-h is adc-h
alias-for adc-a-l is adc-l

emiter: sub-a-r16l  ( reg-idx )  ?r8-no-a @221 + gen-c, ;
emiter: sub-a-r16h  ( reg-idx )  ?r8-no-a @220 + gen-c, ;
emiter: sub-a-b  reg:b @220 alu8-a-r8 ;
emiter: sub-a-c  reg:c @220 alu8-a-r8 ;
emiter: sub-a-d  reg:d @220 alu8-a-r8 ;
emiter: sub-a-e  reg:e @220 alu8-a-r8 ;
emiter: sub-a-h  reg:h @220 alu8-a-r8 ;
emiter: sub-a-l  reg:l @220 alu8-a-r8 ;

alias-for sub-a-b is sub-b
alias-for sub-a-c is sub-c
alias-for sub-a-d is sub-d
alias-for sub-a-e is sub-e
alias-for sub-a-h is sub-h
alias-for sub-a-l is sub-l

emiter: sbc-a-r16l  ( reg-idx )  ?r8-no-a @231 + gen-c, ;
emiter: sbc-a-r16h  ( reg-idx )  ?r8-no-a @230 + gen-c, ;
emiter: sbc-a-b  reg:b @230 alu8-a-r8 ;
emiter: sbc-a-c  reg:c @230 alu8-a-r8 ;
emiter: sbc-a-d  reg:d @230 alu8-a-r8 ;
emiter: sbc-a-e  reg:e @230 alu8-a-r8 ;
emiter: sbc-a-h  reg:h @230 alu8-a-r8 ;
emiter: sbc-a-l  reg:l @230 alu8-a-r8 ;

alias-for sbc-a-b is sbc-b
alias-for sbc-a-c is sbc-c
alias-for sbc-a-d is sbc-d
alias-for sbc-a-e is sbc-e
alias-for sbc-a-h is sbc-h
alias-for sbc-a-l is sbc-l

emiter: and-a-r16l  ( reg-idx )  ?r8-no-a @241 + gen-c, ;
emiter: and-a-r16h  ( reg-idx )  ?r8-no-a @240 + gen-c, ;
emiter: and-a-b  reg:b @240 alu8-a-r8 ;
emiter: and-a-c  reg:c @240 alu8-a-r8 ;
emiter: and-a-d  reg:d @240 alu8-a-r8 ;
emiter: and-a-e  reg:e @240 alu8-a-r8 ;
emiter: and-a-h  reg:h @240 alu8-a-r8 ;
emiter: and-a-l  reg:l @240 alu8-a-r8 ;

alias-for and-a-b is and-b
alias-for and-a-c is and-c
alias-for and-a-d is and-d
alias-for and-a-e is and-e
alias-for and-a-h is and-h
alias-for and-a-l is and-l

emiter: xor-a-r16l  ( reg-idx )  ?r8-no-a @251 + gen-c, ;
emiter: xor-a-r16h  ( reg-idx )  ?r8-no-a @250 + gen-c, ;
emiter: xor-a-b  reg:b @250 alu8-a-r8 ;
emiter: xor-a-c  reg:c @250 alu8-a-r8 ;
emiter: xor-a-d  reg:d @250 alu8-a-r8 ;
emiter: xor-a-e  reg:e @250 alu8-a-r8 ;
emiter: xor-a-h  reg:h @250 alu8-a-r8 ;
emiter: xor-a-l  reg:l @250 alu8-a-r8 ;

alias-for xor-a-b is xor-b
alias-for xor-a-c is xor-c
alias-for xor-a-d is xor-d
alias-for xor-a-e is xor-e
alias-for xor-a-h is xor-h
alias-for xor-a-l is xor-l

emiter: or-a-r16l   ( reg-idx )  ?r8-no-a @261 + gen-c, ;
emiter: or-a-r16h   ( reg-idx )  ?r8-no-a @260 + gen-c, ;
emiter: or-a-b  reg:b @260 alu8-a-r8 ;
emiter: or-a-c  reg:c @260 alu8-a-r8 ;
emiter: or-a-d  reg:d @260 alu8-a-r8 ;
emiter: or-a-e  reg:e @260 alu8-a-r8 ;
emiter: or-a-h  reg:h @260 alu8-a-r8 ;
emiter: or-a-l  reg:l @260 alu8-a-r8 ;

alias-for or-a-b is or-b
alias-for or-a-c is or-c
alias-for or-a-d is or-d
alias-for or-a-e is or-e
alias-for or-a-h is or-h
alias-for or-a-l is or-l

emiter: cp-a-r16l   ( reg-idx )  ?r8-no-a @271 + gen-c, ;
emiter: cp-a-r16h   ( reg-idx )  ?r8-no-a @270 + gen-c, ;
emiter: cp-a-b  reg:b @270 alu8-a-r8 ;
emiter: cp-a-c  reg:c @270 alu8-a-r8 ;
emiter: cp-a-d  reg:d @270 alu8-a-r8 ;
emiter: cp-a-e  reg:e @270 alu8-a-r8 ;
emiter: cp-a-h  reg:h @270 alu8-a-r8 ;
emiter: cp-a-l  reg:l @270 alu8-a-r8 ;

alias-for cp-a-b is cp-b
alias-for cp-a-c is cp-c
alias-for cp-a-d is cp-d
alias-for cp-a-e is cp-e
alias-for cp-a-h is cp-h
alias-for cp-a-l is cp-l

emiter: add-a-a  @207 gen-c, ;
emiter: adc-a-a  @217 gen-c, ;
emiter: sub-a-a  @227 gen-c, ;
emiter: sbc-a-a  @237 gen-c, ;
emiter: and-a-a  @247 gen-c, ;
emiter: xor-a-a  @257 gen-c, ;
emiter: or-a-a   @267 gen-c, ;
emiter: cp-a-a   @277 gen-c, ;

alias-for add-a-a is add-a
alias-for adc-a-a is adc-a
alias-for sub-a-a is sub-a
alias-for sbc-a-a is sbc-a
alias-for and-a-a is and-a
alias-for xor-a-a is xor-a
alias-for or-a-a is or-a
alias-for cp-a-a is cp-a

emiter: add-a-c#  ( n )  @306 gen-c, gen-c, ;
emiter: adc-a-c#  ( n )  @316 gen-c, gen-c, ;
emiter: sub-a-c#  ( n )  @326 gen-c, gen-c, ;
emiter: sbc-a-c#  ( n )  @336 gen-c, gen-c, ;
emiter: and-a-c#  ( n )  @346 gen-c, gen-c, ;
emiter: xor-a-c#  ( n )  @356 gen-c, gen-c, ;
emiter: or-a-c#   ( n )  @366 gen-c, gen-c, ;
emiter: cp-a-c#   ( n )  @376 gen-c, gen-c, ;

alias-for add-a-c# is add-c#
alias-for adc-a-c# is adc-c#
alias-for sub-a-c# is sub-c#
alias-for sbc-a-c# is sbc-c#
alias-for and-a-c# is and-c#
alias-for xor-a-c# is xor-c#
alias-for or-a-c# is or-c#
alias-for cp-a-c# is cp-c#

emiter: add-a-(hl)  @206 gen-c, ;
emiter: adc-a-(hl)  @216 gen-c, ;
emiter: sub-a-(hl)  @226 gen-c, ;
emiter: sbc-a-(hl)  @236 gen-c, ;
emiter: and-a-(hl)  @246 gen-c, ;
emiter: xor-a-(hl)  @256 gen-c, ;
emiter: or-a-(hl)   @266 gen-c, ;
emiter: cp-a-(hl)   @276 gen-c, ;

emiter: add-a-(ix+#)  pfx-IX gen-c, @206 gen-c, (disp,) ;
emiter: adc-a-(ix+#)  pfx-IX gen-c, @216 gen-c, (disp,) ;
emiter: sub-a-(ix+#)  pfx-IX gen-c, @226 gen-c, (disp,) ;
emiter: sbc-a-(ix+#)  pfx-IX gen-c, @236 gen-c, (disp,) ;
emiter: and-a-(ix+#)  pfx-IX gen-c, @246 gen-c, (disp,) ;
emiter: xor-a-(ix+#)  pfx-IX gen-c, @256 gen-c, (disp,) ;
emiter: or-a-(ix+#)   pfx-IX gen-c, @266 gen-c, (disp,) ;
emiter: cp-a-(ix+#)   pfx-IX gen-c, @276 gen-c, (disp,) ;

emiter: add-a-(iy+#)  pfx-IY gen-c, @206 gen-c, (disp,) ;
emiter: adc-a-(iy+#)  pfx-IY gen-c, @216 gen-c, (disp,) ;
emiter: sub-a-(iy+#)  pfx-IY gen-c, @226 gen-c, (disp,) ;
emiter: sbc-a-(iy+#)  pfx-IY gen-c, @236 gen-c, (disp,) ;
emiter: and-a-(iy+#)  pfx-IY gen-c, @246 gen-c, (disp,) ;
emiter: xor-a-(iy+#)  pfx-IY gen-c, @256 gen-c, (disp,) ;
emiter: or-a-(iy+#)   pfx-IY gen-c, @266 gen-c, (disp,) ;
emiter: cp-a-(iy+#)   pfx-IY gen-c, @276 gen-c, (disp,) ;

alias-for add-a-(hl) is add-(hl)
alias-for adc-a-(hl) is adc-(hl)
alias-for sub-a-(hl) is sub-(hl)
alias-for sbc-a-(hl) is sbc-(hl)
alias-for and-a-(hl) is and-(hl)
alias-for xor-a-(hl) is xor-(hl)
alias-for or-a-(hl) is or-(hl)
alias-for cp-a-(hl) is cp-(hl)

alias-for add-a-(ix+#) is add-(ix+#)
alias-for adc-a-(ix+#) is adc-(ix+#)
alias-for sub-a-(ix+#) is sub-(ix+#)
alias-for sbc-a-(ix+#) is sbc-(ix+#)
alias-for and-a-(ix+#) is and-(ix+#)
alias-for xor-a-(ix+#) is xor-(ix+#)
alias-for or-a-(ix+#) is or-(ix+#)
alias-for cp-a-(ix+#) is cp-(ix+#)

alias-for add-a-(iy+#) is add-(iy+#)
alias-for adc-a-(iy+#) is adc-(iy+#)
alias-for sub-a-(iy+#) is sub-(iy+#)
alias-for sbc-a-(iy+#) is sbc-(iy+#)
alias-for and-a-(iy+#) is and-(iy+#)
alias-for xor-a-(iy+#) is xor-(iy+#)
alias-for or-a-(iy+#) is or-(iy+#)
alias-for cp-a-(iy+#) is cp-(iy+#)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8-bit shifts

|: rxx-l/h,  ( reg-idx opc )
  $CB gen-c,
  swap
  ?r8 + gen-c, ;

emiter: rlc-r16l  ( reg-idx ) $CB gen-c, ?r8-no-a @001 + gen-c, ;
emiter: rlc-r16h  ( reg-idx ) $CB gen-c, ?r8-no-a @000 + gen-c, ;
emiter: rlc-b     reg:b    @000 rxx-l/h, ;
emiter: rlc-c     reg:c    @000 rxx-l/h, ;
emiter: rlc-d     reg:d    @000 rxx-l/h, ;
emiter: rlc-e     reg:e    @000 rxx-l/h, ;
emiter: rlc-h     reg:h    @000 rxx-l/h, ;
emiter: rlc-l     reg:l    @000 rxx-l/h, ;
emiter: rlc-(hl)  reg:(hl) @000 rxx-l/h, ;

emiter: rrc-r16l  ( reg-idx )  $CB gen-c, ?r8-no-a @011 + gen-c, ;
emiter: rrc-r16h  ( reg-idx )  $CB gen-c, ?r8-no-a @010 + gen-c, ;
emiter: rrc-b     reg:b    @010 rxx-l/h, ;
emiter: rrc-c     reg:c    @010 rxx-l/h, ;
emiter: rrc-d     reg:d    @010 rxx-l/h, ;
emiter: rrc-e     reg:e    @010 rxx-l/h, ;
emiter: rrc-h     reg:h    @010 rxx-l/h, ;
emiter: rrc-l     reg:l    @010 rxx-l/h, ;
emiter: rrc-(hl)  reg:(hl) @010 rxx-l/h, ;

emiter: rl-r16l   ( reg-idx )  $CB gen-c, ?r8-no-a @021 + gen-c, ;
emiter: rl-r16h   ( reg-idx )  $CB gen-c, ?r8-no-a @020 + gen-c, ;
emiter: rl-b     reg:b    @020 rxx-l/h, ;
emiter: rl-c     reg:c    @020 rxx-l/h, ;
emiter: rl-d     reg:d    @020 rxx-l/h, ;
emiter: rl-e     reg:e    @020 rxx-l/h, ;
emiter: rl-h     reg:h    @020 rxx-l/h, ;
emiter: rl-l     reg:l    @020 rxx-l/h, ;
emiter: rl-(hl)  reg:(hl) @020 rxx-l/h, ;

emiter: rr-r16l   ( reg-idx )  $CB gen-c, ?r8-no-a @031 + gen-c, ;
emiter: rr-r16h   ( reg-idx )  $CB gen-c, ?r8-no-a @030 + gen-c, ;
emiter: rr-b     reg:b    @030 rxx-l/h, ;
emiter: rr-c     reg:c    @030 rxx-l/h, ;
emiter: rr-d     reg:d    @030 rxx-l/h, ;
emiter: rr-e     reg:e    @030 rxx-l/h, ;
emiter: rr-h     reg:h    @030 rxx-l/h, ;
emiter: rr-l     reg:l    @030 rxx-l/h, ;
emiter: rr-(hl)  reg:(hl) @030 rxx-l/h, ;

emiter: sla-r16l  ( reg-idx )  $CB gen-c, ?r8-no-a @041 + gen-c, ;
emiter: sla-r16h  ( reg-idx )  $CB gen-c, ?r8-no-a @040 + gen-c, ;
emiter: sla-b     reg:b    @040 rxx-l/h, ;
emiter: sla-c     reg:c    @040 rxx-l/h, ;
emiter: sla-d     reg:d    @040 rxx-l/h, ;
emiter: sla-e     reg:e    @040 rxx-l/h, ;
emiter: sla-h     reg:h    @040 rxx-l/h, ;
emiter: sla-l     reg:l    @040 rxx-l/h, ;
emiter: sla-(hl)  reg:(hl) @040 rxx-l/h, ;
emiter: sla-a     reg:a    @040 rxx-l/h, ;

emiter: sra-r16l  ( reg-idx )  $CB gen-c, ?r8-no-a @051 + gen-c, ;
emiter: sra-r16h  ( reg-idx )  $CB gen-c, ?r8-no-a @050 + gen-c, ;
emiter: sra-b     reg:b    @050 rxx-l/h, ;
emiter: sra-c     reg:c    @050 rxx-l/h, ;
emiter: sra-d     reg:d    @050 rxx-l/h, ;
emiter: sra-e     reg:e    @050 rxx-l/h, ;
emiter: sra-h     reg:h    @050 rxx-l/h, ;
emiter: sra-l     reg:l    @050 rxx-l/h, ;
emiter: sra-(hl)  reg:(hl) @050 rxx-l/h, ;
emiter: sra-a     reg:a    @050 rxx-l/h, ;

emiter: sls-r16l  ( reg-idx )  $CB gen-c, ?r8-no-a @061 + gen-c, ;
emiter: sls-r16h  ( reg-idx )  $CB gen-c, ?r8-no-a @060 + gen-c, ;
emiter: sls-b     reg:b    @060 rxx-l/h, ;
emiter: sls-c     reg:c    @060 rxx-l/h, ;
emiter: sls-d     reg:d    @060 rxx-l/h, ;
emiter: sls-e     reg:e    @060 rxx-l/h, ;
emiter: sls-h     reg:h    @060 rxx-l/h, ;
emiter: sls-l     reg:l    @060 rxx-l/h, ;
emiter: sls-(hl)  reg:(hl) @060 rxx-l/h, ;
emiter: sls-a     reg:a    @060 rxx-l/h, ;

emiter: srl-r16l  ( reg-idx )  $CB gen-c, ?r8-no-a @071 + gen-c, ;
emiter: srl-r16h  ( reg-idx )  $CB gen-c, ?r8-no-a @070 + gen-c, ;
emiter: srl-b     reg:b    @070 rxx-l/h, ;
emiter: srl-c     reg:c    @070 rxx-l/h, ;
emiter: srl-d     reg:d    @070 rxx-l/h, ;
emiter: srl-e     reg:e    @070 rxx-l/h, ;
emiter: srl-h     reg:h    @070 rxx-l/h, ;
emiter: srl-l     reg:l    @070 rxx-l/h, ;
emiter: srl-(hl)  reg:(hl) @070 rxx-l/h, ;
emiter: srl-a     reg:a    @070 rxx-l/h, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bit operations

|: bit-n-l/h,  ( reg-idx bit# opc )
  over 7 u> ?error" invalid bit number"
  $CB gen-c,
  ( prepare bit#) swap 8 * +
  swap
  ?r8-no-a + gen-c, ;

|: bit-n-r8,  ( reg-idx bit# opc )
  over 7 u> ?error" invalid bit number"
  $CB gen-c,
  ( prepare bit#) swap 8 * +
  swap
  ?r8 + gen-c, ;

emiter: bit-r16l-n  ( reg-idx bit# )  @101 bit-n-l/h, ;
emiter: bit-r16h-n  ( reg-idx bit# )  @100 bit-n-l/h, ;
emiter: bit-b-n     ( bit# )  reg:b @100 bit-n-r8, ;
emiter: bit-c-n     ( bit# )  reg:c @100 bit-n-r8, ;
emiter: bit-d-n     ( bit# )  reg:d @100 bit-n-r8, ;
emiter: bit-e-n     ( bit# )  reg:e @100 bit-n-r8, ;
emiter: bit-h-n     ( bit# )  reg:h @100 bit-n-r8, ;
emiter: bit-l-n     ( bit# )  reg:l @100 bit-n-r8, ;
emiter: bit-(hl)-n  ( bit# )  reg:(hl) @100 bit-n-r8, ;
emiter: bit-a-n     ( bit# )  reg:a @100 bit-n-r8, ;

emiter: bit-n-b     ( bit# )  reg:b @100 bit-n-r8, ;
emiter: bit-n-c     ( bit# )  reg:c @100 bit-n-r8, ;
emiter: bit-n-d     ( bit# )  reg:d @100 bit-n-r8, ;
emiter: bit-n-e     ( bit# )  reg:e @100 bit-n-r8, ;
emiter: bit-n-h     ( bit# )  reg:h @100 bit-n-r8, ;
emiter: bit-n-l     ( bit# )  reg:l @100 bit-n-r8, ;
emiter: bit-n-(hl)  ( bit# )  reg:(hl) @100 bit-n-r8, ;
emiter: bit-n-a     ( bit# )  reg:a @100 bit-n-r8, ;

emiter: res-r16l-n  ( reg-idx bit# )  @201 bit-n-l/h, ;
emiter: res-r16h-n  ( reg-idx bit# )  @200 bit-n-l/h, ;
emiter: res-b-n     ( bit# )  reg:b @200 bit-n-r8, ;
emiter: res-c-n     ( bit# )  reg:c @200 bit-n-r8, ;
emiter: res-d-n     ( bit# )  reg:d @200 bit-n-r8, ;
emiter: res-e-n     ( bit# )  reg:e @200 bit-n-r8, ;
emiter: res-h-n     ( bit# )  reg:h @200 bit-n-r8, ;
emiter: res-l-n     ( bit# )  reg:l @200 bit-n-r8, ;
emiter: res-(hl)-n  ( bit# )  reg:(hl) @200 bit-n-r8, ;
emiter: res-a-n     ( bit# )  reg:a @200 bit-n-r8, ;

emiter: res-n-b     ( bit# )  reg:b @200 bit-n-r8, ;
emiter: res-n-c     ( bit# )  reg:c @200 bit-n-r8, ;
emiter: res-n-d     ( bit# )  reg:d @200 bit-n-r8, ;
emiter: res-n-e     ( bit# )  reg:e @200 bit-n-r8, ;
emiter: res-n-h     ( bit# )  reg:h @200 bit-n-r8, ;
emiter: res-n-l     ( bit# )  reg:l @200 bit-n-r8, ;
emiter: res-n-(hl)  ( bit# )  reg:(hl) @200 bit-n-r8, ;
emiter: res-n-a     ( bit# )  reg:a @200 bit-n-r8, ;

emiter: set-r16l-n  ( reg-idx bit# )  @301 bit-n-l/h, ;
emiter: set-r16h-n  ( reg-idx bit# )  @300 bit-n-l/h, ;
emiter: set-b-n     ( bit# )  reg:b @300 bit-n-r8, ;
emiter: set-c-n     ( bit# )  reg:c @300 bit-n-r8, ;
emiter: set-d-n     ( bit# )  reg:d @300 bit-n-r8, ;
emiter: set-e-n     ( bit# )  reg:e @300 bit-n-r8, ;
emiter: set-h-n     ( bit# )  reg:h @300 bit-n-r8, ;
emiter: set-l-n     ( bit# )  reg:l @300 bit-n-r8, ;
emiter: set-(hl)-n  ( bit# )  reg:(hl) @300 bit-n-r8, ;
emiter: set-a-n     ( bit# )  reg:a @300 bit-n-r8, ;

emiter: set-n-b     ( bit# )  reg:b @300 bit-n-r8, ;
emiter: set-n-c     ( bit# )  reg:c @300 bit-n-r8, ;
emiter: set-n-d     ( bit# )  reg:d @300 bit-n-r8, ;
emiter: set-n-e     ( bit# )  reg:e @300 bit-n-r8, ;
emiter: set-n-h     ( bit# )  reg:h @300 bit-n-r8, ;
emiter: set-n-l     ( bit# )  reg:l @300 bit-n-r8, ;
emiter: set-n-(hl)  ( bit# )  reg:(hl) @300 bit-n-r8, ;
emiter: set-n-a     ( bit# )  reg:a @300 bit-n-r8, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8-bit register->register moves

emiter: r16l->r16l  ( rsrc rdest )  (r16l->r16l) ;
emiter: r16h->r16h  ( rsrc rdest )  (r16h->r16h) ;
emiter: r16h->r16l  ( rsrc rdest )  (r16h->r16l) ;
emiter: r16l->r16h  ( rsrc rdest )  (r16l->r16h) ;

emiter: r16l<-r16l  ( rdest rsrc )  swap (r16l->r16l) ;
emiter: r16h<-r16h  ( rdest rsrc )  swap (r16h->r16h) ;
emiter: r16l<-r16h  ( rdest rsrc )  swap (r16h->r16l) ;
emiter: r16h<-r16l  ( rdest rsrc )  swap (r16l->r16h) ;

\ emiter: b->b  reg:bc reg:bc (r16h->r16h) ;
emiter: b->d  reg:bc reg:de (r16h->r16h) ;
emiter: b->h  reg:bc reg:hl (r16h->r16h) ;
emiter: b->c  reg:bc reg:bc (r16h->r16l) ;
emiter: b->e  reg:bc reg:de (r16h->r16l) ;
emiter: b->l  reg:bc reg:hl (r16h->r16l) ;

\ emiter: b<-b  reg:bc reg:bc (r16h->r16h) ;
emiter: d<-b  reg:bc reg:de (r16h->r16h) ;
emiter: h<-b  reg:bc reg:hl (r16h->r16h) ;
emiter: c<-b  reg:bc reg:bc (r16h->r16l) ;
emiter: e<-b  reg:bc reg:de (r16h->r16l) ;
emiter: l<-b  reg:bc reg:hl (r16h->r16l) ;

emiter: c->b  reg:bc reg:bc (r16l->r16h) ;
emiter: c->d  reg:bc reg:de (r16l->r16h) ;
emiter: c->h  reg:bc reg:hl (r16l->r16h) ;
\ emiter: c->c  reg:bc reg:bc (r16l->r16l) ;
emiter: c->e  reg:bc reg:de (r16l->r16l) ;
emiter: c->l  reg:bc reg:hl (r16l->r16l) ;

emiter: b<-c  reg:bc reg:bc (r16l->r16h) ;
emiter: d<-c  reg:bc reg:de (r16l->r16h) ;
emiter: h<-c  reg:bc reg:hl (r16l->r16h) ;
\ emiter: c<-c  reg:bc reg:bc (r16l->r16l) ;
emiter: e<-c  reg:bc reg:de (r16l->r16l) ;
emiter: l<-c  reg:bc reg:hl (r16l->r16l) ;

emiter: d->b  reg:de reg:bc (r16h->r16h) ;
\ emiter: d->d  reg:de reg:de (r16h->r16h) ;
emiter: d->h  reg:de reg:hl (r16h->r16h) ;
emiter: d->c  reg:de reg:bc (r16h->r16l) ;
emiter: d->e  reg:de reg:de (r16h->r16l) ;
emiter: d->l  reg:de reg:hl (r16h->r16l) ;

emiter: b<-d  reg:de reg:bc (r16h->r16h) ;
\ emiter: d<-d  reg:de reg:de (r16h->r16h) ;
emiter: h<-d  reg:de reg:hl (r16h->r16h) ;
emiter: c<-d  reg:de reg:bc (r16h->r16l) ;
emiter: e<-d  reg:de reg:de (r16h->r16l) ;
emiter: l<-d  reg:de reg:hl (r16h->r16l) ;

emiter: e->b  reg:de reg:bc (r16l->r16h) ;
emiter: e->d  reg:de reg:de (r16l->r16h) ;
emiter: e->h  reg:de reg:hl (r16l->r16h) ;
emiter: e->c  reg:de reg:bc (r16l->r16l) ;
\ emiter: e->e  reg:de reg:de (r16l->r16l) ;
emiter: e->l  reg:de reg:hl (r16l->r16l) ;

emiter: b<-e  reg:de reg:bc (r16l->r16h) ;
emiter: d<-e  reg:de reg:de (r16l->r16h) ;
emiter: h<-e  reg:de reg:hl (r16l->r16h) ;
emiter: c<-e  reg:de reg:bc (r16l->r16l) ;
\ emiter: e<-e  reg:de reg:de (r16l->r16l) ;
emiter: l<-e  reg:de reg:hl (r16l->r16l) ;

emiter: h->b  reg:hl reg:bc (r16h->r16h) ;
emiter: h->d  reg:hl reg:de (r16h->r16h) ;
\ emiter: h->h  reg:hl reg:hl (r16h->r16h) ;
emiter: h->c  reg:hl reg:bc (r16h->r16l) ;
emiter: h->e  reg:hl reg:de (r16h->r16l) ;
emiter: h->l  reg:hl reg:hl (r16h->r16l) ;

emiter: b<-h  reg:hl reg:bc (r16h->r16h) ;
emiter: d<-h  reg:hl reg:de (r16h->r16h) ;
\ emiter: h<-h  reg:hl reg:hl (r16h->r16h) ;
emiter: c<-h  reg:hl reg:bc (r16h->r16l) ;
emiter: e<-h  reg:hl reg:de (r16h->r16l) ;
emiter: l<-h  reg:hl reg:hl (r16h->r16l) ;

emiter: l->b  reg:hl reg:bc (r16l->r16h) ;
emiter: l->d  reg:hl reg:de (r16l->r16h) ;
emiter: l->h  reg:hl reg:hl (r16l->r16h) ;
emiter: l->c  reg:hl reg:bc (r16l->r16l) ;
emiter: l->e  reg:hl reg:de (r16l->r16l) ;
\ emiter: l->l  reg:hl reg:hl (r16l->r16l) ;

emiter: b<-l  reg:hl reg:bc (r16l->r16h) ;
emiter: d<-l  reg:hl reg:de (r16l->r16h) ;
emiter: h<-l  reg:hl reg:hl (r16l->r16h) ;
emiter: c<-l  reg:hl reg:bc (r16l->r16l) ;
emiter: e<-l  reg:hl reg:de (r16l->r16l) ;
\ emiter: l<-l  reg:hl reg:hl (r16l->r16l) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16-bit register->register moves

emiter: r16->r16  ( rsrc rdest )  (r16->r16) ;
emiter: r16<-r16  ( rdest rsrc )  swap (r16->r16) ;

emiter: bc->de  reg:bc reg:de (r16->r16) ;
emiter: bc->hl  reg:bc reg:hl (r16->r16) ;

emiter: de<-bc  reg:bc reg:de (r16->r16) ;
emiter: hl<-bc  reg:bc reg:hl (r16->r16) ;

emiter: de->bc  reg:de reg:bc (r16->r16) ;
emiter: de->hl  reg:de reg:hl (r16->r16) ;

emiter: bc<-de  reg:de reg:bc (r16->r16) ;
emiter: hl<-de  reg:de reg:hl (r16->r16) ;

emiter: hl->bc  reg:hl reg:bc (r16->r16) ;
emiter: hl->de  reg:hl reg:de (r16->r16) ;

emiter: bc<-hl  reg:hl reg:bc (r16->r16) ;
emiter: de<-hl  reg:hl reg:de (r16->r16) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16-bit increments and decrements

|: (inc/dec-r16)  ( reg-ids opc-base )
  swap ?r16-sp r16->opc + gen-c, ;

|: (inc-r16)  ( reg-idx )  @003 (inc/dec-r16) ;
|: (dec-r16)  ( reg-idx )  @013 (inc/dec-r16) ;

emiter: inc-r16  ( reg-idx )  (inc-r16) ;
emiter: inc-bc  reg:bc (inc-r16) ;
emiter: inc-de  reg:de (inc-r16) ;
emiter: inc-hl  reg:hl (inc-r16) ;

emiter: dec-r16  ( reg-idx )  (dec-r16) ;
emiter: dec-bc  reg:bc (dec-r16) ;
emiter: dec-de  reg:de (dec-r16) ;
emiter: dec-hl  reg:hl (dec-r16) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8-bit increments and decrements

|: (inc/dec-r16-as-8)  ( r16 opc-base high? )
  rot ?r8-no-a  ;; high 8-bit register
  swap not?< 1+ >? ;; to low, if necessary
  r8->opc + gen-c, ;

|: (inc-r16l)  ( reg-idx )  @004 false (inc/dec-r16-as-8) ;
|: (inc-r16h)  ( reg-idx )  @004 true (inc/dec-r16-as-8) ;
|: (dec-r16l)  ( reg-idx )  @005 false (inc/dec-r16-as-8) ;
|: (dec-r16h)  ( reg-idx )  @005 true (inc/dec-r16-as-8) ;

emiter: inc-r16l  ( reg-idx )  (inc-r16l) ;
emiter: inc-c  reg:bc (inc-r16l) ;
emiter: inc-e  reg:de (inc-r16l) ;
emiter: inc-l  reg:hl (inc-r16l) ;

emiter: inc-r16h  ( reg-idx )  (inc-r16h) ;
emiter: inc-b  reg:bc (inc-r16h) ;
emiter: inc-d  reg:de (inc-r16h) ;
emiter: inc-h  reg:hl (inc-r16h) ;

emiter: dec-r16l  ( reg-idx )  (dec-r16l) ;
emiter: dec-c  reg:bc (dec-r16l) ;
emiter: dec-e  reg:de (dec-r16l) ;
emiter: dec-l  reg:hl (dec-r16l) ;

emiter: dec-r16h  ( reg-idx )  (dec-r16h) ;
emiter: dec-b  reg:bc (dec-r16h) ;
emiter: dec-d  reg:de (dec-r16h) ;
emiter: dec-h  reg:hl (dec-r16h) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8 and 16 bits increments and decrements for index registers

emiter: inc-ix  pfx-IX gen-c, @043 gen-c, ;
emiter: inc-iy  pfx-IY gen-c, @043 gen-c, ;
emiter: inc-xl  pfx-IX gen-c, @054 gen-c, ;
emiter: inc-yl  pfx-IY gen-c, @054 gen-c, ;
emiter: inc-xh  pfx-IX gen-c, @044 gen-c, ;
emiter: inc-yh  pfx-IY gen-c, @044 gen-c, ;

emiter: dec-ix  pfx-IX gen-c, @053 gen-c, ;
emiter: dec-iy  pfx-IY gen-c, @053 gen-c, ;
emiter: dec-xl  pfx-IX gen-c, @055 gen-c, ;
emiter: dec-yl  pfx-IY gen-c, @055 gen-c, ;
emiter: dec-xh  pfx-IX gen-c, @045 gen-c, ;
emiter: dec-yh  pfx-IY gen-c, @045 gen-c, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16-bit arithmetics

|: (add-hl-r16)  ( reg-idx )
  ?r16-sp
  r16->opc @011 + gen-c, ;

emiter: add-hl-r16  ( reg-idx )  (add-hl-r16) ;
emiter: add-hl-bc  reg:bc (add-hl-r16) ;
emiter: add-hl-de  reg:de (add-hl-r16) ;
emiter: add-hl-hl  reg:hl (add-hl-r16) ;
emiter: add-hl-sp  reg:sp (add-hl-r16) ;

emiter: add-ix-bc  pfx-IX gen-c, reg:bc (add-hl-r16) ;
emiter: add-ix-de  pfx-IX gen-c, reg:de (add-hl-r16) ;
emiter: add-ix-ix  pfx-IX gen-c, reg:hl (add-hl-r16) ;
emiter: add-ix-sp  pfx-IX gen-c, reg:sp (add-hl-r16) ;

emiter: add-iy-bc  pfx-IY gen-c, reg:bc (add-hl-r16) ;
emiter: add-iy-de  pfx-IY gen-c, reg:de (add-hl-r16) ;
emiter: add-iy-iy  pfx-IY gen-c, reg:hl (add-hl-r16) ;
emiter: add-iy-sp  pfx-IY gen-c, reg:sp (add-hl-r16) ;


|: (adc-hl-r16)  ( reg-idx )
  ?r16-sp
  r16->opc
  $ED gen-c, @112 + gen-c, ;

emiter: adc-hl-r16  ( reg-idx )  (adc-hl-r16) ;
emiter: adc-hl-bc  reg:bc (adc-hl-r16) ;
emiter: adc-hl-de  reg:de (adc-hl-r16) ;
emiter: adc-hl-hl  reg:hl (adc-hl-r16) ;
emiter: adc-hl-sp  reg:sp (adc-hl-r16) ;


|: (sbc-hl-r16)  ( reg-idx )
  ?r16-sp
  r16->opc
  $ED gen-c, @102 + gen-c, ;

emiter: sbc-hl-r16  ( reg-idx )  (sbc-hl-r16) ;
emiter: sbc-hl-bc  reg:bc (sbc-hl-r16) ;
emiter: sbc-hl-de  reg:de (sbc-hl-r16) ;
emiter: sbc-hl-hl  reg:hl (sbc-hl-r16) ;
emiter: sbc-hl-sp  reg:sp (sbc-hl-r16) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 16-bit memory loads and stores

|: ((nn)->r16)  ( addr reg-idx )
  ?r16-sp
  dup reg:HL = ?exit< drop @052 gen-c, gen-w, >?
  r16->opc
  $ED gen-c, @113 + gen-c, gen-w, ;

emiter: (nn)->r16  ( addr reg-idx )  ((nn)->r16) ;
emiter: (nn)->bc  ( addr )  reg:bc ((nn)->r16) ;
emiter: (nn)->de  ( addr )  reg:de ((nn)->r16) ;
emiter: (nn)->hl  ( addr )  reg:hl ((nn)->r16) ;

emiter: r16<-(nn)  ( reg-idx addr )  swap ((nn)->r16) ;
emiter: bc<-(nn)  ( addr )  reg:bc ((nn)->r16) ;
emiter: de<-(nn)  ( addr )  reg:de ((nn)->r16) ;
emiter: hl<-(nn)  ( addr )  reg:hl ((nn)->r16) ;


|: (r16->(nn))  ( addr reg-idx )
  ?r16-sp
  dup reg:HL = ?exit< drop @042 gen-c, gen-w, >?
  r16->opc
  $ED gen-c, @103 + gen-c, gen-w, ;

emiter: r16->(nn)  ( addr reg-idx )  (r16->(nn)) ;
emiter: bc->(nn)  ( addr )  reg:bc (r16->(nn)) ;
emiter: de->(nn)  ( addr )  reg:de (r16->(nn)) ;
emiter: hl->(nn)  ( addr )  reg:hl (r16->(nn)) ;

emiter: (nn)<-r16  ( reg-idx addr )  swap (r16->(nn)) ;
emiter: (nn)<-bc  ( addr )  reg:bc (r16->(nn)) ;
emiter: (nn)<-de  ( addr )  reg:de (r16->(nn)) ;
emiter: (nn)<-hl  ( addr )  reg:hl (r16->(nn)) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZXEmuT macros

emiter: zxemut-bp
  $ED gen-c, $FE gen-c, $18 gen-c,
  1 gen-c, 2 gen-c, ;

emiter: zxemut-pause
  $ED gen-c, $FE gen-c, $18 gen-c,
  2 gen-c, $10 gen-c, 0 gen-c, ;

emiter: zxemut-max-speed
  $ED gen-c, $FE gen-c, $18 gen-c,
  2 gen-c, $10 gen-c, 1 gen-c, ;

emiter: zxemut-normal-speed
  $ED gen-c, $FE gen-c, $18 gen-c,
  2 gen-c, $10 gen-c, 2 gen-c, ;

emiter: zxemut-reset-ts-counter
  $ED gen-c, $FE gen-c, $18 gen-c,
  1 gen-c, $00 gen-c, ;

emiter: zxemut-pause-ts-counter
  $ED gen-c, $FE gen-c, $18 gen-c,
  2 gen-c, $00 gen-c, 1 gen-c, ;

emiter: zxemut-resume-ts-counter
  $ED gen-c, $FE gen-c, $18 gen-c,
  2 gen-c, $00 gen-c, 2 gen-c, ;

emiter: zxemut-print-ts-counter
  $ED gen-c, $FE gen-c, $18 gen-c,
  1 gen-c, $01 gen-c, ;

emiter: zxemut-get-ts-counter-de-hl
  $ED gen-c, $FE gen-c, $18 gen-c,
  2 gen-c, $01 gen-c, 1 gen-c, ;

emiter: zxemut-trap-2b  ( trap subcode )
  $ED gen-c, $FE gen-c, $18 gen-c,
  2 gen-c, swap gen-c, gen-c, ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; higher-level code support

false quan (TOS-in-DE?) (private)

@: TOS-in-HL!  (TOS-in-DE?):!f ;
@: TOS-in-DE!  (TOS-in-DE?):!t ;

@: TOS-in-DE?  (TOS-in-DE?) ;
@: TOS-in-HL?  (TOS-in-DE?) 0= ;

@: TOS-invert! (TOS-in-DE?) 0= (TOS-in-DE?):! ;


;; 5D 54        ld    de, hl
;; to be generated
;; EB           ex    de, hl
;; remove previous ex, generate nothing
|: (peep-restore-tos-hl)  ( -- done-flag )
  OPT-OPTIMIZE-PEEPHOLE? not?exit&leave
  at-word-begin? not?exit&leave
  0 ilist-nth-len 2 = not?exit&leave
  $here 2- word@ dup $545D = swap $5D54 = or not?exit&leave
  remove-last-instruction
  stat-restore-tos-exx:1+!
  true ;

;; 6B 62        ld    hl, de
;; to be generated
;; EB           ex    de, hl
;; remove previous ex, generate nothing
|: (peep-restore-tos-de)  ( -- done-flag )
  OPT-OPTIMIZE-PEEPHOLE? not?exit&leave
  at-word-begin? not?exit&leave
  0 ilist-nth-len 2 = not?exit&leave
  $here 2- word@ dup $626B = swap $6B62 = or not?exit&leave
  remove-last-instruction
  stat-restore-tos-exx:1+!
  true ;

;; move TOS to HL (via "ex de, hl")
;; this is the default TOS state.
@: restore-tos-hl
  (TOS-in-DE?) not?exit
  (peep-restore-tos-hl) not?<
    ex-de-hl
  >?
  (TOS-in-DE?):!f ;

;; move TOS to DE (via "ex de, hl")
@: restore-tos-de
  (TOS-in-DE?) ?exit
  (peep-restore-tos-de) not?<
    ex-de-hl
  >?
  (TOS-in-DE?):!t ;

;; restore only if could be optimised away
@: restore-tos-hl-if-opt
  (TOS-in-DE?) not?exit
  (peep-restore-tos-hl) ?<
    (TOS-in-DE?):!f
  >? ;

;; restore only if could be optimised away
;; move TOS to DE (via "ex de, hl")
@: restore-tos-de-if-opt
  (TOS-in-DE?) ?exit
  (peep-restore-tos-de) ?<
    (TOS-in-DE?):!t
  >? ;

;; current TOS register (HL or DE)
@: tos-r16
  (TOS-in-DE?) ?< reg:de || reg:hl >? ;

;; current non-TOS register (HL or DE)
@: non-tos-r16
  (TOS-in-DE?) ?< reg:hl || reg:de >? ;


@: push-tos       tos-r16 push-r16 ;
@: pop-tos        tos-r16 pop-r16 ;
@: push-non-tos   non-tos-r16 push-r16 ;
@: pop-non-tos    non-tos-r16 pop-r16 ;

@: pop-tos-peephole       tos-r16 pop-r16-peephole ;
@: pop-non-tos-peephole   non-tos-r16 pop-r16-peephole ;

;; some handy shortcuts
@: inc-tos  tos-r16 inc-r16 ;
@: dec-tos  tos-r16 dec-r16 ;

@: inc-non-tos  non-tos-r16 inc-r16 ;
@: dec-non-tos  non-tos-r16 dec-r16 ;

@: #->tos  ( value )  tos-r16 #->r16 ;
@: c#->tosl  ( value )  tos-r16 c#->r16l ;
@: c#->tosh  ( value )  tos-r16 c#->r16h ;
@: (nn)->tos  ( addr )  tos-r16 (nn)->r16 ;
@: tos->(nn)  ( addr )  tos-r16 r16->(nn) ;
@: a->(tos)  tos-r16 a->(r16) ;
@: (tos)->a  tos-r16 (r16)->a ;
@: a->tos  tos-r16 a->r16l  0 tos-r16 c#->r16h ;

@: tos<-(nn)  ( addr )  tos-r16 (nn)->r16 ;
@: (nn)<-tos  ( addr )  tos-r16 r16->(nn) ;
@: (tos)<-a  tos-r16 a->(r16) ;
@: a<-(tos)  tos-r16 (r16)->a ;
@: tos<-a  tos-r16 a->r16l  0 tos-r16 c#->r16h ;

@: #->non-tos  ( value )  non-tos-r16 #->r16 ;
@: (nn)->non-tos  ( addr )  non-tos-r16 (nn)->r16 ;
@: non-tos->(nn)  ( addr )  non-tos-r16 r16->(nn) ;
@: a->(non-tos)  non-tos-r16 a->(r16) ;
@: (non-tos)->a  non-tos-r16 (r16)->a ;

@: a->non-tos  non-tos-r16 a->r16l  0 non-tos-r16 c#->r16h ;

@: a->bc  a->c 0 c#->b ;
@: a->de  a->e 0 c#->d ;
@: a->hl  a->l 0 c#->h ;

;; may destroy flags
@: c#->a-destructive  ( n )
  lo-byte dup ?< c#->a || drop xor-a-a >? ;

;; setup IY for ROM.
;; note that IY is used for return stack by the system,
;; so you'd better push it and pop after calling the ROM.
@: restore-iy  $5C3A #->iy ;


;; use as the last instruction, to set tos to HL and pop HL
@: pop-tos-hl
  (TOS-in-DE?):!f
  pop-hl ;

;; use as the last instruction, to set tos to DE and pop DE
@: pop-tos-de
  (TOS-in-DE?):!t
  pop-de ;


;; peephole optimiser utilities
@: last-1b-opcode?  ( opcode -- bool )
  push-pop-peephole? not?exit< drop false >?
  at-word-begin? not?exit< drop false >?
  ilist# 0?exit< drop false >?
  0 ilist-nth-len 1 = not?exit< drop false >?
  0 ilist-nth-addr byte@ = ;

@: last-pop-non-tos?  ( bool )
  TOS-in-HL? ?< @321 || @341 >? last-1b-opcode? ;

@: last-pop-tos?  ( bool )
  TOS-in-DE? ?< @321 || @341 >? last-1b-opcode? ;

@: last-push-non-tos?  ( bool )
  TOS-in-HL? ?< @325 || @345 >? last-1b-opcode? ;

@: last-push-tos?  ( bool )
  TOS-in-DE? ?< @325 || @345 >? last-1b-opcode? ;


;; used in LIT-alikes, for "DROP LIT" and such
;;  pop  tos
;;  push tos
;;  ld   tos, # nnn
;; here we can remove pop/push
;; WARNING! use this only when you will destroy TOS!
@: push-tos-peephole
  last-pop-tos? not?exit< push-tos >?
  [ 0 ] [IF]
    endcr ." curr=$" $here .hex4 ."  addr=$" 0 ilist-nth-addr .hex4
    ."  ilen=" 0 ilist-nth-len . ." byte=$" 0 ilist-nth-addr byte@ .hex2
    ."  ilist#=" ilist# 0.r
    cr
  [ENDIF]
  remove-last-instruction
  [ OPT-DEBUG-PEEPHOLE? ] [IF]
    $00 gen-c, @177 gen-c, ;; ld a,a
  [ENDIF]
    \ push-tos nop
  stat-pop-push-removed:1+! ;

;; HL and DE are DESTROYED!
;; used when we will destroy TOS, and don't care about DE and HL values.
@: push-tos-peephole-restore-tos-hl
  push-tos-peephole
  TOS-in-HL! ;


|: (optim-last-tos-ex-ex)  ( -- success-flag )
  ilist# 1 > not?exit&leave
  \ 0 ilist-nth-len 1 = not?exit&leave -- already checked
  1 ilist-nth-len 1 = not?exit&leave
  1 ilist-nth-addr byte@ @353 = not?exit&leave
  ;; two "ex", remove both
  remove-last-instruction remove-last-instruction
  true ;

;; ld de, hl -> ex de, hl
;; ld hl, de -> ex de, hl
;; ex de, hl / ex de, hl -> none
@: optim-last-tos-load
  push-pop-peephole? not?exit
  ilist# 0?exit
  0 ilist-nth-len 1 = ?exit<
    $here 1- word-begin = not?exit ;;< endcr ." NOT BEGIN(1): $" $here .hex4 cr >?
    $here 1- byte@ @353 = not?exit
    (optim-last-tos-ex-ex) ?exit
    TOS-invert!
  >?
  0 ilist-nth-len 2 = not?exit
  $here 2- word-begin = not?exit ;;< endcr ." NOT BEGIN(2): $" $here .hex4 cr >?
  $here 2- word@
  dup $5D54 = swap @153 256 * @142 + = or ?exit<
    ;; ld de, hl or ld hl, de
    remove-last-instruction
    TOS-invert!
  >? ;


;; we need to have current TOS in DE, and next value in HL; TOS should be HL.
;; the instruction order is suitable for peephole optimising.
@: nd-branch-pop
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl
  ||
    pop-hl-peephole
    TOS-in-HL!
  >? ;

;; move TOS to HL, then pop DE.
;; the instruction order is suitable for peephole optimising.
@: restore-tos-hl-pop-de
  TOS-in-HL? ?<
    pop-de-peephole
  ||
    pop-hl-peephole
    ex-de-hl
    TOS-in-HL!
  >? ;

;; move TOS to DE, then pop HL.
;; the instruction order is suitable for peephole optimising.
@: restore-tos-de-pop-hl
  TOS-in-HL? ?<
    pop-de-peephole
    ex-de-hl
    TOS-in-DE!
  ||
    pop-hl-peephole
  >? ;


;; reinitialise xasm from scratch.
;; used mostly when generating the code for the new IR word.
@: reset
  TOS-in-HL! reset-ilist ;


;; this will not register the word!
*: @label:  ( -- value )  \ name
  parse-name z80-labman:@get
  [\\] {#,} ; (published)

*: @asm-label:
  error" use \'@label:\' instead!" ; (published)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; more peephole utilities

(*
59 50        ld    de, bc
69 60        ld    hl, bc
4B 42        ld    bc, de
6B 62        ld    hl, de
4D 44        ld    bc, hl
5D 54        ld    de, hl
*)

@: last-ld-r16-r16?  ( -- r16src r16dest TRUE // FALSE )
  ilist# 0?exit&leave
  \ at-word-begin? not?exit&leave
  0 ilist-nth-len 2 = not?exit&leave
  0 ilist-nth-addr word@
  << $5059 of?v| reg:bc reg:de true |?
     $6069 of?v| reg:bc reg:hl true |?
     $424B of?v| reg:de reg:bc true |?
     $626B of?v| reg:de reg:hl true |?
     $444D of?v| reg:hl reg:bc true |?
     $545D of?v| reg:hl reg:de true |?
  else| drop false >> ;


seal-module
end-module XASM  (published)
end-module TCOM
