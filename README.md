# CPython for rootful iOS 14.8

This repository builds CPython 3.14.7 for a rootful iOS 14.8 jailbreak, with
both `arm64` and `arm64e` slices in the interpreter, framework, and native
standard-library extensions. The result is a Debian package for a jailbreak
environment, not an App Store application bundle.

The build uses CPython's tagged Apple build driver on a GitHub-hosted macOS
runner. The runner is pinned to the arm64 `macos-14` image and Xcode 15.4,
because Apple's deployment-target table still includes iOS 14 for Xcode 15.4;
newer Xcode releases require iOS 15 or later. The device target is compiled
with an iOS 14.8 deployment target. The official CPython iOS builder is used
for the normal arm64 build; the arm64e build is a separate clean build with an
arm64e compiler wrapper, because upstream CPython's official iOS matrix names
the physical-device ABI `arm64`.

## Build

There is one build entry point: run the **Build CPython for rootful iOS 14.8**
workflow manually, or push a change that touches one of its inputs. You do not
need macOS, Xcode, Theos, or Procursus on your computer; GitHub Actions
provides the macOS/Xcode build environment. The workflow produces an artifact
containing:

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

The package architecture is deliberately `iphoneos-arm`, which is the Theos
rootful architecture name. `iphoneos-arm64` is the rootless package
architecture and is not used for this iOS 14.8 rootful target.

The implementation details are intentionally kept behind
[`scripts/build.sh`](scripts/build.sh). That single script downloads and
checks the pinned CPython source, invokes CPython's official Apple builder,
builds the arm64e dependency archives, creates the package, and verifies it.

## What is verified in CI

CI verifies the CPython source archive checksum, builds the official arm64
device target, builds arm64e separately, creates a fat framework and fat native
extension files, confirms the Debian metadata, and confirms that pip is
present. A GitHub-hosted runner cannot reach a phone on a private LAN, so the
final device test must be run from the WSL host connected to the phone.
