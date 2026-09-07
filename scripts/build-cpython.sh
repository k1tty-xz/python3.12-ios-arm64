#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_VERSION")"
EXPECTED_SHA256="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_SHA256")"
BUILD_ROOT="$(mktemp -d "${RUNNER_TEMP:-/tmp}/python-ios.XXXXXX")"
SOURCE_ARCHIVE="$BUILD_ROOT/Python-${VERSION}.tar.xz"
SOURCE_URL="https://www.python.org/ftp/python/${VERSION}/Python-${VERSION}.tar.xz"
SOURCE_DIR="$BUILD_ROOT/Python-${VERSION}"
ARM64_BUILD="$BUILD_ROOT/cross-build-arm64"
ARM64E_BUILD="$BUILD_ROOT/cross-build-arm64e"
CACHE_DIR="${RUNNER_TEMP:-/tmp}/python-ios-cache"

mkdir -p "$CACHE_DIR"

echo "Build root: $BUILD_ROOT"
echo "CPython: $VERSION"
echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "iPhoneOS SDK: $(xcrun --sdk iphoneos --show-sdk-path)"

curl -fL --retry 5 --retry-all-errors -o "$SOURCE_ARCHIVE" "$SOURCE_URL"
printf '%s  %s\n' "$EXPECTED_SHA256" "$SOURCE_ARCHIVE" | shasum -a 256 -c -
tar -xf "$SOURCE_ARCHIVE" -C "$BUILD_ROOT"

run_apple() {
    CPYTHON_SOURCE_DIR="$SOURCE_DIR" \
        python3 "$ROOT_DIR/scripts/cpython-apple.py" "$@"
}

run_apple_clean_env() {
    env -u CC -u CXX -u CPP -u CFLAGS -u CPPFLAGS -u LDFLAGS \
        CPYTHON_SOURCE_DIR="$SOURCE_DIR" \
        python3 "$ROOT_DIR/scripts/cpython-apple.py" "$@"
}

echo "=== official arm64 build and simulator test ==="
run_apple build iOS all --clean \
    --cross-build-dir "$ARM64_BUILD" \
    --cache-dir "$CACHE_DIR"
run_apple test iOS arm64-apple-ios14.8-simulator \
    --fast-ci \
    --cross-build-dir "$ARM64_BUILD"

echo "=== arm64e build ==="
# The build Python runs on the macOS runner and must remain a native macOS
# binary. Only the target build gets the arm64e compiler wrappers.
run_apple_clean_env build iOS build --clean \
    --cross-build-dir "$ARM64E_BUILD" \
    --cache-dir "$CACHE_DIR"

export IOS_SDK_VERSION=""
export IPHONEOS_DEPLOYMENT_TARGET="14.8"
export CC="$ROOT_DIR/scripts/arm64e-clang.sh"
export CXX="$ROOT_DIR/scripts/arm64e-clang++.sh"
export CPP="$ROOT_DIR/scripts/arm64e-cpp.sh"
export CFLAGS="-arch arm64e"
export CPPFLAGS="-arch arm64e"
export LDFLAGS="-arch arm64e"

run_apple build iOS arm64-apple-ios14.8 --clean \
    --cross-build-dir "$ARM64E_BUILD" \
    --cache-dir "$CACHE_DIR"

echo "=== rootful package ==="
"$ROOT_DIR/scripts/package-rootful.sh" \
    "$ARM64_BUILD" \
    "$ARM64E_BUILD" \
    "$ARM64E_BUILD/build/python" \
    "$ROOT_DIR/dist"

echo "=== final artifact verification ==="
"$ROOT_DIR/scripts/verify-artifact.sh" "$ROOT_DIR/dist"

echo "Artifacts:"
find "$ROOT_DIR/dist" -maxdepth 2 -type f -print
