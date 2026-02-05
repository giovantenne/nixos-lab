#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
secret_key="${repo_root}/secret-key"

if [ ! -f "${secret_key}" ]; then
  echo "Missing ${secret_key}. Copy the secret-key into the repo root." >&2
  exit 1
fi

config_file=$(mktemp)
trap 'rm -f "${config_file}"' EXIT

cat > "${config_file}" <<EOF
bind = "[::]:5000"
sign_key_paths = ["${secret_key}"]
EOF

CONFIG_FILE="${config_file}" exec nix run nixpkgs#harmonia
