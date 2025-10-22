;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 4x7 font (96 chars)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; 32 ( )
row  ....
row  ....
row  ....
row  ....
row  ....
row  ....
row  ....
;; 33 (!)
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  ....
row  ..#.
row  ....
;; 34 (")
row  .#.#
row  .#.#
row  ....
row  ....
row  ....
row  ....
row  ....
;; 35 (#)
row  ....
row  .#.#
row  .###
row  .#.#
row  .###
row  .#.#
row  ....
;; 36 ($)
row  ..#.
row  .###
row  .##.
row  ..##
row  .###
row  ..#.
row  ....
;; 37 (%)
row  ....
row  .#.#
row  ...#
row  ..#.
row  .#..
row  .#.#
row  ....
;; 38 (&)
row  ..#.
row  .#.#
row  ..#.
row  .#.#
row  .#..
row  ..##
row  ....
;; 39 (')
row  ...#
row  ...#
row  ..#.
row  ....
row  ....
row  ....
row  ....
;; 40 (()
row  ...#
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  ...#
row  ....
;; 41 ())
row  .#..
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  .#..
row  ....
;; 42 (*)
row  ....
row  .#.#
row  ..#.
row  .###
row  ..#.
row  .#.#
row  ....
;; 43 (+)
row  ....
row  ..#.
row  ..#.
row  .###
row  ..#.
row  ..#.
row  ....
;; 44 (,)
row  ....
row  ....
row  ....
row  ....
row  ..#.
row  ..#.
row  .#..
;; 45 (-)
row  ....
row  ....
row  ....
row  .###
row  ....
row  ....
row  ....
;; 46 (.)
row  ....
row  ....
row  ....
row  ....
row  ....
row  ..#.
row  ....
;; 47 (/)
row  ...#
row  ...#
row  ..#.
row  ..#.
row  .#..
row  .#..
row  ....
;; 48 (0)
row  .###
row  .#.#
row  .#.#
row  .#.#
row  .#.#
row  .###
row  ....
;; 49 (1)
row  ..#.
row  .##.
row  ..#.
row  ..#.
row  ..#.
row  .###
row  ....
;; 50 (2)
row  .###
row  ...#
row  .###
row  .#..
row  .#..
row  .###
row  ....
;; 51 (3)
row  .###
row  ...#
row  ..##
row  ...#
row  ...#
row  .###
row  ....
;; 52 (4)
row  .#.#
row  .#.#
row  .#.#
row  .###
row  ...#
row  ...#
row  ....
;; 53 (5)
row  .###
row  .#..
row  .###
row  ...#
row  ...#
row  .###
row  ....
;; 54 (6)
row  .###
row  .#..
row  .###
row  .#.#
row  .#.#
row  .###
row  ....
;; 55 (7)
row  .###
row  ...#
row  ...#
row  ..#.
row  ..#.
row  ..#.
row  ....
;; 56 (8)
row  .###
row  .#.#
row  .###
row  .#.#
row  .#.#
row  .###
row  ....
;; 57 (9)
row  .###
row  .#.#
row  .###
row  ...#
row  ...#
row  .###
row  ....
;; 58 (:)
row  ....
row  ....
row  ..#.
row  ....
row  ....
row  ..#.
row  ....
;; 59 (;)
row  ....
row  ....
row  ..#.
row  ....
row  ..#.
row  ..#.
row  .#..
;; 60 (<)
row  ....
row  ...#
row  ..#.
row  .#..
row  ..#.
row  ...#
row  ....
;; 61 (=)
row  ....
row  ....
row  .###
row  ....
row  .###
row  ....
row  ....
;; 62 (>)
row  ....
row  .#..
row  ..#.
row  ...#
row  ..#.
row  .#..
row  ....
;; 63 (?)
row  ..#.
row  .#.#
row  ...#
row  ..#.
row  ....
row  ..#.
row  ....
;; 64 (@)
row  ..#.
row  .#.#
row  .###
row  .#.#
row  .#..
row  ..##
row  ....
;; 65 (A)
row  ..##
row  .#.#
row  .#.#
row  .###
row  .#.#
row  .#.#
row  ....
;; 66 (B)
row  .##.
row  .#.#
row  .##.
row  .#.#
row  .#.#
row  .##.
row  ....
;; 67 (C)
row  ..##
row  .#..
row  .#..
row  .#..
row  .#..
row  ..##
row  ....
;; 68 (D)
row  .##.
row  .#.#
row  .#.#
row  .#.#
row  .#.#
row  .##.
row  ....
;; 69 (E)
row  .###
row  .#..
row  .##.
row  .#..
row  .#..
row  .###
row  ....
;; 70 (F)
row  .###
row  .#..
row  .##.
row  .#..
row  .#..
row  .#..
row  ....
;; 71 (G)
row  ..##
row  .#..
row  .#..
row  .#.#
row  .#.#
row  ..##
row  ....
;; 72 (H)
row  .#.#
row  .#.#
row  .###
row  .#.#
row  .#.#
row  .#.#
row  ....
;; 73 (I)
row  .###
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  .###
row  ....
;; 74 (J)
row  ..##
row  ...#
row  ...#
row  ...#
row  .#.#
row  .##.
row  ....
;; 75 (K)
row  .#.#
row  .#.#
row  .##.
row  .##.
row  .#.#
row  .#.#
row  ....
;; 76 (L)
row  .#..
row  .#..
row  .#..
row  .#..
row  .#..
row  .###
row  ....
;; 77 (M)
row  .#.#
row  .###
row  .###
row  .#.#
row  .#.#
row  .#.#
row  ....
;; 78 (N)
row  .##.
row  .#.#
row  .#.#
row  .#.#
row  .#.#
row  .#.#
row  ....
;; 79 (O)
row  ..##
row  .#.#
row  .#.#
row  .#.#
row  .#.#
row  .##.
row  ....
;; 80 (P)
row  .##.
row  .#.#
row  .#.#
row  .###
row  .#..
row  .#..
row  ....
;; 81 (Q)
row  .##.
row  .#.#
row  .#.#
row  .#.#
row  .###
row  ..##
row  ....
;; 82 (R)
row  .##.
row  .#.#
row  .#.#
row  .##.
row  .#.#
row  .#.#
row  ....
;; 83 (S)
row  ..##
row  .#..
row  .##.
row  ...#
row  ...#
row  .##.
row  ....
;; 84 (T)
row  .###
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  ....
;; 85 (U)
row  .#.#
row  .#.#
row  .#.#
row  .#.#
row  .#.#
row  .###
row  ....
;; 86 (V)
row  .#.#
row  .#.#
row  .#.#
row  .#.#
row  .#.#
row  ..#.
row  ....
;; 87 (W)
row  .#.#
row  .#.#
row  .#.#
row  .###
row  .###
row  .#.#
row  ....
;; 88 (X)
row  .#.#
row  .#.#
row  ..#.
row  .#.#
row  .#.#
row  .#.#
row  ....
;; 89 (Y)
row  .#.#
row  .#.#
row  .#.#
row  ..#.
row  ..#.
row  ..#.
row  ....
;; 90 (Z)
row  .###
row  ...#
row  ..#.
row  ..#.
row  .#..
row  .###
row  ....
;; 91 ([)
row  .###
row  .#..
row  .#..
row  .#..
row  .#..
row  .#..
row  .###
;; 92 (\)
row  .#..
row  .#..
row  ..#.
row  ..#.
row  ...#
row  ...#
row  ....
;; 93 (])
row  .###
row  ...#
row  ...#
row  ...#
row  ...#
row  ...#
row  .###
;; 94 (^)
row  ..#.
row  .#.#
row  ....
row  ....
row  ....
row  ....
row  ....
;; 95 (_)
row  ....
row  ....
row  ....
row  ....
row  ....
row  ....
row  ####
;; 96 (`)
row  ..#.
row  .#.#
row  .#..
row  .##.
row  .#..
row  .###
row  ....
;; 97 (a)
row  ....
row  ....
row  .##.
row  ..##
row  .#.#
row  .###
row  ....
;; 98 (b)
row  .#..
row  .#..
row  .##.
row  .#.#
row  .#.#
row  .###
row  ....
;; 99 (c)
row  ....
row  ....
row  ..##
row  .#..
row  .#..
row  ..##
row  ....
;; 100 (d)
row  ...#
row  ...#
row  ..##
row  .#.#
row  .#.#
row  .###
row  ....
;; 101 (e)
row  ....
row  ....
row  ..##
row  .#.#
row  .##.
row  ..##
row  ....
;; 102 (f)
row  ...#
row  ..#.
row  .###
row  ..#.
row  ..#.
row  ..#.
row  .#..
;; 103 (g)
row  ....
row  ....
row  ..##
row  .#.#
row  .###
row  ...#
row  .##.
;; 104 (h)
row  .#..
row  .#..
row  .##.
row  .#.#
row  .#.#
row  .#.#
row  ....
;; 105 (i)
row  ..#.
row  ....
row  .##.
row  ..#.
row  ..#.
row  .###
row  ....
;; 106 (j)
row  ...#
row  ....
row  ...#
row  ...#
row  ...#
row  .#.#
row  ..#.
;; 107 (k)
row  .#..
row  .#..
row  .#.#
row  .##.
row  .#.#
row  .#.#
row  ....
;; 108 (l)
row  .##.
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  ...#
row  ....
;; 109 (m)
row  ....
row  ....
row  .#.#
row  .###
row  .#.#
row  .#.#
row  ....
;; 110 (n)
row  ....
row  ....
row  .##.
row  .#.#
row  .#.#
row  .#.#
row  ....
;; 111 (o)
row  ....
row  ....
row  ..##
row  .#.#
row  .#.#
row  .##.
row  ....
;; 112 (p)
row  ....
row  ....
row  .##.
row  .#.#
row  .###
row  .#..
row  .#..
;; 113 (q)
row  ....
row  ....
row  ..##
row  .#.#
row  .###
row  ...#
row  ...#
;; 114 (r)
row  ....
row  ....
row  ..##
row  .#..
row  .#..
row  .#..
row  ....
;; 115 (s)
row  ....
row  ....
row  ..##
row  .##.
row  ..##
row  .##.
row  ....
;; 116 (t)
row  ..#.
row  .###
row  ..#.
row  ..#.
row  ..#.
row  ...#
row  ....
;; 117 (u)
row  ....
row  ....
row  .#.#
row  .#.#
row  .#.#
row  ..##
row  ....
;; 118 (v)
row  ....
row  ....
row  .#.#
row  .#.#
row  .#.#
row  ..#.
row  ....
;; 119 (w)
row  ....
row  ....
row  .#.#
row  .#.#
row  .###
row  .#.#
row  ....
;; 120 (x)
row  ....
row  ....
row  .#.#
row  ..#.
row  ..#.
row  .#.#
row  ....
;; 121 (y)
row  ....
row  ....
row  .#.#
row  .#.#
row  ..##
row  ...#
row  .##.
;; 122 (z)
row  ....
row  ....
row  .###
row  ..#.
row  .#..
row  .###
row  ....
;; 123 ({)
row  ..##
row  ..#.
row  .#..
row  ..#.
row  ..#.
row  ..##
row  ....
;; 124 (|)
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  ..#.
row  ....
;; 125 (})
row  .##.
row  ..#.
row  ...#
row  ..#.
row  ..#.
row  .##.
row  ....
;; 126 (~)
row  ....
row  ..##
row  .#.#
row  ....
row  ....
row  ....
row  ....
;; 127
row  ..#.
row  .#.#
row  ..##
row  ..##
row  .#.#
row  ..#.
row  ....
