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
BREW=`which brew`
BREW_PREFIX=`$BREW --prefix`
BREW_LIBGCCJIT_PREFIX=`$BREW --prefix --installed libgccjit 2>/dev/null`
BREW_GCC_MAJOR=15
BREW_GCC_TRIPLET=$(${BREW_PREFIX}/bin/gcc-${BREW_GCC_MAJOR} -dumpmachine)
export CFLAGS="$CFLAGS -I${BREW_LIBGCCJIT_PREFIX}/include"
export LIBRARY_PATH=${BREW_PREFIX}/lib/gcc/current:${BREW_PREFIX}/opt/gcc/lib/gcc/current/gcc/${BREW_GCC_TRIPLET}/${BREW_GCC_MAJOR}

WORKING_DIR="${HOME}/Desktop"
CORES=4
NATIVE="no"
BRANCH=master
while getopts d:j:ngb: opt
do
    case ${opt} in
        n)
            NATIVE="aot"
            ;;
        j)
            CORES=${OPTARG}
            ;;
        d)
            WORKING_DIR=${OPTARG}
            ;;
        g)
            SV_HOST=true
            ;;
        b)
            BRANCH=${OPTARG}
    esac
done

cd ${WORKING_DIR}

echo "---------------------------------"
echo "WorkingDir: ${WORKING_DIR}"
echo "NativeComp: ${NATIVE}"
echo "Cores: ${CORES}"
echo "Target branch: ${BRANCH}"
rm -rf ./emacs
SHALLOW="--depth 1"
if [ ! ${BRANCH} = "master" ]; then
    SHALLOW="--depth 1 --no-single-branch -b ${BRANCH}"
fi

if [ $SV_HOST ]; then
    echo "Source: git://git.sv.gnu.org/emacs.git"
    git clone ${SHALLOW} git://git.sv.gnu.org/emacs.git
else
    echo "Source: https://github.com/emacs-mirror/emacs.git"
    git clone ${SHALLOW} https://github.com/emacs-mirror/emacs.git
fi
echo "---------------------------------"

# inline-patch
git clone --depth 1 https://github.com/takaxp/ns-inline-patch.git

cd emacs
if [ "${BRANCH}" = "emacs-30" ]; then
    patch -p1 < ../ns-inline-patch/emacs-29.1-inline.patch
    # see https://github.com/emacs-mirror/emacs/commit/d587ce8c65a0e22ab0a63ef2873a3dfcfbeba166
    patch -p1 < ../ns-inline-patch/fix-emacs30-head-treesit.c.patch
elif [ "${BRANCH}" = "emacs-29" ]; then
    patch -p1 < ../ns-inline-patch/emacs-29.1-inline.patch
elif [ "${BRANCH}" = "emacs-28" ]; then
    patch -p1 < ../ns-inline-patch/emacs-28.1-inline.patch
elif [ "${BRANCH}" = "emacs-27" ]; then
    patch -p1 < ../ns-inline-patch/emacs-27.1-inline.patch
else
    patch -p1 < ../ns-inline-patch/emacs-head-inline.patch
fi

if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi

sleep 5
./autogen.sh
./configure --without-x --with-ns --with-modules --with-jpeg=no --with-tiff=no --with-gif=no --with-png=no --with-lcms2=no --with-webp=no --with-rsvg=no --with-tree-sitter=no --with-native-compilation=${NATIVE}
make bootstrap -j$CORES
make install -j$CORES
cd ./nextstep
open .
