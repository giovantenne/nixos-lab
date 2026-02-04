#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="$1"
GIT_NAME="$2"
GIT_EMAIL="$3"

echo "Creating home template..."

# Create template directory
mkdir -p "$TEMPLATE_DIR"

# Create .gitconfig
cat > "$TEMPLATE_DIR/.gitconfig" << EOF
[user]
    name = $GIT_NAME
    email = $GIT_EMAIL
EOF

# Create XDG standard directories
mkdir -p "$TEMPLATE_DIR/Desktop"
mkdir -p "$TEMPLATE_DIR/Documents"
mkdir -p "$TEMPLATE_DIR/Downloads"
mkdir -p "$TEMPLATE_DIR/Music"
mkdir -p "$TEMPLATE_DIR/Pictures"
mkdir -p "$TEMPLATE_DIR/Public"
mkdir -p "$TEMPLATE_DIR/Templates"
mkdir -p "$TEMPLATE_DIR/Videos"

# Create config directories
mkdir -p "$TEMPLATE_DIR/.config"
mkdir -p "$TEMPLATE_DIR/.local/share"

echo "Home template created successfully"
