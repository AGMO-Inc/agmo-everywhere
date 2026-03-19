#!/usr/bin/env bash
# vault-update.sh — Modify existing notes in the Obsidian vault
# Subcommands: append, property-set, section-append, section-ensure
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/obsidian-common.sh"

# ============================================================
# Subcommand: append
# Usage: vault-update.sh append --path <NOTE_PATH> (--content <TEXT> | --file <TMPFILE>)
# ============================================================
_cmd_append() {
  local note_path="" content="" content_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)    note_path="$2"; shift 2 ;;
      --content) content="$2";   shift 2 ;;
      --file)    content_file="$2"; shift 2 ;;
      *) _log ERROR "append: unknown argument: $1"; return 1 ;;
    esac
  done

  if [[ -z "$note_path" ]]; then
    _log ERROR "append: --path is required"; return 1
  fi

  local full_path="$(_vault_root)/${note_path}"
  if ! _file_exists "$full_path"; then
    _log ERROR "append: file not found: $full_path"; return 1
  fi

  if [[ -n "$content_file" ]]; then
    printf '\n' >> "$full_path"
    cat "$content_file" >> "$full_path"
  elif [[ -n "$content" ]]; then
    printf '\n%s\n' "$content" >> "$full_path"
  else
    _log ERROR "append: --content or --file is required"; return 1
  fi

  echo "APPENDED:${full_path}"
}

# ============================================================
# Subcommand: property-set
# Usage: vault-update.sh property-set --path <NOTE_PATH> --key <KEY> --value <VALUE>
# ============================================================
_cmd_property_set() {
  local note_path="" key="" value=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)  note_path="$2"; shift 2 ;;
      --key)   key="$2";       shift 2 ;;
      --value) value="$2";     shift 2 ;;
      *) _log ERROR "property-set: unknown argument: $1"; return 1 ;;
    esac
  done

  if [[ -z "$note_path" || -z "$key" || -z "$value" ]]; then
    _log ERROR "property-set: --path, --key, --value are all required"; return 1
  fi

  local full_path="$(_vault_root)/${note_path}"
  if ! _file_exists "$full_path"; then
    _log ERROR "property-set: file not found: $full_path"; return 1
  fi

  # Check if key exists in frontmatter
  local tmp_file="${full_path}.tmp"
  local in_frontmatter=0
  local frontmatter_count=0
  local key_found=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "---" ]]; then
      frontmatter_count=$((frontmatter_count + 1))
      if [[ $frontmatter_count -eq 1 ]]; then
        in_frontmatter=1
        echo "$line" >> "$tmp_file"
        continue
      elif [[ $frontmatter_count -eq 2 ]]; then
        # If key not found, insert before closing ---
        if [[ $key_found -eq 0 ]]; then
          echo "${key}: ${value}" >> "$tmp_file"
        fi
        in_frontmatter=0
        echo "$line" >> "$tmp_file"
        continue
      fi
    fi

    if [[ $in_frontmatter -eq 1 ]] && echo "$line" | grep -q "^${key}:"; then
      echo "${key}: ${value}" >> "$tmp_file"
      key_found=1
    else
      echo "$line" >> "$tmp_file"
    fi
  done < "$full_path"

  mv "$tmp_file" "$full_path"
  echo "PROPERTY_SET:${key}=${value}"
}

# ============================================================
# Subcommand: section-append
# Usage: vault-update.sh section-append --path <NOTE_PATH> --section <HEADING> --content <TEXT>
# ============================================================
_cmd_section_append() {
  local note_path="" section="" content=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)    note_path="$2"; shift 2 ;;
      --section) section="$2";   shift 2 ;;
      --content) content="$2";   shift 2 ;;
      *) _log ERROR "section-append: unknown argument: $1"; return 1 ;;
    esac
  done

  if [[ -z "$note_path" || -z "$section" || -z "$content" ]]; then
    _log ERROR "section-append: --path, --section, --content are all required"; return 1
  fi

  local full_path="$(_vault_root)/${note_path}"
  if ! _file_exists "$full_path"; then
    _log ERROR "section-append: file not found: $full_path"; return 1
  fi

  # Check if section exists
  if ! grep -q "^## ${section}$" "$full_path"; then
    _log ERROR "section-append: section not found: ## ${section}"
    echo "SECTION_NOT_FOUND:${section}"
    return 3
  fi

  # Use awk to insert content at end of section (before next ## or EOF)
  local tmp_file="${full_path}.tmp"
  awk -v section="## ${section}" -v content="$content" '
    BEGIN { in_section=0; inserted=0 }
    $0 == section { in_section=1; print; next }
    in_section && /^## / {
      # Next section found — insert content before it
      if (!inserted) { print content; inserted=1 }
      in_section=0
      print; next
    }
    { print }
    END {
      # If still in section at EOF, append content
      if (in_section && !inserted) { print content }
    }
  ' "$full_path" > "$tmp_file"

  mv "$tmp_file" "$full_path"
  echo "SECTION_APPENDED:${section}"
}

# ============================================================
# Subcommand: section-ensure
# Usage: vault-update.sh section-ensure --path <NOTE_PATH> --section <HEADING>
# ============================================================
_cmd_section_ensure() {
  local note_path="" section=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)    note_path="$2"; shift 2 ;;
      --section) section="$2";   shift 2 ;;
      *) _log ERROR "section-ensure: unknown argument: $1"; return 1 ;;
    esac
  done

  if [[ -z "$note_path" || -z "$section" ]]; then
    _log ERROR "section-ensure: --path, --section are required"; return 1
  fi

  local full_path="$(_vault_root)/${note_path}"
  if ! _file_exists "$full_path"; then
    _log ERROR "section-ensure: file not found: $full_path"; return 1
  fi

  if grep -q "^## ${section}$" "$full_path"; then
    echo "SECTION_EXISTS:${section}"
    return 0
  fi

  printf '\n## %s\n' "$section" >> "$full_path"
  echo "SECTION_CREATED:${section}"
}

# ============================================================
# Vault root guard
# ============================================================
VAULT_ROOT="$(_vault_root)"
if [[ -z "$VAULT_ROOT" ]]; then
  echo "[ERROR] Vault not configured. Run: agmo:setup" >&2
  exit 1
fi

# ============================================================
# Dispatch
# ============================================================
if [[ $# -lt 1 ]]; then
  echo "Usage: vault-update.sh <append|property-set|section-append|section-ensure> [options]" >&2
  exit 1
fi

SUBCMD="$1"; shift
case "$SUBCMD" in
  append)         _cmd_append "$@" ;;
  property-set)   _cmd_property_set "$@" ;;
  section-append) _cmd_section_append "$@" ;;
  section-ensure) _cmd_section_ensure "$@" ;;
  *) _log ERROR "Unknown subcommand: $SUBCMD"; exit 1 ;;
esac
