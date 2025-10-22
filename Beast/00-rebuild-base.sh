#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir"
./urforth Uroborus/urb-main.f --static --base --image urforth-base.elf && ./urforth-base.elf Uroborus/urb-main.f
res="$?"
cd "$odir"
exit $res
