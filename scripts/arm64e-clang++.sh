#!/bin/sh
set -eu

exec xcrun --sdk iphoneos${IOS_SDK_VERSION:-} clang++ \
    -target arm64-apple-ios${IPHONEOS_DEPLOYMENT_TARGET:-14.8} \
    -arch arm64e "$@"
