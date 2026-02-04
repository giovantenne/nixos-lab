#!/usr/bin/env bash
set -euo pipefail

gsettings set org.gnome.shell favorite-apps "['com.mitchellh.ghostty.desktop', 'chromium-browser.desktop', 'code.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Calculator.desktop', 'org.gnome.TextEditor.desktop']"
