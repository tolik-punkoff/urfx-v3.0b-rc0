;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ZX Spectrum UrF/X Forth System
;; Copyright (C) 2024-2025 Ketmar Dark // Invisible Vector
;; Understanding is not required. Only obedience.
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; IR code stack tracer base definitions
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


\EOF

extend-module TCOM
extend-module IR


module STACKER

module WORKERS
end-module WORKERS

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; virtual stack

;; virtual stack item
struct:new vsitem
  ;; this is for value range propagation.
  ;; both values are unsigned words!
  ;; if both are equal, this is known literal.
  field: vumin    -- possible minimum value
  field: vumax    -- possible maximum value
end-struct


@: vsitem-range  ( item^ -- umin umax )
  dup vsitem:vumin swap vsitem::vumax ;

@: vsitem-range!  ( umin umax item^ )
  >r 2dup <= not?error" invalid vsitem range"
  over 65536 u< not?error" invalid vsitem umin"
  dup 65536 u< not?error" invalid vsitem umax"
  r@ vsitem:vumax:! r> vsitem:vumin:! ;

@: vsitem-lit?  ( item^ -- value TRUE // FALSE )
  vsitem-range over = ?< true || drop false >? ;

@: vsitem-byte?  ( item^ -- bool )
  vsitem-range 255 <= swap 0 >= and ;

@: vsitem-bool?  ( item^ -- bool )
  vsitem-range 1 <= swap 0 >= and ;

@: vsitem-lit!  ( value item^ )
  swap lo-word dup rot vsitem-range! ;

@: vsitem-bool!  ( item^ )
  0 1 rot vsitem-range! ;

@: vsitem-byte!  ( item^ )
  0 255 rot vsitem-range! ;

@: vsitem-unknown!  ( item^ )
  0 65535 rot vsitem-range! ;


@: vsitems-swap  ( i0^ i1^ )
  ;; save i1 contents
  dup vsitem:vumin over vsitem:vumax 2>r
  ;; copy i0 to i1
  over vsitem:vumin over vsitem:vumin:!
  over vsitem:vumax over vsitem:vumax:!
  drop
  ;; put i1 contents to i0
  2r> rot tuck  ( umin i0 umax i0 )
  vsitem:vumax:! vsitem:vumin:! ;


;; virtual stack
struct:new vstack
  field: depth    -- number of used items. WARNING! can be negative!
  field: alloted  -- total number of items in the array
  field: items    -- array of `vsitem`
end-struct


@: vstack-new  ( -- addr^ )
  vstack:@size-of dynmem:?zalloc ;

@: vstack-free  ( addr^ )
  dup 0?exit< drop >?
  dup vstack:items dynmem:free
  dup vstack:@size-of erase ;; just in case
  dynmem:free ;

@: vstack-clear  ( addr^ )
  dup 0?exit< drop >?
  vstack:depth:!0 ;


|: (vstack-clone-items)  ( addr^ new-addr^ )
  over vstack:depth dup -0?exit< 3drop >?
  ( addr^ new-addr^ depth )
  vsitem:@size-of * dup >r dynmem:?alloc over vstack:items:!
  ( addr^ new-addr^ | byte-count )
  swap vstack:items  swap vstack:items  r> cmove ;

@: vstack-clone  ( addr^ -- new-addr^ )
  dup not?exit
  vstack-new
  ( addr^ new-addr^ )
  over vstack:depth over vstack:depth:!
  over vstack:depth 0 max over vstack:alloted:!
  (vstack-clone-items) ;


|: (vstack-grow)  ( addr^ )
  dup vstack:alloted 128 +
  ( addr^ newsize )
  2dup swap vstack:alloted:!
  vsitem:@size-of *
  over vstack:items swap dynmem:?realloc
  swap vstack:items:! ;

|: (vstack-ensure)  ( n addr^ )
  over -?error" negative count in (vstack-ensure)!"
  dup vstack:depth rot + swap
  << 2dup vstack:alloted < ?^| dup (vstack-grow) |? else| >>
  2drop ;

;; index is from the top of the stack, like in `PICK`
@: vstack^  ( index addr^ -- item^ )
  dup 0?error" null vstack in \'vstack^\'!"
  over -?error" negative index in \'vstack^\'!"
  ;; ignore overflows
  2dup vstack:depth swap - 1-
  dup -?error" too big index in \'vstack^\'!"
  vstack:items swap vsitem:@size-of * + ;

@: vstack-new-item  ( addr^ -- item^ TRUE // FALSE )
  dup 0?error" null vstack in \'>vstack\'!"
  dup vstack:depth:1+!
  dup vstack:depth -0?exit< drop false >?
  0 swap vstack^
  dup vsitem-unknown! ;

@: vstack-drop  ( addr^ )
  dup 0?error" null vstack in \'>vstack\'!"
  dup vstack:depth:1-! ;

@: vstack-pick  ( idx addr^ -- item^ TRUE // FALSE )
  dup 0?error" null vstack in \'>vstack\'!"
  dup vstack:depth -0?exit< 2drop false >?
  2dup vstack:depth >= ?exit< 2drop false >?
  vstack^ ;

@: vstack-swap  ( addr^ )
  dup 0 vstack-pick
  swap 1 vstack-pick
  vsitems-swap ;


end-module STACKER


end-module IR
end-module TCOM
