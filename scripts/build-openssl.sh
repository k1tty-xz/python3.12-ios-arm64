#!/usr/bin/env bash
# ==============================================================================
# Script: build-openssl.sh
# Purpose: Build OpenSSL (1.1.1w static) for iOS arm64.
# Requires: OPENSSL_VER (defined locally)
# ==============================================================================

set -euxo pipefail

# Load common environment variables and toolchain settings
# shellcheck disable=SC1091
source "$(dirname "$0")/common-env.sh"

# ------------------------------------------------------------------------------
# Check for Existing Build
# ------------------------------------------------------------------------------
# If the static libraries already exist, skip the build.
if [ -f "$DEPS/openssl-ios/usr/local/lib/libcrypto.a" ] && [ -f "$DEPS/openssl-ios/usr/local/lib/libssl.a" ]; then
  echo "Info: OpenSSL already built. Skipping..."
  exit 0
fi

cd "$DEPS"

# ------------------------------------------------------------------------------
# Download Source
# ------------------------------------------------------------------------------
# Use a pinned version (1.1.1w) for stability and reproducibility.
OPENSSL_VER="1.1.1w"
OPENSSL_TAR="openssl-${OPENSSL_VER}.tar.gz"

# Download with retries
if [ ! -d "openssl-${OPENSSL_VER}" ]; then
  for i in 1 2 3 4 5; do
    curl --fail --location --show-error -LO \
      "https://www.openssl.org/source/${OPENSSL_TAR}" && break || {
      echo "Error: Download failed (attempt $i). Retrying in 3s..." >&2
      sleep 3
    }
  done
  # Verify download
  [ -f "${OPENSSL_TAR}" ] || { echo "Error: OpenSSL tarball missing." >&2; exit 1; }
  
  # Extract source
  tar xf "${OPENSSL_TAR}"
fi

cd "openssl-${OPENSSL_VER}"

# ------------------------------------------------------------------------------
# Configure and Build
# ------------------------------------------------------------------------------
# Set up cross-compilation environment variables for OpenSSL's build system.
export CROSS_TOP="$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer"
export CROSS_SDK="$(basename "${IOS_SDK}")"

# Configure for iOS 64-bit, static only, no extra tools/tests
./Configure ios64-cross no-tests no-shared --prefix=/usr/local

# Compile
make -j"${JOBS}"

# Install software (libraries and headers) to staging directory
make install_sw DESTDIR="$DEPS/openssl-ios"

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
# Remove source directory and tarball.
cd "$DEPS"
rm -rf "openssl-${OPENSSL_VER}" "${OPENSSL_TAR}"
