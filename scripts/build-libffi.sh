#!/usr/bin/env bash
set -euxo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/common-env.sh"

cd "$DEPS"

curl -LO "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VER}/libffi-${LIBFFI_VER}.tar.gz"
tar xf "libffi-${LIBFFI_VER}.tar.gz"
cd "libffi-${LIBFFI_VER}"
./configure --host="${HOST_TRIPLE}" --prefix=/usr/local --disable-shared --enable-static \
  CC="${CC} -arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${MIN_IOS}" \
  CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}"
make -j"${JOBS}"
make install DESTDIR="$DEPS/libffi-ios"

