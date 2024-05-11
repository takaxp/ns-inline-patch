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
    echo "PATH:     $PATH"
    echo "MANPATH:  $MANPATH"
    echo "INFOPATH: $INFOPATH"
}

function install_deps () {
    brew install autoconf automake pkg-config gnutls texinfo jansson
    # Required to support NativeComp
    brew install gcc libgccjit

    echo "------------------------------------"
    echo "$(uname -m)"
    if [ $(uname -m) = "x86_64" ]; then
        echo "--- Hot fix for libgccjit 14.1 on x86_64"
        cd /usr/local/opt/libgccjit/lib/gcc/current
        ln -s /usr/local/lib/gcc/current/libgcc_s.1.1.dylib .
    fi
    echo "------------------------------------"
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

setup_homebrew
install_tool
install_deps
# install_xcode
# remove_homebrew

echo "----------------"
echo "OK, let's start to build GNU Emacs with inline-patch."
echo "Usage:"
echo "  sh emacs-****.sh"
echo "Or you can install Emacs by runing pkg file located"
echo "      in https://github.com/takaxp/ns-inline-patch."
echo "----------------"
