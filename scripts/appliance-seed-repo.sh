#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${LAB_APPLIANCE_SOURCE_REPO:-}" ]]; then
  echo "Error: LAB_APPLIANCE_SOURCE_REPO is not set." >&2
  exit 1
fi

if [[ -z "${LAB_APPLIANCE_REPO_ROOT:-}" ]]; then
  echo "Error: LAB_APPLIANCE_REPO_ROOT is not set." >&2
  exit 1
fi

if [[ -z "${LAB_APPLIANCE_SOURCE_CONFIG_PATH:-}" ]]; then
  echo "Error: LAB_APPLIANCE_SOURCE_CONFIG_PATH is not set." >&2
  exit 1
fi

SOURCE_REPO="${LAB_APPLIANCE_SOURCE_REPO}"
TARGET_REPO="${LAB_APPLIANCE_REPO_ROOT}"
SOURCE_CONFIG_PATH="${LAB_APPLIANCE_SOURCE_CONFIG_PATH}"
TARGET_CONFIG_PATH="${TARGET_REPO}/config/instance.json"

if [[ ! -d "${SOURCE_REPO}" ]]; then
  echo "Error: source repo '${SOURCE_REPO}' does not exist." >&2
  exit 1
fi

if [[ ! -f "${SOURCE_REPO}/flake.nix" ]]; then
  echo "Error: source repo '${SOURCE_REPO}' is missing flake.nix." >&2
  exit 1
fi

if [[ ! -f "${SOURCE_CONFIG_PATH}" ]]; then
  echo "Error: source config '${SOURCE_CONFIG_PATH}' does not exist." >&2
  exit 1
fi

if [[ -e "${TARGET_REPO}" && ! -d "${TARGET_REPO}" ]]; then
  echo "Error: target repo path '${TARGET_REPO}' exists but is not a directory." >&2
  exit 1
fi

if [[ ! -d "${TARGET_REPO}" ]]; then
  install -d -m 0755 "$(dirname "${TARGET_REPO}")"
  install -d -m 0755 "${TARGET_REPO}"
  cp -a "${SOURCE_REPO}/." "${TARGET_REPO}/"
  echo "Seeded appliance repo at ${TARGET_REPO}"
elif [[ ! -f "${TARGET_REPO}/flake.nix" ]]; then
  echo "Error: target repo '${TARGET_REPO}' exists but is missing flake.nix." >&2
  exit 1
else
  echo "Appliance repo already present at ${TARGET_REPO}"
fi

install -d -m 0755 "${TARGET_REPO}/config"

if [[ ! -f "${TARGET_CONFIG_PATH}" ]]; then
  install -m 0640 "${SOURCE_CONFIG_PATH}" "${TARGET_CONFIG_PATH}"
  echo "Installed appliance config at ${TARGET_CONFIG_PATH}"
else
  echo "Appliance config already present at ${TARGET_CONFIG_PATH}"
fi
