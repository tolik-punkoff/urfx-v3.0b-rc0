;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Uroborus: UrForth 32-bit target compiler
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; creating headers, wordlists and such in target image
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
this is low-level tools to create target articles.
target vocabularies are not searched, so we don't have search words here.
*)

;; must be power of 2!
;; experiments show that 1024-item hash table is quite optimal.
;; making is smaller slows down system rebuilding, but making it
;; bigger doesn't have noticeable improvements.
4096 4/ constant tgt-#htable
;; mask masks out 2 low bits, so masked hash can be directly used as offset
tgt-#htable 1- 4* constant tgt-hmask
0 quan tgt-ghtable-va

;; maximum word name length
127 constant tgt-#wname-max

0 quan tgt-current-va   ;; this is actually a uservar, but we'll use default user area
0 quan tgt-context-va   ;; this is actually a uservar, but we'll use default user area
0 quan tgt-voc-link-va
0 quan tgt-xfa-va
0 quan tgt-finfo-tail-va

;; statistics
0 quan tgt-word-count
0 quan tgt-prim-count

;; list of all vocabuilary doer addresses, to avoid iterating.
;; (next, doer-va)
0 quan tgt-vocdoer-list


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; word header format
;;
;; note than name hash is ALWAYS calculated with ASCII-uppercased name
;; (actually, bit 5 is always set for all bytes, because we don't need the
;; exact uppercase, only something that resembles it).
;; bfa points to next bfa or to 0 (this is "hash bucket pointer").
;;
;; i decided to use one huge hash table instead of one hash table per vocab.
;; this still accelerates word searching, yet makes everything simplier.
;; as each word have VFA field, we can easily reject words from vocabs
;; we are not interested in.
;;
;; nfa:
;;   db namelen   ; without padding; bit 7 is "case sensitive" flag
;;   db name      ; no terminating zero or other "termination flag" here
;;   db xnamelen  ; length of the full name field up to this byte
;; nfa ends here; the following field is always dword-aligned
;;   dd namehash  ; bit 0 is "smudge" flag
;;   dd bfa       ; next word in hashtable bucket
;;   dd vfa       ; owner vocid
;;   dd xfa       ; points to the previous word header XFA, regardless of vocabularies (or 0)
;;   dd lfa       ; previous vocabulary word LFA or 0 (lfa links points here)
;;   dd wfa       ; points to code dictionary word header
;;   dd wlen      ; number of bytes to copy when inlining (can be 0)
;;   dd vocid     ; associated wordlist (namespace)
;;   dd optinfo   ; optimiser info block address (or 0)
;; here we can have a debug info. it is present if "[fref^]" is not 0.
;;   dd fref^     ; address of file reference
;;   dw fline#    ; file line
;;   db cmt-len   ; length of the comment string; comment string follows
;;
;; dictionary word header:
;;   dd dfa       ; points to wfa (can be 0 for headerless words)
;;   dd ffa       ; flags and code arg type, see below
;; cfa:
;;   dd cfa-xt    ; our internal CFA address; used for execute
;;   ...here we may have various CFA extended fields...
;; pfa:
;;   word data follows
;;   there is always some machine code for code and Forth words in DTC-FAST version.
;;   this is usually what compiled into threaded code, and what is executed.
;;
;; namehash bit 0 is used as "smudge" flag. it should be 0 for non-smudged words.
;; this way, smudged words always fail hash checks.
;;
;; ffa:
;;   db cfa-size  ; add this to FFA(!) to get to real PFA (skipping whole code prologue)
;;   db argtype
;;   dw flags
;;
;; some flags are mutually exclusive!
;; flags:
;;   bit 0: immediate
;;   bit 1: protected
;;   bit 2: private
;;   bit 3: published word
;;   bit 4: noreturn word
;;   bit 5: inline blocker (using this word will prevent inlining)
;;   bit 6: this word can be inlined
;;   bit 7: this word should always be inlined
;;   bit 8: this word ends with "swap-stacks next"
;;   bit 9: this word doesn't use any stacks (explicitly)
;;   bit 10: dummy word (special word recognized by the compiler)
;;   bit 11: this word has backward jumps (used in inliner)
;;
;; note that all args are padded if necessary, so next address is aligned.
;; argtype:
;;   $00: no args
;;   $01: branch word (code arg is branch address)
;;   $02: literal word (code arg is numeric literal)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; wordlist structure (vocid points here):
;;   dd latest-lfa
;;   dd voc-link (voc-link always points here); "-1" means "not linked"
;;   dd header-nfa (can be 0 for anonymous wordlists)
;;   dd hash-ptr      ; hash table pointer, or 0
;;   dd parent        ; parent vocid or 0
;;   dd find-cfa      ; ( addr count skip-hidden? vocid -- cfa TRUE // FALSE )
;;   dd notfound-cfa  ; ( addr count ) -- called when everything else failed
;;   dd execcomp-cfa  ; ( cfa -- ... TRUE // cfa FALSE ) -- called when the word is found
;;   dd literal-cfa   ; ( lit -- ... TRUE // lit FALSE ) -- called after parsing a literal
;;
;; hash-ptr points to wordlist hash table. this is either 0, GHASH, or custom one.

;; this flag is kept in name length
$80 constant tgt-nflag-case-sens

$ffff_0000 constant tgt-wflag-mask

: tgt-new-wflag  ( fval -- fval*2)  ( name )  dup constant 2* ;
0b0000_0000_0000_0001 65536 *
tgt-new-wflag tgt-wflag-immediate
tgt-new-wflag tgt-wflag-protected
tgt-new-wflag tgt-wflag-private
tgt-new-wflag tgt-wflag-published
tgt-new-wflag tgt-wflag-noreturn
tgt-new-wflag tgt-wflag-inline-blocker
tgt-new-wflag tgt-wflag-inline-allowed
tgt-new-wflag tgt-wflag-inline-force
tgt-new-wflag tgt-wflag-end-swap-next
tgt-new-wflag tgt-wflag-no-stacks
tgt-new-wflag tgt-wflag-dummy-word
tgt-new-wflag tgt-wflag-has-back-jumps
drop

;; flags to leave (via AND) for the new module
tgt-wflag-protected constant tgt-wflag-module-mask

$ff_00 constant tgt-wtype-mask

: tgt-new-wtype  ( fval -- fval+$100)  ( name )  dup constant $100 + ;
0
tgt-new-wtype tgt-wtype-normal
tgt-new-wtype tgt-wtype-branch
tgt-new-wtype tgt-wtype-literal
drop

0b0001
tgt-new-wflag tgt-vocflag-temp
tgt-new-wflag tgt-vocflag-nohash
drop

: tgt-new-vofs  ( fval -- fval+4)  ( name )  dup constant 4+ ;
0
tgt-new-vofs tgt-voc-latest-lfa-ofs
tgt-new-vofs tgt-voc-link-ofs
tgt-new-vofs tgt-voc-header-nfa-ofs
tgt-new-vofs tgt-voc-hash-ptr-ofs
tgt-new-vofs tgt-voc-parent-ofs
tgt-new-vofs tgt-voc-find-cfa-ofs     ( addr count skip-hidden? vocid -- cfa-xt TRUE // FALSE )
tgt-new-vofs tgt-voc-notfound-cfa-ofs ( addr count vocid -- ... TRUE // FALSE )
tgt-new-vofs tgt-voc-execcomp-cfa-ofs ( cfa -- ... TRUE // cfa FALSE )
tgt-new-vofs tgt-voc-literal-cfa-ofs  ( lit -- ... TRUE // lit FALSE )
tgt-new-vofs tgt-voc-vocid-size
drop


tgt-wflag-protected variable tgt-default-ffa

;; if prev word was not a code word, align code word to 64 bytes
false quan tgt-last-created-word-code?


: tgt-mk-wordlist  ( -- tgt-vocid )
  tgt-ghtable-va not?error" cannot create wordlist without GHASH"
  tcom:hdr-align-here -- just in case
  tcom:hdr-here >r  ;; vocid
  0 tcom:hdr,  ;; latest-lfa
  tgt-voc-link-va tcom:@ tcom:hdr,  ;; voc-link
  0 tcom:hdr,  ;; header-nfa
  tgt-ghtable-va tcom:hdr,  ;; hash-ptr
  0 tcom:hdr,  ;; parent
  0 tcom:hdr,  ;; find cfa
  0 tcom:hdr,  ;; notfound cfa
  0 tcom:hdr,  ;; execcomp cfa
  0 tcom:hdr,  ;; literal cfa
  r> dup tgt-voc-link-ofs + tgt-voc-link-va tcom:! ;


: ?tgt-vocid-empty  ( vocid-va -- flag )
  tgt-voc-latest-lfa-ofs + tcom:@ ?error" wordlist must be empty " ;

: tgt-vocid-hashed?  ( vocid-va -- flag )
  tgt-voc-hash-ptr-ofs + tcom:@ 0<> ;

: tgt-vocid-nohash!  ( vocid-va )
  dup tgt-vocid-hashed? not?exit< drop >? dup ?tgt-vocid-empty
  tgt-voc-hash-ptr-ofs + 0 swap tcom:! ;

: tgt-vocid-parent@  ( vocid -- parent-vocid )  tgt-voc-parent-ofs + tcom:@ ;
: tgt-vocid-parent!  ( parent-vocid vocid )     tgt-voc-parent-ofs + tcom:! ;

: tgt-current@  ( -- va )  tgt-current-va tcom:@ ;
: tgt-current!  ( -- va )  tgt-current-va tcom:! ;

: tgt-vocid>latest  ( vocid -- latest-lfa^)  tgt-voc-latest-lfa-ofs + ;


0 variable last-used-fref-va

: tgt-ref-uidx=  ( uidx0 uidx1 ref^ -- flag )
  rot over tcom:@ =  nrot 4+ tcom:@ =  and ;

: tgt-fname-remove-./  ( addr count -- addr count )
  dup 2 <= ?exit over c@ [char] . <> ?exit
  over 1+ c@ string:path-delim? ?exit< string:/2chars >? ;

: tgt-ref-fname  ( -- addr count )
  inc-fname tgt-fname-remove-./ 255 string:trunc-left ;

: tgt-new-file-ref  ( -- va )
    \ ." URB: new fref!: " inc-fname type cr
  tcom:hdr-here
  inc-uidx swap tcom:hdr, tcom:hdr, tgt-finfo-tail-va tcom:@ tcom:hdr,
  tgt-ref-fname dup tcom:hdr-c, tcom:hdr-cstr, dup tgt-finfo-tail-va tcom:!
  dup last-used-fref-va ! ;

: tgt-file-ref  ( -- va )
  inc-uidx 2dup or not?exit< drop >?  ( uidx0 uidx1 )
  last-used-fref-va @ dup ?< >r 2dup r> tgt-ref-uidx= ?exit< 2drop last-used-fref-va @ >? || drop >?
  tgt-finfo-tail-va tcom:@ << dup not?v|| >r 2dup r@ tgt-ref-uidx= ?exit< 2drop r@ last-used-fref-va ! r> >?
  r> 8 + tcom:@ ^|| >> 3drop tgt-new-file-ref ;


;; create debug info, patch SFA
;; debug info format (SFA points to it):
;;   dd fileref-addr
;;   dw file-line
;;   db stack-info-string-count
;;     ... stack info string ...
;; we are creating an empty string now, and will fix it in ":"
: tgt-create-debug-info  ( fref-va )
  dup tcom:hdr,   ;; fileref-addr
  not?exit
  inc-line# 65535 umin tcom:hdr-w,  ;; file line
  0 tcom:hdr-c, ( no comment string ) ;


0 quan tgt-(uptable)  ;; NOT a virtual address

;; last bit is always 0
: tgt-hash-name  ( addr count -- hash )
  [ tgt-use-system-name-hash ] [IF] system:hash-name
  [ELSE]
  dup +?<
    $29a >r swap <<
      over +?^| 1 under- c@++
      [ tgt-precise-nhash ] [IF]
        tgt-(uptable) + c@
      [ELSE]
        $20 or
      [ENDIF]
      r> + dup 10 lshift + dup 6 rshift xor >r |?
      else| 2drop >>
    r> dup 3 lshift + dup 11 rshift xor dup 15 lshift + ( final mix )
    1 ~and  ;; last bit must be 0
  || 2drop $01 ( special hash value ) >?
  [ENDIF] ;

;; name start need not to be aligned on a dword boundary
;; (because we rarely compare names anyway)
: tgt-mk-header-align  ( namelen )
  tcom:hdr-here + 2+  ;; initial length, final length
  4 swap - 3 and tcom:hdr-reserve ;

;; link word to the current vocab hash
: tgt-mk-bfa  ( hash -- bfa )
  dup 1 and not?< tgt-hmask and tgt-ghtable-va + dup
                  tcom:@ tcom:hdr-here rot tcom:! || drop 0 >? tcom:hdr, ;

;; up to (but not including) CFA
: (tgt-mk-header-ex)  ( addr count -- nfa )
  dup tgt-#wname-max u> ?error" invalid word name"
\ 2dup type cr
  ;; save file ref addr for debug area
  ;; need to do it here, because a new file ref may be created
  dup ?< tgt-file-ref || 0 >? >r
  dup tgt-mk-header-align
  tcom:hdr-here r> swap >r >r ;; remember nfa address
  2dup tgt-hash-name nrot ;; we'll need the hash later
  dup tcom:hdr-c, 2dup tcom:hdr-cstr, 1+ tcom:hdr-c, drop
  tcom:hdr-here 3 and ?error" invalid header alignment"
  dup tcom:hdr,   ;; namehash
  tgt-current@ tgt-vocid-hashed? ?< tgt-mk-bfa || drop 0 tcom:hdr, >?  ;; bfa
  tgt-current@ tcom:hdr,  ;; vfa
  tcom:hdr-here tgt-xfa-va dup tcom:@ tcom:hdr, tcom:!  ;; xfa
  tcom:hdr-here tgt-current@ tgt-voc-latest-lfa-ofs + dup tcom:@ tcom:hdr, tcom:!  ;; lfa
  tcom:hdr-here tcom:here tcom:hdr, ;; wfa
  0 tcom:hdr, ;; wlen
  0 tcom:hdr, ;; vocid
  0 tcom:hdr, ;; optinfo
  r> tgt-create-debug-info
  ;; now in code dictionary
  tcom:,      ;; dfa
  tgt-default-ffa @ $7fff_ff00 and tcom:,  ;; ffa; cfa-extra length is 0 (unknown) yet
  r> tgt-word-count:1+! ;

(*
: tgt-align-code  ( align )
  dup 1+ +?<
    [ tgt-align-cfa ] [IF]
      ;; special align for code area: dfa and ffa should be *before* the real alignment
      ;; only has sense for align >4
      dup 4 > ?<  ;; we can simply allocate 8 bytes, then align, then backtrack
        0 tcom:, 0 tcom:, tcom:xalign -8 tcom:allot
      || tcom:xalign >?
    [ELSE]
      tcom:xalign
    [ENDIF]
  || drop >? ;

;; we rarely need CFA area in constants and variables, so...
;; only has sense for align >4
: tgt-align-code-var  ( align )
  [ 1 ] [IF] tgt-align-code
  [ELSE]
  dup 4 <= ?< tgt-align-code
  || ;; special align for code area: dfa, ffa and cfa should be *before* the real alignment
     ;; we can simply allocate 16 bytes, then align, then backtrack
     ;; (16, because CFA is 5+3 bytes)
     0 tcom:, 0 tcom:, 0 tcom:, 0 tcom:, tcom:xalign -16 tcom:allot >?
  [ENDIF] ;
*)

;; also sets the flag
: tgt-align-dict  ( new-is-code? )
  dup tgt-last-created-word-code? = ?< 4 || 64 >? tcom:xalign
  tgt-last-created-word-code?:! ;


: (tgt-mk-header-mccode)  ( addr count -- nfa )
  \ tcom:code-align tgt-align-code
  true tgt-align-dict
  (tgt-mk-header-ex) ;

: (tgt-mk-header-forth)  ( addr count -- nfa )
  \ tcom:forth-align tgt-align-code
  true tgt-align-dict
  (tgt-mk-header-ex) ;

: tgt-mk-header-mccode  ( addr count -- nfa )
  dup 0<= ?error" invalid word name" (tgt-mk-header-mccode) ;

: tgt-mk-header-forth  ( addr count -- nfa )
  dup 0<= ?error" invalid word name" (tgt-mk-header-forth) ;

\ : tgt-mk-header-4  ( addr count -- nfa )
\   dup 0<= ?error" invalid word name"
\   4 tgt-align-code (tgt-mk-header-ex) ;

: tgt-mk-header-var-align  ( addr count -- nfa )
  dup 0<= ?error" invalid word name"
  \ tcom:var-align tgt-align-code-var
  false tgt-align-dict
  (tgt-mk-header-ex) ;

: tgt-mk-header-create-align  ( addr count -- nfa )
  dup 0<= ?error" invalid word name"
  \ tcom:code-align tgt-align-code-var
  false tgt-align-dict
  (tgt-mk-header-ex) ;

: tgt-mk-header-const-align  ( addr count -- nfa )
  dup 0<= ?error" invalid word name"
  \ tcom:const-align tgt-align-code
  false tgt-align-dict
  (tgt-mk-header-ex) ;


: tgt-nfaend>nfa  ( nfaend -- nfa )  dup tcom:c@ - ;

: tgt-wfa>dfa     ( wfa -- dfa )     tcom:@ ;
: tgt-wfa>nfa     ( wfa -- nfa )     [ 5 4* 1+ ] {#,} - tgt-nfaend>nfa ;
: tgt-wfa>lfa     ( wfa -- lfa )     [ 1 4* ] {#,} - ;
: tgt-wfa>xfa     ( wfa -- xfa )     [ 2 4* ] {#,} - ;
: tgt-wfa>wlen    ( wfa -- wlen^)    [ 1 4* ] {#,} + ;
: tgt-wfa>vocid   ( wfa -- vocid)    [ 2 4* ] {#,} + ;
: tgt-wfa>optinfo ( wfa -- optinfo ) [ 3 4* ] {#,} + ;

: tgt-dfa>wfa  ( dfa -- nfa )  tcom:@ ;
: tgt-dfa>ffa  ( dfa -- ffa )  [ 1 4* ] {#,} + ;
: tgt-dfa>cfa  ( dfa -- cfa )  [ 2 4* ] {#,} + ;

: tgt-bfa>vfa  ( bfa -- vfa )  [ 1 4* ] {#,} + ;
: tgt-bfa>wfa  ( bfa -- wfa )  [ 4 4* ] {#,} + ;
: tgt-bfa>dfa  ( bfa -- dfa )  tgt-bfa>wfa tgt-wfa>dfa ;
: tgt-bfa>ffa  ( bfa -- ffa )  tgt-bfa>dfa tgt-dfa>ffa ;

: tgt-xfa>nfa  ( xfa -- nfa )  [ 3 4* 1+ ] {#,} - tgt-nfaend>nfa ;
: tgt-xfa>bfa  ( xfa -- bfa )  [ 2 4* ] {#,} - ;
: tgt-xfa>lfa  ( xfa -- lfa )  [ 1 4* ] {#,} + ;
: tgt-xfa>wfa  ( xfa -- wfa )  [ 2 4* ] {#,} + ;
: tgt-xfa>cfa  ( xfa -- bfa )  tgt-xfa>wfa tgt-wfa>dfa tgt-dfa>cfa ;

: tgt-nfa>lfa  ( nfa -- lfa )  dup tcom:c@ $7F and + [ 4 4* 2+ ] {#,} + ;

: tgt-ffa>pfa  ( ffa -- pfa )  dup tcom:c@ ( extpfa ) + ;

: tgt-lfa>xfa  ( lfa -- nfa )  [ 1 4* ] {#,} - ;
: tgt-lfa>wfa  ( lfa -- wfa )  [ 1 4* ] {#,} + ;
: tgt-lfa>sfa  ( lfa -- sfa )  [ 5 4* ] {#,} + ;
: tgt-lfa>dfa  ( lfa -- dfa )  tgt-lfa>wfa tgt-wfa>dfa ;
: tgt-lfa>nfa  ( lfa -- nfa )  tgt-lfa>xfa tgt-xfa>nfa ;
: tgt-lfa>ffa  ( lfa -- ffa )  tgt-lfa>dfa tgt-dfa>ffa ;
: tgt-lfa>cfa  ( lfa -- cfa )  tgt-lfa>dfa tgt-dfa>cfa ;
: tgt-lfa>pfa  ( lfa -- pfa )  tgt-lfa>dfa tgt-dfa>ffa tgt-ffa>pfa ;

: tgt-cfa>lfa     ( cfa -- lfa )    tgt-dfa>wfa tgt-wfa>lfa ;
: tgt-cfa>dfa     ( cfa -- dfa )    [ 2 4* ] {#,} - ;
: tgt-cfa>ffa     ( cfa -- lfa )    [ 1 4* ] {#,} - ;
: tgt-cfa>pfa     ( cfa -- pfa )    tgt-cfa>ffa tgt-ffa>pfa ;
: tgt-cfa>wfa     ( cfa -- wfa )    tgt-cfa>dfa tgt-dfa>wfa ;
: tgt-cfa>nfa     ( cfa -- nfa )    tgt-cfa>wfa tgt-wfa>nfa ;
: tgt-cfa>wlen    ( cfa -- wlen^)   tgt-cfa>wfa tgt-wfa>wlen ;
: tgt-cfa>optinfo ( cfa -- optinfo) tgt-cfa>wfa tgt-wfa>optinfo ;

: tgt-latest-lfa     ( -- lfa )    tgt-current@ tgt-voc-latest-lfa-ofs + tcom:@ ;
: tgt-latest-nfa     ( -- nfa )    tgt-latest-lfa tgt-lfa>nfa ;
: tgt-latest-cfa     ( -- cfa )    tgt-latest-lfa tgt-lfa>cfa ;
: tgt-latest-ffa     ( -- cfa )    tgt-latest-lfa tgt-lfa>ffa ;
: tgt-latest-pfa     ( -- pfa )    tgt-latest-lfa tgt-lfa>pfa ;
: tgt-latest-vocid   ( -- vocid)   tgt-latest-lfa tgt-lfa>wfa tgt-wfa>vocid ;
: tgt-latest-wlen    ( -- ilen )   tgt-latest-lfa tgt-lfa>wfa tgt-wfa>wlen ;
: tgt-latest-optinfo ( -- optinfo) tgt-latest-lfa tgt-lfa>wfa tgt-wfa>optinfo ;

: tgt-latest-ffa-or!   ( val )  tgt-latest-ffa dup tcom:@ rot or swap tcom:! ;
: tgt-latest-ffa-~and! ( val )  tgt-latest-ffa dup tcom:@ rot ~and swap tcom:! ;


7 constant tgt-sfa-#headers

: tgt-can-extend-sfa?  ( -- flag )
  tgt-latest-lfa tgt-lfa>sfa
  dup tcom:@ not?exit< drop false >?
  tgt-sfa-#headers + tcom:hdr-here = ;

;; flag: 0 -- no; 1: until EOL; -1: parens
: tgt-skip-word-comment  ( -- had-comments-flag )
  parse-name/none 1- ?exit< drop false >?
  c@ dup $5C = ?exit< drop skip-line 1 >?
  $28 = not?exit&leave
  $29 parse dup not?exit +?< 2drop false || 2drop true >? ;

: tgt-collect-word-comments  ( -- addr count )
  skip-spaces (tib-in) >r
  tgt-skip-word-comment dup not?exit< r> swap drop false >?
  +?exit< r@ (tib-in) r> - >?
  ;; optional second comment
  (tib-in) >r  ( staddr st2addr )
  tgt-skip-word-comment ?< rdrop r@ (tib-in) || r1:@ r> >? r> - ;

: tgt-debug-record-comment
  tgt-build-base-binary ?exit
  tgt-can-extend-sfa? not?exit
  tgt-save-stack-comments not?exit
  >in >r
  tgt-collect-word-comments string:-trailing 254 min
    \ ." comments: |" 2dup type ." |\n"
  dup ?< dup tcom:hdr-here 1- tcom:c! ;; save length
         tcom:hdr-cstr, ;; save string
  || 2drop >? r> >in:! ;


;; remove bucketed words using the given predicate
: tgt-clean-bucket  ( vocid bucket flag-check-cfa )
  >r swap >r dup tcom:@  ( prev curr | check-cfa vocid )
  << dup ?^|
      dup tgt-bfa>ffa tcom:@ r1:@ execute ?<
        dup tgt-bfa>vfa tcom:@ r@ = ?< 2dup tcom:@ swap tcom:! ( prev should point to our next)
          \ dup bfa>nfa c@++ 127 and type cr
        || nip dup >?
      || nip dup >? tcom:@ |?
  else| 2drop 2rdrop >> ;

;; remove words from LFA links; used for non-hashed dicts
: tgt-unlink-lfas  ( vocid flag-check-cfa )
\ 2drop exit
  >r tgt-vocid>latest dup tcom:@ << ( prev-lfa^ curr-lfa | checker-cfa )
    dup not?v||
    dup tgt-lfa>ffa tcom:@ r@ execute
    ?< \ endcr ." === removing |" dup tgt-lfa>nfa tcom:>real debug:.id ." |\n"
       2dup tcom:@ swap tcom:!
    || nip dup >? tcom:@
  ^|| >> rdrop 2drop ;

;; process all hash table buckets
: tgt-clean-vocid  ( vocid flag-check-cfa )
  2dup tgt-unlink-lfas
  >r >r tgt-#htable tgt-ghtable-va <<
    over ?^| 1 under- r@ over r1:@ tgt-clean-bucket 4+ |?
    else| 2rdrop 2drop >> ;

: tgt-flg-private?  ( flag -- nzres )  tgt-wflag-private and ;
: tgt-remove-vocid-private  ( vocid )  ['] tgt-flg-private? tgt-clean-vocid ;

: tgt-flg-not-published?  ( flag -- nzres )  tgt-wflag-published not-mask? ;
: tgt-remove-vocid-non-published  ( vocid )  ['] tgt-flg-not-published? tgt-clean-vocid ;


;; write "branch to destaddr" address to addr
: (tgt-branch-addr!)  ( destaddr addr )  tuck 4+ - swap tcom:! ;
;; read branch address
: (tgt-branch-addr@)  ( addr -- dest )  dup tcom:@ + 4+ ;

: (tgt-branch-addr,)  ( addr )  tcom:here 0 tcom:, (tgt-branch-addr!) ;


: tgt-set-last-word-length
  tcom:here tgt-latest-cfa dup >r -
    dup 0<= ?error" empty word! wtf?!"
    r> tgt-cfa>wlen tcom:! ;

\ tgt-latest-nfa tcom:>real debug:.id
\ tgt-latest-ilen tcom:@ bl emit ., ." bytes.\n"


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get CFA contents; should be different for different threaded code models

: tgt-cfa@  ( cfa -- jumpaddr )
  dup tcom:c@ $E8 - ?exit< drop false >?
  1+ (tgt-branch-addr@) ;
