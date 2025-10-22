;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; target creatori
;; forward definitions (resolve target word addresses on demand)
;; directly included from "urb-40-tcwdef.f"
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; created forward will try to find the corresponding target word
;; FIXME: this pasta should be removed!

: tgt-forward-resolve-shadow-spfa  ( addr count -- shadow-pfa )
\ endcr ." TGT-CFA-FWD: <" 2dup type ." >\n"
  2>r push-ctx 0 vsp-push   ;; cut it short here
  (tc-forth-vocid) context!
  ws-vocab-cfa >loc
    2r@ find pop-ctx pop-ctx
  loc> ws-vocab-cfa:!
  not?< ." Uroborus ERROR: target word '" 2r> type ." ' not found!\n" abort >?
  2rdrop dup system:does? not?error" internal Uroborus error"
  dart:cfa>pfa dup (?shadow-tgt-sign) ;

: tgt-forward-resolve-shadow-cfa  ( addr count -- shadow-pfa )
  tgt-forward-resolve-shadow-spfa (shadow-tgt-cfa@) ;

: tgt-forward-find-shadow-pfa  ( pfa -- shadow-pfa )
  4+ count tgt-forward-resolve-shadow-spfa ;

: tgt-cfa-forward  \ fwd-name tgt-word-name
  <builds  ( cfa) 0 ,  ( tgt word name) parse-name dup , system:cstr,
  does> ( pfa )
    dup @ dup ?exit< nip >? drop
    dup >r tgt-forward-find-shadow-pfa
    (shadow-tgt-cfa@) dup r> ! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; proper forwards

0 variable tgt-fwd-fix-list
0 quan tgt-fres-#words
0 quan tgt-fres-#fixes
0 quan tgt-real-#fixes

: tgt-resolve-one-forward  ( pfa )
  4+ dup @ not?exit< drop >?
  dup >r
  2 4* + count  r@ 4+ @execute
  r> << ( val node^ ) @ dup not?v||
    2dup 4+ @ tcom:!  tgt-real-#fixes:1+! ^|| >> 2drop ;

: tgt-resolve-forwards
  tgt-real-#fixes:!0
  tgt-fwd-fix-list << @ dup not?v||
    dup tgt-resolve-one-forward ^|| >> drop
  tgt-fres-#words ., ." forwarded word" tgt-fres-#words ?< ." s" >? ." .\n"
  tgt-fres-#fixes ., ." forwarded ref" tgt-fres-#fixes ?< ." s" >? ."  patched.\n"
  tgt-fres-#fixes tgt-real-#fixes <> ?error" internal forward fixer error" ;


: tgt-forward-resolve-shadow-pfa  ( addr count -- shadow-pfa )
  tgt-forward-resolve-shadow-cfa tgt-cfa>pfa ;

module tgt-fwd-doer
<disable-hash>
|: (lfx-doer!)  ( this-pfa )
  ?in-target 4+
  ( next-ptr) here over @  dup 0= tgt-fres-#words:-!  , swap !
  ( fix-addr) tgt-latest-doer^ ,
  tgt-fres-#fixes:1+! ;

*: tgt-latest-doer!
  system:?comp vocobj:this #, \\ (lfx-doer!) ;
end-module tgt-fwd-doer

;; create doer with proper forward resolution.
;; format:
;;   dd flist-next    ;; next in fixlist
;;   dd fix-addr      ;; pointer to "fix list addresses" head
;;   dd resolver-cfa  ;; called by final resolver
;;   dd count:name    ;; target word name
: tgt-forward-doer  \ fwd-name tgt-word-name
  <builds ( register in fix list) here tgt-fwd-fix-list @ , tgt-fwd-fix-list !
          ( fix-addr) 0 ,   ;; no fixes yet
          ( resolver) ['] tgt-forward-resolve-shadow-cfa ,
          ( tgt word name) parse-name dup , system:cstr,
          ( setup methods) vocid: tgt-fwd-doer system:latest-vocid !
  does> error" wut?!" ;

module tgt-fwd-cfa-lazy
<disable-hash>
|: (lfx,)  ( this-pfa )
  ?in-target 4+
  ( next-ptr) here over @  dup 0= tgt-fres-#words:-!  , swap !
  ( fix-addr) tcom:here ,
  tgt-fres-#fixes:1+!
  0 tcom:, ;

*: ,
  system:?comp vocobj:this #, \\ (lfx,) ;
end-module tgt-fwd-cfa-lazy

: tgt-cfa-forward-lazy  \ fwd-name tgt-word-name
  <builds ( register in fix list) here tgt-fwd-fix-list @ , tgt-fwd-fix-list !
          ( fix-addr) 0 ,   ;; no fixes yet
          ( resolver) ['] tgt-forward-resolve-shadow-cfa ,
          ( tgt word name) parse-name dup , system:cstr,
          ( setup methods) vocid: tgt-fwd-cfa-lazy system:latest-vocid !
  does> error" wut?!" ;

tgt-fwd-fix-list !0
tgt-fres-#words:!0
tgt-fres-#fixes:!0

module tgt-forwards
<disable-hash>

tgt-cfa-forward tgt-(exit)            forth:exit
tgt-cfa-forward tgt-(?exit)           forth:?exit
tgt-cfa-forward tgt-(not?exit)        forth:not?exit
tgt-cfa-forward tgt-(0?exit)          forth:0?exit
tgt-cfa-forward tgt-(?exit&leave)     forth:?exit&leave
tgt-cfa-forward tgt-(not?exit&leave)  forth:not?exit&leave
tgt-cfa-forward tgt-(0?exit&leave)    forth:0?exit&leave

tgt-cfa-forward tgt-(error)       forth:error
tgt-cfa-forward tgt-(?error)      forth:?error
tgt-cfa-forward tgt-(not?error)   forth:not?error

tgt-cfa-forward tgt-(@)        forth:@
tgt-cfa-forward tgt-(!)        forth:!

tgt-cfa-forward tgt-rdrop    forth:rdrop
tgt-cfa-forward tgt-2rdrop   forth:2rdrop
tgt-cfa-forward tgt-3rdrop   forth:3rdrop
tgt-cfa-forward tgt-4rdrop   forth:4rdrop

tgt-cfa-forward tgt-\,-ccfa      forth:\,
tgt-cfa-forward tgt-(type)       forth:type
tgt-cfa-forward tgt-(immediate)  forth:immediate
tgt-cfa-forward tgt-(does>)      system::(does>)

tgt-cfa-forward tgt-(reset-system)-cfa  forth::(reset-system)
tgt-cfa-forward tgt-(cold)-cfa          forth::(cold)
tgt-cfa-forward tgt-(chain-tail)-cfa    chain-support:chain-tail

tgt-cfa-forward tgt-(vocab-doer)-doer    system::(vocab-doer)

tgt-forward-doer tgt-(chain-doer)-doer    chain-support::(chain-doer)
tgt-forward-doer tgt-(quan-doer)-doer     quan-support::(xquan-does)
tgt-forward-doer tgt-(vector-doer)-doer   quan-support::(xvector-does)

tgt-cfa-forward-lazy tgt-(notimpl)-cfa    forth:(notimpl)
tgt-cfa-forward-lazy tgt-(noop)-cfa       forth:noop

end-module tgt-forwards
