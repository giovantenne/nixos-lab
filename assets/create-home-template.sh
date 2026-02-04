#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="$1"
GIT_NAME="$2"
GIT_EMAIL="$3"
XDG_USER_DIRS_BIN="$4"
ASSETS_DIR="$5"

echo "Creating home template..."

# Clean and recreate template directory
rm -rf "$TEMPLATE_DIR"
mkdir -p "$TEMPLATE_DIR"

# Create .bashrc that sources system profile
cat > "$TEMPLATE_DIR/.bashrc" << 'EOF'
# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi
EOF

# Create .profile for login shells
cat > "$TEMPLATE_DIR/.profile" << 'EOF'
# Source bashrc
if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
EOF

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
mkdir -p "$TEMPLATE_DIR/.config/Code/User/globalStorage"
mkdir -p "$TEMPLATE_DIR/.local/share"

# Copy VS Code settings
cp "$ASSETS_DIR/vscode-settings.json" "$TEMPLATE_DIR/.config/Code/User/settings.json"

# Copy VS Code storage (UI state - hide chat sidebar)
cp "$ASSETS_DIR/vscode-storage.json" "$TEMPLATE_DIR/.config/Code/User/globalStorage/storage.json"

# Copy mimeapps.list
cp "$ASSETS_DIR/mimeapps.list" "$TEMPLATE_DIR/.config/mimeapps.list"

echo "Home template created successfully"
