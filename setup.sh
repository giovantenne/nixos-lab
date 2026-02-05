#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./setup.sh <pc-number>" >&2
  exit 1
fi

PC_NUMBER="$1"

if ! [[ "$PC_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "PC number must be numeric." >&2
  exit 1
fi

PC_ID=$(printf "%02d" "$PC_NUMBER")
PC_NAME="pc${PC_ID}"

# Extract masterIp from flake.nix
MASTER_IP=$(grep 'masterIp' flake.nix | sed 's/.*"\(.*\)".*/\1/')

if [[ "$MASTER_IP" == "MASTER_IP" || -z "$MASTER_IP" ]]; then
  echo "Error: masterIp not configured in flake.nix" >&2
  exit 1
fi

# Detect UEFI or BIOS
if [ -d /sys/firmware/efi ]; then
  echo "Detected UEFI boot"
  DISKO_CONFIG="./disko-uefi.nix"
else
  echo "Detected BIOS boot"
  DISKO_CONFIG="./disko-bios.nix"
fi

sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko "$DISKO_CONFIG"
sudo nixos-install --flake .#"${PC_NAME}" --substituter "http://${MASTER_IP}:5000" --no-root-passwd
