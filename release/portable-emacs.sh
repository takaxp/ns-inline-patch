#!/bin/sh

# 10.14.* Mojave, 10.15.* Catalina
# 11.* Big Sur, 12.* Monterey, 13.* Ventura, 14.* Sonoma
PRODUCTVERSION=`sw_vers -ProductVersion`
NETTLEVERSION="3.9.1" # "3.7.3", "3.8.1"
if [ ${PRODUCTVERSION%%.*} -lt 11 ]; then
    NETTLEVERSION=3.6 # for Mojave actually
fi

###############################################################################
CPUARC=`uname -m`
if [ "${CPUARC}" = "x86_64" ]; then
    HOMEBREWDIR="/usr/local" # Intel
else
    HOMEBREWDIR="/opt/homebrew" # Apple Silicon
fi
###############################################################################

WORKING_DIR="${HOME}/devel/emacs-head"
while getopts v:b:d:k: opt
do
    case ${opt} in
        d)
            WORKING_DIR=${OPTARG}
            ;;
        b)
            BRANCH=${OPTARG}
            ;;
        v)
            VERSION=${OPTARG}
            ;;
        k)
            KEYCHAIN=${OPTARG}
            ;;
        h)
            echo ""
            exit
            ;;
    esac
done

echo "--- Integrate GnuTLS and its dependencies into Emacs.app"
echo "--- PRODUCT VERSION: ${PRODUCTVERSION%%.*}"

if [ "$VERSION" = "" -a "$BRANCH" = "" ]; then
    echo "Please specify VERSION (-v 27.2) ov BRANCH (-b master)"
    exit 1
fi

if [ ! "${BRANCH}" = "" -a "${VERSION}" = "" ]; then
    APPDIR="${WORKING_DIR}/emacs/nextstep"
    echo "--- Targeting branch: ${BRANCH}"
fi

if [ "${BRANCH}" = "" -a ! "${VERSION}" = "" ]; then
    APPDIR="${WORKING_DIR}/emacs-${VERSION}/nextstep"
    echo "--- Targeting version: ${VERSION}"
fi

NATIVEAP=`${APPDIR}/Emacs.app/Contents/MacOS/Emacs -Q --batch --eval="(princ (when (fboundp 'native-comp-available-p) (native-comp-available-p)))"`

if [ "${NATIVEAP}" == "t" ]; then
    NATIVEAP=true
else
    NATIVEAP=false
fi

TARGETDIR="${APPDIR}/Emacs.app/Contents/MacOS"
if [ ! -d "$TARGETDIR" ]; then
    echo "$TARGETDIR does NOT exist"
    exit 1
fi

echo "$TARGETDIR"
cd "$TARGETDIR"

if [ -d "lib" ]; then
    rm -rf lib
fi

mkdir lib
cp ${HOMEBREWDIR}/opt/gnutls/lib/libgnutls.30.dylib lib
cp ${HOMEBREWDIR}/opt/p11-kit/lib/libp11-kit.0.dylib lib
cp ${HOMEBREWDIR}/opt/libidn2/lib/libidn2.0.dylib lib
cp ${HOMEBREWDIR}/opt/libunistring/lib/libunistring.5.dylib lib
cp ${HOMEBREWDIR}/opt/libtasn1/lib/libtasn1.6.dylib lib
cp ${HOMEBREWDIR}/opt/nettle/lib/libnettle.8.dylib lib
cp ${HOMEBREWDIR}/opt/nettle/lib/libhogweed.6.dylib lib
cp ${HOMEBREWDIR}/opt/gmp/lib/libgmp.10.dylib lib
cp ${HOMEBREWDIR}/opt/gettext/lib/libintl.8.dylib lib
cp ${HOMEBREWDIR}/opt/jansson/lib/libjansson.4.dylib lib
# if [ ${PRODUCTVERSION%%.*} -le 12 ]; then
#     cp ${HOMEBREWDIR}/opt/libffi/lib/libffi.7.dylib lib
# fi


NATIVECOMPILE=false
if [ -f ${HOMEBREWDIR}/opt/libgccjit/include/libgccjit.h ]; then
    NATIVECOMPILE=true
fi

if [ ! ${NATIVEAP} ]; then
    NATIVECOMPILE=false
fi

if [ $NATIVECOMPILE = true ]; then
    cp ${HOMEBREWDIR}/opt/libgccjit/lib/gcc/current/libgccjit.0.dylib lib
    cp ${HOMEBREWDIR}/opt/isl/lib/libisl.23.dylib lib
    cp ${HOMEBREWDIR}/opt/libmpc/lib/libmpc.3.dylib lib
    cp ${HOMEBREWDIR}/opt/mpfr/lib/libmpfr.6.dylib lib
    cp ${HOMEBREWDIR}/opt/zstd/lib/libzstd.1.dylib lib
fi

chmod 644 ./lib/*.dylib

install_name_tool -id "homebrew:gnutls/lib/libgnutls.30.dylib" lib/libgnutls.30.dylib
install_name_tool -id "homebrew:p11-kit/lib/libp11-kit.0.dylib" lib/libp11-kit.0.dylib
install_name_tool -id "homebrew:libidn2/lib/libidn2.0.dylib" lib/libidn2.0.dylib
install_name_tool -id "homebrew:libunistring/lib/libunistring.5.dylib" lib/libunistring.5.dylib
install_name_tool -id "homebrew:libtasn1/lib/libtasn1.6.dylib" lib/libtasn1.6.dylib
install_name_tool -id "homebrew:nettle/lib/libnettle.8.dylib" lib/libnettle.8.dylib
install_name_tool -id "homebrew:nettle/lib/libhogweed.6.dylib" lib/libhogweed.6.dylib
install_name_tool -id "homebrew:gmp/lib/libgmp.10.dylib" lib/libgmp.10.dylib
install_name_tool -id "homebrew:gettext/lib/libintl.8.dylib" lib/libintl.8.dylib
install_name_tool -id "homebrew:jansson/lib/libjansson.4.dylib" lib/libjansson.4.dylib
# if [ ${PRODUCTVERSION%%.*} -le 12 ]; then
#     install_name_tool -id "homebrew:libffi/lib/libffi.7.dylib" lib/libffi.7.dylib
# fi

if [ $NATIVECOMPILE = true ]; then
    install_name_tool -id "homebrew:libgccjit/lib/gcc/current/libgccjit.0.dylib" lib/libgccjit.0.dylib
    install_name_tool -id "homebrew:isl/lib/libisl.23.dylib" lib/libisl.23.dylib
    install_name_tool -id "homebrew:libmpc/lib/libmpc.3.dylib" lib/libmpc.3.dylib
    install_name_tool -id "homebrew:mpfr/lib/libmpfr.6.dylib" lib/libmpfr.6.dylib
    install_name_tool -id "homebrew:zstd/lib/libzstd.1.dylib" lib/libzstd.1.dylib
    install_name_tool -id "homebrew:gmp/lib/libgmp.10.dylib" lib/libgmp.10.dylib
fi

# otool -L Emacs
install_name_tool -change ${HOMEBREWDIR}/opt/gnutls/lib/libgnutls.30.dylib @executable_path/lib/libgnutls.30.dylib Emacs
install_name_tool -change ${HOMEBREWDIR}/opt/gmp/lib/libgmp.10.dylib @executable_path/lib/libgmp.10.dylib Emacs
install_name_tool -change ${HOMEBREWDIR}/opt/jansson/lib/libjansson.4.dylib @executable_path/lib/libjansson.4.dylib Emacs
install_name_tool -change ${HOMEBREWDIR}/Cellar/nettle/${NETTLEVERSION}/lib/libnettle.8.dylib @executable_path/lib/libnettle.8.dylib Emacs
if [ $NATIVECOMPILE = true ]; then
    install_name_tool -change ${HOMEBREWDIR}/opt/libgccjit/lib/gcc/current/libgccjit.0.dylib @executable_path/lib/libgccjit.0.dylib Emacs
fi

# otool -L lib/libgnutls.30.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/p11-kit/lib/libp11-kit.0.dylib @executable_path/lib/libp11-kit.0.dylib lib/libgnutls.30.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/libidn2/lib/libidn2.0.dylib @executable_path/lib/libidn2.0.dylib lib/libgnutls.30.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/libunistring/lib/libunistring.5.dylib @executable_path/lib/libunistring.5.dylib lib/libgnutls.30.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/libtasn1/lib/libtasn1.6.dylib @executable_path/lib/libtasn1.6.dylib lib/libgnutls.30.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/nettle/lib/libnettle.8.dylib @executable_path/lib/libnettle.8.dylib lib/libgnutls.30.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/nettle/lib/libhogweed.6.dylib @executable_path/lib/libhogweed.6.dylib lib/libgnutls.30.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/gmp/lib/libgmp.10.dylib @executable_path/lib/libgmp.10.dylib lib/libgnutls.30.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/gettext/lib/libintl.8.dylib @executable_path/lib/libintl.8.dylib lib/libgnutls.30.dylib

# otool -L lib/libp11-kit.0.dylib
# if [ ${PRODUCTVERSION%%.*} -le 12 ]; then
#     install_name_tool -change ${HOMEBREWDIR}/opt/libffi/lib/libffi.7.dylib @executable_path/lib/libffi.7.dylib lib/libp11-kit.0.dylib
# fi

# otool -L lib/libidn2.0.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/gettext/lib/libintl.8.dylib @executable_path/lib/libintl.8.dylib lib/libidn2.0.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/libunistring/lib/libunistring.5.dylib @executable_path/lib/libunistring.5.dylib lib/libidn2.0.dylib

# otool -L lib/libhogweed.6.dylib
install_name_tool -change ${HOMEBREWDIR}/opt/gmp/lib/libgmp.10.dylib @executable_path/lib/libgmp.10.dylib lib/libhogweed.6.dylib
install_name_tool -change ${HOMEBREWDIR}/Cellar/nettle/${NETTLEVERSION}/lib/libnettle.8.dylib @executable_path/lib/libnettle.8.dylib lib/libhogweed.6.dylib

if [ $NATIVECOMPILE = true ]; then
    # otool -L lib/libgccjit.0.dylib
    install_name_tool -change ${HOMEBREWDIR}/opt/isl/lib/libisl.23.dylib @executable_path/lib/libisl.23.dylib lib/libgccjit.0.dylib
    install_name_tool -change ${HOMEBREWDIR}/opt/libmpc/lib/libmpc.3.dylib @executable_path/lib/libmpc.3.dylib lib/libgccjit.0.dylib
    install_name_tool -change ${HOMEBREWDIR}/opt/mpfr/lib/libmpfr.6.dylib @executable_path/lib/libmpfr.6.dylib lib/libgccjit.0.dylib
    install_name_tool -change ${HOMEBREWDIR}/opt/gmp/lib/libgmp.10.dylib @executable_path/lib/libgmp.10.dylib lib/libgccjit.0.dylib
    install_name_tool -change ${HOMEBREWDIR}/opt/zstd/lib/libzstd.1.dylib @executable_path/lib/libzstd.1.dylib lib/libgccjit.0.dylib
    # otool -L lib/libisl.23.dylib
    install_name_tool -change ${HOMEBREWDIR}/opt/gmp/lib/libgmp.10.dylib @executable_path/lib/libgmp.10.dylib lib/libisl.23.dylib
    # otool -L lib/libmpc.3.dylib
    install_name_tool -change ${HOMEBREWDIR}/opt/mpfr/lib/libmpfr.6.dylib @executable_path/lib/libmpfr.6.dylib lib/libmpc.3.dylib
    install_name_tool -change ${HOMEBREWDIR}/opt/gmp/lib/libgmp.10.dylib @executable_path/lib/libgmp.10.dylib lib/libmpc.3.dylib
    # otool -L lib/libmpfr.6.dylib
    install_name_tool -change ${HOMEBREWDIR}/opt/gmp/lib/libgmp.10.dylib @executable_path/lib/libgmp.10.dylib lib/libmpfr.6.dylib
fi

chmod 444 ./lib/*.dylib

function verify_lib () {
    echo "-L "$1
    if [ "$2" ]; then
        RESULT=`otool -L lib/$1.$2.dylib | grep ${HOMEBREWDIR}`
    else
        RESULT=`otool -L $1 | grep ${HOMEBREWDIR}`
    fi
    if [ ${#RESULT} -gt 0 ]; then
        # echo ${RESULT}
        STATUS="${STATUS}\n${RESULT}"
    fi
}

# Verifying - If ok then nothing will be displayed except the lib names
verify_lib "Emacs"
verify_lib "libgnutls" "30"
verify_lib "libp11-kit" "0"
verify_lib "libidn2" "0"
verify_lib "libunistring" "5"
verify_lib "libtasn1" "6"
verify_lib "libnettle" "8"
verify_lib "libhogweed" "6"
verify_lib "libgmp" "10"
verify_lib "libintl" "8"
verify_lib "libjansson" "4"
# if [ ${PRODUCTVERSION%%.*} -le 12 ]; then
#     verify_lib "libffi" "7"
# fi

if [ ${NATIVECOMPILE} = true ]; then
    verify_lib "libgccjit" "0"
    verify_lib "libisl" "23"
    verify_lib "libmpc" "3"
    verify_lib "libmpfr" "6"
fi

if [ "${STATUS}" ];then
    echo "--- ${STATUS}"
    exit 1
fi

# Codesign
cd ${APPDIR}
ls
SIGNID=`security find-identity -v`
echo ${SIGNID}
DEVELOPERID="Developer ID Application: Takaaki Ishikawa (H2PH8KNN3H)"
echo ${DEVELOPERID}
echo "1"
RESULT=`codesign --verify --sign ${DEVELOPERID} --force --verbose --keychain ${KEYCHAIN} ./Emacs.app`
echo $RESULT
echo "2"
RESULT=`codesign --verify --sign ${DEVELOPERID} --force --verbose ${APPDIR}/Emacs.app`
echo $RESULT
echo ${APPDIR}/Emacs.app
echo "default-keychain"
security default-keychain
echo "login-keychain"
security login-keychain
echo "list-keychains"
security list-keychains
echo "KEYCHAIN"
echo "${KEYCHAIN}"
codesign -dv ./Emacs.app
RESULT=`pkgutil --check-signature ./Emacs.app | grep "no sign"`
if [ "${RESULT}" ]; then
    exit 1
fi
echo "--- done"
