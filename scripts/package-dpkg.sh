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
# Render control file from template with variable substitution
CONTROL_TEMPLATE="$(dirname "$0")/../debian/control.in"
# shellcheck disable=SC2016
sed -e "s#\${PY_VER}#${PY_VER}#g" \
    -e "s#\${INSTALLED_SIZE}#${INSTALLED_SIZE}#g" \
    "$CONTROL_TEMPLATE" > "$PKGROOT/DEBIAN/control"

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
