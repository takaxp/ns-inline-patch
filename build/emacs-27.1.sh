#!/bin/sh

# LIBXML2 for Catalina
MACSDK=`xcrun --show-sdk-path`
export LIBXML2_CFLAGS="-I${MACSDK}/usr/include/libxml2"
export LIBXML2_LIBS="-lxml2"

cd ~/Desktop
git clone git://git.sv.gnu.org/emacs.git
git clone --depth 1 https://github.com/takaxp/ns-inline-patch.git

cd emacs
git checkout --track origin/emacs-27
patch -p1 < ../ns-inline-patch/emacs-27.1-inline.patch

sleep 5
./autogen.sh
./configure CC=clang --without-x --with-ns --with-modules
CORES=
#CORES=4
make bootstrap -j$CORES
make install -j$CORES
cd ./nextstep
open .
