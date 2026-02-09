#!/usr/bin/env bash
# Set GNOME favorites, theme, and dismiss welcome dialog for lab users
set -euo pipefail

# Only run for lab users
case "${USER:-}" in
  informatica) ;;
  *) exit 0 ;;
esac

# Wait for GNOME shell to be ready
sleep 2

# Dock and shell settings
gsettings set org.gnome.shell favorite-apps \
  "['com.mitchellh.ghostty.desktop', 'chromium-browser.desktop', 'code.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.TextEditor.desktop']"

gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false

gsettings set org.gnome.shell welcome-dialog-last-shown-version '9999'

