#!/bin/bash

set -o errexit
set -o nounset

: ${TYPE:="toybox"}

rm -f tiny-initrd.img
rm -rf tinyroot


#mkdir -p tinyroot/{bin,dev,etc,lib,opt,proc,run,sbin,srv,sys,tmp}
mkdir -p tinyroot/{bin,sbin}

case "${TYPE}" in
  "toybox")
    install -m 0755 toybox-x86_64 tinyroot/bin
    install -m 0755 img/init.sh tinyroot/init
    cd tinyroot/bin
    for i in $(./toybox-x86_64); do
      ln -s toybox-x86_64 $i
    done
    cd -
    ;;
  "alpine")
    cd tinyroot
    tar xf ../alpine.tar.gz
    cd -
    install -m 0755 img/init.sh tinyroot/init
    ;;
  *)
    echo "Unknown type"
    exit 1
    ;;
esac

cd tinyroot
find . | cpio -H newc -o | zstd -z -T0 -o ../tiny-initrd-${TYPE}.img
cd -
