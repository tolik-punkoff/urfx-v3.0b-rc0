;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple OOP system with inheritance (but w/o virtual methods)
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(*
create new class
================

inst-size inst-vocid xobj:new-class <name>

`inst-size` is instance size in bytes. the real instance size
will be slightly bigger, but `xobj:self` will always point to the
instance data, skipping all bookkeeping info.

`inst-vocid` is the module containing instance methods.
WARNING! *NOT* class methods!

subclass existing class
=======================

inst-size inst-vocid parent-class xobj:new-subclass <name>

methods vocid parent will be set to the parent class methods vocid.

create new object variable
==========================

myclass:new-obj myinst

using the object variable
=========================

myinst:method
myinst myclass:method
myinst myclass::method

it is possible to call instance methods via "classname:methodname",
passing instance data address. using "::" will not try to find class
methods first.


predefined class methods
========================

@size-of  ( -- full-size-in-bytes )
return full instance size (including all bookkeeping info).
  myclass:@size-of dynmem:?alloc
    (note the you need to use "emplace" on the allocated memory)

is-a?  ( obj-inst/class-ptr -- flag )
check if the given object or class is compatible.
  someinst myclass:is-a?

emplace  ( addr )
initialise the instance (put bookkeeping info).
  myclass:@size-of dynmem:?alloc
  dup myclass:emplace ;; init instance
  myclass:>instance   ;; now we have the proper instance address

mk-obj  ( addr count )
create and init new object variable.

new-obj  \ word-name
create and init new object variable.

invoke  ( ... addr count obj-pfa -- ... )
invoke object method by name. perform runtime searching, slow!
  myinst " method" myclass:invoke


high-level API
==============

xobj:mk-class  ( addr count size mtx-vocid )
create new class word in dictionary, initialise class data.

xobj:new-class  ( size mtx-vocid )
create new class word in dictionary, initialise class data.

xobj:@class  ( obj-pfa/kls-pfa -- class )
get class pointer of the given class/object. for valid
class pointers do nothing. abort on invalid pointer.

xobj:@level  ( obj-pfa/kls-pfa -- level )
get subclass level (`1` means "root class").
abort on invalid pointer.

xobj:@parent  ( obj-pfa/kls-pfa -- class // 0 )
get parent class pointer of the given class/object.
abort on invalid pointer.

xobj:@parent-at  ( nth obj-pfa/kls-pfa -- class // 0 )
get nth parent class pointer of the given class/object.
`1` means "self", negative or zero return `0`.
abort on invalid pointer.

xobj:@name  ( obj-pfa/kls-pfa -- addr count )
get class name. abort on invalid pointer.

xobj:@size-of  ( obj-pfa/kls-pfa -- addr count )
get full instance size. abort on invalid pointer.

xobj:class?  ( kls-pfa -- is-class? )
check if the given address is a valid class pointer.

xobj:instance?  ( kls-pfa -- is-class? )
check if the given address is a valid instance data pointer.

xobj:>instance  ( addr -- inst-addr )
convert address to "instance address", suitable for passing to
other APIs. note that "instance address" may not point to the
beginning of the allocated memory.
WARNING! doesn't perform type checking!

xobj:>raw-addr  ( inst-addr -- addr )
the opposite of ">instance". could be used when you need to
free allocated memory.
WARNING! doesn't perform type checking!

xobj:invoke  ( ... addr count obj-pfa -- ... )
invoke method by name. perform runtime searching, slow!
this API allows calling methods in any instance, without
runtime class type checking.

xobj:has  ( addr count obj-pfa -- flag )
check if the given class/instance has the given method.
return `FALSE` on invalid pointer.


method definition
=================

module MYOBJ-MTX
<disable-hash>
...
end-module MYOBJ-MTX

i.e. simply define a new module (it is better to disable hashing,
to avoid polluting global hash table). public and published words
will be accessible, hidden words will not be accessible.

methods can use "xobj:self" to get pointer to the current instance.

*)


module XOBJ
<disable-hash>
<public-words>

;; class format
struct:new klass
  field: kmagic   -- class "(doer)"
  field: vocid    -- instance methods
  field: isize    -- instance size, w/o this struct
  field: kname    -- class name address; use "idcount" to get ( addr count )
  field: #itable  -- number of items in inheritance table
end-struct klass
(*
for fast "is-a?" checks we will use inheritance table.
this table keeps all parent classes, and this class as
the last item. this way, "is-a?" check is O(1):
  get base class `#itable`
  check if it is less or equal to our
  check if our itable item at that poistion minus 1 equals to the base class
*)

;; instance format
struct:new inst
  field: imagic -- instance "(doer)"
  field: klass  -- instance "klass" struct
  ;; object data follows
end-struct inst


@: SELF  ( -- self )  (this) ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; instance methods

;; main "finder"
module XOBJ-VOC
<disable-hash>
end-module XOBJ-VOC


module XOBJ-MTX
<disable-hash>

;; CFA of this word is used as "kmagic"
|: (DOER)  ( inst-pfa -- obj-pfa )
  inst:@size-of +
  system:comp? ?< #, >? ;

|: (IMAGIC?)  ( inst-pfa -- ok? )
  inst:imagic ['] xobj-mtx::(doer) = ;

|: (?IMAGIC)  ( inst-pfa )
  (imagic?) not?error" instance expected" ;


|: (@CLASS)  ( inst-pfa -- klass-pfa )
  inst:klass ;

*: @class  ( -- class-pfa )
  ['] (doer) vocobj:?this
  inst:klass [\\] {#,} ;

;; get full instance size
*: @size-of  ( -- sizeof )
  ['] (doer) vocobj:?this
  inst:klass klass:isize inst:@size-of + [\\] {#,} ;

end-module XOBJ-MTX


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; class methods

;; main "finder"
module XKLS-VOC
<disable-hash>
end-module XKLS-VOC


module XKLS-MTX
<disable-hash>

;; CFA of this word is used as "kmagic"
|: (DOER)  ( klass-pfa -- klass-pfa )  ;

|: (KMAGIC?)  ( klass-pfa -- ok? )
  klass:kmagic ['] (doer) = ;

|: (?KMAGIC)  ( klass-pfa )
  (kmagic?) not?error" class expected" ;


|: (>itable)  ( klass-pfa -- itable )
  klass:@size-of + ;

|: (@parent)  ( klass-pfa -- parent-pfa )
  dup klass:#itable 1- dup -0?< 2drop 0
  || ( klass #itable-1 ) swap (>itable) swap dd-nth @ >? ;

*: @parent  ( -- parnet-pfa )
  ['] (doer) vocobj:?this
  (@parent) [\\] {#,} ;

*: @name  ( -- addr count )
  ['] (doer) vocobj:?this
  klass:kname idcount
  system:comp? ?< swap #, #, >? ;

;; get full instance size
*: @size-of  ( -- sizeof )
  ['] (doer) vocobj:?this
  klass:isize inst:@size-of + [\\] {#,} ;


|: (OBJ>CLASS)  ( obj-inst-pfa/kls-pfa -- kls-pfa // 0 )
  dup 65536 u< ?exit< drop 0 >?
  dup (kmagic?) ?exit
  inst:@size-of -
  dup xobj-mtx::(imagic?) not?exit< drop 0 >?
  xobj-mtx::(@class) ;

|: (?OBJ/CLASS)  ( obj-inst-pfa -- kls-pfa )
  dup 65536 u< ?error" instance expected"
  inst:@size-of -
  dup xobj-mtx::(imagic?) not?error" instance expected"
  xobj-mtx::(@class) ;


;; O(1) check, yay!
|: (IS-A-CLASS)  ( chk-kls-pfa base-kls-pfa -- is-a? )
  2dup and not?exit< 2drop false >?
  ;; early exit if possible
  2dup = ?exit< 2drop true >?
  ;; our class #itable should be greater than base #itable
  over klass:#itable over klass:#itable > not?exit< 2drop false >?
  ;; our itable item at base:#itable should be base-kls
  swap
  ( base-kls-pfa chk-kls-pfa )
  (>itable)  over klass:#itable 1- swap dd-nth @
  = ;

;; WARNING! we have object pfa here, not instance pfa
|: (IS-A)  ( obj-inst-pfa/kls-pfa kls-pfa -- is-a? )
  swap (obj>class) swap (is-a-class) ;

*: is-a?  ( obj/kls-inst-pfa -- flag )
  ['] (doer) vocobj:?this
  ( obj/kls-inst-pfa kls-inst-pfa )
  system:comp? ?< #, \\ (is-a) || (is-a) >? ;


|: (EMPLACE)  ( dest-addr klass-pfa )
  2dup
  klass:isize inst:@size-of + erase
  ( dest-addr klass-pfa )
  ( imagic) over ['] xobj-mtx::(doer) swap !
  ( klass) swap 4+ ! ;

*: emplace  ( dest-addr )
  ['] (doer) vocobj:?this
  ( dest-addr klass-pfa )
  system:comp? ?< #, \\ (emplace) || (emplace) >? ;


|: (MK-OBJ)  ( addr count klass-pfa )
  >r ['] xobj-mtx::(doer) vocid: xobj-voc vocobj:mk-vocid immediate
  r@ klass:isize inst:@size-of + n-allot
  ( dest-addr | klass-pfa )
  r> (emplace) ;

*: mk-obj  ( addr count )
  ['] (doer) vocobj:?this
  ( addr count klass-pfa )
  system:comp? ?< #, \\ (mk-obj) || (mk-obj) >? ;

*: new-obj  \ word-name
  parse-name  ['] mk-obj execute-tail ;


;; WARNING! we have object pfa here, not instance pfa
;; used in obj voc exec
|: (MT-INVOKE)  ( ... obj-pfa mt-cfa -- ... )
  (this) >loc swap (this):!
  execute
  loc> (this):! ;

|: (INVOKE-BAD-CLASS)  ( obj-klass-pfa klass-pfa )
  " object of class \'" pad$:!
  swap klass:kname idcount pad$:+
  " \' is not a child of \'" pad$:+
  klass:kname idcount pad$:+
  " \'!" pad$:+
  pad$:@ error ; (noreturn)

;; WARNING! we have object pfa here, not instance pfa
|: (INVOKE)  ( ... obj-pfa klass-pfa mt-cfa -- ... )
  >r over (?obj/class)
  ( obj-pfa klass-pfa obj-klass-pfa | mt-cfa )
  swap 2dup (is-a-class) not?< (invoke-bad-class) >? 2drop
  r> (mt-invoke) ;

|: (INVOKE-NOT-FOUND)  ( obj-pfa klass-pfa addr count -- ... )
  " method \'" pad$:! pad$:+
  " \' not found in object of class \'"
  klass:kname idcount pad$:+ " \'!" pad$:+
  drop
  pad$:@ error ; (noreturn)

|: (INVOKE-STR)  ( ... addr count obj-pfa klass-pfa -- ... )
  dup >r 2swap
  2dup r> klass:vocid vocid-find not?exit< (invoke-not-found) >?
  nrot 2drop ;; drop name
  ( obj-inst-pfa klass-pfa mt-cfa )
  (invoke) ;

;; WARNING! we have object pfa here, not instance pfa
*: invoke  ( ... addr count obj-pfa -- ... )
  ['] (doer) vocobj:?this
  ( addr count obj-inst-pfa klass-pfa )
  system:comp? ?exit< #, \\ (invoke-str) >?
  (invoke-str) ;

end-module XKLS-MTX


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; instance finder

0 quan (xobj-vcx-kmt?)  ;; class method?

;; locstack: klass-method?
|: (xobj-execcomp)  ( mt-cfa -- ... TRUE // cfa FALSE )
  (xobj-vcx-kmt?) ?exit< false >? ;; for class methods, we don't have to do anything special
  ws-vocab-cfa dart:cfa>pfa inst:@size-of +
  system:comp? ?< ( obj-pfa) #, ( mt-cfa) #, || swap >?
  ['] xkls-mtx::(mt-invoke)
  false ;
['] (xobj-execcomp) vocid: xobj-voc system:vocid-execcomp-cfa!

|: (xobj-find)  ( addr count skip-hidden? vocid -- cfa TRUE // FALSE )
  2drop
  2dup vocid: xobj-mtx vocid-find ?exit< nrot 2drop (xobj-vcx-kmt?):!t true >?
  \ ws-vocab-cfa dart:cfa>nfa debug:.id cr
  ws-vocab-cfa dart:cfa>pfa
  dup xobj-mtx::(?imagic)
  inst:klass klass:vocid vocid-find not?exit&leave
  (xobj-vcx-kmt?):!f true ;
['] (xobj-find) vocid: xobj-voc system:vocid-find-cfa!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; class finder

0 quan (xkls-vcx-obj?)  ;; object method?

;; locstack: object-method?
|: (xkls-execcomp)  ( mt-cfa -- ... TRUE // cfa FALSE )
  (xkls-vcx-obj?) not?exit&leave ;; for class methods, we don't have to do anything special
  ws-vocab-cfa dart:cfa>pfa
  dup xkls-mtx::(?kmagic)
  ( mt-cfa klass-pfa )
  system:comp? ?< #, #, || swap >?
  ['] xkls-mtx::(invoke)
  false ;
['] (xkls-execcomp) vocid: xkls-voc system:vocid-execcomp-cfa!

|: (xkls-invoke)  ( addr count -- cfa TRUE // FALSE )
  ws-vocab-cfa dart:cfa>pfa dup xkls-mtx::(?kmagic)
  klass:vocid vocid-find ?exit< (xkls-vcx-obj?):!t true >?
  false ;

;; "::" means "invoke only"
|: (xkls-find)  ( addr count skip-hidden? vocid -- cfa TRUE // FALSE )
  drop not?exit< (xkls-invoke) >?
  2dup vocid: xkls-mtx vocid-find ?exit< nrot 2drop (xkls-vcx-obj?):!f true >?
  (xkls-invoke) ;
['] (xkls-find) vocid: xkls-voc system:vocid-find-cfa!


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; query API

@: @class  ( obj-pfa/kls-pfa -- class )
  xkls-mtx::(obj>class)
  dup not?error" not an object" ;

@: @name  ( obj-pfa/kls-pfa -- addr count )
  @class klass:kname idcount ;

@: @size-of  ( obj-pfa/kls-pfa -- addr count )
  @class klass:isize inst:@size-of + ;

@: @level  ( obj-pfa/kls-pfa -- level )
  @class klass:#itable ;

;; `1` is self, `<1` is "none"
@: @parent-at  ( level obj-pfa/kls-pfa -- class // 0 )
  @class
  over 1 < ?error" invalid level"
  2dup klass:#itable > ?exit< 2drop 0 >?
  1 under-  klass:@size-of + dd-nth @ ;

@: >instance  ( addr -- inst-addr ) inst:@size-of + ;
@: >raw-addr  ( inst-addr -- addr ) inst:@size-of - ;

@: class?  ( kls-pfa -- is-class? )
  dup 65536 u< ?exit< drop false >?
  xkls-mtx::(kmagic?) ;

@: instance?  ( kls-pfa -- is-class? )
  dup 65536 u< ?exit< drop false >?
  inst:@size-of - xobj-mtx::(imagic?) ;

|: (MT-NOT-FOUND)  ( addr count obj-pfa )
  " method \'" pad$:! nrot pad$:+
  " \' not found in object of class \'"
  inst:@size-of - inst:klass klass:kname idcount pad$:+
  " \'!" pad$:+
  pad$:@ error ; (noreturn)

@: invoke  ( ... addr count obj-pfa -- ... )
  dup instance? not?error" not an instance"
  >r 2dup r@ inst:@size-of - inst:klass klass:vocid
  vocid-find not?exit< r> (mt-not-found) >?
  nrot 2drop ;; drop name
  r> swap xkls-mtx::(mt-invoke) ;

@: has  ( addr count obj-pfa -- flag )
  xkls-mtx::(obj>class) dup not?exit< 3drop false >?
  klass:vocid vocid-find ?< drop true || false >? ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; class creation API

|: (mk-inh-table)  ( parent-class )
  dup ?<
    ;; calculate table size
    dup klass:#itable
    ( #itable) dup 1+ ,
    ;; copy items
    swap xkls-mtx::(>itable) << ( #itable itable )
      @++ ,  1 under-  over ?^||
    else| 2drop >>
  || drop ( #itable) 1 , >?
  ;; last itable item is ourself
  system:latest-pfa , ;

;; args must be validated
|: (mk-any-class)  ( addr count size mtx-vocid parent-class )
  >r  ( addr count size mtx-vocid | parent-class )
  2swap ['] xkls-mtx::(doer) vocid: xkls-voc vocobj:mk-vocid immediate
  ( size mtx-vocid | parent-class )
  ;; setup vocid parent
  r@ ?< r@ klass:vocid over system:vocid-parent! >?
  ;; create class
  ( kmagic) ['] xkls-mtx::(doer) ,
  ( vocid) ,
  ( isize) ,
  ( kname) system:latest-nfa ,
  r> (mk-inh-table) ;

@: mk-class  ( addr count size mtx-vocid )
  system:?exec
  over 0 < ?error" invalid object size"
  dup not?error" invalid object mtx-vocid"
  0 (mk-any-class) ;

@: mk-subclass  ( addr count size mtx-vocid parent-class )
  system:?exec
  dup not?exit< 0 (mk-any-class) >?
  dup xkls-mtx::(?kmagic)
  over not?error" invalid object mtx-vocid"
  over system:vocid-parent@ ?<
    over system:vocid-parent@  over klass:vocid  =
    not?error" mtx-vocid already has a parent" >?
  >r  ( addr count size mtx-vocid | parent-class )
  over 0 < ?error" invalid object size"
  over r@ klass:isize < ?error" invalid object size"
  r> (mk-any-class) ;

@: new-class  ( size mtx-vocid )
  system:?exec
  parse-name 2swap mk-class ;

@: new-subclass  ( size mtx-vocid parent-class )
  system:?exec
  >r parse-name 2swap r> mk-subclass ;


seal-module
end-module XOBJ

\eof


$use <x86dis>

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; database object

struct:new obj-db
  field: dbx  -- database handle
end-struct obj-db


module DBO-MTX
<disable-hash>

: handle  ( -- handle )  xobj:self obj-db:dbx ;
: handle!  ( handle )  xobj:self obj-db:dbx:! ;

end-module DBO-MTX

\ " dbo" obj-db:@size-of vocid: dbo-mtx xobj:mk-class
obj-db:@size-of vocid: dbo-mtx xobj:new-class dbo
endcr ." class: $" dbo .hex8 ."  " dbo 0.r cr
endcr ." class name: " dbo:@name type cr
\ endcr ." #itable: " dbo xobj:klass:#itable 0.r cr
\ endcr ." #itable(0): " dbo xobj:xkls-mtx::(>itable) @ .hex8 cr
endcr ." class has \'handle\'? " " handle" dbo xobj:has 0.r cr
endcr ." class has \'.handle\'? " " .handle" dbo xobj:has 0.r cr


struct:extend obj-db as obj2-db
  field: fld
end-struct obj2-db

module DBO2-MTX
<disable-hash>
: .handle  dbo-mtx:handle 0.r ;
: fld  ( -- value )  xobj:self obj2-db:fld ;
: fld!  ( value )  xobj:self obj2-db:fld:! ;
end-module DBO2-MTX

obj2-db:@size-of vocid: dbo2-mtx dbo xobj:new-subclass dbo2
endcr ." class2: $" dbo2 .hex8 ."  " dbo2 0.r cr
endcr ." class2 name: " dbo2:@name type cr
\ endcr ." #itable: " dbo2 xobj:klass:#itable 0.r cr
\ endcr ." #itable(0): " dbo2 xobj:xkls-mtx::(>itable) 0 swap dd-nth @ .hex8 cr
\ endcr ." #itable(1): " dbo2 xobj:xkls-mtx::(>itable) 1 swap dd-nth @ .hex8 cr
endcr ." class has \'handle\'? " " handle" dbo2 xobj:has 0.r cr
endcr ." class has \'.handle\'? " " .handle" dbo2 xobj:has 0.r cr

dbo2:new-obj db

endcr ." obj size: " db:@size-of 0.r cr

endcr ." obj: $" db .hex8 ."  " db 0.r cr
endcr ." class: $" db:@class .hex8 ."  " db:@class 0.r cr
endcr ." is-a(dbo): " db dbo:is-a? 0.r cr
endcr ." is-a(dbo2): " db dbo2:is-a? 0.r cr
endcr ." level=" db xobj:@level 0.r cr
endcr ." self=$" 2 db xobj:@parent-at dup .hex8 ."  " xobj:@name type cr
endcr ." parent=$" 1 db xobj:@parent-at dup .hex8 ."  " xobj:@name type cr


: xcc  endcr ." class: $" db:@class .hex8 ."  " db:@class 0.r cr ;
\ debug:see xcc
xcc

dbo xobj:class? " why not a class?" not?error
db xobj:instance? " why not an instance?" not?error

: xcc1  ( obj )  endcr ." class: $" dup xobj:@class .hex8 ."  " xobj:@class 0.r cr ;
\ debug:see xcc1
db xcc1

endcr ." handle from obj: " db:handle 0.r cr

69 db:handle!

endcr ." handle from colon-invoke: " db dbo::handle 0.r cr
endcr ." handle from colon-invoke2: " db dbo2::handle 0.r cr
endcr ." is-a?: " db dbo:is-a? 0.r cr
endcr ." is-a2?: " db dbo2:is-a? 0.r cr

endcr ." handle from invoke: " " handle" db dbo:invoke 0.r cr
endcr ." handle from invoke2: " " handle" db dbo2:invoke 0.r cr

: test0  666 db:handle! ;
test0
endcr ." handle after test: " db:handle 0.r cr

\ : test1 db ;
\ test1

: test2  endcr ." handle from test2: " db dbo:handle 0.r cr ;
test2

: test3  endcr ." handle from test3: " " handle" db dbo:invoke 0.r cr ;
test3

endcr ." dynamic invoke w/o typecheck: " " handle" db xobj:invoke 0.r cr

endcr ." fld: " db:fld 0.r cr
669 db:fld!
endcr ." new-fld: " db:fld 0.r cr

endcr ." fld: " db dbo2:fld 0.r cr
69 db dbo2:fld!
endcr ." new-fld: " db dbo2:fld 0.r cr
