#!/usr/bin/env bash
# Cross-compile CPython for iOS arm64 and stage into $STAGE
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_env.sh"

export PKG_CONFIG_PATH="$DEPS/libffi-ios/usr/local/lib/pkgconfig:$DEPS/openssl-ios/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

cd "$BUILD"
if [ ! -f "Python-${PY_VER}.tgz" ]; then
  curl -LO "https://www.python.org/ftp/python/${PY_VER}/Python-${PY_VER}.tgz"
fi
if [ ! -d "Python-${PY_VER}" ]; then
  tar xf "Python-${PY_VER}.tgz"
fi
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

# Patch configure guard that rejects cross builds
cp configure configure.orig
if command -v gsed >/dev/null 2>&1; then SED=gsed; else SED=sed; fi
$SED -ri 's/^[[:space:]]*as_fn_error[^\n]*cross build not supported[^\n]*$/  : # allow iOS cross build for $host/' configure || true

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
EOF
export CONFIG_SITE="$PWD/config.site"

export CPPFLAGS="-I$DEPS/openssl-ios/usr/local/include -I$DEPS/libffi-ios/usr/local/include ${CPPFLAGS:-}"
export LDFLAGS="-L$DEPS/openssl-ios/usr/local/lib -L$DEPS/libffi-ios/usr/local/lib ${LDFLAGS:-}"
export LIBS="-lssl -lcrypto ${LIBS:-}"
# Provided by workflow via actions/setup-python
export PYTHON_FOR_BUILD="${PYTHON_FOR_BUILD:-}"

# Ensure shared modules link with clang (not ld)
export LD="$CC"
export LDSHARED="$CC -bundle -undefined dynamic_lookup $LDFLAGS"
export LDCXXSHARED="$CXX -bundle -undefined dynamic_lookup $LDFLAGS"

./configure \
  --host="${HOST_TRIPLE}" \
  --build="$(uname -m)-apple-darwin" \
  --prefix=/usr/local \
  ${PYTHON_FOR_BUILD:+--with-build-python="${PYTHON_FOR_BUILD}"} \
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

# Symlinks
ln -sf python3.12 "$STAGE/usr/local/bin/python3" || true
ln -sf python3.12 "$STAGE/usr/local/bin/python" || true
ln -sf pip3.12 "$STAGE/usr/local/bin/pip3" || true
ln -sf pip3.12 "$STAGE/usr/local/bin/pip" || true

# Sign binaries
sign_macho_tree "$STAGE"

