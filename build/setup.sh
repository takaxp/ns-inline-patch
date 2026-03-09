#!/bin/sh

function setup_homebrew () {
    # /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

    if [ $(uname -m) = "arm64" ]; then
        (echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ${HOME}/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        (echo 'eval "$(/usr/local/bin/brew shellenv)"') >> ${HOME}/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    echo "--- Installed."
    echo "PREFIX:     $HOMEBREW_PREFIX"
    echo "CELLAR:     $HOMEBREW_CELLAR"
    echo "REPOSITORY: $HOMEBREW_REPOSITORY"
    echo "PATH:       $PATH"
    echo "MANPATH:    $MANPATH"
    echo "INFOPATH:   $INFOPATH"
}

function install_deps () {
    brew install autoconf automake pkg-config gnutls texinfo jansson
    # Required to support NativeComp and tree-sitter
    brew install gcc libgccjit tree-sitter

    if [ $(uname -m) = "x86_64" ]; then
        echo "--- Hot fix for libgccjit 14.1 on x86_64"
        cd /usr/local/opt/libgccjit/lib/gcc/current
        ln -s /usr/local/lib/gcc/current/libgcc_s.1.1.dylib .
    fi
}

function install_tool () {
    brew install xmlstarlet
}

function install_xcode () {
    xcode-select --install
}

function remove_homebrew () {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall.sh)"
}

function print_gcc_env () {
    BREW=$(which brew)
    BREW_PREFIX=$($BREW --prefix)
    BREW_LIBGCCJIT_PREFIX=$($BREW --prefix --installed libgccjit 2>/dev/null)
    BREW_GCC_MAJOR=$(brew list --version gcc | sed -E 's/.* ([0-9]+)\..*/\1/')
    if [ -f ${BREW_PREFIX}/bin/gcc-${BREW_GCC_MAJOR} ]; then
       BREW_GCC_TRIPLET=$(${BREW_PREFIX}/bin/gcc-${BREW_GCC_MAJOR} -dumpmachine)
    else
        echo "Terminated!"
        echo "--- ${BREW_PREFIX}/bin/gcc-${BREW_GCC_MAJOR} is not installed"
        echo "install Homebrew, then run \"brew install gcc libgccjit.\""
        exit
    fi
    echo "--- GCC ENV"
    echo "BREW:                  ${BREW}"
    echo "BREW_LIBGCCJIT_PREFIX: ${BREW_LIBGCCJIT_PREFIX}"
    echo "BREW_GCC_MAJOR:        ${BREW_GCC_MAJOR}"
    echo "BREW_GCC_TRIPLET:      ${BREW_GCC_TRIPLET}"
}

setup_homebrew
install_tool
install_deps
print_gcc_env
echo "--- SDK PATH"
xcrun --show-sdk-path
# install_xcode
# remove_homebrew

echo "----------------"
echo "OK, let's start to build GNU Emacs with inline-patch."
echo "Usage:"
echo "  sh emacs-****.sh"
echo "Or you can install Emacs by runing pkg file located"
echo "      in https://github.com/takaxp/ns-inline-patch."
echo "----------------"
