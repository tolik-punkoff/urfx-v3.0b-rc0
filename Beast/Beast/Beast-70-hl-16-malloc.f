;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; very simple memory allocator; 32 bins
;; allocated memory is guaranteed to be aligned at 8-byte boundary
;; WARNING! NOT PROPERLY TESTED YET!
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
internally, the allocator aligns everything on 16 bytes. this is the
smallest chunk size. each chunk holds the full size of the previous chunk
and of the current chunk, as two first dwords. this can be used to traverse
chunks in a block. free chunks also holds pointers to prev and next free
chunks in a bin.

chunks sizes for each bin were pulled out of my ass.

there is a 32-bit bitmap with the corresponding bit set if that bin has a
free chunk. it is used to speed up searching for a free chunk if we don't
have one in a requrested bin.

first, the allocator tries to get a chunk from the properly sized bin. if
there are no free chunks there, or the first chunk is bigger than
"size+THRESHOLD", then the allocator tries to get a chunk from the bigger
bin, and split it.

i pulled this strategy out of my ass too.

requests bigger than "MMAP-THRESHOLD" will be served via direct "mmap"
call. freeing mmaped chunks will "munmap" them.

bits 0..2 of "csize" field are used as flags (see the code).
bit 3 is always zero.

note that "psize" is always valid (no flags there).

all chunks in a heap block are put one after another, without gaps. heap
blocks never merged. no blocks will be lost, because their chunks are
either allocated (and will eventually be freed), or kept in a free chunks
bin, and will be reused. this strategy may waste some memory if one block
is half-full from the beginning, and another one is half-full from the end.
but there is no guarantee that the OS will return adjacent blocks on mmaps,
so i don't believe that this "wastage" is important.

on freeing, the allocator will try to merge adjacent free chunks. to make
it easier, there is always two "sentinel" chunks at the top and at the
bottom of the current heap block. the sentinels are always marked as used.
this way we may notice a free block, and return it to the OS.

sentinel chunks have "SENTINEL" bit set in "csize". this is to make the
sentinel detection easier.

the allocator gets memory from the OS by `HEAP-GROW` chunks. such chunk is
called "heap block" (or simply "heap").

returning free heap blocks to the OS is not implemented yet.

block return strategy.
when "free" detects free heap block, it doesn't put its main chunk into a
free bin. instead, it check if there is some room in "free-heaps". if there
is none, it frees all blocks from free heaps list. then it records address
of the empty heap block.

bins don't know about heaps, and don't care.
*)

module DYNMEM
<disable-hash>

<published-words>
;; if "TRUE", return free heap blocks to the OS immediately
false quan AGGRESSIVE-BLOCK-RETURN


<private-words>

;; enable debug dump words?
false constant MM-DEBUG
;; enable debug messages in bin/unbin code
false constant MM-DEBUG-EXTRA

;; some statistics
0 quan stat-mem-allocated       ;; number of currently allocated bytes
0 quan stat-heap-count          ;; number of currently allocated heaps
0 quan stat-heap-mem-allocated  ;; size currently allocated heaps in bytes
0 quan stat-heap-returned       ;; number of heaps returned to the OS

@: mem-alloced     ( -- bytes )  stat-mem-allocated ;
@: heap-count      ( -- count )  stat-heap-count ;
@: ret-heap-count  ( -- count )  stat-heap-returned ;
@: mem-used        ( -- bytes )  stat-heap-mem-allocated ;


;; grow heap by chunks aligned to this size.
;; should be bigger than MMAP-THRESHOLD + 32, and 4KB aligned.
[[ 1024 1024 * 4* ]] quan HEAP-GROW

               4096 constant PAGE-SIZE  ;; FIXME: this should be asked from the OS
 PAGE-SIZE [[ 1- ]] constant PAGE-MASK
         [[ 4 4* ]] constant SIZE-ALIGN ;; minimal allocation chunk
SIZE-ALIGN [[ 1- ]] constant SIZE-MASK
$1C00 SIZE-ALIGN [[ * ]] constant MMAP-THRESHOLD  ;; (>)
         [[ 2 4* ]] constant CHDR-SIZE  ;; internal chunk data size
                 16 constant THRESHOLD  ;; split if have more than this free space

;; flag bits in `csize` (as min chunk size is 16, we have 4 free bits)
%0001 constant MMAPED
%0001 constant RELEASED
%0010 constant FREED
%0100 constant SENTINEL
%0111 constant FLAG-MASK

$8000_0000 SIZE-ALIGN [[ - ]] PAGE-SIZE [[ - 2- ]] constant MAX-ALLOC-SIZE

CHDR-SIZE [[ 2 4* + ]] SIZE-ALIGN [[ u<= " bad sizes" not?error ]]
THRESHOLD SIZE-ALIGN [[ u>= " bad threshold" not?error ]]
HEAP-GROW PAGE-MASK [[ and " invalid HEAP-GROW" ?error ]]
MMAP-THRESHOLD SIZE-ALIGN [[ 2* - ]] HEAP-GROW [[ > " invalid HEAP-GROW" ?error ]]

;; number of pointers to free heap blocks.
;; when all free block pointers are used, free first
;; 3 blocks. reuse last added block in "grow-heap-mmap", if possible.
4 constant #FREE-HEAPS
0 quan free-heaps-used
create free-heaps #FREE-HEAPS [[ 4* ]] allot create;


;; each bin consists of head and "current" pointers. freed chunks appended to
;; the bin head, and "current" pointer is used to check for a free chunk.
;; "current" pointer is advanced in any case (even if we didn't used the chunk).
32 constant MAX-BINS
create bins MAX-BINS [[ 2* 4* ]] allot create;

0 variable used-bitmap

: (xbmp) ( bidx -- mask addr )  1 swap lshift used-bitmap ;
: used?  ( bidx -- flag )  (xbmp) @ mask? ;
: used!  ( bidx )          (xbmp) or! ;
: ~used  ( bidx )          (xbmp) ~and! ;

;; create accessor words
;; with our inliner they are basically zero-cost

;; chunk fields
: >psize  ;
: >csize  4+ ;
;; for free chunks
: >fprev  8 + ;
: >fnext  12 + ;

: cc>mem  8 + ;  ;; chunk address to malloced memory address
: mem>cc  8 - ;  ;; malloced memory address to chunk address

;; bin fields
: >bhead  ;
: >bcurr  4+ ;

: csize@  ( cc^ -- csize )  >csize @ FLAG-MASK ~and ;
: !csize  ( cc^ csize )     swap >csize ! ;
: !psize  ( cc^ psize )     swap >psize ! ;

: >prev-chunk  ( cc^ -- cc^ )  dup >psize @ - ;
: >next-chunk  ( cc^ -- cc^ )  dup csize@ + ;

: free?     ( cc^ -- flg )  >csize @ FREED mask? ;
: mmaped?   ( cc^ -- flg )  >csize @ MMAPED mask? ;
: released? ( cc^ -- flg )  >csize @ RELEASED mask? ;
: sentinel? ( cc^ -- flg )  >csize @ SENTINEL mask? ;

: >bin   ( bidx -- baddr^ )  8 * bins + ;
: >bidx  ( bin^ -- bidx )    bins - 8 u/ ;

: bcurr@ ( bin^ -- bcurr )  >bcurr @ ;
: bcurr! ( bcurr bin^ )     >bcurr ! ;
: bhead@ ( bin^ -- bhead )  >bhead @ ;
: bhead! ( bhead bin^ )     >bhead ! ;

: ^empty?  ( addr^ -- [addr^]=0 )  @ 0= ;

: mark-free    ( cc^ )  FREED swap >csize or! ;
: remove-flags ( cc^ )  >csize FLAG-MASK swap ~and! ;

|: stats-remove-chunk  ( cc^ )  csize@ stat-mem-allocated:-! ;
|: stats-add-chunk     ( cc^ )  csize@ stat-mem-allocated:+! ;


0 quan heap-start
0 quan heap-end

;; should be called on system startup
: initialize
  bins [ MAX-BINS 2* ] {#,} erase32
  free-heaps-used:!0
  used-bitmap !0 heap-start:!0 heap-end:!0
  stat-mem-allocated:!0 stat-heap-count:!0 stat-heap-mem-allocated:!0 ;


: find-used-bin  ( bidx -- idx )
  dup MAX-BINS < ?< 1 swap lshift 1- used-bitmap @ swap ~and ctz >? ;

;; calculate bin for the given *ALIGNED* size
: bin-index  ( sz -- binidx )
  16 u/ ( [ SIZE-ALIGN 16 = ] [IF] 16 u/ [ELSE] SIZE-ALIGN u/ [ENDIF] ) 1-
  dup 8 u<= ?exit 4 u/ 2-
  dup 8 u< ?exit< 8 + >? 16 u/
  dup 4 u< ?exit< 16 + >? 3 u/
  dup 4 u< ?exit< 18 + >? 3 u/ 2-
  dup 9 u< ?exit< 22 + >? drop 31 ;

: chunk-bin-index  ( cc^ -- binidx )  >csize @ bin-index ;

;; calculate aligned size
: align-size  ( sz -- sz TRUE // FALSE )
  dup MAX-ALLOC-SIZE u>
  ?exit< ?< false || SIZE-ALIGN true >? >?
  CHDR-SIZE + SIZE-MASK +  SIZE-MASK ~and true ;

;; should be called *AFTER* "align-size"
: align-size-mmap  ( sz -- sz TRUE // FALSE )
  PAGE-MASK + PAGE-MASK ~and dup -?< drop false || true >? ;


[[ MM-DEBUG MM-DEBUG-EXTRA or ]] [IF]
: dump-chunk  ( cc^ )
  ." CHUNK at $" dup .hex8
  ."  psize=" dup >psize @ .hex8
  ."  csize=" dup >csize @ .hex8
  ."  prev=$" dup >fprev @ .hex8
  ."  next=$" dup >fnext @ .hex8
  ."  bin=" chunk-bin-index 0.r cr ;

: dump-bin  ( bidx )
  dup used? not?<
    dup >bin >bhead @ ?< ." EMPTY BIN #" dup . ." has invalid head ($" dup >bin >bhead @ .hex8 ." )\n" >?
    dup >bin >bcurr @ ?< ." EMPTY BIN #" dup . ." has invalid curr ($" dup >bin >bcurr @ .hex8 ." )\n" >?
    drop exit
  >?
  ." BIN #" dup 0.r
  >bin ."  HEAD: $" dup >bhead @ .hex8 ."   CURR: $" dup >bcurr @ .hex8 cr
  >bhead @ << dup ?^| 2 bl #emit dup dump-chunk >fnext @ |? else| drop >> ;

: dump-bins
  ." heap start: $" heap-start .hex8 cr
  ."   heap end: $" heap-end .hex8 cr
  ." HEAD SENTINEL " heap-start dump-chunk
  ." TAIL SENTINEL " heap-end SIZE-ALIGN - dump-chunk
  0 << dup MAX-BINS = ?v| drop |?
       dup dump-bin 1+ ^|| >> ;

: dump-chunks  ( heap-start )
  dup not?exit< drop >?
  ." === CHUNKS ($" dup .hex8 ." ) ===\n"
  dup 2 bl #emit dump-chunk dup csize@ +  ;; skip first sentinel chunk
  << dup 2 bl #emit dump-chunk
     dup sentinel? not?^| dup csize@ + |?
  else| drop >> ;

<published-words>
: dump  dump-bins heap-start dump-chunks ;
<private-words>
[ENDIF]


: fix-bin-empty-curr  ( cc^ bin^ )  >bcurr dup @ not?< ! || 2drop >? ;
: set-bin-head  ( cc^ bin^ -- cc^ oldhead )  under >bhead dup @ nrot ! ;
: fix-chunk-ptrs  ( cc^ oldhead )  over >fprev !0  over >fnext over swap !
                                   dup ?< >fprev ! || 2drop >? ;
: insert-chunk^ ( cc^ bin^ )  2dup fix-bin-empty-curr set-bin-head fix-chunk-ptrs ;
: insert-chunk  ( cc^ bidx )  dup used! >bin insert-chunk^ ;

;; put free chunk into a bin (and force-set FREED flag)
: bin-chunk  ( cc^ )
  [ MM-DEBUG MM-DEBUG-EXTRA land ] [IF] ." BIN-" dup dump-chunk [ENDIF]
  dup mark-free dup chunk-bin-index insert-chunk ;

: advance^  ( bcurr^ )  dup ^empty? ?exit< drop >? dup @ >fnext @ swap ! ;
: fixcurr^  ( bin^ )  dup >bcurr ^empty? not?exit< drop >? dup bhead@ swap bcurr! ;
: advance   ( bin^ )  dup >bcurr advance^ fixcurr^ ;

;; advance "curr" if it points to the given chunk
: fix-unbin-curr  ( cc^ bin^ )
  2dup >bcurr @ = ?< advance drop || 2drop >? ;

: unbin-fixhead  ( cc^ bin^ )  over >fprev @ ?exit< 2drop >? >bhead swap >fnext @ swap ! ;
: unbin-fixcurr  ( cc^ bin^ -- was-adv? )  2dup bcurr@ <> ?exit< 2drop false >? advance drop true ;
: unbin-fixempty ( bin^ )  dup bhead@ ?exit< drop >? >bidx ~used ;

;; cc.prev.next = cc.next
: extract-fix-prev  ( cc^ )  dup >fprev @ dup not?exit< 2drop >? >fnext swap >fnext @ swap ! ;
;; cc.next.prev = cc.prev
: extract-fix-next  ( cc^ )  dup >fnext @ dup not?exit< 2drop >? >fprev swap >fprev @ swap ! ;
;; remove chunk from the free list
: extract-chunk  ( cc^ )  dup extract-fix-prev extract-fix-next ;

;; also, resets "FREE" flag
: unbin-chunk-was-adv?  ( cc^ )
  [ MM-DEBUG MM-DEBUG-EXTRA land ] [IF] ." 000: UNBIN-" dup dump-chunk ( dump-bins ) [ENDIF]
  dup chunk-bin-index >bin
  2dup unbin-fixhead 2dup unbin-fixcurr  >r  unbin-fixempty
  dup extract-chunk remove-flags  r>
  [ MM-DEBUG MM-DEBUG-EXTRA land ] [IF] ." 001: UNBIN\n" dump-bins [ENDIF] ;

: unbin-chunk  ( cc^ )  unbin-chunk-was-adv? drop ;

;; extract "curr" chunk from the bin
: get-bin-chunk  ( bidx -- cc^ )
  dup 0 MAX-BINS within not?error" invalid bin number"
  >bin  dup >r  >bcurr @ dup unbin-chunk-was-adv? ?exit< rdrop >?  r> advance ;

: can-split?  ( cc^ sz -- nextsz cantrim? )
  swap csize@ swap - dup 0< ?error" internal split error"
  dup THRESHOLD > ;

;; create new free chunk, and put it into the corresponding bin
: new-free-chunk-at  ( cc^ psize csize )
  >r 2dup !psize  drop r> 2dup !csize  drop bin-chunk ;

;; chunk must be already extracted from the bin, and must not be mmaped
;; sz must be properly aligned
;; result chunk "FREE" flag is reset
;; new free chunk is properly binned
: split  ( cc^ sz -- cc^ )
  2dup can-split? not?exit< 2drop dup remove-flags >?  ( cc^ sz nextsz )
  >r 2dup !csize  ( cc^ sz | nextsz )
  2dup + over r@ new-free-chunk-at
  over + r@ + r> !psize ;

;; join two chunks; both should be already extracted from their bins
;; joined chunk flags are reset
: join  ( cc^ cnext^ -- cc^ )
  dup csize@ + dup >r   ( cc^ cnn^ | cnn^ )
  over - >r             ( cc^ | cnn^ size )
  dup r@ !csize
  r> r> >psize ! ;

;; chunks must not be binned
;; result chunk "FREE" flag is undefined
;; result chunk is not binned
: merge-up  ( cc^ -- cc^ )
  dup >prev-chunk free? not?exit
  (*
  ." MERGE-UP: cc=$" dup .hex8 ."  prev=$" dup >prev-chunk .hex8
  ."  cc-size=" dup csize@ .
  ." prev-size=" dup >prev-chunk csize@ 0.r cr
  *)
  dup >prev-chunk dup unbin-chunk swap join ;

: merge-down  ( cc^ -- cc^ )
  dup >next-chunk free? not?exit
  (*
  ." MERGE-DOWN: cc=$" dup .hex8 ."  next=$" dup >next-chunk .hex8
  ."  cc-size=" dup csize@ 0.r ." (" dup >csize @ 0.r ." ) "
  ." next-size=" dup >next-chunk csize@ 0.r
  ." (" dup >next-chunk >csize @ 0.r ." )" cr
  \ dump abort
  *)
  dup >next-chunk dup unbin-chunk join ;

: mk-start-sentinel  ( ss^ )
  dup >psize !0 >csize  SIZE-ALIGN SENTINEL or  swap ! ;

: to-next-under  ( cc^ size -- next^ psize )  dup rot + swap ;

;; this also fixes next chunk psize
;; result chunk "FREE" flag is reset
: mk-main-chunk  ( cc^ size psize )
  >r over r> !psize  2dup !csize  to-next-under !psize ;

;; make end sentinel after "cc^"
: mk-end-sentinel  ( cc^ csize )
  to-next-under 2dup !psize  drop  SIZE-ALIGN SENTINEL or  !csize ;

: mk-lone-block  ( addr poolsz -- cc^ )
    \ endcr ." addr=$" over .hex8 ."  size=$" dup .hex8 cr
  over heap-start:! 2dup + heap-end:!
  over mk-start-sentinel
  SIZE-ALIGN 2* - swap SIZE-ALIGN + swap   ;; move to the main chunk
  2dup SIZE-ALIGN mk-main-chunk
  2dup mk-end-sentinel
  drop ;

;; try to get a free heap block from free block pool
: try-free-heap-block  ( -- addr TRUE // FALSE )
  free-heaps-used not?exit&leave
  free-heaps-used:1-!
  free-heaps-used free-heaps dd-nth @
  true ;

;; allocate new heap block via MMAP
;; returned "sz" should be the same as passed (it is used to split new chunk)
;; result chunk "FREE" flag is undefined
: grow-heap-mmap  ( sz -- cc^ sz TRUE // FALSE )
  try-free-heap-block not?<
    HEAP-GROW linux:prot-r/w linux:mmap not?exit< drop false >?
      \ endcr ." NEW HEAP BLOCK: $" dup .hex8 cr
    ;; statistics
    HEAP-GROW stat-heap-mem-allocated:+!
    stat-heap-count:1+! >?
  ( sz addr )
  HEAP-GROW mk-lone-block
    \ endcr ." lone-block-addr=$" dup .hex8 ."  size=" over 0.r cr
  swap true ;

;; returned "sz" should be the same as passed (it is used to split new chunk)
;; new chunk is not binned
;; result chunk "FREE" flag is undefined
: grow-heap  ( sz -- cc^ sz TRUE // FALSE )
  dup SIZE-ALIGN 2* +
  HEAP-GROW > ?error" invalid HEAP-GROW size"
  grow-heap-mmap ;

;; size must be already aligned with "align-size"
: malloc-mmap  ( sz -- maddr TRUE // FALSE )
  align-size-mmap not?exit&leave
  dup >r linux:prot-r/w linux:mmap not?exit< rdrop false >?
  dup >psize !0 r> MMAPED or over >csize ! cc>mem true ;

: free-heap-block?  ( cc^ -- flag )
  dup >prev-chunk sentinel? not?exit< drop false >?
  >next-chunk sentinel? ;

: return-heap-block  ( addr )
    \ endcr ." RETURNING HEAP BLOCK: $" dup .hex8 cr
  HEAP-GROW linux:munmap drop
  ;; statistics
  HEAP-GROW stat-heap-mem-allocated:-!
  stat-heap-count:1-!
  stat-heap-returned:1+! ;

;; return all heaps from the free list to the OS
: return-all-heaps
    \ endcr ." returning heaps (" free-heaps-used 0.r ." )\n"
  << free-heaps-used ?^|
       free-heaps-used:1-!
       free-heaps free-heaps-used dd-nth @ return-heap-block |?
  else| >> ;

;; cc^ should be the first chunk of the free block
: release-heap-block  ( cc^ )
  >prev-chunk
    \ endcr ." RELEASE HEAP BLOCK: $" dup .hex8 cr
  dup PAGE-MASK and ?error" internal dynmem error -- invalid heap address"
  AGGRESSIVE-BLOCK-RETURN ?exit< return-all-heaps return-heap-block >?
  free-heaps-used #FREE-HEAPS = ?< return-all-heaps >?
  free-heaps-used free-heaps dd-nth !
  free-heaps-used:1+! ;


{no-inline}
@: alloc  ( sz -- maddr TRUE // FALSE )
  [ MM-DEBUG MM-DEBUG-EXTRA lor ] [IF]
    endcr ." ***ALLOC: sz=" dup .
    dup align-size not?exit< drop ." OOPS!\n" >?
    ." newsz=" 0.r cr
  [ENDIF]
  align-size not?exit&leave
  dup MMAP-THRESHOLD u> ?exit< malloc-mmap >?
  dup >r bin-index dup used? ?< dup >bin >bcurr @ ( bidx cc^ | sz )
    dup csize@ r@ - THRESHOLD u<=
    ?< rdrop dup unbin-chunk-was-adv? ?< swap >bin advance || nip >?
    || ;; we can safely split this chunk
      swap >bin advance ( cc^ | sz )
      dup unbin-chunk r> split >?
    dup stats-add-chunk
    cc>mem true exit
  >? ( bidx | sz )
  1+ find-used-bin dup MAX-BINS <
  ?< get-bin-chunk r> true || drop r> grow-heap >?
  dup not?exit drop split
  dup stats-add-chunk
  cc>mem true ;

@: ?alloc  ( sz -- maddr )  alloc not?error" out of memory" ;

@: zalloc  ( sz -- maddr TRUE // FALSE )
  dup alloc not?exit< drop false >?
  ( sz maddr )
  dup rot erase true ;

@: ?zalloc  ( sz -- maddr )  zalloc not?error" out of memory" ;


[[ tgt-dynalloc-guards ]] [IF]
: report-insane-chunk  ( cc^ )
  ." insane chunk $" dup .hex8
  ."  (size:" dup >csize @ 0.r ." )"
  cr ;

: ?sane-chunk  ( cc^ )
  dup >csize @
  dup SIZE-ALIGN u< ?< ." DYNMEM: trying to free " drop report-insane-chunk abort >?
  dup MAX-ALLOC-SIZE u> ?< ." DYNMEM: trying to free " drop report-insane-chunk abort >?
  dup FREED and ?< ." DYNMEM: (FREED) trying to free " drop report-insane-chunk abort >?
  dup SENTINEL and ?< ." DYNMEM: (SENTINEL) trying to free " drop report-insane-chunk abort >?
  drop dup >psize @
  dup FLAG-MASK and ?< ." DYNMEM: (PSIZE) trying to free " drop report-insane-chunk abort >?
  2drop ;
[ENDIF]

{no-inline}
@: free  ( maddr )
  dup not?exit< drop >? mem>cc
  [ tgt-dynalloc-guards ] [IF] dup ?sane-chunk [ENDIF]
  dup stats-remove-chunk
  dup mmaped? ?exit< dup csize@ linux:munmap drop >?
  merge-up merge-down
  dup free-heap-block? not?exit< bin-chunk >?
  release-heap-block ;

;; WARNING! this *CANNOT* be used to check if "maddr" is valid!
@: size@  ( maddr -- size )  dup not?exit mem>cc csize@ CHDR-SIZE - ;


<private-words>

: chunk-copy  ( cc^ ccsz newcc^ )
  CHDR-SIZE + rot CHDR-SIZE + swap rot CHDR-SIZE - move ;

: alloc-copy-free  ( cc^ sz -- newcc^ TRUE // cc^ FALSE )
  alloc not?exit< dup stats-add-chunk false >?  ;; fix stats
  mem>cc  ( cc^ newcc^ )
  >r dup dup csize@ r@ chunk-copy  cc>mem free r> true ;

: realloc-mmap  ( cc^ sz -- newcc^ TRUE // cc^ FALSE )
  align-size-mmap not?exit&leave
  over csize@ over = ?exit< drop true >?
  dup MMAP-THRESHOLD 2 u/ u< ?< dup >r alloc-copy-free ?exit< rdrop true >? r> >?
  2dup 2>r  over csize@ swap linux:mremap not?exit< rdrop r> false >?
  dup r> MMAPED or !csize rdrop true ;

: +free-csize  ( csize cc^ )  dup free? ?< csize@ + || drop >? ;

: calc-join-size  ( cc^ -- totalsize )
  dup >r csize@  r@ >prev-chunk +free-csize  r> >next-chunk +free-csize ;

: realloc-join  ( cc^ sz -- newcc^ TRUE )
  over merge-up merge-down >r  2dup r@ chunk-copy  nip r> swap split true ;

: join-next  ( cc^ )
  >next-chunk dup free? not?exit< drop >?
  dup >next-chunk free? not?exit< drop >?
  dup unbin-chunk merge-down bin-chunk ;

: realloc-norm  ( cc^ sz -- newcc^ TRUE // cc^ FALSE )
  over csize@ over = ?exit< drop true >?
  over stats-remove-chunk
  over csize@ over u> ?exit< split dup join-next  dup stats-remove-chunk  true >?
  over calc-join-size over u>= ?exit< realloc-join over remove-flags >?
  alloc-copy-free ;

\ TODO: this doesn't track allocation statistics yet!
;; on failure, return original "maddr"
;; WARNING! passing 0 size WILL NOT free the memory!
{no-inline}
@: realloc  ( maddr sz -- maddr TRUE // maddr FALSE )
  over not?exit< alloc dup not?< 0 >? >? swap mem>cc swap
  align-size not?exit< cc>mem false >?
  [ tgt-dynalloc-guards ] [IF] over ?sane-chunk [ENDIF]
  over mmaped? ?< realloc-mmap || realloc-norm >?  swap cc>mem swap ;

@: ?realloc  ( maddr sz -- maddr )  realloc not?error" out of memory " ;

\ initialize
seal-module
end-module DYNMEM
