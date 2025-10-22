;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
registers:
  HL -- TOS
  IY -- return stack pointer

  note that this scheme requires custom interrupt handler.
*)

(START-BANNER):!f
(BYE-REPORT):!f


inc-fname string:extract-path string:$new constant self-path
\ self-path count type cr

$use <zxasm>
$use <z80dis>

;; use unrolled code to gain more speed?
;; costs ~108 bytes
true quan OPT-16BIT-MUL/DIV-UNROLLED?

;; number of bytes reserved for return stack
160 quan OPT-RSTACK-BYTES

;; allow Forth word inlining?
true quan OPT-ALLOW-INLINING?

;; assume that return stack is always aligned at 2 bytes
true quan OPT-RSTACK-ALWAYS-ALIGNED?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; more options!

;; base address for the new system; can start from $6000
$8000 quan OPT-BASE-ADDRESS

;; do not use UDG area for stacks? (i.e. is the program uses UDG graphics?
\ false quan OPT-USE-UDG?

;; setup BASIC errors handler?
;; most of the time we don't need it.
false quan OPT-BASIC-ERR-HANDLER?

;; use simplified IM handler instead of the ROM one.
;; it increments only 2 bytes of FRAMES, and uses
;; simplified keyboard scan with basic key translation
;; (no lo-case letters, for example).
;; most of the time it is enough, tho.
;; but note that +3DOS requires the full handler.
false quan OPT-SIMPLIFIED-IM?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; turnkey control

0 quan OPT-TURNKEY-PASS

false quan OPT-TURNKEY-DEBUG?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; debug options

true quan OPT-OPTIMIZE-PEEPHOLE?
false quan OPT-DEBUG-PEEPHOLE?

true quan OPT-OPTIMIZE-SUPER?
true quan OPT-OPTIMIZE-BRANCHES?
false quan OPT-OPTIMIZE-SUPER-MSG?
false quan OPT-OPTIMIZE-BRANCHES-MSG?

false quan OPT-DISASM-P1?
false quan OPT-DISASM-P2?

false quan OPT-DUMP-CGEN-IR-NODES-PRE?
false quan OPT-DUMP-CGEN-IR-NODES?
false quan OPT-DUMP-IR-OPTIM-CALLS?

;; do not try to skip empty bytes and write several code files?
true quan OPT-WRITE-ONE-CODE-FILE?


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLI arguments parsing

: TURNKEY?        OPT-TURNKEY-PASS 0> ;
: TURNKEY-PASS1?  OPT-TURNKEY-PASS 1 = ;
: TURNKEY-PASS2?  OPT-TURNKEY-PASS 2 = ;

: COMPILING-FOR-REAL?  turnkey-pass2? ;


$use <getarg>

;; this is used to define zx library options. the idea is that you do:
;;    false zx-lib-option OPT-SPRX-OR-MODE?
;; then
;;    $zx-use <laser-spr>
;; see the corresponding library source code for the list of options

*: zx-lib-option  ( default-value )  \ name
  system:?exec
  >in >r
  parse-name find ?exit< rdrop 2drop >?
  r> >in:!
  push-cur
  vocid: forth current!
  quan
  pop-cur ;


false quan zx-use-verbose?
0 quan main-path  ;; dynalloced
0 quan apps-path  ;; dynalloced
0 quan zxlibs-path  ;; dynalloced

|: norm-path  ( addr count -- addr count )
  << dup 0?v|| 2dup + 1- c@ [char] / = 0?v|| 1- ^|| >> ;

|: set-apps-path  ( addr count )
  norm-path
  dup 0?error" invalid apps path!"
  apps-path string:$free
  string:$new apps-path:! ;

|: get-apps-path  ( -- addr count )
  apps-path dup 0?exit< drop " apps" >?
  count ;

|: set-zxlibs-path  ( addr count )
  norm-path
  dup 0?error" invalid zxlibs path!"
  zxlibs-path string:$free
  string:$new zxlibs-path:! ;

|: get-zxlibs-path  ( -- addr count )
  zxlibs-path dup 0?exit< drop " zxlibs" >?
  count ;

|: set-main-path
  inc-fname string:extract-path dup not?< 2drop " ./" >?
  string:$new main-path:! ;
set-main-path

|: mk-zx-sys-inc-name  ( addr count -- addr count )
  dup 0< ?error" invalid zx library name"
  over c@ string:path-delim? ?exit
  " ZXLIB_INCLUDE_DIR" string:getenv ?<
    dup not?< 2drop " ./" >?
    pad$:! pad$:@ string:end-delim?
    not?< [char] / pad$:c+ >?
  || main-path count pad$:!
     get-zxlibs-path pad$:+ [char] / pad$:c+ >?
  pad$:+ pad$:@ ;

;; should be called in zx application code
*: $zx-use
  system:?exec includer:parse-fname
  >r
  2dup pad$:! r@ ?< " \x01ZX" || " \x02ZX" >? pad$:+
  pad$:@ includer:(used?) ?exit< rdrop 2drop >?
  pad$:@ includer:(new-used)
  \ 2dup includer:(used?) ?exit< rdrop 2drop >? 2dup includer:(new-used)
    zx-use-verbose? ?<
      endcr ." loading ZX library " r@ ?< [char] < || [char] " >? emit
       2dup type r@ ?< [char] > || [char] " >? emit >?
  r> ?< mk-zx-sys-inc-name || includer:mk-inc-name >? includer:check-dir
    zx-use-verbose? ?< ."  from '" 2dup type ." '...\n" >?
  includer:setup-reader includer:open ;


struct:new extra-file
  field: disk$  ;; dynstr -- virtual disk name
  field: fname$ ;; dynstr -- file name
  field: next
end-struct

0 quan extra-files-head
0 quan extra-files-tail

|: append-extra-file  ( fname$ dname$ )
  \ string:$new nrot string:$new
  swap ( disk$ fname$ )
  extra-file:@size-of n-allot
  ( disk$ fname$ struct )
  dup >r extra-file:fname$:!  r@ extra-file:disk$:!
  r@ extra-file:next:!0
  extra-files-head 0?< r@ extra-files-head:!
  || r@ extra-files-tail extra-file:next:! >?
  r> extra-files-tail:! ;


0 quan output-file-name ;; dynalloced
0 quan app-name         ;; dynalloced
0 quan app-dir-name     ;; dynalloced
0 quan app-opt-fname    ;; dynalloced
0 quan app-zxmain-fname ;; dynalloced
0 quan app-tktemp-fname ;; dynalloced
0 quan cargador-name    ;; dynalloced

|: set-output-fname  ( addr count )
  output-file-name ?error" too many output files"
  string:$new output-file-name:! ;

: DISK-OUTPUT?  ( -- flag )
  output-file-name count
  string:extract-ext " .dsk" string:=ci ;

: TAPE-OUTPUT?  ( -- flag )
  DISK-OUTPUT? not ;


|: set-app-name  ( addr count )
  app-name ?error" application already specified"
  string:$new app-name:!
  ;; build dir name
  get-apps-path pad$:! [char] / pad$:c+
  app-name count pad$:+
  pad$:@ string:$new app-dir-name:!
  ;; build opt name
  app-dir-name count pad$:!
  " /00-urfx-user-options.f" pad$:+
  pad$:@ string:$new app-opt-fname:!
  ;; build zxmain name
  app-dir-name count pad$:!
  " /zx-main.f" pad$:+
  pad$:@ string:$new app-zxmain-fname:!
  ;; temporary file
  ;; FIXME: generate random name?
  app-dir-name count pad$:!
  " /$$$TK-TEMP$$$" pad$:+
  pad$:@ string:$new app-tktemp-fname:! ;

|: set-cargador-name  ( addr count )
  dup 0 11 within not?error" invalid cargador name"
  cargador-name string:$free
  string:$new cargador-name:! ;


getarg:arg: --output  " file name?" getarg:next-arg set-output-fname ;
1 getarg:last-need-#args
getarg:help: ." output tape file (default is \'tap/aforth.tap\')" ;
getarg:last-alias: -o

getarg:arg: --app  " app name?" getarg:next-arg set-app-name ;
getarg:help: ." application to compile" ;

getarg:arg: --apps-path  " apps path?" getarg:next-arg set-apps-path ;
getarg:help: ." set path to apps directory (w/o the final slash)" ;

getarg:arg: --zxlibs-path  " zxlibs path?" getarg:next-arg set-zxlibs-path ;
getarg:help: ." set path to zxlibs directory (w/o the final slash)" ;

getarg:arg: --cargador  " loader name?" getarg:next-arg set-cargador-name ;
getarg:help: ." set the name of the main loader" ;

getarg:arg: --file
  " source file name?" getarg:next-arg string:$new \ endcr dup count type cr
  " dest file name?" getarg:next-arg string:$new \ endcr dup count type cr
  append-extra-file ;
getarg:help: ." append extra files to tape/disk: --file source-name dest-name" ;
2 getarg:last-need-#args


getarg:arg: --turnkey-pass1 1 OPT-TURNKEY-PASS:! ;
getarg:help: ." compile code, trace words, write result to intermediate file" ;
getarg:arg: --turnkey-pass2 2 OPT-TURNKEY-PASS:! ;
getarg:help: ." use the result of the first pass to compile final code" ;


getarg:arg: -O0  OPT-OPTIMIZE-SUPER?:!f OPT-OPTIMIZE-BRANCHES?:!f ;
getarg:help: ." turn off all optimisations" ;
getarg:arg: -O1  OPT-OPTIMIZE-SUPER?:!f OPT-OPTIMIZE-BRANCHES?:!t ;
getarg:help: ." turn on branch optimisations" ;
getarg:arg: -O2  OPT-OPTIMIZE-SUPER?:!t OPT-OPTIMIZE-BRANCHES?:!f ;
getarg:help: ." turn on superinstruction optimisations" ;
getarg:arg: -O3  OPT-OPTIMIZE-SUPER?:!t OPT-OPTIMIZE-BRANCHES?:!t ;
getarg:help: ." turn on branch and superinstruction optimisations (default)" ;

getarg:arg: -Wsuper  OPT-OPTIMIZE-SUPER-MSG?:!t ;
getarg:help: ." turn on superinstruction optimisation messages" ;
getarg:arg: -Wbranch  OPT-OPTIMIZE-BRANCHES-MSG?:!t ;
getarg:help: ." turn on branch optimisation messages" ;
getarg:arg: -Wall  OPT-OPTIMIZE-BRANCHES-MSG?:!t OPT-OPTIMIZE-SUPER-MSG?:!t ;
getarg:help: ." turn on all optimisation messages" ;

" inliner control" getarg:enable/disable-arg: OPT-ALLOW-INLINING? inline
" peephole optimisations" getarg:enable/disable-arg: OPT-OPTIMIZE-PEEPHOLE? peephole

;; hidden options
0 getarg:enable/disable-arg: OPT-TURNKEY-DEBUG? turnkey-debug
0 getarg:enable/disable-arg: OPT-DISASM-P1? disasm-p1
0 getarg:enable/disable-arg: OPT-DISASM-P2? disasm-p2

0 getarg:enable/disable-arg: OPT-DEBUG-PEEPHOLE? peephole-debug

0 getarg:enable/disable-arg: OPT-DUMP-CGEN-IR-NODES-PRE? dump-nodes-pre
0 getarg:enable/disable-arg: OPT-DUMP-CGEN-IR-NODES? dump-nodes

0 getarg:enable/disable-arg: OPT-DUMP-IR-OPTIM-CALLS? dump-ir-optim-calls

0 getarg:enable/disable-arg: OPT-WRITE-ONE-CODE-FILE? one-code-file


getarg:usage:  ." urforth urfx-main.f [args]\nargs:\n" ;
getarg:parse-args


TURNKEY? [IFNOT]
encdr ." MESSAGE: please, use '--turnkey-pass1', and then '--turnkey-pass2'!"
(sp0!) bye
[ENDIF]


app-dir-name [IF]
: check-app-dir
  app-zxmain-fname count false (include-exist?) not?error" no app found!"
  ." compiling application '" app-name count type ." '\n" ;
check-app-dir
app-opt-fname count false (soft-include)
[ELSE]
  " cannot create turnkey application without an application!" error
[ENDIF]


output-file-name [IFNOT]
" tap/aforth.tap" set-output-fname
[ENDIF]


OPT-TURNKEY-DEBUG? [IF] z80-labman:enable-wipe-debug [ENDIF]


: on/off.  ( flag )  ?< ." en" || ." dis" >? ." abled" ;

: opt.  ( addr count flag )  >r type ." : " r> on/off. ;

: options.
  endcr
  turnkey-pass1? ?exit
  ." build options:\n"
   "   inliner" OPT-ALLOW-INLINING? opt. cr
   "   branch optimiser" OPT-OPTIMIZE-BRANCHES? opt. cr
   "   IR optimiser" OPT-OPTIMIZE-SUPER? opt. cr
   "   peephole optimiser" OPT-OPTIMIZE-PEEPHOLE? opt. cr
;
options.


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main code

;; define some constants
module TCOM
;; base address for the new system
\ $6000 quan zx-base-addr
OPT-BASE-ADDRESS $6000 $F000 bounds [IFNOT]
" invalid base address" error
[ENDIF]
OPT-BASE-ADDRESS quan zx-base-addr

true quan TCX-ONLY-OPTION-LOADER?

;; set on the first pass
0 quan zx-init-code-size


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; host shadow dictionaries

module FORTH-SHADOWS
<separate-hash>
end-module

module SYSTEM-SHADOWS
<separate-hash>
end-module

end-module TCOM


turnkey-pass2? [IF]
  ;; for custom loader
  -1 quan tap-fd

  output-file-name count
  string:extract-ext " .pzx" string:=ci [IF]
    zxa:tap:fmt-pzx
  [ELSE]
    zxa:tap:fmt-tap
  [ENDIF]
  zxa:tap:tape-format:!

  app-tktemp-fname [IFNOT] " wtf?!" error [ENDIF]
  $include "tcom/tcom-20-creatori-50-refproc.f"
  app-tktemp-fname count tcom:include-trace-options
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; calculate disk buffer sizes

extend-module TCOM

TCX-ONLY-OPTION-LOADER?:!f

;; UDG at $FF58
;; we need bytes from $FFF4 to setup IM2 handler, so last 2 UDG chars are unusable.

\ OPT-USE-UDG? [IF]
\ $FF50 constant zx-mem-bottom
\ [ELSE]
$FFF0 constant zx-mem-bottom
\ [ENDIF]

zx-mem-bottom dup constant zx-r0
OPT-RSTACK-BYTES 128 max - constant zx-s0

turnkey-pass1? [IFNOT]
endcr ." ZX Forth S0: $" zx-s0 .hex4 cr
endcr ." ZX Forth R0: $" zx-r0 .hex4 ."  (" OPT-RSTACK-BYTES ., ." bytes)\n"
[ENDIF]

end-module TCOM


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load target compiler

get-msecs quan tcom-total-stt

$include "tcom/tcom-06-miniasm.f"
$include "tcom/tcom-10-base.f"
$include "tcom/tcom-20-creatori.f"
$include "tcom/tcom-30-if-begin.f"
$include "tcom/tcom-36-parnas.f"
$include "tcom/tcom-60-util.f"

get-msecs tcom-total-stt - tcom-total-stt:!
tcom-total-stt ., ." msecs spent compiling TCOM.\n"


turnkey-pass2? [IF]
  app-tktemp-fname [IFNOT] " wtf?!" error [ENDIF]
  app-tktemp-fname count tcom:include-trace-refs
[ENDIF]


*: $zx-require  \ word <lib>
  system:?exec
  parse-name
  vocid: tcom:forth-shadows
  find-in-vocid ?exit< includer:parse-fname 2drop 2drop >?
  \*\ $zx-use ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load ZX Forth system sources

get-msecs quan kernel-total-stt

$include "kernel/zx-10-startup.f"
$include "kernel/zx-20-prims.f"
$include "kernel/zx-22-prims-math.f"
$include "kernel/zx-24-prims-muldiv.f"
$include "kernel/zx-26-prims-mem.f"
$include "kernel/zx-28-prims-io.f"
$include "kernel/zx-30-emit-driver.f"
$include "kernel/zx-36-rom-fp.f"
$include "kernel/zx-40-low-level.f"
$include "kernel/zx-48-bench-support.f"
$include "kernel/zx-50-debug-dump.f"
$include "kernel/zx-80-startup.f"
tcom:ir:cgen-flush

get-msecs kernel-total-stt - kernel-total-stt:!
kernel-total-stt ., ." msecs spent compiling the kernel.\n"

0 quan (zx-total-app-size)
app-dir-name [IF]
  tcom:zx-here quan (zx-app-start-addr)
  app-zxmain-fname count false
  get-msecs quan app-total-stt
  <zx-definitions>
  (include)
  <zx-done>
  tcom:ir:cgen-flush
  get-msecs app-total-stt - app-total-stt:!
  app-total-stt ., ." msecs spent compiling the application.\n"
  turnkey? not  turnkey-pass2? forth:lor [IF]
    tcom:zx-here (zx-app-start-addr) - (zx-total-app-size):!
  [ENDIF]
[ENDIF]

tcom:ir:cgen:cgen-finish

vsp-depth " vsp fucked" ?error
nsp-depth " nsp fucked" ?error

tcom:check-forwards
zxa:finalise


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; write used words

tcom:zx-set-main-auto

turnkey-pass1? [IF]
app-tktemp-fname [IFNOT] " wtf?!" error [ENDIF]
tcom:(zx-trace-main)
app-tktemp-fname count tcom:write-trace-result
endcr ." MESSAGE: now use '--turnkey-pass2' to generate final code." cr
1 [IF]
." ZX RAM used on pass 1: " tcom:zx-here tcom:zx-base-addr - tcom:.bytes
."  by " tcom:zx-stats-words ., ." words." cr
[ENDIF]
bye
[ENDIF]


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; show statistics

extend-module TCOM

endcr
zx-here zx-base-addr -
(zx-total-app-size) [IF]
." final kernel code size: " dup (zx-total-app-size) - .bytes cr
." final application size: " (zx-total-app-size) .bytes cr
." final system code size: " dup zx-stats-data-bytes - .bytes cr
." final total code size : " .bytes cr
[ELSE]
." final system code size : " dup zx-stats-data-bytes - .bytes cr
." final total system size: " .bytes cr
[ENDIF]
." system start address: $" zx-base-addr .hex4 cr
."   system end address: $" zx-here .hex4 cr
\ ." system size in bytes: " zx-here zx-base-addr - .bytes cr
xasm:stat-lit-tos [IF]
." peephole: lit TOS swaps    : " xasm:stat-lit-tos 0.r, cr
[ENDIF]
xasm:stat-8bit-optim [IF]
." peephole: 16-bit to 8-bit  : " xasm:stat-8bit-optim 0.r, cr
[ENDIF]
xasm:stat-bool-optim [IF]
." peephole: bools optimised  : " xasm:stat-bool-optim 0.r, cr
[ENDIF]
xasm:stat-push-pop-removed [IF]
." peephole: push-pop removed : " xasm:stat-push-pop-removed 0.r, cr
[ENDIF]
xasm:stat-pop-push-removed [IF]
." peephole: pop-push removed : " xasm:stat-pop-push-removed 0.r, cr
[ENDIF]
xasm:stat-push-pop-replaced [IF]
." peephole: push-pop replaced: " xasm:stat-push-pop-replaced 0.r, cr
[ENDIF]
xasm:stat-restore-tos-exx [IF]
." peephole: restore-tos-exx  : " xasm:stat-restore-tos-exx 0.r, cr
[ENDIF]
zx-stats-peephole-addsub [IF]
." peephole: add/sub loads    : " zx-stats-peephole-addsub 0.r, cr
[ENDIF]
zx-stats-peepbranch [IF]
." peephole: branch loads     : " zx-stats-peepbranch 0.r, cr
[ENDIF]
\ turnkey-pass2? [IF]
\ ." unused word count: " zx-unused-words 0.r, cr
\ [ENDIF]
\ ." total word count: " zx-stats-words 0.r, cr
\ ." total primitive count: " zx-stats-prims 0.r, cr
zx-stats-forwards [IF]
." forward references: " zx-stats-forwards 0.r, cr
[ENDIF]
."   code words : " zx-stats-code 0.r, ." , size: " zx-stats-mcode-bytes .bytes cr
."   colon words: " zx-stats-colon 0.r, ." , size: " zx-stats-tcode-bytes .bytes cr
."   data size  : " zx-stats-data-bytes .bytes cr
."   variable words: " zx-stats-var 0.r, cr
."   constant words: " zx-stats-const 0.r, cr
."   quan words    : " zx-stats-quan 0.r, cr
."   vect words    : " zx-stats-vect 0.r, cr
\ ."   alias words   : " zx-stats-alias 0.r, cr

zx-here zx-s0 128 - u>= " system image is too big" ?error
end-module


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; write tape

output-file-name count
string:extract-ext " .dsk" string:=ci [IF]
  ;; save disk
  endcr ." SAVING DSK: " output-file-name count type cr

  \ mk-cpcdsk:p3-data mk-cpcdsk:new-dsk
  mk-cpcdsk:pcw-ds mk-cpcdsk:new-dsk
  zxa:dsk:set-autoload-cargador-name
  zxa:dsk:save-all

  0 [IF]
  " ROOMEDIT.BLK" mk-cpcdsk:create-file
  " _zxemut_.DISC.blk" file:open-r/o quan blk-fd
  here  blk-fd file:size  blk-fd file:read-exact
  blk-fd file:size blk-fd file:close
  here swap mk-cpcdsk:write
  mk-cpcdsk:close-file
  [ENDIF]

  : disk-extra-file  ( disk$ fname$ )
    count file:open-r/o >r
    count mk-cpcdsk:create-file
    here  r@ file:size  r@ file:read-exact
    r@ file:size r> file:close
    here swap mk-cpcdsk:write
    mk-cpcdsk:close-file ;

  : disk-extras
    extra-files-head << dup ?^|
      endcr ." appending '" dup extra-file:fname$ count type
      ." ' as '" dup extra-file:disk$ count type ." '\n"
      dup extra-file:disk$ over extra-file:fname$ disk-extra-file
      extra-file:next |?
    else| drop >> ;

  disk-extras

  output-file-name count file:create
  dup mk-cpcdsk:save-dsk file:close

  mk-cpcdsk:free-dsk
[ELSE]
  (*
  output-file-name count
  string:extract-ext " .pzx" string:=ci [IF]
    zxa:tap:fmt-pzx
  [ELSE]
    zxa:tap:fmt-tap
  [ENDIF]
  zxa:tap:tape-format:!
  *)

  pad$:!0 $0a pad$:c+ " Created by " pad$:+
  tcom:Succubus-mark-string string:/char pad$:+
  pad$:@ string:$new zxa:tap:pzx-descrption$:!

  cargador-name [IFNOT] " UrF/X app" set-cargador-name [ENDIF]

  ;; save tape
  OPT-WRITE-ONE-CODE-FILE? zxa:tap:set-one-code-file
  cargador-name count zxa:tap:set-cargador-name
  output-file-name count
  endcr ." SAVING TAPE: " 2dup type cr
  file:create tap-fd:!

  tap-fd zxa:tap:tap-save-initial-header

  [HAS-WORD] custom-tap-writer [IF]
    custom-tap-writer
  [ELSE]
  tap-fd zxa:tap:save-fd

  (*
  false ( OPT-SAVE-DEMO-DISC?) [IF]
  \ endcr ." SAVING DEMO DISK...\n"
  : load-demo-disk  ( -- addr count )
    " demo/game.blk" file:open-r/o >r
    \ r@ file:size r@ file:tell -
    here ( tcom:zx-#ramdisc) $2C00 1- 2dup r@ file:read-exact
    r> file:close ;

  : shrink-disk  ( addr count -- addr count )
    0 max << dup 0?v|| 2dup + 1- c@ bl <= ?^| 1- |? else| >> ;

  : align-disk  ( addr count -- addr count )
    << dup 1023 and ?^| 2dup + bl swap c! 1+ |? else| >> ;

  : save-demo-disk  ( addr count fd )
    endcr ." TAP: saving GAME demo disk (" over ., ." bytes)\n"
    " DISC" zxa:tap:set-cblock-name
    >r tcom:zx-ramdisc^ r> zxa:tap:save-code-block ;

  load-demo-disk
  shrink-disk align-disk
  tap-fd save-demo-disk
  [ENDIF]
  *)
  [ENDIF]

  tap-fd file:close
[ENDIF]


;; remove temporary file
turnkey-pass2? OPT-TURNKEY-DEBUG? not land [IF]
app-tktemp-fname [IFNOT] " wtf?!" error [ENDIF]
app-tktemp-fname count file:unlink
[ENDIF]

depth [IF]
(BYE-REPORT):!t
[ENDIF]
