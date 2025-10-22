#!/bin/sh

if [ -f _zxemut_.sprites.dat ]; then
  ZDAT="."
else
  ZDAT="baseblk"
fi

sh 0build-tk-app.sh spr16-editor \
  --file $ZDAT/_zxemut_.sprites.dat SPRITES.DAT \
  -o dsk/sped.dsk
