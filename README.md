# CPython for rootful iOS

This project builds CPython 3.14.7 as an arm64 command-line runtime for a
rootful iOS 14.8 jailbreak. The Debian package installs Python and pip under
`/usr/local`.

## Build

Run the **Build CPython for rootful iOS 14.8** GitHub Actions workflow. It uses
macOS 14 with Xcode 15.4 and produces:

```text
python-ios_3.14.7-1_iphoneos-arm.deb
```

The single build script downloads and verifies CPython, uses CPython's Apple
builder for the arm64 device target, builds the command-line launcher, stages
pip from the bundled wheel, and verifies the Debian package.

## Install

Copy the package and smoke test to the phone, then install and run the test:

```sh
scp python-ios_3.14.7-1_iphoneos-arm.deb root@PHONE:/tmp/
scp scripts/device-smoke.sh root@PHONE:/tmp/
ssh root@PHONE 'dpkg -i /tmp/python-ios_3.14.7-1_iphoneos-arm.deb'
ssh root@PHONE 'sh /tmp/device-smoke.sh'
```

The phone needs a rootful jailbreak, `dpkg`, and `ca-certificates`. Add the
runtime to the shell path if needed:

```sh
export PATH="/usr/local/bin:$PATH"
python3 --version
python3 my_script.py
python3 -m pip install --only-binary=:all: six
```

The package provides `python`, `python3`, `python3.14`, `pip`, `pip3`, and
`pip3.14`. The standard library is in `/usr/local/lib/python3.14`.

## Limits

CPython's official iOS support is for embedding in an application. This
project adapts that runtime for a jailbreak shell. iOS builds do not support
subprocess creation or multiprocessing, and some desktop modules are omitted.
Use pure-Python wheels; native packages need compatible iOS binaries.

The package architecture is `iphoneos-arm` (the rootful Debian name); the
executable architecture is arm64. A successful GitHub Actions build does not
replace the device smoke test.

## References

- [Python on iOS](https://docs.python.org/3.14/using/ios.html)
- [PEP 730: Adding iOS as a supported platform](https://peps.python.org/pep-0730/)
- [CPython Apple build driver](https://github.com/python/cpython/blob/v3.14.7/Apple/__main__.py)
- [Python initialization configuration](https://docs.python.org/3.14/c-api/init_config.html)
- [Apple Xcode system requirements](https://developer.apple.com/xcode/system-requirements)
