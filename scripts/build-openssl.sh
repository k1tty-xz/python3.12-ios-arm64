#!/usr/bin/env bash
set -euxo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/common-env.sh"

cd "$DEPS"

git clone --depth 1 --branch "${OPENSSL_BRANCH}" https://github.com/openssl/openssl.git "openssl-${OPENSSL_BRANCH}"
cd "openssl-${OPENSSL_BRANCH}"
export CROSS_TOP="$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer"
export CROSS_SDK="$(basename "${IOS_SDK}")"
./Configure ios64-cross no-tests no-shared --prefix=/usr/local
make -j"${JOBS}"
make install_sw DESTDIR="$DEPS/openssl-ios"

