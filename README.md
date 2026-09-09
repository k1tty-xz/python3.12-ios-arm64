# Python for a jailbroken iPhone

These packages give a rootful jailbroken iPhone or iPad running iOS 14.8 or
newer a working Python 3.14 command line.

They are Debian packages for a jailbreak terminal. They are not App Store apps.

## Install

Download the latest `python-ios-rootful-*` artifact from the
[GitHub Actions build](https://github.com/k1tty-xz/python-ios/actions/workflows/build.yml),
then copy the Debian package to the phone:

```sh
scp python-ios_3.14.7-1_iphoneos-arm.deb root@PHONE:/tmp/
ssh root@PHONE 'dpkg -i /tmp/python-ios_3.14.7-1_iphoneos-arm.deb'
```

Replace `PHONE` with the phone's hostname or IP address. The phone needs a
rootful jailbreak, `dpkg`, and `ca-certificates`.

Add the installed commands to the current shell:

```sh
export PATH="/usr/local/bin:$PATH"
```

## Python

```sh
python3 --version
python3 my_script.py
python3 -c 'print(2 + 2)'
python3 -m pip install --only-binary=:all: six
```

Python, its standard library, pip, and pure-Python packages run on the phone.
This rootful build also enables `subprocess`, which pip needs for build
isolation and source packages that contain only Python. Packages with native
code still need an arm64 iOS wheel built for this Python; desktop and Linux
wheels cannot run on iOS.

## Limitations

`multiprocessing` and some desktop-only modules remain unavailable on iOS. The
phone generally cannot compile native Python extensions itself, so native
packages must be installed from compatible iOS wheels.

## Build

The package is built by the
[GitHub Actions workflow](https://github.com/k1tty-xz/python-ios/actions/workflows/build.yml)
on macOS with Xcode. The build follows Python's
[iOS documentation](https://docs.python.org/3.14/using/ios.html) and
[PEP 730](https://peps.python.org/pep-0730/).
