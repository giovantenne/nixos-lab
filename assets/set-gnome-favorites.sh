#!/usr/bin/env bash
set -euo pipefail

TARGET="['com.mitchellh.ghostty.desktop', 'chromium-browser.desktop', 'code.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Calculator.desktop', 'org.gnome.TextEditor.desktop']"

for _ in $(seq 1 10); do
  gsettings set org.gnome.shell favorite-apps "$TARGET" && break
  sleep 1
done
