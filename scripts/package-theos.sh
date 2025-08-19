#!/usr/bin/env bash
# Package the staged CPython 3.12 runtime using Theos (layout-only)
# - Requires: THEOS environment variable set, or $HOME/theos present
# - Input payload: work/stage/usr
# - Output: package-python3.12/packages/*.deb
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_DIR="$REPO_ROOT/package-python3.12"
STAGED_USR="$REPO_ROOT/work/stage/usr"
LAYOUT_DIR="$PKG_DIR/layout"

if [ ! -d "$STAGED_USR" ]; then
  echo "Error: staged payload not found: $STAGED_USR" >&2
  echo "Build first: make deps && make python" >&2
  exit 1
end
fi

# Ensure Theos is available
if [ -z "${THEOS:-}" ]; then
  if [ -d "$HOME/theos" ]; then
    export THEOS="$HOME/theos"
  else
    echo "Error: THEOS not set and $HOME/theos not found." >&2
    echo "Set THEOS to your Theos path, e.g.: export THEOS=~/theos" >&2
    exit 2
  fi
fi

# Stage payload into Theos layout
rm -rf "$LAYOUT_DIR/usr" || true
mkdir -p "$LAYOUT_DIR"
cp -a "$STAGED_USR" "$LAYOUT_DIR/usr"

# Build package
make -C "$PKG_DIR" package

echo "Built packages in: $PKG_DIR/packages"
