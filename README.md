# Python for rootful iOS

Run Python 3.14.7 on a rootful jailbroken iPhone or iPad running iOS 14.8 or
newer.

This project creates a Debian package containing Python, the standard library,
and pip. It is made for a jailbreak terminal and is not an App Store app.

## Get Python

Builds are made by GitHub Actions on macOS. You do not need a Mac or Xcode.

1. Open the [latest workflow run](https://github.com/k1tty-xz/python-ios/actions/workflows/build.yml).
2. Download its artifact named `python-ios-rootful-*`.
3. Extract `python-ios_3.14.7-1_iphoneos-arm.deb` from the downloaded archive.

## Install it

Replace `PHONE` with the phone's hostname or IP address:

```sh
scp python-ios_3.14.7-1_iphoneos-arm.deb root@PHONE:/tmp/
ssh root@PHONE 'dpkg -i /tmp/python-ios_3.14.7-1_iphoneos-arm.deb'
```

The phone must have a rootful jailbreak, `dpkg`, and `ca-certificates`.

Add Python to the current shell:

```sh
export PATH="/usr/local/bin:$PATH"
```

## Use it

```sh
python3 --version
python3
python3 my_script.py
python3 -c 'print(2 + 2)'
python3 -m pip install --only-binary=:all: six
```

The package installs `python`, `python3`, `python3.14`, `pip`, `pip3`, and
`pip3.14` in `/usr/local/bin`.

## What to expect

Python itself, its iOS standard library, and pure-Python packages work as
expected. Packages containing native code need an arm64 iOS wheel or another
binary built specifically for this environment.

iOS does not provide the process features used by Python's `subprocess` and
`multiprocessing` modules. Some desktop-only modules are also unavailable, and
packages that need to compile native code on the phone generally will not work.

## Build the package yourself

To create a new package, run the **Build CPython for rootful iOS 14.8** workflow.
The workflow builds the arm64 runtime and uploads the Debian package when it
finishes.

The build uses CPython's official iOS support and follows Apple's deployment
requirements for iOS 14.8:

- [Python on iOS](https://docs.python.org/3.14/using/ios.html)
- [PEP 730](https://peps.python.org/pep-0730/)
- [Apple Xcode system requirements](https://developer.apple.com/xcode/system-requirements)
