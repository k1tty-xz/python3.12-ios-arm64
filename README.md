# Python for iOS

Python 3.14 for an iPhone or iPad with a rootful jailbreak running iOS 14.8
or newer.
It installs as a normal command-line program under `/usr/local`.

## Install

1. Download the latest `python-ios-rootful-*` artifact from the
   [GitHub Actions builds](https://github.com/k1tty-xz/python-ios/actions/workflows/build.yml).
2. Copy the package to the phone and install it:

   ```sh
   scp python-ios_*.deb root@PHONE:/tmp/python-ios.deb
   ssh root@PHONE 'dpkg -i /tmp/python-ios.deb'
   ```

   Replace `PHONE` with the phone's hostname or IP address. The phone needs a
   rootful jailbreak, `dpkg`, and `ca-certificates`.

3. If the command is not found, add `/usr/local/bin` to the current shell:

   ```sh
   export PATH="/usr/local/bin:$PATH"
   ```

## Use

```sh
python3 --version
python3 my_script.py
python3 -m pip --version
python3 -m pip install six
```

The package includes Python, its standard library, and pip. `subprocess` is
enabled so pip can build and install pure-Python packages on the phone.
Packages with native code need a wheel built for iOS arm64 and this Python;
Linux and macOS wheels cannot run on iOS. The phone generally cannot compile
those extensions itself.

This project builds one arm64 device package on macOS with Apple's Xcode and
CPython's official [iOS build](https://docs.python.org/3.14/using/ios.html).
