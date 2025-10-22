\ FIXME: NOT DONE YET!
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level I/O: ZXEmuT
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


zxlib-begin" ZXEmuT I/O library library"


code: (DOS-R/W)  ( addr count -- read/written 0 // read/written errcode )
  ld    a, # 255  ;; invalid mode
$here 1- @def: zio-io-mode
  exx
  ld    de, # 0
$here 2- @def: zio-fofs-hi
  ld    hl, # 0
$here 2- @def: zio-fofs-lo
  exx
  ld    bc, hl  ;; count
  pop   de      ;; address
  ld    hl, # zxemut-blk-fname
  $13 $20 zxemut-trap-2b
  push  bc      ;; r/w-count
  ld    hl, # 0
  jr    nc, # .done
  ld    l, a
.done:
  next
flush!
zxemut-blk-fname:
  [char] D db,
  [char] I db,
  [char] S db,
  [char] C db,
  [char] . db,
  [char] b db,
  [char] l db,
  [char] k db,
  0 db, 0 db, 0 db, 0 db, 0 db, 0 db, 0 db, 0 db,
;code-no-next

code: (DOS-ERASE)  ( -- err//0 )
  push  hl
  ld    hl, # zxemut-blk-fname
  $13 $16 zxemut-trap-2b
  ld    hl, # 0
  jr    nc, # .done
  ld    l, a
.done:
;code

code: (DOS-CREATE)  ( -- err//0 )
  push  hl
  ld    hl, # zxemut-blk-fname
  ld    de, # $4000
  ld    bc, # 0
  $13 $14 zxemut-trap-2b
  ld    hl, # 0
  jr    nc, # .done
  ld    l, a
.done:
;code

code: (DOS-EXISTS?)  ( -- bool )
  push  hl
  xor   a
  ld    hl, # zxemut-blk-fname
  $13 $17 zxemut-trap-2b
  ld    hl, # 0
  jr    c, # .error
  inc   l
.error:
;code

code: (DOS-GET-SIZE)  ( -- sizedbl errcode )
  push  hl
  xor   a
  ld    hl, # zxemut-blk-fname
  $13 $17 zxemut-trap-2b
  jr    c, # .error
  xor   a
.error:
  push  hl
  push  de
  ld    l, a
  ld    h, # 0
;code


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level API helpers
;; it currently supports only one file. sorry.

0 quan (DOS-R/W-MODE?)

|: ?DOS-ERROR  ( err )
  DUP 0?EXIT< DROP >?
  DOS-LAST-ERR:! DOS-ERROR ;

|: DOS-FNAME!  ( addr count )
  DUP 1 < IF 2DROP " BLOCKS.blk" ENDIF
  15 MIN
  asm-label: zxemut-blk-fname 16 ERASE
  asm-label: zxemut-blk-fname SWAP CMOVE ;

|: (DOS-OPEN-COMMON)  ( addr count r/w-mode )
  (DO-DOS-CLOSE)
  (dos-r/w-mode?):! \ asm-label: zio-io-mode c!
  DOS-FNAME! ;

|: (DOS-SEEK)  ( posd )
  asm-label: zio-fofs-hi ! asm-label: zio-fofs-lo ! ;

|: (DOS-ADVANCE)  ( count )
  asm-label: zio-fofs-lo @ asm-label: zio-fofs-hi @ SD+
  (DOS-SEEK) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level API
;; it currently supports only one file. sorry.

|: (DO-DOS-CLOSE)
  255 (dos-r/w-mode?):!
  0 0 (DOS-SEEK) ;
['] (DO-DOS-CLOSE) TO DOS-CLOSE

|: (DO-DOS-OPEN-R/O)  ( addr count )
  0 (DOS-OPEN-COMMON) ;
['] (DO-DOS-OPEN-R/O) TO DOS-OPEN-R/O

|: (DO-DOS-OPEN-R/W)  ( addr count )
  1 (DOS-OPEN-COMMON) ;
['] (DO-DOS-OPEN-R/W) TO DOS-OPEN-R/W

|: (DO-DOS-OPEN-R/W-CREATE)  ( addr count )
  2 (DOS-OPEN-COMMON) ;
['] (DO-DOS-OPEN-R/W-CREATE) TO DOS-OPEN-R/W-CREATE

|: (DO-DOS-CREATE)  ( addr count )
  (DO-DOS-CLOSE)
  DOS-FNAME! (DOS-CREATE)
  2 (dos-r/w-mode?):! ;
['] (DO-DOS-CREATE) TO DOS-CREATE

['] (DOS-SEEK) TO DOS-SEEK

|: (DO-DOS-READ)  ( addr count )
  (dos-r/w-mode?) 255 = ?exit< 2drop DOS-ERR-BAD-API ?DOS-ERROR >?
  0 asm-label: zio-io-mode c!
  dup >r (DOS-R/W)
  dup ?exit< nip rdrop ?DOS-ERROR >? drop
  dup (dos-advance)
  r> = ?exit DOS-ERR-READ ?DOS-ERROR ;
['] (DO-DOS-READ) TO DOS-READ

|: (DO-DOS-WRITE)  ( addr count )
  (dos-r/w-mode?) dup 255 = ?exit< 3drop DOS-ERR-BAD-API ?DOS-ERROR >?
  asm-label: zio-io-mode c!
  dup >r (DOS-R/W)
  dup ?exit< nip rdrop ?DOS-ERROR >? drop
  dup (dos-advance)
  r> = ?exit DOS-ERR-READ ?DOS-ERROR ;
['] (DO-DOS-WRITE) TO DOS-WRITE

;; of the opened file
|: (DO-DOS-GET-SIZE)  ( -- sizedbl )
  (dos-r/w-mode?) 255 = ?exit< DOS-ERR-BAD-API ?DOS-ERROR 0 0 >?
  (DOS-GET-SIZE) ?DOS-ERROR ;
['] (DO-DOS-GET-SIZE) TO DOS-GET-SIZE

;; currently opened file is closed.
|: (DO-DOS-EXISTS?)  ( addr count -- flag )
  (DO-DOS-CLOSE) DOS-FNAME! (DOS-EXISTS?) ;
['] (DO-DOS-EXISTS?) TO DOS-EXISTS?

;; erase file, set current file name to erased file.
;; currently opened file is closed.
|: (DO-DOS-ERASE)  ( addr count )
  (DO-DOS-CLOSE) DOS-FNAME! (DOS-ERASE) dup 0?exit< drop >?
  DUP DOS-ERR-NO-FILE = ?exit< drop >?
  ?DOS-ERROR ;
['] (DO-DOS-ERASE) TO DOS-ERASE

['] NOOP TO DOS-FLUSH


zxlib-end
