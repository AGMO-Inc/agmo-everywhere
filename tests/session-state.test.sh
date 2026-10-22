#!/usr/bin/env bash
# Regression tests for decision-log.sh and the session-start handoff block. Requires only Bash + Python 3.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export AGMO_STATE_DIR="$TMP/state"
export AGMO_VAULT_ROOT="$TMP/vault"
mkdir -p "$AGMO_STATE_DIR" "$AGMO_VAULT_ROOT"

assert_file() {
  test -f "$1" || { echo "missing file: $1" >&2; exit 1; }
}

assert_no_file() {
  test ! -e "$1" || { echo "unexpected file: $1" >&2; exit 1; }
}

assert_eq() {
  [ "$1" = "$2" ] || { echo "expected '$2', got '$1' ($3)" >&2; exit 1; }
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  printf '%s' "$haystack" | grep -Fq -- "$needle" || { echo "missing text: $needle" >&2; exit 1; }
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    echo "unexpected text: $needle" >&2
    exit 1
  fi
}

assert_json() {
  printf '%s' "$1" | python3 -m json.tool >/dev/null || { echo "invalid JSON output" >&2; exit 1; }
}

# Extract additionalContext from hook JSON on stdin.
ctx() {
  python3 -c "import sys,json; print(json.load(sys.stdin)['hookSpecificOutput']['additionalContext'], end='')"
}

# Longest run of a character class in stdin (runs are not summed).
max_run() {
  python3 -c "import sys,re; runs=re.findall(sys.argv[1], sys.stdin.read()); print(max(len(r) for r in runs) if runs else 0)" "$1"
}

# Length of the line right after the handoff header (character count).
handoff_line_len() {
  python3 -c "import sys; c=sys.stdin.read(); i=c.find('## Session Handoff ('); print(len(c[i:].split('\n')[1]))"
}

# Run session-start with the given stdin JSON; prints raw hook output.
run_hook() {
  printf '%s' "$1" | bash hooks/session-start
}

cd "$ROOT"

# --- decision-log.sh ---
unset CLAUDE_CODE_SESSION_ID AGMO_SESSION_ID

bash scripts/decision-log.sh --session s1 plan T1 "pick A" "faster" "bench" "pass" >/dev/null
bash scripts/decision-log.sh --session s1 plan T2 "pick B" "simpler" "test" "pass" >/dev/null
LOG="$AGMO_STATE_DIR/sessions/s1/decisions.tsv"
assert_file "$LOG"
assert_eq "$(python3 -c "import sys; print(len(open(sys.argv[1]).read().splitlines()))" "$LOG")" "3" "line count (header + 2 rows)"
assert_eq "$(head -n 1 "$LOG" | cut -f1)" "ts" "header first column"
assert_eq "$(sed -n 2p "$LOG" | awk -F'\t' '{print NF}')" "7" "row column count"

# Cell sanitization.
bash scripts/decision-log.sh --session s3 plan T1 '=SUM(1)' $'tab\there\nnewline' '+x' '-x' >/dev/null
ROW="$AGMO_STATE_DIR/sessions/s3/decisions.tsv"
assert_eq "$(sed -n 2p "$ROW" | awk -F'\t' '{print NF}')" "7" "sanitized row column count"
assert_eq "$(sed -n 2p "$ROW" | cut -f4)" "'=SUM(1)" "formula prefix"
assert_eq "$(sed -n 2p "$ROW" | cut -f5)" "tab here newline" "tab/newline collapsed"
assert_eq "$(sed -n 2p "$ROW" | cut -f6)" "'+x" "plus prefix"
assert_eq "$(sed -n 2p "$ROW" | cut -f7)" "'-x" "minus prefix"
assert_eq "$(bash scripts/decision-log.sh --session s4 plan T1 d w '@x' r >/dev/null; sed -n 2p "$AGMO_STATE_DIR/sessions/s4/decisions.tsv" | cut -f6)" "'@x" "at prefix"
sed -n 2p "$ROW" | cut -f1 | grep -Eq '^[0-9]{4}-' || { echo "ts column malformed" >&2; exit 1; }

# No session id: exit 0 and nothing created.
set +e
env -u CLAUDE_CODE_SESSION_ID -u AGMO_SESSION_ID bash scripts/decision-log.sh plan T1 d w e r >/dev/null 2>&1
code=$?
set -e
assert_eq "$code" "0" "no session id exit code"
assert_no_file "$AGMO_STATE_DIR/sessions/decisions.tsv"
assert_no_file "$AGMO_STATE_DIR/decisions.tsv"

# Env var session id.
AGMO_SESSION_ID=s2 bash scripts/decision-log.sh plan T1 d w e r >/dev/null
assert_file "$AGMO_STATE_DIR/sessions/s2/decisions.tsv"

# --- decision-log.sh --archive ---
ARCH_OUT="$(bash scripts/decision-log.sh --session s1 --archive)"
case "$ARCH_OUT" in ARCHIVED:*) ;; *) echo "archive stdout: $ARCH_OUT" >&2; exit 1 ;; esac
ARCH_PATH="${ARCH_OUT#ARCHIVED:}"
assert_no_file "$AGMO_STATE_DIR/sessions/s1/decisions.tsv"
assert_file "$ARCH_PATH"
assert_eq "$(python3 -c "import sys; print(len(open(sys.argv[1]).read().splitlines()))" "$ARCH_PATH")" "3" "archived line count"
echo "$(basename "$ARCH_PATH")" | grep -Eq '^decisions\.[0-9]{8}T[0-9]{6}Z\.tsv$' || { echo "bad archive name: $ARCH_PATH" >&2; exit 1; }

bash scripts/decision-log.sh --session s1 plan T3 "pick C" "why" "ev" "pass" >/dev/null
assert_eq "$(python3 -c "import sys; print(len(open(sys.argv[1]).read().splitlines()))" "$AGMO_STATE_DIR/sessions/s1/decisions.tsv")" "2" "fresh log after archive"

set +e
ARCH_MISSING="$(bash scripts/decision-log.sh --session s9 --archive 2>/dev/null)"
code=$?
set -e
assert_eq "$code" "0" "archive missing file exit code"
assert_eq "$ARCH_MISSING" "" "archive missing file stdout"
assert_no_file "$AGMO_STATE_DIR/sessions/s9/decisions.tsv"

set +e
env -u CLAUDE_CODE_SESSION_ID -u AGMO_SESSION_ID bash scripts/decision-log.sh --archive >/dev/null 2>&1
code=$?
set -e
assert_eq "$code" "0" "archive no session id exit code"

# Wrong arg count.
set +e
bash scripts/decision-log.sh --session s5 a b c d e >/dev/null 2>&1
code=$?
set -e
assert_eq "$code" "1" "5 args exit code"

# --- session-start handoff block ---
mkdir -p "$AGMO_STATE_DIR/sessions/t"
RESUME="$AGMO_STATE_DIR/sessions/t/resume.md"
DEC="$AGMO_STATE_DIR/sessions/t/decisions.tsv"

# source=startup does not inject the handoff.
printf -- '- intent: x\n- next: y\n' > "$RESUME"
out="$(run_hook '{"session_id":"t","cwd":"'"$ROOT"'","source":"startup"}')"
assert_json "$out"
assert_not_contains "$(printf '%s' "$out" | ctx)" "Session Handoff"

# source=compact injects header and body.
out="$(run_hook '{"session_id":"t","source":"compact"}')"
assert_json "$out"
c="$(printf '%s' "$out" | ctx)"
assert_contains "$c" "## Session Handoff (compact)"
assert_contains "$c" "- next: y"

# ASCII 1,600 chars with source=resume is truncated at 1,500 characters.
python3 -c "import sys; open(sys.argv[1],'w',encoding='utf-8').write('a'*1600)" "$RESUME"
out="$(run_hook '{"session_id":"t","source":"resume"}')"
assert_json "$out"
c="$(printf '%s' "$out" | ctx)"
assert_contains "$c" "[truncated]"
assert_eq "$(printf '%s' "$c" | handoff_line_len)" "1500" "ASCII handoff line length"
assert_eq "$(printf '%s' "$c" | max_run 'a+')" "1500" "ASCII longest run"

# Korean 600 chars (1,782 bytes) with source=compact is kept whole.
python3 -c "import sys; open(sys.argv[1],'w',encoding='utf-8').write('# Resume\n'+'가'*591)" "$RESUME"
out="$(run_hook '{"session_id":"t","source":"compact"}')"
assert_json "$out"
c="$(printf '%s' "$out" | ctx)"
assert_not_contains "$c" "[truncated]"
assert_contains "$c" "Skill Catalog"
assert_eq "$(printf '%s' "$c" | max_run '가+')" "591" "Korean longest run"

# Korean 1,600 chars with source=resume is truncated at 1,500 characters.
python3 -c "import sys; open(sys.argv[1],'w',encoding='utf-8').write('가'*1600)" "$RESUME"
out="$(run_hook '{"session_id":"t","source":"resume"}')"
assert_json "$out"
c="$(printf '%s' "$out" | ctx)"
assert_contains "$c" "[truncated]"
assert_eq "$(printf '%s' "$c" | handoff_line_len)" "1500" "Korean handoff line length"

# Empty resume.md is ignored.
: > "$RESUME"
out="$(run_hook '{"session_id":"t","source":"compact"}')"
assert_json "$out"
assert_not_contains "$(printf '%s' "$out" | ctx)" "Session Handoff"

# decisions.tsv row-count pointer.
printf -- '- intent: x\n- next: y\n' > "$RESUME"
printf 'ts\tphase\ttodo\tdecision\twhy\tevidence\tresult\nr1\nr2\n' > "$DEC"
out="$(run_hook '{"session_id":"t","source":"compact"}')"
assert_json "$out"
assert_contains "$(printf '%s' "$out" | ctx)" "decisions.tsv: 2행"
printf 'ts\tphase' > "$DEC"
out="$(run_hook '{"session_id":"t","source":"compact"}')"
assert_json "$out"
assert_contains "$(printf '%s' "$out" | ctx)" "decisions.tsv: 0행"

# --- skill count sync ---
# T4 adds skills/handoff and bumps plugin.json to 31 in the same change; before T4 this is 30 = 30
[ "$(ls skills | wc -l | tr -d ' ')" = "$(grep -o '[0-9]* demand-loaded skills' .claude-plugin/plugin.json | grep -o '^[0-9]*')" ] || { echo "skill count out of sync with plugin.json" >&2; exit 1; }

echo "session-state tests passed"
