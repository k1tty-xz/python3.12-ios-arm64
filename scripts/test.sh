#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_VERSION")"
PYTHON_VERSION="${VERSION%.*}"
PACKAGE="${1:-}"

if [ "$#" -ne 1 ] || [ ! -f "$PACKAGE" ]; then
    echo "usage: $0 path/to/python-ios_*.deb" >&2
    exit 2
fi

VERIFY="$(mktemp -d "${TMPDIR:-/tmp}/python-ios-test.XXXXXX")"
trap 'rm -rf "$VERIFY"' EXIT
dpkg-deb --extract "$PACKAGE" "$VERIFY"
CONTROL="$VERIFY/control"
mkdir "$CONTROL"
dpkg-deb --control "$PACKAGE" "$CONTROL"

PREFIX="$VERIFY/usr/local"
LIB_DIR="$PREFIX/lib/python$PYTHON_VERSION"
test "$(dpkg-deb -f "$PACKAGE" Package)" = com.python.ios
test "$(dpkg-deb -f "$PACKAGE" Version)" = "$VERSION-1"
test "$(dpkg-deb -f "$PACKAGE" Architecture)" = iphoneos-arm
test "$(dpkg-deb -f "$PACKAGE" Depends)" = 'firmware (>= 14.8), ca-certificates'
test -x "$PREFIX/bin/python$PYTHON_VERSION"
test -x "$PREFIX/bin/pip$PYTHON_VERSION"
test "$(readlink "$PREFIX/bin/python3")" = "python$PYTHON_VERSION"
test "$(readlink "$PREFIX/bin/pip3")" = "pip$PYTHON_VERSION"
test -f "$LIB_DIR/encodings/__init__.py"
test -f "$LIB_DIR/os.py"
test -f "$LIB_DIR/site-packages/pip/__main__.py"
test -f "$CONTROL/postinst"
sh -n "$CONTROL/postinst"
test -z "$(find "$LIB_DIR" -type d -name __pycache__ -print -quit)"
grep -Fq '_can_fork_exec = sys.platform not in {"emscripten", "wasi", "tvos", "watchos"}' \
    "$LIB_DIR/subprocess.py"

for module in _ssl _hashlib _ctypes _sqlite3 _bz2 _lzma _decimal _zstd _posixsubprocess zlib; do
    extensions=("$LIB_DIR/lib-dynload/$module".*.so)
    test -f "${extensions[0]}"
done

while IFS= read -r -d '' native; do
    lipo "$native" -verify_arch arm64
    codesign --verify "$native"
done < <(find "$PREFIX" -type f \( -name '*.so' -o -name Python -o -name "python$PYTHON_VERSION" \) -print0)

printf 'Package tests passed: %s\n' "$PACKAGE"
