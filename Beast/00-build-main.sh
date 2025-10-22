#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir"
./urforth-base.elf Uroborus/urb-main.f
res="$?"
cd "$odir"
exit $res
