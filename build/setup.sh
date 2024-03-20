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
    echo $HOMEBREW_PREFIX
    echo $HOMEBREW_CELLAR
    echo $HOMEBREW_REPOSITORY
    echo $PATH
    echo $MANPATH
    echo $INFOPATH
}
function install_deps () {
    brew install autoconf automake pkg-config gnutls texinfo jansson
    # Required to install for Native Comp
    brew install gcc libgccjit
}

function install_tool () {
    brew install xmlstarlet
}

function install_xcode () {
    xcode-select --install
}

setup_homebrew
install_tool
install_deps
# install_xcode

echo "----------------"
echo "OK, let's start to build GNU Emacs with inline-patch."
echo "Usage:"
echo "  sh emacs-****.sh"
echo "Or you can install Emacs by runing pkg file located"
echo "      in https://github.com/takaxp/ns-inline-patch."
echo "----------------"
