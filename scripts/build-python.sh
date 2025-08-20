#!/usr/bin/env bash
# ==============================================================================
# Script: build-python.sh
# Purpose: Build CPython 3.12 for iOS arm64.
# Requires: PY_VER (set in environment)
# ==============================================================================

set -euxo pipefail

# Load common environment variables and toolchain settings
# shellcheck disable=SC1091
source "$(dirname "$0")/common-env.sh"

cd "$BUILD"

# ------------------------------------------------------------------------------
# Pre-flight Checks
# ------------------------------------------------------------------------------
# Ensure PYTHON_FOR_BUILD is set and executable.
# This is required for cross-compiling Python (it needs a host python to run tools).
if [ -z "${PYTHON_FOR_BUILD:-}" ]; then
    echo "Error: PYTHON_FOR_BUILD is not set." >&2
    echo "Please set it to the path of a host python${PY_VER} interpreter." >&2
    exit 1
fi
if [ ! -x "$PYTHON_FOR_BUILD" ]; then
    echo "Error: PYTHON_FOR_BUILD='$PYTHON_FOR_BUILD' is not executable." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Download CPython Source
# ------------------------------------------------------------------------------
# Download the official Python source tarball with retries.
for i in 1 2 3 4 5; do
  curl --fail --location --show-error -LO \
    "https://www.python.org/ftp/python/${PY_VER}/Python-${PY_VER}.tgz" && break || {
    echo "Error: Download failed (attempt $i). Retrying in 3s..." >&2
    sleep 3
  }
done

# Verify download
[ -f "Python-${PY_VER}.tgz" ] || { echo "Error: Python tarball missing." >&2; exit 1; }

# Extract source
tar xf "Python-${PY_VER}.tgz"
cd "Python-${PY_VER}"

# ------------------------------------------------------------------------------
# Patching and Configuration
# ------------------------------------------------------------------------------

# Disable NIS (Network Information Service) module on iOS to avoid missing headers.
cat > Modules/Setup.local <<'EOF'
*disabled*
nis
EOF

# Refresh triplet recognition (config.sub/config.guess)
# Derive repo root robustly from WORKDIR (which is <repo>/work)
REPO_ROOT="$(cd "$(dirname "$WORKDIR")" && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor/gnu-config"

# Use patch file for configure script to allow cross-compilation.
# This replaces the "cross build not supported" error with a warning.
PATCH_FILE="$REPO_ROOT/scripts/python-configure.patch"
patch -p0 < "$PATCH_FILE" || {
    echo "Error: Patch failed. Falling back to sed..."
    cp configure configure.orig
    /usr/local/bin/gsed -ri 's/^[[:space:]]*as_fn_error[^\n]*cross build not supported[^\n]*$/  : # allow iOS cross build for $host/' configure
}
grep -n 'cross build not supported' configure || true

# Create config.site to pre-define answers for configure checks that cannot run
# during cross-compilation.
cat > config.site <<'EOF'
# Files
ac_cv_file__dev_ptc=no
ac_cv_file__dev_ptmx=no

# Functions problematic or unavailable on iOS
ac_cv_func_system=no
ac_cv_func_pipe2=no
ac_cv_func_forkpty=no
ac_cv_func_openpty=no

# Avoid other cross-run checks
ac_cv_func_sendfile=no
ac_cv_func_preadv=no
ac_cv_func_pwritev=no
ac_cv_func_getentropy=no
ac_cv_func_utimensat=no
ac_cv_func_posix_fallocate=no
ac_cv_func_clock_settime=no

# Disable NIS
ac_cv_header_rpcsvc_yp_prot_h=no
ac_cv_header_rpcsvc_ypclnt_h=no
ac_cv_header_rpcsvc_rpcsvc_h=no
ac_cv_func_yp_get_default_domain=no
ac_cv_lib_nsl_yp_get_default_domain=no
ac_cv_have_nis=no

# Networking
ac_cv_func_getaddrinfo=yes
ac_cv_working_getaddrinfo=yes
ac_cv_buggy_getaddrinfo=no
ac_cv_func_getnameinfo=yes
EOF
export CONFIG_SITE="$PWD/config.site"

# Set compiler flags to include our dependencies (OpenSSL, libffi)
export CPPFLAGS="-I$DEPS/openssl-ios/usr/local/include -I$DEPS/libffi-ios/usr/local/include"
export LDFLAGS="-L$DEPS/openssl-ios/usr/local/lib -L$DEPS/libffi-ios/usr/local/lib ${LDFLAGS}"
export LIBS="-lssl -lcrypto"
export PKG_CONFIG_PATH="$DEPS/libffi-ios/usr/local/lib/pkgconfig:$DEPS/openssl-ios/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Configure linker for shared modules
export LD="$CC"
export LDSHARED="$CC -bundle -undefined dynamic_lookup $LDFLAGS"
export LDCXXSHARED="$CXX -bundle -undefined dynamic_lookup $LDFLAGS"

# Run configure
./configure \
  --host="${HOST_TRIPLE}" \
  --build="$(uname -m)-apple-darwin" \
  --prefix=/usr/local \
  --with-build-python="${PYTHON_FOR_BUILD}" \
  --with-openssl="$DEPS/openssl-ios/usr/local" \
  --with-ensurepip=install \
  --disable-test-modules

# Patch Makefile to skip 'checksharedmods' which fails during cross-compilation
awk 'BEGIN{skip=0}
  /^checksharedmods:/{print "checksharedmods:\n\t@true"; skip=1; next}
  skip && (/^\t/ || /^[[:space:]]*$/){next}
  skip {skip=0}
  {print}
' Makefile > Makefile.new && mv Makefile.new Makefile

# ------------------------------------------------------------------------------
# Build and Install
# ------------------------------------------------------------------------------
make -j"${JOBS}"
make install ENSUREPIP=no DESTDIR="$STAGE"

# Cleanup source tarball
cd "$BUILD"
rm -f "Python-${PY_VER}.tgz"

# ------------------------------------------------------------------------------
# Post-Processing
# ------------------------------------------------------------------------------

# Create symlinks for version-agnostic names (python3)
ln -sf python3.12 "$STAGE/usr/local/bin/python3" || true

# Strip debug symbols to reduce package size
# We use the iOS toolchain strip
echo "Stripping binaries..."
find "$STAGE" -type f \( -name "*.dylib" -o -name "*.so" -o -path "$STAGE/usr/local/bin/*" \) | while read -r f; do
    if file -b "$f" | grep -q 'Mach-O'; then
        "$STRIP" -x "$f" || echo "Warning: strip failed on $f" >&2
    fi
done

# Sign binaries with entitlements
# This is critical for iOS to allow the binaries to run, especially on jailbroken devices.
ENTITLEMENTS="$REPO_ROOT/scripts/entitlements.plist"
while IFS= read -r -d '' f; do
  if file -b "$f" | grep -q 'Mach-O'; then
    ldid -S"$ENTITLEMENTS" "$f" || echo "Warning: ldid failed on $f" >&2
  fi
done < <(find "$STAGE" -type f \( -name "*.dylib" -o -name "*.so" -o -path "$STAGE/usr/local/bin/*" \) -print0)
