;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; main target compiler module
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


$use <unixdate>
$use <getarg>

(*
registers:
  ESP -- return stack pointer (URP)
  EBP -- data stack pointer (USP)
  EBX -- data stack TOS (UTOS)
  EDI -- user area

  other registers (EAX, ECX, EDX, ESI) are free to use, and need not to be stored.

  both stacks grow naturally (as PUSH does). top stack element is [REG]
  (again, as hardware PUSH does).

  note that x86 ABI declares registers EAX, ECX and EDX as volatile (caller-saved).

WARNING! if you will decide to change the primitives, you will need to fix
         the optimiser code. generally, changing primitives is a VERY BAD IDEA,
         because most optimisations expect the code to be written in a particular way.
         that is, do not touch ANY primitives unless you REALLY KNOW what you're doing!
*)

true constant BEAST-NO-IP-REG
4 constant BEAST-RP-REG  -- ESP
5 constant BEAST-SP-REG  -- EBP
3 constant BEAST-TOS-REG -- EBX
7 constant BEAST-ADR-REG -- EDI

;; we'll define them ourselves
true constant BEAST-TC-MACROS

;; do not include instructions nobody needs ;-)
true constant X86ASM-SMALL


.banner

true constant UROBORUS-THE-GREAT-SNAKE

[HAS-WORD] BEAST-DEVASTATOR [IFNOT]
false constant BEAST-DEVASTATOR
[ENDIF]


false constant SC-EXPERIMENTAL-NO-SSWAP-OPT -- disable stack swap optimisation?

;; there is no reason to not include it; invaluable for debugging!
 true constant BEAST-INCLUDE-DISASM

;; doesn't work (and prolly will never be)
false quan BEAST-PE

false quan tgt-save-stack-comments
false quan tgt-use-system-name-hash -- use "system:hash-name"?
false quan tgt-precise-nhash -- use "precise" case convertsion insted of simply setting one bit?
 true quan tgt-dynamic-binary -- build dynamic binary (only for ELF)?
false quan tgt-build-base-binary -- build "base.elf" binary (with less features)?
false quan tgt-mtask-support -- multitask support words?

\ false constant tgt-align-cfa -- align code CFA fields, not DFA? don't bother, it is slower

false quan tgt-disable-hash-find -- just4fun ;-)

 true quan tgt-dynalloc-guards

false quan tgt-disable-inliner

false quan tgt-map-file

;; binary file name
0 quan tgt-image-name

69 quan tgt-#inline-bytes

 true quan tgt-aggressive-inliner
 true quan tgt-forth-inliner

 true constant tgt-align-loops

 true constant tgt-exit-as-branch -- compile various "EXIT" as branches?

false quan tgt-asm-listing
false quan tgt-prim-listing -- list all primitives


;; asciiz
: image-name!  ( addr count )
  dup 1 < ?error" invalid image name"
  tgt-image-name dynmem:free
  dup 4+ 1+ dynmem:?alloc dup tgt-image-name:!
  dup >r string:mk$ 0 r> string:end$ c! ;

: image-name@  ( -- addr count )  tgt-image-name count ;

: free-image-name  tgt-image-name dynmem:free ;

" urforth" image-name!


: .def?  ( val )  ?< ."  (default)" >? cr ;

getarg:arg: --shitdoze  BEAST-PE:!t ;
getarg:help: ." compile shitdoze version (doesn't work yet)" ;
getarg:arg: --dynamic  tgt-dynamic-binary:!t ;
getarg:help: ." build dynamic binary" tgt-dynamic-binary .def? ;
getarg:arg: --static        tgt-dynamic-binary:!f ;
getarg:help: ." build static binary" tgt-dynamic-binary not .def? ;
getarg:arg: --base
  tgt-build-base-binary:!t tgt-mtask-support:!f
  24 tgt-#inline-bytes:! ;
getarg:help: ." build 'base' binary" ;
getarg:arg: --image  ( addr count ) image-name! ;
getarg:help: ." set image name; default is \'" image-name@ type ." \'" ;
getarg:last-need-arg
getarg:arg: --save-stack-comments  tgt-save-stack-comments:!t ;
getarg:help: ." save stack comments to use with \'DEBUG:WHELP\'" tgt-save-stack-comments .def? ;
getarg:arg: --no-stack-comments  tgt-save-stack-comments:!f ;
getarg:help: ." do not save stack comments to use with \'DEBUG:WHELP\'" tgt-save-stack-comments not .def? ;
getarg:arg: --mtask         tgt-mtask-support:!t ;
getarg:arg: --no-mtask      tgt-mtask-support:!f ;
getarg:arg: --new-hash      tgt-use-system-name-hash:!f ;
getarg:help: ." use this if you changed hash parameters/function" ;
getarg:arg: --precise-nhash tgt-precise-nhash:!t ;
getarg:arg: --rough-nhash   tgt-precise-nhash:!f ;
getarg:arg: --disable-hash-find tgt-disable-hash-find:!t ;
getarg:arg: --alloc-guards  tgt-dynalloc-guards:!t ;
getarg:arg: --no-alloc-guards  tgt-dynalloc-guards:!f ;
getarg:arg: --disable-inliner  tgt-disable-inliner:!t ;
getarg:arg: --no-inline  tgt-#inline-bytes:!0 ;
getarg:arg: --inline-8  8 tgt-#inline-bytes:! ;
getarg:arg: --inline-16  16 tgt-#inline-bytes:! ;
getarg:arg: --inline-32  32 tgt-#inline-bytes:! ;
getarg:arg: --inline-48  48 tgt-#inline-bytes:! ;
getarg:arg: --inline-64  64 tgt-#inline-bytes:! ;
getarg:arg: --map  tgt-map-file:!t ;
getarg:help: ." write map file" ;
getarg:arg: --aggressive-inliner  tgt-aggressive-inliner:!t ;
getarg:arg: --no-aggressive-inliner  tgt-aggressive-inliner:!f ;
getarg:arg: --forth-inliner  tgt-forth-inliner:!t ;
getarg:arg: --no-forth-inliner  tgt-forth-inliner:!f ;
getarg:arg: --list  tgt-asm-listing:!t ;
getarg:help: ." write disassembled listing" ;
getarg:arg: --list-no-ofs  tgt-asm-listing:!1 ;
getarg:help: ." write disassembled listing" ;
getarg:arg: --prims  tgt-prim-listing:!t ;

;; optional
getarg:usage: ." usage: urforth urb-main.f [args]\nargs:\n" ;


: process-cli-args
  (*
  0 << dup argv# < ?^| dup argv@ vocid: cli-args find-in-vocid
                      not?< drop ['] cli-args:--help >? execute 1+ |? else| drop >>
  *)
  getarg:parse-args
  BEAST-PE ?< tgt-dynamic-binary:!t >? ;
process-cli-args


: .show-opts
  ." target OS: " BEAST-PE ?< ." shitdoze\n"
  || ." GNU/Linux (" tgt-dynamic-binary ?< ." dynamic)\n" || ." static)\n" >? >?
  tgt-mtask-support ?< ." basic multitasking enabled\n" >?
  \ ." code align field: " tgt-align-cfa ?< ." CFA\n" || ." DFA\n" >?
  ." maximum inline: " tgt-#inline-bytes ., ." bytes.\n" ;
.show-opts


get-msecs quan total-stt

tgt-build-base-binary [IFNOT]
true constant X86ASM-FPU
[ENDIF]

here get-msecs
$use <x86asm>
get-msecs swap - ." MSG: asm loaded in " ., ." msecs (" here swap - ., ." bytes compiled).\n"

BEAST-INCLUDE-DISASM [IF]
here get-msecs
$use <x86dis>
get-msecs swap - ." MSG: disasm loaded in " ., ." msecs (" here swap - ., ." bytes compiled).\n"

false constant dump-asm-code

\ : disasm-range  ( from to )
\   << 2dup u< ?^| swap x86dis:disasm-one swap |? else| 2drop >> ;
[ENDIF]


get-msecs quan total-stt-w/o-asm

0 variable tgt-userval-vocid-fixups
0 variable tgt-chain-vocid-fixups
0 variable tgt-quan-vocid-fixups
0 variable tgt-vector-vocid-fixups


;; load target compiler foundation
$include "urb-10-tcom.f"
\ tgt-code-align tcom:code-align:!
\ tgt-build-base-binary [IF] 4 [ELSE] tgt-code-align [ENDIF] tcom:code-align:!
\ tgt-build-base-binary [IF] 4 [ELSE] tgt-forth-align [ENDIF] tcom:forth-align:!
\ tgt-build-base-binary [IF] 4 [ELSE] tgt-const-align [ENDIF] tcom:const-align:!
\ tgt-build-base-binary [IF] 4 [ELSE] tgt-var-align [ENDIF] tcom:var-align:!
tgt-dynamic-binary to tcom:dynamic-binary
$include "urb-20-elf.f"
$include "urb-22-pe.f"
$include "urb-30-tcbase.f"

BEAST-PE [IF]
pe-builder:setup
[ELSE]
elf-builder:setup
[ENDIF]

depth " load-wuta?!" ?error

: setup-disasm
  [ BEAST-INCLUDE-DISASM ] [IF]
  ['] tcom:c@ x86dis:dis-c@:!
  [ENDIF] ;

: setup-asm
  ['] tcom:here to x86asm:emit:here
  [']   tcom:c, to x86asm:emit:c,
  [']   tcom:c@ to x86asm:emit:c@
  [']   tcom:c! to x86asm:emit:c!
  [']    tcom:@ to x86asm:emit:@
  [']    tcom:! to x86asm:emit:! ;

setup-asm
setup-disasm

tcom:init

$include "urb-60-tcom-asm-macs.f"
$include "urb-70-tgt-sysvars.f"


\ get-msecs quan total-stt

;; startup code, execute and prologues
$include "../Beast/Beast-10-startup-elf.f"
$include "../Beast/Beast-16-do-ll.f"

$include "urb-32-tcfa.f"

;; initialise vocabularies
$include "urb-35-tcvocs.f"
;; various definitions in shadow vocab
$include "urb-40-tcwdef.f"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; some initial constants

BEAST-PE not dup tgt-constant (*NIX?)
constant tgt-(*NIX?)

\ ll@ (ghtable-addr)    tgt-constant (GHTABLE^)
ll@ (finfo-tail-addr) tgt-constant (FINFO-TAIL^)

ll@ (sigstack-addr) tgt-constant (SIGSTACK-START)
ll@ (sigpad-addr)   tgt-constant (SIGPAD-START)

ll@ (argv-addr) tgt-constant (ARGV)
ll@ (argc-addr) tgt-constant (#ARG)
ll@ (envp-addr) tgt-constant (ENV^)
tcom:dynamic-binary [IF]
ll@ (xsp-addr)  tgt-constant (SYS-ESP^)
[ENDIF]

\ " @FORTH" tgt-hash-name tgt-constant (@FORTH-NAME-HASH)
\ " @CONTEXT" tgt-hash-name tgt-constant (@CTX-NAME-HASH)
\ " @CURRENT" tgt-hash-name tgt-constant (@CUR-NAME-HASH)

>in-target
$include "../Beast/Beast-18-user.f"
>in-origin

$include "urb-74-tgt-constants.f"


;; shadow modules
$include "urb-42-modules.f"

;; various assembler primitives
>in-target
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; QUAN and DEFER wordlists
;; i didn't found a better place for them, sorry
;; they will be filled later, but we need the vocids to create quans
module QUAN-SUPPORT
<disable-hash>
  module (QUAN-MTX) <disable-hash>
    tgt-current-vocid-to tgt-(quan-vocid)
  end-module (QUAN-MTX)
  module (VECTOR-MTX) <disable-hash>
    tgt-current-vocid-to tgt-(vector-vocid)
  end-module (VECTOR-MTX)
end-module QUAN-SUPPORT

module CHAIN-SUPPORT
<disable-hash>
  module (CHAIN-MTX) <disable-hash>
    tgt-current-vocid-to tgt-(chain-vocid)
  end-module (CHAIN-MTX)
end-module CHAIN-SUPPORT

module USERVALUE-SUPPORT
<disable-hash>
  module (USERVALUE-MTX) <disable-hash>
    tgt-current-vocid-to tgt-(uservalue-vocid)
  end-module (USERVALUE-MTX)
end-module USERVALUE-SUPPORT

>in-origin
tgt-(uservalue-vocid) tgt-userval-vocid-fixups tgt-patch-vocobj-list
tgt-(chain-vocid) tgt-chain-vocid-fixups tgt-patch-vocobj-list
tgt-(quan-vocid) tgt-quan-vocid-fixups tgt-patch-vocobj-list
tgt-(vector-vocid) tgt-vector-vocid-fixups tgt-patch-vocobj-list
>in-target


$8000_0000 constant MIN-INT
$7FFF_FFFF constant MAX-INT
$FFFF_FFFF constant MAX-UINT

 0 constant FALSE
-1 constant TRUE
32 constant BL
10 constant NL
$include "../Beast/Beast-20-syslow-elf.f"
$include "../Beast/Beast-30-branchlit.f"
$include "../Beast/Beast-32-abort.f"
$include "../Beast/Beast-38-stacks.f"
$include "../Beast/Beast-40-peekpoke.f"
$include "../Beast/Beast-42-math-base.f"
>in-origin
  ;; shadow flow control words
\  tgt-setup-peek-poke-optim
\  tgt-setup-and-or-optim
\  tgt-setup-math-optim
\  tgt-setup-tco-optim
  $include "urb-46-flowctl.f"
>in-target
$include "../Beast/Beast-44-math-more.f"
$include "../Beast/Beast-52-syslow-linux.f"
$include "../Beast/Beast-54-string.f"
[[ tgt-build-base-binary ]] [IFNOT]
$include "../Beast/Beast-56-syslow-linux-tty.f"
[ENDIF]
$include "../Beast/Beast-58-syslow-callback.f"

|: SETUP-RAW-OUTPUT
  ['] raw-emit:emit (emit^) !
  ['] raw-emit:type (type^) !
  ['] raw-emit:endcr? (endcr?^) !
  ['] raw-emit:endcr! (endcr!^) !
  ['] raw-emit:endcr (endcr^) !
  ['] raw-emit:getch (getch^) !
  raw-emit:lastcr? !t ;

: EMIT   ( ch )          (emit^) @execute-tail ;
: TYPE   ( addr count )  (type^) @execute-tail ;
: #EMIT  ( count ch )    << over +?^| 1 under- dup emit |? else| 2drop >> ;
: CR                     nl emit ;
: ENDCR? ( -- flag )     (endcr?^) @execute-tail ;
: ENDCR! ( flag )        (endcr!^) @execute-tail ;
: ENDCR                  (endcr^) @execute-tail ;
: READKEY  ( -- ch // -1 ) (getch^) @execute-tail ;

$include "../Beast/Beast-60-hl-06-numconv.f"
$include "../Beast/Beast-60-hl-08-vocstack.f"
$include "../Beast/Beast-60-hl-16-compile-base.f"
$include "../Beast/Beast-60-hl-20-flowctl.f"
$include "../Beast/Beast-60-hl-24-loops.f"
$include "../Beast/Beast-60-hl-30-creatori.f"
$include "../Beast/Beast-60-hl-32-debug-base.f"
$include "../Beast/Beast-60-hl-34-creatori-more.f"
$include "../Beast/Beast-60-hl-38-segfault.f"
$include "../Beast/Beast-60-hl-40-findbase.f"
$include "../Beast/Beast-60-hl-46-parse.f"
$include "../Beast/Beast-60-hl-48-vocobjs.f"
$include "../Beast/Beast-60-hl-50-colon.f"
$include "../Beast/Beast-60-hl-54-struct.f"
$include "../Beast/Beast-60-hl-56-enum.f"
$include "../Beast/Beast-60-hl-60-chain.f"
$include "../Beast/Beast-60-hl-64-quan.f"
$include "../Beast/Beast-60-hl-66-uservalue.f"
$include "../Beast/Beast-70-hl-10-module.f"
$include "../Beast/Beast-70-hl-16-malloc.f"
[[ tgt-build-base-binary ]] [IFNOT]
$include "../Beast/Beast-70-hl-20-prng.f"
$include "../Beast/Beast-70-hl-30-dynstr.f"
[ENDIF]
$include "../Beast/Beast-70-hl-40-interpret.f"
[[ tgt-build-base-binary ]] [IFNOT]
$include "../Beast/Beast-70-hl-60-float-base.f"
[ENDIF]
$include "../Beast/Beast-80-hl-10-file.f"
$include "../Beast/Beast-80-hl-20-include.f"
$include "../Beast/Beast-90-hl-30-xif.f"
[[ tgt-mtask-support ]] [IF]
$include "Beast/Beast-90-hl-60-mtask.f"
[ENDIF]
[[ tgt-build-base-binary ]] [IFNOT]
$include "../Beast/Beast-90-hl-90-srepl.f"
$include "../Beast/Beast-90-hl-99-save.f"
[ENDIF]
$include "../Beast/Beast-99-hl-99-main.f"
>in-origin
tgt-forwards:tgt-(cold)-cfa ll@ (cold-cfa-addr) tcom:!
;; fix DP
tcom:here ll@ (dp-addr) tcom:!
;; fix HDR-DP
tcom:hdr-here ll@ (hdr-dp-addr) tcom:!

;; fix reset address
tgt-forwards:tgt-(reset-system)-cfa " system reset word is not set" not?error
tgt-forwards:tgt-(reset-system)-cfa tgt-(reset-system)-cfa-va tcom:!


: .$plural  ( n addr count )
  rot dup ., >r type r> 1- ?exit< [char] s emit >? ;


;; default vocab doer IP is 0; fix it
: tgt-fix-vocab-doers  ( tgt-vocdoer-ip )
  dup not?error" vocab doer is not set"
  0 >r
  tgt-vocdoer-list << ( tgt-vocdoer-ip list^ )
    2dup 4+ @ tcom:!
  r0:1+! @ dup ?^|| else| 2drop >>
  r> ., ." vocabulary doers fixed.\n" ;

tgt-forwards:tgt-(vocab-doer)-doer tgt-fix-vocab-doers

tgt-resolve-forwards

\ tgt-forwards:tgt-(opt-constant-value) tgt-constant-optcfa-list tgt-patch-xlist
\ " constant optcfa" .$plural ."  patched.\n"

\ tgt-forwards:tgt-(opt-variable-addr) tgt-variable-optcfa-list tgt-patch-xlist
\ " variable optcfa" .$plural ."  patched.\n"


get-msecs dup total-stt - total-stt:!
total-stt-w/o-asm - total-stt-w/o-asm:!

$include "urb-90-tgt-stats.f"
$include "urb-80-tgt-map.f"
tgt-write-map-file

depth " load-wuta?!" ?error

(*
BEAST-PE [IF]
" urbforth.exe" tcom:save
[ELSE]
" urbforth" tcom:save
[ENDIF]
*)
image-name@ tcom:save


0 [IF]
debug:hstats-full-names 0!
debug:.hashstats
debug:.hashstats-more bye
[ENDIF]

free-image-name
