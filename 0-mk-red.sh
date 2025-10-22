#!/bin/sh

if [ -f _zxemut_.propname.dat ]; then
  ZDAT="."
else
  ZDAT="baseblk"
fi

sh 0build-tk-app.sh room-editor \
  --file $ZDAT/_zxemut_.propname.dat PROPNAME.DAT \
  --file $ZDAT/_zxemut_.rooms.dat ROOMS.DAT \
  --file $ZDAT/_zxemut_.tiles.dat TILES.DAT \
  --file $ZDAT/_zxemut_.wkroom.tmp WKROOM.TMP \
  -o dsk/red.dsk
