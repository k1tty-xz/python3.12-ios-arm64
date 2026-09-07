# CPython for rootful iOS 14.8

Build CPython 3.14.7 as an **arm64 command-line runtime** for a rootful iOS
14.8 jailbreak. The Debian package installs Python, its available iOS standard
library, and pip under `/usr/local`.

Arm64 is CPython's supported physical-device architecture and also runs on
arm64e-capable phones. This runtime uses one arm64 build and upstream binary
dependencies; it does not need a second arm64e build or universal binaries.

## Build

Run the **Build CPython for rootful iOS 14.8** GitHub Actions workflow, or push
a change to its build inputs. The workflow uses macOS 14 with Xcode 15.4 to
retain an iOS 14.8 deployment target. It produces:

```text
python-ios_3.14.7-1_iphoneos-arm.deb
```

`scripts/build.sh` verifies the pinned source checksum, invokes CPython's
Apple builder for the build machine and arm64 device, and packages the result.
The small `scripts/python.c` launcher uses Python's initialization API and
keeps stdout/stderr connected to the terminal. Upstream's iOS install provides
embedding resources, so the launcher is compiled explicitly. Pip is installed
offline from CPython's bundled wheel using the build-machine Python.

CI checks package metadata, standard-library placement, pip, required native
extensions, arm64 architecture, and code signatures. **A successful build is
not a device test.** Run the smoke test below on the target phone to verify
startup, imports, terminal I/O, exit codes, and a package installation.

## Install and test

The phone needs a rootful jailbreak, `dpkg`, and `ca-certificates`. From WSL
on the phone's network, after downloading the Actions artifact:

```sh
scp python-ios_3.14.7-1_iphoneos-arm.deb root@192.168.1.244:/tmp/
ssh root@192.168.1.244 'dpkg -i /tmp/python-ios_3.14.7-1_iphoneos-arm.deb'
scp scripts/device-smoke.sh root@192.168.1.244:/tmp/
ssh root@192.168.1.244 'sh /tmp/device-smoke.sh'
```

If `dpkg` reports a missing `ca-certificates` dependency, install it with the
phone's package manager, then rerun the installation. The post-install script
links the existing certificate bundle only when `/etc/ssl/cert.pem` is absent.

```sh
/usr/local/bin/python3
/usr/local/bin/python3 my_script.py
/usr/local/bin/python3 -m pip install --only-binary=:all: six
```

The package provides `python`, `python3`, `python3.14`, `pip`, `pip3`, and
`pip3.14` in `/usr/local/bin`. The standard library lives at
`/usr/local/lib/python3.14`, and the runtime framework at
`/usr/local/Frameworks/Python.framework`.

## Platform limits and official references

CPython officially supports iOS through embedding in an application. This
repository adapts that runtime for a jailbreak shell; it is not an App Store
bundle or a desktop Python port. Upstream disables subprocess creation,
multiprocessing, and several desktop modules on iOS. `venv` with pip bootstrap
and source-package builds that launch subprocesses are therefore unavailable.
Use pure-Python wheels; native packages additionally need compatible iOS
binaries and signing. The package architecture is `iphoneos-arm`, the rootful
Debian architecture, even though the executable itself is arm64.

The implementation follows these primary references:

- [Python on iOS](https://docs.python.org/3.14/using/ios.html) and
  [PEP 730](https://peps.python.org/pep-0730/): supported runtime and platform limits.
- [CPython 3.14.7 Apple builder](https://github.com/python/cpython/blob/v3.14.7/Apple/__main__.py),
  [configure rules](https://github.com/python/cpython/blob/v3.14.7/configure.ac), and
  [install rules](https://github.com/python/cpython/blob/v3.14.7/Makefile.pre.in):
  device target, dependencies, and installed framework layout.
- [Python initialization configuration](https://docs.python.org/3.14/c-api/init_config.html):
  command-line arguments, terminal logging, and `Py_RunMain`.
- [ensurepip availability](https://docs.python.org/3.14/library/ensurepip.html) and
  [pip install options](https://pip.pypa.io/en/stable/cli/pip_install/): offline
  bootstrap on the build machine and wheel-only installation on the phone.
- [Apple Xcode requirements](https://developer.apple.com/xcode/system-requirements) and
  [GitHub macOS 14 runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-14-arm64-Readme.md):
  Xcode 15.4 and iOS 14 deployment support.
- [Theos packaging](https://theos.dev/docs/packaging) and
  [arm64e deployment](https://theos.dev/docs/arm64e-deployment): jailbreak package
  architecture and when an arm64e ABI is needed.
