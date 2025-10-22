;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; low-level Linux kernel calls
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
: ERASE  ( addr count )   0 fill ;
: BLANK  ( addr count )  32 fill ;

: ERASE32  ( addr count )   0 fill32 ;


['] (NBYE) variable (NBYE^) (private)
['] (BYE)  variable (BYE^)  (private)

{no-inline}
: NBYE  ( code )  (nbye^) @execute 1 (nbye) ;
{no-inline}
: BYE  (bye^) @execute (bye) ;


\ : ABORT  " user abort" error ; (noreturn)
{no-inline}
: ABORT  error" user abort" ; (noreturn)

{no-inline}
: (NOTIMPL) error" not implemented" ; (noreturn)


module LINUX
<disable-hash>

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

 -1 constant EPERM
 -2 constant ENOENT
 -3 constant ESRCH
 -4 constant EINTR
 -5 constant EIO
 -6 constant ENXIO
 -7 constant E2BIG
 -8 constant ENOEXEC
 -9 constant EBADF
-10 constant ECHILD
-11 constant EAGAIN
-11 constant EWOULDBLOCK
-12 constant ENOMEM
-13 constant EACCES
-14 constant EFAULT
-15 constant ENOTBLK
-16 constant EBUSY
-17 constant EEXIST
-18 constant EXDEV
-19 constant ENODEV
-20 constant ENOTDIR
-21 constant EISDIR
-22 constant EINVAL
-23 constant ENFILE
-24 constant EMFILE
-25 constant ENOTTY
-26 constant ETXTBSY
-27 constant EFBIG
-28 constant ENOSPC
-29 constant ESPIPE
-30 constant EROFS
-31 constant EMLINK
-32 constant EPIPE
-33 constant EDOM
-34 constant ERANGE



;; copy string to the bottom of PAD area if it is not ASCIIZ
{no-inline}
: ENSURE-ASCIIZ  ( addr count -- addr )
  0 max 2dup + c@ ?< >r
    pad #pad 2/ +
    r@ - 8 - r@ over >r
    cmove r> r> 2dup + !0 >? drop ;


code-swap-no-inline: (MK-DIR)  ( addr mode -- errcode-or-0 )
  mov   ecx, utos   ;; TOS is EBX
  pop   ebx
  mov   eax, # 39
  sys-call
  mov   utos, eax
;code-swap-next

\ TODO: EINTR?
{no-inline}
: MK-DIR-EX  ( addr count mode -- errcode-or-0 )
  nrot ensure-asciiz swap (mk-dir) ;

: MK-DIR  ( addr count -- errcode-or-0 )
  @755 MK-DIR-EX ;

code-swap-no-inline: (RM-DIR)  ( addr -- errcode-or-0 )
  mov   eax, # 40
  sys-call
  mov   utos, eax
;code-swap-next

\ TODO: EINTR?
{no-inline}
: RM-DIR  ( addr count -- errcode-or-0 )
  ensure-asciiz (rm-dir) ;


code-naked-no-inline: (UNLINK)  ( addr -- errcode-or-0 )
  \ mov   ebx, utos ;; TOS is EBX already
  mov   eax, # 10
  sys-call
  mov   utos, eax
;code-no-stacks

{no-inline}
: UNLINK  ( addr count -- errcode-or-0 )
  ensure-asciiz (unlink) ;

code-swap-no-inline: CHMOD-FD  ( mode fd -- errcode-or-0 )
  \ mov   ebx, utos ;; TOS is EBX already
  mov   eax, # 94
  pop   ecx
  sys-call
  mov   utos, eax
;code-swap-next

code-swap-no-inline: (CHMOD)  ( mode addr -- errcode-or-0 )
  \ mov   ebx, utos ;; TOS is EBX already
  mov   eax, # 15
  pop   ecx
  sys-call
  mov   utos, eax
;code-swap-next

{no-inline}
: CHMOD  ( mode addr count -- errcode-or-0 )
  ensure-asciiz (chmod) ;

code-naked-no-inline: CLOSE  ( fd -- flag )
  \ mov   ebx, utos ;; TOS is EBX already
  mov   eax, # 6
  sys-call
  mov   utos, eax
;code-no-stacks

code-swap-no-inline: (OPEN)  ( addr flags crperm -- fd-or-minusone )
  ;; EBX: addr
  ;; ECX: flags
  ;; EDX: crperm
  mov   edx, utos   ;; TOS is EBX
  pop   ecx
  pop   ebx
  mov   eax, # 5
  sys-call
  mov   utos, eax
;code-swap-next

\ TODO: EINTR?
{no-inline}
: OPEN  ( addr count flags crperm -- handle-or-<0 )
  2swap ensure-asciiz nrot (open) dup -?< drop false || true >? ;

code-swap-no-inline: (OPEN-AT)  ( addr flags crperm dfd -- fd-or-minusone )
  ;; EBX: dfd
  ;; ECX: addr
  ;; EDX: flags
  ;; ESI: crperm
  pop   eax
  pop   edx
  pop   ecx
  mov   esi, # 0o644
  mov   eax, # 295
  sys-call
  mov   utos, eax
;code-swap-next

\ TODO: EINTR!
{no-inline}
: OPEN-AT  ( addr count flags crperm dfd -- handle-or-<0 )
  >r 2swap ensure-asciiz nrot r> (open-at) dup -?< drop false || true >? ;

code-swap-no-inline: (READ)  ( addr count fd -- count )
  ;; EBX: fd
  ;; ECX: addr
  ;; EDX: count
  pop   edx
  pop   ecx
  mov   eax, # 3
  sys-call
  mov   utos, eax
;code-swap-next

code-swap-no-inline: (WRITE)  ( addr count fd -- count )
  ;; EBX: fd
  ;; ECX: addr
  ;; EDX: count
  pop   edx
  pop   ecx
  mov   eax, # 4
  sys-call
  mov   utos, eax
;code-swap-next

|: (DO-RW)  ( addr count fd cfa -- count )
  << 2over 2over execute dup EINTR = ?^| drop |? else| >r 4drop r> >> ;

{no-inline}
: READ   ( addr count fd -- count/err )  ['] (read) (do-rw) ;
{no-inline}
: WRITE  ( addr count fd -- count/err )  ['] (write) (do-rw) ;

code-swap-no-inline: LSEEK  ( ofs whence fd -- res )
  ;; EBX: fd
  ;; ECX: ofs
  ;; EDX: whenre
  pop   edx
  pop   ecx
  mov   eax, # 19
  sys-call
  mov   utos, eax
;code-swap-next

code-naked-no-inline: FSYNC  ( fd -- res )
  mov   eax, # 118
  sys-call
  mov   utos, eax
;code-no-stacks

code-naked-no-inline: FSYNC-DATA  ( fd -- res )
  mov   eax, # 148
  sys-call
  mov   utos, eax
;code-no-stacks

code-swap-no-inline: FTRUNC  ( size fd -- res )
  pop   ecx
  mov   eax, # 93
  sys-call
  mov   utos, eax
;code-swap-next

0 constant O-RDONLY
1 constant O-WRONLY
2 constant O-RDWR

      0o100 constant O-CREAT
\     0o200 constant O-EXCL
\     0o400 constant O-NOCTTY
     0o1000 constant O-TRUNC
     0o2000 constant O-APPEND
\    0o4000 constant O-NONBLOCK
\   0o10000 constant O-DSYNC
  0o200000 constant O-DIRECTORY
  0o400000 constant O-NOFOLLOW
  0o2000000 constant O-CLOEXEC
\ 0o4010000 constant O-SYNC
\ 0o4010000 constant O-RSYNC

\     0o4000 constant O-NDELAY
\    0o20000 constant O-ASYNC
\    0o40000 constant O-DIRECT
\   0o100000 constant O-LARGEFILE
\  0o1000000 constant O-NOATIME
\ 0o10000000 constant O-PATH
\ 0o20200000 constant O-TMPFILE

\ 0x000240 constant O-CREATE-FLAGS-NOMODE
\ 0x000241 constant O-CREATE-WRONLY-FLAGS
\    0x1A4 constant O-CREATE-MODE-NORMAL

0 constant SEEK-SET
1 constant SEEK-CUR
2 constant SEEK-END

\ 0o4000 constant S-ISUID
\ 0o2000 constant S-ISGID
\ 0o1000 constant S-ISVTX
\  0o400 constant S-IRUSR
\  0o200 constant S-IWUSR
\  0o100 constant S-IXUSR
  0o700 constant S-IRWXU
  0o040 constant S-IRGRP
\  0o020 constant S-IWGRP
  0o010 constant S-IXGRP
\  0o070 constant S-IRWXG
  0o004 constant S-IROTH
\  0o002 constant S-IWOTH
  0o001 constant S-IXOTH
\  0o007 constant S-IRWXO


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
\  0 constant STAT.dev  ;; rd 1
\  4 constant STAT.ino  ;; rd 1
  8 constant STAT.mode  ;; rw 1
\ 10 constant STAT.nlink  ;; rw 1
\ 12 constant STAT.uid  ;; rw 1
\ 14 constant STAT.gid  ;; rw 1
\ 16 constant STAT.rdev  ;; rd 1
 20 constant STAT.size  ;; rd 1
\ 24 constant STAT.blksize  ;; rd 1
\ 28 constant STAT.blocks  ;; rd 1
\ 32 constant STAT.atime  ;; rd 1
\ 36 constant STAT.atime_nsec  ;; rd 1
 40 constant STAT.mtime  ;; rd 1
\ 44 constant STAT.mtime_nsec  ;; rd 1
\ 48 constant STAT.ctime  ;; rd 1
\ 52 constant STAT.ctime_nsec  ;; rd 1
;; $constant "STAT.__unused4"     56  ;; rd 1
;; $constant "STAT.__unused5"     60  ;; rd 1
64 constant #STAT

\  0 constant STAT64.dev  ;; rq 1, rb 4
\ 12 constant STAT64._ino  ;; rd 1
 16 constant STAT64.mode  ;; rd 1
\ 20 constant STAT64.nlink  ;; rd 1
\ 24 constant STAT64.uid  ;; rd 1
\ 28 constant STAT64.gid  ;; rd 1
\ 32 constant STAT64.rdev  ;; rq 1, rb 4
 44 constant STAT64.size64  ;; rq 1
\ 52 constant STAT64.blksize  ;; rd 1
\ 56 constant STAT64.blocks  ;; rq 1
\ 64 constant STAT64.atime  ;; rd 1
\ 68 constant STAT64.atime_nsec  ;; rd 1
 72 constant STAT64.mtime  ;; rd 1
\ 76 constant STAT64.mtime_nsec  ;; rd 1
\ 80 constant STAT64.ctime  ;; rd 1
\ 84 constant STAT64.ctime_nsec  ;; rd 1
\ 88 constant STAT64.ino  ;; rq 1
96 constant #STAT64

\ 0o0170000 constant S-IFMT

 0o0040000 constant S-IFDIR
\ 0o0020000 constant S-IFCHR
\ 0o0060000 constant S-IFBLK
\ 0o0010000 constant S-IFIFO
 0o0100000 constant S-IFREG
 0o0120000 constant S-IFLNK
\ 0o0140000 constant S-IFSOCK

 -100 constant AT-FDCWD
$0100 constant AT-SYMLINK-NOFOLLOW
\ $0400 constant AT-SYMLINK-FOLLOW -- unneded for now
$0800 constant AT-NO-AUTOMOUNT
$1000 constant AT-EMPTY-PATH


\ statbuf should be #STAT bytes
code-swap-no-inline: (STAT)  ( nameaddrz statbuf -- errcode )
  mov   ecx, utos
  pop   ebx
  mov   eax, # 106
  sys-call
  mov   utos, eax
;code-swap-next

\ statbuf should be #STAT bytes
code-swap-no-inline: (STAT-FD)  ( statbuf fd -- errcode )
  pop   ecx
  mov   eax, # 108
  sys-call
  mov   utos, eax
;code-swap-next

\ statbuf should be #STAT64 bytes
code-swap-no-inline: (STAT64)  ( nameaddrz statbuf -- errcode )
  mov   ecx, utos
  pop   ebx
  mov   eax, # 195
  sys-call
  mov   utos, eax
;code-swap-next

\ statbuf should be #STAT64 bytes
code-swap-no-inline: (FSTAT-AT64)  ( nameaddrz statbuf flags fd -- errcode )
  pop   eax   ;; flags, will be moved to ESI
  pop   edx   ;; statbuf
  pop   ecx   ;; nameaddrz
  mov   esi, eax
  mov   eax, # 300
  sys-call
  mov   utos, eax
;code-swap-next

;; used for both STAT and STAT64
128 mk-buffer (statbuf)

{no-inline}
: STAT    ( nameaddr namecount statbuf -- errcode )  nrot ensure-asciiz swap (stat) ;
{no-inline}
: STAT64  ( nameaddr namecount statbuf -- errcode )  nrot ensure-asciiz swap (stat64) ;

{no-inline}
: STAT-MODE  ( addr count -- mode TRUE // FALSE )
  (statbuf) stat ?< false || (statbuf) stat.mode + w@ true >? ;

{no-inline}
: STAT-SIZE  ( addr count -- size TRUE // FALSE )
  (statbuf) stat ?< false || (statbuf) stat.size + @ true >? ;

{no-inline}
: STAT-MTIME  ( addr count -- mtime TRUE // FALSE )
  (statbuf) stat ?< false || (statbuf) stat.mtime + @ true >? ;

{no-inline}
: FILE?  ( addr count -- flag )  stat-mode ?< S-IFREG mask? || false >? ;
{no-inline}
: DIR?   ( addr count -- flag )  stat-mode ?< S-IFDIR mask? || false >? ;
{no-inline}
: LINK?  ( addr count -- flag )  stat-mode ?< S-IFLNK mask? || false >? ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
code-swap-no-inline: GET-CWD  ( buf bufsize -- err//0 )
  pop   ecx
  \ fuckin' fuck86 has FUCKIN' SLOW xchg! wuta...
  xchg  ebx, ecx
  mov   eax, # 183
  sys-call
  mov   utos, eax
;code-swap-next

code-naked-no-inline: (CHDIR)  ( asciiz -- err//0 )
  mov   eax, # 12
  sys-call
  mov   utos, eax
;code-no-stacks

code-naked-no-inline: FCHDIR  ( dfd -- err//0 )
  mov   eax, # 133
  sys-call
  mov   utos, eax
;code-no-stacks

{no-inline}
: CHDIR  ( addr count -- success-flag? )
  ensure-asciiz (chdir) 0= ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; get seconds and nanoseconds (since some random starting point)
code-swap-no-inline: GET-TZ  ( -- tzwestseconds tzdst )
  push  ebx
  sub   esp, # 8    ;; tz
  mov   eax, # 78   ;; sys_gettimeofday
  xor   ebx, ebx    ;; no tv
  mov   ecx, esp    ;; tz
  sys-call
  pop   edx         ;; tzwest
  pop   ebx         ;; tzdst
  xor   ecx, ecx
  test  eax, eax
  cmovnz ebx, ecx
  cmovnz edx, ecx
  push  edx
;code-swap-next

;; get seconds since epoch (UTC)
code-swap-no-inline: TIME  ( -- seconds )
  push  utos
  mov   eax, # 13 ;; sys_time
  xor   ebx, ebx  ;; result only in eax
  sys-call
  mov   utos, eax
;code-swap-next

;; get seconds since epoch (local)
{no-inline}
: LOC-TIME  ( -- seconds )
  time get-tz drop 60 * - ;


0 constant CLOCK-REALTIME
1 constant CLOCK-MONOTONIC
\ 2 constant CLOCK-PROCESS-CPUTIME-ID
\ 3 constant CLOCK-THREAD-CPUTIME-ID
\ 4 constant CLOCK-MONOTONIC-RAW
\ 5 constant CLOCK-REALTIME-COARSE
\ 6 constant CLOCK-MONOTONIC-COARSE
\ 7 constant CLOCK-BOOTTIME
\ 8 constant CLOCK-REALTIME-ALARM
\ 9 constant CLOCK-BOOTTIME-ALARM

   1000000 constant NANOSECONDS/MSEC
1000000000 constant NANOSECONDS/SECOND

;; get seconds and nanoseconds (since some random starting point)
code-swap-no-inline: CLOCK-GETTIME  ( clockid -- seconds nanoseconds )
  \ mov   ebx, utos     ;; clockid
  ;; timespec
  sub   esp, # 4 4 +
  mov   eax, # 265    ;; sys_clock_gettime
  mov   ecx, esp
  sys-call
  test  eax, eax
  pop   eax
  pop   utos
  jz    @@f
  xor   utos, utos
  xor   eax, eax
@@:
  push eax
;code-swap-next

[[ tgt-build-base-binary ]] [IFNOT]
code-swap-no-inline: NANOSLEEP  ( seconds nanoseconds -- errcode )
  pop   eax
  ;; timespec will be on the CPU stack
  push  utos
  push  eax
  mov   eax, # 162
  mov   ebx, esp
  mov   ecx, ebx  ;; fill the same struct
  sys-call
  add   esp, # 4 4 +
  mov   utos, eax
;code-swap-next


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
code-swap-no-inline: GET-PID  ( -- pid )
  push  utos
  mov   eax, # 20
  sys-call
  mov   utos, eax
;code-swap-next

code-swap-no-inline: GET-TID  ( -- tid )
  push  utos
  mov   eax, # 224
  sys-call
  mov   utos, eax
;code-swap-next


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; request and reply
0x0001 constant POLL-IN   ;; read ready
0x0002 constant POLL-PRI  ;; some exceptional condition
0x0004 constant POLL-OUT  ;; write ready
;; reply only
0x0008 constant POLL-ERR  ;; error, or read end of the pipe closed (set for write end)
0x0010 constant POLL-HUP  ;; hangup/connection closed (there still may be data to read)
0x0020 constant POLL-NVAL ;; invalid fd

\ 0x0040 constant POLL-RDNORM ;; man says that this is the same as "POLL-IN"
\ 0x0080 constant POLL-RDBAND ;; priority data can be read
\ 0x0100 constant POLL-WRNORM ;; man says that this is the same as "POLL-OUT"
\ 0x0200 constant POLL-WRBAND ;; priority data can be written

\ 0x0400 constant POLL-MSG    ;; man says that is is accepted, but does nothing
0x2000 constant POLL-RDHUP  ;; stream socket peer closed connection, or shut down writing half of connection

;; special timeouts
-1 constant POLL-INFINITE
 0 constant POLL-NOWAIT

8 constant #POLLFD

0 constant POLLFD.fd
4 constant POLLFD.events
6 constant POLLFD.revents


;; returs -errno or number of records changed
code-swap-no-inline: POLL  ( pollfdarrptr count mstime -- res )
  mov   edx, utos
  pop   ecx
  pop   ebx
  mov   eax, # 168
  sys-call
  mov   utos, eax
;code-swap-next
[ENDIF]


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
0x0000_0000 constant MAP-FILE
0x0000_0001 constant MAP-SHARED
0x0000_0002 constant MAP-PRIVATE
\ 0x0000_0003 constant MAP-SHARED_VALIDATE
\ 0x0000_000f constant MAP-TYPE
\ 0x0000_0010 constant MAP-FIXED
\ 0x0000_0020 constant MAP-ANON
0x0000_0020 constant MAP-ANONYMOUS
0x0000_4000 constant MAP-NORESERVE
0x0000_0100 constant MAP-GROWSDOWN
\ 0x0000_0800 constant MAP-DENYWRITE
\ 0x0000_1000 constant MAP-EXECUTABLE
\ 0x0000_2000 constant MAP-LOCKED
\ 0x0000_8000 constant MAP-POPULATE
\ 0x0001_0000 constant MAP-NONBLOCK
\ 0x0002_0000 constant MAP-STACK
\ 0x0004_0000 constant MAP-HUGETLB
\ 0x0008_0000 constant MAP-SYNC
\ 0x0010_0000 constant MAP-FIXED_NOREPLACE

\ 1 constant MS-ASYNC
\ 2 constant MS-INVALIDATE
\ 4 constant MS-SYNC


0 constant PROT-NONE
1 constant PROT-READ
2 constant PROT-WRITE
4 constant PROT-EXEC
3 constant PROT-R/W
7 constant PROT-RWX

\ 0x01000000 constant PROT-GROWSDOWN
\ 0x02000000 constant PROT-GROWSUP

  0 constant MADV-NORMAL
\   1 constant MADV-RANDOM      ;; less read-ahead
\   2 constant MADV-SEQUENTIAL  ;; more read-ahead
\   3 constant MADV-WILLNEED    ;; expect the access in the near future (aggressive read-ahead)
  4 constant MADV-DONTNEED    ;; release memory, but not pages.
                              ;; if not backed by a file, pages will lost their contents
                              ;; on next access.
  ;; Linux-specific, and not really interesting
  8 constant MADV-FREE        ;; somewhat like MADV-DONTNEED, but more lazy
  9 constant MADV-REMOVE
\  10 constant MADV-DONTFORK
\  11 constant MADV-DOFORK
 ;; KSM
\  12 constant MADV-MERGEABLE
\  13 constant MADV-UNMERGEABLE
\  14 constant MADV-HUGEPAGE
\  15 constant MADV-NOHUGEPAGE

\  16 constant MADV-DONTDUMP
\  17 constant MADV-DODUMP

\ 100 constant MADV-HWPOISON
\ 101 constant MADV-SOFT-OFFLINE


code-swap-no-inline: MMAP  ( size prot -- addr TRUE // FALSE )
  mov   edx, utos ;; protflags
  pop   ecx       ;; size
  push  edi
  push  ebp
  mov   esi, # 0x0000_0022  ;; we always doing anon private alloc
  xor   ebp, ebp            ;; offset, it is ignored, but why not
  mov   edi, # -1           ;; fd (-1)
  xor   ebx, ebx            ;; address
  mov   eax, # 192
  sys-call
  pop   ebp
  pop   edi
  cp    eax, # 0xffff_f000
  jnc   @@8
  push  eax
  mov   utos, # -1
  jmp   @@9
@@8:
  xor   utos, utos
@@9:
;code-swap-next

code-swap-no-inline: MUNMAP  ( addr size -- res )
  mov   ecx, utos ;; size
  pop   ebx
  mov   eax, # 91
  sys-call
  mov   utos, eax
;code-swap-next

;; can move block
code-swap-no-inline: MREMAP  ( addr oldsize newsize -- newaddr TRUE // FALSE )
  mov   edx, utos
  pop   ecx
  pop   ebx
  push  edi
  mov   eax, # 163
  mov   esi, # 1    ;; MREMAP_MAYMOVE
  xor   edi, edi    ;; new address; doesn't matter
  sys-call
  pop   edi
  cp    eax, # 0xffff_f000
  jnc   @@8
  push  eax
  mov   utos, # -1
  jmp   @@9
@@8:
  xor   utos, utos
@@9:
;code-swap-next


[[ tgt-build-base-binary ]] [IFNOT]
code-swap-no-inline: MMAP-FD  ( ofs size prot fd -- addr TRUE // FALSE )
  ;; EBX: fd
  pop   edx       ;; prot
  pop   ecx       ;; size
  pop   eax       ;; ofs
  ;; EDX: prot
  ;; EBX: address
  ;; ECX: length
  ;; EAX: ofs
  push  edi
  push  ebp
  ;; put everything to the proper registers
  mov   ebp, eax  ;; offset
  mov   edi, utos ;; fd
  xor   ebx, ebx  ;; address
  ;; MAP-SHARED
  mov   esi, # $0000_0001
  ;; EBX: address
  ;; ECX: length
  ;; EDX: prot
  ;; ESI: flags
  ;; EDI: fd
  ;; EBP: offset
  mov   eax, # 192
  sys-call
  pop   ebp
  pop   edi
  cp    eax, # 0xffff_f000
  jnc   @@8
  push  eax
  mov   utos, # -1
  jmp   @@9
@@8:
  xor   utos, utos
@@9:
;code-swap-next

;; always does MS-SYNC | MS-INVALIDATE
code-swap-no-inline: MSYNC  ( addr size -- res )
  mov   ecx, utos ;; size
  pop   ebx
  mov   edx, # 6  ;; MS-SYNC | MS-INVALIDATE
  mov   eax, # 144
  sys-call
  mov   utos, eax
;code-swap-next
[ENDIF]

code-swap-no-inline: MPROTECT  ( addr size prot -- res )
  mov   edx, utos
  pop   ecx
  pop   ebx
  mov   eax, # 125
  sys-call
  mov   utos, eax
;code-swap-next

code-swap-no-inline: MADVISE  ( addr size advice -- res )
  mov   edx, utos
  pop   ecx
  pop   ebx
  mov   eax, # 219
  sys-call
  mov   utos, eax
;code-swap-next


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[[ tgt-build-base-binary ]] [IFNOT]
 1 constant LOCK-SH
 2 constant LOCK-EX
 4 constant LOCK-NB
 5 constant LOCK-SH-NB
 6 constant LOCK-EX-NB
 8 constant LOCK-UN

;; 0 on ok
;; EAGAIN if already locked
code-swap-no-inline: (FLOCK)  ( cmd fd -- res )
  pop   ecx       ;; ECX is cmd
  mov   eax, # 143
  sys-call
  mov   utos, eax
;code-swap-next

;; 0 on ok
;; EAGAIN if already locked
{no-inline}
: FLOCK  ( cmd fd -- success-flag? )
  << 2dup (flock) dup EINTR = ?^| drop |? else| nrot 2drop >> 0= ;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  0 constant DENT.ino     ;; rd 1
  4 constant DENT.doff    ;; rd 1
  8 constant DENT.reclen  ;; rw 1
\ 10 constant DENT.type    ;; rb 1
\ 11 constant DENT.resv    ;; rb 1
 10 constant DENT.name
288 constant #DENT

  0 constant DENT64.ino     ;; rq 1
  8 constant DENT64.doff    ;; rq 1
 16 constant DENT64.reclen  ;; rw 1
\ 18 constant DENT64.type    ;; rb 1
\ 19 constant DENT64.resv    ;; rb 1
 18 constant DENT64.name
288 constant #DENT64


code-swap-no-inline: GETDENTS  ( addr count dfd -- res )
  pop   edx
  pop   ecx
  mov   eax, # 141
  sys-call
  mov   utos, eax
;code-swap-next

code-swap-no-inline: GETDENTS64  ( addr count dfd -- res )
  pop   edx
  pop   ecx
  mov   eax, # 220
  sys-call
  mov   utos, eax
;code-swap-next
[ENDIF]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
code-swap-no-inline: (READLINK)  ( addrz dest dcount -- rdcount )
  mov   edx, utos
  pop   ecx
  pop   ebx
  mov   eax, # 85
  sys-call
  mov   utos, eax
;code-swap-next


(*
;; this code is totally MT-unsafe!
;; there is no way to use BRK in thread-safe manner without
;; all threads cooperating (i.e. using a single entry point to call BRK).
;; UrForth itself doesn't use threads (yet ;-), but shared libraries may.
;; i don't know why the kernel doesn't provide "BRK-BUMP" syscall. yet
;; another fuckin' idiocity of Linux, i guess.

;; returns current address if the request is invalid
code-naked: (BRK)  ( newaddr -- newaddr )
  mov   eax, # 45  ;; brk
  sys-call
  mov   utos, eax
;code-no-stacks (no-stacks)
*)


[[dynamic?]] [IF]
$00000001 constant RTLD_LAZY
$00000100 constant RTLD_GLOBAL

code-naked-no-inline: (dlopen)  ( addr flags -- handle )
  upop  ecx
  mov   edx, dword^ # (SYS-ESP^)
  lea   edx, [edx+] # -16
  ;; save our ESP
  mov   [edx+] 4 #, esp
  mov   [edx+] 8 #, ebp
  ;; switch to the system stack
  mov   esp, edx
  mov   ebp, edx
  ;; degenerative GCC broke x86 ABI, hence this shit
  push  # 0
  push  # 0
  push  ebx
  push  ecx
  ;; save ESP (for recursive invokes from callbacks)
  mov   dword^ (SYS-ESP^) #, esp
  call  dword^ # tcom:dlopen-va
  mov   esp, [ebp+] # 4   ;; our ESP
  mov   ebx, [ebp+] # 8   ;; our EBP, wi'll restore it later
  lea   ebp, [ebp+] # 16  ;; drop the stack frame we created on the OS stack
  mov   dword^ (SYS-ESP^) #, ebp
  mov   ebp, ebx
  ;; we restored everything
  mov   utos, eax         ;; return the result
;code-next

code-naked-no-inline: (dlsym)  ( addr handle -- addr )
  upop  ecx
  mov   edx, dword^ # (SYS-ESP^)
  lea   edx, [edx+] # -16
  ;; save our ESP
  mov   [edx+] 4 #, esp
  mov   [edx+] 8 #, ebp
  ;; switch to the system stack
  mov   esp, edx
  mov   ebp, edx
  ;; degenerative GCC broke x86 ABI, hence this shit
  push  # 0
  push  # 0
  push  ecx
  push  ebx
  ;; save ESP (for recursive invokes from callbacks)
  mov   dword^ (SYS-ESP^) #, esp
  call  dword^ # tcom:dlsym-va
  mov   esp, [ebp+] # 4   ;; our ESP
  mov   ebx, [ebp+] # 8   ;; our EBP, wi'll restore it later
  lea   ebp, [ebp+] # 16  ;; drop the stack frame we created on the OS stack
  mov   dword^ (SYS-ESP^) #, ebp
  mov   ebp, ebx
  ;; we restored everything
  mov   utos, eax         ;; return the result
;code-next

code-naked-no-inline: (dlclose)  ( handle -- addr )
  mov   edx, dword^ # (SYS-ESP^)
  lea   edx, [edx+] # -16
  ;; save our ESP
  mov   [edx+] 4 #, esp
  mov   [edx+] 8 #, ebp
  ;; switch to the system stack
  mov   esp, edx
  mov   ebp, edx
  ;; degenerative GCC broke x86 ABI, hence this shit
  push  # 0
  push  # 0
  push  # 0
  push  ebx
  ;; save ESP (for recursive invokes from callbacks)
  mov   dword^ (SYS-ESP^) #, esp
  call  dword^ # tcom:dlclose-va
  mov   esp, [ebp+] # 4   ;; our ESP
  mov   ebx, [ebp+] # 8   ;; our EBP, wi'll restore it later
  lea   ebp, [ebp+] # 16  ;; drop the stack frame we created on the OS stack
  mov   dword^ (SYS-ESP^) #, ebp
  mov   ebp, ebx
  ;; we restored everything
  mov   utos, eax         ;; return the result
;code-next


;; invoke function from shared library.
;; for cdecl, args arg in natural order.
;; we cannot use our CPU stack, because it is usally very small (about 4KB),
;; so switch to the stack provided by the system (we saved ESP on startup).
code-naked-no-inline: (dlinvoke)  ( ... argc ptr -- retval )
  ;; there is no need to save any registers, due to x86 ABI.
  ;; i.e. we are using only callee-saved registers in our system.
  ;; but we have to setup ESP and EBP, so save them.
  ;; load argc (ptr is in TOS aka EBX).
  ;; we will drop arguments later.
  ;; we'll save our EBP and ESP onto the system stack.
  mov   edx, dword^ # (SYS-ESP^)
  lea   edx, [edx+] # -16
  ;; save our ESP
  mov   [edx+] 4 #, esp
  ;; switch to the system stack
  mov   esp, edx
  ;; EBP still points to the data stack
  upop  ecx   ;; argc
  ;; degenerative GCC broke x86 ABI, hence this shit
  ;; align stack to 16 bytes (ABI requires only 4, but g-shit-cc is The Fuckin' Boss)
  mov   eax, # 4
  sub   eax, ecx
  and   eax, # 3
  shl   eax, # 2
  sub   esp, eax
  ;; copy arguments
  begin,
    dec   ecx
  ns? while,
    upop  eax
    push  eax
  repeat,
  ;; save EBP (we popped everything here)
  mov   [edx+]  8 #, ebp
  ;; save ESP (for recursive invokes from callbacks)
  mov   dword^ (SYS-ESP^) #, esp
  ;; setup EBP (we'll use it to restore the OS stack)
  mov   ebp, edx
  ;; call the subroutine
  call  ebx
  ;; restore everything
  mov   esp, [ebp+] # 4   ;; our ESP
  mov   ebx, [ebp+] # 8   ;; our EBP, we'll restore it later
  lea   ebp, [ebp+] # 16  ;; drop the stack frame we created on the OS stack
  mov   dword^ (SYS-ESP^) #, ebp
  mov   ebp, ebx
  ;; we restored everything
  mov   utos, eax         ;; return the result
;code-next


;; invoke function from shared library.
;; for cdecl, args arg in natural order.
;; we cannot use our CPU stack, because it is usally very small (about 4KB),
;; so switch to the stack provided by the system (we saved ESP on startup).
code-naked-no-inline: (dlinvoke-ret64)  ( ... argc ptr -- retval-lo retval-hi )
  ;; there is no need to save any registers, due to x86 ABI.
  ;; i.e. we are using only callee-saved registers in our system.
  ;; but we have to setup ESP and EBP, so save them.
  ;; load argc (ptr is in TOS aka EBX).
  ;; we will drop arguments later.
  ;; we'll save our EBP and ESP onto the system stack.
  mov   edx, dword^ # (SYS-ESP^)
  lea   edx, [edx+] # -16
  ;; save our ESP
  mov   [edx+] 4 #, esp
  ;; switch to the system stack
  mov   esp, edx
  ;; EBP still points to the data stack
  upop  ecx   ;; argc
  ;; degenerative GCC broke x86 ABI, hence this shit
  ;; align stack to 16 bytes (ABI requires only 4, but g-shit-cc is The Fuckin' Boss)
  mov   eax, # 4
  sub   eax, ecx
  and   eax, # 3
  shl   eax, # 2
  sub   esp, eax
  ;; copy arguments
  begin,
    dec   ecx
  ns? while,
    upop  eax
    push  eax
  repeat,
  ;; save EBP (we popped everything here)
  mov   [edx+]  8 #, ebp
  ;; save ESP (for recursive invokes from callbacks)
  mov   dword^ (SYS-ESP^) #, esp
  ;; setup EBP (we'll use it to restore the OS stack)
  mov   ebp, edx
  ;; call the subroutine
  call  ebx
  ;; restore everything
  mov   esp, [ebp+] # 4   ;; our ESP
  mov   ebx, [ebp+] # 8   ;; our EBP, we'll restore it later
  lea   ebp, [ebp+] # 16  ;; drop the stack frame we created on the OS stack
  mov   dword^ (SYS-ESP^) #, ebp
  mov   ebp, ebx
  ;; we restored everything
  ;; return the result
  upush edx
  mov   utos, eax
;code-next
[ENDIF]


0 quan (GTC-START-SECS)

end-module LINUX


extend-module FORTH
using linux

[[ tgt-build-base-binary ]] [IFNOT]
{no-inline}
: MS-SLEEP  ( msecs )
  dup +?< 1000 u/mod nanoseconds/msec u* nanosleep >? drop ;
[ENDIF]

{no-inline}
: GET-MSECS  ( -- msecs )
  clock-monotonic clock-gettime nanoseconds/msec u/ swap 1+
  (gtc-start-secs) dup not?< drop dup dup (gtc-start-secs):! >?
  - 1000 u* + ;

[[dynamic?]] [IF]
{no-inline}
: DL-OPEN  ( addr count -- handle // 0 )  ensure-asciiz RTLD_LAZY RTLD_GLOBAL or (dlopen) ;
{no-inline}
: DL-CLOSE  ( handle )  (dlclose) drop ;
{no-inline}
: DL-SYM  ( addr count handle -- addr )  >r ensure-asciiz r> (dlsym) ;

: DL-INVOKE  ( ... argc ptr -- retval )  linux:(dlinvoke) ;
: DL-INVOKE-RET64  ( ... argc ptr -- retval )  linux:(dlinvoke-ret64) ;
[ENDIF]

: TIME  ( -- secs-since-epoch )  linux:time ;

end-module FORTH
