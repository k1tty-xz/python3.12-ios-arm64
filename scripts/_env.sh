#!/usr/bin/env bash
# Common build environment for iOS (arm64) Python build
# This file defines defaults and helper variables used by build scripts.

set -euo pipefail

# ---- Configurable versions (can be overridden via environment) ----
export PY_VER="${PY_VER:-3.12.5}"
export LIBFFI_VER="${LIBFFI_VER:-3.4.4}"
export MIN_IOS="${MIN_IOS:-12.0}"
export OPENSSL_BRANCH="${OPENSSL_BRANCH:-OpenSSL_1_1_1-stable}"

# Python used for host build (provided by workflow). Optional.
export PYTHON_FOR_BUILD="${PYTHON_FOR_BUILD:-}"

# ---- Directories ----
export WORKDIR="${WORKDIR:-$PWD/work}"
export DEPS="$WORKDIR/deps"
export BUILD="$WORKDIR/build"
export STAGE="$WORKDIR/stage"
export PKGROOT="$WORKDIR/pkgroot"
mkdir -p "$DEPS" "$BUILD" "$STAGE"

# ---- Toolchain / SDK ----
export JOBS="${JOBS:-$(sysctl -n hw.ncpu || echo 4)}"
export IOS_SDK="${IOS_SDK:-$(xcrun --sdk iphoneos --show-sdk-path)}"
export CC="${CC:-$(xcrun --sdk iphoneos -f clang)}"
export CXX="${CXX:-$(xcrun --sdk iphoneos -f clang++)}"
export AR="${AR:-$(xcrun --sdk iphoneos -f ar)}"
export RANLIB="${RANLIB:-$(xcrun --sdk iphoneos -f ranlib)}"
export STRIP="${STRIP:-$(xcrun --sdk iphoneos -f strip)}"
export HOST_TRIPLE="${HOST_TRIPLE:-aarch64-apple-darwin}"

# Base flags for arm64 iOS
export CFLAGS="-arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${MIN_IOS} -fPIC ${CFLAGS:-}"
export LDFLAGS="-arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${MIN_IOS} ${LDFLAGS:-}"

# Helper: ensure gsed exists in PATH (brew installs it as 'gsed')
command -v gsed >/dev/null 2>&1 || true

# Helper function to sign Mach-O files if ldid is available
sign_macho_tree() {
  local root_dir="$1"
  if ! command -v ldid >/dev/null 2>&1; then
    echo "ldid not found; skipping code signing" >&2
    return 0
  fi
  while IFS= read -r -d '' f; do
    if file -b "$f" | grep -q 'Mach-O'; then
      ldid -S "$f" || echo "ldid warning on $f" >&2
    fi
  done < <(find "$root_dir" -type f \( -name "*.dylib" -o -name "*.so" -o -path "$root_dir/usr/local/bin/*" \) -print0)
}

