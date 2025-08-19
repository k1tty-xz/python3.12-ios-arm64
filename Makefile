# Makefile orchestrating iOS (arm64) Python build and packaging
#
# Usage examples:
#   make deps           # build OpenSSL and libffi
#   make python         # build CPython and stage files
#   make package        # create the .deb from staged files
#   make all            # deps + python + package
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

# ---- Package (.deb) ----

package:
	bash scripts/package-deb.sh

# ---- Housekeeping ----

clean:
	rm -rf work/stage work/pkgroot || true

distclean:
	rm -rf work || true

