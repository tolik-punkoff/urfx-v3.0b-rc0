;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; more creation/compiler utilities
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module SYSTEM
using dart

;; allocate unique ids for vstack/nstack
;; all such ids are always positive; negative values are reserved for the system
1 quan NEXT-VNSTACK-ID

: ALLOC-VN-ID  ( -- id )
  next-vnstack-id 65535 u> ?error" out of vstack/nstack ids"
  next-vnstack-id:1+! ;


;; vocabulary words have vocid stored right before PFA
: VOCID@  ( cfa -- vocid )  cfa>vocid @ ;
: VOCID!  ( vocid cfa )     cfa>vocid ! ;

: ?VOCOBJ  ( cfa )  vocid@ not?error" vocobj word expected" ;
: ?VOCID@  ( cfa -- vocid )  vocid@ dup not?error" vocobj word expected" ;


\ : (?ANY-DOES)  ( cfa-xt -- flag )  dup does? swap does-inlineable? or ;

: (DOER^)  ( builded-word-cfa -- doer-ip^ )
  dup does? not?error" not a DOES> word"
  8 + ;

: DOER@  ( builded-word-cfa -- doer-cfa )  (doer^) @ ;
: !DOER  ( builded-word-cfa doer-cfa )  swap (doer^) ! ;
: DOER!  ( doer-cfa builded-word-cfa )  (doer^) ! ;


: XCFALEN!  ( ffa-addr )  here over - swap c! ;

;; cfa ids
[[ 0 dup ]] constant DOES-CFA
[[ 2 4* + dup ]] constant VARIABLE-CFA
[[ 2 4* + dup ]] constant CONSTANT-CFA
[[ 2 4* + dup ]] constant USERVAR-CFA
[[ 2 4* + dup ]] constant USERVALUE-CFA
[[ 2 4* + dup ]] constant (ALIAS-CFA) (private)
[[ drop ]]

create CFA-LIST
  ;; format: cfa-xt-va extra-data-size
  uro-label@ do-does , 4 ,
  uro-label@ do-variable , 0 ,
  uro-label@ do-constant , 0 ,
  uro-label@ do-uservar , 0 ,
  uro-label@ do-uservalue , 0 ,
  uro-label@ do-alias , 0 ,
create;

: CFA,  ( cfaid )
  dup -?exit< drop >?
  cfa-list + here 4- ( ffa address ) >r @++
  $E8 c, Succubus:low:branch-addr,
  ( align) 0 w, 0 c,
  @ resv
  r> xcfalen! ;

: ALIAS-CFA,  ( origcfa )
  (alias-cfa) cfa, , ;


: (ARG-BRANCH!)    ?exec wtype-branch latest-ffa or! ;
: (ARG-LITERAL!)   ?exec wtype-literal latest-ffa or! ;


;; do not mark this as "(noreturn)", because the code happily continues after it
;; next code dword is the cfa of the anonymous colon doer
|: (DOES>)
  latest-cfa system:rr> @ !doer ; (inline-blocker)

: MK-BUILDS   ( addr count )  mk-header-builds does-cfa cfa, latest-cfa ['] noop !doer ;
: MK-FORTH    ( addr count )  mk-header-forth ( forth-cfa) -1 cfa, ;
: MK-CODE     ( addr count )  mk-header-code ( code-cfa) -1 cfa, ;
: MK-USERVAR  ( ofs addr count )  mk-header-usrvar uservar-cfa cfa, , ;

: MK-CREATE  ( addr count )
  ;; use code align here, it should be better for tables
  mk-header-create variable-cfa cfa, ;

: MK-VARIABLE  ( value addr count )
  mk-header-var variable-cfa cfa, , ;

: MK-CONSTANT  ( value addr count )
  mk-header-const constant-cfa cfa, , ;

: MK-DOES  ( addr count doer-cfa )
  nrot mk-builds latest-cfa doer! ;

;; HACK: for "ordinary" vocabs, CFA is 4+ for doer
|: (VOCAB-DOER)  ( pfa -- vocid )
  ( to cfa) 12 - vocid@ ;

;; is word a simple vocabulary? (i.e. is it a non-vocobject?)
: SIMPLE-VOCAB?  ( cfa -- flag )
  dup not?exit< drop false >?
  dup does? not?exit< drop false >?
  doer@ ['] (vocab-doer) = ;

|: (VOCOBJECT-CALL)  ( vocobj-cfa ws-vocab-cfa )
  ws-vocab-cfa >r ws-vocab-cfa:! execute r> ws-vocab-cfa:! ;


;; if not empty
: VOCID-SET-LATEST-RFA  ( vocid )
  vocid>rfa dup @ not?< latest-nfa swap ! || drop >? ;

;; reserve room before PFA (extend CFA)
: LATEST-#CFA+!  ( n )
  latest-ffa dup c@ rot +  dup 0 250 within not?error" invalid #cfa"
  swap c! ;

;; build vocab word. it has "vocabulary" flag set, and vocid at PFA-4.
: MK-BUILDS-VOCAB   ( addr count vocid )
  >r mk-header-create does-cfa cfa, latest-cfa ['] (vocab-doer) !doer
  r@ latest-vocid !
  r> vocid-set-latest-rfa ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; global hash table cleanups

;; remove bucketed words using the given predicate
: CLEAN-BUCKET  ( vocid bucket flag-check-cfa )
  >r swap >r dup @  ( prev curr | check-cfa vocid )
  << dup not?v||
     dup dart:bfa>vfa @ r@ = not?^| nip dup @ |?
     dup dart:bfa>ffa @ r1:@ execute
     [ 0 ] [IF]
       endcr ."   FLAG-CHECK: |" over dart:bfa>nfa debug:.idfull ." |"
       ."  flag=" dup 0.r cr
     [ENDIF]
     ?< 2dup @ swap ! ( prev should point to our next)
        [ 0 ] [IF]
          endcr ."    DROPPING: |" dup dart:bfa>nfa debug:.idfull ." |"
          ."  flags=$" dup bfa>ffa @ dup hi-word .hex4 [char] _ emit lo-word .hex4 cr
        [ENDIF]
      || nip dup >?
  ^| @ |
  >> 2drop 2rdrop ;

;; remove words from LFA links; used both for hashed and non-hashed dicts
: UNLINK-LFAS  ( vocid flag-check-cfa )
  >r vocid>latest dup @ << ( prev-lfa^ curr-lfa | checker-cfa )
    dup not?v||
    dup lfa>ffa @ r@ execute
    ?< \ endcr ." === removing |" dup lfa>nfa debug:.idfull ." |\n"
       2dup @ swap !
    || nip dup >? @
  ^|| >> rdrop 2drop ;

;; process all hash table buckets
: CLEAN-VOCID  ( vocid flag-check-cfa )
  [ 0 ] [IF]
    endcr ." === CLEANING |" over debug:.vocname-full ." |\n"
  [ENDIF]
  2dup unlink-lfas
  >r >r ( | flag-check-cfa vocid )
  system:#htable r@ vocid-hashtbl@
  dup not?exit< 2rdrop 2drop >?
  << over ?^| 1 under- r@ over r1:@ clean-bucket 4+ |?
  else| 2rdrop 2drop >> ;

|: FLG-PRIVATE?  ( flag -- nzres )  wflag-private and ;
: REMOVE-VOCID-PRIVATE  ( vocid )  ['] flg-private? clean-vocid ;

|: FLG-NOT-PUBLISHED?  ( flag -- nzres )  wflag-published not-mask? ;
: REMOVE-VOCID-NON-PUBLISHED  ( vocid )  ['] flg-not-published? clean-vocid ;

|: FLG-ANY?  ( flag -- nzres )  true ;
: REMOVE-VOCID-ALL  ( vocid )  ['] flg-any? clean-vocid ;

end-module SYSTEM


[[ tgt-build-base-binary ]] [IFNOT]
module FORGET-SUPPORT
<disable-hash>
using dart

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FORGET mechanics
;; scan each GHTABLE bucket, remove all words not in a dict anymore.
;; this leaks some header segment memory due to name align.
;; it is usually only several bytes, though, and it doesn't worth
;; introducing a new header field.

;; remove all file infos after the given header segment address.
;; caller should make sure that address is not inside some fref.
: FORGET-SFAS  ( hdr-dp )
  << (finfo-tail^) @ dup not?v| drop |?
     over ( hdr-dp ft hdr-dp ) u< ?v||
     system:last-used-fref:!0
     (finfo-tail^) @ system:finfo>prev @ (finfo-tail^) ! ^|| >> drop ;

;; "forget-xfa" must be XFA of the word we are going to forget
: FIX-LATEST-XFA  ( forget-xfa )
  >r forth::(last-xfa) @ << dup r@ u>= ?^| @ |? v|| >> rdrop forth::(last-xfa) ! ;

;; move owner vocid latest to the next latest
: FIX-VOCLATEST  ( bfa )
  dup bfa>vfa @ dup ?< system:vocid>latest swap bfa>lfa @ swap ! || 2drop >? ;

;; "forget-bfa" must be BFA of the word we are going to forget
: FIX-BUCKET  ( forget-bfa bucket )
  swap >r dup @  ( prev curr | forget-bfa )
  << dup ?^|
      dup r@ u>= ?< 2dup @ swap ! ( prev should point to our next)
      dup fix-voclatest || nip dup >? @ |?
  else| 2drop rdrop >> ;

;; "forget-bfa" must be BFA of the word we are going to forget
: FIX-HTABLE  ( forget-bfa )
  dup >r
  dart:bfa>vfa @ system:vocid-hashtbl@
  ( hashtbl^ | bfa )
  dup not?exit< rdrop drop >?
  system:#htable swap
  ( count hashtbl^ | bfa )
  << over ?^| 1 under- r@ over fix-bucket 4+ |?
  else| rdrop 2drop >> ;

;; forget wordlist too.
;; the system usually creates wordlist right before the vocab word header. check for it.
: FIX-VOCAB-ADDR  ( forget-nfa -- hdr-dp )
  dup nfa>lfa lfa>cfa system:vocid@ not?exit< drop >?
  2dup system:voc-vocid-size + = ?< nip || drop >? ;

;; ensure that we don't have protected words in a chain
: ?CHECK-PROTECTED  ( forget-nfa )
  nfa>xfa >r forth::(last-xfa) << dup not?v|| dup r@ u< ?v||
  dup xfa>ffa @ system:wflag-protected and ?error" protected word in forget chain"
  @ ^|| >> rdrop drop ;

: FORGET-NFA  ( forget-nfa )
  ;; we don't have "debug" yet
  dup (elf-hdr-base-addr) hdr-here within not?error" invalid forget address"
  dup ?check-protected
  dup forget-sfas
  dup nfa>xfa fix-latest-xfa
  dup nfa>lfa lfa>bfa fix-htable
  dup nfa>wfa wfa>dfa (dp!)
  fix-vocab-addr (hdr-dp!) ;

end-module FORGET-SUPPORT (private)
[ENDIF]
