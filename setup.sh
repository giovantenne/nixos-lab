#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./setup.sh <pc-number>" >&2
  exit 1
fi

PC_NUMBER="$1"

if ! [[ "$PC_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Error: PC number must be numeric." >&2
  exit 1
fi

if [[ "$PC_NUMBER" -lt 1 || "$PC_NUMBER" -gt 31 ]]; then
  echo "Error: PC number must be between 1 and 31." >&2
  exit 1
fi

PC_ID=$(printf "%02d" "$PC_NUMBER")
PC_NAME="pc${PC_ID}"

# Extract settings from flake.nix
NETWORK_BASE=$(awk -F'"' '/networkBase =/ { print $2; exit }' flake.nix)
MASTER_HOST_NUMBER=$(awk '/masterHostNumber =/ { gsub(/;/, "", $3); print $3; exit }' flake.nix)
CACHE_KEY=$(awk -F'"' '/cachePublicKey =/ { print $2; exit }' flake.nix)

if [[ -z "$NETWORK_BASE" ]]; then
  echo "Error: networkBase not configured in flake.nix" >&2
  exit 1
fi

if [[ -z "$MASTER_HOST_NUMBER" ]]; then
  echo "Error: masterHostNumber not configured in flake.nix" >&2
  exit 1
fi

MASTER_STATIC_IP="${NETWORK_BASE}.${MASTER_HOST_NUMBER}"

# During netboot install the master may only be reachable on its DHCP address.
# Try the static IP first; fall back to the DHCP next-server (PXE boot source).
if curl -sf --connect-timeout 2 "http://${MASTER_STATIC_IP}:5000/nix-cache-info" > /dev/null 2>&1; then
  MASTER_IP="${MASTER_STATIC_IP}"
else
  # The PXE next-server is the master's DHCP address
  MASTER_IP=$(ip route | awk '/default/ { print $3; exit }')
  if [[ -z "$MASTER_IP" ]] || ! curl -sf --connect-timeout 2 "http://${MASTER_IP}:5000/nix-cache-info" > /dev/null 2>&1; then
    echo "Error: cannot reach Harmonia cache on ${MASTER_STATIC_IP} or ${MASTER_IP:-<no gateway>}" >&2
    exit 1
  fi
fi

echo "Using binary cache at ${MASTER_IP}:5000"

# Detect UEFI or BIOS
if [ -d /sys/firmware/efi ]; then
  echo "Error: UEFI boot not supported. Disable UEFI in BIOS settings." >&2
  exit 1
else
  echo "Detected BIOS boot"
fi

echo "Partitioning disk..."
sudo disko --mode disko ./disko-bios.nix

echo "Installing NixOS for ${PC_NAME}..."
sudo nixos-install --flake ".#${PC_NAME}" \
  --option substituters "http://${MASTER_IP}:5000" \
  --option trusted-public-keys "${CACHE_KEY}" \
  --no-channel-copy \
  --no-root-passwd
