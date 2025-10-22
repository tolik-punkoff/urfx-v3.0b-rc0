;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CPCEMU .DSK disk image support library
;; coded by Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main module
;; https://www.cpcwiki.eu/index.php/Format:DSK_disk_image_file_format
;; i only need to write standard +3DOS disks, so no fancy features.
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
this is very simple module to create standard .DSK disk images.

the API is minimalistic by design: you can create a file,
write file bytes (sequentially), and close the file.
the library does the minimal amount of work to satisfy +3DOS,
and that's all.

it is possible to create a boot sector for all disks except
P3-DATA. boot code will be loaded at $FE00. machine state is:
  SP: $FE00
  IP: $FE10
  RAM banks: RAM4, RAM7, RAM6, RAM3
  ROM bank: dunno (need to check it)

disk images are written as "interleaved", for speed.
*)

module MK-CPCDSK
<disable-hash>

true constant INTERLEAVED?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; internal data structures

<published-words>
enum{
  def: PCW-SS   -- standard PCW range DD SS ST (and +3) (180)
  def: P3-SYS   -- standard CPC range DD SS ST system format
  def: P3-DATA  -- standard CPC range DD SS ST data only format
  def: PCW-DS   -- standard PCW range DD DS DT (720)
}

;; disk info, pointers to disk data
0
new-field dsk>trdata   -- data for all tracks, malloced
new-field dsk>#tracks  -- number of tracks
new-field dsk>#sides   -- number of sides
new-field dsk>#sectors -- number of sectors
new-field dsk>type     -- see above
;; disk geometry
new-field geom>resv-tracks  -- number of reserved tracks
new-field geom>recs/block   -- size of block, in 128-byte records; size=128<<recs/block
new-field geom>dir-blocks   -- number of directory blocks
new-field geom>bootable?    -- valid CP/M bootable disk?
new-field geom>#blocks      -- number of blocks in disk (calculated)
new-field geom>free-block   -- first free block
constant #dsk

;; bytes per directory entry (extent)
32 constant bytes/xt
;; bytes per sector
512 constant bytes/sector
;; logical block record size
128 constant bytes/block-rec
;; sectors per track is hardcoded to 9
bytes/sector 9 * constant bytes/track


;; current DSK struct. everything works with this.
0 quan curr-dsk  (published)


;; free allocated dsk image. it is safe to pass "0" here.
@: free-dsk
  curr-dsk not?exit
  curr-dsk dsk>trdata:@ dynmem:free
  curr-dsk dynmem:free
  curr-dsk:!0 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; easy access to current disk info

|: dsk-trdata   ( -- tracks )    curr-dsk dsk>trdata:@ ;
|: dsk-#tracks  ( -- #tracks )   curr-dsk dsk>#tracks:@ ;
|: dsk-#sides   ( -- #sided )    curr-dsk dsk>#sides:@ ;
|: dsk-#sectors ( -- #sectors )  curr-dsk dsk>#sectors:@ ;
|: dsk-type     ( -- type )      curr-dsk dsk>type:@ ;

|: dsk-resv-tracks  ( -- count )  curr-dsk geom>resv-tracks:@ ;
|: dsk-recs/block   ( -- count )  curr-dsk geom>recs/block:@ ;
|: dsk-dir-blocks   ( -- count )  curr-dsk geom>dir-blocks:@ ;
|: dsk-bootable?    ( -- flag  )  curr-dsk geom>bootable?:@ ;
|: dsk-#blocks      ( -- count )  curr-dsk geom>#blocks:@ ;
|: dsk-free-block   ( -- index )  curr-dsk geom>free-block:@ ;
|: dsk-bytes/block  ( -- bytes )  bytes/block-rec dsk-recs/block lshift ;
|: dsk-#xts         ( -- count )  dsk-bytes/block dsk-dir-blocks bytes/xt u*/ ;

|: dsk-type-str  ( -- addr count )
  dsk-type <<
    PCW-SS of?v| " PCW-SS" |?
    P3-SYS of?v| " P3-SYS" |?
    P3-DATA of?v| " P3-DATA" |?
    PCW-DS of?v| " PCW-DS" |?
  else| drop " INVALID" >> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate data address for various entities

;; return address of the logical track in track data
|: track^  ( log-tidx -- addr )  bytes/track * dsk-trdata + ;

;; logical sectors are: track 0, side 0; track 0, side 1; etc.
|: sector^  ( log-sector-index -- addr )
  dsk-#sectors u/mod    ( track-num sec-num )
  bytes/sector * swap  ( sec-ofs track-num )
  track^ + ;

;; return address of the first byte of the logical block.
;; block data are consecutive.
|: block^  ( block-idx -- addr )
  ;; calculate byte offset for block data
  dsk-bytes/block *
  ;; calculate address of the first block
  dsk-resv-tracks dsk-#sectors * sector^
  ;; use the fact that data sectors are consecutive
  + ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Disk Parameter Blocks for some disk types

;; PCW-SS disk DPB
create dpb-pcw180
  $00 c,  ;; disk type
  $00 c,  ;; disk geometry
  40 c,   ;; tracks
  9 c,    ;; sectors
  2 c,    ;; sector size
  1 c,    ;; reserved tracks
  3 c,    ;; sectors/block
  2 c,    ;; dir blocks
  $2A c,  ;; gap (r/w)
  $52 c,  ;; gap (format)
create;  (private)

;; PCW-DS disk DPB
create dpb-pcw720
  $03 c,  ;; disk type
  $81 c,  ;; disk geometry
  80 c,   ;; tracks
  9 c,    ;; sectors
  2 c,    ;; sector size
  2 c,    ;; reserved tracks
  4 c,    ;; sectors/block
  4 c,    ;; dir blocks
  $2A c,  ;; gap (r/w)
  $52 c,  ;; gap (format)
create;  (private)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; new disk image creation

;; create new disk image data structure for the given format.
;; frees currently opened disk ("curr-dsk").
;; aborts on error. may leave partially allocated "curr-dsk".
@: new-dsk  ( format )
  free-dsk
  #dsk dynmem:?alloc curr-dsk:!
  curr-dsk #dsk erase
  << PCW-SS of?v| ;; first sector: 1
       PCW-SS curr-dsk dsk>type:!
       40 curr-dsk dsk>#tracks:!
        1 curr-dsk dsk>#sides:!
        9 curr-dsk dsk>#sectors:!
        1 curr-dsk geom>resv-tracks:!
        3 curr-dsk geom>recs/block:!
        2 curr-dsk geom>dir-blocks:! |?
     P3-SYS of?v| ;; first sector: 65
       P3-SYS curr-dsk dsk>type:!
       40 curr-dsk dsk>#tracks:!
        1 curr-dsk dsk>#sides:!
        9 curr-dsk dsk>#sectors:!
        2 curr-dsk geom>resv-tracks:!
        3 curr-dsk geom>recs/block:!
        2 curr-dsk geom>dir-blocks:! |?
     P3-DATA of?v| ;; first sector: 193
       P3-DATA curr-dsk dsk>type:!
       40 curr-dsk dsk>#tracks:!
        1 curr-dsk dsk>#sides:!
        9 curr-dsk dsk>#sectors:!
        0 curr-dsk geom>resv-tracks:!
        3 curr-dsk geom>recs/block:!
        2 curr-dsk geom>dir-blocks:! |?
     PCW-DS of?v| ;; first sector: 1
       PCW-DS curr-dsk dsk>type:!
       80 curr-dsk dsk>#tracks:!
        2 curr-dsk dsk>#sides:!
        9 curr-dsk dsk>#sectors:!
        2 curr-dsk geom>resv-tracks:!
        4 curr-dsk geom>recs/block:!  ;; because +3DOS can handle max 360 blocks
        4 curr-dsk geom>dir-blocks:! |?
  else| error" invalid DSK type" >>
  ;; calculate number of blocks in disk
  dsk-#tracks dsk-resv-tracks - dsk-#sides * dsk-#sectors *
  bytes/sector dsk-bytes/block u*/
  curr-dsk geom>#blocks:!
  ;; allocate track data
  dsk-#tracks dsk-#sides * dsk-#sectors * bytes/sector *
  dup dynmem:?alloc dup curr-dsk dsk>trdata:!
  swap $E5 fill
  ;; set first free block
  dsk-dir-blocks curr-dsk geom>free-block:!
  ;; put DPB
  dsk-type <<
    PCW-SS of?v| dpb-pcw180 |?
    PCW-DS of?v| dpb-pcw720 |?
    P3-SYS of?v| dpb-pcw180 |?
  else| drop exit >>
  0 track^  dup 512 erase  10 cmove ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; saving disk image to file

|: dsk-1st-sector  ( -- sector-id )
  dsk-type <<
    P3-SYS  of?v| 65 |?
    P3-DATA of?v| 193 |?
  else| drop 1 >> ;

|: hdr-scinfo-start  ( -- addr )  pad $18 + ;
|: hdr-scinfo^  ( sidx -- addr )  8 * hdr-scinfo-start + ;
|: sci>track    ( addr -- addr )  ;
|: sci>side     ( addr -- addr )  1+ ;
|: sci>secid    ( addr -- addr )  2 + ;
|: sci>secsize  ( addr -- addr )  3 + ;

;; header is at PAD
|: mk-track-info-header  ( tidx )
  dsk-#sides u/mod
  ( side) pad $11 + c!
  ( track) pad $10 + c!
  ( sector size) 2 pad $14 + c!
  ( sector count) 9 pad $15 + c!
  ( gap3) 78 pad $16 + c! ;; (92 bytes for TR-DOS)
  ( filler byte) $E5 pad $17 + c! ;

;; header is at PAD
|: mk-base-sector-info
  0 hdr-scinfo^ dsk-#sectors 8 * erase
  dsk-#sectors for
    i hdr-scinfo^
    pad $10 + c@  over sci>track c!
    pad $11 + c@  over sci>side c!
    0 over sci>secid c! ;; for now
    2 swap sci>secsize c!
  endfor ;

;; header is at PAD
|: find-free-sec  ( sidx -- sidx )
  << dsk-#sectors umod
     dup hdr-scinfo^ sci>secid c@ ?^| 1+ |?
  else| >> ;

;; header is at PAD
|: mk-interleaved
  dsk-1st-sector 0  ( secid sidx )
  dsk-#sectors for
    find-free-sec
    2dup hdr-scinfo^ sci>secid c!
    2+  ;; advance by 2 sectors
  1 under+ endfor 2drop ;

;; header is at PAD
|: mk-normal
  dsk-1st-sector dsk-#sectors for
    dup i hdr-scinfo^ sci>secid c!
  1+ endfor drop ;

|: save-track-header  ( tidx fd )
  >r pad 256 erase
  " Track-Info\r\n" pad swap cmove
  mk-track-info-header
  mk-base-sector-info
  [ interleaved? ] [IF] mk-interleaved [ELSE] mk-normal [ENDIF]
  pad 256 r> file:write ;

|: save-sectors  ( tdata^ fd )
  >r dsk-#sectors for
    ( sector info offset in header) i 8 *
    ( sector info address in header) pad $18 +
    + 2 + c@ dsk-1st-sector - ( tdata^ sidx | fd )
    bytes/sector * over +     ( tdata^ sdata^ | fd )
    bytes/sector r@ file:write
  endfor rdrop drop ;

|: save-header  ( fd )
  >r pad 256 erase
  " MV - CPCEMU Disk-File\r\nDisk-Info\r\n" pad swap cmove
  " UrForth/Beast!" pad $22 + swap cmove  ;; creator
  dsk-#tracks pad $30 + c!
  dsk-#sides pad $31 + c!
  dsk-#sectors bytes/sector * 256 + pad $32 + w!  ;; track data size
  pad 256 r> file:write ;

;; save current disk to the given fd.
;; aborts on any error.
;; doesn't seek.
;; corrupts PAD.
@: save-dsk  ( fd )
  dup >r save-header
  ;; save tracks
  dsk-#tracks dsk-#sides * for
    i r@ save-track-header
    i track^ r@ save-sectors
  endfor rdrop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; creating machine boot sector

|: calc-boot-checksum  ( -- checksum-byte )
  0 0 track^ 512 for c@++ rot + lo-byte swap endfor
  ;; final fix
  $FF xor 4 + lo-byte ;

;; set bootsector data. first 16 bytes are ignored.
@: set-boot  ( addr )
  dsk-type P3-DATA = ?error" cannot create boot for this disk type"
  16 +  0 track^ 16 +  512 16 -  cmove
  0  0 track^ 511 +  c!   ;; clear checksum
  calc-boot-checksum
  0 track^ 511 + c! ;

@: boot-allowed?  ( -- flag )
  dsk-type P3-DATA <> ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; creating and writing new +3DOS file

;; FCB used to write file
0
new-field fcb>xt^     -- direntry address
new-field fcb>alc#    -- index of the current ALC
new-field fcb>wrsize  -- total number of written bytes
constant #fcb

create fcb #fcb allot create;  (private)

|: fcb-xt^    ( -- addr )  fcb fcb>xt^:@ ;
|: fcb-alc#   ( -- idx )  fcb fcb>alc#:@ ;
|: fcb-wrsize ( -- idx )  fcb fcb>wrsize:@ ;

;; get extent number
|: fcb-xn@    ( -- num )
  fcb-xt^ dup 12 + c@
  swap 14 + c@ 5 lshift + ;

|: fcb-xn!  ( num )
  dup %000_11111 and fcb-xt^ 12 + c!
  5 rshift fcb-xt^ 14 + c! ;


;; directory starts from the block #0
|: extent^  ( xt-idx -- addr )
  bytes/xt * 0 block^ + ;

;; as we are creating the disk ourselves, it is easy
|: find-free-extent  ( -- xt-addr TRUE // FALSE )
  dsk-#xts extent^  0 extent^  ( eaddr caddr )
  << 2dup = ?v| 2drop false |?
     dup c@ $E5 = ?v| nip true |?
  ^| bytes/xt + | >> ;

;; create first empty direntry, with blank name, setup "fcb".
;; aborts on error.
|: (create-file)
  fcb #fcb erase
  find-free-extent not?error" out of directory space for new file"
  dup fcb fcb>xt^:!
  dup bytes/xt erase
  1+ 11 blank ;

;; split file name to name and extension.
;; extension doesn't contain a dot, and can be empty.
|: fn-split  ( addr count -- naddr ncount eaddr ecount )
  2dup << dup -0?v| 2drop over 0 |?
    2dup + 1- c@ [char] . = not?^| 1- |?
  else| ( addr count addr left )
    dup >r 1- 2swap  ( addr left addr count | left )
    r@ - r> under+ >> ;

|: good-name-char?  ( ch -- flag )
  dup 32 128 within not?exit< drop false >?
  " <>.,;:=?*[]" rot string:memchr
  >r 2drop r> 0= ;

|: good-name-str?  ( addr count -- flag )
  swap << over ?^| c@++ good-name-char? not?exit< 2drop false >? 1 under- |?
  else| 2drop true >> ;

;; create new file with the given name, prepare it for writing.
;; aborts on error.
@: create-file  ( addr count )
  \ endcr ." FNAME=<" 2dup type ." >\n"
  fcb-xt^ ?error" some file already opened"
  fcb #fcb erase
  dup 0<= ?error" cannot create file without a name"
  fn-split  ( naddr ncount eaddr ecount )
  \ endcr ." EXT=<" 2dup type ." >\n"
  dup 3 > ?error" invalid file extension"
  2dup good-name-str? not?error" invalid file extension"
  2over dup 1 9 within not?error" invalid file name"
  good-name-str? not?error" invalid file name"
  ( naddr ncount eaddr ecount )
  (create-file)
  fcb-xt^ 9 + swap cmove
  fcb-xt^ 1 + swap cmove ;

;; finish writing the file.
@: close-file
  fcb-xt^ not?error" file not opened"
  endcr ." DSK: written '" fcb-xt^ 1+ 8 string:-trailing type
        fcb-xt^ 9 + 3 string:-trailing dup ?< [char] . emit type || 2drop >?
        ." '; bytes=" fcb-wrsize 0.r
        ." ; extents=" fcb-xn@ 0.r cr
  fcb #fcb erase ;


|: xt-bytes/alc  ( -- 1 // 2 )  1 dsk-#blocks 255 > - ;
|: xt-#alc  ( -- #-of-alc-items )  16 xt-bytes/alc u/ ;

;; allocate new file extent.
;; aborts on error.
|: alloc-new-extent
  \ endcr ." want new extent...\n"
  find-free-extent not?error" out of directory space for file data"
  ;; clear new extent
  dup bytes/xt erase
  ;; copy file name to the new extent
  fcb-xt^ 1+ over 1+ 11 cmove
  fcb-xn@ 1+ ( new-xt^ new-xn )
  swap fcb fcb>xt^:!  fcb fcb>alc#:!0
  fcb-xn! ;

;; allocate new file block.
;; aborts on error.
|: alloc-new-block
  ;; check if we have any free blocks left.
  ;; this is because we always want a new free block when calling this.
  \ endcr ." freeblk=" dsk-free-block . ." #blocks=" dsk-#blocks . ." bsize=" dsk-bytes/block 0.r cr
  dsk-free-block dsk-#blocks u>= ?error" out of disk space"
  fcb-alc# xt-#alc = ?< alloc-new-extent >?
  ;; here we are sure that current extent can hold at least one more block
  dsk-free-block  curr-dsk geom>free-block:1+!
  dup block^ dsk-bytes/block erase  ;; why not
  ( free-block )
  fcb-xt^ 16 +  fcb-alc# xt-bytes/alc * +
  ( free-block alc^ )
  xt-bytes/alc 1 = ?< c! || w! >?
  ;; advance alc counter
  fcb fcb>alc#:1+!
  ;; clear `Rc`
  0 fcb-xt^ 15 + c! ;

;; put data to the last used block.
;; everything is correct when calling this.
|: put-block-data  ( addr count )
  [ 0 ] [IF]
    endcr ." writing " dup . ." bytes of data ("
      fcb-wrsize . ." written, block offset: "
      fcb-wrsize dsk-bytes/block umod 0.r ." )\n"
  [ENDIF]
  dsk-free-block 1- block^  ;; block address to write
  fcb-wrsize dsk-bytes/block umod +   ;; skip already written data
  over >r ;; save count
  swap cmove  ;; copy data
  r> fcb fcb>wrsize:+!  ;; update number of written bytes
  ;; fix `Rc`. it is number of `bytes/block-rec` records in the current extent.
  fcb-wrsize
  ;; calculate number of bytes per extent
  dsk-bytes/block xt-#alc *
  umod  ;; bytes in the current extent
  bytes/block-rec u/mod 0<> -
  ;; "0" means that the extent is full
  dup 0?< drop dsk-bytes/block xt-#alc *  bytes/block-rec u/ >?
  fcb-xt^ 15 + c! ;

;; write bytes to opened file.
;; aborts on error.
@: write  ( addr count )
  fcb-xt^ not?error" file not opened"
  dup not?exit< 2drop >?
  << dup 0?v||
    fcb-wrsize dsk-bytes/block umod 0?< alloc-new-block >?
    ;; calculate bytes left in the current block
    dsk-bytes/block  fcb-wrsize dsk-bytes/block umod -
    >r 2dup r> min  ( addr count addr to-write-count )
    dup >r          ( addr count addr to-write-count | to-write-count )
    put-block-data
  ^| r@ under+ r> - | >> 2drop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; writing +3DOS BASIC headers

|: fix-header-checksum
  0 127 for pad i + c@ + lo-byte endfor
  pad 127 + c! ;

|: init-header  ( zx-length )
  fcb-xt^ not?error" file not opened"
  fcb-wrsize ?error" header must come first"
  pad 128 erase
  " PLUS3DOS\x1a" pad swap cmove
  $0001 pad 9 + w!  ;; issue and version
  ( file length, with header) 128 +  pad 11 + ! ;

|: header-ftype!  ( type )  pad 15 + c! ;
|: header-flen!   ( len )   pad 16 + w! ;
|: header-fstart! ( val )   pad 18 + w! ;
|: header-vstart! ( val )   pad 20 + w! ;

|: write-header
  fix-header-checksum
  pad 128 write ;

;; write +3 code file header.
;; corrupts PAD.
@: write-code-header  ( zx-addr zx-length )
  dup init-header
  ( code file) 3 header-ftype!
  ( file length) header-flen!
  ( start address) header-fstart!
  ( variables offset) $8000 header-vstart!
  write-header ;

;; write +3 basic file header with autostart at line 0.
;; corrupts PAD.
@: write-basic-header  ( zx-length )
  dup init-header
  ( basic file) 0 header-ftype!
  ( file length) dup header-flen!
  ( start line) 0 header-fstart!
  ( variables offset) header-vstart!
  write-header ;


end-module  \ MK-CPCDSK

(+
mk-cpcdsk:p3-data mk-cpcdsk:new-dsk
\ mk-cpcdsk:pcw-ds mk-cpcdsk:new-dsk
" z000.dsk" file:create

(*
" TEST.BIN" mk-cpcdsk:create-file
" hello there!" mk-cpcdsk:write
mk-cpcdsk:close-file
*)

: mk-scr  6144 for i here i + c! endfor ;
" SCR.BIN" mk-cpcdsk:create-file
$4000 6144 mk-cpcdsk:write-code-header
mk-scr
here 6144 mk-cpcdsk:write
mk-cpcdsk:close-file

dup mk-cpcdsk:save-dsk file:close
mk-cpcdsk:free-dsk
+)
