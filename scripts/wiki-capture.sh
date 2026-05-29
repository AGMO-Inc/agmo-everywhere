#!/usr/bin/env bash
# wiki-capture.sh — Capture durable agent-facing context into the llm-wiki spine.
# Usage: wiki-capture.sh --project <PROJECT> --title <TITLE> [--type <TYPE>] [--source <SOURCE>] [--file <FILE>|--content <TEXT>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/obsidian-common.sh"

PROJECT="" TITLE="" TYPE="capture" SOURCE="user" CONTENT_FILE="" CONTENT="" CONFIDENCE="" SUPERSEDES="" CONTESTED=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --title) TITLE="${2:-}"; shift 2 ;;
    --type) TYPE="${2:-}"; shift 2 ;;
    --source) SOURCE="${2:-}"; shift 2 ;;
    --confidence) CONFIDENCE="${2:-}"; shift 2 ;;
    --supersedes) SUPERSEDES="${2:-}"; shift 2 ;;
    --contested) CONTESTED="true"; shift ;;
    --file) CONTENT_FILE="${2:-}"; shift 2 ;;
    --content) CONTENT="${2:-}"; shift 2 ;;
    --help|-h)
      echo "Usage: wiki-capture.sh --project <PROJECT> --title <TITLE> [--type <TYPE>] [--source <SOURCE>] [--confidence high|medium|low] [--supersedes <PATH>] [--contested] [--file <FILE>|--content <TEXT>]" >&2
      exit 0 ;;
    *) _log ERROR "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROJECT" || -z "$TITLE" ]]; then
  _log ERROR "Missing required arguments: --project and --title"
  exit 1
fi

if [[ -n "$CONTENT_FILE" && -n "$CONTENT" ]]; then
  _log ERROR "Use only one content source: --file or --content"
  exit 1
fi

if [[ -n "$CONTENT_FILE" ]]; then
  if [[ ! -f "$CONTENT_FILE" ]]; then
    _log ERROR "Content file not found: $CONTENT_FILE"
    exit 1
  fi
  CONTENT="$(cat "$CONTENT_FILE")"
elif [[ -z "$CONTENT" ]]; then
  if [ -t 0 ]; then
    _log ERROR "Missing content. Provide --file, --content, or stdin."
    exit 1
  fi
  CONTENT="$(cat)"
fi

if [[ -z "$CONTENT" ]]; then
  _log ERROR "Refusing to capture empty content."
  exit 1
fi

if [[ -n "$CONFIDENCE" && "$CONFIDENCE" != "high" && "$CONFIDENCE" != "medium" && "$CONFIDENCE" != "low" ]]; then
  _log ERROR "Invalid --confidence: $CONFIDENCE. Use high, medium, or low."
  exit 1
fi

VAULT_ROOT="$(_vault_root)"
if [[ -z "$VAULT_ROOT" ]]; then
  echo "[ERROR] Vault not configured. Run setup skill or set AGMO_VAULT_ROOT." >&2
  exit 1
fi

bash "${SCRIPT_DIR}/wiki-init.sh" --project "$PROJECT" >/dev/null

WIKI_ROOT="${VAULT_ROOT}/.agmo/llm-wiki"
CAPTURES_DIR="${WIKI_ROOT}/projects/${PROJECT}/captures"
TODAY="$(_today)"
FILENAME="$(_slugify "[Wiki] ${TITLE}").md"
TARGET_PATH="${CAPTURES_DIR}/${FILENAME}"

if _file_exists "$TARGET_PATH"; then
  echo "DUPLICATE:${TARGET_PATH}"
  exit 2
fi

mkdir -p "$CAPTURES_DIR"
CHAR_COUNT=$(printf '%s' "$CONTENT" | wc -c | tr -d ' ')
yaml_quote() {
  python3 -c 'import sys, json; print(json.dumps(sys.argv[1], ensure_ascii=False))' "$1"
}
PROJECT_YAML="$(yaml_quote "$PROJECT")"
TITLE_YAML="$(yaml_quote "$TITLE")"
SOURCE_YAML="$(yaml_quote "$SOURCE")"
SUPERSEDES_YAML="$(yaml_quote "$SUPERSEDES")"
TMPFILE="$(mktemp)"
cat > "$TMPFILE" <<EOF
---
type: ${TYPE}
project: ${PROJECT_YAML}
title: ${TITLE_YAML}
source: ${SOURCE_YAML}
created: ${TODAY}
updated: ${TODAY}
chars: ${CHAR_COUNT}
tags: [llm-wiki, context, ${PROJECT_YAML}]
EOF
if [[ -n "$CONFIDENCE" ]]; then
  printf 'confidence: %s\n' "$CONFIDENCE" >> "$TMPFILE"
fi
if [[ -n "$SUPERSEDES" ]]; then
  printf 'supersedes: %s\n' "$SUPERSEDES_YAML" >> "$TMPFILE"
fi
if [[ -n "$CONTESTED" ]]; then
  printf 'contested: true\n' >> "$TMPFILE"
fi
cat >> "$TMPFILE" <<EOF
---

# ${TITLE}

${CONTENT}
EOF
mv "$TMPFILE" "$TARGET_PATH"

REL_PATH=".agmo/llm-wiki/projects/${PROJECT}/captures/${FILENAME}"
if ! grep -Fq "$REL_PATH" "${WIKI_ROOT}/INDEX.md"; then
  printf -- '- [[%s]] — %s (%s).\n' "$REL_PATH" "$TITLE" "$TYPE" >> "${WIKI_ROOT}/INDEX.md"
fi
printf '\n## [%s] capture | %s\n- Project: %s\n- Type: %s\n- Path: %s\n' "$TODAY" "$TITLE" "$PROJECT" "$TYPE" "$REL_PATH" >> "${WIKI_ROOT}/LOG.md"

echo "CAPTURED:${TARGET_PATH}"
