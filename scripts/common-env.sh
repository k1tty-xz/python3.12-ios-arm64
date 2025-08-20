#!/usr/bin/env bash
# ---------------------------------------------
# Common environment for iOS (arm64) build
# ---------------------------------------------
# Expected inputs from caller (workflow):
# - MIN_IOS (e.g., 12.0)
# - OPENSSL_BRANCH (e.g., OpenSSL_1_1_1-stable)
# - LIBFFI_VER (e.g., 3.4.4)
# - PY_VER (e.g., 3.12.5)
set -euo pipefail

# ---------------------------------------------
# Parallel jobs
# ---------------------------------------------
JOBS="$(sysctl -n hw.ncpu)"

# ---------------------------------------------
# Working directories
# ---------------------------------------------
WORKDIR="${WORKDIR:-$PWD/work}"
DEPS="$WORKDIR/deps"
BUILD="$WORKDIR/build"
STAGE="$WORKDIR/stage"
mkdir -p "$DEPS" "$BUILD" "$STAGE"

# ---------------------------------------------
# Xcode toolchain / target (shell variables, not exported)
# ---------------------------------------------
IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CC="$(xcrun --sdk iphoneos -f clang)"
CXX="$(xcrun --sdk iphoneos -f clang++)"
AR="$(xcrun --sdk iphoneos -f ar)"
RANLIB="$(xcrun --sdk iphoneos -f ranlib)"
STRIP="$(xcrun --sdk iphoneos -f strip)"
HOST_TRIPLE="aarch64-apple-darwin"

# ---------------------------------------------
# Base flags for cross-compiling to iOS arm64
# ---------------------------------------------
export CFLAGS="-arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${MIN_IOS} -fPIC"
export LDFLAGS="-arch arm64 -isysroot ${IOS_SDK} -miphoneos-version-min=${MIN_IOS}"

# ---------------------------------------------
# Export essential variables for child scripts
# ---------------------------------------------
export JOBS WORKDIR DEPS BUILD STAGE IOS_SDK HOST_TRIPLE
