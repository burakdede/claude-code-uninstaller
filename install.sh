#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_TARGET="${INSTALL_TARGET:-$HOME/.local/bin}"
TARGET_NAME="${TARGET_NAME:-cc-uninstall}"
TARGET_PATH="$INSTALL_TARGET/$TARGET_NAME"

if [ ! -d "$INSTALL_TARGET" ]; then
    mkdir -p "$INSTALL_TARGET"
fi

cp "$SCRIPT_DIR/cc-uninstall.sh" "$TARGET_PATH"
chmod +x "$TARGET_PATH"

echo "Installed $TARGET_NAME to $TARGET_PATH"
echo "Add $INSTALL_TARGET to your PATH if it's not already present."
