;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple elf header creation, and writing binary elf file
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module tcom
\ <disable-hash>

\ 64 quan code-align
\ 64 quan forth-align
\ 32 quan const-align
\ 32 quan var-align

0 quan optinfo-size ;; for statistics

;; do we want a dynamically-linked ELF binary?
;; this doesn't work for PE, because there is no such thing as "static PE"
true quan dynamic-binary

$0040_0000 quan base-va
0 quan mem-dp  ;; real address
0 quan here-offset

;; headers area
$0080_0000 quan hdr-base-va
0 quan hdr-mem-dp  ;; real address

;; allocate memory for target image
;; its virtual address is base-va
;; 1MB should be more than enough
1024 1024 * constant target-memory-size
0 quan target-memory

;; allocate memory for target image headers
;; its virtual address is hdr-base-va
;; 1MB should be more than enough
1024 1024 * constant hdr-target-memory-size
0 quan hdr-target-memory

;; total image size in memory (i.e. how much memory to reserve for the system).
;; actually, 1MB is more than enough. 2MB is plenty. 8MB is "you'll never need that much".
;; this is for the image section, so real used memory may be slitghtly bigger.
1024 1024 * 4* constant image-vsize

;; headers section size
1024 1024 * 4* constant hdr-image-vsize

;; in target address space
: here      ( -- va )  mem-dp target-memory - base-va + here-offset + ;
: hdr-here  ( -- va )  hdr-mem-dp hdr-target-memory - hdr-base-va + ;

;; executable binary builder interface
vect init-header   ;; set image base, build header, set "here"
vect ep!  ( va )   ;; set entry point
vect finish-binary ;; final touches before saving

;; binary builder should fill these with target addresses
;; used to call SO/DLL, via "call dword^ # dlopen-va"
0 quan dlopen-va
0 quan dlclose-va
0 quan dlsym-va
0 quan exitproc-va  ;; only for shitdoze, 0 for GNU/Linux
;; in ELF headers
0 quan codesize-va
0 quan imagesize-va
0 quan imptable-va
0 quan imptable-size
;; word headers
0 quan hdr-foffset-va
0 quan hdr-codesize-va
0 quan hdr-imagesize-va

|: ?dp  ( size )  >r mem-dp target-memory dup target-memory-size + r> - 1-
                  bounds not?error" tc segfault" ;

|: ?hdr-dp  ( size )  >r hdr-mem-dp hdr-target-memory dup hdr-target-memory-size + r> - 1-
                      bounds not?error" tc segfault" ;

;; for headers
|: hdr-addr?  ( va -- flag )   hdr-base-va dup hdr-target-memory-size + 32 - bounds ;
|: ?hdr-addr  ( va -- va )     dup hdr-addr? not?error" tc segmentation fault" ;
|: hdr>real   ( va -- addr )   ?hdr-addr hdr-base-va - hdr-target-memory + ;
\ |: hdr-real-here  ( -- addr )  hdr-here hdr>real ;

: addr?  ( va -- flag )   4+ here-offset - base-va dup target-memory-size + 1- bounds ;
: ?addr  ( va -- va )     dup addr? not?error" tc segmentation fault" ;

: >real   ( va -- addr )
  dup hdr-base-va u>= ?exit< hdr>real >?
  ?addr here-offset - base-va - target-memory + ;

: real-here  ( -- addr )  here >real ;

;; used in PE builder
: >rva  ( addr -- rva )  base-va - ;
: rva-here  ( -- addr )  here base-va - ;

;; number of bytes used in target memory chunk
: binary-size      ( -- size )  mem-dp target-memory - ;
: hdr-binary-size  ( -- size )  hdr-mem-dp hdr-target-memory - ;

: init-memory
  target-memory ?error" double tc init"
  target-memory-size linux:prot-r/w linux:mmap
  not?error" cannot allocate image memory"
  dup target-memory:! mem-dp:! here-offset:!0
  hdr-target-memory ?error" double tc init"
  hdr-target-memory-size linux:prot-r/w linux:mmap
  not?error" cannot allocate header image memory"
  dup hdr-target-memory:! hdr-mem-dp:! ;

: free-memory
  target-memory target-memory-size linux:munmap drop target-memory:!0 mem-dp:!0
  hdr-target-memory hdr-target-memory-size linux:munmap drop hdr-target-memory:!0 hdr-mem-dp:!0 ;

: here!  ( va )  >real mem-dp:! ;

: unallot  ( n )  dup 0< ?error" invalid unallot" mem-dp:-! ;

: hdr-c,  1 ?hdr-dp hdr-mem-dp forth:c! hdr-mem-dp:1+! ;
: hdr-w,  2 ?hdr-dp hdr-mem-dp forth:w! hdr-mem-dp:2+! ;
: hdr,    4 ?hdr-dp hdr-mem-dp  forth:! hdr-mem-dp:4+! ;

: c,  1 ?dp mem-dp forth:c! mem-dp:1+! ;
: w,  2 ?dp mem-dp forth:w! mem-dp:2+! ;
: ,   4 ?dp mem-dp  forth:! mem-dp:4+! ;

: c@  >real forth:c@ ;
: c!  >real forth:c! ;
: w@  >real forth:w@ ;
: w!  >real forth:w! ;
:  @  >real  forth:@ ;
:  !  >real  forth:! ;

: OR!   ( val addr )  >real dup forth:@ rot or swap ! ;
: ~AND! ( val addr )  >real dup forth:@ rot ~and swap ! ;

\ : c@++  ( addr -- addr+1 b[addr])  dup c@ 1 under+ ;

: cstr,  ( addr count )
  dup +?< dup ?dp dup >r mem-dp swap cmove r> mem-dp:+! || 2drop >? ;
: cstrz,  ( addr count )  cstr, 0 c, ;

: hdr-cstr,  ( addr count )
  dup +?< dup ?dp dup >r hdr-mem-dp swap cmove r> hdr-mem-dp:+! || 2drop >? ;

: allot  ( count )  mem-dp:+! ;

: reserve     ( count )  << dup +?^| 1- 0 c, |? else| drop >> ;
: reserve-dw  ( count )  << dup +?^| 1- 0 , |? else| drop >> ;

: hdr-reserve     ( count )  << dup +?^| 1- 0 hdr-c, |? else| drop >> ;
: hdr-reserve-dw  ( count )  << dup +?^| 1- 0 hdr, |? else| drop >> ;

: def4  ( value )  , ;

: nalign  ( size )
  dup not?exit< drop >?
  here over umod dup not?exit< 2drop >?
  - mem-dp over $90 fill \ erase
  mem-dp:+! ;

: xalign  nalign ;

;; align must be POT
\ : aligned?  ( size align -- flag )  1- ~and 0=;

\ : forth-align-here  forth-align xalign ;
\ : code-align-here   code-align xalign ;
\ : align-here-4   4 xalign ;
\ : align-here-32  32 xalign ;
\ : align-here-64  64 xalign ;

\ : hdr-align  ( size )  << hdr-here over umod ?^| 0 hdr-c, |? else| drop >> ;
: hdr-align  ( size )
  dup not?exit< drop >?
  hdr-here over umod dup not?exit< 2drop >?
  - hdr-mem-dp over erase hdr-mem-dp:+! ;

: hdr-align-here  4 hdr-align ;

: init  init-memory init-header ;

|: save-binary  ( addr count )
  ." saving: " 2dup type cr
  2dup linux:unlink drop
  file:create >r
  tcom:target-memory tcom:binary-size r@ file:write
  tcom:hdr-target-memory tcom:hdr-binary-size r@ file:write
  0o755 r@ file:chmod-fd
  r> file:close ;

: save  ( addr count )
  endcr ."    code size: " tcom:binary-size ., ." bytes.\n"
  4096 tcom:xalign
  endcr ." headers size: " tcom:hdr-binary-size ., ." bytes (optinfo: " tcom:optinfo-size ., ." bytes).\n"
  endcr ."  binary size: " tcom:binary-size tcom:hdr-binary-size + ., ." bytes.\n"
  finish-binary save-binary free-memory ;

end-module tcom
