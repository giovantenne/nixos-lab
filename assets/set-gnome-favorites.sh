#!/usr/bin/env bash
set -euo pipefail

TARGET="['com.mitchellh.ghostty.desktop', 'chromium-browser.desktop', 'code.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Calculator.desktop', 'org.gnome.TextEditor.desktop']"

GSETTINGS_BIN=$(command -v gsettings || true)
if [ -z "$GSETTINGS_BIN" ]; then
  exit 0
fi

for _ in $(seq 1 12); do
  "$GSETTINGS_BIN" set org.gnome.shell favorite-apps "$TARGET" || true
  CURRENT=$("$GSETTINGS_BIN" get org.gnome.shell favorite-apps || true)
  if [ "$CURRENT" = "$TARGET" ]; then
    break
  fi
  sleep 2
done
