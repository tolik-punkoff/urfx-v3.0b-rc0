;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple SQLite3 interface
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
$use <dlx>
$use <xobj>


module SQ3
<disable-hash>

;; SQLite3 import module
module API

0 constant SQLITE_OK          ;; Successful result
;; beginning-of-error-codes
1 constant SQLITE_ERROR       ;; Generic error
2 constant SQLITE_INTERNAL    ;; Internal logic error in SQLite
3 constant SQLITE_PERM        ;; Access permission denied
4 constant SQLITE_ABORT       ;; Callback routine requested an abort
5 constant SQLITE_BUSY        ;; The database file is locked
6 constant SQLITE_LOCKED      ;; A table in the database is locked
7 constant SQLITE_NOMEM       ;; A malloc() failed
8 constant SQLITE_READONLY    ;; Attempt to write a readonly database
9 constant SQLITE_INTERRUPT   ;; Operation terminated by sqlite3_interrupt()
10 constant SQLITE_IOERR      ;; Some kind of disk I/O error occurred
11 constant SQLITE_CORRUPT    ;; The database disk image is malformed
12 constant SQLITE_NOTFOUND   ;; Unknown opcode in sqlite3_file_control()
13 constant SQLITE_FULL       ;; Insertion failed because database is full
14 constant SQLITE_CANTOPEN   ;; Unable to open the database file
15 constant SQLITE_PROTOCOL   ;; Database lock protocol error
16 constant SQLITE_EMPTY      ;; Internal use only
17 constant SQLITE_SCHEMA     ;; The database schema changed
18 constant SQLITE_TOOBIG     ;; String or BLOB exceeds size limit
19 constant SQLITE_CONSTRAINT ;; Abort due to constraint violation
20 constant SQLITE_MISMATCH   ;; Data type mismatch
21 constant SQLITE_MISUSE     ;; Library used incorrectly
22 constant SQLITE_NOLFS      ;; Uses OS features not supported on host
23 constant SQLITE_AUTH       ;; Authorization denied
24 constant SQLITE_FORMAT     ;; Not used
25 constant SQLITE_RANGE      ;; 2nd parameter to sqlite3_bind out of range
26 constant SQLITE_NOTADB     ;; File opened that is not a database file
27 constant SQLITE_NOTICE     ;; Notifications from sqlite3_log()
28 constant SQLITE_WARNING    ;; Warnings from sqlite3_log()

100 constant SQLITE_ROW   ;; sqlite3_step() has another row ready
101 constant SQLITE_DONE  ;; sqlite3_step() has finished executing

;; extended error codes
1 8 lshift SQLITE_ERROR or constant SQLITE_ERROR_MISSING_COLLSEQ
2 8 lshift SQLITE_ERROR or constant SQLITE_ERROR_RETRY
3 8 lshift SQLITE_ERROR or constant SQLITE_ERROR_SNAPSHOT
1 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_READ
2 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_SHORT_READ
3 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_WRITE
4 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_FSYNC
5 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_DIR_FSYNC
6 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_TRUNCATE
7 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_FSTAT
8 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_UNLOCK
9 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_RDLOCK
10 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_DELETE
11 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_BLOCKED
12 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_NOMEM
13 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_ACCESS
14 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_CHECKRESERVEDLOCK
15 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_LOCK
16 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_CLOSE
17 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_DIR_CLOSE
18 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_SHMOPEN
19 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_SHMSIZE
20 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_SHMLOCK
21 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_SHMMAP
22 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_SEEK
23 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_DELETE_NOENT
24 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_MMAP
25 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_GETTEMPPATH
26 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_CONVPATH
27 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_VNODE
28 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_AUTH
29 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_BEGIN_ATOMIC
30 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_COMMIT_ATOMIC
31 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_ROLLBACK_ATOMIC
32 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_DATA
33 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_CORRUPTFS
34 8 lshift SQLITE_IOERR or constant SQLITE_IOERR_IN_PAGE
1 8 lshift SQLITE_LOCKED or constant SQLITE_LOCKED_SHAREDCACHE
2 8 lshift SQLITE_LOCKED or constant SQLITE_LOCKED_VTAB
1 8 lshift SQLITE_BUSY or constant SQLITE_BUSY_RECOVERY
2 8 lshift SQLITE_BUSY or constant SQLITE_BUSY_SNAPSHOT
3 8 lshift SQLITE_BUSY or constant SQLITE_BUSY_TIMEOUT
1 8 lshift SQLITE_CANTOPEN or constant SQLITE_CANTOPEN_NOTEMPDIR
2 8 lshift SQLITE_CANTOPEN or constant SQLITE_CANTOPEN_ISDIR
3 8 lshift SQLITE_CANTOPEN or constant SQLITE_CANTOPEN_FULLPATH
4 8 lshift SQLITE_CANTOPEN or constant SQLITE_CANTOPEN_CONVPATH
\ 5 8 lshift SQLITE_CANTOPEN or constant SQLITE_CANTOPEN_DIRTYWAL /* Not Used */
6 8 lshift SQLITE_CANTOPEN or constant SQLITE_CANTOPEN_SYMLINK
1 8 lshift SQLITE_CORRUPT or constant SQLITE_CORRUPT_VTAB
2 8 lshift SQLITE_CORRUPT or constant SQLITE_CORRUPT_SEQUENCE
3 8 lshift SQLITE_CORRUPT or constant SQLITE_CORRUPT_INDEX
1 8 lshift SQLITE_READONLY or constant SQLITE_READONLY_RECOVERY
2 8 lshift SQLITE_READONLY or constant SQLITE_READONLY_CANTLOCK
3 8 lshift SQLITE_READONLY or constant SQLITE_READONLY_ROLLBACK
4 8 lshift SQLITE_READONLY or constant SQLITE_READONLY_DBMOVED
5 8 lshift SQLITE_READONLY or constant SQLITE_READONLY_CANTINIT
6 8 lshift SQLITE_READONLY or constant SQLITE_READONLY_DIRECTORY
2 8 lshift SQLITE_ABORT or constant SQLITE_ABORT_ROLLBACK
1 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_CHECK
2 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_COMMITHOOK
3 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_FOREIGNKEY
4 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_FUNCTION
5 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_NOTNULL
6 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_PRIMARYKEY
7 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_TRIGGER
8 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_UNIQUE
9 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_VTAB
10 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_ROWID
11 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_PINNED
12 8 lshift SQLITE_CONSTRAINT or constant SQLITE_CONSTRAINT_DATATYPE
1 8 lshift SQLITE_NOTICE or constant SQLITE_NOTICE_RECOVER_WAL
2 8 lshift SQLITE_NOTICE or constant SQLITE_NOTICE_RECOVER_ROLLBACK
3 8 lshift SQLITE_NOTICE or constant SQLITE_NOTICE_RBU
1 8 lshift SQLITE_WARNING or constant SQLITE_WARNING_AUTOINDEX
1 8 lshift SQLITE_AUTH or constant SQLITE_AUTH_USER
1 8 lshift SQLITE_OK or constant SQLITE_OK_LOAD_PERMANENTLY
;; internal use only
\ 2 8 lshift SQLITE_OK or constant SQLITE_OK_SYMLINK


0x00000001 constant SQLITE_OPEN_READONLY
0x00000002 constant SQLITE_OPEN_READWRITE
0x00000004 constant SQLITE_OPEN_CREATE
0x00000008 constant SQLITE_OPEN_DELETEONCLOSE
0x00000010 constant SQLITE_OPEN_EXCLUSIVE
0x00000020 constant SQLITE_OPEN_AUTOPROXY
0x00000040 constant SQLITE_OPEN_URI
0x00000080 constant SQLITE_OPEN_MEMORY
\ 0x00000100 constant SQLITE_OPEN_MAIN_DB
\ 0x00000200 constant SQLITE_OPEN_TEMP_DB
\ 0x00000400 constant SQLITE_OPEN_TRANSIENT_DB
\ 0x00000800 constant SQLITE_OPEN_MAIN_JOURNAL
\ 0x00001000 constant SQLITE_OPEN_TEMP_JOURNAL
\ 0x00002000 constant SQLITE_OPEN_SUBJOURNAL
\ 0x00004000 constant SQLITE_OPEN_SUPER_JOURNAL
0x00008000 constant SQLITE_OPEN_NOMUTEX
0x00010000 constant SQLITE_OPEN_FULLMUTEX
0x00020000 constant SQLITE_OPEN_SHAREDCACHE
0x00040000 constant SQLITE_OPEN_PRIVATECACHE
\ 0x00080000 constant SQLITE_OPEN_WAL
0x01000000 constant SQLITE_OPEN_NOFOLLOW
0x02000000 constant SQLITE_OPEN_EXRESCODE

(*
1 constant SQLITE_CONFIG_SINGLETHREAD
2 constant SQLITE_CONFIG_MULTITHREAD
3 constant SQLITE_CONFIG_SERIALIZED
4 constant SQLITE_CONFIG_MALLOC
5 constant SQLITE_CONFIG_GETMALLOC
6 constant SQLITE_CONFIG_SCRATCH
7 constant SQLITE_CONFIG_PAGECACHE
8 constant SQLITE_CONFIG_HEAP
9 constant SQLITE_CONFIG_MEMSTATUS
10 constant SQLITE_CONFIG_MUTEX
11 constant SQLITE_CONFIG_GETMUTEX
13 constant SQLITE_CONFIG_LOOKASIDE
14 constant SQLITE_CONFIG_PCACHE
15 constant SQLITE_CONFIG_GETPCACHE
*)
16 constant SQLITE_CONFIG_LOG
(*
17 constant SQLITE_CONFIG_URI
18 constant SQLITE_CONFIG_PCACHE2
19 constant SQLITE_CONFIG_GETPCACHE2
20 constant SQLITE_CONFIG_COVERING_INDEX_SCAN
21 constant SQLITE_CONFIG_SQLLOG
22 constant SQLITE_CONFIG_MMAP_SIZE
23 constant SQLITE_CONFIG_WIN32_HEAPSIZE
24 constant SQLITE_CONFIG_PCACHE_HDRSZ
25 constant SQLITE_CONFIG_PMASZ
26 constant SQLITE_CONFIG_STMTJRNL_SPILL
27 constant SQLITE_CONFIG_SMALL_MALLOC
28 constant SQLITE_CONFIG_SORTERREF_SIZE
29 constant SQLITE_CONFIG_MEMDB_MAXSIZE
30 constant SQLITE_CONFIG_ROWID_IN_VIEW
*)

(*
1000 constant SQLITE_DBCONFIG_MAINDBNAME
1001 constant SQLITE_DBCONFIG_LOOKASIDE
1002 constant SQLITE_DBCONFIG_ENABLE_FKEY
1003 constant SQLITE_DBCONFIG_ENABLE_TRIGGER
1004 constant SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER
1005 constant SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION
1006 constant SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE
1007 constant SQLITE_DBCONFIG_ENABLE_QPSG
1008 constant SQLITE_DBCONFIG_TRIGGER_EQP
1009 constant SQLITE_DBCONFIG_RESET_DATABASE
1010 constant SQLITE_DBCONFIG_DEFENSIVE
1011 constant SQLITE_DBCONFIG_WRITABLE_SCHEMA
1012 constant SQLITE_DBCONFIG_LEGACY_ALTER_TABLE
1013 constant SQLITE_DBCONFIG_DQS_DML
1014 constant SQLITE_DBCONFIG_DQS_DDL
1015 constant SQLITE_DBCONFIG_ENABLE_VIEW
1016 constant SQLITE_DBCONFIG_LEGACY_FILE_FORMAT
1017 constant SQLITE_DBCONFIG_TRUSTED_SCHEMA
1018 constant SQLITE_DBCONFIG_STMT_SCANSTATUS
1019 constant SQLITE_DBCONFIG_REVERSE_SCANORDER
1019 constant SQLITE_DBCONFIG_MAX
*)

(*
0x01 constant SQLITE_PREPARE_PERSISTENT
0x02 constant SQLITE_PREPARE_NORMALIZE
0x04 constant SQLITE_PREPARE_NO_VTAB
*)

 0 constant SQLITE_STATIC
-1 constant SQLITE_TRANSIENT


" sqlite3" dlx:register-type
" sqlite3_stmt" dlx:register-type
" sqlite3_value" dlx:register-type

" sqlite3_int64" dlx:register-type64
" sqlite3_uint64" dlx:register-type64

" sqlite3_filename" dlx:register-typeptr


dlx:library libsqlite3.so

dlx:import const char *sqlite3_libversion(void);
dlx:import const char *sqlite3_sourceid(void);
dlx:import int sqlite3_libversion_number(void);

dlx:import int sqlite3_initialize(void);
dlx:import int sqlite3_shutdown(void);

\ SQLITE_API int sqlite3_config(int, ...);
\ SQLITE_API int sqlite3_db_config(sqlite3*, int op, ...);

dlx:import int sqlite3_close(sqlite3*);
dlx:import int sqlite3_close_v2(sqlite3*);

dlx:import int sqlite3_exec(
  sqlite3*,
  const char *sql,
  void *callback,
  void *,
  char **errmsg
);

dlx:import int sqlite3_extended_result_codes(sqlite3*, int onoff);

dlx:import sqlite3_filename sqlite3_db_filename(sqlite3 *db, const char *zDbName);
dlx:import int sqlite3_db_readonly(sqlite3 *db, const char *zDbName);

dlx:import int sqlite3_txn_state(sqlite3*,const char *zSchema);

dlx:import sqlite3_stmt *sqlite3_next_stmt(sqlite3 *pDb, sqlite3_stmt *pStmt);

dlx:import sqlite3_int64 sqlite3_last_insert_rowid(sqlite3*);
dlx:import void sqlite3_set_last_insert_rowid(sqlite3*,sqlite3_int64);

dlx:import int sqlite3_changes(sqlite3*);
dlx:import sqlite3_int64 sqlite3_changes64(sqlite3*);

dlx:import int sqlite3_total_changes(sqlite3*);
dlx:import sqlite3_int64 sqlite3_total_changes64(sqlite3*);

dlx:import void sqlite3_interrupt(sqlite3*);
dlx:import int sqlite3_is_interrupted(sqlite3*);

dlx:import int sqlite3_complete(const char *sql);
\ dlx:import int sqlite3_complete16(const void *sql);

dlx:import int sqlite3_busy_timeout(sqlite3*, int ms);

(*
dlx:import int sqlite3_open(
  const char *filename,
  sqlite3 **ppDb
);
*)
dlx:import int sqlite3_open_v2(
  const char *filename,
  sqlite3 **ppDb,
  int flags,
  const char *zVfs
);

dlx:import int sqlite3_errcode(sqlite3 *db);
dlx:import int sqlite3_extended_errcode(sqlite3 *db);
dlx:import const char *sqlite3_errmsg(sqlite3*);
\ dlx:import const void *sqlite3_errmsg16(sqlite3*);
dlx:import const char *sqlite3_errstr(int);
dlx:import int sqlite3_error_offset(sqlite3 *db);

dlx:import int sqlite3_prepare_v2(
  sqlite3 *db,
  const char *zSql,
  int nByte,
  sqlite3_stmt **ppStmt,
  const char **pzTail
);

dlx:import sqlite3 *sqlite3_db_handle(sqlite3_stmt*);


dlx:import int sqlite3_bind_blob(sqlite3_stmt*, int, const void*, int n, void* clrcb);
\ dlx:import int sqlite3_bind_double(sqlite3_stmt*, int, double);
dlx:import int sqlite3_bind_int(sqlite3_stmt*, int, int);
dlx:import int sqlite3_bind_int64(sqlite3_stmt*, int, sqlite3_int64);
dlx:import int sqlite3_bind_null(sqlite3_stmt*, int);
dlx:import int sqlite3_bind_text(sqlite3_stmt*,int,const char*,int,void* clrcb);
\ dlx:import int sqlite3_bind_text16(sqlite3_stmt*, int, const void*, int, void *clrcb);
dlx:import int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);
dlx:import int sqlite3_bind_pointer(sqlite3_stmt*, int, void*, const char*,void* clrcb);
dlx:import int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);

dlx:import int sqlite3_bind_parameter_count(sqlite3_stmt*);
dlx:import const char *sqlite3_bind_parameter_name(sqlite3_stmt*, int);
dlx:import int sqlite3_bind_parameter_index(sqlite3_stmt*, const char *zName);

dlx:import int sqlite3_clear_bindings(sqlite3_stmt*);

dlx:import int sqlite3_column_count(sqlite3_stmt *pStmt);
dlx:import const char *sqlite3_column_name(sqlite3_stmt*, int N);
\ dlx:import const void *sqlite3_column_name16(sqlite3_stmt*, int N);

dlx:import const char *sqlite3_column_database_name(sqlite3_stmt*,int);
\ dlx:import const void *sqlite3_column_database_name16(sqlite3_stmt*,int);
dlx:import const char *sqlite3_column_table_name(sqlite3_stmt*,int);
\ dlx:import const void *sqlite3_column_table_name16(sqlite3_stmt*,int);
dlx:import const char *sqlite3_column_origin_name(sqlite3_stmt*,int);
\ dlx:import const void *sqlite3_column_origin_name16(sqlite3_stmt*,int);

dlx:import const char *sqlite3_column_decltype(sqlite3_stmt*,int);
\ dlx:import const void *sqlite3_column_decltype16(sqlite3_stmt*,int);

dlx:import int sqlite3_step(sqlite3_stmt*);

dlx:import int sqlite3_data_count(sqlite3_stmt *pStmt);

dlx:import const void *sqlite3_column_blob(sqlite3_stmt*, int iCol);
\ dlx:import double sqlite3_column_double(sqlite3_stmt*, int iCol);
dlx:import int sqlite3_column_int(sqlite3_stmt*, int iCol);
dlx:import sqlite3_int64 sqlite3_column_int64(sqlite3_stmt*, int iCol);
dlx:import const unsigned char *sqlite3_column_text(sqlite3_stmt*, int iCol);
\ dlx:import const void *sqlite3_column_text16(sqlite3_stmt*, int iCol);
dlx:import sqlite3_value *sqlite3_column_value(sqlite3_stmt*, int iCol);
dlx:import int sqlite3_column_bytes(sqlite3_stmt*, int iCol);
\ dlx:import int sqlite3_column_bytes16(sqlite3_stmt*, int iCol);
dlx:import int sqlite3_column_type(sqlite3_stmt*, int iCol);

dlx:import int sqlite3_finalize(sqlite3_stmt *pStmt);

dlx:import int sqlite3_reset(sqlite3_stmt *pStmt);


dlx:import int sqlite3_get_autocommit(sqlite3*);

dlx:import int sqlite3_stmt_readonly(sqlite3_stmt *pStmt);
dlx:import int sqlite3_stmt_isexplain(sqlite3_stmt *pStmt);

dlx:import const char *sqlite3_sql(sqlite3_stmt *pStmt);
dlx:import char *sqlite3_expanded_sql(sqlite3_stmt *pStmt);

\ SQLITE_API void sqlite3_log(int iErrCode, const char *zFormat, ...);
;; WARNING! do not pass strings with percents!
dlx:import void sqlite3_log(int iErrCode, const char *zFormat, const char *zStr) [sqlite3_log_str3];

\ SQLITE_API int sqlite3_config(int, ...);
dlx:import int sqlite3_config(int, void *val0, void *val1) [sqlite3_config_arg3];

dlx:close-library


@: ?err  ( 0 // err-code )
  dup ( SQLITE_OK =) 0?exit< drop >?
  " SQLITE OPEN ERROR: " pad$:!
  sqlite3_errstr zcount pad$:+
  pad$:@ error ;

end-module API

using API


;; must be at quote char
|: (skip-quote)  ( addr count -- addr count )
  over c@ >r string:/char
  r> string:scan-until string:/char ;

|: (skip-ml-comment)  ( addr count -- addr count )
  << [char] * string:scan-until
     dup 2 < ?v| drop 0 |?
     over w@ $2F_2A = not?^| string:/char |?
  else| >> ;

;; split SQL string on ";".
;; ( a1 c1 ) is the rest (after semicolon).
;; ( a2 c2 ) is the first statement (with semicolon).
;; doesn't process string escapes.
@: split-sql  ( addr count -- a1 c1 a2 c2 )
  0 max string:skip-blanks 2dup
  ( addr count addr count )
  << string:skip-blanks
     dup 0?v||
       \ endcr ." REST=<" 2dup type ." >\n"
     over c@ dup [char] ; = ?v| drop string:/char |?
     dup 34 = swap 39 = or ?^| (skip-quote) |?
     over w@ <<
       $2D_2D of?v| 10 string:scan-until |?
       $2A_2F of?v| string:/2chars (skip-ml-comment) |?
     else| drop string:/char >>
  ^|| >>
  ( addr count a2 c2 )
  rot over - nrot
  2swap
  string:skip-blanks ;

0 quan sq3-err-log-cback

;; scan for ` in "`
|: (sq3-error-msg?)  ( zMsg -- flag )
  zcount 2dup string:scan-eol ?< nip >?
  "  in \'" string:search nrot 2drop ;

|: (sq3-type-other)  ( zMsg need-cr? )
  >r  ( need-cr? )
  zcount <<
    dup 0?v| 2drop |?
    r> ?< ." \n ..> " >? false >r
    2dup string:scan-eol not?v| type |?
    >r over r@ 1- type r> string:/chars
  ^| true r! | >> rdrop ;

|: (sq3-type-error)  ( zMsg )
  dup zcount [char] " string:find-ch not?exit< (sq3-type-other) >?
  1+ 2dup type +
  true (sq3-type-other) ;

|: (sq3-err-log-cback)  ( pArg iErrCode zMsg -- unused-res )
  \ endcr ." ***SQLITE ["
  \ swap sqlite3_errstr zcount type ." ]: " zcount type cr
  endcr ." ***SQLITE "
  swap <<
    SQLITE_NOTICE of?v| " NOTICE" true |?
    SQLITE_WARNING of?v| " WARNING" true |?
    SQLITE_NOTICE_RECOVER_WAL of?v| " WAL-RECOVER" true |?
    SQLITE_NOTICE_RECOVER_ROLLBACK of?v| " ROLLBACK-RECOVER" true |?
    SQLITE_WARNING_AUTOINDEX of?v| " AUTOINDEX" true |?
    SQLITE_SCHEMA of?v| " SCHEMA" true |?
  else| ." (" 0.r ." )" false >>
  ?< type >? ." : "
  dup (sq3-error-msg?) ?< (sq3-type-error) || false (sq3-type-other) >?
  cr
  drop 0 ;
3 ['] (sq3-err-log-cback) callback:new sq3-err-log-cback:!


true quan error-callback? (published)

: set-error-log-cb
  error-callback? not?exit
  SQLITE_CONFIG_LOG sq3-err-log-cback 0
  sqlite3_config_arg3 drop ;

@: disable-error-log
  error-callback?:!f
  SQLITE_CONFIG_LOG 0 0
  sqlite3_config_arg3 drop ;


@: sq3-log  ( addr count )
  dup -0?exit< 2drop >?
  linux:ensure-asciiz
  SQLITE_NOTICE swap " %s" drop swap sqlite3_log_str3 ;

@: sq3-warning  ( addr count )
  dup -0?exit< 2drop >?
  linux:ensure-asciiz
  SQLITE_WARNING swap " %s" drop swap sqlite3_log_str3 ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; database class

struct:new obj-db
  field: dbx  -- database handle
  field: do-optimise?
end-struct obj-db

;; db object methods
module DBO-MTX
<disable-hash>

: handle  ( -- handle )  xobj:self obj-db:dbx ;

: opened?  ( -- flag )  handle 0<> ;

: autocommit?  ( -- flag )
  opened? not?exit< true >?
  handle sqlite3_get_autocommit 0<> ;

|: (open-with-flags)  ( addr count flags -- sqlite3db* err )
  opened? ?error" database already opened"
  set-error-log-cb
  SQLITE_OPEN_EXRESCODE ( SQLITE_OPEN_URI or) or
  xobj:self obj-db:@size-of erase
  >loc linux:ensure-asciiz
  0 >r (rp@)
  loc> 0 sqlite3_open_v2
  r> swap ;

: open-r/o  ( addr count )
  SQLITE_OPEN_READONLY (open-with-flags) ?err
  xobj:self obj-db:dbx:! ;

: open-r/w  ( addr count )
  SQLITE_OPEN_READWRITE (open-with-flags) ?err
  xobj:self obj-db:dbx:!
  xobj:self obj-db:do-optimise?:!t ;

: open-r/w-create  ( addr count )
  SQLITE_OPEN_READWRITE SQLITE_OPEN_CREATE or
  (open-with-flags) ?err
  xobj:self obj-db:dbx:!
  xobj:self obj-db:do-optimise?:!t ;


: open-r/o?  ( addr count -- success-flag )
  SQLITE_OPEN_READONLY
  (open-with-flags) SQLITE_OK = not?exit< drop false >?
  xobj:self obj-db:dbx:!
  true ;

: open-r/w?  ( addr count -- success-flag )
  SQLITE_OPEN_READWRITE
  (open-with-flags) SQLITE_OK = not?exit< drop false >?
  xobj:self obj-db:dbx:!
  xobj:self obj-db:do-optimise?:!t
  true ;

: open-r/w-create?  ( addr count -- success-flag )
  SQLITE_OPEN_READWRITE SQLITE_OPEN_CREATE or
  (open-with-flags) SQLITE_OK = not?exit< drop false >?
  xobj:self obj-db:dbx:!
  xobj:self obj-db:do-optimise?:!t
  true ;


: timeout!  ( msecs )
  handle swap sqlite3_busy_timeout ?err ;

;; executes semicolon-serapated SQL statements
: execute  ( addr count )
    \ >r endcr ." EXEC:<" 2dup type ." >\n" r>
  linux:ensure-asciiz
  handle swap
  0 0 0 sqlite3_exec ?err ;

: close  ( -- )
  opened? not?exit
  xobj:self obj-db:do-optimise? ?< " PRAGMA optimize;" execute >?
  handle sqlite3_close_v2 ?err
  xobj:self obj-db:@size-of erase ;

(*
;; executes all statements
: execute-all  ( addr count obj )
  >r << sq3:split-sql r@ execute dup ?^|| else| 2drop >> rdrop ;
*)

: changes  ( -- changes )
  handle sqlite3_changes 0 max ;

: total-changes  ( -- total-changes )
  handle sqlite3_total_changes 0 max ;

: changes64  ( -- changes-lo changes-hi )
  handle sqlite3_changes64 ;

: total-changes64  ( -- total-changes-lo total-changes-hi )
  handle sqlite3_total_changes64 0 max ;

: last-rowid-64  ( -- rowid-lo rowid-hi )
  handle sqlite3_last_insert_rowid ;

: last-rowid  ( -- rowid )
  handle sqlite3_last_insert_rowid
  dup ?error" rowid too big to fit in 32 bits" ;


: default-pragmas  ( -- )
<<<HDOC>>>
PRAGMA foreign_keys=OFF;
PRAGMA secure_delete=OFF;
PRAGMA trusted_schema=ON;
PRAGMA writable_schema=OFF;
PRAGMA auto_vacuum=NONE;
PRAGMA encoding='UTF-8';
>>>HDOC<<<
  execute ;

: journal-mode-delete  ( -- )
  " PRAGMA journal_mode=DELETE;" execute ;

: journal-mode-wal  ( -- )
  " PRAGMA journal_mode=WAL;" execute ;

: no-sync-mode  ( -- )
  " PRAGMA synchronous=OFF;" execute ;

: default-sync-mode  ( -- )
  " PRAGMA synchronous=NORMAL;" execute ;

: full-sync-mode  ( -- )
  " PRAGMA synchronous=FULL;" execute ;

end-module DBO-MTX

obj-db:@size-of vocid: dbo-mtx xobj:new-class dbh


@: new-dbo  \ name
  parse-name dbh:mk-obj ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; statement object

struct:new obj-st
  field: stx  -- statement handle
end-struct obj-st

;; db object methods
module STO-MTX
<disable-hash>

: handle  ( -- handle )  xobj:self obj-st:stx ;

: opened?  ( -- flag )  handle 0<> ;

: read-only?  ( -- flag )
  opened? not?exit< drop true >?
  handle sqlite3_stmt_readonly 0<> ;

: explain?  ( -- flag )
  opened? not?exit< drop true >?
  handle sqlite3_stmt_isexplain 0<> ;

: sql@  ( -- addr count )
  opened? not?exit< drop " " >?
  handle sqlite3_sql
  dup ?exit< zcount >?
  drop " " ;

: expanded-sql@  ( -- addr count )
  opened? not?exit< drop " " >?
  handle sqlite3_expanded_sql
  dup ?exit< zcount >?
  drop " " ;

: close  ( -- )
  handle dup 0?exit< drop >?
  sqlite3_finalize ?err
  xobj:self obj-st:stx:!0 ;

: prepare  ( addr count dbo )
  close
  dup dbh:is-a? not?error" database object expected"
  obj-db:dbx nrot
  0 >r (rp@)
  0 sqlite3_prepare_v2 ?err
  r> xobj:self obj-st:stx:! ;

: reset  ( -- )
  handle dup 0?exit< drop >?
  sqlite3_reset ?err ;


;; return TRUE if a row was fetched, or FALSE on done
: step  ( -- row? )
  handle sqlite3_step <<
    SQLITE_ROW of?v| true |?
    SQLITE_DONE of?v| reset false |?
    SQLITE_OK of?v| SQLITE_ERROR ?err |?
  else| ?err >> ;

: do-all
  << step ?^|| else| reset >> ;


: #cols  ( -- #columns )
  handle sqlite3_column_count ;

: col-name  ( idx -- addr count )
  handle swap sqlite3_column_name
  dup ?exit< zcount >?
  drop " " ;

: col-idx  ( addr count -- idx // -1 )
  #cols 0 << ( addr count limit idx )
    dup >r 2over r>
    ( addr count limit idx addr count idx )
    col-name string:=ci
    ( addr count limit idx strequ? )
    ?v| >r 3drop r> |?
  1+ 2dup > ?^||
  else| 4drop -1 >> ;

: col-int  ( idx -- int )
  handle swap sqlite3_column_int ;

: col-int64  ( idx -- int-lo int-hi )
  handle swap sqlite3_column_int64 ;

: col-bytes  ( idx -- size )
  handle swap sqlite3_column_bytes ;

: col-type  ( idx -- type )
  handle swap sqlite3_column_type ;

: col-blob  ( idx -- addr count )
  >r handle r@ sqlite3_column_blob
  dup 0?exit< rdrop 0 >?
  r> col-bytes ;

: col-text  ( idx -- addr count )
  >r handle r@ sqlite3_column_text
  dup 0?exit< rdrop 0 >?
  r> col-bytes ;

|: (scol-do)  ( addr count run-cfa -- ... )
  >r 2dup col-idx
  dup -?exit< rdrop drop
    " cannot find db result column \'" pad$:!
    pad$:+ " \'" pad$:+
    pad$:@ error >?
  nrot 2drop
  r> execute-tail ;

: scol-int  ( addr count -- int )  ['] col-int (scol-do) ;
: scol-int64  ( addr count -- int-lo int-hi )  ['] col-int64 (scol-do) ;
: scol-bytes  ( addr count -- bytes )  ['] col-bytes (scol-do) ;
: scol-type  ( addr count -- type )  ['] col-type (scol-do) ;
: scol-blob  ( addr count -- addr count )  ['] col-blob (scol-do) ;
: scol-text  ( addr count -- addr count )  ['] col-text (scol-do) ;


: reset-binds  ( -- )
  handle sqlite3_clear_bindings ?err ;

: #binds  ( -- bind-count )
  handle sqlite3_bind_parameter_count 0 max ;

: bind-name  ( idx -- addr count )
  handle swap sqlite3_bind_parameter_name
  dup ?exit< zcount >?
  drop " " ;

: bind-idx  ( addr count -- idx )
  linux:ensure-asciiz handle swap sqlite3_bind_parameter_index
  dup -0?< drop -1 >? ;

: bind-int  ( int idx )
  handle swap rot sqlite3_bind_int ?err ;

: bind-int64  ( int-lo int-hi idx )
  handle swap 2swap sqlite3_bind_int64 ?err ;

: bind-null  ( idx )
  handle swap sqlite3_bind_null ?err ;

: bind-zeroblob  ( size idx )
  handle swap rot sqlite3_bind_zeroblob ?err ;

: bind-text  ( addr count idx )
  handle swap 2swap
  dup 0< ?error" invalid bind text length"
  SQLITE_TRANSIENT sqlite3_bind_text ?err ;

: bind-const-text  ( addr count idx )
  handle swap 2swap
  dup 0< ?error" invalid bind text length"
  SQLITE_STATIC sqlite3_bind_text ?err ;

: bind-blob  ( addr count idx )
  handle swap 2swap
  dup 0< ?error" invalid bind blob length"
  SQLITE_TRANSIENT sqlite3_bind_blob ?err ;

: bind-const-blob  ( addr count idx )
  handle swap 2swap
  dup 0< ?error" invalid bind blob length"
  SQLITE_STATIC sqlite3_bind_blob ?err ;


|: (sbind-do)  ( addr count run-cfa -- ... )
  >r 2dup bind-idx
  dup -?exit< rdrop drop
    " cannot find db binding \'" pad$:!
    pad$:+ " \'" pad$:+
    pad$:@ error >?
  nrot 2drop
  r> execute-tail ;

: sbind-int  ( addr count -- int )  ['] bind-int (sbind-do) ;
: sbind-int64  ( addr count -- int-lo int-hi )  ['] bind-int64 (sbind-do) ;
: sbind-text  ( addr count -- addr count )  ['] bind-text (sbind-do) ;
: sbind-const-text  ( addr count -- addr count )  ['] bind-const-text (sbind-do) ;
: sbind-blob  ( addr count -- addr count )  ['] bind-blob (sbind-do) ;
: sbind-const-blob  ( addr count -- addr count )  ['] bind-const-blob (sbind-do) ;

end-module STO-MTX

obj-st:@size-of vocid: sto-mtx xobj:new-class stmt

@: new-stmt  \ name
  [\\] stmt:new-obj ;

end-module SQ3
