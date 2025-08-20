# Python 3.12 for iOS

[![Build Status](https://github.com/k1tty-xz/python3.12-ios-arm64/actions/workflows/python3.12-ios-arm64.yml/badge.svg)](https://github.com/k1tty-xz/python3.12-ios-arm64/actions)
[![License](https://img.shields.io/github/license/k1tty-xz/python3.12-ios-arm64)](LICENSE)
[![iOS](https://img.shields.io/badge/iOS-14.5%2B-black?logo=apple)](https://apple.com)

A fully-featured, stable port of **Python 3.12** for jailbroken iOS devices (arm64). This project provides a Debian package (`.deb`) that installs a complete Python environment, optimized for mobile usage and development.

## Features

-   **Python 3.12**: Full standard library with SSL/TLS support (OpenSSL 1.1.1).
-   **Package Management**: `pip` available via `python3 -m ensurepip`.
-   **Automatic Setup**: Configures PATH automatically upon installation.

## Installation

Add the repository to your package manager (Sileo, Zebra, Cydia):

```
https://k1tty-xz.github.io/repo/
```

Then search for **Python 3.12 (k1tty)** and install.

### Post-Installation

After installation, you may need to reload your shell profile or start a new terminal session for the PATH to update:

```bash
source /etc/profile
```

To install pip:

```bash
python3 -m ensurepip
pip3 install --upgrade pip
```

## Build Instructions

To build this package yourself, you can use the provided GitHub Actions workflow or build locally on macOS.

### Prerequisites

-   macOS (for Xcode toolchain)
-   Xcode Command Line Tools
-   Homebrew (for dependencies like `ldid`, `automake`)

### Local Build

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/k1tty-xz/python3.12-ios-arm64.git
    cd python3.12-ios-arm64
    ```

2.  **Install build tools**:
    ```bash
    bash scripts/install-build-tools.sh
    ```

3.  **Set up environment variables**:
    ```bash
    export PY_VER=3.12.5
    export LIBFFI_VER=3.4.4
    export MIN_IOS=14.5
    export PYTHON_FOR_BUILD=$(which python3.12 || which python3)
    ```

4.  **Build and Package**:
    ```bash
    # This will download sources, compile, and create the .deb
    make all
    ```

    The resulting `.deb` file will be in the `work/` directory.

## Project Structure

-   `scripts/`: Build scripts and patches.
    -   `build-python.sh`: Main build logic for CPython.
    -   `entitlements.plist`: Entitlements for code signing.
    -   `python-configure.patch`: Patch for cross-compilation support.
-   `debian/`: Debian packaging metadata (`control`, `prerm`, etc.).
-   `.github/`: CI/CD configuration.

## Credits

-   **k1tty-xz**: Main maintainer.
-   **Python Software Foundation**: For the Python programming language.
-   **OpenSSL**: For the crypto library.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
