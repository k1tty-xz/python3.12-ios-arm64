#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 CACHE_DIR BUILD_ROOT" >&2
    exit 2
fi

CACHE_DIR="$1"
BUILD_ROOT="$2"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_COMMIT="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_APPLE_DEPS_COMMIT")"
DEPS_DIR="$BUILD_ROOT/cpython-apple-source-deps"

echo "=== build arm64e Apple dependencies ==="
git clone --quiet https://github.com/beeware/cpython-apple-source-deps.git "$DEPS_DIR"
test "$(git -C "$DEPS_DIR" rev-parse HEAD)" = "$DEPS_COMMIT"

make -C "$DEPS_DIR" -j3 iOS \
    TARGETS-iOS=iphoneos.arm64 \
    BUILD_NUMBER=arm64e \
    BZIP2_VERSION=1.0.8 \
    XZ_VERSION=5.6.4 \
    OPENSSL_VERSION=3.5.7 \
    MPDECIMAL_VERSION=4.0.0 \
    ZSTD_VERSION=1.5.7 \
    LIBFFI_VERSION=3.4.7 \
    CFLAGS-iOS="-mios-version-min=14.8 -arch arm64e"

mkdir -p "$CACHE_DIR"
declare -a PRODUCTS=(
    "bzip2-1.0.8-arm64e-iphoneos.arm64.tar.gz:bzip2-1.0.8-2-iphoneos.arm64.tar.gz"
    "libffi-3.4.7-arm64e-iphoneos.arm64.tar.gz:libffi-3.4.7-2-iphoneos.arm64.tar.gz"
    "openssl-3.5.7-arm64e-iphoneos.arm64.tar.gz:openssl-3.5.7-1-iphoneos.arm64.tar.gz"
    "xz-5.6.4-arm64e-iphoneos.arm64.tar.gz:xz-5.6.4-2-iphoneos.arm64.tar.gz"
    "mpdecimal-4.0.0-arm64e-iphoneos.arm64.tar.gz:mpdecimal-4.0.0-2-iphoneos.arm64.tar.gz"
    "zstd-1.5.7-arm64e-iphoneos.arm64.tar.gz:zstd-1.5.7-1-iphoneos.arm64.tar.gz"
)

VERIFY_DIR="$BUILD_ROOT/arm64e-deps-verify"
mkdir -p "$VERIFY_DIR"
for product in "${PRODUCTS[@]}"; do
    source_archive="${product%%:*}"
    cache_archive="${product##*:}"
    source_path="$DEPS_DIR/dist/$source_archive"
    test -f "$source_path"
    cp "$source_path" "$CACHE_DIR/$cache_archive"

    product_dir="$VERIFY_DIR/${cache_archive%.tar.gz}"
    mkdir -p "$product_dir"
    tar -xzf "$CACHE_DIR/$cache_archive" -C "$product_dir"
    while IFS= read -r -d '' library; do
        lipo -archs "$library" | tr ' ' '\n' | grep -Fxq arm64e
    done < <(find "$product_dir/lib" -type f -name '*.a' -print0)
done

echo "arm64e dependency archives ready in $CACHE_DIR"
