#!/usr/bin/env bash
# ---------------------------------------------
# Install Homebrew tools required by the CI build
# ---------------------------------------------
# Expected environment: macOS runner with Homebrew available
set -euxo pipefail

brew update
brew install dpkg ldid autoconf automake libtool pkg-config coreutils gnu-sed cmake nasm yasm git wget
