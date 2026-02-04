#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="$1"
CODE_BIN="$2"
shift 2
EXTENSIONS=("$@")

EXTENSIONS_DIR="$TEMPLATE_DIR/.vscode/extensions"
USER_DATA_DIR="$TEMPLATE_DIR/.config/Code"

mkdir -p "$EXTENSIONS_DIR"

for ext in "${EXTENSIONS[@]}"; do
  echo "Installing extension: $ext"
  HOME="$TEMPLATE_DIR" "$CODE_BIN" \
    --user-data-dir "$USER_DATA_DIR" \
    --extensions-dir "$EXTENSIONS_DIR" \
    --install-extension "$ext" \
    --force || true
done

echo "VS Code extensions installed"
