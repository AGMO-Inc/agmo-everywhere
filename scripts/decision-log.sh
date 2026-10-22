#!/usr/bin/env bash
# decision-log.sh — Append one decision row to the session decision log (TSV).
# Ported from pstack skills/show-me-your-work/scripts/log.sh (MIT).
# Usage: decision-log.sh [--session <id>] <phase> <todo> <decision> <why> <evidence> <result>
# Output: ${AGMO_STATE_DIR:-$HOME/.agmo/state}/sessions/<id>/decisions.tsv
set -euo pipefail

usage() {
  printf 'usage: decision-log.sh [--session <id>] <phase> <todo> <decision> <why> <evidence> <result>\n' >&2
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

if [ "$#" -ne 6 ]; then
  usage
  exit 1
fi

# Session id priority: --session > AGMO_SESSION_ID > CLAUDE_CODE_SESSION_ID
if [ -z "$sid" ]; then
  sid="${AGMO_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"
fi
if [ -z "$sid" ]; then
  printf '[decision-log] no session id; skipped\n' >&2
  exit 0
fi

# Reject ids that could escape the sessions directory
case "$sid" in
  */*|.|..)
    printf '[decision-log] invalid session id; skipped\n' >&2
    exit 0
    ;;
esac

logfile="${AGMO_STATE_DIR:-$HOME/.agmo/state}/sessions/${sid}/decisions.tsv"
mkdir -p "$(dirname "$logfile")"

# Use `>>` here, never `>`.
if [ ! -s "$logfile" ]; then
  printf 'ts\tphase\ttodo\tdecision\twhy\tevidence\tresult\n' >> "$logfile"
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Strip tabs/newlines/CR so cells stay on one line, and prefix cells starting
# with a spreadsheet formula character (= + - @) with a single quote.
clean() {
  printf '%s' "$1" | tr '\t\n\r' '   ' | awk '{ if ($0 ~ /^[=+@-]/) printf "'\''%s", $0; else printf "%s", $0 }'
}

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$ts" \
  "$(clean "$1")" "$(clean "$2")" "$(clean "$3")" \
  "$(clean "$4")" "$(clean "$5")" "$(clean "$6")" >> "$logfile"

printf 'LOGGED:%s\n' "$logfile"
