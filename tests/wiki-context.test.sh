#!/usr/bin/env bash
# Regression tests for llm-wiki context scripts. Requires only Bash + Python 3.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export AGMO_VAULT_ROOT="$TMP/My Vault"
export AGMO_STATE_DIR="$TMP/state"
mkdir -p "$AGMO_VAULT_ROOT"

assert_file() {
  test -f "$1" || { echo "missing file: $1" >&2; exit 1; }
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  printf '%s' "$haystack" | grep -Fq "$needle" || { echo "missing text: $needle" >&2; exit 1; }
}

cd "$ROOT"

# wiki-init is idempotent.
out="$(bash scripts/wiki-init.sh --project demo)"
assert_contains "$out" "INITIALIZED:"
assert_file "$AGMO_VAULT_ROOT/.agmo/llm-wiki/SCHEMA.md"
assert_file "$AGMO_VAULT_ROOT/.agmo/llm-wiki/INDEX.md"
assert_file "$AGMO_VAULT_ROOT/.agmo/llm-wiki/LOG.md"
assert_file "$AGMO_VAULT_ROOT/.agmo/llm-wiki/projects/demo.md"
out2="$(bash scripts/wiki-init.sh --project demo)"
assert_contains "$out2" "EXISTS:"

# wiki-capture stores durable context and rejects duplicates.
printf '# Finding\nImportant context for demo.\n' > "$TMP/input.md"
out="$(bash scripts/wiki-capture.sh --project demo --title 'API/Auth: token rules?' --type decision --source test --file "$TMP/input.md")"
assert_contains "$out" "CAPTURED:"
path="${out#CAPTURED:}"
assert_file "$path"
grep -Fq 'Important context for demo.' "$path"
set +e
dup="$(bash scripts/wiki-capture.sh --project demo --title 'API/Auth: token rules?' --type decision --source test --file "$TMP/input.md" 2>/dev/null)"
code=$?
set -e
test "$code" -eq 2 || { echo "expected duplicate exit 2, got $code" >&2; exit 1; }
assert_contains "$dup" "DUPLICATE:"

# wiki-context emits markdown and JSON within budget.
mkdir -p "$AGMO_VAULT_ROOT/demo/wisdom" "$AGMO_VAULT_ROOT/shared/wisdom"
printf '# Learnings\n- Project wisdom should appear.\n' > "$AGMO_VAULT_ROOT/demo/wisdom/learnings.md"
printf '# Decisions\n- Shared wisdom should appear.\n' > "$AGMO_VAULT_ROOT/shared/wisdom/decisions.md"
ctx="$(bash scripts/wiki-context.sh --project demo --budget 10000)"
assert_contains "$ctx" "## LLM Wiki Context (demo)"
assert_contains "$ctx" "Important context for demo."
assert_contains "$ctx" "Project wisdom should appear."
json="$(bash scripts/wiki-context.sh --project demo --budget 10000 --format json)"
printf '%s' "$json" | python3 -m json.tool >/dev/null

small="$(bash scripts/wiki-context.sh --project demo --budget 900)"
chars="$(printf '%s' "$small" | wc -c | tr -d ' ')"
test "$chars" -le 900 || { echo "context exceeded budget: $chars" >&2; exit 1; }

# wiki-maintain detects stale/low-confidence/contested/broken/superseded context.
cat > "$AGMO_VAULT_ROOT/.agmo/llm-wiki/projects/demo/captures/stale.md" <<'EOF'
---
type: decision
project: demo
title: stale low confidence claim
created: 2026-01-01
updated: 2026-01-01
confidence: low
contested: true
---

# Stale
Old unverified claim with [[missing-note]].
EOF
printf 'Corrected verified claim.\n' | bash scripts/wiki-capture.sh --project demo --title 'Corrected context' --confidence high --supersedes '.agmo/llm-wiki/projects/demo/captures/stale.md' >/dev/null
maintain="$(bash scripts/wiki-maintain.sh --project demo --max-age-days 30)"
assert_contains "$maintain" "LOW_CONFIDENCE"
assert_contains "$maintain" "STALE"
assert_contains "$maintain" "CONTESTED"
assert_contains "$maintain" "BROKEN_WIKILINK"
assert_contains "$maintain" "SUPERSEDED"
assert_contains "$maintain" "## LLM Wiki Maintenance"
maintain_json="$(bash scripts/wiki-maintain.sh --project demo --max-age-days 30 --format json)"
printf '%s' "$maintain_json" | python3 -m json.tool >/dev/null
ctx_after_supersede="$(bash scripts/wiki-context.sh --project demo --budget 10000)"
assert_contains "$ctx_after_supersede" "Corrected verified claim."
if printf '%s' "$ctx_after_supersede" | grep -Fq "Old unverified claim"; then
  echo "superseded stale context was still injected" >&2
  exit 1
fi

# session-start remains valid JSON and includes compiled context when present.
hook_json="$(printf '{"session_id":"test-session"}' | PATH="/usr/bin:/bin" bash hooks/session-start)"
printf '%s' "$hook_json" | python3 -m json.tool >/dev/null
HOOK_JSON="$hook_json" python3 - <<'PY'
import json, os
payload = json.loads(os.environ["HOOK_JSON"])
ctx = payload["hookSpecificOutput"]["additionalContext"]
assert "LLM Wiki Context" in ctx
assert "AGMO_VAULT_ROOT=" in ctx
PY

echo "wiki-context tests passed"
