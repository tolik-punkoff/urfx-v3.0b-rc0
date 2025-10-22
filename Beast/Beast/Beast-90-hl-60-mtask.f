;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; multitasking support
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
example:

: xtask  ( oldtask )
  ." hi! i am a new task! old is: $" dup .hex8 cr
  mtask:switch
  ." more new task work... old is: $" dup .hex8 cr
  ." number: " 666 0.r cr
  mtask:switch
  bye ;

mtask:alloc quan ntask -- allocate task state, but nothing more
-- here, you can use "8192 ntask mtask:dsize!", for example
['] xtask ntask mtask:prepare -- allocate stacks, set run word (it must be in Forth!)

hex
ntask mtask:switch
." hello again! xtask: $" .hex8 cr
ntask mtask:switch
." i'm done. xtask: $" .hex8 cr
decimal

." freeing task $" ntask .hex8 cr
ntask mtask:free
." done.\n"
*)

module MTASK
<disable-hash>

code: MY-TID  ( -- taddr )
  upush utos
  mov   utos, uadr
;code

: UV@  ( uvar-cfa taddr -- value )  swap system:uvar-ofs + @ ;
: UV!  ( value uvar-cfa taddr )  swap system:uvar-ofs + ! ;

;; crude check
: READY?  ( taddr -- flag )  ['] (sp-start^) swap uv@ 0<> ;
: ?UNREADY  ( taddr )  ready? ?error" cannot change ready state" ;
: ?GOOD-SIZE  ( size )  1 $10_0001 within not?error" bad size" ;
: ?NOT-ACTIVE  ( taddr ) my-tid = ?error" cannot modify active task" ;

|: (ALIGN-PAGE)  ( size -- size )  4095 + 4095 ~and ;

|: X-ALLOC  ( size -- addr )
  dup 0<= ?error" bad size" (align-page) 8192 + dup >r
  linux:prot-r/w linux:mmap not?error" out of memory for new task state"
  ;; mark guard pages
  dup 4096 linux:prot-none linux:mprotect ?error" cannot mark first guard page"
  dup r> + 4096 - 4096 linux:prot-none linux:mprotect ?error" cannot mark last guard page"
  4096 + ;

|: X-FREE  ( addr size )
  dup 0<= ?error" bad size" (align-page) 8192 +
  swap 4096 - swap linux:munmap ?error" cannot free task memory" ;

;; stack info: size, start, stk0
|: SET-STK0-E  ( ssize-uvar-cfa taddr )
  swap system:uvar-ofs + ( uvs-addr )
  @++ swap @++ rot + swap ! ;

|: XPUSH  ( value stkptr )  dup 4-! @ ! ;
|: XPOP  ( stkptr -- value )  dup @ @ swap 4+! ;

|: .TUVAR  ( uvar-cfa taddr )
  swap system:uvar-ofs
  ." : (" dup 3 .r ." ): $"
  + @ .hex8 cr ;

: DUMP-TASK  ( taddr )
  ." === TASK: $" dup .hex8 ."  ===\n"
  >r ." (sp-saved)" ['] (sp-saved) r@ .tuvar
     ." (rp-saved)" ['] (rp-saved) r@ .tuvar
     ."      (lsp)" ['] (lsp) r@ .tuvar
     ."      (vsp)" ['] (vsp) r@ .tuvar
     ."      (nsp)" ['] (nsp) r@ .tuvar
     ."  (#dstack)" ['] (#dstack-bytes) r@ .tuvar
     ." (sp-start)" ['] (sp-start^) r@ .tuvar
     ."     (sp0^)" ['] (sp0^) r@ .tuvar
     ."  (#rstack)" ['] (#rstack-bytes) r@ .tuvar
     ." (rp-start)" ['] (rp-start^) r@ .tuvar
     ."     (rp0^)" ['] (rp0^) r@ .tuvar
     ."  (#vstack)" ['] (#vstack-bytes) r@ .tuvar
     ." (vp-start)" ['] (vp-start) r@ .tuvar
     ."  (#nstack)" ['] (#nstack-bytes) r@ .tuvar
     ." (np-start)" ['] (np-start) r@ .tuvar
     ."  (#lstack)" ['] (#lstack-bytes) r@ .tuvar
     ." (lp-start)" ['] (lp-start) r@ .tuvar
     ."  (#padbuf)" ['] (#padbuf) r@ .tuvar
     ." (padstart)" ['] (pad-start) r@ .tuvar
     ."       base" ['] base r@ .tuvar
     ."    current" ['] current r@ .tuvar
     ."    context" ['] context r@ .tuvar
  rdrop ;


<published-words>
: RESET  ( taddr )
  >r ['] (#dstack-bytes) r@ set-stk0-e ['] (#rstack-bytes) r@ set-stk0-e
  ['] (sp0^) r@ uv@ ['] (sp-saved) r@ uv!
  ['] (rp0^) r@ uv@ ['] (rp-saved) r@ uv!
  ['] (vp-start) r@ uv@ 4- ['] (vsp) r@ uv!
  ['] (np-start) r@ uv@ 4- ['] (nsp) r@ uv!
  ['] (lp-start) r@ uv@ ['] (lsp) r@ uv!
  10 ['] base r@ uv!
  vocid: forth dup ['] current r@ uv! ['] context r@ uv!
  0 ['] (self) r@ uv! 0 ['] (excf) r@ uv!
  rdrop ;

\ : R-RESET  ( taddr )  >r ['] (rp0^) r@ uv@ ['] (rp-saved) r> uv! ;

: RPUSH  ( value taddr )
  swap system:r-fix swap
  ['] (rp-saved) system:uvar-ofs + xpush ;

: RPOP  ( taddr -- value )
  ['] (rp-saved) system:uvar-ofs + xpop
  system:r-unfix ;

: DPUSH  ( value taddr )
  ['] (sp-saved) system:uvar-ofs + xpush ;

: DPOP  ( taddr -- value )
  ['] (sp-saved) system:uvar-ofs + xpop ;

|: (XSIZE!)  ( size taddr uvar-cfa )
  >r dup ?unready over ?good-size swap (align-page) r> rot uv! ;

|: (XSIZEX!)  ( size taddr uvar-cfa )
  >r dup ?unready over ?good-size swap 3 + 3 ~and r> rot uv! ;

: DSIZE!  ( size taddr )  ['] (#dstack-bytes) (xsize!) ; -- set data stack size
: RSIZE!  ( size taddr )  ['] (#rstack-bytes) (xsize!) ; -- set return stack size
: VSIZE!  ( size taddr )  ['] (#vstack-bytes) (xsizex!) ; -- set context stack size
: NSIZE!  ( size taddr )  ['] (#nstack-bytes) (xsizex!) ; -- set current stack size
: LSIZE!  ( size taddr )  ['] (#lstack-bytes) (xsize!) ; -- set locals stack size
: PADSIZE!  ( size taddr )  ['] (#padbuf) (xsize!) ; -- set pad size

: DSIZE@  ( taddr -- size )  ['] (#dstack-bytes) swap uv@ (align-page) ; -- get data stack size
: RSIZE@  ( taddr -- size )  ['] (#rstack-bytes) swap uv@ (align-page) ; -- get return stack size
: VSIZE@  ( taddr -- size )  ['] (#vstack-bytes) swap uv@ 3 + 3 ~and ; -- get context stack size
: NSIZE@  ( taddr -- size )  ['] (#nstack-bytes) swap uv@ 3 + 3 ~and ; -- get current stack size
: LSIZE@  ( taddr -- size )  ['] (#lstack-bytes) swap uv@ (align-page) ; -- get locals stack size
: PADSIZE@  ( taddr -- size )  ['] (#padbuf) swap uv@ (align-page) ; -- get pad size

;; allocate user data area, prepare it, but don't allocate anything else
: ALLOC  ( -- taddr )
  (#user-max) x-alloc >r
  r@ (#user-max) erase -- just in case
  4096 r@ dsize! 4096 r@ rsize!
  4096 r@ vsize! 4096 r@ nsize! 4096 r@ lsize!
  4096 r@ padsize! r> ;

|: (CALC-MEM-SIZE)  ( taddr -- size )
  >r 0 r@ dsize@ (align-page) + r@ rsize@ (align-page) +
  r@ vsize@ r@ nsize@ + (align-page) + r@ lsize@ (align-page) +
  r@ padsize@ (align-page) + rdrop
  4 4096 * + ( guard pages ) ;

;; vars should be in this order: size, start
;; also, marks guard page
|: (SET-ADVANCE)  ( xaddr sz-uvar-cfa taddr -- next-xaddr )
  swap system:uvar-ofs + swap >r  ( szaddr | xaddr )
  @++ (align-page) swap  ( size staddr | xaddr )
  r@ swap !  ( size | xaddr )
  +r!       ( | xaddr )
  r@ 4096 linux:prot-none linux:mprotect ?error" cannot mark guard page"
  r> 4096 + ;

;; make it ready (i.e. allocate all the memory).
;; this allocates the memory as one chunk, with guard pages inserted inbetween.
;; then it marks guard pages as "no access" with "mprotect".
;; this way those pages will not be reused by the system.
: PREPARE  ( runcfa taddr -- )
  over system:forth? not?error" forth word expected"
  dup ?unready 2>r
  r@ (calc-mem-size) x-alloc  ( xaddr | taddr )
  ['] (#dstack-bytes) r@ (set-advance)
  ['] (#rstack-bytes) r@ (set-advance)
  \ ['] (#vstack) r@ (set-advance)
  \ ['] (#nstack) r@ (set-advance)
  dup ['] (vp-start) r@ uv!
  dup ['] (#vstack-bytes) r@ uv@ 3 + 3 ~and + ['] (np-start) r@ uv!
  ['] (#vstack-bytes) r@ uv@ ['] (#nstack-bytes) r@ uv@ + (align-page) +
  dup 4096 linux:prot-none linux:mprotect ?error" cannot mark guard page" 4096 +
  ['] (#lstack-bytes) r@ (set-advance)
  ['] (#padbuf) r@ (set-advance)
  drop r@ reset
  r> r> dart:cfa>pfa swap rpush ;

: FREE  ( taddr )
  dup ?not-active
  >r ['] (sp-start^) r@ uv@ dup ?< r@ (calc-mem-size) x-free || drop >?
  r> (#user-max) x-free ;

code-noadv: SWITCH  ( mtbuf-new -- prevtask-uarea )
  urpush uip
  ;; save stack pointers
  mov   [uadr+] uofs@ (saved-sp^) #, usp
  mov   [uadr+] uofs@ (saved-rp^) #, urp
  \ mov   [uadr+] uofs@ (switched-from^) #, utos
  ;; switch to the new task
  \ fuckin' fuck86 has FUCKIN' SLOW xchg! wuta...
  \ xchg  utos, uadr
  mov   eax, utos
  mov   utos, uadr
  mov   uadr, eax
  ;; restore stack pointers
  mov   usp, [uadr+] uofs@ (saved-sp^) #
  mov   urp, [uadr+] uofs@ (saved-rp^) #
  urpop uip
  beast-advuip
;code

end-module MTASK
