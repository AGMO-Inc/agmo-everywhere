#!/usr/bin/env bash
# vault-search.sh — Search notes in the Obsidian vault
# Usage: vault-search.sh --query <KEYWORD> [--project <PROJECT>] [--limit <N>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/obsidian-common.sh"

# --- Argument parsing ---
QUERY="" PROJECT="" LIMIT=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)   QUERY="$2";   shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --limit)   LIMIT="$2";   shift 2 ;;
    --help|-h)
      echo "Usage: vault-search.sh --query <KEYWORD> [--project <PROJECT>] [--limit <N>]" >&2
      exit 0 ;;
    *) _log ERROR "Unknown argument: $1"; exit 1 ;;
  esac
done

# --- Validation ---
if [[ -z "$QUERY" ]]; then
  _log ERROR "Missing required argument: --query"
  exit 1
fi

VAULT_ROOT="$(_vault_root)"
if [[ -z "$VAULT_ROOT" ]]; then
  echo "[ERROR] Vault not configured. Run: agmo:setup" >&2
  exit 1
fi

# --- Primary: obsidian CLI search ---
OBS_RESULT=""
if [[ -n "$PROJECT" ]]; then
  OBS_RESULT="$(obsidian search query="${QUERY}" format=json limit="${LIMIT}" path="${PROJECT}" 2>/dev/null)" || true
else
  OBS_RESULT="$(obsidian search query="${QUERY}" format=json limit="${LIMIT}" 2>/dev/null)" || true
fi

# Accept only if output looks like a JSON array (starts with '[')
if [[ -n "$OBS_RESULT" && "${OBS_RESULT#[}" != "$OBS_RESULT" ]]; then
  echo "$OBS_RESULT"
  exit 0
fi

# --- Fallback: grep-based search ---
if [[ -n "$PROJECT" ]]; then
  SEARCH_ROOT="${VAULT_ROOT}/${PROJECT}"
else
  SEARCH_ROOT="${VAULT_ROOT}"
fi

# Collect matching files (up to LIMIT)
JSON_ARRAY="["
COUNT=0
FIRST=1

# Use a temp file to avoid subshell variable scoping issues
TMPFILE="$(mktemp)"
grep -rli --include="*.md" "${QUERY}" "${SEARCH_ROOT}" 2>/dev/null > "$TMPFILE" || true

while IFS= read -r file; do
  if [[ "$COUNT" -ge "$LIMIT" ]]; then
    break
  fi

  # Get first matching line
  MATCH_LINE="$(grep -m1 "${QUERY}" "$file" 2>/dev/null)" || MATCH_LINE=""

  # Make path relative to VAULT_ROOT
  REL_PATH="${file#${VAULT_ROOT}/}"

  # Escape backslash, double-quote, and control characters for JSON
  MATCH_ESCAPED="$(printf '%s' "$MATCH_LINE" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g')"
  REL_ESCAPED="$(printf '%s' "$REL_PATH" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  if [[ "$FIRST" -eq 1 ]]; then
    JSON_ARRAY="${JSON_ARRAY}{\"path\":\"${REL_ESCAPED}\",\"match\":\"${MATCH_ESCAPED}\"}"
    FIRST=0
  else
    JSON_ARRAY="${JSON_ARRAY},{\"path\":\"${REL_ESCAPED}\",\"match\":\"${MATCH_ESCAPED}\"}"
  fi

  COUNT=$((COUNT + 1))
done < "$TMPFILE"

rm -f "$TMPFILE"

JSON_ARRAY="${JSON_ARRAY}]"
echo "$JSON_ARRAY"
exit 0
