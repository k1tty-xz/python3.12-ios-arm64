#!/usr/bin/env bash
# ---------------------------------------------
# Build libffi static for iOS arm64
# ---------------------------------------------
# Requires: LIBFFI_VER; common-env.sh sets toolchain vars
set -euxo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/common-env.sh"

# Skip if output already exists (supports cache restore)
if [ -f "$DEPS/libffi-ios/usr/local/lib/libffi.a" ]; then
  echo "libffi already built, skipping"
  exit 0
fi

cd "$DEPS"

# Download with retries
for i in 1 2 3 4 5; do
  curl --fail --location --show-error -LO \
    "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VER}/libffi-${LIBFFI_VER}.tar.gz" && break || {
    echo "curl download failed (attempt $i)" >&2; sleep 3;
  }
done
[ -f "libffi-${LIBFFI_VER}.tar.gz" ] || { echo "libffi tarball missing after retries" >&2; exit 1; }

tar xf "libffi-${LIBFFI_VER}.tar.gz"
cd "libffi-${LIBFFI_VER}"
./configure --host="${HOST_TRIPLE}" --prefix=/usr/local --disable-shared --enable-static \
  CC="${CC} -arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${MIN_IOS}" \
  CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
make -j"${JOBS}"
make install DESTDIR="$DEPS/libffi-ios"

# Cleanup source and tarball to save disk
cd "$DEPS"
rm -rf "libffi-${LIBFFI_VER}" "libffi-${LIBFFI_VER}.tar.gz"
