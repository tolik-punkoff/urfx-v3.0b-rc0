;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; save current image as executable binary
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; pre- and post-save hooks
;; WARNING! *NEVER* throw any errors from the hooks!

;; use ":!"
chained (PRE-SAVE-IMAGE) (private)
;; use ":!pre"
chained (POST-SAVE-IMAGE) (private)

true quan (SAVE-IMAGE-HEADERS?) (private)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; save current image to ELF executable file
;; we're using the fact that our ELF header is loaded into memory,
;; and is writeable

|: (?SAVE-IMAGE-WR-OK)  ( wr wrmust )  <> ?error" error writing binary" ;

|: (SAVE-IMAGE)  ( fd )
  >r  ;; move fd to return stack
  ;; fix code segment size
  ;; write code from code start to real HERE
  here (elf-base-addr) - (save-image-headers?) ?< 4095 + 4095 ~and >? (elf-code-size) !
  ;; fix headers segment offset and size
  (save-image-headers?) ?< (elf-code-size) @ || 4096 >? (elf-hdr-foffset-size) !
  (save-image-headers?) ?< hdr-here (elf-hdr-base-addr) - || 0 >? (elf-hdr-code-size) !
  ;; everything in our header is ok now, including entry point (it isn't changed)
  [ tcom:dynamic-binary ] [IF]
    0 >r ( bytes written so far )
    ;; write everything up until import table
    (elf-base-addr) (elf-imptable-addr) (elf-base-addr) - dup r0:+! r1:@ linux:write
    (elf-imptable-addr) (elf-base-addr) - (?save-image-wr-ok)
    ;; write zero bytes for imports: this is where import addresses will be put by ld.so
    ;; use HERE as temp buffer
    here (elf-imptable-size) erase
    here (elf-imptable-size) dup r0:+! r1:@ linux:write (elf-imptable-size) (?save-image-wr-ok)
    ;; write code from imports end to real here
    (elf-imptable-addr) (elf-imptable-size) +
    (elf-code-size) @ r> - r@ over >r linux:write
  [ELSE]
    ;; write the whole code chunk
    (elf-base-addr) (elf-code-size) @ r@ over >r linux:write
  [ENDIF]
  r>  ;; restore write result and number of bytes written
  (?save-image-wr-ok)
  ;; write headers segment
  (save-image-headers?) ?<
    (elf-hdr-base-addr) (elf-hdr-code-size) @ r> over >r linux:write r> (?save-image-wr-ok)
  || rdrop >?
  ( you may not believe me, but we're done! ) ;


: SAVE-IMAGE  ( addr count )
  ;; create output file
  linux:o-wronly linux:o-creat or linux:o-trunc or  ;; flags
  linux:s-irwxu linux:s-irgrp or linux:s-ixgrp or linux:s-iroth or linux:s-ixoth or  ;; mode
  linux:open not?error" error creating image file"
  >r (pre-save-image) ?error" presave chain failed"
  r@ (save-image) r> linux:close ?error" error closing image file"
  (post-save-image) ?error" postsave chain failed" ;
