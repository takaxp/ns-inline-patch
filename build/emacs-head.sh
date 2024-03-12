#!/bin/sh

# LIBXML2 for Catalina
MACSDK=`xcrun --show-sdk-path`
export LIBXML2_CFLAGS="-I${MACSDK}/usr/include/libxml2"
export LIBXML2_LIBS="-lxml2"

# For Apple Silicon, Emacs version 27.2 or later supports to build.
CPUARC=`uname -m`
if [ "${CPUARC}" = "x86_64" ]; then
    # Catalina or later
    export MACOSX_DEPLOYMENT_TARGET=10.15
else
    # Big Sur or later
    export MACOSX_DEPLOYMENT_TARGET=11.0
fi

# Native compilation
if [ "${CPUARC}" = "arm64" ]; then
    BREW=`which brew`
    BREW_LIBGCCJIT_PREFIX=`$BREW --prefix --installed libgccjit 2>/dev/null`
    export CFLAGS="$CFLAGS -I${BREW_LIBGCCJIT_PREFIX}/include"
fi

export WORKING_DIR="${HOME}/Desktop"
while getopts d: opt
do
    case ${opt} in
        d)
            WORKING_DIR=${OPTARG}
            ;;
    esac
done

cd ${WORKING_DIR}

# Please select emacs-mirror if you have any connection troubles.
# git clone --depth 1 https://github.com/emacs-mirror/emacs.git
git clone --depth 1 git://git.sv.gnu.org/emacs.git

# inline-patch
git clone --depth 1 https://github.com/takaxp/ns-inline-patch.git

cd emacs
patch -p1 < ../ns-inline-patch/emacs-head-inline.patch
if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi

sleep 5
./autogen.sh
./configure CC=clang --without-x --with-ns --with-modules --with-native-compilation=yes
CORES=
#CORES=4
make bootstrap -j$CORES
make install -j$CORES
cd ./nextstep
open .
