#!/bin/sh

# LIBXML2 for Catalina
MACSDK=`xcrun --show-sdk-path`
export LIBXML2_CFLAGS="-I${MACSDK}/usr/include/libxml2"
export LIBXML2_LIBS="-lxml2"

#
# For BREW, change to
# LOCAL_BASE=/opt/local
LOCAL_BASE=/usr/local

cd ~/Desktop
git clone git://git.sv.gnu.org/emacs.git
git clone --depth 1 https://github.com/takaxp/ns-inline-patch.git

cd emacs
git checkout --track origin/emacs-27
patch -p1 < ../ns-inline-patch/emacs-27.1-inline.patch

sleep 5
./autogen.sh
#./configure CC=clang --without-x --with-ns --with-modules
./configure --without-x --with-ns --with-modules --enable-silent-rules \
			PKG_CONFIG_PATH=${LOCAL_BASE}/lib/pkgconfig \
			LDFLAGS="-L${LOCAL_BASE}/lib" CPPFLAGS="-I${LOCAL_BASE}/include" \
			CC=clang OBJC=clang CFLAGS="-g -O2"

CORES=
#CORES=4
make bootstrap -j$CORES
make install -j$CORES

#
# Inspired by
# https://www.reddit.com/r/emacs/comments/bclyyc/building_emacs_from_source_on_macos/
#
mkdir nextstep/Emacs.app/Contents/Frameworks
/usr/bin/python -m macholib standalone nextstep/Emacs.app
#
#
#
cd ./nextstep
open .
