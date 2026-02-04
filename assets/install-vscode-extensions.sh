#!/usr/bin/env bash
set -euo pipefail

EXTENSIONS_DIR="$1"
CODE_BIN="$2"
shift 2
EXTENSIONS=("$@")

mkdir -p "$EXTENSIONS_DIR"

for ext in "${EXTENSIONS[@]}"; do
  echo "Installing extension: $ext"
  "$CODE_BIN" --extensions-dir "$EXTENSIONS_DIR" --install-extension "$ext" --force || true
done

echo "VS Code extensions installed"
