# <img src="images/python3.png" alt="Logo" width="60" style="vertical-align: middle; margin-right: 8px;"> Python 3.12 for iOS (arm64) rootful
![Build & Publish](https://github.com/k1tty-xz/python3.12-ios-arm64-deb/actions/workflows/python3.12-ios-arm64.yml/badge.svg)  
![Version](https://img.shields.io/badge/Python-3.12.5-blue.svg)  
![Platform](https://img.shields.io/badge/Platform-iOS%2012.0+-lightgrey.svg)  
![License](https://img.shields.io/badge/License-MIT-green.svg)  
[![Contributions Welcome](https://img.shields.io/badge/Contributions-welcome-brightgreen.svg)](https://github.com/Tamior930/python3.12-ios-arm64/pulls)  


Python **3.12.5** for jailbroken iOS (arm64), packaged as a Debian `.deb` and built automatically with GitHub Actions.  

---

## Why this project?

Most jailbreak repos only provide outdated Python builds.  
This project compiles and packages the latest stable Python 3.12 for iOS so you can use modern features and libraries.  

---

## Features

- Python **3.12.5** with `pip` support  
- Full standard library, including `ssl` and `ctypes` (built against OpenSSL 1.1.1 and libffi)  
- Built and packaged automatically with GitHub Actions  
- Installable via repo or manual `.deb`  

---

## Installation

### Option 1: Install from Repo (recommended)

1. Add this repo to **Sileo/Zebra/Cydia**:  
   ```
   https://k1tty-xz.github.io/
   ```
2. Search for **Python 3.12 for iOS** and install.  

### Option 2: Manual Install

1. Download the latest `.deb`:  
   [GitHub Releases](https://github.com/k1tty-xz/python3.12-ios-arm64-deb/releases/latest)  
2. Transfer it to your device (Filza, AirDrop, SCP, etc.).  
3. Install via Filza or run:  
   ```sh
   dpkg -i /path/to/python3.12-package.deb
   ```

---

## After Installation

Check version:  
```sh
python3.12 -V
# Python 3.12.5
```

Enable `pip`:  
```sh
python3.12 -m ensurepip --upgrade
```

Install packages:  
```sh
pip3.12 install <package>
```

---

## Maintainer

Created and maintained by **k1tty-xz**.  
