40 quan curr-spr-buf
0 quan curr-spr-buf-ofs

(*
16x16 sprite loader.
sprite format:
  db mask    ;; mask for the first byte ($FF -- put full first byte)
  32 bytes of data, upside down

sprite definition:
  db attr
  dw gfx-addr
  db reserved
*)

|: adv-spr-ofs
  curr-spr-buf-ofs 34 +
  b/buf over - 34 < ?< drop 0  1 +to curr-spr-buf >?
  to curr-spr-buf-ofs ;

|: write-one-sprite  ( gfx-addr )
  curr-spr-buf ( buffer) block curr-spr-buf-ofs +
  ( gfx-addr dest-addr )
  over c@ over c! ;; mask
  1+ 0 over c!    ;; reserved
  under+1 1+ 32 cmove
  update
  adv-spr-ofs ;

|: write-sprite-set  ( set-addr count )
  under+1 for dup @ write-one-sprite 4 + loop drop ;

: wrs
  SPR-REX-WALK 8 write-sprite-set
  SPR-REX-FALL 8 write-sprite-set
  SPR-SOLDIER-WALK 8 write-sprite-set
  SPR-SOLDIER-SHOOT 8 write-sprite-set
  SPR-SOLDIER-DYING 8 write-sprite-set
  SPR-FUN-ARROW 8 write-sprite-set
  SPR-SKULL 4 write-sprite-set
  flush
  endcr ." EBUF=" curr-spr-buf . ." EOFS=" curr-spr-buf-ofs . cr
;
