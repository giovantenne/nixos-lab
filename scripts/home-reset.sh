#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: home-reset.sh <snapshots-dir> <home-dir> <template-dir> <owner>" >&2
  exit 1
fi

SNAPSHOTS_DIR="$1"
HOME_DIR="$2"
TEMPLATE_DIR="$3"
OWNER="$4"

# Validate template exists before doing anything destructive
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: template directory '$TEMPLATE_DIR' does not exist" >&2
  exit 1
fi

# Safety: ensure HOME_DIR is a real absolute path under /home
if [[ "$HOME_DIR" != /home/* ]]; then
  echo "Error: home directory must be under /home/" >&2
  exit 1
fi

# If something goes wrong between delete and copy, log a critical error
trap 'echo "CRITICAL: home-reset failed, home may be incomplete" >&2' ERR

echo "Starting home reset..."

# Ensure snapshots directory exists
mkdir -p "$SNAPSHOTS_DIR"

# Check if home has any content (not first boot)
if [ -n "$(find "$HOME_DIR" -maxdepth 1 -mindepth 1 -print -quit 2>/dev/null)" ]; then
  echo "Rotating snapshots..."

  # Remove oldest snapshot (5)
  if [ -d "$SNAPSHOTS_DIR/snapshot-5" ]; then
    btrfs subvolume delete "$SNAPSHOTS_DIR/snapshot-5" 2>/dev/null || rm -rf "$SNAPSHOTS_DIR/snapshot-5"
  fi

  # Rotate snapshots: 4->5, 3->4, 2->3, 1->2
  for I in 4 3 2 1; do
    NEXT=$((I + 1))
    if [ -d "$SNAPSHOTS_DIR/snapshot-$I" ]; then
      mv "$SNAPSHOTS_DIR/snapshot-$I" "$SNAPSHOTS_DIR/snapshot-$NEXT"
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
cp -a "$TEMPLATE_DIR/." "$HOME_DIR/"

# Ensure correct ownership
chown -R "$OWNER" "$HOME_DIR"
chmod 700 "$HOME_DIR"

echo "Home reset completed"
