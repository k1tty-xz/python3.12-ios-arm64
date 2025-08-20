# <img src="/icons/AppIcon-1024pt-squircle.png" alt="Icon" width="60"> Python 3.12 for iOS (arm64)

![Build & Publish](https://github.com/k1tty-xz/python3.12-ios-arm64/actions/workflows/python3.12-ios-arm64.yml/badge.svg)
![Version](https://img.shields.io/badge/Python-3.12.5-blue.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2012.0+-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

CPython 3.12.5 for jailbroken iOS (arm64), packaged as a single Debian .deb and installed under /usr/local.

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
- Packaged as a single .deb using dpkg-deb (layout-only)

Workflow: .github/workflows/python3.12-ios-arm64.yml

## Local build (macOS)
```sh
# Build runtime
make deps
make python

# Package .deb (mirrors CI packaging)
make package
# -> work/python3.12_*.deb
```

## License
MIT
