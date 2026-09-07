#!/bin/sh
set -eu

PYTHON=/usr/local/bin/python3.14

test -x "$PYTHON"
"$PYTHON" -c 'import sys; assert sys.version_info[:3] == (3, 14, 7); print(sys.version)'
"$PYTHON" -c 'import _ssl, bz2, ctypes, lzma, zlib, zoneinfo; print("native stdlib imports: OK")'
"$PYTHON" -m pip --version
"$PYTHON" -c 'import pip; print("pip import: OK")'

TEST_DIR=/tmp/python-ios-pip-smoke
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
"$PYTHON" -m pip install \
    --disable-pip-version-check \
    --no-input \
    --target "$TEST_DIR" \
    six==1.17.0
PYTHONPATH="$TEST_DIR" "$PYTHON" -c 'import six; assert six.__version__ == "1.17.0"; print("pure-Python PyPI install: OK")'
rm -rf "$TEST_DIR"
