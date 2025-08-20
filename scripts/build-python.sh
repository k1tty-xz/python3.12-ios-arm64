#!/usr/bin/env bash
# ---------------------------------------------
# Build CPython for iOS arm64
# ---------------------------------------------
# Requires: PY_VER; common-env.sh sets toolchain vars
set -euxo pipefail

# shellcheck disable=SC1091
source "$(dirname "$0")/common-env.sh"

cd "$BUILD"

# Download with retries
for i in 1 2 3 4 5; do
  curl --fail --location --show-error -LO \
    "https://www.python.org/ftp/python/${PY_VER}/Python-${PY_VER}.tgz" && break || {
    echo "curl download failed (attempt $i)" >&2; sleep 3;
  }
done
[ -f "Python-${PY_VER}.tgz" ] || { echo "Python tarball missing after retries" >&2; exit 1; }

tar xf "Python-${PY_VER}.tgz"
cd "Python-${PY_VER}"

# Disable NIS on iOS to avoid rpcsvc/yp_prot.h
cat > Modules/Setup.local <<'EOF'
*disabled*
nis
EOF

# Refresh triplet recognition
curl -sSLo config.sub  https://git.savannah.gnu.org/cgit/config.git/plain/config.sub
curl -sSLo config.guess https://git.savannah.gnu.org/cgit/config.git/plain/config.guess
chmod +x config.sub config.guess

# Replace ONLY the guard line; preserve surrounding if/case to avoid 'fi' syntax errors
cp configure configure.orig
/usr/local/bin/gsed -ri 's/^[[:space:]]*as_fn_error[^\n]*cross build not supported[^\n]*$/  : # allow iOS cross build for $host/' configure
grep -n 'cross build not supported' configure || true

# Cross-compile cache
cat > config.site <<'EOF'
# Files
ac_cv_file__dev_ptc=no
ac_cv_file__dev_ptmx=no

# Functions that are problematic or unavailable on iOS
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

# Disable NIS (nis module) on iOS
ac_cv_header_rpcsvc_yp_prot_h=no
ac_cv_header_rpcsvc_ypclnt_h=no
ac_cv_header_rpcsvc_rpcsvc_h=no
ac_cv_func_yp_get_default_domain=no
ac_cv_lib_nsl_yp_get_default_domain=no
ac_cv_have_nis=no

# IPv6/getaddrinfo (keep enabled)
ac_cv_func_getaddrinfo=yes
ac_cv_working_getaddrinfo=yes
ac_cv_buggy_getaddrinfo=no
ac_cv_func_getnameinfo=yes

# Sizes (cross-compile cache)
ac_cv_sizeof_long_double=8
EOF
export CONFIG_SITE="$PWD/config.site"

export CPPFLAGS="-I$DEPS/openssl-ios/usr/local/include -I$DEPS/libffi-ios/usr/local/include"
export LDFLAGS="-L$DEPS/openssl-ios/usr/local/lib -L$DEPS/libffi-ios/usr/local/lib ${LDFLAGS}"
export LIBS="-lssl -lcrypto"
# Ensure pkg-config can resolve libffi/openssl if needed by sub-configures
export PKG_CONFIG_PATH="$DEPS/libffi-ios/usr/local/lib/pkgconfig:$DEPS/openssl-ios/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# PYTHON_FOR_BUILD must be provided by caller via env
# Ensure shared modules link with clang (not ld)
export LD="$CC"
export LDSHARED="$CC -bundle -undefined dynamic_lookup $LDFLAGS"
export LDCXXSHARED="$CXX -bundle -undefined dynamic_lookup $LDFLAGS"

./configure \
  --host="${HOST_TRIPLE}" \
  --build="$(uname -m)-apple-darwin" \
  --prefix=/usr/local \
  --with-build-python="${PYTHON_FOR_BUILD}" \
  --with-openssl="$DEPS/openssl-ios/usr/local" \
  --with-ensurepip=install \
  --disable-test-modules

# Skip checksharedmods (host can't import arm64 .so during cross-compile)
awk 'BEGIN{skip=0}
  /^checksharedmods:/{print "checksharedmods:\n\t@true"; skip=1; next}
  skip && (/^\t/ || /^[[:space:]]*$/){next}
  skip {skip=0}
  {print}
' Makefile > Makefile.new && mv Makefile.new Makefile

make -j"${JOBS}"
make install ENSUREPIP=no DESTDIR="$STAGE"

# Cleanup Python tarball to save disk
cd "$BUILD"
rm -f "Python-${PY_VER}.tgz"

# Symlinks
ln -sf python3.12 "$STAGE/usr/local/bin/python3" || true
ln -sf python3.12 "$STAGE/usr/local/bin/python" || true
ln -sf pip3.12 "$STAGE/usr/local/bin/pip3" || true
ln -sf pip3.12 "$STAGE/usr/local/bin/pip" || true

# Sign binaries and loadables
while IFS= read -r -d '' f; do
  if file -b "$f" | grep -q 'Mach-O'; then
    ldid -S "$f" || echo "ldid warning on $f" >&2
  fi
done < <(find "$STAGE" -type f \( -name "*.dylib" -o -name "*.so" -o -path "$STAGE/usr/local/bin/*" \) -print0)

