#!/bin/sh

# LIBXML2 for Catalina
MACSDK=`xcrun --show-sdk-path`
export LIBXML2_CFLAGS="-I${MACSDK}/usr/include/libxml2"
export LIBXML2_LIBS="-lxml2"
export PATH="/usr/local/opt/texinfo/bin:$PATH"

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
mkdir emacs_ns
cd emacs_ns
VERSION=26.3
curl -LO ftp://ftp.gnu.org/gnu/emacs/emacs-$VERSION.tar.gz
git clone --depth 1 https://github.com/takaxp/ns-inline-patch.git
tar zxvf emacs-$VERSION.tar.gz
cd ./emacs-$VERSION
patch -p1 < ../ns-inline-patch/emacs-25.2-inline.patch
if [ $? -ne 0 ]; then echo "FAILED"; exit; fi
sleep 5
./autogen.sh
./configure CC=clang --without-x --with-ns --with-modules
CORES=
#CORES=1
make bootstrap -j$CORES
make install -j$CORES
cd ./nextstep
open .
