#!/usr/bin/env bash
# ==============================================================================
# Script: build-libffi.sh
# Purpose: Build libffi (static library) for iOS arm64.
# Requires: LIBFFI_VER (set in environment or common-env.sh)
# ==============================================================================

set -euxo pipefail

# Load common environment variables and toolchain settings
# shellcheck disable=SC1091
source "$(dirname "$0")/common-env.sh"

# ------------------------------------------------------------------------------
# Check for Existing Build
# ------------------------------------------------------------------------------
# If the static library already exists, skip the build to save time.
if [ -f "$DEPS/libffi-ios/usr/local/lib/libffi.a" ]; then
  echo "Info: libffi already built. Skipping..."
  exit 0
fi

cd "$DEPS"

# ------------------------------------------------------------------------------
# Download Source
# ------------------------------------------------------------------------------
# Download the libffi source tarball with retries to handle network flakiness.
for i in 1 2 3 4 5; do
  curl --fail --location --show-error -LO \
    "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VER}/libffi-${LIBFFI_VER}.tar.gz" && break || {
    echo "Error: Download failed (attempt $i). Retrying in 3s..." >&2
    sleep 3
  }
done

# Verify the download was successful
[ -f "libffi-${LIBFFI_VER}.tar.gz" ] || { echo "Error: libffi tarball missing." >&2; exit 1; }

# Extract source
tar xf "libffi-${LIBFFI_VER}.tar.gz"
cd "libffi-${LIBFFI_VER}"

# ------------------------------------------------------------------------------
# Configure and Build
# ------------------------------------------------------------------------------
# Configure for iOS arm64 cross-compilation.
# CFLAGS/LDFLAGS/CC are picked up from the environment (exported by common-env.sh).
./configure \
  --host="${HOST_TRIPLE}" \
  --prefix=/usr/local \
  --disable-shared \
  --enable-static

# Compile using the number of available CPU cores
make -j"${JOBS}"

# Install to the dependency staging directory
make install DESTDIR="$DEPS/libffi-ios"

# ------------------------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------------------------
# Remove source directory and tarball to free up disk space.
cd "$DEPS"
rm -rf "libffi-${LIBFFI_VER}" "libffi-${LIBFFI_VER}.tar.gz"
