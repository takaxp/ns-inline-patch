#!/bin/sh

function setup_homebrew () {
    # /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
}

function install_deps () {
    brew install autoconf automake pkg-config gnutls texinfo jansson
    brew install gcc libgccjit
}

function install_tool () {
    brew install xmlstarlet
}
function install_xcode () {
    xcode-select --install
}

# install_xcode
setup_homebrew
install_tool
install_deps

echo "----------------"
echo "OK, let's start to build GNU Emacs with inline-patch."
echo "Usage:"
echo "  sh emacs-****.sh"
echo "Or you can install Emacs by runing pkg file located"
echo "      in https://github.com/takaxp/ns-inline-patch."
echo "----------------"
ls
