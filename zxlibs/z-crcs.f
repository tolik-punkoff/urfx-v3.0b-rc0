;; CRC-8 Maxim/Dallas checksum (unrolled)
;;
;; From Maxim/Dallas AP Note 27
;;
;; "Understanding and Using Cyclic Redundancy Checks with
;; Dallas Semiconductor iButton Products"
;;
;; Input:
;;  HL = DATA Pointer
;;  BC = DATA Length
;;
;; Output:
;;  A = CRC-8
;;  HL, D, BC and Flags modified

    ; CRC-8 ShiftXor
    MACRO CRC8XOR x
      rr d
      jr nc,$+4
        xor x
    MEND

crc8:
    xor a
    inc b
    dec bc
    inc c
_crc8
      xor (hl)
      ld d,a
      xor a

      CRC8XOR &5E
      CRC8XOR &BC
      CRC8XOR &61
      CRC8XOR &C2
      CRC8XOR &9D
      CRC8XOR &23
      CRC8XOR &46
      CRC8XOR &8C

      inc hl
      dec c
      jr nz,_crc8
      djnz _crc8

    ret

CRC-16 (CCITT)

;; CRC-16-CCITT checksum
;;
;; Poly: &1021
;; Seed: &FFFF
;;
;; Input:
;;  IX = Data address
;;  DE = Data length
;;
;; Output:
;;  HL = CRC-16
;;  IX,DE,BC,AF modified

crc16:
      ld hl,&FFFF
      ld c,8
_crc16_read
        ld a,h
        xor (ix+0)
        ld h,a
        inc ix
        ld b,c
_crc16_shift
        add hl,hl
        jr nc,_crc16_noxor
          ld a,h
          xor &10
          ld h,a
          ld a,l
          xor &21
          ld l,a
_crc16_noxor
        djnz _crc16_shift
        dec de
        ld a,d
        or e
        jr nz,_crc16_read
      ret

CRC-32

Also provided for the sake of completeness, CRC-32 is slow, even in full unrolled glory.

;; CRC-32 checksum (unrolled)
;;
;; Poly: &04C11DB7
;; Seed: &FFFFFFFF
;;
;; Input:
;;  IX = Data address
;;  BC = Data length
;;
;; Output:
;;  HLDE = CRC-32
;;  IX,BC,AF modified

    MACRO CRC32XOR x1,x2,x3,x4
      rr b
      jr nc,@nextBit
        ld a,e
        xor x1
        ld e,a
        ld a,d
        xor x2
        ld d,a
        ld a,l
        xor x3
        ld l,a
        ld a,h
        xor x4
        ld h,a
@nextBit
    MEND

crc32:
    ld hl,&FFFF
    ld d,h
    ld e,l
_crc32_loop
       ld a,(ix+0)
       inc ix
       push bc

       xor e
       ld b,a
       rr b
       jr c,_crc32_bit0
         ld e,d
         ld d,l
         ld l,h
         ld h,0
         jr _crc32_bit1

_crc32_bit0
         ld a,d
         xor &96
         ld e,a
         ld a,l
         xor &30
         ld d,a
         ld a,h
         xor &07
         ld l,a
         ld h,&77

_crc32_bit1
       CRC32XOR &2C,&61,&0E,&EE
       CRC32XOR &19,&C4,&6D,&07
       CRC32XOR &32,&88,&DB,&0E
       CRC32XOR &64,&10,&B7,&1D
       CRC32XOR &C8,&20,&6E,&3B
       CRC32XOR &90,&41,&DC,&76
       CRC32XOR &20,&83,&B8,&ED

       pop bc
       dec bc
       ld a,b
       or c
       jp nz,_crc32_loop

     dec b
     ; Final XOR value
     ; HLDE ^= &FFFFFFFF
     ld a,h
     xor b
     ld h,a
     ld a,l
     xor b
     ld l,a
     ld a,d
     xor b
     ld d,a
     ld a,e
     xor b
     ld e,a

     ret

;; Unit tests
;;
;; "Semilanceata" => &B78816DE
;; "Longueteau"   => &935384D5
;; "Severin"      => &E442806C
;; "Damoiseau"    => &95C8BAFA

Fletcher-16

    Author: John G. Fletcher
    Published: January 1982, ?An Arithmetic Checksum for Serial Transmissions?. IEEE Transactions on Communications.
    Reference : Wikipedia ? Fletcher?s checksum

;; Fletcher-16 checksum
;;
;; Input:
;;  HL = Data address
;;  BC = Data length
;;
;; Output:
;;  DE = Fletcher-16
;;  HL,BC,AF are modified

fletcher16:
     ; Initialize both sums to zero
     ld de,0
     ; Adjust 16-bit length for 2x8-bit loops
     inc b
     dec bc
     inc c
_fletcher16_loop
       ld a,(hl)
       inc hl
       ; sum1 += data
       add a,e
       ld e,a
       ; sum2 += sum1
       add a,d
       ld d,a
       dec c
       jr nz,_fletcher16_loop
       djnz  _fletcher16_loop
     ret

;; Unit tests
;;
;; "Semilanceata" => &B8C7
;; "Longueteau"   => &0D19
;; "Severin"      => &1BDC
;; "Damoiseau"    => &4098
