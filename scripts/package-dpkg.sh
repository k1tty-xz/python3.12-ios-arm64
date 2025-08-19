#!/usr/bin/env bash
# Package staged files into a Debian .deb (inline-YML equivalent)
# - Input: $STAGE/usr tree created by scripts/build-python.sh
# - Output: $WORKDIR/python3.12_${PY_VER}-1_iphoneos-arm.deb
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_env.sh"

# Prepare packaging root
PKGROOT="$WORKDIR/pkgroot"
rm -rf "$PKGROOT" || true
mkdir -p "$PKGROOT/DEBIAN"

# Move staged usr into package root
if [ ! -d "$STAGE/usr" ]; then
  echo "Error: staged payload not found at $STAGE/usr" >&2
  exit 1
fi
mv "$STAGE/usr" "$PKGROOT/usr"

# Installed size in KB
INSTALLED_SIZE="$(du -sk "$PKGROOT/usr" | awk '{print $1}')"

# Control file (match inline workflow)
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

# Post-install script: create convenient symlinks
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

# Build the .deb (same naming as inline)
OUTPUT="$WORKDIR/python3.12_${PY_VER}-1_iphoneos-arm.deb"
dpkg-deb --build --root-owner-group "$PKGROOT" "$OUTPUT"
echo "Built: $OUTPUT"
