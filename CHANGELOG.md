# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2025-12-02

### Added
- **Jailbreak Support**: Added `entitlements.plist` for proper iOS permissions (`platform-application`, `task_for_pid-allow`).
- **Cross-Compilation**: Added `python-configure.patch` and `config.site` to fix build issues on iOS.
- **User Experience**: Added automatic PATH configuration via `/etc/profile.d/python3.sh`.
- **Documentation**: Added post-install instructions for `pip` and PATH setup.

### Changed
- **Requirements**: Bumped minimum iOS version to 14.5.
- **Packaging**: Updated package metadata to reflect that `pip` is installed on-demand.
- **Assets**: Updated AppIcon to a new standard design.
- **CI/CD**: Optimized build workflow (reduced timeout, better artifact naming).
- **Build System**: Improved validation for build tools and environment variables.

### Removed
- **Assets**: Removed unused icon variants.
- **Legacy**: Removed redundant `python` symlink (standardized on `python3`).
