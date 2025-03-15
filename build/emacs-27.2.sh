#!/bin/sh

VERSION=27.2

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

# if [ ! -f emacs-$VERSION.tar.gz ]; then
#     curl -LO ftp://ftp.gnu.org/gnu/emacs/emacs-$VERSION.tar.gz
# fi
curl -LO ftp://ftp.gnu.org/gnu/emacs/emacs-$VERSION.tar.gz

rm -rf ./emacs-${VERSION}
tar xvf ./emacs-$VERSION.tar.gz
if [ ! -d "emacs-$VERSION" ]; then
    echo "missing emacs-$VERSION/"
    exit 1
fi
echo "---------------------------------"

# inline-patch
git clone --depth 1 https://github.com/takaxp/ns-inline-patch.git

cd emacs-${VERSION}
patch -p1 < ../ns-inline-patch/emacs-27.1-inline.patch
if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
# patch -p1 < ../ns-inline-patch/revert-89d0c445.patch
# if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi
# patch -p1 < ../$PATCH/ns-inline-patch/fix-working-text.patch
# if [ $? -ne 0 ]; then echo "FAILED"; exit 1; fi

sleep 5
./autogen.sh
./configure CC=clang --without-x --with-ns --with-modules
CORES=
#CORES=4
make bootstrap -j$CORES
make install -j$CORES
cd ./nextstep
open .
