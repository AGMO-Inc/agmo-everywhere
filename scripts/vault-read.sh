#!/usr/bin/env bash
# vault-read.sh — Read notes or backlinks from the Obsidian vault
# Usage: vault-read.sh <subcommand> --path <NOTE_PATH>
#   subcommands: read, backlinks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/obsidian-common.sh"

# --- Helpers ---

_cmd_read() {
  local NOTE_PATH=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path) NOTE_PATH="$2"; shift 2 ;;
      *) _log ERROR "Unknown argument: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$NOTE_PATH" ]]; then
    _log ERROR "Missing required argument: --path"
    exit 1
  fi

  local full_path
  full_path="$(_vault_root)/${NOTE_PATH}"

  if [[ ! -f "$full_path" ]]; then
    _log ERROR "File not found: $full_path"
    exit 1
  fi

  local output
  if output="$(obsidian read path="${NOTE_PATH}" 2>/dev/null)"; then
    echo "$output"
  else
    cat "$full_path"
  fi
}

_cmd_backlinks() {
  local NOTE_PATH=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path) NOTE_PATH="$2"; shift 2 ;;
      *) _log ERROR "Unknown argument: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$NOTE_PATH" ]]; then
    _log ERROR "Missing required argument: --path"
    exit 1
  fi

  # Extract note name (filename without .md extension)
  local NOTE_NAME
  NOTE_NAME="$(basename "${NOTE_PATH}" .md)"

  local output
  if output="$(obsidian backlinks file="${NOTE_NAME}" format=json 2>/dev/null)"; then
    echo "$output"
  else
    # Fallback: grep for wikilinks, then format as JSON array
    local vault_root
    vault_root="$(_vault_root)"

    local matches
    matches="$(grep -rli --include="*.md" "\[\[.*${NOTE_NAME}.*\]\]" "$vault_root" 2>/dev/null || true)"

    # Build JSON array from matches
    local json="["
    local first=1
    while IFS= read -r match_path; do
      [[ -z "$match_path" ]] && continue
      # Convert absolute path to relative path from vault root
      local rel_path="${match_path#${vault_root}/}"
      if [[ "$first" -eq 1 ]]; then
        json="${json}{\"path\":\"${rel_path}\"}"
        first=0
      else
        json="${json},{\"path\":\"${rel_path}\"}"
      fi
    done <<< "$matches"

    json="${json}]"
    echo "$json"
  fi
}

# --- Subcommand dispatch ---

if [[ $# -lt 1 ]]; then
  _log ERROR "Usage: vault-read.sh <read|backlinks> --path <NOTE_PATH>"
  exit 1
fi

SUBCOMMAND="$1"
shift

case "$SUBCOMMAND" in
  read)      _cmd_read "$@" ;;
  backlinks) _cmd_backlinks "$@" ;;
  --help|-h)
    echo "Usage: vault-read.sh <read|backlinks> --path <NOTE_PATH>" >&2
    exit 0 ;;
  *) _log ERROR "Unknown subcommand: $SUBCOMMAND. Use: read, backlinks"; exit 1 ;;
esac
