;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; article headers creation
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


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
;;                ; if this points to code dictinary, this is direct optcfa
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
;;   bit 11: this word was tail-call optimised (used by inliner)
;;   bit 12: this word doesn't have any CALL/JMP instructions to patch (used by inliner)
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
;;   dd notfound-cfa  ; ( addr count -- processed-flag ) -- called when everything else failed
;;   dd execcomp-cfa  ; ( cfa -- ... TRUE // cfa FALSE ) -- called when the word is found
;;   dd literal-cfa   ; ( lit -- ... TRUE // lit FALSE ) -- called after parsing a literal
;;
;; hash-ptr points to wordlist hash table. this is either 0, GHASH, or custom one.

extend-module SYSTEM

;; special flag for "mk-header"
$8000_0000 constant fflag-case-sens

;; this is VARIABLE for a reason (to use "and!" and such)
0 variable DEFAULT-FFA
vect-empty REDEFINE-CHECK  ( addr count -- addr count )


: LATEST-FFA-OR!   ( val )  latest-ffa or! ;
: LATEST-FFA-~AND! ( val )  latest-ffa ~and! ;

: CSTR,  ( addr count )  swap << over +?^| 1 under- c@++ c, |? else| 2drop >> ;
: CSTRZ, ( addr count )  cstr, 0 c, ;
: RESV   ( count )  << dup +?^| 0 c, 1- |? else| drop >> ;

: HDR-CSTR,  ( addr count )  swap << over +?^| 1 under- c@++ hdr-c, |? else| 2drop >> ;
: HDR-RESV   ( count )  << dup +?^| 0 hdr-c, 1- |? else| drop >> ;


: VOCID>LNK     ( vocid -- hdrfl )  voc-link-ofs + ;
: VOCID>RFA     ( vocid -- hdrfl )  voc-header-nfa-ofs + ;
\ : VOCID>FFA     ( vocid -- hdrfl )  voc-flags-ofs + ;
: VOCID>HASHPTR ( vocid -- hash-ptr^ ) voc-hash-ptr-ofs + ;
: VOCID>PARENT  ( vocid -- parent^ )  voc-parent-ofs + ;
: VOCID>LATEST  ( vocid -- lfa^ )  voc-latest-lfa-ofs + ;
: VOCID-LATEST  ( vocid -- lfa )  vocid>latest @ ;
: VOCID-PARENT! ( parent-vocid vocid )     vocid>parent ! ;
: VOCID-PARENT@ ( vocid -- parent-vocid )  vocid>parent @ ;

: VOCID-RFA@    ( vocid -- hdrfl // 0 )  vocid>rfa @ ;

: VOCID-FIND-CFA@  ( vocid -- cfa // 0 )  voc-find-cfa-ofs + @ ;
: VOCID-FIND-CFA!  ( cfa vocid )  voc-find-cfa-ofs + ! ;

: VOCID-NOTFOUND-CFA@  ( vocid -- cfa // 0 )  voc-notfound-cfa-ofs + @ ;
: VOCID-NOTFOUND-CFA!  ( cfa vocid )  voc-notfound-cfa-ofs + ! ;

: VOCID-EXECCOMP-CFA@  ( vocid -- cfa // 0 )  voc-execcomp-cfa-ofs + @ ;
: VOCID-EXECCOMP-CFA!  ( cfa vocid )  voc-execcomp-cfa-ofs + ! ;

: VOCID-LITERAL-CFA@  ( vocid -- cfa // 0 )  voc-literal-cfa-ofs + @ ;
: VOCID-LITERAL-CFA!  ( cfa vocid )  voc-literal-cfa-ofs + ! ;

;; link to the global list
: VOCLINK-WORDLIST  ( vocid )
  vocid>lnk dup @ -1 <> ?error" wordlist already linked"
  voc-link @ over ! voc-link ! ;

;; not linked to the global list
: MK-LONE-WORDLIST  ( -- vocid )  \ creates wordlist in headers segment
  hdr-align-here hdr-here ;; vocid
  0 hdr,  ;; latest-lfa
  -1 hdr, ;; voc-link
  0 hdr,  ;; header-nfa
  (ghtable) hdr,  ;; default hash-ptr: global hash table
  0 hdr,  ;; parent
  0 hdr,  ;; find cfa
  0 hdr,  ;; notfound cfa
  0 hdr,  ;; execcomp cfa
  0 hdr,  ;; literal cfa
  ( done ) ;

: MK-WORDLIST  ( -- vocid )
  mk-lone-wordlist dup voclink-wordlist ;

: ?VOCID-EMPTY  ( vocid -- flag )
  vocid-latest ?error" wordlist must be empty " ;

: VOCID-HASHTBL@ ( vocid -- htbl^ // 0 )  vocid>hashptr @ ;
: VOCID-HASHED?  ( vocid -- flag )  vocid-hashtbl@ 0<> ;
: VOCID-TEMP?    ( vocid -- flag )  vocid>lnk @ -1 = ;

: VOCID-NOHASH!  ( vocid )
  dup vocid-hashed? not?exit< drop >?
  dup ?vocid-empty
  vocid>hashptr !0 ;

;; create separate hash table in header area
: VOCID-SEPARATE-HASH!  ( vocid )
  ;; check if it is not used ghash already
  dup vocid-hashed? ?< dup vocid-hashtbl@ (ghtable) = not?exit< drop >? >?
  dup ?vocid-empty
  hdr-align-here
  hdr-here
  #htable << 0 hdr, 1- dup ?^|| else| drop >>
  swap vocid>hashptr ! ;

: MK-WORDLIST-NOHASH  ( -- vocid )
  mk-lone-wordlist dup voclink-wordlist dup vocid-nohash! ;

;; it is enough to not link the wordlist to make it temporary.
;; temp wordlists are not using hash table too.
: MK-WORDLIST-TEMP  ( -- vocid )
  mk-lone-wordlist dup vocid-nohash! ;


;; last bit is always 0
: HASH-NAME  ( addr count -- hash )
  dup +?<
    $29a >r swap <<
      over +?^| 1 under- c@++
      [ tgt-precise-nhash ] [IF]
        (sys-uptable) + c@
      [ELSE]
        $20 or
      [ENDIF]
      r> + dup 10 lshift + dup 6 rshift xor >r |?
      else| 2drop >>
    r> dup 3 lshift + dup 11 rshift xor dup 15 lshift + ( final mix )
    1 ~and  ;; last bit must be 0
  || 2drop $01 ( special hash value ) >? ;


0 quan LAST-USED-FREF
vect (INC-FNAME^)
vect (INC-UIDX^)
vect (INC-LINE#^)

(* file info:
  dd uid0, uid1
  dd prev
  byte-counted string
*)

: FINFO>UIDX   ( fi -- uidx^ )  ;
: FINFO>PREV   ( fi -- prev^ )  8 + ;
: FINFO>NAME   ( fi -- name^ )  12 + ;
: FINFO-NAME@  ( name -- addr count )  c@++ ;

: REF-UIDX=  ( uidx0 uidx1 ref^ -- flag )
  rot over @ =  nrot 4+ @ =  and ;

: FNAME-REMOVE-./  ( addr count -- addr count )
  dup 2 <= ?exit over c@ [char] . <> ?exit
  over 1+ c@ string:path-delim? ?exit< string:/2chars >? ;

: REF-FNAME  ( -- addr count )
  (inc-fname^) fname-remove-./ 255 string:trunc-left ;

: NEW-FILE-REF  ( -- addr )
    \ ." new fref!: " (inc-fname^) type cr
  hdr-here (inc-uidx^) swap hdr, hdr, (finfo-tail^) @ hdr,
  ref-fname dup hdr-c, hdr-cstr, dup (finfo-tail^) !
  dup last-used-fref:! ;

: CACHED-FILE-REF?  ( uidx0 uidx1 -- addr TRUE // FALSE )
  last-used-fref dup not?exit< 3drop 0 >?
  ref-uidx= not?exit&leave
  last-used-fref true ;

: FIND-FILE-REF  ( uidx0 uidx1 -- addr TRUE // FALSE )
  (finfo-tail^) @ <<
    dup not?v| 3drop false |?
    >r 2dup r@ ref-uidx= ?v| 2drop r> true |?
    ^| r> finfo>prev @ | >> ;

: FILE-REF  ( -- addr//0 )
  (inc-uidx^) 2dup or not?exit< drop >?  ( uidx0 uidx1 )
  2dup cached-file-ref? ?exit< nrot 2drop >?
  find-file-ref ?< dup last-used-fref:! || new-file-ref >? ;

;; link word to the current vocab hash
: MK-BFA  ( hash -- bfa )
  dup 1 and not?< hmask and current@ vocid-hashtbl@ + dup @ hdr-here rot ! || drop 0 >? hdr, ;

;; name start need not to be aligned on a dword boundary
;; (because we rarely compare names anyway)
: MK-HEADER-ALIGN  ( namelen )
  hdr-here + 2+  ;; initial length, final length
  4 swap - 3 and hdr-resv ;

;; create debug info, patch SFA
;; debug info format (SFA points to it):
;;   dd fileref-addr
;;   dw file-line
;;   db stack-info-string-count
;;     ... stack info string ...
;; we are creating an empty string now, and will fix it in ":"
: CREATE-DEBUG-INFO  ( fref^ )
  dup hdr,  ;; fileref-addr
  not?exit
  (inc-line#^) 65535 umin hdr-w,  ;; file line
  0 hdr-c, ( no comment string ) ;

uro-constant@ tgt-sfa-#headers constant SFA-#HEADERS

: CAN-EXTEND-SFA?  ( -- flag )
  latest-lfa dart:lfa>sfa dup @ not?exit< drop false >?
  sfa-#headers + hdr-here = ;

;; up to (but not including) CFA
: (MK-HEADER-EX)  ( addr count )
  dup 0 #wname-max bounds not?error" invalid word name"
  2dup redefine-check
  ;; save file ref addr for debug area
  ;; need to do it here, because a new file ref may be created
  dup ?< file-ref || 0 >?
  >r
  dup mk-header-align
  2dup hash-name nrot ;; we'll need the hash later
  dup default-ffa @ fflag-case-sens and ?< $80 or >? hdr-c, ;; initial length
  2dup hdr-cstr, 1+ hdr-c, drop
  hdr-here 3 and ?error" invalid header align"
  dup hdr,      ;; namehash
  current@ vocid-hashed? ?< mk-bfa || drop 0 hdr, >?
  current@ hdr, ;; vfa
  ;; xfa
  current@ vocid-temp? ?< 0 hdr, || hdr-here forth::(last-xfa) dup @ hdr, ! >?
  hdr-here current@ vocid>latest dup @ hdr, ! ;; lfa
  hdr-here here hdr,  ;; wfa
  ;; done with wfa
  0 hdr,  ;; wlen
  0 hdr,  ;; vocid
  0 hdr,  ;; optinfo
  r> create-debug-info
  ;; now in code dictionary
  , ;; dfa
  [ 0 ] [IF] endcr ."  CREATED |" latest-nfa idcount type ." | with flags=$" default-ffa @ .hex8 cr [ENDIF]
  default-ffa @ $7fff_ff00 and
  , (+ ffa; cfa-extra length is 0 (unknown) yet +) ;

(*
: ALIGN-CODE  ( align )
  dup 1+ +?<
    [ tgt-align-cfa ] [IF]
      ;; special align for code area: dfa and ffa should be *before* the real alignment
      ;; only has sense for align >4
      dup 4 > ?<  ;; we can simply allocate 8 bytes, then align, then backtrack
        0 , 0 , n-align-here -8 (dp+!)
      || n-align-here >?
    [ELSE]
      n-align-here
    [ENDIF]
  || drop >? ;

;; we rarely need CFA area in constants and variables, so...
;; only has sense for align >4
: ALIGN-CODE-VAR  ( align )
  [ 1 ] [IF] align-code
  [ELSE]
  dup 4 <= ?< align-code
  || ;; special align for code area: dfa, ffa and cfa should be *before* the real alignment
     ;; we can simply allocate 16 bytes, then align, then backtrack
     ;; (16, because CFA is 5+3 bytes)
     0 , 0 , 0 , 0 , n-align-here -16 (dp+!) >?
  [ENDIF] ;


: (MK-HEADER)    ( addr count )  system:forth-align align-code (mk-header-ex) ;
: (MK-HEADER-0)  ( addr count )  (mk-header-ex) ;
: (MK-HEADER-4)  ( addr count )  4 align-code (mk-header-ex) ;
: (MK-HEADER-VV) ( addr count )  system:var-align align-code-var (mk-header-ex) ;
: (MK-HEADER-CV) ( addr count )  system:const-align align-code-var (mk-header-ex) ;
: (MK-HEADER-FV) ( addr count )  system:forth-align align-code-var (mk-header-ex) ;
: (MK-HEADER-XV) ( addr count )  system:forth-align align-code (mk-header-ex) ;

;; doesn't allow creating words with empty names
: MK-HEADER    ( addr count )  dup 0<= ?error" invalid word name" (mk-header) ;
: MK-HEADER-0  ( addr count )  dup 0<= ?error" invalid word name" (mk-header-0) ;
: MK-HEADER-4  ( addr count )  dup 0<= ?error" invalid word name" (mk-header-4) ;
: MK-HEADER-VV ( addr count )  dup 0<= ?error" invalid word name" (mk-header-vv) ;
: MK-HEADER-CV ( addr count )  dup 0<= ?error" invalid word name" (mk-header-cv) ;
: MK-HEADER-FV ( addr count )  dup 0<= ?error" invalid word name" (mk-header-fv) ;
: MK-HEADER-XV ( addr count )  dup 0<= ?error" invalid word name" (mk-header-xv) ;
*)

;; if prev word was not a code word, align code word to 64 bytes
false quan LAST-CREATED-WORD-CODE?

;; also sets the flag
: ALIGN-DICT  ( new-is-code? )
  dup last-created-word-code? = ?< 4 || 64 >? n-align-here
  last-created-word-code?:! ;

\ : MK-HEADER    ( addr count )  dup 0<= ?error" invalid word name" (mk-header) ;
: MK-HEADER-CREATE ( addr count )  dup 0<= ?error" invalid word name" false align-dict (mk-header-ex) ;
: MK-HEADER-CODE   ( addr count )  dup 0<= ?error" invalid word name" true align-dict (mk-header-ex) ;
: MK-HEADER-FORTH  ( addr count )  dup 0<= ?error" invalid word name" true align-dict (mk-header-ex) ;
: MK-HEADER-CONST  ( addr count )  dup 0<= ?error" invalid word name" false align-dict (mk-header-ex) ;
: MK-HEADER-VAR    ( addr count )  dup 0<= ?error" invalid word name" false align-dict (mk-header-ex) ;
: MK-HEADER-USRVAR ( addr count )  dup 0<= ?error" invalid word name" false align-dict (mk-header-ex) ;
: MK-HEADER-BUILDS ( addr count )  dup 0<= ?error" invalid word name" false align-dict (mk-header-ex) ;
: MK-HEADER-NONAME                 " " false align-dict (mk-header-ex) ;


;; bit 0 of name hash is always 0 for non-smudged names
: SET-SMUDGE    1 latest-hfa or! ;
: RESET-SMUDGE  1 latest-hfa ~and! ;

: RESET-PUBLISHED-FLAG  wflag-published default-ffa ~and! ;

: OR-WORD-FLAGS-NP   ( flg )  default-ffa or! reset-published-flag ;
: ~AND-WORD-FLAGS-NP ( flg )  default-ffa ~and! reset-published-flag ;

: RESET-LATEST-VISIBILITY [ wflag-private wflag-published or ] {#,} latest-ffa-~and! ;

end-module SYSTEM


: IMMEDIATE   system:wflag-immediate system:latest-ffa xor! ;
: (PRIVATE)   system:reset-latest-visibility system:wflag-private system:latest-ffa-or! ;
: (PUBLIC)    system:reset-latest-visibility ;
: (PUBLISHED) system:reset-latest-visibility system:wflag-published system:latest-ffa-or! ;
: (PROTECTED) system:wflag-protected system:latest-ffa-or! ;
: (NORETURN)  system:wflag-noreturn system:latest-ffa-or! ;
: (CASE-SENSITIVE)  system:latest-lfa dart:lfa>nfa dup c@ $80 xor swap c! ;

: (INLINE-BLOCKER)  system:wflag-inline-blocker system:latest-ffa-or! ;
: (ALLOW-INLINE)    system:wflag-inline-allowed system:latest-ffa-or! ;
: (FORCE-INLINE)    system:wflag-inline-force system:latest-ffa-or! ;
