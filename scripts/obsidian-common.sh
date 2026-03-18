#!/usr/bin/env bash
# obsidian-common.sh — Shared functions for vault scripts
# Usage: source this file, do not execute directly

_vault_root() {
  echo "${AGMO_VAULT_ROOT:-/Users/sungmincho/sungmin}"
}

_ensure_dir() {
  local dir="$1"
  if [ -z "$dir" ]; then
    _log ERROR "_ensure_dir: directory path is empty"
    return 1
  fi
  mkdir -p "$dir"
}

_file_exists() {
  [ -f "$1" ]
}

_slugify() {
  local input="$1"
  # Trim leading/trailing whitespace
  input="$(echo "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  # Remove filesystem-forbidden characters: / \ : * ? " < > |
  input="$(echo "$input" | sed 's/[\/\\:*?"<>|]//g')"
  echo "$input"
}

_today() {
  date +%Y-%m-%d
}

_log() {
  local level="$1"
  local message="$2"
  echo "[$level] $message" >&2
}
