#!/bin/bash

# before starting build for release, do as follow:
# brew uninstall imagemagick@6 webp giflib

# For Apple Silicon, Emacs version 27.2 or later supports to build.
CPUARC=`uname -m`

# LIBXML2
if [ "${SYSTEMTYPE}" = "darwin" ]; then
    MACSDK=`xcrun --show-sdk-path`
    export LIBXML2_CFLAGS="-I${MACSDK}/usr/include/libxml2"
    export LIBXML2_LIBS="-lxml2"
    if [ "${CPUARC}" = "x86_64" ]; then
        # Catalina, Big Sur, Monterey
        export MACOSX_DEPLOYMENT_TARGET=10.15
    else
        # Big Sur, Monterey
        export MACOSX_DEPLOYMENT_TARGET=11.0
    fi
fi

# Native compilation
if [ "${CPUARC}" = "arm64" ]; then
    BREW=`which brew`
    BREW_LIBGCCJIT_PREFIX=`$BREW --prefix --installed libgccjit 2>/dev/null`
    export CFLAGS="$CFLAGS -I${BREW_LIBGCCJIT_PREFIX}/include"
fi

WORKDIR="${HOME}/devel/emacs-head"
INSTALLDIR="${HOME}/.local"
PATCHMODE="private" # pure, inline, private
PATCHDIR="patch"
DOPTION="--with-modules" # the default option
APPLEIDCODE="Developer ID Application: Takaaki Ishikawa (H2PH8KNN3H)"
PORTABLE="False" # {"True"|"False"}
FULL_AOT="False" # {"True"|"False"}

function print_help () {
    echo "Usage:"
    echo "- build with private patch (nightly):"
    echo "  > build-my-build.sh -b emacs-27"
    echo ""
    echo "- build without inline-patch for publication (major release):"
    echo "  > build-my-build.sh -v 27.2 -p pure"
    echo ""
    echo "- build with inline-patch for publication (major release):"
    echo "  > build-my-build.sh -v 27.2 -p inline"
    echo ""
    echo "- build without inline-patch for publication (nightly):"
    echo "  > build-my-build.sh -b emacs-27 -p pure"
    echo ""
    echo "- build with inline-patch for publication (nightly):"
    echo "  > build-my-build.sh -b emacs-27 -p inline"
    echo ""
    echo "-s : CodeSign"
    echo "-r : Clean up and reset repository directory"
    echo ""
}

function hotfix () {
    patch -p1 < ${WORKDIR}/sources/220806-gcclibjit-hotfix.patch
}

function init_check () {
    if [ ! "$VERSION" -a ! $BRANCH ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "  Please specify VERSION or BRANCH"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo ""
        print_help
        exit;
    fi

    if [ "$VERSION" -a "$BRANCH" ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "  Please select VERSION or BRANCH"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo ""
        print_help
        exit;
    fi
}

function repos_setup () {
    # cd ~/devel/emacs-head/emacs
    # git clean -fd && rm -rf 'lib-src/*.dSYM' && git reset --hard HEAD && git fetch origin

    cd ${WORKDIR}/emacs

    rm -f .gitignore
    git clean -fd
    # rm -f src/macim.h
    # rm -f src/macim.m
    rm -rf lib-src/*.dSYM
    git reset --hard HEAD
    git fetch origin
    if [ ! ${BRANCH} ]; then
        echo "${BRANCH} is empty."
        exit;
    fi
    LOCALBRANCH=`git branch | grep $BRANCH`
    if [ "$LOCALBRANCH" = "" ]; then
        git checkout -b $BRANCH origin/$BRANCH
    else
        git checkout -f $BRANCH
    fi
    git pull origin $BRANCH

    if [ ! "$COMMIT" ]; then
        COMMIT=`git log -n 1 --format=%H`
    fi
    COMMIT=${COMMIT:0:10}
    git reset --hard $COMMIT
}

while getopts sb:c:ho:v:p:j:nrN opt
do
    case ${opt} in
        n)
            NATIVE=true
            ;;
        b)
            BRANCH=${OPTARG}
            ;;
        o)
            OPTIONS=${OPTARG}
            ;;
        p)
            PATCHMODE=${OPTARG}
            ;;
        v)
            VERSION=${OPTARG}
            ;;
        c)
            COMMIT=${OPTARG}
            ;;
        j)
            NUMCORES=${OPTARG}
            ;;
        s)
            CODESIGN=true
            ;;
        N)
            FULL_AOT=True
            ;;
        r)
            init_check
            repos_setup
            exit
            ;;
        h)
            print_help
            exit
            ;;
    esac
done

init_check

function build_setup () {
    cd ${HOME}
    if [ ! -d "${WORKDIR}" ]; then
        mkdir -p ${WORKDIR}
    fi

    if [ ! -d "$WORKDIR/$PATCHDIR" ]; then
        mkdir -p "$WORKDIR/$PATCHDIR"
    fi

    if [ "${SYSTEMTYPE}" = "linux" -a ! -d "${INSTALLDIR}" ]; then
        mkdir -p "$HOME/.local"
    fi

    cd $WORKDIR/$PATCHDIR
    # curl -LO https://gist.githubusercontent.com/takaxp/01ff965361d70de93e9aba3795193cc7/raw/4265d48c13f33a2046669086756c85a2bb83c318/ns-private.patch

    # inline patch (googleime, locale=en)
    # echo "Getting patch emacs-25.2-inline-googleime..."
    # if [ -d emacs-25.2-inline-googleime ]; then
    #     cd emacs-25.2-inline-googleime
    #     git pull
    #     cd ..
    # else
    #     git clone --depth 1 https://gist.github.com/5294b6c52782d0be0b25342be62e4a77.git emacs-25.2-inline-googleime
    # fi

    # inline patch
    echo "Getting patch ns-inline.patch..."
    if [ -d ns-inline-patch ]; then
        cd ns-inline-patch
        git pull
    else
        # git clone git@github.com:takaxp/ns-inline-patch.git
        git clone https://github.com/takaxp/ns-inline-patch.git
    fi

    cd $WORKDIR
    if [ ! -d "emacs" ]; then
        git clone git://git.sv.gnu.org/emacs.git
    fi
}

function release_setup () {
    if [ ! -d "${WORKDIR}/sources" ]; then
        mkdir $WORKDIR/sources
    fi
    cd $WORKDIR/sources
    if [ ! -f emacs-$VERSION.tar.gz ]; then
        curl -LO ftp://ftp.gnu.org/gnu/emacs/emacs-$VERSION.tar.gz
    fi

    cd $WORKDIR
    if [ -d emacs-$VERSION ]; then
        rm -rf emacs-$VERSION
    fi

     if [ -f sources/emacs-$VERSION.tar.gz ]; then
        tar zxvf sources/emacs-$VERSION.tar.gz
        cd ./emacs-$VERSION
    else
        echo "emacs-$VERSION is NOT ready."
        exit
    fi
}

function apply_patch_linux () {
    echo "Applying patch for linux build"
    # if [ "$VERSION" = "25.3" -o "$VERSION" = "25.2" ]; then
    #     patch -p0 < ../$PATCHDIR/linux/fix-emacs25.3-sysdep.c.patch
    # elif [ "$VERSION" = "26.3" -o "$VERSION" = "26.2" -o "$VERSION" = "26.1" ]; then
    #     patch -p0 < ../$PATCHDIR/linux/fix-emacs25.3-sysdep.c.patch
    # elif [ "$VERSION" = "27.2" -o "$VERSION" = "27.1" ]; then
    if [ $VERSION ]; then
        if (( $(echo "$VERSION > 28.0" | bc -l) )); then
            echo "--- do nothing"
        elif (( $(echo "$VERSION < 25.2" | bc -l) )); then
            echo "Emacs $VERSION or eariler is NOT supported."
            exit;
        else
            patch -p0 < ../$PATCHDIR/linux/fix-emacs25.3-sysdep.c.patch
        fi
    fi
}


function apply_patch_pure () {
    echo "Applying no patches. (except hotfix)"
    if [ "$VERSION" = "26.3" -o "$BRANCH" = "emacs-26" ]; then
        # Avoid build error
        patch -p1 < ../$PATCHDIR/ns-inline-patch/fix-emacs26.3-unexmacosx.c.patch

    elif [ "$VERSION" = "27.1" -o "$VERSION" = "27.2" -o "$BRANCH" = "emacs-27" ]; then
        # Avoid flicking when IME ON, these patches integrated to inline patch
        patch -p1 < ../$PATCHDIR/ns-inline-patch/archive/revert-89d0c445.patch
        patch -p1 < ../$PATCHDIR/ns-inline-patch/archive/fix-working-text.patch
        # Note: Portable Dumper was adopted from 27.1.

    elif [ "$VERSION" = "29.2" -o "$BRANCH" = "emacs-29" ]; then
        # Avoid build error
        echo "nothing to do"

    elif [ "$VERSION" = "29.1" -o "$BRANCH" = "emacs-29" ]; then
        # Avoid build error
        echo "nothing to do"

    elif [ "$VERSION" = "28.1" -o "$BRANCH" = "emacs-28" ]; then
        # Avoid build error
        echo "nothing to do"

    elif [ "$VERSION" = "28.2" -o "$BRANCH" = "emacs-28" ]; then
        # Avoid build error
        echo "nothing to do"

    elif [ "$BRANCH" = "master" ]; then
        echo "nothing to do"

    elif [ "$VERSION" = "25.3" -o "$BRANCH" = "emacs-25" ]; then
        echo "nothing to do"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/fix-emacs26.3-unexmacosx.c.patch

    else
        echo "(pure) Unexpected VERSION or BRANCH (${VERSION}|${BRANCH})"
        exit
    fi
}

function apply_patch_inline () {
    if [ "$BRANCH" = "master" ]; then
        echo "Applying for master"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/emacs-head-inline.patch

    elif [ "$BRANCH" = "emacs-29" -o "$VERSION" = "29.1" -o "$VERSION" = "29.2" ]; then
        echo "Applying for emacs-29 or 29.1/29.2"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/emacs-29.1-inline.patch

    elif [ "$BRANCH" = "emacs-28" -o "$VERSION" = "28.2" ]; then
        echo "Applying for emacs-28 or 28.2"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/emacs-28.1-inline.patch

    elif [ "$BRANCH" = "emacs-28" -o "$VERSION" = "28.1" ]; then
        echo "Applying for emacs-28 or 28.1"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/emacs-28.1-inline.patch

    elif [ "$BRANCH" = "emacs-27" -o "$VERSION" = "27.2" ]; then
        echo "Applying for emacs-27"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/emacs-27.1-inline.patch
        # patch -p1 < ../$PATCHDIR/ns-inline-patch/revert-89d0c445.patch
        # patch -p1 < ../$PATCHDIR/ns-inline-patch/fix-working-text.patch

    elif [ "$BRANCH" = "emacs-26" -o "$VERSION" = "26.3" ]; then
        echo "Applying for emacs-26"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/fix-emacs26.3-unexmacosx.c.patch
        # patch -p1 < ../$PATCHDIR/emacs-25.2-inline-googleime/emacs-25.2-inline-googleime.patch
        patch -p1 < ../$PATCHDIR/ns-inline-patch/emacs-25.2-inline.patch

    elif [ "$BRANCH" = "emacs-25" -o "$VERSION" = "25.3" ]; then
        patch -p1 < ../$PATCHDIR/ns-inline-patch/fix-emacs25.3-unexmacosx.c.patch
        patch -p1 < ../$PATCHDIR/ns-inline-patch/emacs-25.2-inline.patch

    else
        echo "(inline) Unexpected VERSION or BRANCH (${VERSION}|${BRANCH})"
        exit
    fi
}

function apply_patch_private () {
    apply_patch_inline
    if [ "$BRANCH" = "master" ]; then
        echo "Applying for master (private)"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/private/ns-head-private.patch

    elif [ "$BRANCH" = "emacs-29" -o "$VERSION" = "29.1" -o "$VERSION" = "29.2" ]; then
        echo "Applying for emacs-29 (private)"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/private/ns-head-private.patch

    elif [ "$BRANCH" = "emacs-28" -o "$VERSION" = "28.2" ]; then
        echo "Applying for emacs-28 (private)"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/private/ns-head-private.patch

    elif [ "$BRANCH" = "emacs-28" -o "$VERSION" = "28.1" ]; then
        echo "Applying for emacs-28 (private)"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/private/ns-head-private.patch

    elif [ "$BRANCH" = "emacs-27" -o "$VERSION" = "27.2" ]; then
        echo "Applying for emacs-27 (private)"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/private/ns-27.0-private.patch

    elif [ "$BRANCH" = "emacs-26" -o "$VERSION" = "26.3" ]; then
        echo "Applying for emacs-26 (private)"
        patch -p1 < ../$PATCHDIR/ns-inline-patch/private/ns-26.2-private.patch

    elif [ "$VERSION" = "25.3" -o "$BRANCH" = "emacs-25" ]; then
        # Avoid build error
        # do nothing
        echo "Applying for emacs-25 (private)"
        echo "emacs-25.2-inline-googleime.patch is broken. Need to be fixed."
        exit
        patch -p1 < ../$PATCHDIR/emacs-25.2-inline-googleime/emacs-25.2-inline-googleime.patch

    else
        echo "(private) Unexpected VERSION or BRANCH (${VERSION}|${BRANCH})"
        exit
    fi
}

build_setup

if [ "${BRANCH}" ]; then
    repos_setup
else
    release_setup
fi

# hotfix

###############################################################################
# exit
# diff -crN --exclude .git emacs/src/nsterm.m ~/Desktop/nsterm.m
###############################################################################

if [ "$SYSTEMTYPE" = "darwin" ]; then
    if [ "$PATCHMODE" = "pure" ]; then
        echo "Applying no patches"
        apply_patch_pure
    elif [ "$PATCHMODE" = "inline" ]; then
        apply_patch_inline
    else # default
        apply_patch_private
    fi
fi

if [ "$SYSTEMTYPE" = "linux" ]; then
    apply_patch_linux
fi

if [ "$PATCHMODE" = "private" ]; then
    if [ ! "$OPTIONS" ]; then
        OPTIONS="--with-jpeg=ifavailable --with-tiff=ifavailable --with-gif=ifavailable --with-png=ifavailable --with-lcms2=ifavailable --with-webp=ifavailable --with-dbus=ifavailable --with-rsvg=ifavailable --with-tree-sitter=no"
    fi
else
    if [ ! "$OPTIONS" ]; then
        OPTIONS="--with-jpeg=no --with-tiff=no --with-gif=no --with-png=no --with-lcms2=no --with-webp=no --with-dbus=no --with-rsvg=no --with-tree-sitter=no"
    fi
fi

if [ "$NATIVE" ]; then
    OPTIONS="${OPTIONS} --with-native-compilation=yes"
    # For portable-emacs.sh
    NATIVE="-n"
fi

if [ ${SYSTEMTYPE} = "linux" ]; then
    if [ "$VERSION" ]; then
        VINST=$INSTALLDIR/emacs-$VERSION
    else
        VINST=$INSTALLDIR
    fi
    mkdir -p ${VINST}
fi
if [ ${SYSTEMTYPE} = "darwin" ]; then
    VINST="./nextstep"
fi

echo "======================================"
if [ "$BRANCH" ]; then
    echo " Ready to build Emacs ${BRANCH} (${COMMIT})"
else
    echo " Ready to build Emacs ${VERSION}"
fi
echo " Directory:            ${PWD}"
echo " Branch:               ${BRANCH}"
echo " Version:              ${VERSION}"
echo " Release (patch) mode: ${PATCHMODE}"
echo " Options:              ${DOPTION} ${OPTIONS}"
echo " AOT:                  ${FULL_AOT}"
echo " INSTALLTO:            ${VINST}"
echo " CPU:                  ${CPUARC}"
echo " (min) OS Version:     ${MACOSX_DEPLOYMENT_TARGET}"
echo "======================================"
# sleep 5
read -p "Proceed?...[Y/n] " options
case $options in
    y)
    ;;
    *)
        echo "--- quit."
        exit;
        ;;
esac

# Unlink
if [ "${SYSTEMTYPE}" = "darwin" ]; then
    brew unlink giflib
fi

# generate Makefile
if [ -f "Makefile" ]; then
    make clean -j1
else
    sh autogen.sh
    if [ "${SYSTEMTYPE}" = "darwin" ]; then
        ./configure --without-x --with-ns $DOPTION $OPTIONS
    else
        ./configure --with-x-toolkit=gtk3 --prefix=${VINST} $DOPTION $OPTIONS
    fi
fi

# build Emacs
if [ ${FULL_AOT} = "True" ]; then
    make bootstrap -j${NUMCORES} NATIVE_FULL_AOT=1
else
    make bootstrap -j${NUMCORES}
fi

if [ "${SYSTEMTYPE}" = "darwin" ]; then
    if [ ${FULL_AOT} = "True" ]; then
        make install -j${NUMCORES} NATIVE_FULL_AOT=1
    else
        make install -j${NUMCORES}
    fi
    cd ${VINST}
    if [ "${CODESIGN}" ]; then
        echo "CodeSigning..."
        codesign --force --deep --sign "${APPLEIDCODE}" Emacs.app
    fi
    open .
else
    make install -j${NUMCORES}
    if [ "${VERSION}" ]; then
        ln -fs ${VINST}/bin/emacs ${INSTALLDIR}/bin
    fi
    echo "--- installed (or linked) as ${INSTALLDIR}/bin/emacs"
fi

# Link
if [ "${SYSTEMTYPE}" = "darwin" ]; then
    brew link giflib
fi

if [ ${COMMIT} ]; then
    echo "Commit: ${COMMIT}"
fi

# make it portable
if [ ${PORTABLE} = "True" ]; then
    if [ ${VERSION} ]; then
        echo "portable-emacs.sh -v ${VERSION} ${NATIVE}"
        portable-emacs.sh -v ${VERSION} ${NATIVE}
    elif [ ${BRANCH} ]; then
        echo "portable-emacs.sh -b ${BRANCH} ${NATIVE}"
        portable-emacs.sh -b ${BRANCH} ${NATIVE}
    else
        echo "no portable"
    fi
else
    echo "--- Not portable."
fi


