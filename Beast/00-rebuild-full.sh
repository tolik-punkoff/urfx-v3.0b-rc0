#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir"
./urforth Uroborus/urb-main.f --image urforth0.elf
res="$?"
if [ $res -eq 0 ]; then
  echo "saving 'urforth' binary with x86dis..."
  ./urforth0.elf 0-build-maxi.f
  res="$?"
fi
rm urforth0.elf 2>/dev/null
cd "$odir"
exit $res
