# Makefile orchestrating iOS (arm64) Python build and Theos packaging
#
# Usage examples:
#   make deps            # build OpenSSL and libffi
#   make python          # build CPython and stage files (work/stage/usr)
#   make package         # copy staged files into Theos layout and package
#   make all             # deps + python + package
#
SHELL := /bin/bash

.PHONY: all deps openssl libffi python package clean distclean

all: deps python package

# ---- Dependencies ----

deps: openssl libffi

openssl:
	bash scripts/build-openssl.sh

libffi:
	bash scripts/build-libffi.sh

# ---- Build CPython ----

python:
	bash scripts/build-python.sh

# ---- Package (.deb) using Theos layout ----

package:
	bash scripts/package-theos.sh

# ---- Housekeeping ----

clean:
	rm -rf work/stage work/pkgroot || true

distclean:
	rm -rf work || true

