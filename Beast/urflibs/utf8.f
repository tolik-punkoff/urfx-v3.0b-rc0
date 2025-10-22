;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Feral x86 Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; GPLv3 ONLY
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; utf8 conversions
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


module UTF8
<private-words>

: check-sys-locale-utf?  ( -- flag )
  " LC_ALL" string:getenv not?< " LANG" string:getenv not?exit< true >? >?
  ( addr count )
  << dup 3 < ?v|| over " UTF" string:mem=ci ?exit< 2drop true >? 1 under+ 1- ^|| >>
  2drop false ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; UTF-8 DFA decoder tables
;; see http://bjoern.hoehrmann.de/utf-8/decoder/dfa/
;; $16C bytes
create utf8dfa
;; maps bytes to character classes
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, ;; 00-0f
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, ;; 10-1f
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, ;; 20-2f
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, ;; 30-3f
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, ;; 40-4f
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, ;; 50-5f
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, ;; 60-6f
$00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, $00 c, ;; 70-7f
$01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, $01 c, ;; 80-8f
$09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, $09 c, ;; 90-9f
$07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, ;; a0-af
$07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, $07 c, ;; b0-bf
$08 c, $08 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, ;; c0-cf
$02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, $02 c, ;; d0-df
$0a c, $03 c, $03 c, $03 c, $03 c, $03 c, $03 c, $03 c, $03 c, $03 c, $03 c, $03 c, $03 c, $04 c, $03 c, $03 c, ;; e0-ef
$0b c, $06 c, $06 c, $06 c, $05 c, $08 c, $08 c, $08 c, $08 c, $08 c, $08 c, $08 c, $08 c, $08 c, $08 c, $08 c, ;; f0-ff
;; maps a combination of a state of the automaton and a character class to a state
$00 c, $0c c, $18 c, $24 c, $3c c, $60 c, $54 c, $0c c, $0c c, $0c c, $30 c, $48 c, $0c c, $0c c, $0c c, $0c c, ;; 100-10f
$0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $00 c, $0c c, $0c c, $0c c, $0c c, $0c c, $00 c, ;; 110-11f
$0c c, $00 c, $0c c, $0c c, $0c c, $18 c, $0c c, $0c c, $0c c, $0c c, $0c c, $18 c, $0c c, $18 c, $0c c, $0c c, ;; 120-12f
$0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $18 c, $0c c, $0c c, $0c c, $0c c, $0c c, $18 c, $0c c, $0c c, ;; 130-13f
$0c c, $0c c, $0c c, $0c c, $0c c, $18 c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $24 c, ;; 140-14f
$0c c, $24 c, $0c c, $0c c, $0c c, $24 c, $0c c, $0c c, $0c c, $0c c, $0c c, $24 c, $0c c, $24 c, $0c c, $0c c, ;; 150-15f
$0c c, $24 c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c, $0c c,
create;

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; length table; 256 bytes
(*
create utf8-lentbl
1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
;; high part
$FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c,
$FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c,
$FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c,
$FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c,
;; $Cx
$FF c, $FF c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, ;; replace first two with 2 for overlong support
2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c, 2 c,
3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c, 3 c,
;;overlong support: 4 c, 4 c, 4 c, 4 c, 4 c, 4 c, 4 c, 4 c, 5 c, 5 c, 5 c, 5 c, 6 c, 6 c, $FF c, $FF c,
4 c, 4 c, 4 c, 4 c, 4 c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c, $FF c,
create;
*)


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; koi8 -> unicode translation table
create koi2uni-tbl
$0000 w, $0001 w, $0002 w, $0003 w, $0004 w, $0005 w, $0006 w, $0007 w, $0008 w, $0009 w, $000a w, $000b w, $000c w, $000d w, $000e w, $000f w,
$0010 w, $0011 w, $0012 w, $0013 w, $0014 w, $0015 w, $0016 w, $0017 w, $0018 w, $0019 w, $001a w, $001b w, $001c w, $001d w, $001e w, $001f w,
$0020 w, $0021 w, $0022 w, $0023 w, $0024 w, $0025 w, $0026 w, $0027 w, $0028 w, $0029 w, $002a w, $002b w, $002c w, $002d w, $002e w, $002f w,
$0030 w, $0031 w, $0032 w, $0033 w, $0034 w, $0035 w, $0036 w, $0037 w, $0038 w, $0039 w, $003a w, $003b w, $003c w, $003d w, $003e w, $003f w,
$0040 w, $0041 w, $0042 w, $0043 w, $0044 w, $0045 w, $0046 w, $0047 w, $0048 w, $0049 w, $004a w, $004b w, $004c w, $004d w, $004e w, $004f w,
$0050 w, $0051 w, $0052 w, $0053 w, $0054 w, $0055 w, $0056 w, $0057 w, $0058 w, $0059 w, $005a w, $005b w, $005c w, $005d w, $005e w, $005f w,
$0060 w, $0061 w, $0062 w, $0063 w, $0064 w, $0065 w, $0066 w, $0067 w, $0068 w, $0069 w, $006a w, $006b w, $006c w, $006d w, $006e w, $006f w,
$0070 w, $0071 w, $0072 w, $0073 w, $0074 w, $0075 w, $0076 w, $0077 w, $0078 w, $0079 w, $007a w, $007b w, $007c w, $007d w, $007e w, $007f w,
$2500 w, $2502 w, $250c w, $2510 w, $2514 w, $2518 w, $251c w, $2524 w, $252c w, $2534 w, $253c w, $2580 w, $2584 w, $2588 w, $258c w, $2590 w,
$2591 w, $2592 w, $2593 w, $2320 w, $25a0 w, $2219 w, $221a w, $2248 w, $2264 w, $2265 w, $00a0 w, $2321 w, $00b0 w, $00b2 w, $00b7 w, $00f7 w,
$2550 w, $2551 w, $2552 w, $0451 w, $0454 w, $2554 w, $0456 w, $0457 w, $2557 w, $2558 w, $2559 w, $255a w, $255b w, $0491 w, $255d w, $255e w,
$255f w, $2560 w, $2561 w, $0401 w, $0404 w, $2563 w, $0406 w, $0407 w, $2566 w, $2567 w, $2568 w, $2569 w, $256a w, $0490 w, $256c w, $00a9 w,
$044e w, $0430 w, $0431 w, $0446 w, $0434 w, $0435 w, $0444 w, $0433 w, $0445 w, $0438 w, $0439 w, $043a w, $043b w, $043c w, $043d w, $043e w,
$043f w, $044f w, $0440 w, $0441 w, $0442 w, $0443 w, $0436 w, $0432 w, $044c w, $044b w, $0437 w, $0448 w, $044d w, $0449 w, $0447 w, $044a w,
$042e w, $0410 w, $0411 w, $0426 w, $0414 w, $0415 w, $0424 w, $0413 w, $0425 w, $0418 w, $0419 w, $041a w, $041b w, $041c w, $041d w, $041e w,
$041f w, $042f w, $0420 w, $0421 w, $0422 w, $0423 w, $0416 w, $0412 w, $042c w, $042b w, $0417 w, $0428 w, $042d w, $0429 w, $0427 w, $042a w,
create;

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; cp1251 -> unicode translation table
create win2uni-tbl
$0000 w, $0001 w, $0002 w, $0003 w, $0004 w, $0005 w, $0006 w, $0007 w, $0008 w, $0009 w, $000a w, $000b w, $000c w, $000d w, $000e w, $000f w,
$0010 w, $0011 w, $0012 w, $0013 w, $0014 w, $0015 w, $0016 w, $0017 w, $0018 w, $0019 w, $001a w, $001b w, $001c w, $001d w, $001e w, $001f w,
$0020 w, $0021 w, $0022 w, $0023 w, $0024 w, $0025 w, $0026 w, $0027 w, $0028 w, $0029 w, $002a w, $002b w, $002c w, $002d w, $002e w, $002f w,
$0030 w, $0031 w, $0032 w, $0033 w, $0034 w, $0035 w, $0036 w, $0037 w, $0038 w, $0039 w, $003a w, $003b w, $003c w, $003d w, $003e w, $003f w,
$0040 w, $0041 w, $0042 w, $0043 w, $0044 w, $0045 w, $0046 w, $0047 w, $0048 w, $0049 w, $004a w, $004b w, $004c w, $004d w, $004e w, $004f w,
$0050 w, $0051 w, $0052 w, $0053 w, $0054 w, $0055 w, $0056 w, $0057 w, $0058 w, $0059 w, $005a w, $005b w, $005c w, $005d w, $005e w, $005f w,
$0060 w, $0061 w, $0062 w, $0063 w, $0064 w, $0065 w, $0066 w, $0067 w, $0068 w, $0069 w, $006a w, $006b w, $006c w, $006d w, $006e w, $006f w,
$0070 w, $0071 w, $0072 w, $0073 w, $0074 w, $0075 w, $0076 w, $0077 w, $0078 w, $0079 w, $007a w, $007b w, $007c w, $007d w, $007e w, $007f w,
$0402 w, $0403 w, $201a w, $0453 w, $201e w, $2026 w, $2020 w, $2021 w, $20ac w, $2030 w, $0409 w, $2039 w, $040a w, $040c w, $040b w, $040f w,
$0452 w, $2018 w, $2019 w, $201c w, $201d w, $2022 w, $2013 w, $2014 w, $fffd w, $2122 w, $0459 w, $203a w, $045a w, $045c w, $045b w, $045f w,
$00a0 w, $040e w, $045e w, $0408 w, $00a4 w, $0490 w, $00a6 w, $00a7 w, $0401 w, $00a9 w, $0404 w, $00ab w, $00ac w, $00ad w, $00ae w, $0407 w,
$00b0 w, $00b1 w, $0406 w, $0456 w, $0491 w, $00b5 w, $00b6 w, $00b7 w, $0451 w, $2116 w, $0454 w, $00bb w, $0458 w, $0405 w, $0455 w, $0457 w,
$0410 w, $0411 w, $0412 w, $0413 w, $0414 w, $0415 w, $0416 w, $0417 w, $0418 w, $0419 w, $041a w, $041b w, $041c w, $041d w, $041e w, $041f w,
$0420 w, $0421 w, $0422 w, $0423 w, $0424 w, $0425 w, $0426 w, $0427 w, $0428 w, $0429 w, $042a w, $042b w, $042c w, $042d w, $042e w, $042f w,
$0430 w, $0431 w, $0432 w, $0433 w, $0434 w, $0435 w, $0436 w, $0437 w, $0438 w, $0439 w, $043a w, $043b w, $043c w, $043d w, $043e w, $043f w,
$0440 w, $0441 w, $0442 w, $0443 w, $0444 w, $0445 w, $0446 w, $0447 w, $0448 w, $0449 w, $044a w, $044b w, $044c w, $044d w, $044e w, $044f w,
create;

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; cp866 -> unicode translation table
create dos2uni-tbl
$0000 w, $0001 w, $0002 w, $0003 w, $0004 w, $0005 w, $0006 w, $0007 w, $0008 w, $0009 w, $000a w, $000b w, $000c w, $000d w, $000e w, $000f w,
$0010 w, $0011 w, $0012 w, $0013 w, $0014 w, $0015 w, $0016 w, $0017 w, $0018 w, $0019 w, $001a w, $001b w, $001c w, $001d w, $001e w, $001f w,
$0020 w, $0021 w, $0022 w, $0023 w, $0024 w, $0025 w, $0026 w, $0027 w, $0028 w, $0029 w, $002a w, $002b w, $002c w, $002d w, $002e w, $002f w,
$0030 w, $0031 w, $0032 w, $0033 w, $0034 w, $0035 w, $0036 w, $0037 w, $0038 w, $0039 w, $003a w, $003b w, $003c w, $003d w, $003e w, $003f w,
$0040 w, $0041 w, $0042 w, $0043 w, $0044 w, $0045 w, $0046 w, $0047 w, $0048 w, $0049 w, $004a w, $004b w, $004c w, $004d w, $004e w, $004f w,
$0050 w, $0051 w, $0052 w, $0053 w, $0054 w, $0055 w, $0056 w, $0057 w, $0058 w, $0059 w, $005a w, $005b w, $005c w, $005d w, $005e w, $005f w,
$0060 w, $0061 w, $0062 w, $0063 w, $0064 w, $0065 w, $0066 w, $0067 w, $0068 w, $0069 w, $006a w, $006b w, $006c w, $006d w, $006e w, $006f w,
$0070 w, $0071 w, $0072 w, $0073 w, $0074 w, $0075 w, $0076 w, $0077 w, $0078 w, $0079 w, $007a w, $007b w, $007c w, $007d w, $007e w, $007f w,
$0410 w, $0411 w, $0412 w, $0413 w, $0414 w, $0415 w, $0416 w, $0417 w, $0418 w, $0419 w, $041a w, $041b w, $041c w, $041d w, $041e w, $041f w,
$0420 w, $0421 w, $0422 w, $0423 w, $0424 w, $0425 w, $0426 w, $0427 w, $0428 w, $0429 w, $042a w, $042b w, $042c w, $042d w, $042e w, $042f w,
$0430 w, $0431 w, $0432 w, $0433 w, $0434 w, $0435 w, $0436 w, $0437 w, $0438 w, $0439 w, $043a w, $043b w, $043c w, $043d w, $043e w, $043f w,
$2591 w, $2592 w, $2593 w, $2502 w, $2524 w, $2561 w, $2562 w, $2556 w, $2555 w, $2563 w, $2551 w, $2557 w, $255d w, $255c w, $255b w, $2510 w,
$2514 w, $2534 w, $252c w, $251c w, $2500 w, $253c w, $255e w, $255f w, $255a w, $2554 w, $2569 w, $2566 w, $2560 w, $2550 w, $256c w, $2567 w,
$2568 w, $2564 w, $2565 w, $2559 w, $2558 w, $2552 w, $2553 w, $256b w, $256a w, $2518 w, $250c w, $2588 w, $2584 w, $258c w, $2590 w, $2580 w,
$0440 w, $0441 w, $0442 w, $0443 w, $0444 w, $0445 w, $0446 w, $0447 w, $0448 w, $0449 w, $044a w, $044b w, $044c w, $044d w, $044e w, $044f w,
$0401 w, $0451 w, $0404 w, $0454 w, $0407 w, $0457 w, $040e w, $045e w, $00b0 w, $2219 w, $00b7 w, $221a w, $2116 w, $00a4 w, $25a0 w, $00a0 w,
create;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; words used to build uni->1byte translation tables

create uni2koi_ctbl0  ;; 64
$e1 c, $e2 c, $f7 c, $e7 c, $e4 c, $e5 c, $f6 c, $fa c, $e9 c, $ea c, $eb c, $ec c, $ed c, $ee c, $ef c, $f0 c,
$f2 c, $f3 c, $f4 c, $f5 c, $e6 c, $e8 c, $e3 c, $fe c, $fb c, $fd c, $ff c, $f9 c, $f8 c, $fc c, $e0 c, $f1 c,
$c1 c, $c2 c, $d7 c, $c7 c, $c4 c, $c5 c, $d6 c, $da c, $c9 c, $ca c, $cb c, $cc c, $cd c, $ce c, $cf c, $d0 c,
$d2 c, $d3 c, $d4 c, $d5 c, $c6 c, $c8 c, $c3 c, $de c, $db c, $dd c, $df c, $d9 c, $d8 c, $dc c, $c0 c, $d1 c,
create;
create uni2koi_ctbl1 $a8 c, $a9 c, $aa c, $ab c, $ac c, create;
create uni2koi_ctbl2 $ae c, $af c, $b0 c, $b1 c, $b2 c, create;
create uni2koi_ctbl3 $b8 c, $b9 c, $ba c, $bb c, $bc c, create;
create uni2koi_ctbl4 $8f c, $90 c, $91 c, $92 c, create;

create uni2win_ctbl0 $ab c, $ac c, $ad c, $ae c, create;
create uni2win_ctbl1 $a8 c, $80 c, $81 c, $aa c, $bd c, $b2 c, $af c, $a3 c, $8a c, $8c c, $8e c, $8d c, create;
create uni2win_ctbl2
$a1 c, $8f c, $c0 c, $c1 c, $c2 c, $c3 c, $c4 c, $c5 c, $c6 c, $c7 c, $c8 c, $c9 c, $ca c, $cb c, $cc c, $cd c,
$ce c, $cf c, $d0 c, $d1 c, $d2 c, $d3 c, $d4 c, $d5 c, $d6 c, $d7 c, $d8 c, $d9 c, $da c, $db c, $dc c, $dd c,
$de c, $df c, $e0 c, $e1 c, $e2 c, $e3 c, $e4 c, $e5 c, $e6 c, $e7 c, $e8 c, $e9 c, $ea c, $eb c, $ec c, $ed c,
$ee c, $ef c, $f0 c, $f1 c, $f2 c, $f3 c, $f4 c, $f5 c, $f6 c, $f7 c, $f8 c, $f9 c, $fa c, $fb c, $fc c, $fd c,
$fe c, $ff c,
create;
create uni2win_ctbl3 $b8 c, $90 c, $83 c, $ba c, $be c, $b3 c, $bf c, $bc c, $9a c, $9c c, $9e c, $9d c, create;

create uni2dos_ctbl0
$80 c, $81 c, $82 c, $83 c, $84 c, $85 c, $86 c, $87 c, $88 c, $89 c, $8a c, $8b c, $8c c, $8d c, $8e c, $8f c,
$90 c, $91 c, $92 c, $93 c, $94 c, $95 c, $96 c, $97 c, $98 c, $99 c, $9a c, $9b c, $9c c, $9d c, $9e c, $9f c,
$a0 c, $a1 c, $a2 c, $a3 c, $a4 c, $a5 c, $a6 c, $a7 c, $a8 c, $a9 c, $aa c, $ab c, $ac c, $ad c, $ae c, $af c,
$e0 c, $e1 c, $e2 c, $e3 c, $e4 c, $e5 c, $e6 c, $e7 c, $e8 c, $e9 c, $ea c, $eb c, $ec c, $ed c, $ee c, $ef c,
create;
create uni2dos_ctbl1
$cd c, $ba c, $d5 c, $d6 c, $c9 c, $b8 c, $b7 c, $bb c, $d4 c, $d3 c, $c8 c, $be c, $bd c, $bc c, $c6 c, $c7 c,
$cc c, $b5 c, $b6 c, $b9 c, $d1 c, $d2 c, $cb c, $cf c, $d0 c, $ca c, $d8 c, $d7 c, $ce c,
create;
create uni2dos_ctbl2 $de c, $b0 c, $b1 c, $b2 c, create;

: uni2koi-slow  ( cp -- char )
  dup $80 u< ?exit
  dup $00a0 = ?exit< drop $9a >?
  dup $00a9 = ?exit< drop $bf >?
  dup $00b0 = ?exit< drop $9c >?
  dup $00b2 = ?exit< drop $9d >?
  dup $00b7 = ?exit< drop $9e >?
  dup $00f7 = ?exit< drop $9f >?
  dup $0401 = ?exit< drop $b3 >?
  dup $0404 = ?exit< drop $b4 >?
  dup $0406 = ?exit< drop $b6 >?
  dup $0407 = ?exit< drop $b7 >?
  dup $0410 $044f bounds ?exit< $0410 - uni2koi_ctbl0 + c@ >?
  dup $0451 = ?exit< drop $a3 >?
  dup $0454 = ?exit< drop $a4 >?
  dup $0456 = ?exit< drop $a6 >?
  dup $0457 = ?exit< drop $a7 >?
  dup $0490 = ?exit< drop $bd >?
  dup $0491 = ?exit< drop $ad >?
  dup $2219 = ?exit< drop $95 >?
  dup $221a = ?exit< drop $96 >?
  dup $2248 = ?exit< drop $97 >?
  dup $2264 = ?exit< drop $98 >?
  dup $2265 = ?exit< drop $99 >?
  dup $2320 = ?exit< drop $93 >?
  dup $2321 = ?exit< drop $9b >?
  dup $2500 = ?exit< drop $80 >?
  dup $2502 = ?exit< drop $81 >?
  dup $250c = ?exit< drop $82 >?
  dup $2510 = ?exit< drop $83 >?
  dup $2514 = ?exit< drop $84 >?
  dup $2518 = ?exit< drop $85 >?
  dup $251c = ?exit< drop $86 >?
  dup $2524 = ?exit< drop $87 >?
  dup $252c = ?exit< drop $88 >?
  dup $2534 = ?exit< drop $89 >?
  dup $253c = ?exit< drop $8a >?
  dup $2550 = ?exit< drop $a0 >?
  dup $2551 = ?exit< drop $a1 >?
  dup $2552 = ?exit< drop $a2 >?
  dup $2554 = ?exit< drop $a5 >?
  dup $2557 $255b bounds ?exit< $2557 - uni2koi_ctbl1 + c@ >?
  dup $255d $2561 bounds ?< $255d - uni2koi_ctbl2 + c@ >?
  dup $2563 = ?exit< drop $b5 >?
  dup $2566 $256a bounds ?exit< $2566 - uni2koi_ctbl3 + c@ >?
  dup $256c = ?exit< drop $be >?
  dup $2580 = ?exit< drop $8b >?
  dup $2584 = ?exit< drop $8c >?
  dup $2588 = ?exit< drop $8d >?
  dup $258c = ?exit< drop $8e >?
  dup $2590 $2593 bounds ?exit< $2590 - uni2koi_ctbl4 + c@ >?
  dup $25a0 = ?exit< drop $94 >?
  drop [char] ? ;

: uni2win-slow  ( cp -- char )
  dup $80 u< ?exit
  dup $00a0 = ?exit< drop $a0 >?
  dup $00a4 = ?exit< drop $a4 >?
  dup $00a6 = ?exit< drop $a6 >?
  dup $00a7 = ?exit< drop $a7 >?
  dup $00a9 = ?exit< drop $a9 >?
  dup $00ab $00ae bounds ?exit< $00ab - uni2win_ctbl0 + c@ >?
  dup $00b0 = ?exit< drop $b0 >?
  dup $00b1 = ?exit< drop $b1 >?
  dup $00b5 = ?exit< drop $b5 >?
  dup $00b6 = ?exit< drop $b6 >?
  dup $00b7 = ?exit< drop $b7 >?
  dup $00bb = ?exit< drop $bb >?
  dup $0401 $040c bounds ?< $0401 - uni2win_ctbl1 + c@ >?
  dup $040e $044f bounds ?< $040e - uni2win_ctbl2 + c@ >?
  dup $0451 $045c bounds ?< $0451 - uni2win_ctbl3 + c@ >?
  dup $045e = ?exit< drop $a2 >?
  dup $045f = ?exit< drop $9f >?
  dup $0490 = ?exit< drop $a5 >?
  dup $0491 = ?exit< drop $b4 >?
  dup $2013 = ?exit< drop $96 >?
  dup $2014 = ?exit< drop $97 >?
  dup $2018 = ?exit< drop $91 >?
  dup $2019 = ?exit< drop $92 >?
  dup $201a = ?exit< drop $82 >?
  dup $201c = ?exit< drop $93 >?
  dup $201d = ?exit< drop $94 >?
  dup $201e = ?exit< drop $84 >?
  dup $2020 = ?exit< drop $86 >?
  dup $2021 = ?exit< drop $87 >?
  dup $2022 = ?exit< drop $95 >?
  dup $2026 = ?exit< drop $85 >?
  dup $2030 = ?exit< drop $89 >?
  dup $2039 = ?exit< drop $8b >?
  dup $203a = ?exit< drop $9b >?
  dup $20ac = ?exit< drop $88 >?
  dup $2116 = ?exit< drop $b9 >?
  dup $2122 = ?exit< drop $99 >?
  drop [char] ? ;

: uni2dos-slow  ( cp -- char )
  dup $80 u< ?exit
  dup $00a0 = ?exit< drop $ff >?
  dup $00a4 = ?exit< drop $fd >?
  dup $00b0 = ?exit< drop $f8 >?
  dup $00b7 = ?exit< drop $fa >?
  dup $0401 = ?exit< drop $f0 >?
  dup $0404 = ?exit< drop $f2 >?
  dup $0407 = ?exit< drop $f4 >?
  dup $040e = ?exit< drop $f6 >?
  dup $0410 $044f bounds ?exit< $0410 - uni2dos_ctbl0 + c@ >?
  dup $0451 = ?exit< drop $f1 >?
  dup $0454 = ?exit< drop $f3 >?
  dup $0457 = ?exit< drop $f5 >?
  dup $045e = ?exit< drop $f7 >?
  dup $2116 = ?exit< drop $fc >?
  dup $2219 = ?exit< drop $f9 >?
  dup $221a = ?exit< drop $fb >?
  dup $2500 = ?exit< drop $c4 >?
  dup $2502 = ?exit< drop $b3 >?
  dup $250c = ?exit< drop $da >?
  dup $2510 = ?exit< drop $bf >?
  dup $2514 = ?exit< drop $c0 >?
  dup $2518 = ?exit< drop $d9 >?
  dup $251c = ?exit< drop $c3 >?
  dup $2524 = ?exit< drop $b4 >?
  dup $252c = ?exit< drop $c2 >?
  dup $2534 = ?exit< drop $c1 >?
  dup $253c = ?exit< drop $c5 >?
  dup $2550 $256c bounds ?exit< $2550 - uni2dos_ctbl1 + c@ >?
  dup $2580 = ?exit< drop $df >?
  dup $2584 = ?exit< drop $dc >?
  dup $2588 = ?exit< drop $db >?
  dup $258c = ?exit< drop $dd >?
  dup $2590 $2593 bounds ?exit< $2590 - uni2dos_ctbl2 + c@ >?
  dup $25a0 = ?exit< drop $fe >?
  drop [char] ? ;

0 quan uni2koi-tbl

: create-u2k-table
  65536 dynmem:?alloc uni2koi-tbl:!
  0 << dup 65535 > ?v|| dup uni2koi-slow over uni2koi-tbl + c! 1+ ^|| >> drop ;
create-u2k-table


<published-words>
$FFFD constant replacement-cp -- replacement char for invalid unicode
$FEFF constant idiotic-bom-cp -- BOM codepoint

check-sys-locale-utf? quan utf-locale?
\ ." LOCALE IS UTF: " utf-locale? 0.r cr bye

;; useful in saved binaries
: detect-locale  check-sys-locale-utf? utf-locale?:! ;


;; is the given codepoint valid?
;; inlineable.
: valid-cp?  ( cp -- flag )  dup $D800 u< swap $DFFF $10FFFF bounds or ;

;; is the given codepoint considered printable?
;; i restrict it to some useful subset.
;; unifuck is unifucked, but i hope that i sorted out all idiotic diactritics and control chars.
;; alas, not inlineable.
: printable-cp?  ( cp -- flag )
  dup $024F u<= ?exit< drop true >?  ;; basic latin
  ;; some greek, and cyrillic w/o combiners
  dup $0390 $0482 bounds ?exit< drop true >?
  dup $048A $052F bounds ?exit< drop true >?
  \ dup $16A0 $16FF bounds ?exit< drop true >?  ;; runic (just for fun)
  dup $1E00 $1EFF bounds ?exit< drop true >?  ;; latin extended additional
  dup $2000 $2C7F bounds ?exit< drop true >?  ;; some general punctuation, extensions, etc.
  dup $2E00 $2E42 bounds ?exit< drop true >?  ;; supplemental punctuation
  ;; more latin extended
  $AB30 $AB65 bounds ;

;; can `ch` be a beginning of an utf-8 sequence?
;; ASCII char is a valid beginning.
;; inlineable.
: start-char?  ( ch -- flag )  dup 255 u<= swap $C0 and $80 <> and ;

;; can `ch` be a continuation of an utf-8 sequence?
;; inlineable.
: cont-char?  ( ch -- flag )  dup 255 u<= swap $C0 and $80 = and ;

;; determine utf-8 sequence length (in bytes) by its first char.
;; returns length ([1..4]) or 0 on invalid first char.
;; doesn't allow overlongs.
;; not inlineable.
: len-by-first  ( ch -- len // FALSE )
  dup $7F u<= ?exit< drop 1 >?
  dup %1110_0000 and %1100_0000 = ?exit< dup $C0 = swap $C1 = or ?< 0 || 2 >? >?
  dup %1111_0000 and %1110_0000 = ?exit< drop 3 >?
      %1111_1000 and %1111_0000 = ?< 4 || 0 >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;
;; DFA-based utf-8 decoder with only 32 bits of state; rejects overlongs
;;
;; use like this:
;;
;;   0  ;; 0 is important! (also, assigning zero can be used to reset the decoder)
;;   << read-char utf8:consume dup utf8:valid-cp? not?^|| >>
;;   process unicode codepoint from `cp`; can keep it, or restart from 0

;; never reaches `invalid` state, returns `replacement` for invalid chars
;; returns invalid codepoint while it is "in progress" (i.e. result > $10FFFF)
: consume  ( state/cp char -- state/cp )
  dup 255 u> ?exit< 2drop replacement-cp >? >r
  dup 24 rshift ( state/cp state | char )
  ;; if invalid utf-8 sequence was hit, restart (just in case)
  dup 12 (* State.Reject *) = ?< drop 0 (* State.Accept *) >?
  r@ utf8dfa + c@ ( state/cp state type | char )
  over ?< (* state <> State.Accept *) rot $ff000000 ~and 6 lshift  r> $3F and  or
       || rot drop $FF over rshift  r> and >?
  ( state type new-state/cp )
  nrot  ( new-state/cp state type )
  + 256 + utf8dfa + c@  ( new-state/cp new-state )
  dup 12 (* State.Reject *) = ?exit< 2drop replacement-cp >?  ;; invalid utf-8 sequence
  ( new-state/cp new-state )
  dup ?exit< 24 lshift or >? drop
  ;;k8: i don't remember if this is required, but it's better be safe than sorry
  dup valid-cp? ?exit drop replacement-cp ;


|: (encode-2)  ( cp dest -- 2 )
  over 6 rshift $C0 or av-c!++
  swap $3F and $80 or swap c!  2 ;

|: (encode-3)  ( cp dest -- 3 )
  over 12 rshift $E0 or av-c!++
  over 6 rshift $3F and $80 or av-c!++
  swap $3F and $80 or swap c!  3 ;

|: (encode-4)  ( cp dest -- 4 )
  over 18 rshift $F0 or av-c!++
  over 12 rshift $3F and $E0 or av-c!++
  over 6 rshift $3F and $80 or av-c!++
  swap $3F and $80 or swap c!  4 ;

;; encode unicode codepoint to utf-8 sequence.
;; return number of generated bytes ([1..4]).
;; will never set more than 4 bytes of `dest`.
: encode  ( cp dest -- len )
  over $7F u<= ?exit< c! 1 >?
  over $7FF u<= ?exit< (encode-2) >?
  over $FFFF u<= ?exit< over valid-cp? not?< nip replacement-cp swap >? (encode-3) >?
  over $10FFFF u<= ?exit< (encode-4) >?
  nip replacement-cp swap (encode-3) ;

\ here !0
\ $10000 here encode . cr
\ here c@ .hex2 bl emit
\ here 1+ c@ .hex2 bl emit
\ here 2+ c@ .hex2 bl emit
\ here 3 + c@ .hex2 cr
\ bye


;; not inlineable
: valid-first-char?  ( addr count -- flag )
  1- dup -?exit< 2drop false >?
  over c@ len-by-first  ( addr count len )
  dup not?exit< 3drop false >?
  1- dup not?exit< 3drop true >?
  ;; 2 or more, check them
  2dup < ?exit< 3drop false >?  ;; not enough bytes
  nip 1 under+ swap  ( len addr )
  << c@++ cont-char? not?exit< 2drop false >?
  1 under- over +?^|| v|| >> 2drop true ;


;; inlineable
: koi>uni  ( ch -- cp )  lo-byte 2* koi2uni-tbl + w@ ;
;; inlineable
: win>uni  ( ch -- cp )  lo-byte 2* win2uni-tbl + w@ ;
;; inlineable
: dos>uni  ( ch -- cp )  lo-byte 2* dos2uni-tbl + w@ ;

;; inlineable
: uni>koi  ( cp -- char )  $FFFF umin uni2koi-tbl + c@ ;
;; not inlineable
: uni>win  ( cp -- char )  uni2win-slow ;
;; not inlineable
: uni>dos  ( cp -- char )  uni2dos-slow ;

seal-module
end-module (published)
