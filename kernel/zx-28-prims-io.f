;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; input/output primitives
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


<zx-definitions>
\ zxlib-begin" low-level i/o prims"

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; emit driver variables, used by installable drivers

0 quan OBL? -- last printed char was BL?
0 quan SC#  -- incremented on scroll
0 quan OUT# -- incremented with each output char
;; show cursor while waiting a key?
;; bit 0: show cursor?
;; bit 7: simple inverted block, no C/L char.
;; bit 4 is used to tell if the cursor was printed.
;; it is set by ".CUR", and reset by ".CUR0".
1 variable KCUR
;; allow CS+9 "GRAPH" switch? has sense only for 32-columns mode.
0 quan ALLOW-G?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; open ROM channel for ROM emit

code: OPEN-CHAN-# ( chan )
  push  iy
  restore-iy
  ;; we need to have at least one line in the bottom area
  ld    a, # 1
  ld    sysvar-defsz (), a
  ld    a, l
  call  # $1601
  ;; print whole 24 lines
  xor   a
  ld    sysvar-defsz (), a
  ;; no scroll prompt
  dec   a
  ld    sysvar-scr-ct (), a
  pop   iy
;code-pop-tos

: OPEN-CHAN-#2  2 OPEN-CHAN-# ; zx-inline


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; raw ROM printing

code: (ROM-EMIT)  ( ch )
  push  iy
  restore-iy
  ld    a, l
  rst   # $10
  pop   iy
  pop   hl
;code
1 0 Succubus:setters:in-out-args
(*
:codegen-xasm
  tos-r16 r16l->a
  push-iy
  restore-iy
  $10 rst-n
  pop-iy
  pop-tos ;
*)

code: (ROM-EMIT-ATTR)  ( value code )
  pop   de
  push  iy
  restore-iy
  ld    a, l
  rst   # $10
  ld    a, e
  rst   # $10
  ;; make temporary attributes permanent
  ;; we have channel #2 (main screen) open, so just call ROM
  ;; this destroys HL and AF
  call  # $1CAD
  pop   iy
  pop   hl
;code
2 0 Succubus:setters:in-out-args

code: (ROM-TYPE)  ( addr count )
  ex    de, hl
  pop   hl
  push  iy
  restore-iy
.loop:
  ld    a, d
  or    a
  jp    m, # .done
  ld    a, e
  or    a
  jr    z, # .done
  ld    a, (hl)
  rst   # $10
  inc   hl
  dec   de
  jr    # .loop
.done:
  pop   iy
  pop   hl
;code
2 0 Succubus:setters:in-out-args


primitive: (FIX-ATTRS)  ( -- )
  (*
  ld    hl, () sysvar-attr-p
  ;; we need Z flag to be set
  xor   a
  call  # $0D5B
  *)
  ;; we have channel #2 (main screen) open, so just call ROM
\   call  # $0D4D
\ ;code
:codegen-xasm
  push-iy
  restore-iy
  ;; we have channel #2 (main screen) open, so just call ROM
  $0D4D call-#
  pop-iy ;

;; make temporary attributes permanent
\ code: (ATTRS-T-PERM)
\   ;; we have channel #2 (main screen) open, so just call ROM
\   call  # $1CAD
\ ;code


;; very simple "CLS" code
raw-code: (SIMPLE-CLS)
  push  hl
  ;; fix attrs
  ld    hl, () sysvar-attr-p
  ld    sysvar-attr-t (), hl
  ;; clear scr$
  ld    hl, # $4000
  ld    de, # $4001
  ld    bc, # 6144
  ld    (hl), l
  ldir
  ;; set attr$
  ld    bc, # 767
  ld    a, () sysvar-attr-p
  ld    (hl), a
  ldir
  pop   hl
;code
0 0 Succubus:setters:in-out-args


;; very simple "CLS" code
raw-code: (ROM-CLS)
  push  hl
  push  iy
  restore-iy
  ;; fix attrs
  ld    hl, () sysvar-attr-p
  ld    sysvar-attr-t (), hl
  ;; clear scr$
  ld    hl, # $4000
  ld    de, # $4001
  ld    bc, # 6144
  ld    (hl), l
  ldir
  ;; set attr$
  ld    bc, # 767
  ld    a, () sysvar-attr-p
  ld    (hl), a
  ldir
  ;; we need to have at least one line in the bottom area for ROM printing
  ld    a, # 1
  ld    sysvar-defsz (), a
  ;; open chan #2
  ld    a, # 2
  call  # $1601
  ;; print whole 24 lines
  xor   a
  ld    sysvar-defsz (), a
  ;; no scroll prompt
  dec   a
  ld    sysvar-scr-ct (), a
  ;; AT 0, 0
  ld    a, # 22
  rst   # $10
  xor   a
  rst   # $10
  xor   a
  rst   # $10
  pop   iy
  pop   hl
;code
0 0 Succubus:setters:in-out-args


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; keyboard input words

;; read key, no wait, no translation, no special processing.
;; zeroes LAST-K.
code: INKEY?  ( -- char )
  \ push  bc
  \ ld    a, # 2
  \ call  # $1601
  \ pop   bc
  \ ei    ;; just in case
  push  hl
  ;; bit 5 of (iy+1) is set when a new key is pressed
  ;; just in case
  ld    hl, # sysvar-last-k
  ld    a, (hl)
  ;; zero LAST-K
  ld    (hl), # 0
  ld    h, # 0
  ld    l, a
  cp    a, # 13
  jr    nz, # .not-cr
  ;; ENTER produces #13
  ;; SS+ENTER produces #2
  ;; check for SS pressed
  ld    a, # $7F
  in    a, () $FE
  and   # $02
  jr    nz, # .not-cr
  ld    l, # 2
.not-cr:
  ;; just in case
  (*
  OPT-32-COLS? [IF]
  ld    a, (iy+) 7
  and   # $02
  ld    7 (iy+), a
  [ELSE]
  ld    7 (iy+), # 00 ;; #5C41
  [ENDIF]
  *)
;code
0 1 Succubus:setters:in-out-args

;; translate pressed key
raw-code: TR-KEY  ( char -- char )
  ld    a, l
  ld    e, a
  or    a
  jr    z, # .done

  cp    # 128
  jr    nc, # .translate

  cp    # 32
  jr    nc, # .done

  ;; something's pressed
  cp    # 6           ;; CS+2?
  jr    nz, # .not-caps
  ;; toggle CAPS
  ld    hl, # sysvar-flags2
  ld    a, # $08      ;; CAPS flag
.do-graph:
  xor   (hl)
  ld    (hl), a
  ld    e, # 0
  jr    # .done

.not-caps:
  ;; CS+9 should switch to "G"
  cp    # 15
  jr    nz, # .not-graph
  ld    a, () zx-['pfa] ALLOW-G?
  or    a
  jr    z, # .not-graph
  ld    hl, # sysvar-tv-flag
  ld    a, # $02      ;; GRAPH flag
  jr    # .do-graph
.not-graph:
  \ ld    a, # 15

.done:
  ld    l, e
  ld    h, # 0
  ret

.translate:
  ;; translate codes
  ld    hl, # key-translation-table 1-
.table-loop:
  inc   hl
  ld    a, (hl)       ;; src
  or    a             ;; end?
  jr    z, # .done
  inc   hl
  cp    e
  ld    a, (hl)       ;; dest
  jr    nz, # .table-loop
  ld    e, a
  jr    # .done

flush!

key-translation-table:
  198 db,  91 db, ;; AND->[
  197 db,  93 db, ;; OR->]
  172 db, 127 db, ;; AT->(c)
  226 db, 126 db, ;; STOP->~
  195 db, 124 db, ;; NOT->|
  205 db,  92 db, ;; STEP->slash
  204 db, 123 db, ;; TO->{
  203 db, 125 db, ;; THEN->}
  ;; SS+Q, SS+W, SS+E
  199 db, 29 db,  ;; SS+Q
  201 db, 30 db,  ;; SS+W
  200 db, 31 db,  ;; SS+E
0 db,
;code-no-next
1 1 Succubus:setters:in-out-args
\ <zx-forth>

;; bit 0 set for CS, bit 1 set for SS
code: CS/SS?  ( -- shift-flags )
  push  hl
  ld    h, # 0
  ;; check for SS pressed
  ld    a, # $7F
  in    a, () $FE
  cpl
  and   # $02
  ld    l, a
  ;; check for CS pressed
  ld    a, # $FE
  in    a, () $FE
  cpl
  and   # $01
  or    l
  ld    l, a
;code
0 1 Succubus:setters:in-out-args

primitive: CS?  ( -- bool )
Succubus:setters:out-bool
:codegen-xasm
  push-tos-peephole
  ;; check for CS pressed
  $FE c#->a
  $FE in-a-(c#)
  cpl
  $01 and-a-c#
  a->tos ;

primitive: SS?  ( -- bool )
Succubus:setters:out-bool
:codegen-xasm
  push-tos-peephole
  ;; check for SS pressed
  $7F c#->a
  $FE in-a-(c#)
  cpl
  rra
  $01 and-a-c#
  a->tos ;

primitive: TERMINAL?  ( -- break? )
Succubus:setters:out-bool
:codegen-xasm
  push-tos-peephole
  0 #->tos
  $1F54 call-#  ;; this modifies only AF
  ccf
  tos-r16 rl-r16l ;


;; read input key without waiting, do not use ROM.
;; CS and SS has special codes:
;;   13: enter
;;   30: CS
;;   31: SS
code: INKEY-EX  ( -- ascii // 0 )
  push  hl
  call  # InKeyEx
  jr    c, # .inkey-ex-done
  xor   a
.inkey-ex-done:
  ld    h, # 0
  ld    l, a
  next
;; don't wait for keypress; return char or carry reset
;; OUT:
;;   A: key code or trash
;;   HL,DE,BC,F: dead
;;   CARRY: set if key was decoded
;; note:
;;   30: CS
;;   31: SS
InKeyEx:
  ld    hl, # .keytab 1-  ;; ascii values
  ld    de, # 5
  ld    c, # $7F          ;; 1st half row
.loop0:
  ld    a, c
  in    a, () $FE         ;; get half row
  cpl
  and   # $1F
  ld    b, a
  jr    z, # .nokey       ;; no keys pressed
  push  hl
.loop1:
  inc   hl                ;; find key within row
  rra
  jr    nc, # .loop1      ;; Wow - No key if carry
  ld    a, (hl)           ;; get azcii value from table
  pop   hl
  scf
  ret
.nokey:
  add   hl, de
  rrc   c                 ;; next row on keyboard (carry=1)
  jr    c, # .loop0
  ret                     ;; go back with NO CARRY if no key pressed

.keytab:
  32 db, 31 db, [char] M db, [char] N db, [char] B db,
  13 db, [char] L db, [char] K db, [char] J db, [char] H db,
  [char] P db, [char] O db, [char] I db, [char] U db, [char] Y db,
  [char] 0 db, [char] 9 db, [char] 8 db, [char] 7 db, [char] 6 db,
  [char] 1 db, [char] 2 db, [char] 3 db, [char] 4 db, [char] 5 db,
  [char] Q db, [char] W db, [char] E db, [char] R db, [char] T db,
  [char] A db, [char] S db, [char] D db, [char] F db, [char] G db,
  30 db, [char] Z db, [char] X db, [char] C db, [char] V db,
;code-no-next
0 1 Succubus:setters:in-out-args

;; wait for keypress; return char
primitive: GETKEY-EX  ( -- ascii )
Succubus:setters:out-8bit
:codegen-xasm
  $here
  @label: InKeyEx call-#
  cond:nc jr-#-cc
  a->tos ;
zx-required: INKEY-EX


raw-code: KEY-BEEP
  push  hl
  push  ix
  push  iy
  restore-iy
  ld    hl, # $C8   ;; pitch
  ld    a, () sysvar-pip
  ld    e, a
  ld    d, # 0
  call  # $03B5
  pop   iy
  pop   ix
  pop   hl
;code
0 0 Succubus:setters:in-out-args

raw-code: ERR-BEEP
  push  hl
  push  ix
  push  iy
  restore-iy
  ld    hl, # $1A90 ;; pitch
  ld    a, () sysvar-rasp
  ld    e, a
  ld    d, # 0
  call  # $03B5
  pop   iy
  pop   ix
  pop   hl
;code
0 0 Succubus:setters:in-out-args


code: BLEEP  ( duration pitch )
  pop   de
  push  ix
  push  iy
  restore-iy
  call  # $03B5
  pop   iy
  pop   ix
  pop   hl
;code
2 0 Succubus:setters:in-out-args


;; calculate values for BLEEP
: (BLC)  ( ms hz -- duration pitch )
  >R R@ 1000 */ ( 3500.000) $67E0 $35 R> UDU/MOD
  241 - 8u/ NIP ; zx-inline

: BEEP  ( ms hz )  (BLC) BLEEP ;


code: BORDER  ( color )
  push  iy
  restore-iy
  ld    a, l
  and   a, # 07
  call  # $229B
  pop   iy
  pop   hl
;code
1 0 Succubus:setters:in-out-args


code: INKEY  ( -- char//255 )
  push  hl
  push  iy
  restore-iy
  call  # $028E
  jr    nz, # .done
  call  # $031E
  jr    nc, # .done
  dec   d
  ld    e, a
  call  # $0333
.done:
  ld    l, a
  ld    h, # 0
  pop   iy
;code
0 1 Succubus:setters:in-out-args
Succubus:setters:out-8bit


primitive: OUTP  ( value port )
:codegen-xasm
  pop-non-tos-peephole
  TOS-in-HL? ?<
    hl->bc
    out-(c)-e
  ||
    de->bc
    out-(c)-l
  >?
  pop-tos ;

primitive: INP  ( port -- value )
Succubus:setters:out-8bit
:codegen-xasm
  tos-r16 reg:bc r16->r16
  TOS-in-HL? ?<
    in-l-(c)
    0 c#->h
  ||
    in-e-(c)
    0 c#->d
  >? ;

<zx-system>
primitive: LIT:OUTP  ( value )  \ [port]
Succubus:setters:in-8bit
:codegen-xasm
  ?curr-node-lit-value #->bc
  TOS-in-HL? ?<
    out-(c)-l
  ||
    out-(c)-e
  >?
  pop-tos ;

primitive: LIT:INP  ( -- value )  \ [port]
Succubus:setters:out-8bit
:codegen-xasm
  push-tos-peephole
  ?curr-node-lit-value
  dup hi-byte c#->a
  lo-byte in-a-(c#)
  a->tos ;
<zx-forth>


: UDG  ( -- udgstart^ )  SYS: UDG^ @ ; zx-inline
: UDG! ( udgstart^ )  SYS: UDG^ ! ; zx-inline

: LASTK-OFF  0 sys: last-k c! ; zx-inline
: LASTK@  ( -- char )  sys: last-k c@ ; zx-inline


\ zxlib-end

<zx-done>
