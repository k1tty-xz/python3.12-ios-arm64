#!/bin/sh
set -eu

PYTHON=/usr/local/bin/python3.14
TEST_DIR="$(mktemp -d /tmp/python-ios-smoke.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
trap 'exit 1' HUP INT TERM

# Exercise the CLI, including streams and exit codes, before testing packages.
test "$("$PYTHON" -c 'print("stdout OK")')" = 'stdout OK'
test "$(printf 'print(input())\nhello\n' | "$PYTHON" -c 'exec(input())')" = hello
"$PYTHON" -c 'import sys; print("stderr OK", file=sys.stderr)' 2> "$TEST_DIR/stderr"
test "$(cat "$TEST_DIR/stderr")" = 'stderr OK'
status=0
"$PYTHON" -c 'raise SystemExit(7)' || status=$?
test "$status" -eq 7
printf 'import sys; assert sys.argv[1:] == ["hello world"]\n' > "$TEST_DIR/script.py"
"$PYTHON" "$TEST_DIR/script.py" 'hello world'
"$PYTHON" -I -c 'import sys; assert sys.prefix == "/usr/local"; assert sys.version_info[:3] == (3, 14, 7); print(sys.version)'
"$PYTHON" -c 'import bz2, ctypes, decimal, hashlib, lzma, sqlite3, ssl, zlib; from compression import zstd; assert sqlite3.connect(":memory:").execute("select 42").fetchone() == (42,); assert ctypes.CDLL(None); print(ssl.OPENSSL_VERSION); print("native stdlib: OK")'
"$PYTHON" -m pip --version
/usr/local/bin/pip3.14 --version

# Wheels avoid build subprocesses, which upstream CPython disables on iOS.
"$PYTHON" -m pip --isolated install \
    --disable-pip-version-check --no-input --no-cache-dir \
    --only-binary=:all: --no-deps \
    --target "$TEST_DIR/packages" six==1.17.0
PYTHONPATH="$TEST_DIR/packages" "$PYTHON" -c 'import six; assert six.__version__ == "1.17.0"; print("pure-Python PyPI install: OK")'
