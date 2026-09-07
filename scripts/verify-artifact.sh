#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 DIST_DIR" >&2
    exit 2
fi

DIST_DIR="$1"
PACKAGE="$(find "$DIST_DIR" -maxdepth 1 -type f -name '*.deb' -print -quit)"
test -n "$PACKAGE"
dpkg-deb --info "$PACKAGE" | grep -Fq 'Architecture: iphoneos-arm'
dpkg-deb --contents "$PACKAGE" | grep -Fq '/usr/local/bin/python3.14'
dpkg-deb --contents "$PACKAGE" | grep -Fq '/usr/local/bin/pip3.14'
dpkg-deb --contents "$PACKAGE" | grep -Fq '/usr/local/Frameworks/Python.framework/Python'

CHECKOUT="$(mktemp -d "${RUNNER_TEMP:-/tmp}/python-ios-verify.XXXXXX")"
dpkg-deb -x "$PACKAGE" "$CHECKOUT"

assert_fat() {
    local file="$1"
    local info
    info="$(lipo -info "$file")"
    case "$info" in
        *arm64*arm64e*|*arm64e*arm64*) ;;
        *)
            echo "Expected arm64 + arm64e in $file; got: $info" >&2
            exit 1
            ;;
    esac
}

assert_fat "$CHECKOUT/usr/local/Frameworks/Python.framework/Python"
assert_fat "$CHECKOUT/usr/local/bin/python3.14"
assert_fat "$CHECKOUT/usr/local/lib/python3.14/lib-dynload/_ssl.so"
test -d "$CHECKOUT/usr/local/lib/python3.14/site-packages/pip"

echo "Verified: $PACKAGE"
echo "Python.framework: $(lipo -info "$CHECKOUT/usr/local/Frameworks/Python.framework/Python")"
echo "python3.14: $(lipo -info "$CHECKOUT/usr/local/bin/python3.14")"
echo "_ssl: $(lipo -info "$CHECKOUT/usr/local/lib/python3.14/lib-dynload/_ssl.so")"
