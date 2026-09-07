#!/usr/bin/env python3
"""Run CPython's tagged Apple builder with the iOS 14.8 target."""

from __future__ import annotations

import importlib.util
import os
from pathlib import Path


source_dir = Path(os.environ["CPYTHON_SOURCE_DIR"]).resolve()
apple_main = source_dir / "Apple" / "__main__.py"
spec = importlib.util.spec_from_file_location("cpython_apple_build", apple_main)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load CPython Apple builder: {apple_main}")

builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)

# CPython's release builder uses these host names to select the SDK and output
# directories. The version suffix is the documented way to set the minimum
# iOS version in configure.
builder.HOSTS["iOS"] = {
    "ios-arm64": {
        "arm64-apple-ios14.8": "arm64-iphoneos",
    },
    "ios-arm64_x86_64-simulator": {
        "arm64-apple-ios14.8-simulator": "arm64-iphonesimulator",
        "x86_64-apple-ios14.8-simulator": "x86_64-iphonesimulator",
    },
}

# The upstream fast CI suite includes live network tests. They can fail for a
# transient reason unrelated to the build (the GitHub runner's FTP address is
# rejected by the test server), so make this release build deterministic while
# retaining the rest of the official simulator test suite.
original_run = builder.run


def run_without_network_tests(command, **kwargs):
    command = list(command)
    if "--" in command:
        test_args = command[command.index("--") + 1 :]
        if "test" in test_args and "-u-network" not in test_args:
            command.append("-u-network")
    return original_run(command, **kwargs)


builder.run = run_without_network_tests

os.chdir(source_dir)
builder.main()
