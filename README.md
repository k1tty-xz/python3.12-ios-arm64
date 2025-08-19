# <img src="/icons/AppIcon-1024pt-squircle.png" alt="Icon" width="60"> Python 3.12 for iOS (arm64)

![Build & Publish](https://github.com/k1tty-xz/python3.12-ios-arm64/actions/workflows/theos-tweak.yml/badge.svg)
![Version](https://img.shields.io/badge/Python-3.12.5-blue.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2012.0+-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A reproducible build of CPython 3.12.5 for jailbroken iOS (arm64), packaged as a single Debian .deb using Theos (layout-only). The payload installs under /usr/local.

## Contents
- CPython 3.12.5 binaries and standard library
- ssl module (OpenSSL 1.1.1), ctypes (libffi)
- pip bootstrapping via ensurepip

## Supported
- Architecture: arm64
- iOS: 12.0+
- Environment: rootful jailbreaks

## Install
- From repo (recommended): add https://k1tty-xz.github.io/ to Sileo/Zebra/Cydia and install “Python 3.12 for iOS (arm64)”.
- Manual: download the latest .deb from Releases and install with dpkg -i <file>.

After install, symlinks are created if needed:
- /usr/local/bin/python3 -> python3.12
- /usr/local/bin/python  -> python3.12
- /usr/local/bin/pip3    -> pip3.12
- /usr/local/bin/pip     -> pip3.12

## Quick check
```sh
python3.12 -V    # expect: Python 3.12.5
python3.12 -m ensurepip --upgrade
pip3.12 install <package>
```

## How this is built
- CI workflow builds dependencies (OpenSSL, libffi) and CPython for iOS
- Files are staged into work/stage/usr
- Theos packages that staged layout as a single .deb (no MobileSubstrate hooks)

Workflow: .github/workflows/theos-tweak.yml

## Local build (macOS + Theos)
```sh
# Build runtime
make deps
make python

# Stage into Theos layout
rm -rf package-python3.12/layout/usr
cp -a work/stage/usr package-python3.12/layout/usr

# Package
cd package-python3.12
make package
# -> packages/*.deb
```

## Package metadata
- Package: com.k1tty-xz.python3.12
- Name: Python 3.12 for iOS (arm64)
- Section: Development

## Notes
- Built with Xcode toolchain (xcrun) targeting iOS arm64
- Requires a jailbroken device (rootful)

## License
MIT
