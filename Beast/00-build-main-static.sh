#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir"
./urforth-base.elf Uroborus/urb-main.f --static --image urforth-static
res="$?"
cd "$odir"
exit $res
