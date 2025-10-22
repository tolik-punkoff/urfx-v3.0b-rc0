;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; various string and memory scanning words
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module STRING

{no-inline}
: BUILD-ASCII-TABLE  ( addr )
  0 swap << over av-c!++ 1 under+ over 256 < ?^|| else| 2drop >> ;

{no-inline}
|: (ATABLE-32+)  ( addr count )
  << over dup c@ 32 + swap c! 1 under+ 1- dup ?^|| else| 2drop >> ;

{no-inline}
|: (ATABLE-32-)  ( addr count )
  << over dup c@ 32 - swap c! 1 under+ 1- dup ?^|| else| 2drop >> ;

{no-inline}
: BUILD-ASCII-UPTABLE  ( addr )  dup >r build-ascii-table r> 97 + 26 (atable-32-) ;
{no-inline}
: BUILD-ASCII-LOTABLE  ( addr )  dup >r build-ascii-table r> 65 + 26 (atable-32+) ;

{no-inline}
: BUILD-KOI8-UPTABLE  ( addr )
  dup >r build-ascii-uptable r@ 192 + 32 (atable-32+)
  179 r@ 163 + c! 180 r@ 164 + c!
  182 r@ 166 + c! 183 r@ 167 + c!
  189 r> 173 + c! ;

{no-inline}
: BUILD-KOI8-LOTABLE  ( addr )
  dup >r build-ascii-lotable r@ 224 + 32 (atable-32-)
  163 r@ 179 + c! 164 r@ 180 + c!
  166 r@ 182 + c! 167 r@ 183 + c!
  173 r> 189 + c! ;

[[ tgt-build-base-binary ]] [IFNOT]
{no-inline}
: BUILD-1251-UPTABLE  ( addr )
  dup >r build-ascii-uptable r@ 224 + 32 (atable-32-)
  131 r@ 129 + c! 161 r@ 162 + c!
  178 r@ 179 + c! 165 r@ 180 + c!
  169 r@ 184 + c! 170 r@ 186 + c!
  175 r> 191 + c! ;

{no-inline}
: BUILD-1251-LOTABLE  ( addr )
  dup >r build-ascii-lotable r@ 192 + 32 (atable-32+)
  129 r@ 131 + c! 162 r@ 161 + c!
  179 r@ 178 + c! 180 r@ 165 + c!
  184 r@ 169 + c! 186 r@ 170 + c!
  191 r> 175 + c! ;
[ENDIF]


code-naked-inline: UPCHAR  ( ch -- ch )
  movzx utos, bl
  mov   eax, # ll@ (uptable)
  movzx utos, byte^ [eax+] [utos*1]
;code-no-stacks (no-stacks)

code-naked-inline: LOCHAR  ( ch -- ch )
  movzx utos, bl
  mov   eax, # ll@ (lotable)
  movzx utos, byte^ [eax+] [utos*1]
;code-no-stacks (no-stacks)


code-naked-no-inline: MEM=  ( addr1 addr2 size -- equflag )
  lea   usp, [usp+] # 8
  cmp   utos, # 0
  jle   @@9
  mov   ecx, utos
  ;; save in registers, it is faster this way
  mov   edx, esi
  mov   ebx, edi
  mov   edi, [usp+] # -8
  mov   esi, [usp+] # -4
  repz  cmpsb
  mov   edi, ebx
  mov   esi, edx
  setz  bl
  movzx utos, bl
  neg   utos
  beast-nextjmp
@@9:
  mov   utos, # 0
  z? do-when dec utos
;code-next

code-naked-no-inline: MEM=CI  ( addr1 addr2 size -- equflag )
  ;; save in register, it is faster this way
  mov   edx, edi
  mov   edi, [usp]
  mov   esi, [usp+] # 4
  lea   usp, [usp+] # 8
  cmp   utos, # 0
  jle   @@9
  mov   ecx, utos
@@1:
  movzx eax, byte^ [esi]
  movzx ebx, byte^ [edi]
  inc   esi
  inc   edi
  movzx eax, byte^ [eax+] # ll@ (uptable)
  movzx ebx, byte^ [ebx+] # ll@ (uptable)
  cmp   al, bl
  jnz   @@2
  dec   ecx
  jnz   @@1
  mov   edi, edx
  mov   utos, # -1
  beast-nextjmp
@@2:
  xor   utos, utos
  mov   edi, edx
  beast-nextjmp
@@9:
  mov   utos, # 0
  z? do-when dec utos
  mov   edi, edx
;code-next

: =CI ( addr0 count0 addr1 count1 -- flag )  rot over - ?< 3drop false || mem=ci >? ;
: ==  ( addr0 count0 addr1 count1 -- flag )  rot over - ?< 3drop false || mem= >? ;

;; search the string specified by addr size for the char ch.
;; if flag is true, a match was found at addr1 with size1 characters remaining.
;; if flag is false there was no match and addr1 is addr and size1 is size.
;; if size1 is <=0, flag is always false
code-naked-no-inline: MEMCHR  ( addr size ch -- addr1 size1 found-flag? )
  mov   eax, utos
  mov   ecx, [usp]   ;; size
  cmp   ecx, # 0
  jle   @@9
  push  edi
  mov   edi, [usp+] # 4 ;; addr
  repnz scasb
  jnz   @@8
  dec   edi
  inc   ecx
  mov   [usp], ecx
  mov   [usp+] 4 #, edi
  pop   edi
  mov   utos, # -1
  beast-nextjmp
@@8:
  pop   edi
@@9:
  xor   utos, utos
;code-next


;; search the string specified by addr size for the char ch
code-swap-no-inline: FIND-CH  ( addr size ch -- offset TRUE // FALSE )
  mov   eax, utos
  pop   ecx         ;; size
  pop   edx         ;; addr
  cmp   ecx, # 0
  jle   @@8
  push  edi
  mov   edi, edx
  repnz scasb
  mov   eax, edi
  pop   edi
  jnz   @@8
  sub   eax, edx
  dec   eax
  push  eax
  mov   utos, # -1
  jmp   @@9
@@8:
  xor   utos, utos
@@9:
;code-swap-next


;; size1 is the size *including* #10
code-naked-no-inline: SCAN-EOL  ( addr size -- size1 TRUE // FALSE )
  cmp   utos, # 0
  jle   @@9
  push  edi
  mov   edx, [usp]  ;; addr
  mov   ecx, utos   ;; size
  mov   edi, edx
  mov   eax, # 10
  repnz scasb
  jnz   @@8
  sub   edi, edx
  mov   edx, edi
  pop   edi
  mov   [usp], edx
  mov   utos, # -1
  beast-nextjmp
@@8:
  pop   edi
@@9:
  upop  eax
  xor   utos, utos
;code-next


[[ tgt-build-base-binary ]] [IFNOT]
;; size1 is the size before the first high ASCII char
code-naked-no-inline: SCAN-HI-ASCII  ( addr size -- size1 TRUE // FALSE )
  cmp   utos, # 0
  jle   @@9
  mov   edx, [usp]  ;; addr
@@1:
  movsx eax, byte^ [edx]
  test  eax, eax
  js    @@6
  inc   edx
  dec   utos
  jnz   @@1
  ;; no high ascii
@@9:
  upop  eax
  xor   utos, utos
  beast-nextjmp
@@6:
  sub   edx, [usp]  ;; size1
  mov   [usp], edx
  mov   utos, # -1
;code-next

;; search the string specified by c-addr1 u1 for the string specified by c-addr2 u2.
;; if flag is true, a match was found at c-addr3 with u3 characters remaining.
;; if flag is false there was no match and c-addr3 is c-addr1 and u3 is u1.
code-naked-no-inline: SEARCH  ( c-addr1 u1 c-addr2 u2 -- c-addr3 u3 flag )
  \ upush utos
  push  edi
  ;; EBX: u2
  cmp   ebx, # 0
  jz    @@8 ;; this is what tester wants
  jle   @@9
  mov   edx, [usp+] # 4 ;; u1
  cmp   edx, # 0
  jle   @@9
  mov   edi, [usp+] # 8 ;; c-addr1
  add   edx, edi        ;; EDX is end address
@@1:
  mov   esi, [usp]      ;; c-addr2
  lodsb
  mov   ecx, edx
  sub   ecx, edi
  jbe   @@9
  repnz scasb
  jnz   @@9         ;; no first char found
  cmp   ebx, # 1
  jz    @@7         ;; our pattern is one char, and it was found
  mov   ecx, ebx
  dec   ecx
  mov   eax, edx
  sub   eax, edi
  cmp   eax, ecx
  jc    @@9         ;; the rest is shorter than a pattern
  push  edi
  repz  cmpsb
  pop   edi
  jnz   @@1
@@7:
  dec   edi             ;; exact match found
  sub   edx, edi
  mov   [usp+] 8 #, edi ;; c-addr1
  mov   [usp+] 4 #, edx ;; u1
@@8:
  mov   utos, # -1
  jmp   @@f
@@9:
  xor   utos, utos
@@:
  lea   usp, [usp+] # 4
  pop   edi
;code-next

code-naked-no-inline: MEMCMP  ( addr1 addr2 size -- n )
  mov   ecx, utos
  push  edi
  upop  edi
  upop  esi
  xor   utos, utos
  cmp   ecx, # 0
  jle   @@9
  cmp   esi, edi
  jz    @@9
  repz  cmpsb
  jz    @@9
  mov   utos, # 1
  jnc   @@9
  mov   utos, # -1
@@9:
  pop   edi
;code-next

;; -1, 0 or 1
code-naked-no-inline: MEMCMP-CI  ( addr1 addr2 size -- n )
  mov   ecx, utos
  push  edi
  upop  edi
  upop  esi
  xor   utos, utos
  cmp   ecx, # 0
  jle   @@9
@@1:
  lodsb
  mov   ah, byte^ [edi]
  inc   edi
  ;; it may work
  cmp   al, ah
  jnz   @@3
@@2:
  dec   ecx
  jnz   @@1
  jmp   @@9
@@3:
  cmp   al, # 65  ;; 'A'
  jc    @@f
  cmp   al, # 91  ;; 'Z'+1
  jnc   @@f
  or    al, # $20
@@:
  cmp   ah, # 65  ;; 'A'
  jc    @@f
  cmp   ah, # 91  ;; 'Z'+1
  jnc   @@f
  or    ah, # $20
@@:
  cmp   al, ah
  jz    @@2
  ;; failure
  mov   utos, # 1
  jnc   @@9
  mov   utos, # -1
@@9:
  pop   edi
;code-next


: COMPARE  ( c-addr1 u1 c-addr2 u2 -- n )
  rot 2dup 2>r umin memcmp dup not?< drop 2r> swap ucmp || 2rdrop >? ;

: COMPARE-CI  ( c-addr1 u1 c-addr2 u2 -- n )
  rot 2dup 2>r umin memcmp-ci dup not?< drop 2r> swap ucmp || 2rdrop >? ;

;; stops at the given char
code-naked-no-inline: SCAN-UNTIL  ( addr size char -- addr1 size1 )
  movzx ecx, bl
  upop  utos
  cmp   utos, # 0
  jle   @@9
  mov   edx, [usp]  ;; addr
@@1:
  movzx eax, byte^ [edx]
  cmp   eax, ecx
  jz    @@2
  inc   edx
  dec   utos
  jnz   @@1
@@2:
  mov   [usp], edx
  beast-nextjmp
@@9:
  xor   utos, utos
;code-next


;; addr1 is after the last blank
code-naked-no-inline: SKIP-BLANKS  ( addr size -- addr1 size1 )
  cmp   utos, # 0
  jle   @@9
  mov   edx, [usp]  ;; addr
@@1:
  movzx eax, byte^ [edx]
  cmp   al, # 33
  jnc   @@2
  inc   edx
  dec   utos
  jnz   @@1
@@2:
  mov   [usp], edx
  beast-nextjmp
@@9:
  xor   utos, utos
;code-next

;; addr1 is after the last non-blank
code-naked-no-inline: SKIP-NON-BLANKS  ( addr size -- addr1 size1 )
  cmp   utos, # 0
  jle   @@9
  mov   edx, [usp]  ;; addr
@@1:
  movzx eax, byte^ [edx]
  cmp   al, # 33
  jc    @@2
  inc   edx
  dec   utos
  jnz   @@1
@@2:
  mov   [usp], edx
  beast-nextjmp
@@9:
  xor   utos, utos
;code-next
[ENDIF]

: -TRAILING  ( addr count -- addr count )
  << dup -0?v|| 2dup + 1- c@ bl > ?v|| 1- ^|| >> 0 max ;

;; throw away begining of the string, if it is too long.
;; doesn't check args for validity.
: TRUNC-LEFT  ( addr count maxlen -- addr count )
  2dup > ?< 2dup - >r nip swap r> + swap || drop >? ;

;; advance one char; correctly processes invalid/0 counts
: /CHAR   ( addr count -- addr+1 count-1 )  dup 0> tuck + 0 max nrot - swap ;
: /2CHARS ( c-addr1 u1 -- c-addr+2 u1-2 )   /char /char ;

: /CHARS  ( addr count n -- addr+1 count-1 )
  dup 0< ?error" invalid char count"
  2dup > ?exit< >r swap r@ + swap r> - >? 2drop false ;

;; adjust the character string at c-addr1 by n characters.
;; the resulting character string, specified by c-addr2 u2,
;; begins at c-addr1 plus n characters and is u1 minus n characters long.
;; doesn't check length, allows negative n.
: /STRING  ( c-addr1 count n -- c-addr2 count )
  \ dup >r - swap r> + swap ;
  ;; this is better inlineable (and smaller)
  tuck - nrot + swap ;


;; create dd-counted string at the given address.
;; inlineable
: MK$  ( addr count dest )
  ;; copy string first, to allow overlaps
  swap 0 max swap 2dup 2>r 4+ swap move 2r> ! ;

;; inlineable
: END$  ( cc-str -- addr )  count + ;

;; inlineable
: CHAR>$  ( char cc-str )  tuck end$ c! 1+! ;

;; not inlineable
: STR>$  ( addr count cc-str )
  >r dup -0?exit< 2drop rdrop >?
  tuck r@ end$ swap move r> +! ;

: $-LAST-CHAR!  ( char cc-str )
  count 1 max + 1- c! ;

;; the names are sux, but quite a lot of my code using them...
: PAD+CHAR  ( ch )  pad char>$ ;
: PAD+CC    ( addr count )  pad str>$ ;
: PAD-LAST-CHAR!  ( ch )  pad $-last-char! ;

;; copy string to pad as dd-counted string
: >PAD  ( addr count )  pad mk$ ;

: PAD-CC@  ( -- addr count )  pad count ;
: PAD-LEN@ ( -- count )  pad @ ;
: PAD-LEN! ( count )  pad ! ;

: PAD-CHAR@  ( idx -- ch )  pad 4+ + c@ ;

: PATH-DELIM?  ( ch )
  [ tgt-(*nix?) ] [IF]
    [char] / forth:=
  [ELSE]
    dup [char] / forth:= over [char] \ forth:= or swap [char] : forth:= or
  [ENDIF] ;

;; leaves only path (or empty string)
;; leaves final path delimiter
: EXTRACT-PATH  ( addr count -- addr count )
  << dup -0?v| 0 max |? 2dup + 1- c@ path-delim? not?^| 1- |? v|| >> ;

: END-DELIM?  ( addr count -- flag )
  dup +?< + 1- c@ path-delim? || 2drop false >? ;

;; with extension
: EXTRACT-NAME  ( addr count -- addr count )
  0 max 2dup 2>r extract-path dup r@ forth:= ?< 2drop 2r> 2dup end-delim? ?< drop 0 >?
  || tuck + r> rot - rdrop >? ;

;; with leading dot.
;; if there is no extension, "count" is 0, "addr" is unchanged.
: EXTRACT-EXT  ( addr count -- addr count )
  dup >r 0 max << ( addr count )
    1- dup -?v| rdrop drop 0 |?
    2dup + c@ dup [char] . forth:= ?v| drop tuck + r> rot - |?
    path-delim? ?v| rdrop drop 0 |?
  ^|| >> ;

: FIX-SLASHES  ( addr count )
  [ tgt-(*nix?) ] [IFNOT]
  swap << over -0?v|| 1 under- c@++ [char] \ forth:= ?< [char] / over 1- c! >? ^|| >> 2drop
  [ENDIF] 2drop ;

;; leaves only path (or empty string)
;; leaves final path delimiter
: PAD-REMOVE-NAME
  pad-cc@ extract-path pad-len! drop ;

: PAD-REMOVE-EXT
  pad-len@ << 1- dup -0?v| drop |?
    dup pad-char@ [char] . of?v| pad-len! |?
    path-delim? ?v| drop |?
  ^|| >> ;

: ENV-NAME  ( addr -- addr count )
  dup << dup c@ dup not?v| 2drop 0 |? [char] = <>of?^| 1+ |? else| drop over - >> ;

: ENV-VALUE  ( addr -- addr count )
  zcount [char] = string:memchr ?< string:/char || drop 0 >? ;

: GETENV  ( addr count -- addr count TRUE // FALSE )
  dup 0< ?exit< 2drop false >?
  (env^) @ << dup c@ not?v| 3drop false |?
  >r 2dup r@ env-name =ci not?^| r> zcount + 1+ |?
  else| 2drop r> env-value true >> ;


0 quan (BINPATH) (private)

{no-inline}
: BINPATH  ( -- addr count )
  (binpath) dup not?< drop
    4096 linux:prot-r/w linux:mmap not?error" out of memory"
    dup (binpath):!
    " /proc/self/exe" drop over 4+ 4090 linux:(readlink)
    dup 1 4090 bounds not?error" cannot get binary path"
    over ! >? count ;


{no-inline}
: JOAAT  ( addr count -- hash )
  dup +?<
    $29a >r swap <<
      over +?^| 1 under- c@++
      r> + dup 10 lshift + dup 6 rshift xor >r |?
      else| 2drop >>
    r> dup 3 lshift + dup 11 rshift xor dup 15 lshift + ( final mix )
  || 2drop 0 >? ;

;; returns hash and accumulator. this is enough to make string
;; hash unique (collision chance is so small that it could be
;; safely ignored).
{no-inline}
: JOAAT-2X ( addr count -- hash accum )
  dup -0?exit< 2drop 0 0 >?
  ( accum) 0 >r ( current hash) $29a >r swap <<
    over +?^| 1 under- c@++
      r> + dup 10 lshift + dup 6 rshift xor
      dup r0:-! ( update accum) >r |?
    else| 2drop >>
  r> dup 3 lshift + dup 11 rshift xor dup 15 lshift + ( final mix )
  dup r0:-! r> ;


[[ tgt-build-base-binary ]] [IFNOT]
: STARTS-WITH  ( addr count pataddr patcount -- flag )
  rot over u< ?exit< 3drop false >? ( addr pataddr patcount ) mem= ;

: STARTS-WITH-CI  ( addr count pataddr patcount -- flag )
  rot over u< ?exit< 3drop false >? ( addr pataddr patcount ) mem=ci ;

: ENDS-WITH  ( addr count pataddr patcount -- flag )
  2over nip over u< ?exit< 4drop false >?
  2>r ( addr count | pataddr patcount )
  + r@ - 2r> mem= ;

: ENDS-WITH-CI  ( addr count pataddr patcount -- flag )
  2over nip over u< ?exit< 4drop false >?
  2>r ( addr count | pataddr patcount )
  + r@ - 2r> mem=ci ;
[ENDIF]


: =  ( addr0 count0 addr1 count1 -- flag )  == ;


clean-module
end-module STRING


extend-module LINUX
: OPEN-DIR  ( addr count -- dfd TRUE // false )
  [ o-rdonly o-directory or ] {#,} 0 at-fdcwd open-at ;

|: GET-DFD-PATH  ( dfd -- addr count TRUE // FALSE )
  ;; save current directory fd
  " ." open-dir not?exit< close drop false >?
  >r >r  ( | olddfd dfd )
  r@ fchdir ?exit< r> close drop r@ fchdir drop r> close drop false >?
  pad 4+ 2048 get-cwd
  r> close drop r@ fchdir drop r> close drop
  dup 1 < ?exit< drop false >? 1-
  dup pad ! ;; set length, we may need it
  pad 4+ swap true ;

;; at PAD+4 (dd-counted string at PAD).
;; it doesn't matter if the file exists.
: REALPATH  ( addr count -- addr count TRUE // FALSE )
  dup 0< ?error" invalid file name length"
  dup not?< 2drop " ." >?
  2dup 2>r open-dir ?exit< 2rdrop get-dfd-path >?
  ( | addr count )
  ;; not a dir, must be a file; cut file name
  2r@ string:end-delim? ?exit< 2rdrop false >?
  2r@ string:extract-path dup >r dup not?< 2drop " ." >?
  open-dir not?exit< 3rdrop false >?
  ( dfd | addr count orig-count )
  get-dfd-path not?exit< 3rdrop false >?
  ;; ok, we got the path; append file name
  + 1- c@ string:path-delim? not?< [char] / string:pad+char >?
  r2:@ r@ + r1:@ r> - 2rdrop string:pad+cc
  string:pad-cc@ true ;
end-module LINUX


;; NOTE: this module was never used by me, so i see no reason to keep it.
(*
;; we cannot extend PAD word, so...
[[ tgt-build-base-binary ]] [IFNOT]
module S$
<disable-hash>
<published-words>

;; string will be there
0 quan $PAD

: USE-PAD  pad $pad:! ;

: MK  ( addr count )
  0 max
  ;; copy string first, to allow overlaps
  2dup $pad 4+ swap move
  $pad ! drop ;

: CLEAR  $pad !0 ;

: >CC  ( -- addr count )  $pad count ;

: $END  ( -- addr count ) $pad count + ;

: >ASCIIZ  ( -- addr count ) 0 $end c! >cc ;

: CHAR+  ( char )  $end c! $pad 1+! ;

: CC+  ( addr count )  dup +?< 2dup $end swap move $pad +! drop || 2drop >? ;

: LENGTH  ( -- count ) $pad @ ;

: CHOP-RIGHT  ( count )  0 length clamp $pad -! ;

: CHOP-LEFT  ( count )
  0 length clamp
  $pad 4+ over + swap  ( from^ count )
  $pad @ swap -        ( from^ copy-count )
  dup $pad !  ;; set new counter
  $pad 4+ swap move ;

seal-module
end-module S$
[ENDIF]
*)

;; as "string:padXXX" are used quite often, let's define a separate module for them.
;; the easiest way is to reuse "STRING" words, because i am too lazy to rewrite all my code.
module PAD$

;; get current string length
: #  ( -- len )  pad @ 0 max ;

;; set new string length. will not grow the string.
;; i.e. it is only possible to trim it.
: #!  ( newlen )  0 max # min pad ! ;

;; append char to the stored one
: C+  ( char )  pad count 0 max  dup 1+ pad !  + c! ;

;; get last char in the string. for zero-length string return 0.
: LAST-C@  ( -- char )
  pad count dup not?exit< 2drop 0 >? + 1- c@ ;

;; replace last char. for zero-length string does nothing.
: LAST-C!  ( char )
  pad count dup not?exit< 3drop >? + 1- c! ;

;; for out-of-bounds indicies return `0`.
: NTH-C  ( idx -- addr )
  dup # u>= ?exit< drop 0 >?
  pad 4+ db-nth ;

;; for out-of-bounds indicies return `0`.
: NTH-C@  ( idx -- char )
  nth-c dup ?< c@ || drop 0 >? ;

;; for out-of-bounds do nothing.
: NTH-C!  ( char idx )
  nth-c dup ?< c! || 2drop >? ;


;; chop `n` trailing chars from the string.
;; it is ok to chop more chars than then string has.
: CHOP  ( n )  0 max # swap - 0 max pad ! ;


;; the most comples words, involving string copying

;; chop `n` leading chars from the string.
;; it is ok to chop more chars than then string has.
: CHOP-LEFT  ( n )
  0 max #
  ( n count )
  2dup >= ?exit< 2drop pad !0 >?
  ;; move `count-n` bytes from `pad+n` to `pad`
  over -  ( n cmovelen )
  over pad 4+ +  pad 4+  rot cmove
  pad -! ;

;; make room for `count` leading bytes.
;; no sanity checks.
;; move `pad @` bytes from `pad+4` to `pad+4+count`.
;; fixes string length.
|: MK-LEFT-ROOM  ( count )
  dup  pad 4+  dup rot +  # cmove>
  pad +! ;

|: IN-PAD$  ( addr count )
  drop  pad count 0 max over + 3 + bounds ;

;; prepend a string.
;; note that prepending part of PAD$ work if it is not out-of-bounds.
: PREPEND  ( addr count )
  dup -0?exit< 2drop >?
  dup mk-left-room
  2dup in-pad$ ?< tuck + swap >?  ;; shift it
  pad 4+ swap cmove ;

|: (#DIGIT)  ( digit )  48 + dup 57 > ?< 7 + >? c+ ;

: (HEX-NIBBLE)  ( u )  $0F and (#digit) ;
: (HEXB)  ( u )  dup 4 rshift (hex-nibble) (hex-nibble) ;
: (HEXW)  ( u )  dup hi-byte (hexb) (hexb) ;
: (HEXD)  ( u )  dup hi-word (hexw) (hexw) ;

: HEX2  ( u )  [char] $ c+ (hexb) ;
: HEX4  ( u )  [char] $ c+ (hexw) ;
: HEX8  ( u )  [char] $ c+ (hexd) ;

;; unsigned number, in decimal; doesn't use numeric conversion
: U#S  ( u )
  10 u/mod swap dup ?< recurse || drop >?
  [char] 0 + c+ ;

;; signed number, in decimal; doesn't use numeric conversion
: #S  ( n )
  dup $8000_0000 = ?exit< drop " -2147483648" string:pad+cc >?
  dup -?< [char] - c+ abs >? u#s ;

;; the following words are defined last to not interfere with Forth words

;; create uninitialized string with the given length
: MK#  ( len )
  dup #pad 128 - u> ?error" invalid string length in `PAD$:MK#`"
  pad ! ;

;; store string to PAD as counted, removing previously stored string
: !  ( addr count )  string:>pad ;

;; init with empty string
: !0  pad forth:!0 ;

;; append string to the stored one
: +  ( addr count )  string:pad+cc ;

;; get current string and count from PAD.
;; don't append trailing 0.
;; the "PAD string" is still usable after this.
;; no copies are made!
: @  ( addr count )  pad count 0 max ;

;; get current string and count from PAD.
;; append trailing 0.
;; the "PAD string" is still usable after this.
;; no copies are made!
: @Z  ( addr count )  @@current:@ 2dup forth:+ c!0 ;

end-module PAD$
