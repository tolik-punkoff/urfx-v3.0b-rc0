;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level I/O: +3DOS
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; Pages 1, 3, 4, 6 are considered as an array
;; of 128 sector buffers (numbered 0...127),
;; each of 512 bytes.
;; The cache and RAMdisk occupy two separate
;; (contiguous) areas of this array.

;; registers for +3DOS calls
;; loaded before calling a function, and the result will be stored here
(*
0 quan +3DOS-AF
0 quan +3DOS-BC
0 quan +3DOS-DE
0 quan +3DOS-HL
*)


zxlib-begin" +3DOS I/O library library"


|: +3DOS-TRANSLATE-ERROR  ( err -- err )
  <<  1 of?v| DOS-ERR-WRITE |?
      2 of?v| DOS-ERR-SEEK |?
      3 of?v| DOS-ERR-READ |?
      4 of?v| DOS-ERR-READ |?
     20 of?v| DOS-ERR-BAD-NAME |?
     21 of?v| DOS-ERR-BAD-API |?
     23 of?v| DOS-ERR-NO-FILE |?
     24 of?v| DOS-ERR-CANT-CREATE |?
     25 of?v| DOS-ERR-READ |?
     26 of?v| DOS-ERR-WRITE |?
     27 of?v| DOS-ERR-WRITE |?
     28 of?v| DOS-ERR-WRITE |?
     29 of?v| DOS-ERR-READ |?
  else| drop DOS-ERR-OTHER >> ;


;; call +3DOS
;; WARNING! SP should not be at TSTACK!
code: +3DOS-CMD  ( fn-call-address )
\ dop3dos:
  \ pop   hl

  ld    a, () zx-['pfa] +3DOS?
  or    a
  jr    z, # .no-p3dos-present

  \ push  bc
  push  ix          ;; some +3DOS functions destroys it
  push  iy          ;; it is used by the system

  ld    p3dos-call-addr (), hl

  di
  ;; prepare stack and RAM/ROM
  ld    a, () sysvar-bankm  ;; RAM/ROM switching system variable
  and   # $DF               ;; reset bit 5 (lock), just in case
  ld    p3dos-saved-bankm (), a ;; save it to be restored later
  or    # $07               ;; want RAM page 7
  and   # $EF               ;; reset bit 4 (ROM) and bit 5 (lock)
  ld    bc, # $7FFD         ;; port used for horiz ROM switch and RAM paging
  ld    sysvar-bankm (), a  ;; keep system variables up to date
  out   (c), a              ;; RAM page 7 to top and DOS ROM

  ;; set +2A/+3 port #1FFD
  ld    a, () sysvar-bank678
  ld    p3dos-saved-bank678 (), a
  or    # $04               ;; switch on +3DOS ROM
  ld    sysvar-bank678 (), a
  ld    b, # $1F
  out   (c), a

  ld    p3dos-saved-sp (), sp

  ;; switch to IM1
  ld    a, # $3F
  ld    i, a
  ld    iy, # $5C3A
  im    # 1

  ;; load registers
  ld    sp, # p3dos-reg-af
  pop   af
  pop   bc
  pop   de
  pop   hl

  ;; switch stack (because it is in a switched page).
  ;; this is the official TSTACK used by BASIC when calling +3DOS.
  ;; according to the official manual, it can extend to $5B7C (inclusive).
  ld    sp, # $5C00
$here 2- @def: p3dos-sp0

  ei
  call  # 0   ;; self-modifying code
$here 2- @def: p3dos-call-addr

@p3dosret:
  di
  ;; save all registers
  ld    sp, # p3dos-reg-hl 2+
  push  hl
  push  de
  push  bc
  push  af

  ;; restore 128K banking
  ld    a, () p3dos-saved-bankm
  ld    bc, # $7FFD
  ld    sysvar-bankm (), a
  out   (c), a      ;; switch back to RAM page 0 and 48 BASIC
  ;; restore +2A/+3 port #1FFD
  ld    a, () p3dos-saved-bank678
  ld    b, # $1F
  ld    sysvar-bank678 (), a
  out   (c), a

  ;; restore stack
  ld    sp, () p3dos-saved-sp

  ;; as arrow library is using the TSTACK area to save scr$,
  ;; notify it that there is nothing interesting there.
  ld    hl, # $5C00 1-
  ld    (hl), # 0
  dec   l
  ld    $5B7C (), hl

  ;; switch back to IM2
  1 [IF]
  ld    a, # $3B  ;; ROM contains a lot of #FF there
  ;; I register points to area filled with #FF here
  ld    i, a
  im    # 2
  [ENDIF]

  ei
  pop   iy
  pop   ix
  pop   hl
  next

.no-p3dos-present:
  ld    hl, # $0000   ;; reset carry, error #0 (drive not ready)
  ld    p3dos-reg-af (), hl
  pop   hl
  next

p3dos-saved-bankm: 0 db,
p3dos-saved-bank678: 0 db,
p3dos-saved-sp: 0 dw,

p3dos-reg-af: 0 dw,
p3dos-reg-bc: 0 dw,
p3dos-reg-de: 0 dw,
p3dos-reg-hl: 0 dw,
;code-no-next

asm-label: p3dos-reg-af constant +3DOS-AF
asm-label: p3dos-reg-bc constant +3DOS-BC
asm-label: p3dos-reg-de constant +3DOS-DE
asm-label: p3dos-reg-hl constant +3DOS-HL

asm-label: p3dos-sp0 constant +3DOS-SP0

code: +3DOS-ERR?  ( -- err-code // 0 )
  push  hl
  ld    hl, () p3dos-reg-af
  bit   0, l
  ld    l, h
  ld    h, # 0
  jr    z, # .error
  ld    l, h
.error:
;code

code: +3DOS-CF?  ( -- carry-set? )
  push  hl
  ld    a, () p3dos-reg-af
  cpl
  and   # $01
zx-word-p3dos-flag-push-a:
  ld    l, a
  ld    h, # 0
;code

code: +3DOS-ZF?  ( -- zero-set? )
  push  hl
  ld    a, () p3dos-reg-af
  and   # $40
  cp    # $40
  ld    a, # 1
  sbc   a, # 0
  jr    # zx-word-p3dos-flag-push-a
;code

;; turn off ramdisk
\ : +3DOS-NO-RAMDISK
\   8 +3DOS-DE !  ;; cache: 8 buffers by 512 bytes
\   4 +3DOS-HL !  ;; ramdisk: minimum possible size is 4 sectors
\   $13F +3DOS-CMD ;

: +3DOS-MOTOR-ON
  $196 +3DOS-CMD ; zx-inline

: +3DOS-MOTOR-OFF
  $19C +3DOS-CMD ; zx-inline

|: INIT+3DOS
  ;; disable alert routine
  0 +3DOS-AF !
  $14E +3DOS-CMD
  ;; start "motor off" countdown
  $199 +3DOS-CMD ; zx-inline


|: (INIT+3DOS-I/O)
  INIT+3DOS
  [ OPT-DOS-I/O-+3DOS-BUFFERS 0 32768 forth:within ] [IF]
    ;; cache
    [ OPT-DOS-I/O-+3DOS-BUFFERS ] {#,} +3DOS-DE !
    ;; ramdisk
    [ OPT-DOS-I/O-+3DOS-BUFFERS 256 forth:*
      OPT-DOS-I/O-+3DOS-RAMDISK 4 forth:max forth:+ ] {#,} +3DOS-HL !
    $13F +3DOS-CMD
  [ENDIF]
  [ OPT-DOS-I/O-+3DOS-STOP-MOTOR? ] [IF] +3DOS-MOTOR-OFF [ENDIF] ;

['] (INIT+3DOS-I/O) TO SYS:(INIT-I/O)


;; current block file name
create +3DOS-FNAME 13 allot create;
false quan +3DOS-OPEN?

|: +3DOS-FNAME!  ( addr count )
  DUP 1 < IF 2DROP " BLOCKS.BLK" ENDIF
  12 MIN
  +3DOS-FNAME 13 $FF FILL
  +3DOS-FNAME SWAP CMOVE ;

;; close opened block file
: +3DOS-CLOSE
  +3DOS-OPEN? IF
    +3DOS-BC OFF
    $109 +3DOS-CMD
    +3DOS-ERR? IF
      ;; abandon it
      +3DOS-BC OFF
      $10C +3DOS-CMD
    ENDIF
    FALSE TO +3DOS-OPEN?
  ENDIF ;

;; abort on disk i/o error
: ?+3DOS-ERROR
  +3DOS-ERR? dup 0?exit< drop >?
  +3DOS-TRANSLATE-ERROR DOS-LAST-ERR:!
  DOS-ERROR ;

0 constant +3MODE-R/O
1 constant +3MODE-R/W
2 constant +3MODE-R/W-CREATE  ;; create if absent
3 constant +3MODE-CREATE      ;; truncate to zero size

|: (+3DOS-SETUP-MODE)  ( mode )
  ;; first number: file number, access mode
  ;; second number: create action, open action
  $00_03 ;; file #0, exclusive r/w -- most common mode
  SWAP <<
    +3MODE-R/O of?v| DROP $00_05 $00_02 |?
    +3MODE-R/W of?v| $00_02 |?
    +3MODE-R/W-CREATE of?v| $02_02 |?
    +3MODE-CREATE of?v| $02_04 |?
  \ else| 2DROP DOS-ERROR false exit >>
  else| 2DROP $00_05 $00_02 >>
  +3DOS-DE !  +3DOS-BC !  ;

|: (+3DOS-OPEN-COMMON)  ( addr count mode )
  +3DOS-CLOSE
  (+3DOS-SETUP-MODE)
  +3DOS-FNAME!
  +3DOS-FNAME +3DOS-HL !
  $106 +3DOS-CMD
  +3DOS-ERR? 0?exit< +3DOS-OPEN?:!t >?
  ?+3DOS-ERROR ;

: +3DOS-EXISTS  ( addr count -- bool )
  +3DOS-CLOSE
  +3DOS-FNAME!
  +3DOS-FNAME +3DOS-HL !
  $00_05 +3DOS-BC !
  $00_02 +3DOS-DE !
  $106 +3DOS-CMD
  +3DOS-ERR? ?exit< false >?
  +3DOS-OPEN?:!t +3DOS-CLOSE
  true ;

: +3DOS-FLUSH
  $4100 +3DOS-AF !  ;; drive A
  $142 +3DOS-CMD ?+3DOS-ERROR ;

;; erase file, set current file name to erased file.
;; currently opened file is closed.
;; in +3DOS, this is done via "OPEN" command
: +3DOS-ERASE  ( addr count )
  +3DOS-CLOSE
  +3DOS-FNAME!
  +3DOS-FNAME +3DOS-HL !
  $00_03 +3DOS-BC ! ;; file #0, exclusive r/w -- most common mode
  $00_04 +3DOS-DE ! ;; erase existing, fail to open
  $106 +3DOS-CMD ;

: +3DOS-SEEK  ( posd )
  +3DOS-DE ! +3DOS-HL !
  +3DOS-BC OFF
  $136 +3DOS-CMD
  ?+3DOS-ERROR ;

: +3DOS-READ  ( addr count )
  ;; read or write bytes
  SWAP +3DOS-HL !   ;; addr
  +3DOS-DE !        ;; length
  $0000 +3DOS-BC !  ;; file # and page #0 for $C000 -- FIXME!
  $112 +3DOS-CMD
  ?+3DOS-ERROR ;

: +3DOS-WRITE  ( addr count )
  ;; read or write bytes
  SWAP +3DOS-HL !   ;; addr
  +3DOS-DE !        ;; length
  $0000 +3DOS-BC !  ;; file # and page #0 for $C000 -- FIXME!
  $115 +3DOS-CMD
  ?+3DOS-ERROR ;

: +3DOS-GET-SIZE  ( -- sized )
  0 +3DOS-BC !
  $139 +3DOS-CMD
  +3DOS-ERR? dup ?exit< ?+3DOS-ERROR 0 0 >? drop
  +3DOS-HL @ +3DOS-DE C@ ;


$5B00 constant (CAT-BUF)
\ : (CAT-BUF)  ( -- addr )  PAD ;

: CAT
  (CAT-BUF) 26 ERASE
  BEGIN
    (CAT-BUF) 13 + (CAT-BUF) 13 CMOVE   ;; continue from this entry
    $0201 +3DOS-BC !
    (CAT-BUF) +3DOS-DE !
    " *.*\xff" DROP +3DOS-HL !
    $11E +3DOS-CMD
    ?+3DOS-ERROR
  +3DOS-BC 1+ C@ 2- 0WHILE
    (CAT-BUF) 13 +
    DUP 8 TYPE [CHAR] . EMIT DUP 8 + 3 TYPE
    SPACE 11 + @ 0 U.R ." K\n"
  REPEAT
  $4100 +3DOS-AF !
  $121 +3DOS-CMD
  +3DOS-ERR? 0IF +3DOS-HL @ 0 U.R ." K free\n" ENDIF ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level API
;; it currently supports only one file. sorry.

['] +3DOS-CLOSE TO DOS-CLOSE

|: (DO-DOS-OPEN-R/O)  ( addr count )
  +3MODE-R/O (+3DOS-OPEN-COMMON) ;
['] (DO-DOS-OPEN-R/O) TO DOS-OPEN-R/O

|: (DO-DOS-OPEN-R/W)  ( addr count )
  +3MODE-R/W (+3DOS-OPEN-COMMON) ;
['] (DO-DOS-OPEN-R/W) TO DOS-OPEN-R/W

|: (DO-DOS-OPEN-R/W-CREATE)  ( addr count )
  +3MODE-R/W-CREATE (+3DOS-OPEN-COMMON) ;
['] (DO-DOS-OPEN-R/W-CREATE) TO DOS-OPEN-R/W-CREATE

|: (DO-DOS-CREATE)  ( addr count )
  +3MODE-CREATE (+3DOS-OPEN-COMMON) ;
['] (DO-DOS-CREATE) TO DOS-CREATE

['] +3DOS-SEEK TO DOS-SEEK
['] +3DOS-READ TO DOS-READ
['] +3DOS-WRITE TO DOS-WRITE
['] +3DOS-GET-SIZE TO DOS-GET-SIZE

|: (DO-DOS-EXISTS?)  ( addr count -- flag )
  DOS-CLOSE +3DOS-EXISTS ;
['] (DO-DOS-EXISTS?) TO DOS-EXISTS?

['] +3DOS-ERASE TO DOS-ERASE
['] +3DOS-FLUSH TO DOS-FLUSH


zxlib-end
