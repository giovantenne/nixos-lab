#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="$1"
GIT_NAME="$2"
GIT_EMAIL="$3"
XDG_USER_DIRS_BIN="$4"
ASSETS_DIR="$5"

echo "Creating home template..."

# Create template directory
mkdir -p "$TEMPLATE_DIR"

# Create .gitconfig
cat > "$TEMPLATE_DIR/.gitconfig" << EOF
[user]
    name = $GIT_NAME
    email = $GIT_EMAIL
EOF

# Create XDG standard directories using xdg-user-dirs
HOME="$TEMPLATE_DIR" "$XDG_USER_DIRS_BIN" --force

# Create config directories
mkdir -p "$TEMPLATE_DIR/.config"
mkdir -p "$TEMPLATE_DIR/.config/Code/User"
mkdir -p "$TEMPLATE_DIR/.local/share"

# Copy VS Code settings
cp "$ASSETS_DIR/vscode-settings.json" "$TEMPLATE_DIR/.config/Code/User/settings.json"

# Copy mimeapps.list
cp "$ASSETS_DIR/mimeapps.list" "$TEMPLATE_DIR/.config/mimeapps.list"

# Copy starship config
if [ -f "$ASSETS_DIR/starship.toml" ]; then
  cp "$ASSETS_DIR/starship.toml" "$TEMPLATE_DIR/.config/starship.toml"
fi

# GNOME favorites autostart (informatica only)
mkdir -p "$TEMPLATE_DIR/.config/autostart"
if [ -f "$ASSETS_DIR/autostart/gnome-favorites.desktop" ]; then
  cp "$ASSETS_DIR/autostart/gnome-favorites.desktop" "$TEMPLATE_DIR/.config/autostart/gnome-favorites.desktop"
fi
if [ -f "$ASSETS_DIR/set-gnome-favorites.sh" ]; then
  cp "$ASSETS_DIR/set-gnome-favorites.sh" "$TEMPLATE_DIR/.config/autostart/set-gnome-favorites.sh"
  chmod +x "$TEMPLATE_DIR/.config/autostart/set-gnome-favorites.sh"
fi

echo "Home template created successfully"
