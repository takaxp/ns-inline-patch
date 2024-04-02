#!/bin/bash

BREW_DIR=$(brew --prefix)
WORKING_DIR="${HOME}/devel/emacs-head"
GLOBAL_LIB_LIST=()

function lib_in_list () {
    for lib in ${GLOBAL_LIB_LIST[@]}
    do
        [ "$lib" = "$1" ] && return 0
    done

    return 1
}

function colloect_deps_lib () {
    LOCAL_LIB_LIST=()
    count=0
    local _RESULT=$(otool -L $1 | grep ${BREW_DIR})
    if [ ! "$1" = "Emacs" ]; then
        _RESULT=$(echo "$_RESULT" | sed -r "s/.*dylib:(.*)/\1/")
    fi

    _IFS="$IFS"
    IFS=$'\n'
    for lib in ${_RESULT[@]}
    do
        count=$(expr $count + 1)
        if [ ! "$1" = "Emacs" -a "$2" -a $count = 1 ]; then
            continue
        fi
        regexp="^.*${BREW_DIR}/(.*).dylib"
        if [[ $lib =~ $regexp ]]; then
            DYLIB=${BASH_REMATCH[1]}

            if [ "$2" = "copy" ]; then
                lib_in_list $DYLIB
                if [ $? = 0 ]; then
                    continue
                else
                    GLOBAL_LIB_LIST+=("$DYLIB")
                    colloect_deps_lib "${BREW_DIR}/${DYLIB}.dylib" "copy"
                fi
            else
                LOCAL_LIB_LIST+=("$DYLIB")
            fi
        fi
    done
    IFS="$_IFS"

    return 0
}

function verify_lib () {
    echo "-L "$1
    if [ "$1" = "Emacs" ]; then
        RESULT=$(otool -L $1 | grep ${BREW_DIR})
    else
        RESULT=$(otool -L ${EMACS_EXEC_DIR}/lib/$1.dylib | grep ${BREW_DIR})
    fi
    if [ ${#RESULT} -gt 0 ]; then
        STATUS="${STATUS}\n${RESULT}"
    fi

    return 0
}

while getopts v:b:d:h opt
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
        h)
            echo ""
            exit
            ;;
    esac
done

echo "--- Integrate libraries and its dependencies into Emacs.app"

if [ "$VERSION" = "" -a "$BRANCH" = "" ]; then
    echo "Please specify VERSION (-v 27.2) ov BRANCH (-b master)"
    exit 1
fi

if [ ! "${BRANCH}" = "" -a "${VERSION}" = "" ]; then
    APP_DIR="${WORKING_DIR}/emacs/nextstep"
    echo "--- Target branch: ${BRANCH}"
fi

if [ "${BRANCH}" = "" -a ! "${VERSION}" = "" ]; then
    APP_DIR="${WORKING_DIR}/emacs-${VERSION}/nextstep"
    echo "--- Target version: ${VERSION}"
fi

# EMACSVERSION=`${APP_DIR}/Emacs.app/Contents/MacOS/Emacs -Q --batch --eval="(princ emacs-version)"`
NATIVEP=`${APP_DIR}/Emacs.app/Contents/MacOS/Emacs -Q --batch --eval="(princ (when (fboundp 'native-comp-available-p) (native-comp-available-p)))"`

if [ "${NATIVEP}" == "t" ]; then
    NATIVEP=true
    if [ ! -f ${BREW_DIR}/opt/libgccjit/include/libgccjit.h ]; then
        NATIVEP=false
    fi
else
    NATIVEP=false
fi

EMACS_EXEC_DIR="${APP_DIR}/Emacs.app/Contents/MacOS"
if [ ! -d "$EMACS_EXEC_DIR" ]; then
    echo "$EMACS_EXEC_DIR does NOT exist"
    exit 1
fi

cd "$EMACS_EXEC_DIR"
mkdir -p ${EMACS_EXEC_DIR}/lib

echo "--- Copying libraries, and applying modification"
colloect_deps_lib "Emacs" "copy"
for lib in ${GLOBAL_LIB_LIST[@]}
do
    cp -f "${BREW_DIR}/${lib}.dylib" ${EMACS_EXEC_DIR}/lib
    regexp=".+/(.+)"
    if [[ $lib =~ $regexp ]]; then
        # echo "install_name_tool -id "homebrew:$lib.dylib" lib/${BASH_REMATCH[1]}.dylib"
        install_name_tool -id "homebrew:$lib.dylib" lib/${BASH_REMATCH[1]}.dylib > /dev/null 2>&1
    fi
done

echo "--- Linking dependent libraries"
colloect_deps_lib "Emacs"
for deps in ${LOCAL_LIB_LIST[@]}
do
    regexp=".+/(.+)"
    if [[ $deps =~ $regexp ]]; then
        install_name_tool -change ${BREW_DIR}/${deps}.dylib @executable_path/lib/${BASH_REMATCH[1]}.dylib Emacs> /dev/null 2>&1
    fi
done

for lib in ${GLOBAL_LIB_LIST[@]}
do
    regexp=".+/(.+)"
    if [[ $lib =~ $regexp ]]; then
        TARGET_LIB=${BASH_REMATCH[1]}
        # echo ">>> $TARGET_LIB.dylib"

        colloect_deps_lib "lib/$TARGET_LIB.dylib"
        for deps in ${LOCAL_LIB_LIST[@]}
        do
            regexp=".+/(.+)"
            if [[ $deps =~ $regexp ]]; then
                install_name_tool -change "${BREW_DIR}/${deps}.dylib" "@executable_path/lib/${BASH_REMATCH[1]}.dylib" "lib/${TARGET_LIB}.dylib"> /dev/null 2>&1
            fi
        done
    fi
done

chmod 644 ${EMACS_EXEC_DIR}/lib/*.dylib

# Verifying - If ok then nothing will be displayed except the lib names
for lib in ${GLOBAL_LIB_LIST[@]}
do
    regexp=".+/(.+)"
    if [[ $lib =~ $regexp ]]; then
        verify_lib "${BASH_REMATCH[1]}"
    fi
done
verify_lib "Emacs"

# Return false for Github Actions if needed
if [ "${STATUS}" ];then
    echo "--- ${STATUS}"
    exit 1
fi

echo "--- done"
