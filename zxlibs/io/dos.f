;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple DOS I/O (one file at a time)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


false zx-lib-option OPT-DOS-I/O-FORCE-+3DOS?
false zx-lib-option OPT-DOS-I/O-FORCE-ZXEMUT?


;; manually turn off disk drive motor on program startup?
false zx-lib-option OPT-DOS-I/O-+3DOS-STOP-MOTOR?
;; number of disk buffers for +3DOS
;; set to -1 to not change (ramdisk will not be set too)
8 zx-lib-option OPT-DOS-I/O-+3DOS-BUFFERS
;; number of ramdisk buffers for +3DOS (minimum is 4)
4 zx-lib-option OPT-DOS-I/O-+3DOS-RAMDISK


zxlib-begin" DOS I/O library"

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; error codes for each driver

0 constant DOS-NO-ERR
1 constant DOS-ERR-NO-FILE
2 constant DOS-ERR-CANT-CREATE
3 constant DOS-ERR-READ
4 constant DOS-ERR-WRITE
5 constant DOS-ERR-SEEK
6 constant DOS-ERR-BAD-NAME
7 constant DOS-ERR-BAD-API
8 constant DOS-ERR-OTHER


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; error handler. called on each error.

;; unchanged if no error occured
0 quan DOS-LAST-ERR

|: (DOS-ERR-HANDLER-DEFAULT)
  endcr ." ERROR: DOS ERROR!"
  (dihalt) ;

['] (DOS-ERR-HANDLER-DEFAULT) vect DOS-ERROR

|: (DOS-BAD-API)
  DOS-ERR-BAD-API DOS-LAST-ERR:! DOS-ERROR ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; high-level API
;; it currently supports only one file. sorry.

['] (DOS-BAD-API) vect DOS-CLOSE
['] (DOS-BAD-API) vect DOS-OPEN-R/O  ( addr count )
['] (DOS-BAD-API) vect DOS-OPEN-R/W  ( addr count )
['] (DOS-BAD-API) vect DOS-OPEN-R/W-CREATE  ( addr count )
['] (DOS-BAD-API) vect DOS-CREATE  ( addr count )
['] (DOS-BAD-API) vect DOS-SEEK  ( posd )
['] (DOS-BAD-API) vect DOS-READ  ( addr count )
['] (DOS-BAD-API) vect DOS-WRITE  ( addr count )
;; of the opened file
['] (DOS-BAD-API) vect DOS-GET-SIZE  ( -- sizedbl )
;; currently opened file is closed.
['] (DOS-BAD-API) vect DOS-EXISTS?  ( addr count -- flag )
;; erase file, set current file name to erased file.
;; currently opened file is closed.
['] (DOS-BAD-API) vect DOS-ERASE  ( addr count )
;; can be called at any time
['] (DOS-BAD-API) vect DOS-FLUSH


zxlib-end


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level driver selection

OPT-DOS-I/O-FORCE-+3DOS? OPT-DOS-I/O-FORCE-ZXEMUT? forth:lor [IF]
  OPT-DOS-I/O-FORCE-+3DOS? OPT-DOS-I/O-FORCE-ZXEMUT? forth:land [IF]
    " select one driver, please!" error
  [ENDIF]
  OPT-DOS-I/O-FORCE-+3DOS? [IF]
    $zx-use <io/p3dos>
  [ENDIF]
  OPT-DOS-I/O-FORCE-ZXEMUT? [IF]
    $zx-use <io/zxemut>
  [ENDIF]
[ELSE]
  DISK-OUTPUT? [IF]
    $zx-use <io/p3dos>
  [ELSE]
    $zx-use <io/zxemut>
  [ENDIF]
[ENDIF]
