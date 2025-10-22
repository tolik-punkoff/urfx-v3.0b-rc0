;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Abersoft fig-FORTH extensions
;; coded by Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; .TAP writer
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module tap
<disable-hash>
<private-words>

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; options

<published-words>
enum{
  def: fmt-tap
  def: fmt-pzx
  \ def: fmt-tzx -- not supported yet
}

fmt-tap quan tape-format

;; this is what ROM save routine does
8063 quan long-pilot-length
3223 quan short-pilot-length
2168 quan pilot-pulses-count
 667 quan pilot-first-sync-pulse-length
 735 quan pilot-second-sync-pulse-length

true quan initial-data-pulse-high?
 945 quan tail-pulse-length
 855 quan zero-pulse-length
1710 quan one-pulse-length

;; address of the counted string, or 0.
;; saved into the header.
0 quan pzx-descrption$


create xxbuf 4 allot create;

|: (write-xxbuf)  ( count fd )
  xxbuf nrot file:write ;

|: (write-byte)  ( b fd )
  >r xxbuf !  1 r> (write-xxbuf) ;

|: (write-word)  ( w fd )
  >r xxbuf !  2 r> (write-xxbuf) ;

|: (write-dword) ( u fd )
  >r xxbuf !  4 r> (write-xxbuf) ;

|: (write-4cc)  ( addr count fd )
  over 4 = not?error" invalid 4CC code"
  file:write ;


@: save-pzx-header  ( fd )
  >r
  " PZXT" r@ (write-4cc)
  2 pzx-descrption$ ?< pzx-descrption$ count nip 1+ + >?
  r@ (write-dword)
  1 r@ (write-byte)
  0 r@ (write-byte)
  pzx-descrption$ ?<
    pzx-descrption$ count r@ file:write
    0 r@ (write-byte)
  >?
  rdrop ;


@: save-pilot  ( short? fd )
  >r
  " PULS" r@ (write-4cc)
  8 r@ (write-dword)  ;; block length
  ?< short-pilot-length || long-pilot-length >? 0x8000 or r@ (write-word)
  pilot-pulses-count r@ (write-word)
  pilot-first-sync-pulse-length r@ (write-word)
  pilot-second-sync-pulse-length r@ (write-word)
  rdrop ;

;; all service bits should be included
@: save-data  ( addr count fd )
  over 0 65580 within not?error" invalid counter"
  \ endcr ." PZX DATA: " over . ." bytes.\n"
  >r
  " DATA" r@ (write-4cc)
  ;; block length
  dup 4 +  2 +  2 +  4 2 * +  r@ (write-dword)
  ;; block header
  dup 8 * initial-data-pulse-high? ?< 0x8000_0000 + >? r@ (write-dword)
  tail-pulse-length r@ (write-word)
  2 r@ (write-byte)
  2 r@ (write-byte)
  zero-pulse-length r@ (write-word)
  zero-pulse-length r@ (write-word)
  one-pulse-length r@ (write-word)
  one-pulse-length r@ (write-word)
  ;; block data
  r@ file:write
  rdrop ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; create basic loader

false quan opt-one-code-file?

;; basic loader name
create cargador-name 10 allot create;

@: set-cargador-name  ( addr count )
  cargador-name 10 blank
  0 max 10 min cargador-name swap cmove ;
" cargador" set-cargador-name

@: set-one-code-file  ( value )
  opt-one-code-file?:! ;

;; code block name
create cblock-name 10 allot create;

@: set-cblock-name  ( addr count )
  cblock-name 10 blank
  0 max 10 min cblock-name swap cmove ;
" code" set-cblock-name

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

@: create-cargador
  zxa:count-blocks not?error" no code blocks to write"
  cc-pos:!0
  ( line number ) 0 cc-db, 10 cc-db,
  ( line length ) 0 cc-db, 0 cc-db,
  ;; CLEAR VAL "xxx"
  " \xfd\xb0\'" cc-str zxa:clr@ cc-dec [char] " cc-db,
  ;; load blocks
  opt-one-code-file? ?<
    ;; :LOAD "" CODE
    " :\xef\'\'\xaf" cc-str
  ||
    0 << zxa:next-block-from dup hi-word ?v||
      ;; :LOAD "" CODE
      " :\xef\'\'\xaf" cc-str
    ^| zxa:block-end-from | >> drop
  >?
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

create tap-buf 32 allot create;

@: tap-checksum  ( addr count flag-byte -- checksum )
  >r swap << over ?^| c@++ r> xor >r 1 under- |? else| 2drop r> >> ;

@: tap-mk-header  ( addr count type )
  tap-buf 32 erase
  $13 tap-buf w!
  tap-buf 3 + c!  ;; type
  0 10 clamp
  tap-buf 4+ 10 blank
  tap-buf 4+ swap cmove ;

@: tap-header-len!  ( len )
  dup tap-buf 14 + w!
  tap-buf 18 + w! ;

@: tap-header-autostart!  ( line )
  tap-buf 16 + w! ;

@: tap-code-start!  ( zx-addr )
  tap-buf 16 + w!
  $807C tap-buf 18 + w! ;


@: tap-save-data-with-flag-byte-tap  ( addr len flag-byte fd )
  >r
  over 2+ tap-buf w!  ;; total block length
  tap-buf 2+ c!   ;; flag byte
  tap-buf 3 r@ file:write  ;; length and flag byte
  2dup r@ file:write  ;; data
  \ $FF
  tap-buf 2+ c@ ;; use proper first byte
  tap-checksum tap-buf c!
  ( checksum byte) tap-buf 1 r> file:write ;

create pzxbuf 65800 allot create;

@: tap-save-data-with-flag-byte-pzx  ( addr len flag-byte fd )
  \ endcr ." PZX: " 2over . drop ." bytes.\n"
  >r
  over 0 65535 within not?error" invalid tape data length"
  dup lo-byte $80 > r@ save-pilot
  pzxbuf c!
  dup >r  ;; save length
  ?< pzxbuf 1+ r@ cmove || drop >?
  r> 1+
  ( full-len | fd )
  pzxbuf 1+ over 1- pzxbuf c@ tap-checksum
  >r pzxbuf over + r> swap c!
  pzxbuf swap 1+ r> save-data ;


;; this can be used to save headerless byte block
@: tap-save-data-with-flag-byte  ( addr len flag-byte fd )
  tape-format <<
    fmt-tap of?v| tap-save-data-with-flag-byte-tap |?
    fmt-pzx of?v| tap-save-data-with-flag-byte-pzx |?
  else| error" invalid tape format" >> ;


;; create initial PZX header; does nothing for TAP
@: tap-save-initial-header  ( fd )
  tape-format <<
    fmt-tap of?v| drop |?
    fmt-pzx of?v| save-pzx-header |?
  else| error" invalid tape format" >> ;


;; save built header
@: tap-save-header  ( fd )
  (*
  tap-buf 2+ 18 0 tap-checksum
  tap-buf 20 + c!
  tap-buf 21 rot file:write ;
  *)
  >r tap-buf 3 + 17 $00 r> tap-save-data-with-flag-byte ;


;; this can be used to save headerless byte block
@: tap-save-data  ( addr len fd )
  $FF swap tap-save-data-with-flag-byte ;


;; basic loader
@: tap-save-cargador  ( fd )
  create-cargador
  cargador-name 10 0 tap-mk-header
  cc-pos tap-header-len!
  10 tap-header-autostart!
  dup tap-save-header
  cargador cc-pos rot tap-save-data ;

;; uses "cblock-name" as name
@: save-code-block  ( addr count zx-start fd )
  >r >r
  dup 1 65536 within not?error" invalid code block (len)"
  ;; tape header block
  cblock-name 10 3 tap-mk-header
  dup tap-header-len!
  r> tap-code-start!
  r@ tap-save-header
  ;; tape data block
  r> tap-save-data ;

;; destroys "cblock-name"
|: tap-save-zx-code  ( zx-addr-start zx-addr-end fd )
  >r
\ endcr ." BLOCK: start=$" over .hex8 ."  end=$" dup .hex8 cr
  2dup u>= ?error" invalid code block (len)"
  over hi-word over hi-word or ?error" invalid code block (addrs)"
  over - ( zx-addr-start len | fd )
  ;; create code block name
  cblock-name 10 blank
  [char] # cblock-name c!
  base @ >r hex
  over <# # # # # #> cblock-name 1 + swap cmove
  [char] : cblock-name 5 + c!
  dup <# # # # # #> cblock-name 6 + swap cmove
  r> base !
  endcr ." TAP: saving CODE block \'" cblock-name 10 string:-trailing type ." \'\n"
  ( zx-addr-start len | fd )
  over zxa:mem:ram^ swap rot r> save-code-block ;

|: tap-save-zx-code-blocks  ( fd )
  >r 0 << ( zx-addr | fd )
    zxa:next-block-from dup hi-word not?^|
      dup zxa:block-end-from ( zx-bstart zx-bend | fd )
      2dup r@ tap-save-zx-code
      nip |?
  else| rdrop drop >> ;

|: tap-save-one-zx-code-block  ( fd )
  >r $10000 -1 2>r 0  ( zx-addr | fd min max )
  <<
    zxa:next-block-from dup hi-word not?^|
      dup zxa:block-end-from
      ( zx-bstart zx-bend | fd min max )
      2dup 2dup 2r>
      >r min min
      nrot r> max max
      2>r
      nip |?
  else| drop >>
  ;; now save
  2r> r>  ( min max fd )
  tap-save-zx-code ;

@: save-fd  ( fd )
  endcr ." TAP: saving BASIC loader \'" cargador-name 10 string:-trailing type ." \'\n"
  dup tap-save-cargador
  opt-one-code-file?
  ?< tap-save-one-zx-code-block
  || tap-save-zx-code-blocks
  >? ;

@: create  ( addr count )
  file:create
  dup tap-save-initial-header
  dup save-fd
  file:close ;


end-module (published)
