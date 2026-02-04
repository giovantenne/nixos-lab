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

sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./disko-config.nix
sudo nixos-install --flake .#"${PC_NAME}" --substituter http://10.22.9.31:8080 --no-substitutes
