#!/bin/sh

# LIBXML2 for Catalina
MACSDK=`xcrun --show-sdk-path`
export LIBXML2_CFLAGS="-I${MACSDK}/usr/include/libxml2"
export LIBXML2_LIBS="-lxml2"

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

git clone --depth 1 git://git.sv.gnu.org/emacs.git
git clone --depth 1 https://github.com/takaxp/ns-inline-patch.git

cd emacs
patch -p1 < ../ns-inline-patch/emacs-head-inline.patch
if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi

sleep 5
./autogen.sh
./configure CC=clang --without-x --with-ns --with-modules
CORES=
#CORES=4
make bootstrap -j$CORES
make install -j$CORES
cd ./nextstep
open .
