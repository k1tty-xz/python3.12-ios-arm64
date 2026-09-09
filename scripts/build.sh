#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_VERSION")"
PYTHON_VERSION="${VERSION%.*}"
BUILD_ROOT="$(mktemp -d "${RUNNER_TEMP:-/tmp}/python-ios.XXXXXX")"
SOURCE_DIR="$BUILD_ROOT/Python-$VERSION"
TARGET="arm64-apple-ios"
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

# Rootful iOS can run POSIX subprocesses, which pip needs for source builds.
python3 - "$SOURCE_DIR/Lib/subprocess.py" "$SOURCE_DIR/configure" <<'PY'
from pathlib import Path
import sys

subprocess_path = Path(sys.argv[1])
configure_path = Path(sys.argv[2])

subprocess = subprocess_path.read_text()
old = '_can_fork_exec = sys.platform not in {"emscripten", "wasi", "ios", "tvos", "watchos"}'
new = '_can_fork_exec = sys.platform not in {"emscripten", "wasi", "tvos", "watchos"}'
if subprocess.count(old) != 1:
    raise SystemExit(f"unexpected subprocess guard in {subprocess_path}")
subprocess_path.write_text(subprocess.replace(old, new, 1))

configure = configure_path.read_text()
needle = "    py_cv_module__posixsubprocess=n/a\n"
if configure.count(needle) < 1:
    raise SystemExit(f"unexpected _posixsubprocess configure entry in {configure_path}")
configure = configure.replace(needle, "", 1)
configure_path.write_text(configure)
PY

python3 Apple/__main__.py build iOS build
python3 Apple/__main__.py build iOS "$TARGET" -- --disable-test-modules
PRODUCT="$SOURCE_DIR/cross-build/$TARGET/Apple/iOS/Frameworks/arm64-iphoneos"

mkdir -p "$PREFIX/Frameworks" "$PREFIX/bin" "$PREFIX/lib" "$OUTPUT_DIR"
cp -R "$PRODUCT/Python.framework" "$PREFIX/Frameworks/"
cp -R "$PRODUCT/lib/python$PYTHON_VERSION" "$PREFIX/lib/"
find "$PREFIX/lib/python$PYTHON_VERSION" -type d -name __pycache__ \
    -prune -exec rm -rf {} +
ln -s ../Frameworks/Python.framework/Python "$PREFIX/lib/libpython$PYTHON_VERSION.dylib"

# Build the terminal launcher; CPython's iOS config also needs UIKit linked.
xcrun --sdk iphoneos clang -target "$TARGET" -mios-version-min=13.0 \
    -Werror=deprecated-declarations \
    -I"$PRODUCT/Python.framework/Headers" \
    -F"$PRODUCT" -framework Python \
    -Wl,-needed_framework,UIKit \
    -Wl,-rpath,@executable_path/../Frameworks \
    "$ROOT_DIR/scripts/python.c" -o "$PREFIX/bin/python$PYTHON_VERSION"
ln -s "python$PYTHON_VERSION" "$PREFIX/bin/python3"
ln -s python3 "$PREFIX/bin/python"

# Install the bundled wheel offline with the host build Python.
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

# Strip, validate, and sign each shipped native binary.
while IFS= read -r -d '' native; do
    lipo "$native" -verify_arch arm64
    xcrun --sdk iphoneos strip -x "$native"
    codesign -f -s - --timestamp=none "$native"
    codesign --verify "$native"
done < <(find "$PREFIX" -type f \( -name '*.so' -o -name Python -o -name "python$PYTHON_VERSION" \) -print0)

dpkg-deb --root-owner-group -Zxz -b "$PKG_ROOT" "$PACKAGE"
ls -lh "$PACKAGE"
