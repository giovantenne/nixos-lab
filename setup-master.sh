#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for pc31 (master controller)
# Run this from the NixOS live USB with internet access

if [ ! -d /sys/firmware/efi ]; then
  echo "Error: UEFI boot required. Enable EFI in BIOS settings." >&2
  exit 1
fi

echo "Downloading disko config..."
curl -LO https://raw.githubusercontent.com/giovantenne/nixos-lab/master/disko-uefi.nix

echo "Partitioning disk..."
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko-uefi.nix

echo "Installing NixOS for pc31..."
sudo nixos-install --flake github:giovantenne/nixos-lab#pc31 --no-write-lock-file --no-root-passwd

echo "Installation complete. Rebooting..."
reboot
