#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Usage: ./install-pc99.sh [disk]" >&2
  echo "Example: ./install-pc99.sh /dev/sdb" >&2
  exit 1
fi

INSTALL_DISK="${1:-}"
FLAKE_REF="${FLAKE_REF:-github:giovantenne/nixos-lab}"
DISKO_URL="${DISKO_URL:-https://raw.githubusercontent.com/giovantenne/nixos-lab/master/disko-bios.nix}"
AVAILABLE_DISKS=()

prompt_input() {
  local PROMPT_TEXT="$1"
  local TARGET_VAR="$2"
  if [[ -r /dev/tty ]]; then
    read -r -p "$PROMPT_TEXT" "$TARGET_VAR" < /dev/tty
  else
    read -r -p "$PROMPT_TEXT" "$TARGET_VAR"
  fi
}

list_disks() {
  lsblk -dno PATH,SIZE,MODEL,TYPE | awk '$4=="disk" { printf "  %s  %s  %s\n", $1, $2, $3 }'
}

canonicalize_disk() {
  local RAW_DISK="$1"
  if [[ -z "$RAW_DISK" ]]; then
    echo ""
  elif [[ "$RAW_DISK" == /dev/* ]]; then
    echo "$RAW_DISK"
  else
    echo "/dev/$RAW_DISK"
  fi
}

is_available_disk() {
  local CANDIDATE="$1"
  local DISK
  for DISK in "${AVAILABLE_DISKS[@]}"; do
    if [[ "$DISK" == "$CANDIDATE" ]]; then
      return 0
    fi
  done
  return 1
}

# Detect UEFI or BIOS
if [ -d /sys/firmware/efi ]; then
  echo "Error: UEFI boot not supported. Disable UEFI in BIOS settings." >&2
  exit 1
else
  echo "Detected BIOS boot"
fi

mapfile -t AVAILABLE_DISKS < <(lsblk -dno PATH,TYPE | awk '$2=="disk" { print $1 }')

if [[ ${#AVAILABLE_DISKS[@]} -eq 0 ]]; then
  echo "Error: no installable disks detected." >&2
  exit 1
fi

if [[ -n "$INSTALL_DISK" ]]; then
  INSTALL_DISK=$(canonicalize_disk "$INSTALL_DISK")
  if ! is_available_disk "$INSTALL_DISK"; then
    echo "Error: disk '$INSTALL_DISK' is not available on this machine." >&2
    echo "Available disks:"
    list_disks
    exit 1
  fi
elif [[ ${#AVAILABLE_DISKS[@]} -eq 1 ]]; then
  INSTALL_DISK="${AVAILABLE_DISKS[0]}"
  echo "Only one disk detected, selecting: $INSTALL_DISK"
else
  echo "Available disks:"
  list_disks
  prompt_input "Choose install disk: " CHOSEN_DISK
  INSTALL_DISK=$(canonicalize_disk "$CHOSEN_DISK")
  if [[ -z "$INSTALL_DISK" ]]; then
    echo "Error: no disk selected." >&2
    exit 1
  fi
  if ! is_available_disk "$INSTALL_DISK"; then
    echo "Error: disk '$INSTALL_DISK' is not available on this machine." >&2
    exit 1
  fi
fi

echo "Selected disk: $INSTALL_DISK"
prompt_input "This will erase all data on $INSTALL_DISK. Type YES to continue: " CONFIRMATION
if [[ "$CONFIRMATION" != "YES" ]]; then
  echo "Installation cancelled."
  exit 1
fi

TEMP_DISKO_INPUT=$(mktemp)
TEMP_DISKO_FILE=$(mktemp)
trap 'rm -f "$TEMP_DISKO_INPUT" "$TEMP_DISKO_FILE"' EXIT

echo "Downloading disko config..."
curl -fsSL "$DISKO_URL" -o "$TEMP_DISKO_INPUT"
sed -E "s#device = \"[^\"]+\";#device = \"${INSTALL_DISK}\";#" "$TEMP_DISKO_INPUT" > "$TEMP_DISKO_FILE"

echo "Partitioning disk..."
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko "$TEMP_DISKO_FILE"

echo "Installing NixOS for pc99..."
sudo nixos-install --flake "${FLAKE_REF}#pc99" --no-write-lock-file --no-root-passwd

echo "Installation complete. Reboot with: reboot"
