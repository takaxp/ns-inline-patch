#!/bin/sh

SOURCE_DIR="${HOME}/devel/emacs-head"
WORKING_DIR="${HOME}/Desktop"
PROFILE_NAME="emacs-build"
LIB_GCCJIT="libgccjit.0.dylib"

while getopts v:p:b:k:d:s:a:m: opt
do
    case ${opt} in
        s)
            SOURCE_DIR=${OPTARG}
            ;;
        d)
            WORKING_DIR=${OPTARG}
            ;;
        p)
            PATCH=${OPTARG}
            ;;
        a)
            PROFILE_NAME=${OPTARG}
            ;;
        b)
            BRANCH=${OPTARG}
            ;;
        v)
            VERSION=${OPTARG}
            ;;
        m)
            MACOS="-${OPTARG}"
            ;;
        h)
            echo ""
            exit
            ;;
    esac
done

if [ "${PATCH}" = "pure" ]; then
    APPINSTALL_DIR="Emacs-takaxp/pure" # APPINSTALL_DIR="Emacs-takaxp"
    PKG_TITLE="GNU Emacs (NS without patch)"
elif [ "${PATCH}" = "inline" ]; then
    APPINSTALL_DIR="Emacs-takaxp"
    PKG_TITLE="GNU Emacs (NS with inline-patch)"
elif [ "${PATCH}" = "private" ]; then
    APPINSTALL_DIR="" # Emacs-takaxp/private
    PKG_TITLE="GNU Emacs (NS with private patch)"
else
    echo "Please provide patch mode by \"-p pure\"."
    exit 1
fi

PKG_VERSION=$(date '+%Y.%m%d.%H%M')
if [ ! "$VERSION" -a ! "${BRANCH}" ]; then
    echo "Please specify VERSION (-v 28.2)"
    echo "Also check APPINSTALL_DIR and PKG_VERSION ($APPINSTALL_DIR, $PKG_VERSION)"
    exit 1
else
    echo "Version:    $VERSION"
    echo "Branch:     $BRANCH"
    echo "APPINSTALL_DIR:     $APPINSTALL_DIR"
    echo "PKG_TITLE: $PKG_TITLE"
    echo "PKG_VERSION: $PKG_VERSION"
fi

##############################################################################

# Setup working directory
cd ${WORKING_DIR}
if [ -d "notarize" ]; then
    rm -rf notarize
fi
PKG_APPINSTALL_DIR="pkg/Applications/${APPINSTALL_DIR}"
mkdir -p notarize/${PKG_APPINSTALL_DIR}

cd ${WORKING_DIR}/notarize

# Generate entitlements.plist
rm -f entitlements.plist
touch entitlements.plist
echo '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n    <dict>\n        <key>com.apple.security.network.client</key>\n        <true/>\n        <key>com.apple.security.cs.disable-library-validation</key>\n        <true/>\n    </dict>\n</plist>' >> entitlements.plist

# Codesign
if [ ! "${BRANCH}" = "" -a "${VERSION}" = "" ]; then
    APP_DIR="${SOURCE_DIR}/emacs/nextstep"
    echo "--- Targeting branch: ${BRANCH}"
fi
if [ "${BRANCH}" = "" -a ! "${VERSION}" = "" ]; then
    APP_DIR="${SOURCE_DIR}/emacs-${VERSION}/nextstep"
    echo "--- Targeting version: ${VERSION}"
fi
cp -r ${APP_DIR}/Emacs.app ${PKG_APPINSTALL_DIR}

DEVELOPER_ID='Developer ID Application: Takaaki Ishikawa (H2PH8KNN3H)'
codesign --verify --sign "${DEVELOPER_ID}" --deep --force --verbose --option runtime --entitlements entitlements.plist --timestamp ./${PKG_APPINSTALL_DIR}/Emacs.app

# Check the signature
RESULT=$(pkgutil --check-signature ./${PKG_APPINSTALL_DIR}/Emacs.app | grep "no sign")
if [ "${RESULT}" ]; then
    exit 1
fi

# Edit packages.plist
cd ${WORKING_DIR}/notarize/pkg
pkgbuild --analyze --root Applications packages.plist

echo "---------------------------------"
echo "Make BundleIsRelocatable false"
echo "Make BundleIsVersionChecked false"
echo "---------------------------------"
plutil -replace 'BundleIsRelocatable' -bool false packages.plist
plutil -replace 'BundleIsVersionChecked' -bool false packages.plist

# Create pkg file
pkgbuild Emacs.pkg --root Applications --component-plist packages.plist --identifier com.takaxp.emacs --version ${PKG_VERSION} --install-location "/Applications"

# Edit Distribution.xml
productbuild --synthesize --package Emacs.pkg Distribution.xml

XMLSTARLET=$(which xmlstarlet)
if [ ! ${XMLSTARLET} ]; then
    echo "xmlstarlet shall be instaled."
    exit 1
fi

echo "---------------------------------"
echo "Add title and allowed-os-versions"
echo "---------------------------------"
${XMLSTARLET} ed -a '/installer-gui-script/choice[@id="com.takaxp.emacs"]' -t 'elem' -n 'title' -v "${PKG_TITLE}" \
-a '/installer-gui-script/title' -t 'elem' -n 'allowed-os-versions' \
-s '/installer-gui-script/allowed-os-versions' -t 'elem' -n 'os-version' \
-a '/installer-gui-script/allowed-os-versions/os-version' -t 'attr' -n 'min' -v '10.15' Distribution.xml > edited.xml
mv edited.xml Distribution.xml

# Create Emacs-Distribution.pkg
productbuild --distribution Distribution.xml --package-path Emacs.pkg Emacs-Distribution.pkg

# Productsign
DEVELOPER_ID='Developer ID Installer: Takaaki Ishikawa (H2PH8KNN3H)'
productsign --sign "${DEVELOPER_ID}" Emacs-Distribution.pkg Emacs-Distribution_SIGNED.pkg

# Check the signature
RESULT=$(pkgutil --check-signature Emacs-Distribution_SIGNED.pkg | grep "no sign")
if [ "${RESULT}" ]; then
    exit 1
fi

# Uploading the pkg to apple server
xcrun notarytool submit "Emacs-Distribution_SIGNED.pkg" --keychain-profile "${PROFILE_NAME}" --wait
rm -f Emacs.pkg Emacs-Distribution.pkg

sleep 2

cd ${WORKING_DIR}/notarize/pkg
xcrun stapler staple Emacs-Distribution_SIGNED.pkg
CPUARC=$(uname -m)
echo "--- Build for ${CPUARC}"

if [ "${BRANCH}" ]; then
    FILENAME="${BRANCH}"
    if [ "${BRANCH}" = "master" ]; then
        FILENAME="emacs-head"
    fi
elif [ "${VERSION}" ]; then
    FILENAME="emacs-${VERSION}"
fi

VENDER="_apple"
[ "${CPUARC}" = "x86_64" ] && VENDER="_intel"
[ "${PATCH}" = "pure" ] && PURE="_pure"
if [ -f ./Applications/${APPINSTALL_DIR}/Emacs.app/Contents/MacOS/lib/${LIB_GCCJIT} ]; then
    NATIVE="_nc"
fi

mv Emacs-Distribution_SIGNED.pkg ${FILENAME}${VENDER}${PURE}${NATIVE}${MACOS}.pkg
rm -f ${FILENAME}${VENDER}${PURE}${NATIVE}${MACOS}.md5
md5 ${FILENAME}${VENDER}${PURE}${NATIVE}${MACOS}.pkg > ${FILENAME}${VENDER}${PURE}${NATIVE}${MACOS}.md5

echo "--- ${FILENAME}${VENDER}${PURE}${NATIVE}${MACOS}.pkg and md5 are generaed"

cp -f *.pkg ${WORKING_DIR}
cp -f *.md5 ${WORKING_DIR}
rm -rf ${WORKING_DIR}/notarize

echo "--- done"
