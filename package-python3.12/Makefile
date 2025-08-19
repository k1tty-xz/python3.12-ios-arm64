# Theos layout-only package for Python 3.12 runtime

export TARGET := iphone:clang:latest:12.0
export ARCHS := arm64

include $(THEOS)/makefiles/common.mk

# Layout-only target (no tweak code compiled)
TWEAK_NAME = Python312Runtime
Python312Runtime_FILES =

# No target processes — this is a pure runtime package
# INSTALL_TARGET_PROCESSES =

include $(THEOS_MAKE_PATH)/tweak.mk

# Package metadata
PACKAGE_VERSION = 1.0
PACKAGE_NAME = Python 3.12 for iOS (arm64)
PACKAGE_DESCRIPTION = Minimal tweak that loads into SpringBoard and logs on launch (arm64, iOS 12+)
PACKAGE_AUTHOR = k1tty-xz
PACKAGE_IDENTIFIER = com.k1tty-xz.python3.12

after-install::
	# No processes to restart for a runtime package; keep as no-op
	true

