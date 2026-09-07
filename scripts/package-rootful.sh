#!/bin/bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
    echo "usage: $0 ARM64_BUILD ARM64E_BUILD BUILD_PYTHON DIST_DIR" >&2
    exit 2
fi

ARM64_BUILD="$1"
ARM64E_BUILD="$2"
BUILD_PYTHON="$3"
DIST_DIR="$4"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_VERSION")"
PRODUCT_REL="arm64-apple-ios14.8/Apple/iOS/Frameworks/arm64-iphoneos"
ARM64_PRODUCT="$ARM64_BUILD/$PRODUCT_REL"
ARM64E_PRODUCT="$ARM64E_BUILD/$PRODUCT_REL"
WORK_DIR="$(mktemp -d "${RUNNER_TEMP:-/tmp}/python-ios-package.XXXXXX")"
PKG_ROOT="$WORK_DIR/root"
FRAMEWORK="$PKG_ROOT/usr/local/Frameworks/Python.framework"
BIN_DIR="$PKG_ROOT/usr/local/bin"
LIB_DIR="$PKG_ROOT/usr/local/lib/python3.14"

for product in "$ARM64_PRODUCT" "$ARM64E_PRODUCT"; do
    test -d "$product/Python.framework"
    test -d "$product/bin"
    test -d "$product/lib/python3.14"
done

mkdir -p "$FRAMEWORK" "$BIN_DIR" "$LIB_DIR" "$DIST_DIR"
cp -R "$ARM64_PRODUCT/Python.framework/." "$FRAMEWORK/"

is_macho() {
    file -b "$1" | grep -q 'Mach-O'
}

merge_file() {
    local arm64="$1"
    local arm64e="$2"
    local output="$3"
    mkdir -p "$(dirname "$output")"
    lipo -create "$arm64" "$arm64e" -output "$output"
}

merge_tree() {
    local arm64_root="$1"
    local arm64e_root="$2"
    local output_root="$3"
    local source relative target target_arm64e

    while IFS= read -r -d '' source; do
        relative="${source#"$arm64_root/"}"
        target="$output_root/$relative"
        target_arm64e="$arm64e_root/$relative"
        if ! is_macho "$source"; then
            continue
        fi
        test -f "$target_arm64e" || {
            echo "Missing arm64e counterpart for $relative" >&2
            exit 1
        }
        is_macho "$target_arm64e"
        merge_file "$source" "$target_arm64e" "$target"
    done < <(find "$arm64_root" -type f \( -name '*.so' -o -name '*.dylib' \) -print0)
}

merge_file \
    "$ARM64_PRODUCT/Python.framework/Python" \
    "$ARM64E_PRODUCT/Python.framework/Python" \
    "$FRAMEWORK/Python"

cp -R "$ARM64_PRODUCT/lib/." "$LIB_DIR/"
merge_tree \
    "$ARM64_PRODUCT/lib/python3.14/lib-dynload" \
    "$ARM64E_PRODUCT/lib/python3.14/lib-dynload" \
    "$LIB_DIR/lib-dynload"

cp -R "$ARM64_PRODUCT/bin/." "$BIN_DIR/"
while IFS= read -r -d '' source; do
    relative="${source#"$ARM64_PRODUCT/bin/"}"
    target="$BIN_DIR/$relative"
    target_arm64e="$ARM64E_PRODUCT/bin/$relative"
    if is_macho "$source"; then
        test -f "$target_arm64e"
        is_macho "$target_arm64e"
        merge_file "$source" "$target_arm64e" "$target"
    fi
done < <(find "$ARM64_PRODUCT/bin" -type f -print0)

# The iOS framework build sets the default prefix to /usr/local. Add the
# framework location used by the rootful layout to every native launcher.
for executable in "$BIN_DIR"/*; do
    if [ -f "$executable" ] && is_macho "$executable"; then
        if ! otool -l "$executable" | grep -Fq '@executable_path/../Frameworks'; then
            install_name_tool -add_rpath '@executable_path/../Frameworks' "$executable"
        fi
    fi
done

ln -sf ../Frameworks/Python.framework/Python \
    "$PKG_ROOT/usr/local/lib/libpython3.14.dylib"

# Bootstrap pip from CPython's bundled, offline ensurepip wheel. Doing this
# with the matching build Python avoids downloading any runtime packages while
# still putting pip directly in the final /usr/local layout.
PIP_ROOT="$(mktemp -d "${RUNNER_TEMP:-/tmp}/python-ios-pip.XXXXXX")"
"$BUILD_PYTHON" -m ensurepip --upgrade --default-pip --root "$PIP_ROOT"
PIP_SITE="$(find "$PIP_ROOT" -type d -name site-packages -print -quit)"
PIP_BIN="$(find "$PIP_ROOT" -type d -name bin -print -quit)"
test -n "$PIP_SITE"
test -n "$PIP_BIN"
mkdir -p "$LIB_DIR/site-packages"
cp -R "$PIP_SITE/." "$LIB_DIR/site-packages/"
PYTHON_MINOR="${VERSION%.*}"
for pip_script in pip pip3 "pip$PYTHON_MINOR"; do
    test -f "$PIP_BIN/$pip_script"
    cp "$PIP_BIN/$pip_script" "$BIN_DIR/$pip_script"
    sed -i '' '1s|^#!.*$|#!/usr/local/bin/python3.14|' "$BIN_DIR/$pip_script"
    chmod 755 "$BIN_DIR/$pip_script"
done

# Keep conventional Python command names available in a jailbreak shell.
ln -sf python3.14 "$BIN_DIR/python3"
ln -sf python3.14 "$BIN_DIR/python"

mkdir -p "$PKG_ROOT/DEBIAN"
sed "s/@VERSION@/$VERSION/g" "$ROOT_DIR/packaging/control.in" \
    > "$PKG_ROOT/DEBIAN/control"
cp "$ROOT_DIR/packaging/postinst" "$PKG_ROOT/DEBIAN/postinst"
chmod 755 "$PKG_ROOT/DEBIAN/postinst"

# Ad-hoc signing is sufficient for a rootful jailbreak and makes the result
# usable even when the device has code-signing enforcement enabled.
codesign -f -s - --timestamp=none "$FRAMEWORK/Python"
while IFS= read -r -d '' native; do
    codesign -f -s - --timestamp=none "$native"
done < <(find "$PKG_ROOT/usr/local" -type f \( -name '*.so' -o -name '*.dylib' \) -print0)

PACKAGE="$DIST_DIR/python-ios_${VERSION}-1_iphoneos-arm.deb"
rm -f "$PACKAGE"
dpkg-deb -b "$PKG_ROOT" "$PACKAGE"
echo "$PACKAGE"
