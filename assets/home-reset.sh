#!/usr/bin/env bash
set -euo pipefail

SNAPSHOTS_DIR="$1"
HOME_DIR="$2"
TEMPLATE_DIR="$3"

echo "Starting home reset..."

# Ensure snapshots directory exists
mkdir -p "$SNAPSHOTS_DIR"

# Check if home has any content (not first boot)
if [ "$(ls -A "$HOME_DIR" 2>/dev/null)" ]; then
  echo "Rotating snapshots..."
  
  # Remove oldest snapshot (5)
  if [ -d "$SNAPSHOTS_DIR/snapshot-5" ]; then
    btrfs subvolume delete "$SNAPSHOTS_DIR/snapshot-5" 2>/dev/null || rm -rf "$SNAPSHOTS_DIR/snapshot-5"
  fi
  
  # Rotate snapshots: 4->5, 3->4, 2->3, 1->2
  for i in 4 3 2 1; do
    next=$((i + 1))
    if [ -d "$SNAPSHOTS_DIR/snapshot-$i" ]; then
      mv "$SNAPSHOTS_DIR/snapshot-$i" "$SNAPSHOTS_DIR/snapshot-$next"
    fi
  done
  
  # Create new snapshot of current home
  echo "Creating snapshot of current home..."
  btrfs subvolume snapshot -r "$HOME_DIR" "$SNAPSHOTS_DIR/snapshot-1" 2>/dev/null || \
    cp -a "$HOME_DIR" "$SNAPSHOTS_DIR/snapshot-1"
fi

# Clear home directory content (keep the subvolume mount)
echo "Clearing home directory..."
find "$HOME_DIR" -mindepth 1 -delete 2>/dev/null || true

# Copy template to home
echo "Copying template to home..."
if [ -d "$TEMPLATE_DIR" ]; then
  cp -a "$TEMPLATE_DIR/." "$HOME_DIR/"
fi

# Ensure correct ownership
chown -R informatica:users "$HOME_DIR"
chmod -R u+rwX,go+rX "$HOME_DIR"
chmod 755 "$HOME_DIR"

# Ensure default ACLs so newly created folders stay writable
setfacl -R -m u:informatica:rwx "$HOME_DIR"
setfacl -R -m d:u:informatica:rwx "$HOME_DIR"

echo "Home reset completed"
