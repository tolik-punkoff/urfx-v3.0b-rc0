#!/bin/sh

if [ "z$1" = "z" ]; then
  echo "app?"
  exit 1
fi

odir=`pwd`
mydir=`dirname "$0"`
cd "$mydir"

Beast/urforth-static ./urfx-main.f --app "$@" --turnkey-pass1 && \
Beast/urforth-static ./urfx-main.f --app "$@" --turnkey-pass2
res=$?

cd "$odir"
exit $res
