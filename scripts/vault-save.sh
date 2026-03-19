#!/usr/bin/env bash
# vault-save.sh — Create a new note in the Obsidian vault
# Usage: vault-save.sh --type <type> --project <PROJECT> --title <TITLE> --file <TMPFILE>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/obsidian-common.sh"

# --- Type mappings (bash 3.x compatible) ---
_get_prefix() {
  case "$1" in
    plan)     echo "[Plan]" ;;
    impl)     echo "[Impl]" ;;
    design)   echo "[Design]" ;;
    research) echo "[Research]" ;;
    meeting)  echo "[Meeting]" ;;
    memo)     echo "[Memo]" ;;
    *)        return 1 ;;
  esac
}

_get_subdir() {
  case "$1" in
    plan)     echo "plans" ;;
    impl)     echo "implementations" ;;
    design)   echo "designs" ;;
    research) echo "research" ;;
    meeting)  echo "meetings" ;;
    memo)     echo "memos" ;;
    *)        return 1 ;;
  esac
}

# --- Argument parsing ---
TYPE="" PROJECT="" TITLE="" CONTENT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)    TYPE="$2";    shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --title)   TITLE="$2";   shift 2 ;;
    --file)    CONTENT_FILE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: vault-save.sh --type <plan|impl|design|research|meeting|memo> --project <PROJECT> --title <TITLE> --file <TMPFILE>" >&2
      exit 0 ;;
    *) _log ERROR "Unknown argument: $1"; exit 1 ;;
  esac
done

# --- Validation ---
if [[ -z "$TYPE" || -z "$PROJECT" || -z "$TITLE" || -z "$CONTENT_FILE" ]]; then
  _log ERROR "Missing required arguments. Use --help for usage."
  exit 1
fi

PREFIX="$(_get_prefix "$TYPE")" || {
  _log ERROR "Invalid type: $TYPE. Must be one of: plan, impl, design, research, meeting, memo"
  exit 1
}

SUBDIR="$(_get_subdir "$TYPE")"

if [[ ! -f "$CONTENT_FILE" ]]; then
  _log ERROR "Content file not found: $CONTENT_FILE"
  exit 1
fi

# --- Build paths ---
FILENAME="$(_slugify "${PREFIX} ${TITLE}").md"
VAULT_ROOT="$(_vault_root)"
if [[ -z "$VAULT_ROOT" ]]; then
  echo "[ERROR] Vault not configured. Run: agmo:setup" >&2
  exit 1
fi
TARGET_DIR="${VAULT_ROOT}/${PROJECT}/${SUBDIR}"
TARGET_PATH="${TARGET_DIR}/${FILENAME}"

# --- Duplicate check ---
if _file_exists "$TARGET_PATH"; then
  echo "DUPLICATE:${TARGET_PATH}"
  exit 2
fi

# --- Create ---
_ensure_dir "$TARGET_DIR"
cp "$CONTENT_FILE" "$TARGET_PATH"

echo "CREATED:${TARGET_PATH}"
exit 0
