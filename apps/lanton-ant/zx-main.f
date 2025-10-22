\ $zx-use <emit8-rom>
$zx-use <gfx/plot>

0 quan dir
0 quan ant-x
0 quan ant-y

create dir-dxy
   0 , -1 , ;; up
   1 ,  0 , ;; right
   0 ,  1 , ;; down
  -1 ,  0 , ;; left
create;

: dir!  ( n )  3 and dir:c! ; zx-inline

: turn-left   dir 1- dir! ; zx-inline
: turn-right  dir 1+ dir! ; zx-inline

: move-ant
  dir 4* dir-dxy +
  @++
  ant-x + 255 and ant-x:!
  \ @ ant-y + 192 + 192 umod ant-y:! ;
  ;; for speed
  @ dup not?exit< drop >?
  -?< ant-y 1- dup -?< drop 191 >?
   || ant-y 1+ dup 191 > ?< drop 0 >?
  >? ant-y:! ; zx-inline

0 quan test

: opt-test
  test abs test:+!
;

: RUN
  opt-test
  \ scr$-checker-pattern!
  cls
  " Bytes: #8000:0695" (ROM-TYPE)
  128 ant-x:!
  96 ant-y:!
  1 dir:!
  << ant-x ant-y point
     ant-x ant-y pxor
     ?< turn-left || turn-right >?
     move-ant
  ^|| >> ;
zx-no-return
