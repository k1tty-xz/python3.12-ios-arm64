This directory packages the CPython 3.12 runtime into a single .deb using Theos.

Build (CI):
- The workflow builds runtime (OpenSSL, libffi, CPython) and copies work/stage/usr here under layout/usr before calling `make package`.

Build (local):
- make deps && make python
- cp -a work/stage/usr package-python3.12/layout/usr
- cd package-python3.12 && make package

Output: package-python3.12/packages/*.deb

