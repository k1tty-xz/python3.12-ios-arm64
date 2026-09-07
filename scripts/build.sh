#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_VERSION")"
PYTHON_VERSION="${VERSION%.*}"
BUILD_ROOT="$(mktemp -d "${RUNNER_TEMP:-/tmp}/python-ios.XXXXXX")"
SOURCE_DIR="$BUILD_ROOT/Python-$VERSION"
TARGET="arm64-apple-ios14.8"
OUTPUT_DIR="${RUNNER_TEMP:-/tmp}/python-ios-dist"
PKG_ROOT="$BUILD_ROOT/package"
PREFIX="$PKG_ROOT/usr/local"
PACKAGE="$OUTPUT_DIR/python-ios_${VERSION}-1_iphoneos-arm.deb"

echo "Build root: $BUILD_ROOT"
xcodebuild -version
command -v dpkg-deb
curl -fL --retry 5 --retry-all-errors \
    -o "$BUILD_ROOT/Python.tar.xz" \
    "https://www.python.org/ftp/python/$VERSION/Python-$VERSION.tar.xz"
printf '%s  %s\n' "$(cat "$ROOT_DIR/CPYTHON_SHA256")" "$BUILD_ROOT/Python.tar.xz" \
    | shasum -a 256 -c -
tar -xf "$BUILD_ROOT/Python.tar.xz" -C "$BUILD_ROOT"
cd "$SOURCE_DIR"

# Upstream defaults to iOS 13. Name the documented deployment target in its
# device host triple; use the tagged builder unchanged for everything else.
run_apple() {
    python3 - "$@" <<'PY'
import runpy

builder = runpy.run_path("Apple/__main__.py")
builder["HOSTS"]["iOS"]["ios-arm64"] = {
    "arm64-apple-ios14.8": "arm64-iphoneos",
}
builder["main"]()
PY
}

run_apple build iOS build
run_apple build iOS "$TARGET" -- --disable-test-modules
PRODUCT="$SOURCE_DIR/cross-build/$TARGET/Apple/iOS/Frameworks/arm64-iphoneos"

mkdir -p "$PREFIX/Frameworks" "$PREFIX/bin" "$PREFIX/lib" "$OUTPUT_DIR"
cp -R "$PRODUCT/Python.framework" "$PREFIX/Frameworks/"
cp -R "$PRODUCT/lib/python$PYTHON_VERSION" "$PREFIX/lib/"
ln -s ../Frameworks/Python.framework/Python "$PREFIX/lib/libpython$PYTHON_VERSION.dylib"

# Upstream installs embedding resources and cross-compiler helpers, not a CLI.
xcrun --sdk iphoneos clang -target "$TARGET" -Werror=deprecated-declarations \
    -I"$PRODUCT/Python.framework/Headers" \
    -F"$PRODUCT" -framework Python \
    -Wl,-rpath,@executable_path/../Frameworks \
    "$ROOT_DIR/scripts/python.c" -o "$PREFIX/bin/python$PYTHON_VERSION"
ln -s "python$PYTHON_VERSION" "$PREFIX/bin/python3"
ln -s python3 "$PREFIX/bin/python"

# Install the bundled wheel offline with the macOS build Python. Do not run
# ensurepip on iOS, where its subprocess-based bootstrap is unavailable.
BUILD_PYTHON="$SOURCE_DIR/cross-build/build/python"
if [ ! -f "$BUILD_PYTHON" ]; then
    BUILD_PYTHON="$BUILD_PYTHON.exe"
fi
PIP_WHEEL=("$SOURCE_DIR"/Lib/ensurepip/_bundled/pip-*.whl)
PYTHONPATH="${PIP_WHEEL[0]}" "$BUILD_PYTHON" -m pip --isolated install \
    --no-index --no-deps --ignore-installed --no-compile \
    --prefix /usr/local --root "$PKG_ROOT" "${PIP_WHEEL[0]}"
# Host-generated scripts can contain a multi-line shebang for long build paths.
printf '#!/bin/sh\nexec /usr/local/bin/python%s -m pip "$@"\n' "$PYTHON_VERSION" \
    > "$PREFIX/bin/pip$PYTHON_VERSION"
chmod 755 "$PREFIX/bin/pip$PYTHON_VERSION"
ln -sf "pip$PYTHON_VERSION" "$PREFIX/bin/pip3"
ln -sf pip3 "$PREFIX/bin/pip"

mkdir -p "$PKG_ROOT/DEBIAN"
sed "s/@VERSION@/$VERSION/g" "$ROOT_DIR/packaging/control.in" > "$PKG_ROOT/DEBIAN/control"
install -m 755 "$ROOT_DIR/packaging/postinst" "$PKG_ROOT/DEBIAN/postinst"

# Validate and sign every shipped native binary, including all extensions.
while IFS= read -r -d '' native; do
    lipo "$native" -verify_arch arm64
    codesign -f -s - --timestamp=none "$native"
    codesign --verify "$native"
done < <(find "$PREFIX" -type f \( -name '*.so' -o -name Python -o -name "python$PYTHON_VERSION" \) -print0)

dpkg-deb --root-owner-group -Zxz -b "$PKG_ROOT" "$PACKAGE"
VERIFY="$BUILD_ROOT/verify"
dpkg-deb --extract "$PACKAGE" "$VERIFY"
PREFIX="$VERIFY/usr/local"
LIB_DIR="$PREFIX/lib/python$PYTHON_VERSION"
test "$(dpkg-deb -f "$PACKAGE" Architecture)" = iphoneos-arm
test "$(dpkg-deb -f "$PACKAGE" Version)" = "$VERSION-1"
test -x "$PREFIX/bin/python$PYTHON_VERSION"
test -x "$PREFIX/bin/pip$PYTHON_VERSION"
test -f "$LIB_DIR/encodings/__init__.py"
test -f "$LIB_DIR/os.py"
test -f "$LIB_DIR/site-packages/pip/__main__.py"
for module in _ssl _hashlib _ctypes _sqlite3 _bz2 _lzma _decimal _zstd zlib; do
    extensions=("$LIB_DIR/lib-dynload/$module".*.so)
    test -f "${extensions[0]}"
done
ls -lh "$PACKAGE"
