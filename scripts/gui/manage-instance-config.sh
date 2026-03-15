#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  lab-gui-config status
  lab-gui-config list
  lab-gui-config backup [name-or-path]
  lab-gui-config restore <backup-name-or-path>
EOF
}

ensure_suffix() {
  local NAME="$1"

  if [[ "${NAME}" == *.json ]]; then
    printf '%s\n' "${NAME}"
    return 0
  fi

  printf '%s.json\n' "${NAME}"
}

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

resolve_backup_path() {
  local INPUT="$1"

  if [[ -f "${INPUT}" ]]; then
    printf '%s\n' "${INPUT}"
    return 0
  fi

  if [[ -f "${BACKUPS_DIR}/${INPUT}" ]]; then
    printf '%s\n' "${BACKUPS_DIR}/${INPUT}"
    return 0
  fi

  echo "Error: backup '${INPUT}' not found." >&2
  return 1
}

validate_candidate() {
  local CONFIG_PATH="$1"

  if [[ ! -f "${VALIDATE_NIX}" ]]; then
    echo "Error: validate helper not found at '${VALIDATE_NIX}'." >&2
    return 1
  fi

  LAB_GUI_VALIDATE_CONFIG_PATH="${CONFIG_PATH}" \
    nix eval --impure --json --file "${VALIDATE_NIX}" >/dev/null
}

backup_current_config() {
  local DESTINATION="$1"

  if [[ ! -f "${INSTANCE_CONFIG_PATH}" ]]; then
    echo "Error: '${INSTANCE_CONFIG_PATH}' does not exist yet." >&2
    return 1
  fi

  install -d -m 0770 "${BACKUPS_DIR}"
  install -D -m 0640 "${INSTANCE_CONFIG_PATH}" "${DESTINATION}"
}

status_command() {
  local BACKUP_COUNT="0"

  if [[ -d "${BACKUPS_DIR}" ]]; then
    BACKUP_COUNT="$(find "${BACKUPS_DIR}" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')"
  fi

  printf 'Repo root: %s\n' "${REPO_ROOT}"
  printf 'GUI state dir: %s\n' "${STATE_DIR}"
  printf 'Instance config path: %s\n' "${INSTANCE_CONFIG_PATH}"
  printf 'Validate helper: %s\n' "${VALIDATE_NIX}"
  printf 'Instance config present: %s\n' "$([[ -f "${INSTANCE_CONFIG_PATH}" ]] && echo yes || echo no)"
  printf 'Automatic/manual backups: %s\n' "${BACKUP_COUNT}"

  if command -v systemctl >/dev/null 2>&1; then
    printf 'Service status: %s\n' "$(systemctl is-active lab-gui-backend 2>/dev/null || echo unknown)"
  fi
}

list_command() {
  if [[ ! -d "${BACKUPS_DIR}" ]]; then
    echo "No backups found."
    return 0
  fi

  find "${BACKUPS_DIR}" -maxdepth 1 -type f -name '*.json' -printf '%f\n' | sort -r
}

backup_command() {
  local INPUT="${1:-}"
  local DESTINATION

  if [[ -z "${INPUT}" ]]; then
    DESTINATION="${BACKUPS_DIR}/manual-$(timestamp).json"
  else
    INPUT="$(ensure_suffix "${INPUT}")"
    if [[ "${INPUT}" == */* ]]; then
      DESTINATION="${INPUT}"
    else
      DESTINATION="${BACKUPS_DIR}/${INPUT}"
    fi
  fi

  backup_current_config "${DESTINATION}"
  printf 'Backup created: %s\n' "${DESTINATION}"
}

restore_command() {
  local INPUT="$1"
  local SOURCE_PATH
  local SAFETY_BACKUP
  local TEMP_PATH

  SOURCE_PATH="$(resolve_backup_path "${INPUT}")"
  validate_candidate "${SOURCE_PATH}"

  if [[ -f "${INSTANCE_CONFIG_PATH}" ]]; then
    SAFETY_BACKUP="${BACKUPS_DIR}/pre-restore-$(timestamp).json"
    backup_current_config "${SAFETY_BACKUP}"
    printf 'Safety backup created: %s\n' "${SAFETY_BACKUP}"
  fi

  install -d -m 0770 "$(dirname "${INSTANCE_CONFIG_PATH}")"
  TEMP_PATH="$(mktemp "${INSTANCE_CONFIG_PATH}.tmp.XXXXXX")"
  trap 'rm -f "${TEMP_PATH}"' EXIT
  install -m 0640 "${SOURCE_PATH}" "${TEMP_PATH}"
  install -m 0640 "${TEMP_PATH}" "${INSTANCE_CONFIG_PATH}"
  rm -f "${TEMP_PATH}"
  trap - EXIT

  printf 'Restored config from: %s\n' "${SOURCE_PATH}"
  echo "Next step: sudo nixos-rebuild switch --flake ${REPO_ROOT}#<controller-host> --no-write-lock-file"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

COMMAND="$1"
shift

REPO_ROOT="${LAB_GUI_REPO_ROOT:-}"
STATE_DIR="${LAB_GUI_STATE_DIR:-/var/lib/lab-gui}"
INSTANCE_CONFIG_PATH="${LAB_GUI_INSTANCE_CONFIG:-${REPO_ROOT}/config/instance.json}"
VALIDATE_NIX="${LAB_GUI_VALIDATE_NIX:-${REPO_ROOT}/scripts/gui/validate-instance.nix}"
BACKUPS_DIR="${STATE_DIR}/backups"

if [[ -z "${REPO_ROOT}" ]]; then
  echo "Error: LAB_GUI_REPO_ROOT is not set." >&2
  exit 1
fi

case "${COMMAND}" in
  status)
    if [[ $# -ne 0 ]]; then
      usage
      exit 1
    fi
    status_command
    ;;
  list)
    if [[ $# -ne 0 ]]; then
      usage
      exit 1
    fi
    list_command
    ;;
  backup)
    if [[ $# -gt 1 ]]; then
      usage
      exit 1
    fi
    backup_command "${1:-}"
    ;;
  restore)
    if [[ $# -ne 1 ]]; then
      usage
      exit 1
    fi
    restore_command "$1"
    ;;
  *)
    usage
    exit 1
    ;;
esac
