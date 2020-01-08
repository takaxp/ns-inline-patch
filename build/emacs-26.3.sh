#!/bin/sh

# LIBXML2 for Catalina
MACSDK=`xcrun --show-sdk-path`
export LIBXML2_CFLAGS="-I${MACSDK}/usr/include/libxml2"
export LIBXML2_LIBS="-lxml2"

cd ~/Desktop
mkdir emacs_ns
cd ~/Desktop/emacs_ns
VERSION=26.3
curl -LO ftp://ftp.gnu.org/gnu/emacs/emacs-$VERSION.tar.gz
git clone --depth 1 https://github.com/takaxp/ns-inline-patch.git
tar zxvf emacs-$VERSION.tar.gz
cd ./emacs-$VERSION
patch -p1 < ../ns-inline-patch/emacs-25.2-inline.patch
sleep 5
./autogen.sh
./configure CC=clang --without-x --with-ns --with-modules
CORES=
#CORES=1
make bootstrap -j$CORES
make install -j$CORES
cd ./nextstep
open .
