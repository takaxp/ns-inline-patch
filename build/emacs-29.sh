#!/bin/sh

VERSION=29.3

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

WORKING_DIR="${HOME}/Desktop"
CORES=4
NATIVE="no"
while getopts d:j:ngp: opt
do
    case ${opt} in
        n)
            NATIVE="yes"
            ;;
        j)
            CORES=${OPTARG}
            ;;
        d)
            WORKING_DIR=${OPTARG}
            ;;
        p)
            PATCH=${OPTARG}
            ;;
    esac
done

cd ${WORKING_DIR}

echo "---------------------------------"
echo "WorkingDir: ${WORKING_DIR}"
echo "NativeComp: ${NATIVE}"
echo "Cores: ${CORES}"
curl -LO ftp://ftp.gnu.org/gnu/emacs/emacs-$VERSION.tar.gz
tar xvf ./emacs-$VERSION.tar.gz
if [ ! -d "emacs-$VERSION" ]; then
    echo "missing emacs-$VERSION/"
    exit 1
fi

echo "---------------------------------"

if [ "${PATCH}" = "inline" ]; then
    # inline-patch
    git clone --depth 1 https://github.com/takaxp/ns-inline-patch.git

    cd emacs-${VERSION}
    patch -p1 < ../ns-inline-patch/emacs-29.1-inline.patch
    if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
else
    cd emacs-${VERSION}
fi

sleep 5
./autogen.sh
./configure --without-x --with-ns --with-modules --with-jpeg=no --with-tiff=no --with-gif=no --with-png=no --with-lcms2=no --with-webp=no --with-rsvg=no --with-tree-sitter=no --with-native-compilation=${NATIVE}
make bootstrap -j$CORES
make install -j$CORES
cd ./nextstep
open .
