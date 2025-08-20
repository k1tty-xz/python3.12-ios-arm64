#!/usr/bin/env bash
# ---------------------------------------------
# Install Homebrew tools required by the CI build
# ---------------------------------------------
# Expected environment: macOS runner with Homebrew available
set -euxo pipefail

# Speed up Homebrew operations and avoid upgrading already-installed formulas
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Install only missing formulas to avoid time-consuming upgrades
FORMULAE=(dpkg ldid autoconf automake libtool pkg-config coreutils gnu-sed cmake nasm yasm git wget)
for f in "${FORMULAE[@]}"; do
  if brew list --formula | grep -qx "${f}"; then
    echo "brew formula ${f} already installed; skipping"
  else
    brew install "${f}"
  fi
done
