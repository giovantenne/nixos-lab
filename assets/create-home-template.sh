#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="$1"
GIT_NAME="$2"
GIT_EMAIL="$3"
XDG_USER_DIRS_BIN="$4"

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
mkdir -p "$TEMPLATE_DIR/.local/share"

echo "Home template created successfully"
