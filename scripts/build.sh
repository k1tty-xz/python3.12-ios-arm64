#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_VERSION")"
EXPECTED_SHA256="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_SHA256")"
DEPS_COMMIT="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_APPLE_DEPS_COMMIT")"
BUILD_ROOT="$(mktemp -d "${RUNNER_TEMP:-/tmp}/python-ios.XXXXXX")"
SOURCE_ARCHIVE="$BUILD_ROOT/Python-${VERSION}.tar.xz"
SOURCE_DIR="$BUILD_ROOT/Python-${VERSION}"
ARM64_BUILD="$SOURCE_DIR/cross-build-arm64"
ARM64E_BUILD="$SOURCE_DIR/cross-build-arm64e"
ARM64_CACHE="${RUNNER_TEMP:-/tmp}/python-ios-cache"
ARM64E_CACHE="${RUNNER_TEMP:-/tmp}/python-ios-cache-arm64e"
OUTPUT_DIR="${RUNNER_TEMP:-/tmp}/python-ios-dist"
TARGET="arm64-apple-ios14.8"
PRODUCT_REL="$TARGET/Apple/iOS/Frameworks/arm64-iphoneos"

mkdir -p "$ARM64_CACHE" "$ARM64E_CACHE" "$OUTPUT_DIR"

echo "Build root: $BUILD_ROOT"
echo "CPython: $VERSION"
echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "iPhoneOS SDK: $(xcrun --sdk iphoneos --show-sdk-path)"

curl -fL --retry 5 --retry-all-errors \
    -o "$SOURCE_ARCHIVE" \
    "https://www.python.org/ftp/python/${VERSION}/Python-${VERSION}.tar.xz"
printf '%s  %s\n' "$EXPECTED_SHA256" "$SOURCE_ARCHIVE" | shasum -a 256 -c -
tar -xf "$SOURCE_ARCHIVE" -C "$BUILD_ROOT"

# This is CPython's tagged Apple builder. Upstream names the physical iOS
# slice arm64; the only local customization is the documented host-triple
# deployment-target suffix and the arm64e device slice needed by this package.
run_apple() {
    local -a command=(python3 -)
    if [[ "${1:-}" == "--clean-env" ]]; then
        shift
        command=(env -u CC -u CXX -u CPP -u CFLAGS -u CPPFLAGS -u LDFLAGS python3 -)
    fi

    CPYTHON_SOURCE_DIR="$SOURCE_DIR" "${command[@]}" "$@" <<'PY'
from __future__ import annotations

import importlib.util
import os
from pathlib import Path

source_dir = Path(os.environ["CPYTHON_SOURCE_DIR"]).resolve()
apple_main = source_dir / "Apple" / "__main__.py"
spec = importlib.util.spec_from_file_location("cpython_apple_build", apple_main)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load CPython Apple builder: {apple_main}")

builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
builder.HOSTS["iOS"] = {
    "ios-arm64": {
        "arm64-apple-ios14.8": "arm64-iphoneos",
    },
}
os.chdir(source_dir)
builder.main()
PY
}

build_arm64e_dependencies() {
    local deps_dir="$BUILD_ROOT/cpython-apple-source-deps"
    local sdk_root
    local target_flags
    local verify_dir="$BUILD_ROOT/arm64e-deps-verify"

    echo "=== build arm64e Apple dependencies ==="
    git clone --quiet https://github.com/beeware/cpython-apple-source-deps.git "$deps_dir"
    test "$(git -C "$deps_dir" rev-parse HEAD)" = "$DEPS_COMMIT"

    sdk_root="$(xcrun --sdk iphoneos --show-sdk-path)"
    target_flags="-target arm64-apple-ios14.8 --sysroot=$sdk_root -mios-version-min=14.8 -arch arm64e"
    # The pinned dependency Makefile invokes libffi's recursive make without
    # forwarding its target-specific variables. Export these flags and let
    # the recursive make inherit them so libffi cannot fall back to arm64.
    export CFLAGS="$target_flags"
    export CXXFLAGS="$target_flags"
    export LDFLAGS="$target_flags"
    make -C "$deps_dir" -j3 iOS \
        TARGETS-iOS=iphoneos.arm64 \
        BUILD_NUMBER=arm64e \
        BZIP2_VERSION=1.0.8 \
        XZ_VERSION=5.6.4 \
        OPENSSL_VERSION=3.5.7 \
        MPDECIMAL_VERSION=4.0.0 \
        ZSTD_VERSION=1.5.7 \
        LIBFFI_VERSION=3.4.7 \
        CFLAGS="$target_flags" \
        CXXFLAGS="$target_flags" \
        LDFLAGS="$target_flags" \
        CFLAGS-iOS="-mios-version-min=14.8 -arch arm64e" \
        MAKEFLAGS=-e

    declare -a products=(
        "bzip2-1.0.8-arm64e-iphoneos.arm64.tar.gz:bzip2-1.0.8-2-iphoneos.arm64.tar.gz"
        "libffi-3.4.7-arm64e-iphoneos.arm64.tar.gz:libffi-3.4.7-2-iphoneos.arm64.tar.gz"
        "openssl-3.5.7-arm64e-iphoneos.arm64.tar.gz:openssl-3.5.7-1-iphoneos.arm64.tar.gz"
        "xz-5.6.4-arm64e-iphoneos.arm64.tar.gz:xz-5.6.4-2-iphoneos.arm64.tar.gz"
        "mpdecimal-4.0.0-arm64e-iphoneos.arm64.tar.gz:mpdecimal-4.0.0-2-iphoneos.arm64.tar.gz"
        "zstd-1.5.7-arm64e-iphoneos.arm64.tar.gz:zstd-1.5.7-1-iphoneos.arm64.tar.gz"
    )

    mkdir -p "$verify_dir" "$ARM64E_CACHE"
    for product in "${products[@]}"; do
        local source_archive="${product%%:*}"
        local cache_archive="${product##*:}"
        local source_path="$deps_dir/dist/$source_archive"
        local product_dir="$verify_dir/${cache_archive%.tar.gz}"
        local library architecture_info

        echo "Preparing $cache_archive"
        test -f "$source_path"
        cp "$source_path" "$ARM64E_CACHE/$cache_archive"
        mkdir -p "$product_dir"
        tar -xzf "$ARM64E_CACHE/$cache_archive" -C "$product_dir"
        while IFS= read -r -d '' library; do
            architecture_info="$(lipo -info "$library" 2>&1)"
            echo "$architecture_info"
            if ! printf '%s\n' "$architecture_info" \
                | grep -Eiq 'architecture: arm64e([[:space:]]|$)|architectures in the fat file:.*([[:space:]]|^)arm64e([[:space:]]|$)'; then
                echo "Missing arm64e architecture in $library" >&2
                exit 1
            fi
        done < <(find "$product_dir/lib" -type f -name '*.a' -print0)
    done
}

make_arm64e_compilers() {
    local tools_dir="$BUILD_ROOT/tools"
    mkdir -p "$tools_dir"
    printf '%s\n' \
        '#!/bin/bash' \
        'set -e' \
        'exec xcrun --sdk iphoneos clang -target "arm64-apple-ios${IPHONEOS_DEPLOYMENT_TARGET:-14.8}" -arch arm64e "$@"' \
        > "$tools_dir/arm64e-clang"
    printf '%s\n' \
        '#!/bin/bash' \
        'set -e' \
        'exec xcrun --sdk iphoneos clang++ -target "arm64-apple-ios${IPHONEOS_DEPLOYMENT_TARGET:-14.8}" -arch arm64e "$@"' \
        > "$tools_dir/arm64e-clang++"
    printf '%s\n' \
        '#!/bin/bash' \
        'set -e' \
        'exec xcrun --sdk iphoneos clang -target "arm64-apple-ios${IPHONEOS_DEPLOYMENT_TARGET:-14.8}" -arch arm64e -E "$@"' \
        > "$tools_dir/arm64e-cpp"
    chmod +x "$tools_dir/arm64e-clang" "$tools_dir/arm64e-clang++" "$tools_dir/arm64e-cpp"
    printf '%s\n' "$tools_dir"
}

is_macho() {
    file -b "$1" | grep -q 'Mach-O'
}

merge_file() {
    mkdir -p "$(dirname "$3")"
    lipo -create "$1" "$2" -output "$3"
}

merge_extensions() {
    local arm64_root="$1"
    local arm64e_root="$2"
    local output_root="$3"
    local source relative target_arm64e

    while IFS= read -r -d '' source; do
        relative="${source#"$arm64_root/"}"
        target_arm64e="$arm64e_root/$relative"
        if is_macho "$source"; then
            test -f "$target_arm64e"
            is_macho "$target_arm64e"
            merge_file "$source" "$target_arm64e" "$output_root/$relative"
        fi
    done < <(find "$arm64_root" -type f \( -name '*.so' -o -name '*.dylib' \) -print0)
}

package_rootful() {
    local arm64_product="$ARM64_BUILD/$PRODUCT_REL"
    local arm64e_product="$ARM64E_BUILD/$PRODUCT_REL"
    local work_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/python-ios-package.XXXXXX")"
    local pkg_root="$work_dir/root"
    local framework="$pkg_root/usr/local/Frameworks/Python.framework"
    local bin_dir="$pkg_root/usr/local/bin"
    local lib_dir="$pkg_root/usr/local/lib/python3.14"
    local pip_root="$work_dir/pip"
    local pip_site pip_bin pip_script native executable relative target_arm64e
    local package="$OUTPUT_DIR/python-ios_${VERSION}-1_iphoneos-arm.deb"

    echo "=== rootful package ==="
    for product in "$arm64_product" "$arm64e_product"; do
        test -d "$product/Python.framework"
        test -d "$product/bin"
        test -d "$product/lib/python3.14"
    done

    mkdir -p "$framework" "$bin_dir" "$lib_dir" "$OUTPUT_DIR"
    cp -R "$arm64_product/Python.framework/." "$framework/"
    merge_file "$arm64_product/Python.framework/Python" \
        "$arm64e_product/Python.framework/Python" "$framework/Python"

    cp -R "$arm64_product/lib/." "$lib_dir/"
    merge_extensions \
        "$arm64_product/lib/python3.14/lib-dynload" \
        "$arm64e_product/lib/python3.14/lib-dynload" \
        "$lib_dir/lib-dynload"

    cp -R "$arm64_product/bin/." "$bin_dir/"
    while IFS= read -r -d '' executable; do
        relative="${executable#"$arm64_product/bin/"}"
        target_arm64e="$arm64e_product/bin/$relative"
        if is_macho "$executable"; then
            test -f "$target_arm64e"
            merge_file "$executable" "$target_arm64e" "$bin_dir/$relative"
        fi
    done < <(find "$arm64_product/bin" -type f -print0)

    for executable in "$bin_dir"/*; do
        if [ -f "$executable" ] && is_macho "$executable" \
            && ! otool -l "$executable" | grep -Fq '@executable_path/../Frameworks'; then
            install_name_tool -add_rpath '@executable_path/../Frameworks' "$executable"
        fi
    done
    while IFS= read -r -d '' native; do
        if is_macho "$native" \
            && ! otool -l "$native" | grep -Fq '@loader_path/../../../Frameworks'; then
            install_name_tool -add_rpath '@loader_path/../../../Frameworks' "$native"
        fi
    done < <(find "$lib_dir/lib-dynload" -type f \( -name '*.so' -o -name '*.dylib' \) -print0)

    ln -sf ../Frameworks/Python.framework/Python \
        "$pkg_root/usr/local/lib/libpython3.14.dylib"

    "$ARM64_BUILD/build/python" -m ensurepip --upgrade --default-pip --root "$pip_root"
    pip_site="$(find "$pip_root" -type d -name site-packages -print -quit)"
    pip_bin="$(find "$pip_root" -type d -name bin -print -quit)"
    test -n "$pip_site" -a -n "$pip_bin"
    mkdir -p "$lib_dir/site-packages"
    cp -R "$pip_site/." "$lib_dir/site-packages/"
    for pip_script in pip pip3 "pip${VERSION%.*}"; do
        test -f "$pip_bin/$pip_script"
        cp "$pip_bin/$pip_script" "$bin_dir/$pip_script"
        sed -i '' '1s|^#!.*$|#!/usr/local/bin/python3.14|' "$bin_dir/$pip_script"
        chmod 755 "$bin_dir/$pip_script"
    done
    ln -sf python3.14 "$bin_dir/python3"
    ln -sf python3.14 "$bin_dir/python"

    mkdir -p "$pkg_root/DEBIAN"
    sed "s/@VERSION@/$VERSION/g" "$ROOT_DIR/packaging/control.in" \
        > "$pkg_root/DEBIAN/control"
    cp "$ROOT_DIR/packaging/postinst" "$pkg_root/DEBIAN/postinst"
    chmod 755 "$pkg_root/DEBIAN/postinst"

    while IFS= read -r -d '' native; do
        if is_macho "$native"; then
            codesign -f -s - --timestamp=none "$native"
        fi
    done < <(find "$pkg_root/usr/local" -type f -print0)
    rm -f "$package"
    dpkg-deb -b "$pkg_root" "$package"
}

has_architecture() {
    local expected="$2"
    local info
    info="$(lipo -info "$1" 2>&1)"
    printf '%s\n' "$info"
    printf '%s\n' "$info" \
        | grep -Eiq "(^|[[:space:]])${expected}([[:space:]]|$)"
}

verify_package() {
    local package="$OUTPUT_DIR/python-ios_${VERSION}-1_iphoneos-arm.deb"
    local extract_dir="$BUILD_ROOT/package-verify"
    local framework_binary="$extract_dir/usr/local/Frameworks/Python.framework/Python"
    local ssl_extension

    echo "=== verify package ==="
    test -f "$package"
    dpkg-deb --info "$package" | grep -Fq 'Architecture: iphoneos-arm'
    dpkg-deb --extract "$package" "$extract_dir"
    has_architecture "$framework_binary" arm64
    has_architecture "$framework_binary" arm64e
    has_architecture "$extract_dir/usr/local/bin/python3.14" arm64
    has_architecture "$extract_dir/usr/local/bin/python3.14" arm64e
    ssl_extension="$(find "$extract_dir/usr/local/lib/python3.14/lib-dynload" -name '_ssl*.so' -print -quit)"
    test -n "$ssl_extension"
    has_architecture "$ssl_extension" arm64
    has_architecture "$ssl_extension" arm64e
    test -d "$extract_dir/usr/local/lib/python3.14/site-packages/pip"
    test -x "$extract_dir/usr/local/bin/pip3.14"
}

echo "=== arm64 device build ==="
run_apple build iOS build --clean \
    --cross-build-dir "$ARM64_BUILD" \
    --cache-dir "$ARM64_CACHE"
run_apple build iOS "$TARGET" --clean \
    --cross-build-dir "$ARM64_BUILD" \
    --cache-dir "$ARM64_CACHE"

build_arm64e_dependencies
echo "=== arm64e device build ==="
run_apple --clean-env build iOS build --clean \
    --cross-build-dir "$ARM64E_BUILD" \
    --cache-dir "$ARM64E_CACHE"
TOOLS_DIR="$(make_arm64e_compilers)"
export IOS_SDK_VERSION=""
export IPHONEOS_DEPLOYMENT_TARGET="14.8"
export CC="$TOOLS_DIR/arm64e-clang"
export CXX="$TOOLS_DIR/arm64e-clang++"
export CPP="$TOOLS_DIR/arm64e-cpp"
export CFLAGS="-arch arm64e"
export CPPFLAGS="-arch arm64e"
export LDFLAGS="-arch arm64e"
run_apple build iOS "$TARGET" --clean \
    --cross-build-dir "$ARM64E_BUILD" \
    --cache-dir "$ARM64E_CACHE"

package_rootful
verify_package
find "$OUTPUT_DIR" -maxdepth 1 -type f -print -exec ls -lh {} \;
