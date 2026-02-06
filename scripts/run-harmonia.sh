#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SECRET_KEY="${REPO_ROOT}/secret-key"

if [ ! -f "${SECRET_KEY}" ]; then
  echo "Missing ${SECRET_KEY}. Copy the secret-key into the repo root." >&2
  exit 1
fi

CONFIG_FILE=$(mktemp)
trap 'rm -f "${CONFIG_FILE}"' EXIT

cat > "${CONFIG_FILE}" <<EOF
bind = "[::]:5000"
sign_key_paths = ["${SECRET_KEY}"]
EOF

# Run without exec so the trap fires on exit
CONFIG_FILE="${CONFIG_FILE}" nix run nixpkgs#harmonia
