#!/bin/sh
set -eu

PYTHON=/usr/local/bin/python3.14
TEST_DIR="$(mktemp -d /tmp/python-ios-smoke.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
trap 'exit 1' HUP INT TERM

# Exercise the CLI, including streams and exit codes, before testing packages.
test "$("$PYTHON" -c 'print("stdout OK")')" = 'stdout OK'
test "$(printf 'hello\n' | "$PYTHON" -c 'print(input())')" = hello
test "$(printf 'print("stdin OK")\n' | "$PYTHON" -)" = 'stdin OK'
"$PYTHON" -c 'import sys; print("stderr OK", file=sys.stderr)' 2> "$TEST_DIR/stderr"
test "$(cat "$TEST_DIR/stderr")" = 'stderr OK'
status=0
"$PYTHON" -c 'raise SystemExit(7)' || status=$?
test "$status" -eq 7
printf 'import sys; assert sys.argv[1:] == ["hello world"]\n' > "$TEST_DIR/script.py"
"$PYTHON" "$TEST_DIR/script.py" 'hello world'
"$PYTHON" -I - <<'PY'
import sys
import bz2
import ctypes
import hashlib
import lzma
import sqlite3
import ssl
import zlib
from compression import zstd
from decimal import Decimal

assert sys.prefix == "/usr/local"
assert sys.version_info[:3] == (3, 14, 7)
assert sqlite3.connect(":memory:").execute("select 42").fetchone() == (42,)
ctypes.CDLL(None)
assert Decimal("0.1") + Decimal("0.2") == Decimal("0.3")
assert hashlib.sha256(b"abc").hexdigest() == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
for module in (bz2, lzma, zlib, zstd):
    assert module.decompress(module.compress(b"Python on iOS")) == b"Python on iOS"
print(sys.version)
print(ssl.OPENSSL_VERSION)
print("native stdlib: OK")
PY
"$PYTHON" -m pip --version
/usr/local/bin/pip3.14 --version

# Wheels avoid build subprocesses, which upstream CPython disables on iOS.
"$PYTHON" -m pip --isolated install \
    --disable-pip-version-check --no-input --no-cache-dir \
    --only-binary=:all: --no-deps \
    --target "$TEST_DIR/packages" six==1.17.0
PYTHONPATH="$TEST_DIR/packages" "$PYTHON" -c 'import six; assert six.__version__ == "1.17.0"; print("pure-Python PyPI install: OK")'
