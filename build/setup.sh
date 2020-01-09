#!/bin/sh

function setup_homebrew () {
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

function install_deps () {
    brew install autoconf automake pkg-config gnutls texinfo
}

function install_xcode () {
    xcode-select --install
}

# install_xcode
setup_homebrew
install_deps

echo "----------------"
echo "OK, let's start to build GNU Emacs with inline-patch."
echo "Usage:"
echo "  sh emacs-****.sh"
echo "----------------"
ls
