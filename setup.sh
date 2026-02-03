#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${HOST:-}" ]]; then
  echo "Usage: HOST=<number> /etc/nixos/setup.sh" >&2
  exit 1
fi

HOST_ID=$(printf "%02d" "$HOST")
HOST_NAME="pc${HOST_ID}"
HOST_DIR="/etc/nixos/hosts/${HOST_NAME}"
HOST_FILE="${HOST_DIR}/default.nix"

if [[ ! -d "$HOST_DIR" ]]; then
  echo "Host directory not found: $HOST_DIR" >&2
  exit 1
fi

if [[ ! -f "$HOST_FILE" ]]; then
  echo "Host file not found: $HOST_FILE" >&2
  exit 1
fi

sudo nixos-generate-config --show-hardware-config > "${HOST_DIR}/hardware-configuration.nix"

sed -i "s/networking.hostName = \".*\";/networking.hostName = \"${HOST_NAME}\";/" "$HOST_FILE"

sed -i "s/address = \"10\.22\.9\.[0-9]\+\";/address = \"10.22.9.${HOST}\";/" "$HOST_FILE"

sudo nixos-rebuild switch --flake /etc/nixos#"${HOST_NAME}"

echo "Setup complete for ${HOST_NAME}."
