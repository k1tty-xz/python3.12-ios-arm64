# Python and Frida for a jailbroken iPhone

These packages give a rootful jailbroken iPhone or iPad running iOS 14.8 or
newer a working Python 3.14 command line and an optional Frida installation.

They are Debian packages for a jailbreak terminal. They are not App Store apps.

## Install

Download the latest `python-ios-rootful-*` artifact from the
[GitHub Actions build](https://github.com/k1tty-xz/python-ios/actions/workflows/build.yml),
then copy both Debian packages to the phone:

```sh
scp python-ios_3.14.7-1_iphoneos-arm.deb root@PHONE:/tmp/
scp frida-ios_17.17.0-1_iphoneos-arm.deb root@PHONE:/tmp/
ssh root@PHONE 'dpkg -i /tmp/python-ios_3.14.7-1_iphoneos-arm.deb'
ssh root@PHONE 'dpkg -i /tmp/frida-ios_17.17.0-1_iphoneos-arm.deb'
```

Replace `PHONE` with the phone's hostname or IP address. The phone needs a
rootful jailbreak, `dpkg`, and `ca-certificates`.

The Frida package is optional; Python works without it.

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
Packages with native code need an arm64 iOS wheel built for this Python.

## Frida on the phone

The separate Frida package contains Frida 17.17.0. Install it after Python;
do not install `frida` or `frida-tools` from pip on the phone. The command line
tools and Python API use the phone's local Frida device directly:

```sh
frida-ps
```

The Python API is available directly in the phone's Python process:

```sh
python3 - <<'PY'
import frida

device = frida.get_local_device()
for process in device.enumerate_processes():
    print(process.pid, process.name)
PY
```

To control the phone from another computer, start the bundled server after
each boot and connect to port `27042`:

```sh
/usr/sbin/frida-server >/tmp/frida-server.log 2>&1 &
frida-ps -H 127.0.0.1:27042
```

The matching server and agent are included in the same package, so the Python
API and command line tools use a compatible Frida runtime.

## Limitations

iOS does not provide the process features used by Python's `subprocess` and
`multiprocessing` modules. Some desktop-only modules are unavailable, and the
phone generally cannot compile native Python extensions itself.

## Build

The packages are built by the
[GitHub Actions workflow](https://github.com/k1tty-xz/python-ios/actions/workflows/build.yml)
on macOS with Xcode. The build follows Python's
[iOS documentation](https://docs.python.org/3.14/using/ios.html) and
[PEP 730](https://peps.python.org/pep-0730/).
