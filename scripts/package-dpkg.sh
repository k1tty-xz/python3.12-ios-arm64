#!/usr/bin/env bash
# ---------------------------------------------
# Package staged files into a Debian .deb under work/
# ---------------------------------------------
set -euxo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/common-env.sh"

PKGROOT="$WORKDIR/pkgroot"
mkdir -p "$PKGROOT/DEBIAN"
mv "$STAGE/usr" "$PKGROOT/usr"
INSTALLED_SIZE="$(du -sk "$PKGROOT/usr" | awk '{print $1}')"
cat > "$PKGROOT/DEBIAN/control" <<CTRL
Package: com.k1tty-xz.python3.12
Name: Python 3.12 for iOS (arm64)
Version: ${PY_VER}-1
Section: Development
Priority: optional
Architecture: iphoneos-arm
Maintainer: k1tty-xz
Installed-Size: ${INSTALLED_SIZE}
Description: CPython ${PY_VER} for jailbroken iOS (arm64).
 Includes OpenSSL (ssl), ctypes, and pip.
Icon: https://k1tty-xz.github.io/icons/AppIcon-60pt@2x-squircle.png
CTRL

cat > "$PKGROOT/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
ln -sf /usr/local/bin/python3.12 /usr/local/bin/python3 || true
ln -sf /usr/local/bin/python3.12 /usr/local/bin/python || true
ln -sf /usr/local/bin/pip3.12 /usr/local/bin/pip3 || true
ln -sf /usr/local/bin/pip3.12 /usr/local/bin/pip || true
exit 0
POST
chmod 0755 "$PKGROOT/DEBIAN/postinst"

OUTPUT="python3.12_${PY_VER}-1_iphoneos-arm.deb"
dpkg-deb --build --root-owner-group "$PKGROOT" "$WORKDIR/$OUTPUT"
echo "Built: $WORKDIR/$OUTPUT"
