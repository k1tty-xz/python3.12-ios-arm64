#!/usr/bin/env bash
# ---------------------------------------------
# Build OpenSSL (1.1.1 stable branch) for iOS arm64, static
# ---------------------------------------------
# Requires: OPENSSL_BRANCH; common-env.sh sets toolchain vars
set -euxo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/common-env.sh"

# Skip if output already exists (supports cache restore)
if [ -f "$DEPS/openssl-ios/usr/local/lib/libcrypto.a" ] && [ -f "$DEPS/openssl-ios/usr/local/lib/libssl.a" ]; then
  echo "OpenSSL already built, skipping"
  exit 0
fi

cd "$DEPS"

# Clone exact branch depth-1 for deterministic builds (with retries)
if [ ! -d "openssl-${OPENSSL_BRANCH}" ]; then
  for i in 1 2 3 4 5; do
    git clone --depth 1 --single-branch --branch "${OPENSSL_BRANCH}" \
      https://github.com/openssl/openssl.git "openssl-${OPENSSL_BRANCH}" && break || {
      echo "git clone failed (attempt $i)" >&2; sleep 3;
    }
  done
fi
[ -d "openssl-${OPENSSL_BRANCH}" ] || { echo "OpenSSL clone failed after retries" >&2; exit 1; }
cd "openssl-${OPENSSL_BRANCH}"

# Configure + build static
export CROSS_TOP="$(xcrun --sdk iphoneos --show-sdk-platform-path)/Developer"
export CROSS_SDK="$(basename "${IOS_SDK}")"
./Configure ios64-cross no-tests no-shared no-apps --prefix=/usr/local
make -j"${JOBS}"
make install_sw DESTDIR="$DEPS/openssl-ios"

# Cleanup source tree to save disk
cd "$DEPS"
rm -rf "openssl-${OPENSSL_BRANCH}"
