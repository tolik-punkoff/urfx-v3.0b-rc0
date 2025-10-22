;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple pe header creation, and writing binary pe file
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module pe-builder
<disable-hash>

0 quan entry-point-addr  ;; not va
0 quan code-size-addr    ;; not va
0 quan import-table-va

<private-words>

: >db,   ( value -- addr+1 )  tcom:c, ;
: >dw,   ( value -- addr+2 )  tcom:w, ;
: >dd,   ( value -- addr+4 )  tcom:, ;
: >strz, ( addr count )       tcom:cstrz, ;

512 constant FILE_ALIGNMENT
4096 constant SECTION_ALIGNMENT

0x20000000 constant IMAGE_SCN_MEM_EXECUTE
0x40000000 constant IMAGE_SCN_MEM_READ
0x80000000 constant IMAGE_SCN_MEM_WRITE

0x14c constant IMAGE_FILE_MACHINE_I386

0x0001 constant IMAGE_FILE_RELOCS_STRIPPED
0x0002 constant IMAGE_FILE_EXECUTABLE_IMAGE
0x0020 constant IMAGE_FILE_LARGE_ADDRESS_AWARE
0x0100 constant IMAGE_FILE_32BIT_MACHINE
0x0200 constant IMAGE_FILE_DEBUG_STRIPPED


\ 0 quan pe-start-addr     ;; not va

0 quan pe-header-real-size
0 quan pe-header-copy-addr  ;; real

0 quan opt-header-size-fix
\ 0 quan all-headers-size-fix

0 quan opt-header-start-va

0 quan import-table-start
0 quan import-table-rva-fix
0 quan import-table-size-fix

0 variable import-ltbl-addr
0 variable import-atbl-addr

: >dbs,  ( count )  << dup +?^| 0 >db, 1- |? else| drop >> ;
: >dds,  ( count )  << dup +?^| 0 >dd, 1- |? else| drop >> ;

: >vput-dd  ( dd var-addr )  dup >r @ ! r> 4 swap +! ;

: >imp-name  ( naddr ncount )
  tcom:rva-here dup import-ltbl-addr >vput-dd import-atbl-addr >vput-dd
  0 >dw, >strz, 2 tcom:xalign ;

<public-words>

: build-header
  tcom:here tcom:base-va <> ?error" invalid TCOM:HERE"

  tcom:real-here to pe-header-real-size
  ;; MZ stub
  [char] M >db,
  [char] Z >db,
  ;; stub size: $3C + 4 + 8 = $48
  $48 >dw,  ;; bytes in last stub sector
  1 >dw,    ;; number of sectors in stub
  0 >dw,    ;; number of relocations
  4 >dw,    ;; paragraphs in header
  50 >dbs,  ;; fill up to $3C
  tcom:real-here >r 0 >dd,  ;; PE header offset, will be patched later
  ;; written 64 bytes of DOS crap
  ;; DOS code: just exit, nobody cares
  $B8 >db, $01 >db, $4C >db, $CD >db, $21 >db,
  0 >db, 0 >db, 0 >db,  ;; align to 8 bytes
  " UrForth for Shitdoze32. what did you expected to find here?" >strz,
  32 tcom:xalign

  tcom:rva-here r> !
  ;; real PE header starts here
  [char] P >db, [char] E >db, 0 >dw,
  IMAGE_FILE_MACHINE_I386 >dw,
  2 >dw,          ;; number of sections
  $54465255 >dd,  ;; timestamp, nobody cares; "URFT", why not
  0 >dd, 0 >dd,   ;; object format crap we are not interested in
  tcom:real-here to opt-header-size-fix
  $0e0 >dw,       ;; size of optional header (which is not optional)
  [ IMAGE_FILE_RELOCS_STRIPPED IMAGE_FILE_EXECUTABLE_IMAGE or
    IMAGE_FILE_32BIT_MACHINE IMAGE_FILE_DEBUG_STRIPPED or or ] {#,} >dw,

  ;; non-optional optional header
  tcom:here to opt-header-start-va ;; for size
  $10B >dw,       ;; signature
  0 >dw,          ;; linker version, nobody cares
  0 >dd,          ;; size of code in COFF
  0 >dd,          ;; size of data in COFF
  0 >dd,          ;; size of BSS in COFF
  tcom:real-here to entry-point-addr 0 >dd,  ;; entry point RVA (not VA!)
  0 >dd,          ;; base of code in COFF
  0 >dd,          ;; base of data in COFF
  ;; more crap
  tcom:base-va >dd,  ;; image base VA
  SECTION_ALIGNMENT >dd,
  FILE_ALIGNMENT >dd,
  3 >dw, 10 >dw,         ;; OS version
  0 >dd,                 ;; image version
  3 >dw, 10 >dw,         ;; subsystem version
  0 >dd,                 ;; more shitdoze version crap
  tcom:image-vsize [ SECTION_ALIGNMENT 2* ] {#,} + >dd,  ;; full image size, with reserved memory
  \ tcom:real-here to all-headers-size-fix 0 >dd,
  FILE_ALIGNMENT >dd,    ;; first 512 bytes is the header
  0 >dd,                 ;; file checksum nobody cares about
  3 >dw,                 ;; console; use 2 for GUI
  0 >dw,                 ;; DLL crap
  ;; we will switch stacks to our own, but provide some space for OS calls
  [ 1024 1024 * ] {#,} >dd, ;; stack reserve: 1MB
  4096 >dd,              ;; stack commit
  65536 >dd,             ;; heap reserve (i don't fuckin' know)
  0 >dd,                 ;; heap commit
  0 >dd,                 ;; loader flags
  16 >dd,                ;; number of entries in the following directory
  ;; the directory itself
  0 >dd, 0 >dd,          ;; export
  ;; import table; it will always start at the image start
  tcom:real-here to import-table-rva-fix 0 >dd,
  tcom:real-here to import-table-size-fix 0 >dd,
  0 >dd, 0 >dd,          ;; resources
  0 >dd, 0 >dd,          ;; exceptions
  0 >dd, 0 >dd,          ;; certificates
  0 >dd, 0 >dd,          ;; relocations
  0 >dd, 0 >dd,          ;; debug
  0 >dd, 0 >dd,          ;; arch-dependent
  0 >dd, 0 >dd,          ;; global pointers (i haven't the slightest idea)
  0 >dd, 0 >dd,          ;; TLS
  0 >dd, 0 >dd,          ;; load config (i haven't the slightest idea again)
  0 >dd, 0 >dd,          ;; bound import
  0 >dd, 0 >dd,          ;; IAT
  0 >dd, 0 >dd,          ;; delay import
  0 >dd, 0 >dd,          ;; com+
  0 >dd, 0 >dd,          ;; reserved
  tcom:here opt-header-start-va - opt-header-size-fix w!

  ;; sections table
  ;; header section
  " .header" >strz,      ;; 8 bytes
  SECTION_ALIGNMENT >dd, ;; virtual size
  SECTION_ALIGNMENT >dd, ;; virtual address
  [ FILE_ALIGNMENT 2* ] {#,} >dd,    ;; size of data present in file
  FILE_ALIGNMENT >dd,    ;; where in file it is
  0 >dd, 0 >dd,          ;; pointers to relocations and lines, COFF crap
  0 >dw, 0 >dw,          ;; sizes of relocations and lines, COFF crap
  [ IMAGE_SCN_MEM_READ IMAGE_SCN_MEM_WRITE or ] {#,} >dd,
  ;; image section
  " .image " >strz,      ;; 8 bytes
  tcom:image-vsize >dd,  ;; virtual size
  [ SECTION_ALIGNMENT 2* ] {#,} >dd, ;; virtual address
  tcom:real-here to code-size-addr 0 >dd, ;; size of data present in file
  [ FILE_ALIGNMENT 3 * ] {#,} >dd,   ;; where in file it is
  0 >dd, 0 >dd,          ;; pointers to relocations and lines, COFF crap
  0 >dw, 0 >dw,          ;; sizes of relocations and lines, COFF crap
  [ IMAGE_SCN_MEM_EXECUTE IMAGE_SCN_MEM_READ or IMAGE_SCN_MEM_WRITE or ] {#,} >dd,
  ;; this ends the header
  tcom:real-here pe-header-real-size - to pe-header-real-size
  \ pe-header-real-size . cr
  pe-header-real-size FILE_ALIGNMENT u>= ?error" wuta..."

  FILE_ALIGNMENT tcom:nalign
  \ tcom:rva-here all-headers-size-fix !

  tcom:here tcom:>real to pe-header-copy-addr

  ;; this section will hold the copy of the header, and import table
  ;; adjust "TCOM:HERE"
  SECTION_ALIGNMENT tcom:here tcom:base-va - - to tcom:here-offset

  ;; reserve room for header (we'll copy it here on saving)
  pe-header-real-size << dup +?^| 0 tcom:c, 1- |? else| drop >>

  ;; now create import table (why shitdoze makes everything so complicated?!)
  tcom:rva-here import-table-rva-fix !
  tcom:real-here to import-table-start
  ;; we will fill this later
  [ 5 2* ] {#,} >dds,
  ;; put DLL name, and fill its offset
  tcom:rva-here import-table-start [ 3 4* ] {#,} + !
  " kernel32.dll" >strz, 4 tcom:xalign
  ;; create empty lookup table -- we will fill it later
  tcom:real-here import-ltbl-addr !
  tcom:rva-here import-table-start !
  5 >dds, 4 tcom:xalign
  ;; create empty address table -- we will fill it later
  tcom:real-here import-atbl-addr !
  tcom:rva-here import-table-start [ 4 4* ] {#,} + !
  ;; our 4 imports will be here
  tcom:here to import-table-va
  5 >dds, 4 tcom:xalign
  ;; now we need to create the lookup table itself
  2 tcom:xalign
  " LoadLibraryA" >imp-name
  " FreeLibrary" >imp-name
  " GetProcAddress" >imp-name
  " ExitProcess" >imp-name
  ;; we are done with this shit
  tcom:real-here import-table-start - import-table-size-fix !

  import-table-va dup to tcom:dlopen-va
  4+ dup to tcom:dlclose-va
  4+ dup to tcom:dlsym-va
  4+ to tcom:exitproc-va

  0 to tcom:here-offset
  FILE_ALIGNMENT tcom:nalign

  [ SECTION_ALIGNMENT 2* ] {#,} tcom:here tcom:base-va - - to tcom:here-offset
  tcom:here tcom:base-va - [ SECTION_ALIGNMENT 2* ] {#,} = not?error" dafuck!" ;


: ep!  ( va )  tcom:>rva entry-point-addr ! ;

: finish-binary
  (* do not align last section, it is not necessary.
     besides, we are using last section size as "(DP)".
  tcom:here-offset
  0 to tcom:here-offset
  FILE_ALIGNMENT tcom:align
  *)
  tcom:binary-size [ FILE_ALIGNMENT 3 * ] {#,} - code-size-addr !
  ;; copy original headers
  tcom:target-memory dup FILE_ALIGNMENT + pe-header-real-size cmove
  to tcom:here-offset ;

;; default image base for PE executables
: init-image-base  $0040_0000 to tcom:base-va ;
: init-header  init-image-base build-header ;


: setup
  ['] init-header to tcom:init-header
  ['] ep! to tcom:ep!
  ['] finish-binary to tcom:finish-binary ;

end-module pe-builder
