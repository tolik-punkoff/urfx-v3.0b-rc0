;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; startup
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


true quan (START-BANNER)
true quan (BYE-REPORT)

1 quan (ARGOFS) (private)

\ : #ARG  ( -- n )  (#arg) @ (argofs) - 0 max ;
: ARGV# ( -- n )  (#arg) @ (argofs) - 0 max ;
\ [[ x86-disasm-last bye ]]

: ARGV@  ( idx -- addr count )
  dup 0 argv# within ?< (argofs) + 4* (argv) @ + @ zcount || drop pad 0 >? ;


extend-module SYSTEM
: SYS-RESET
  state:!0 system:Succubus-noinline-mark:!0
  ws-vocab-cfa:!0 default-ffa !0
  \ ['] debug:.idfull system:peephole:(opt-.idfull):!
  Succubus:sys-reset
  parnas-support:sys-reset
  loops-sys-reset
  ['] redefine-checker redefine-check:! ;

: TIB-SYS-RESET
  pad (* (expect-buf) @ *) tib:! #tib:!0 >in:!0
  allow-refill?:!f interpret-hooks:repl?:!f ;
end-module SYSTEM

;; called on system startup, and on error
chained (ON-RESET-SYSTEM)

;; this is called on startup, and on error.
;; call it via "(sys-reset-cfa^) @execute".
{no-inline}
|: (RESET-SYSTEM)
  (user-reset)
  (sp0!)
  r> (rp0!) >r
  vocid: forth dup current! context!
  decimal
  vsp0! nsp0! lsp0!
  ws-vocab-cfa:!0 ws-vocid-hit:!0
  (this):!0 (excf):!0
  system:sys-reset system:tib-sys-reset
  setup-raw-output
  (segfault):setup-handlers
  includer:close-all
  ['] .inc-pos (segfault):(.inc-pos) ! (inc-setup-compiler-fref)
  callback:free-all-stacks
  [ tgt-build-base-binary ] [IFNOT] fpu-reset [ENDIF]

  [ ll@ xccx ] {#,}  [ ll@ xcce ] {#,} [ ll@ xccx ] {#,} - string:joaat-2x
  \ [ 0 ] [IF] endcr ." SUM1: $" dup .hex8 ."  $" over .hex8 cr [ENDIF]
  ;; two, for dynamic and for static
  2dup $5D2D8405 - swap $12789B40 - or 0?< 2drop
  || $67A06DF5 - swap $68966649 - or ?< endcr ." FATAL: system corrupted.\n" 1 (nbye) >? >?

  [ ll@ xccs1 ] {#,}  [ ll@ xcce1 ] {#,} [ ll@ xccs1 ] {#,} - string:joaat-2x
  [ 0 ] [IF] endcr ." SUM2: $" dup .hex8 ."  $" over .hex8 cr [ENDIF]
  ;; two, for dynamic and for static
  2dup $32B1B4AA - swap $2935F32D - or 0?< 2drop
  || $E92936AE - swap $50750921 - or ?< endcr ." FATAL: system corrupted2.\n" 1 (nbye) >? >?

  (on-reset-system) ?< endcr ." FATAL: system reset hook failed!\n" 1 (nbye) >? ;
\ [[ x86-disasm-last bye ]]


;; called on exit (even via "BYE")
chained (ON-FINISH)

{no-inline}
|: (FINISH)
  (on-finish) not?<
    [ tgt-build-base-binary ] [IFNOT]
    (bye-report) ?<
      linux:is-tty? ?< linux:tty-restore ." \x1b[m" >?
      depth dup ?< dup endcr ." Beast: stack depth: " 0.r cr >r debug:.s r> cr >? drop
      debug:.hashstats
      endcr ." Beast: image used: " code-dict-used ., ." code bytes, "
      hdr-dict-used ., ." header bytes.\n" >?
    [ENDIF]
  >? (bye) ;


{no-inline}
: .BUILD-TIME
  (build-ts-utc-strz^) zcount
  ." build time (UTC): " type cr ;

{no-inline}
: .BANNER
  ." UrForth/Beast (Devastator), written by Ketmar Dark. see LICENSE.txt.\n"
  .build-time
  system:#default-inline-bytes ?<
    ." Succubus: inliner "
    system:Succubus:disable-aggressive-inliner
    ?< ." dis" || ." en" >? ." abled, "
    ." Forth inliner "
    system:Succubus:allow-forth-inlining-analysis
    ?< ." en" || ." dis" >? ." abled ("
    system:#default-inline-bytes ., ." bytes).\n"
  >? ;

[[ tgt-build-base-binary ]] [IF]
: quit  ." usage: urbforth-base.elf urb-main.f\n" ;
[ENDIF]

{no-inline}
|: (RUN-MAIN)
  (argofs):!1
  ['] (finish) (bye^) !
  (#arg) @ 2 < ?< (argofs):!1 (start-banner) ?< .banner >? quit bye >?
  2 (argofs):!
  (argv) @ 4+ @ zcount false (include)
  interpret
  (finish) (bye) ;

['] (run-main) quan (MAIN) (private)

;; set new main word (used in saved images)
: MAIN!  ( cfa )  (main):! ;


{no-inline}
|: (COLD)
  [ tgt-build-base-binary ] [IFNOT] fpu-reset [ENDIF]
  ['] inc-line# system:(include-line#):!
  ['] inc-fname system:(include-fname):!
  string::(binpath):!0
  dynmem:initialize
  includer:reinit ( reset includer after "save")
  system:initial-cg-setup
  callback:initialise
  [ tgt-build-base-binary ] [IFNOT]
    (save-image-headers?) 0<> debug:named-backtrace?:!
  [ELSE] debug:named-backtrace?:!t [ENDIF]
  [ tgt-build-base-binary ] [IFNOT]
    ['] flt-parse:(bad-float) flt-parse:bad-float:!
  [ENDIF]
  (reset-system) (* (cold-init) *)
  (main) ['] abort main! execute abort ;

[[ tgt-build-base-binary ]] [IFNOT]
: SAVE-DEFAULT-IMAGE  ( addr count )
  ['] (run-main) main! save-image ;
[ENDIF]
