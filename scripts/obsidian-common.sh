#!/usr/bin/env bash
# obsidian-common.sh — Shared functions for vault scripts
# Usage: source this file, do not execute directly

_vault_root() {
  # Priority 1: environment variable
  if [ -n "${AGMO_VAULT_ROOT:-}" ]; then
    echo "$AGMO_VAULT_ROOT"
    return
  fi
  # Priority 2: ~/.agmo/config JSON field "vault_root"
  local config_path="$HOME/.agmo/config"
  if [ -f "$config_path" ]; then
    local val
    val=$(python3 -c "import json; print(json.load(open('$config_path')).get('vault_root',''))" 2>/dev/null || echo "")
    if [ -n "$val" ]; then
      echo "$val"
      return
    fi
  fi
  # Priority 3: empty string
  echo ""
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
