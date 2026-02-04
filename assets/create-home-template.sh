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

# Create basic directories
mkdir -p "$TEMPLATE_DIR/Documenti"
mkdir -p "$TEMPLATE_DIR/Progetti"
mkdir -p "$TEMPLATE_DIR/.config"
mkdir -p "$TEMPLATE_DIR/.local/share"

echo "Home template created successfully"
