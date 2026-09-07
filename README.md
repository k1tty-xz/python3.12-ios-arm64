# CPython for rootful iOS 14.8

This repository builds CPython 3.14.7 for a rootful iOS 14.8 jailbreak, with
both `arm64` and `arm64e` slices in the interpreter, framework, and native
standard-library extensions. The result is a Debian package for a jailbreak
environment, not an App Store application bundle.

The build uses CPython's tagged Apple build driver on a GitHub-hosted macOS
runner. The runner is pinned to `macos-15` and Xcode 16.4. The device target is
compiled with an iOS 14.8 deployment target. The official CPython iOS builder
is used for the normal arm64 build; the arm64e build is a separate clean build
with an arm64e compiler wrapper, because upstream CPython's official iOS
matrix currently names the physical-device ABI `arm64`.

## Build

Run the GitHub Actions workflow manually, or push a change that touches one of
the workflow inputs. It produces an artifact containing:

```text
python-ios_3.14.7-1_iphoneos-arm.deb
```

The package installs into `/usr/local` and provides:

```text
/usr/local/bin/python3.14
/usr/local/bin/python3
/usr/local/bin/python
/usr/local/bin/pip3.14
/usr/local/bin/pip3
/usr/local/bin/pip
/usr/local/lib/python3.14
/usr/local/Frameworks/Python.framework
```

`pip` is bootstrapped offline from CPython's bundled `ensurepip` wheel during
the build. The package does not claim that arbitrary third-party C extensions
will compile on the phone; pure-Python packages are the initial supported pip
case, and each native package must separately provide compatible iOS slices.

## Install and test on the phone

From WSL, after downloading the Actions artifact:

```sh
scp python-ios_3.14.7-1_iphoneos-arm.deb root@192.168.1.244:/tmp/
ssh root@192.168.1.244 'dpkg -i /tmp/python-ios_3.14.7-1_iphoneos-arm.deb'
scp scripts/device-smoke.sh root@192.168.1.244:/tmp/
ssh root@192.168.1.244 'sh /tmp/device-smoke.sh'
```

The smoke test checks the exact CPython version, imports representative native
standard-library modules, confirms `pip`, and installs the pure-Python `six`
package from PyPI into a temporary directory. It intentionally avoids
`subprocess`: iOS has platform restrictions around process creation even when
the rootful filesystem is writable.

The simulator test keeps the rest of CPython's fast CI suite but excludes its
live network-resource tests (`-u-network`), because external FTP services can
reject a GitHub runner's temporary address even when the build is correct.

The package architecture is deliberately `iphoneos-arm`, which is the Theos
rootful architecture name. `iphoneos-arm64` is the rootless package
architecture and is not used for this iOS 14.8 rootful target.

## What is verified in CI

CI verifies the CPython source archive checksum, builds and tests the official
arm64 simulator target, builds arm64e separately, creates a fat framework and
fat native extension files, confirms the Debian metadata, and confirms that
pip is present. A GitHub-hosted runner cannot reach a phone on a private LAN,
so the final device test must be run from the WSL host connected to the phone.
