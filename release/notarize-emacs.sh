#!/bin/sh

SOURCE_DIR="${HOME}/devel/emacs-head"
WORKING_DIR="${HOME}/Desktop"
PROFILE_NAME="emacs-build"

while getopts v:p:b:k:d:s:a: opt
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
        h)
            echo ""
            exit
            ;;
    esac
done

if [ "${PATCH}" = "pure" ]; then
    APPINSTALLDIR="Emacs-takaxp/pure" # APPINSTALLDIR="Emacs-takaxp"
elif [ "${PATCH}" = "inline" ]; then
    APPINSTALLDIR="Emacs-takaxp"
elif [ "${PATCH}" = "private" ]; then
    APPINSTALLDIR="" # Emacs-takaxp/private
else
    echo "Please provide patch mode by \"-p pure\"."
    exit 1
fi

PKGVERSION=`date '+%Y%m%d%H%M'`
if [ ! "$VERSION" -a ! "${BRANCH}" ]; then
    echo "Please specify VERSION (-v 28.2)"
    echo "Also check APPINSTALLDIR and PKGVERSION ($APPINSTALLDIR, $PKGVERSION)"
    exit 1
else
    echo "Version:    $VERSION"
    echo "Branch:     $BRANCH"
    echo "APPINSTALLDIR:     $APPINSTALLDIR"
    echo "PKGVERSION: $PKGVERSION"
fi

##############################################################################

# Setup working directory
cd ${WORKING_DIR}
if [ -d "notarize" ]; then
    rm -rf notarize
fi
mkdir -p notarize/pkg/Applications/${APPINSTALLDIR}

cd ${WORKING_DIR}/notarize

# Generate entitlements.plist
rm -f entitlements.plist
touch entitlements.plist
echo '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n    <dict>\n        <key>com.apple.security.network.client</key>\n        <true/>\n        <key>com.apple.security.cs.disable-library-validation</key>\n        <true/>\n    </dict>\n</plist>' >> entitlements.plist

# Codesign
if [ ! "${BRANCH}" = "" -a "${VERSION}" = "" ]; then
    APPDIR="${SOURCE_DIR}/emacs/nextstep"
    echo "--- Targeting branch: ${BRANCH}"
fi
if [ "${BRANCH}" = "" -a ! "${VERSION}" = "" ]; then
    APPDIR="${SOURCE_DIR}/emacs-${VERSION}/nextstep"
    echo "--- Targeting version: ${VERSION}"
fi
cp -r ${APPDIR}/Emacs.app pkg/Applications/${APPINSTALLDIR}

DEVELOPERID='Developer ID Application: Takaaki Ishikawa (H2PH8KNN3H)'
codesign --verify --sign "${DEVELOPERID}" --deep --force --verbose --option runtime --entitlements entitlements.plist --timestamp ./pkg/Applications/${APPINSTALLDIR}/Emacs.app

# Check the signature
RESULT=`pkgutil --check-signature ./pkg/Applications/${APPINSTALLDIR}/Emacs.app | grep "no sign"`
if [ "${RESULT}" ]; then
    exit 1
fi

# Edit packages.plist
cd ${WORKING_DIR}/notarize/pkg
pkgbuild --analyze --root Applications packages.plist

echo "---------------------------------"
echo "Make BundleIsRelocatable false"
echo "---------------------------------"
plutil -replace 'BundleIsRelocatable' -bool false packages.plist

# Create pkg file
pkgbuild Emacs.pkg --root Applications --component-plist packages.plist --identifier com.takaxp.emacs --version ${PKGVERSION} --install-location "/Applications"

# Edit Distribution.xml
productbuild --synthesize --package Emacs.pkg Distribution.xml

XMLSTARLET=`which xmlstarlet`
if [ ! ${XMLSTARLET} ]; then
    echo "xmlstarlet shall be instaled."
    exit 1
fi

echo "---------------------------------"
echo "Add title and allowed-os-versions"
echo "---------------------------------"
${XMLSTARLET} ed -a '/installer-gui-script/choice[@id="com.takaxp.emacs"]' -t 'elem' -n 'title' -v 'GNU Emacs (NS with inline-patch)' \
-a '/installer-gui-script/title' -t 'elem' -n 'allowed-os-versions' \
-s '/installer-gui-script/allowed-os-versions' -t 'elem' -n 'os-version' \
-a '/installer-gui-script/allowed-os-versions/os-version' -t 'attr' -n 'min' -v '10.15' Distribution.xml > edited.xml
mv edited.xml Distribution.xml

# Create Emacs-Distribution.pkg
productbuild --distribution Distribution.xml --package-path Emacs.pkg Emacs-Distribution.pkg

# Productsign
DEVELOPERID='Developer ID Installer: Takaaki Ishikawa (H2PH8KNN3H)'
productsign --sign "${DEVELOPERID}" Emacs-Distribution.pkg Emacs-Distribution_SIGNED.pkg

# Check the signature
RESULT=`pkgutil --check-signature Emacs-Distribution_SIGNED.pkg | grep "no sign"`
if [ "${RESULT}" ]; then
    exit 1
fi

# Uploading the pkg to apple server
xcrun notarytool submit "Emacs-Distribution_SIGNED.pkg" --keychain-profile "${PROFILE_NAME}" --wait
rm -f Emacs.pkg Emacs-Distribution.pkg

sleep 2

cd ${WORKING_DIR}/notarize/pkg
xcrun stapler staple Emacs-Distribution_SIGNED.pkg
CPUARC=`uname -m`
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
NATIVEAP=`${APPDIR}/Emacs.app/Contents/MacOS/Emacs -Q --batch --eval="(princ (when (fboundp 'native-comp-available-p) (native-comp-available-p)))"`
if [ "${NATIVEAP}" == "t" ]; then
    NATIVEAP=true
    if [ ! -f ${HOMEBREWDIR}/opt/libgccjit/include/libgccjit.h ]; then
        NATIVEAP=false
    fi
else
    NATIVEAP=false
fi
[ "${NATIVEAP}" = "true" ] && NATIVE="_nc"

mv Emacs-Distribution_SIGNED.pkg ${FILENAME}${VENDER}${PURE}${NATIVE}.pkg
rm -f ${FILENAME}${VENDER}${PURE}${NATIVE}.md5
md5 ${FILENAME}${VENDER}${PURE}${NATIVE}.pkg > ${FILENAME}${VENDER}${PURE}${NATIVE}.md5

echo "--- ${FILENAME}${VENDER}${PURE}${NATIVE}.pkg and md5 are generaed"

cp -f *.pkg ${WORKING_DIR}
cp -f *.md5 ${WORKING_DIR}

echo "--- done"
