;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; and now for something completely different...
;; UrForth/Beast: Devastator -- Seductive and Deadly Forth System
;; Copyright (C) 2023-2024 Ketmar Dark // Invisible Vector
;; see LICENSE.txt for license terms
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; convert between unix epoch date and y/m/d
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(*
  gday = (int)(y*365.25) + (int)(y/400) - (int)(y/100) + (int)(30.59*(m-2)) + d + 32
  jan and feb are monthes 13 and 14 of the previous year.
*)

719531 constant epoch-greg-diff

: dmy>gday  ( day month year -- gday )
  dup 1583 6000 within not?error" invalid year"
  swap dup 3 < ?< 12 + 1 under- >?
  2- 3059 100 u*/   ( d y mda )
  rot 32 + + swap   ( mdb y )
  dup 400 / over 100 / -  ( mdb y yadd )
  swap 36525 100 u*/ + + ;

: dmy>wday  ( day month year -- week-day )
  dmy>gday 3 + 7 mod ;

: dmy>epoch  ( day month year -- epoch-day )
  dmy>gday epoch-greg-diff - ;

(*
https://howardhinnant.github.io/date_algorithms.html
return number of days since civil 1970-01-01.
m: [1..12]
d: [1..n]
y: [1583..5999]
*)
(*
: dmy>epoch  ( day month year -- epoch-day )
  dup 1583 6000 within not?error" invalid year"
  over 1 13 within not?error" invalid month"
  over 2 <= +   ( day month year )
  rot dup 1 32 within not?error" invalid day"  ( month year day )
  1- rot 9 + 12 mod 153 * 2+ 5 / + >r ( year | day[0..365] )
  dup 400 /   ( year era | day )
  dup 400 * rot swap - >r  ( era | day yoe )
  r@ 365 * r@ 4/ + r> 100 / - r> +  ( era doe )
  swap 146097 * + 719468 - ;
*)

: epoch>dmy  ( epoch-day -- day month year )
  719468 + dup 0 2191395 within not?error" invalid epoch day"
  dup 146097 /   ( eday era )
  dup 146097 * rot swap - ( era doe )
  dup >r dup 1460 / - r@ 36524 / + r@ 146096 / - 365 /  ( era yoe | doe )
  swap 400 * over + swap  ( year yoe | doe )
  r> swap >r              ( year doe | yoe )
  r@ 365 * r@ 4/ + r> 100 / - - ( year doy )
  dup 5 * 2+ 153 /        ( year doy mp )
  tuck 153 * 2 + 5 / - 1+ ( year mp day )
  swap 2 + 12 mod 1+      ( year day month )
  rot over 2 <= - ;

: gday>dmy  ( gday -- day month year )
  epoch-greg-diff - epoch>dmy ;


;; 0 is sunday
: epoch>week-day  ( epoch-day -- week-day )
  dup 0< ?error" invalid epoch day" 4+ 7 mod ;

: leap?  ( year -- flag )
  dup 3 and ?exit< drop false >?
  dup 100 mod ?exit< drop true >?
  400 mod 0= ;

create days-month-table
31 c, 28 c, 31 c, 30 c, 31 c, 30 c, 31 c, 31 c, 30 c, 31 c, 30 c, 31 c,
create;

: days-in-month  ( month year -- days )
  \ swap 1- dup 0 12 within not?error" invalid month index"
  \ dup 1 = ?< drop 28 swap leap? - || nip 1+ dup 7 > - 1 and 30 + >? ;
  over 2 = ?< leap? negate || drop false >?
  swap 1- dup 0 12 within not?error" invalid month index"
  days-month-table + c@ + ;

create year-mstart-table
1 w, 32 w, 60 w, 91 w, 121 w, 152 w, 182 w, 213 w, 244 w, 274 w, 305 w, 335 w,
create;

;; 1-based
: my>yday  ( month year -- year-day )
  swap 1- dup 0 12 within not?error" invalid month"
  2* year-mstart-table + w@ swap
  over 32 > ?< leap? - || drop >? ;

;; 1-based
: dmy>year-day  ( day month year -- year-day )
  my>yday + 1- ;

;; 1-based
: epoch>year-day  ( epoch -- year-day )
  epoch>dmy dmy>year-day ;

: year-day>dmy  ( year-day year -- day month year )
  over 1 367 within not?error" invalid day" dup >r
  leap? negate 60 +
  2dup < ?exit< drop dup 32 / tuck 31 * - swap 1+ r> >?
  - dup 5 * 2+ 153 /  ( yday month )
  tuck 153 * 2+ 5 / 1+ - 2+ swap 3 + r> ;

: year-day>epoch  ( year-day year -- epoch-day )
  year-day>dmy dmy>epoch ;


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; unix time (seconds since epoch) conversions

60 60 * 24 * constant seconds-in-day

: utime>epoch  ( unix-time -- epoch ) seconds-in-day / ;
: epoch>utime  ( epoch -- unix-time ) seconds-in-day * ;

: utime>dmy  ( unix-time -- day month year )
  utime>epoch epoch>dmy ;

: dmy>utime  ( day month year -- unix-time )
  dmy>epoch epoch>utime ;

: utime>time  ( unix-time -- day-second )
  dup utime>dmy dmy>utime - ;

: utime>hms  ( unix-time -- second minute hour )
  utime>time
  60 /mod ( epoch-rest second )
  swap 60 /mod swap ;
