#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/CPYTHON_VERSION")"
PYTHON_VERSION="${VERSION%.*}"
FRIDA_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/FRIDA_VERSION")"
FRIDA_DEPS_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/FRIDA_DEPS_VERSION")"
FRIDA_TOOLS_VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/FRIDA_TOOLS_VERSION")"
BUILD_ROOT="$(mktemp -d "${RUNNER_TEMP:-/tmp}/frida-ios.XXXXXX")"
OUTPUT_DIR="${RUNNER_TEMP:-/tmp}/python-ios-dist"
TARGET="arm64-apple-ios14.8"
PYTHON_PACKAGE="$OUTPUT_DIR/python-ios_${VERSION}-1_iphoneos-arm.deb"
PACKAGE="$OUTPUT_DIR/frida-ios_${FRIDA_VERSION}-1_iphoneos-arm.deb"
PKG_ROOT="$BUILD_ROOT/package"
PREFIX="$PKG_ROOT/usr/local"
LIB_DIR="$PREFIX/lib/python$PYTHON_VERSION"
FRIDA_SITE="$LIB_DIR/site-packages"

FRIDA_CORE_SHA256="699dcb9e76a6c7ef8f4b6f5088bb899f30ffd227a2913fe904f13ec83ac3593e"
FRIDA_SDK_SHA256="80ffdfcfa8f68ae779b591f4ea05ac61c2834440ad13605f037d658e80f648b2"
FRIDA_SERVER_SHA256="b77ed65fd8d9de55191711acd1fa89ca0939e7d9848347918948d4989fdb7934"
FRIDA_TOOLS_SHA256="7a2c544b545d095040fffbd3768a287a426343dad89095b4a24f4b20382d926a"

download_verified() {
    local url="$1"
    local sha256="$2"
    local output="$3"

    curl -fL --retry 5 --retry-all-errors -o "$output" "$url"
    printf '%s  %s\n' "$sha256" "$output" | shasum -a 256 -c -
}

test -f "$PYTHON_PACKAGE"
test -f "$OUTPUT_DIR/.build-python"
test -f "$OUTPUT_DIR/.build-python-lib"
test -f "$OUTPUT_DIR/.python-framework"
BUILD_PYTHON="$(cat "$OUTPUT_DIR/.build-python")"
BUILD_PYTHON_LIB="$(cat "$OUTPUT_DIR/.build-python-lib")"
PYTHON_FRAMEWORK="$(cat "$OUTPUT_DIR/.python-framework")"
test -x "$BUILD_PYTHON"
PIP_WHEEL=("$BUILD_PYTHON_LIB"/ensurepip/_bundled/pip-*.whl)
test -f "${PIP_WHEEL[0]}"

test -f "$PYTHON_FRAMEWORK/Headers/Python.h"

FRIDA_CORE_ARCHIVE="$BUILD_ROOT/frida-core-devkit-ios-arm64.tar.xz"
FRIDA_SDK_ARCHIVE="$BUILD_ROOT/frida-sdk-ios-arm64.tar.xz"
FRIDA_SERVER_DEB="$BUILD_ROOT/frida-ios.deb"
FRIDA_TOOLS_ARCHIVE="$BUILD_ROOT/frida-tools.tar.gz"
download_verified \
    "https://github.com/frida/frida/releases/download/$FRIDA_VERSION/frida-core-devkit-$FRIDA_VERSION-ios-arm64.tar.xz" \
    "$FRIDA_CORE_SHA256" "$FRIDA_CORE_ARCHIVE"
download_verified \
    "https://build.frida.re/deps/$FRIDA_DEPS_VERSION/sdk-ios-arm64.tar.xz" \
    "$FRIDA_SDK_SHA256" "$FRIDA_SDK_ARCHIVE"
download_verified \
    "https://github.com/frida/frida/releases/download/$FRIDA_VERSION/frida_${FRIDA_VERSION}_iphoneos-arm.deb" \
    "$FRIDA_SERVER_SHA256" "$FRIDA_SERVER_DEB"
download_verified \
    "https://files.pythonhosted.org/packages/source/f/frida-tools/frida_tools-$FRIDA_TOOLS_VERSION.tar.gz" \
    "$FRIDA_TOOLS_SHA256" "$FRIDA_TOOLS_ARCHIVE"

FRIDA_CORE="$BUILD_ROOT/frida-core"
FRIDA_SDK="$BUILD_ROOT/frida-sdk"
FRIDA_TOOLS="$BUILD_ROOT/frida-tools"
FRIDA_PYTHON="$BUILD_ROOT/frida-python"
FRIDA_GEN="$BUILD_ROOT/frida-generated"
mkdir -p "$FRIDA_CORE" "$FRIDA_SDK" "$FRIDA_TOOLS" "$FRIDA_GEN" "$FRIDA_SITE"
tar -xf "$FRIDA_CORE_ARCHIVE" -C "$FRIDA_CORE"
tar -xf "$FRIDA_SDK_ARCHIVE" -C "$FRIDA_SDK"
tar -xf "$FRIDA_TOOLS_ARCHIVE" -C "$FRIDA_TOOLS"

git clone --depth 1 --branch "$FRIDA_VERSION" --recurse-submodules --shallow-submodules \
    https://github.com/frida/frida-python.git "$FRIDA_PYTHON"
FRIDA_TOOLS_SOURCE="$FRIDA_TOOLS/frida_tools-$FRIDA_TOOLS_VERSION"
test -d "$FRIDA_TOOLS_SOURCE"
FRIDA_CORE_SOURCE="$BUILD_ROOT/frida-core-source"
git clone --depth 1 --branch "$FRIDA_VERSION" \
    https://github.com/frida/frida-core.git "$FRIDA_CORE_SOURCE"

cp "$FRIDA_CORE_SOURCE/src/api/GLib-2.0.gir" "$FRIDA_GEN/"
cp "$FRIDA_CORE_SOURCE/src/api/GObject-2.0.gir" "$FRIDA_GEN/"
cp "$FRIDA_CORE_SOURCE/src/api/Gio-2.0.gir" "$FRIDA_GEN/"
cp "$FRIDA_CORE/frida-core.gir" "$FRIDA_GEN/"
PYTHONPATH="$BUILD_PYTHON_LIB:$FRIDA_PYTHON/frida:$FRIDA_PYTHON/frida-bindgen" \
    "$BUILD_PYTHON" -m frida_bindgen \
    --frida-gir="$FRIDA_GEN/frida-core.gir" \
    --glib-gir="$FRIDA_GEN/GLib-2.0.gir" \
    --gobject-gir="$FRIDA_GEN/GObject-2.0.gir" \
    --gio-gir="$FRIDA_GEN/Gio-2.0.gir" \
    --output-py="$FRIDA_GEN/__init__.py" \
    --output-pyi="$FRIDA_GEN/_frida.pyi" \
    --output-c="$FRIDA_GEN/extension.c" \
    --output-aio="$FRIDA_GEN/aio.py"

FRIDA_EXTENSION_OBJECT="$FRIDA_GEN/extension.o"
FRIDA_EXTENSION="$FRIDA_SITE/frida/_frida.abi3.so"
mkdir -p "$FRIDA_SITE/frida"
xcrun --sdk iphoneos clang -target "$TARGET" \
    -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)" \
    -I"$PYTHON_FRAMEWORK/Headers" \
    -I"$FRIDA_CORE" \
    -I"$FRIDA_SDK/include" \
    -I"$FRIDA_SDK/include/glib-2.0" \
    -I"$FRIDA_SDK/include/json-glib-1.0" \
    -I"$FRIDA_SDK/include/gio-unix-2.0" \
    -I"$FRIDA_SDK/lib/glib-2.0/include" \
    -DPy_LIMITED_API=0x03070000 -DNDEBUG -fPIC -fvisibility=hidden -O2 \
    -c "$FRIDA_GEN/extension.c" -o "$FRIDA_EXTENSION_OBJECT"
xcrun --sdk iphoneos clang -target "$TARGET" \
    -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)" \
    -bundle -Wl,-dead_strip -Wl,-exported_symbol,_PyInit__frida \
    -F"$(dirname "$PYTHON_FRAMEWORK")" -framework Python \
    "$FRIDA_EXTENSION_OBJECT" "$FRIDA_CORE/libfrida-core.a" \
    -lbsm -ldl -lm -lresolv \
    -framework Foundation -framework CoreFoundation -framework CoreGraphics -framework UIKit \
    -o "$FRIDA_EXTENSION"

cp "$FRIDA_GEN/__init__.py" "$FRIDA_SITE/frida/"
cp "$FRIDA_GEN/aio.py" "$FRIDA_SITE/frida/"
cp "$FRIDA_GEN/_frida.pyi" "$FRIDA_SITE/frida/"
cp "$FRIDA_PYTHON/frida/py.typed" "$FRIDA_SITE/frida/"
mkdir -p "$FRIDA_SITE/frida-$FRIDA_VERSION.dist-info"
cat > "$FRIDA_SITE/frida-$FRIDA_VERSION.dist-info/METADATA" <<EOF
Metadata-Version: 2.1
Name: frida
Version: $FRIDA_VERSION
Summary: Python bindings for Frida
Home-page: https://frida.re/
Requires-Python: >=3.7
EOF
cat > "$FRIDA_SITE/frida-$FRIDA_VERSION.dist-info/WHEEL" <<'EOF'
Wheel-Version: 1.0
Generator: python-ios
Root-Is-Purelib: false
Tag: cp37-abi3-ios_14_8_arm64_iphoneos
EOF

FRIDA_WHEELS="$BUILD_ROOT/frida-wheels"
mkdir -p "$FRIDA_WHEELS"
FRIDA_REQUIREMENTS=(
    "colorama==0.4.6"
    "prompt-toolkit==3.0.53"
    "pygments==2.21.0"
    "websockets==13.1"
    "wcwidth==0.8.3"
)
PYTHONPATH="$BUILD_PYTHON_LIB:${PIP_WHEEL[0]}" \
    "$BUILD_PYTHON" -m pip --isolated download --only-binary=:all: --no-deps \
    --dest "$FRIDA_WHEELS" "${FRIDA_REQUIREMENTS[@]}"
PYTHONPATH="$BUILD_PYTHON_LIB:${PIP_WHEEL[0]}" \
    "$BUILD_PYTHON" -m pip --isolated install --no-index --no-deps \
    --only-binary=:all: --prefix /usr/local --root "$PKG_ROOT" \
    "$FRIDA_WHEELS"/*.whl
cp -R "$FRIDA_TOOLS_SOURCE/frida_tools" "$FRIDA_SITE/"
mkdir -p "$FRIDA_SITE/frida_tools-$FRIDA_TOOLS_VERSION.dist-info"
cat > "$FRIDA_SITE/frida_tools-$FRIDA_TOOLS_VERSION.dist-info/METADATA" <<EOF
Metadata-Version: 2.1
Name: frida-tools
Version: $FRIDA_TOOLS_VERSION
Summary: CLI tools for Frida
Home-page: https://frida.re/
Requires-Python: >=3.7
Requires-Dist: colorama>=0.2.7,<1.0.0
Requires-Dist: frida>=17.10.0,<18.0.0
Requires-Dist: prompt-toolkit>=2.0.0,<4.0.0
Requires-Dist: pygments>=2.0.2,<3.0.0
Requires-Dist: websockets>=13.0.0,<14.0.0
EOF
cat > "$FRIDA_SITE/frida_tools-$FRIDA_TOOLS_VERSION.dist-info/WHEEL" <<'EOF'
Wheel-Version: 1.0
Generator: python-ios
Root-Is-Purelib: true
Tag: py3-none-any
EOF
while IFS='=' read -r command target; do
    module="${target%:*}"
    entrypoint="${target#*:}"
    cat > "$PREFIX/bin/$command" <<EOF
#!/bin/sh
exec /usr/local/bin/python$PYTHON_VERSION -c 'from $module import $entrypoint; $entrypoint()' "\$@"
EOF
    chmod 755 "$PREFIX/bin/$command"
done <<'EOF'
frida=frida_tools.repl:main
frida-apk=frida_tools.apk:main
frida-compile=frida_tools.compiler:main
frida-create=frida_tools.creator:main
frida-discover=frida_tools.discoverer:main
frida-itrace=frida_tools.itracer:main
frida-join=frida_tools.join:main
frida-kill=frida_tools.kill:main
frida-ls=frida_tools.ls:main
frida-ls-devices=frida_tools.lsd:main
frida-pm=frida_tools.pm:main
frida-ps=frida_tools.ps:main
frida-pull=frida_tools.pull:main
frida-push=frida_tools.push:main
frida-rm=frida_tools.rm:main
frida-strace=frida_tools.stracer:main
frida-trace=frida_tools.tracer:main
EOF

FRIDA_DEB_ROOT="$BUILD_ROOT/frida-deb"
mkdir -p "$FRIDA_DEB_ROOT"
(
    cd "$FRIDA_DEB_ROOT"
    ar -x "$FRIDA_SERVER_DEB"
    tar -xf data.tar.xz
)
mkdir -p "$PKG_ROOT/usr/sbin" "$PKG_ROOT/usr/lib/frida-1.0"
cp "$FRIDA_DEB_ROOT/usr/sbin/frida-server" "$PKG_ROOT/usr/sbin/"
cp "$FRIDA_DEB_ROOT/usr/lib/frida-1.0/frida-agent.dylib" "$PKG_ROOT/usr/lib/frida-1.0/"

mkdir -p "$PKG_ROOT/DEBIAN"
sed -e "s/@VERSION@/$FRIDA_VERSION/g" -e "s/@PYTHON_VERSION@/$VERSION-1/g" \
    "$ROOT_DIR/packaging/frida-control.in" > "$PKG_ROOT/DEBIAN/control"

while IFS= read -r -d '' native; do
    lipo "$native" -verify_arch arm64
    codesign -f -s - --timestamp=none "$native"
    codesign --verify "$native"
done < <(find "$PREFIX" "$PKG_ROOT/usr/sbin" "$PKG_ROOT/usr/lib/frida-1.0" -type f \( \
    -name '*.so' -o -name frida-server -o -name frida-agent.dylib \
\) -print0)

dpkg-deb --root-owner-group -Zxz -b "$PKG_ROOT" "$PACKAGE"
VERIFY="$BUILD_ROOT/verify"
dpkg-deb --extract "$PACKAGE" "$VERIFY"
test "$(dpkg-deb -f "$PACKAGE" Architecture)" = iphoneos-arm
test "$(dpkg-deb -f "$PACKAGE" Version)" = "$FRIDA_VERSION-1"
test "$(dpkg-deb -f "$PACKAGE" Depends)" = "com.python.ios (= $VERSION-1), firmware (>= 14.8)"
test -f "$VERIFY/usr/local/lib/python$PYTHON_VERSION/site-packages/frida/__init__.py"
test -f "$VERIFY/usr/local/lib/python$PYTHON_VERSION/site-packages/frida/_frida.abi3.so"
test -x "$VERIFY/usr/local/bin/frida-ps"
test -x "$VERIFY/usr/sbin/frida-server"
test -f "$VERIFY/usr/lib/frida-1.0/frida-agent.dylib"
ls -lh "$PACKAGE"
