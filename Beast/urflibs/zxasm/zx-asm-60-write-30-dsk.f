;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Abersoft fig-FORTH extensions
;; coded by Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; .DSK writer
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module dsk
<disable-hash>
<private-words>

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create basic loader

;; basic loader name
create cargador-name 12 allot create;

@: set-cargador-name  ( addr count )
  cargador-name 12 blank
  0 max 8 min cargador-name swap cmove
  " .BAS"  cargador-name 12 string:-trailing + swap cmove ;
" cargador" set-cargador-name

@: set-autoload-cargador-name
  cargador-name 12 blank
  " DISK" cargador-name swap cmove ;

;; code block name
create cblock-name 12 allot create;

@: set-cblock-name  ( addr count )
  cblock-name 12 blank
  0 max 8 min cblock-name swap cmove
  " .BIN"  cblock-name 12 string:-trailing + swap cmove ;
" MCODE" set-cblock-name

create cargador 16384 allot create; ;; should be enough for everyone

0 quan cc-pos

|: cc-db,  ( byte )
  cc-pos 16384 u< not?error" out or cargador buffer"
  cc-pos cargador + c!
  cc-pos:1+! ;

|: cc-str  ( addr count )
  swap << over ?^| c@++ cc-db, 1 under- |? else| 2drop >> ;

|: cc-dec  ( num )
  lo-word base @ decimal swap <#s> cc-str base ! ;

|: cc-hex4  ( num )
  lo-word base @ hex swap <# # # # # #> cc-str base ! ;

|: create-cargador
  zxa:count-blocks not?error" no code blocks to write"
  cc-pos:!0
  ( line number ) 0 cc-db, 10 cc-db,
  ( line length ) 0 cc-db, 0 cc-db,
  ;; CLEAR VAL "xxx"
  " \xfd\xb0\'" cc-str zxa:clr@ cc-dec [char] " cc-db,
  ;; load blocks
  0 << zxa:next-block-from dup hi-word ?v||
    ;; :LOAD "name" CODE
    " :\xef\'MC#" cc-str
    dup cc-hex4
    " .BIN\'\xaf" cc-str
  ^| zxa:block-end-from | >> drop
  ;; and run
  zxa:ent@ ?<
    ;; :RANDOMIZE USR VAL "xxx"
    " :\xf9\xc0\xb0\'" cc-str zxa:ent@ cc-dec [char] " cc-db, >?
  ;; end of line
  13 cc-db,
  ;; patch line len
  cc-pos 4- cargador 2+ w! ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create tape file

;; basic loader
|: save-cargador
  create-cargador
  cargador-name 12 string:-trailing mk-cpcdsk:create-file
  cc-pos mk-cpcdsk:write-basic-header
  cargador cc-pos mk-cpcdsk:write
  mk-cpcdsk:close-file ;

;; uses "cblock-name" as name
@: save-code-block  ( addr count zx-start )
  over 1 65536 within not?error" invalid code block (len)"
  cblock-name 12 string:-trailing mk-cpcdsk:create-file
  lo-word over mk-cpcdsk:write-code-header
  mk-cpcdsk:write
  mk-cpcdsk:close-file ;

;; destroys "cblock-name"
|: save-zx-code  ( zx-addr-start zx-addr-end )
\ endcr ." BLOCK: start=$" over .hex8 ."  end=$" dup .hex8 cr
  2dup u>= ?error" invalid code block (len)"
  over hi-word over hi-word or ?error" invalid code block (addrs)"
  over - ( zx-addr-start len )
  ;; create code block name
  cblock-name 12 blank
  base @ >r hex
  over <# " .BIN" #holds # # # # " MC#" #holds #>
  cblock-name swap cmove
  r> base !
  endcr ." DSK: saving CODE block \'" cblock-name 12 string:-trailing type ." \'\n"
  ( zx-addr-start len )
  over zxa:mem:ram^ swap rot save-code-block ;

|: save-zx-code-blocks
  0 << ( zx-addr )
    zxa:next-block-from dup hi-word not?^|
      dup zxa:block-end-from ( zx-bstart zx-bend )
      2dup save-zx-code
      nip |?
  else| rdrop drop >> ;

@: save-all
  endcr ." DSK: saving BASIC loader \'" cargador-name 10 string:-trailing type ." \'\n"
  save-cargador
  save-zx-code-blocks ;

(*
@: save-fd  ( fd )
  endcr ." DSK: saving BASIC loader \'" cargador-name 10 string:-trailing type ." \'\n"
  dup tap-save-cargador
  tap-save-zx-code-blocks ;

@: create  ( addr count )
  file:create
  dup tap-save-fd
  file:close ;
*)

end-module (published)
