;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level Linux TTY control
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


extend-module LINUX

(*
EAX: syscall number
args:
  EBX -- 1
  ECX -- 2
  EDX -- 3
  ESI -- 4
  EDI -- 5
  EBP -- 6
*)

0 constant STDIN-FD
1 constant STDOUT-FD
2 constant STDERR-FD

$5401 constant TCGETS
$5402 constant TCSETS
$5403 constant TCSETSW
$5404 constant TCSETSF
$5405 constant TCGETA
$5406 constant TCSETA
$5407 constant TCSETAW
$5408 constant TCSETAF
$5409 constant TCSBRK
$540A constant TCXONC
$540B constant TCFLSH
(*
$540C constant TIOCEXCL
$540D constant TIOCNXCL
$540E constant TIOCSCTTY
$540F constant TIOCGPGRP
$5410 constant TIOCSPGRP
$5411 constant TIOCOUTQ
$5412 constant TIOCSTI
*)
$5413 constant TIOCGWINSZ
(*
$5414 constant TIOCSWINSZ
$5415 constant TIOCMGET
$5416 constant TIOCMBIS
$5417 constant TIOCMBIC
$5418 constant TIOCMSET
$5419 constant TIOCGSOFTCAR
$541A constant TIOCSSOFTCAR
$541B constant FIONREAD
$541B constant TIOCINQ
$541C constant TIOCLINUX
$541D constant TIOCCONS
$541E constant TIOCGSERIAL
$541F constant TIOCSSERIAL
$5420 constant TIOCPKT
$5421 constant FIONBIO
$5422 constant TIOCNOTTY
$5423 constant TIOCSETD
$5424 constant TIOCGETD
$5425 constant TCSBRKP  ;; needed for POSIX tcsendbreak()
$5427 constant TIOCSBRK ;; BSD compatibility
$5428 constant TIOCCBRK ;; BSD compatibility
$5429 constant TIOCGSID ;; return the session ID of FD
*)


 0 quan RAW-MODE?
-1 quan TTYCHECK

create SAVED-TIO 80 allot create;  ;; actually, 60, but who cares

create COOCKED-TIO
  \ $00002102 ,     ;; c_iflag
  \ $00000005 ,     ;; c_oflag
  $00002001 ,     ;; c_iflag
  $00000004 ,     ;; c_oflag
  $000008B0 ,     ;; c_cflag
  \ $00008A3B ,     ;; c_lflag
  $00000A30 ,     ;; c_lflag
  $3B c,          ;; c_line
  $03 c, $1C c, $7F c, $15 c, $04 c, $00 c, $01 c, $00 c,
  $11 c, $13 c, $1A c, $00 c, $12 c, $0F c, $17 c, $16 c, ;; c_cc
  $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c,
  $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, ;; c_cc
  0 c, 0 c, 0 c,  ;; align
  0 ,             ;; c_ispeed
  0 ,             ;; c_ospeed
create;

$00002001 , -- c_iflag
$00000004 , -- c_oflag
$000008B0 , -- c_cflag
$3B c, -- c_line
;; NCCS=32
$03 c, $1C c, $7F c, $15 c, $04 c, $00 c, $01 c, $00 c,
$11 c, $13 c, $1A c, $00 c, $12 c, $0F c, $17 c, $16 c,
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c,
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c,  -- c_cc


;; set terminal mode (60-bytes buffer)
code-swap-no-inline: SET-TIO-MODE  ( bufaddr fd -- res )
  pop   edx           ;; buffer
  mov   eax, # 54     ;; ioctl
  ;;mov   ebx, # 1      ;; stdout
  mov   ecx, # TCSETSF  ;; (TCSAFLUSH)
  sys-call
  mov   utos, eax
;code-swap-next


;; get terminal mode (60-bytes buffer)
code-swap-no-inline: GET-TIO-MODE  ( bufaddr fd -- res )
  pop   edx           ;; buffer
  mov   eax, # 54     ;; ioctl
  ;;mov   ebx, # 1      ;; stdout
  mov   ecx, # TCGETS
  sys-call
  mov   utos, eax
;code-swap-next


code-naked-no-inline: GET-TTY-SIZE  ( fd -- w h )
  sub   esp, # 16     ;; buffer
  mov   dword^ [esp], # 0
  mov   edx, esp
  mov   eax, # 54     ;; ioctl
  ;;mov   ebx, # 1      ;; stdout
  mov   ecx, # TIOCGWINSZ
  sys-call
  movzx utos, word^ [esp]
  movzx edx, word^ [esp+] # 2
  add   esp, # 16
  ;; convert eax
  sub   eax, # 1
  sbb   eax, eax
  ;; check utos
  mov   ecx, utos
  neg   ecx
  sbb   ecx, ecx
  and   eax, ecx
  ;; check edx
  mov   ecx, edx
  neg   ecx
  sbb   ecx, ecx
  and   eax, ecx
  jnz   @@2
  mov   edx, # 80
  mov   utos, # 24
@@2:
  upush edx
;code-next


{no-inline}
: TTY-SIZE  ( -- w h )  stdout-fd get-tty-size ;

{no-inline}
: KEY-TOUT?  ( mstout -- flag )
  >r #pollfd lalloc >r 0
  << drop stdin-fd r@ pollfd.fd + !
     poll-in r@ pollfd.events + ! ;; this also clears revents
     r@ 1 r1:@ poll dup -4 = ?^|| v|| >>
  0> 2rdrop #pollfd ldealloc ;

: KEY?  ( -- flag )  0 key-tout? ;

: KEY  ( -- ch )  raw-emit:getch ;

{no-inline}
: IS-TTY?  ( -- flag )
  ttycheck dup -?< drop
    saved-tio stdin-fd get-tio-mode ?exit< 0 dup ttycheck:! >?
    80 lalloc stdout-fd get-tio-mode 80 ldealloc
    ?< 0 || 1 >? dup ttycheck:! >? negate ;

{no-inline}
: TTY-SET-RAW  ( -- success-flag )
  is-tty? ?< raw-mode? dup ?exit drop
    coocked-tio stdin-fd set-tio-mode 0= dup raw-mode?:!
    dup ?< raw-emit:cr-crlf? !t >?
  || false >? ;

{no-inline}
: TTY-RESTORE
  raw-mode? ?< saved-tio stdin-fd set-tio-mode
               0<> dup raw-mode?:! not?< raw-emit:cr-crlf? !0 >? >? ;


;; for input
{no-inline}
: TTY-CR>NL!  ( flag )
  ?< $2101 || $2001 >?
  dup coocked-tio @ <> ?<
    coocked-tio ! raw-mode? ?< coocked-tio stdin-fd set-tio-mode drop >?
  >? ;

{no-inline}
: TTY-CR>NL?  ( -- flag )  coocked-tio @ $2101 = ;

%0000_0001 constant CAP-YTERM
%0000_0010 constant CAP-16-COLORS   ;; always set
%0000_0100 constant CAP-256-COLORS
%0000_1000 constant CAP-RGB-COLORS

{no-inline}
: DETECT-TERM-CAPS  ( -- caps-bits )
  " K8YTERM" string:getenv ?< " tan" string:=ci
                              ?exit< [ CAP-YTERM CAP-16-COLORS or
                                        CAP-256-COLORS or CAP-RGB-COLORS or ]
                                     {#,} >? >?
  " COLORTERM" string:getenv not?exit<
    ;; check "TERM"
    " TERM" string:getenv not?exit< 0 >?
    2dup " -32bit" string:search nrot 2drop ?exit<
      2drop [ CAP-16-COLORS CAP-256-COLORS or CAP-RGB-COLORS or ] {#,} >?
    2dup " -24bit" string:search nrot 2drop ?exit<
      2drop [ CAP-16-COLORS CAP-256-COLORS or CAP-RGB-COLORS or ] {#,} >?
    2dup " -truecolor" string:search nrot 2drop ?exit<
      2drop [ CAP-16-COLORS CAP-256-COLORS or CAP-RGB-COLORS or ] {#,} >?
    2dup " -256color" string:search nrot 2drop ?exit<
      2drop [ CAP-16-COLORS CAP-256-COLORS or ] {#,} >?
    5 min " xterm" string:=ci ?exit< CAP-16-COLORS >?
    CAP-16-COLORS >?
  ;; check "COLORTERM"
  2dup 4 min " true" string:=ci ?exit<
    2drop [ CAP-16-COLORS CAP-256-COLORS or CAP-RGB-COLORS or ] {#,} >?
  2dup 5 min " 32bit" string:=ci ?exit<
    2drop [ CAP-16-COLORS CAP-256-COLORS or CAP-RGB-COLORS or ] {#,} >?
  2dup 5 min " 24bit" string:=ci ?exit<
    2drop [ CAP-16-COLORS CAP-256-COLORS or CAP-RGB-COLORS or ] {#,} >?
  2dup 3 min " 256" string:= ?exit<
    2drop [ CAP-16-COLORS CAP-256-COLORS or ] {#,} >?
  2drop CAP-16-COLORS ;

end-module LINUX
