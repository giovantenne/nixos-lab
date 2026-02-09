#!/usr/bin/env bash
# Set GNOME favorites, theme, and dismiss welcome dialog for lab users
set -euo pipefail

# Only run for lab users
case "${USER:-}" in
  informatica|admin|docente) ;;
  *) exit 0 ;;
esac

# Wait for GNOME shell to be ready
sleep 2

# Dock and shell settings
if [ "${USER:-}" = "informatica" ]; then
  gsettings set org.gnome.shell favorite-apps \
    "['com.mitchellh.ghostty.desktop', 'chromium-browser.desktop', 'code.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.TextEditor.desktop']"
else
  current_favorites=$(gsettings get org.gnome.shell favorite-apps)
  updated_favorites=$(python3 - "$current_favorites" << 'PY'
import ast
import sys

raw = sys.argv[1].strip()
if raw.startswith("@as "):
    raw = raw[4:]

favorites = ast.literal_eval(raw)
if "io.veyon.desktop" not in favorites:
    if "code.desktop" in favorites:
        favorites.insert(favorites.index("code.desktop") + 1, "io.veyon.desktop")
    else:
        favorites.append("io.veyon.desktop")
print(repr(favorites))
PY
  )
  gsettings set org.gnome.shell favorite-apps "$updated_favorites"
fi

gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false

gsettings set org.gnome.shell welcome-dialog-last-shown-version '9999'

