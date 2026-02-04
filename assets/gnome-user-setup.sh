#!/usr/bin/env bash
set -euo pipefail

if [ "${USER:-}" != "informatica" ]; then
  exit 0
fi

gsettings set org.gnome.shell favorite-apps "['com.mitchellh.ghostty.desktop', 'chromium-browser.desktop', 'code.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Calculator.desktop', 'org.gnome.TextEditor.desktop']"
gsettings set org.gnome.shell welcome-dialog-last-shown-version 9999
