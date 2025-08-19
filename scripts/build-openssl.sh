#!/usr/bin/env bash
# Build OpenSSL (1.1.1 stable branch by default) for iOS arm64 static
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_env.sh"

cd "$DEPS"
if [ ! -d "openssl-${OPENSSL_BRANCH}" ]; then
  git clone --depth 1 --branch "$OPENSSL_BRANCH" https://github.com/openssl/openssl.git "openssl-${OPENSSL_BRANCH}"
fi
cd "openssl-${OPENSSL_BRANCH}"

export CROSS_TOP="$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer"
export CROSS_SDK="$(basename "${IOS_SDK}")"

./Configure ios64-cross no-tests no-shared --prefix=/usr/local
make -j"${JOBS}"
make install_sw DESTDIR="$DEPS/openssl-ios"

