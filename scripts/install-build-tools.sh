#!/usr/bin/env bash
set -euxo pipefail

brew update
brew install dpkg ldid autoconf automake libtool pkg-config coreutils gnu-sed cmake nasm yasm git wget

