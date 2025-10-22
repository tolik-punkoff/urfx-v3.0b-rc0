;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OS-independent file i/o
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module FILE
<disable-hash>

0 constant SEEK-SET
1 constant SEEK-CUR
2 constant SEEK-END


{no-inline}
: UNLINK    ( addr count )  linux:unlink drop ;

{no-inline}
: CHMOD-NAME  ( mode addr count )  linux:chmod drop ;
{no-inline}
: CHMOD-FD    ( mode fd )  linux:chmod-fd drop ;

{no-inline}
: OPEN-R/O? ( addr count -- fd TRUE // FALSE )  linux:o-rdonly 0o644 linux:open ;

{no-inline}
|: ?OPEN  ( addr count flags -- fd )
  >r 2dup r> 0o644 linux:open
  not?< endcr ." ERROR: cannot open file '" type ." '\n" error" cannot open file" >?
  nrot 2drop ;

{no-inline}
: OPEN-R/O  ( addr count -- fd )  linux:o-rdonly ?open ;
{no-inline}
: OPEN-R/W  ( addr count -- fd )  linux:o-rdwr ?open ;
{no-inline}
: OPEN/CREATE-R/W  ( addr count -- fd )  [ linux:o-rdwr linux:o-creat or ] {#,} ?open ;
{no-inline}
: CREATE  ( addr count -- fd )  [ linux:o-rdwr linux:o-creat or linux:o-trunc or ] {#,} ?open ;
{no-inline}
: CLOSE  ( fd )  linux:close 0< ?error" error closing file" ;

{no-inline}
: TELL  ( fd -- pos )  0 linux:seek-cur rot linux:lseek dup -1 = ?error" cannot get file position" ;

{no-inline}
: SEEK-EX  ( ofs whence fd )  linux:lseek -1 = ?error" cannot set file position" ;
{no-inline}
: SEEK     ( ofs fd )         seek-set swap seek-ex ;

{no-inline}
: SIZE     ( fd -- size )  linux:(statbuf) swap linux:(stat-fd) ?error" cannot get file size"
                           linux:(statbuf) linux:stat.size + @ ;

{no-inline}
: MTIME    ( fd -- mtime ) linux:(statbuf) swap linux:(stat-fd) ?error" cannot get file time"
                           linux:(statbuf) linux:stat.mtime + @ ;

{no-inline}
: READ  ( addr count fd -- rdsize )
  over 0< ?error" invalid read count" linux:read dup 0< ?error" error reading file" ;

{no-inline}
: READ-EXACT  ( addr count fd )
  over 0< ?error" invalid read count" over >r linux:read r> <> ?error" error reading file" ;

{no-inline}
: WRITE  ( addr count fd )
  over 0< ?error" invalid write count" over >r linux:write r> <> ?error" error writing file" ;

{no-inline}
;; return -1 on any error
: NAMED-SIZE  ( addr count -- size )  linux:stat-size not?< -1 >? ;

{no-inline}
: EXIST?  ( addr count -- flag )  linux:(statbuf) linux:stat 0= ;
{no-inline}
: FILE?   ( addr count -- flag )  linux:file? ;
{no-inline}
: DIR?    ( addr count -- flag )  linux:dir? ;

end-module FILE
