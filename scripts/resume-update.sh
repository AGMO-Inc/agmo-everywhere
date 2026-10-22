#!/usr/bin/env bash
# resume-update.sh — Patch individual fields of the session resume.md.
# Usage: resume-update.sh [--session <id>] <field> <value> [<field> <value> ...]
#        fields: intent|progress|verified|next|gotchas
# Output: ${AGMO_STATE_DIR:-$HOME/.agmo/state}/sessions/<id>/resume.md (prints UPDATED:<path>)
set -euo pipefail

usage() {
  printf 'usage: resume-update.sh [--session <id>] <field> <value> [<field> <value> ...]\n' >&2
  printf '       fields: intent|progress|verified|next|gotchas\n' >&2
}

sid=""
if [ "${1:-}" = "--session" ]; then
  if [ "$#" -lt 2 ]; then
    usage
    exit 1
  fi
  sid="$2"
  shift 2
fi

if [ "$#" -eq 0 ] || [ $(( $# % 2 )) -ne 0 ]; then
  usage
  exit 1
fi

args=("$@")
i=0
while [ "$i" -lt "$#" ]; do
  case "${args[$i]}" in
    intent|progress|verified|next|gotchas) ;;
    *) usage; exit 1 ;;
  esac
  i=$((i + 2))
done

if [ -z "$sid" ]; then
  sid="${AGMO_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"
fi
if [ -z "$sid" ]; then
  printf '[resume-update] no session id; skipped\n' >&2
  exit 0
fi

case "$sid" in
  */*|.|..)
    printf '[resume-update] invalid session id; skipped\n' >&2
    exit 0
    ;;
esac

dir="${AGMO_STATE_DIR:-$HOME/.agmo/state}/sessions/$sid"
file="$dir/resume.md"
mkdir -p "$dir"

# Drop stray RU_* from the caller's environment so only this call's fields are applied.
while IFS= read -r v; do unset "$v"; done < <(compgen -e RU_ 2>/dev/null || true)

i=0
while [ "$i" -lt "$#" ]; do
  f="${args[$i]}"
  v="$(printf '%s' "${args[$((i + 1))]}" | tr '\t\n\r' '   ')"
  export "RU_$f=$v" "RU_SET_$f=1"
  i=$((i + 2))
done

tmp="$(mktemp "$dir/.resume.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [ ! -f "$file" ]; then
  awk 'BEGIN {
    n = split("intent progress verified next gotchas", F, " ")
    print "# Resume"
    for (i = 1; i <= n; i++) {
      k = F[i]
      print "- " k ": " (ENVIRON["RU_SET_" k] == "1" ? ENVIRON["RU_" k] : "-")
    }
  }' > "$tmp"
else
  awk '{ print }' "$file" | awk 'BEGIN {
    n = split("intent progress verified next gotchas", F, " ")
  }
  {
    done = 0
    for (i = 1; i <= n; i++) {
      k = F[i]
      if (ENVIRON["RU_SET_" k] == "1" && index($0, "- " k ": ") == 1) {
        print "- " k ": " ENVIRON["RU_" k]
        seen[k] = 1
        done = 1
        break
      }
    }
    if (!done) print
  }
  END {
    for (i = 1; i <= n; i++) {
      k = F[i]
      if (ENVIRON["RU_SET_" k] == "1" && !seen[k]) print "- " k ": " ENVIRON["RU_" k]
    }
  }' > "$tmp"
fi

mv "$tmp" "$file"
trap - EXIT

size="$(wc -c < "$file" | tr -d ' ')"
if [ "$size" -gt 1200 ]; then
  printf '[resume-update] warning: resume.md is %s chars (>1200; hook truncates at 1500)\n' "$size" >&2
fi
printf 'UPDATED:%s\n' "$file"
