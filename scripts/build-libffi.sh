#!/usr/bin/env bash
# Build static libffi for iOS arm64
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_env.sh"

cd "$DEPS"
if [ ! -f "libffi-${LIBFFI_VER}.tar.gz" ]; then
  curl -LO "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VER}/libffi-${LIBFFI_VER}.tar.gz"
fi
if [ ! -d "libffi-${LIBFFI_VER}" ]; then
  tar xf "libffi-${LIBFFI_VER}.tar.gz"
fi
cd "libffi-${LIBFFI_VER}"

./configure --host="${HOST_TRIPLE}" --prefix=/usr/local --disable-shared --enable-static \
  CC="${CC} -arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${MIN_IOS}" \
  CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
make -j"${JOBS}"
make install DESTDIR="$DEPS/libffi-ios"

