#!/usr/bin/env bash
# wiki-init.sh — Initialize the agent-facing llm-wiki context spine inside the Obsidian vault.
# Usage: wiki-init.sh --project <PROJECT>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/obsidian-common.sh"

PROJECT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --help|-h)
      echo "Usage: wiki-init.sh --project <PROJECT>" >&2
      exit 0 ;;
    *) _log ERROR "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROJECT" ]]; then
  _log ERROR "Missing required argument: --project"
  exit 1
fi

VAULT_ROOT="$(_vault_root)"
if [[ -z "$VAULT_ROOT" ]]; then
  echo "[ERROR] Vault not configured. Run setup skill or set AGMO_VAULT_ROOT." >&2
  exit 1
fi

mkdir -p "$VAULT_ROOT"
WIKI_ROOT="${VAULT_ROOT}/.agmo/llm-wiki"
PROJECTS_DIR="${WIKI_ROOT}/projects"
PROJECT_DIR="${PROJECTS_DIR}/${PROJECT}"
CAPTURES_DIR="${PROJECT_DIR}/captures"
TODAY="$(_today)"

created=0
mkdir -p "$PROJECTS_DIR" "$CAPTURES_DIR" "$WIKI_ROOT/shared" "$WIKI_ROOT/raw"

if [[ ! -f "${WIKI_ROOT}/SCHEMA.md" ]]; then
  cat > "${WIKI_ROOT}/SCHEMA.md" <<EOF
# LLM Wiki Schema

## Domain
Personal and project context for Claude Code sessions. Obsidian remains the human-facing vault; this llm-wiki layer is the agent-facing compiled context spine used to reduce context-window pressure.

## Context Budget Rules
- Session-start should inject only bounded high-signal context.
- Prefer SCHEMA, INDEX, current project capsule, recent LOG, then selected wisdom.
- Do not inject raw transcripts or whole vault folders.
- Use detailed pages on demand via vault search/read.

## Page Types
- project: compact project capsule for startup orientation
- capture: durable agent-facing synthesis from plans, implementations, decisions, QA, PRs, or issues
- shared: cross-project context

## Update Policy
- Keep Obsidian notes as source-of-truth for human-authored plans/implementations.
- Capture only durable summaries here.
- Append every capture to INDEX.md and LOG.md.
EOF
  created=1
fi

if [[ ! -f "${WIKI_ROOT}/INDEX.md" ]]; then
  cat > "${WIKI_ROOT}/INDEX.md" <<EOF
# LLM Wiki Index

> Agent-facing context catalog. Use this to decide what to read; do not dump the whole vault into context.
> Last updated: ${TODAY}

## Projects

EOF
  created=1
fi

if [[ ! -f "${WIKI_ROOT}/LOG.md" ]]; then
  cat > "${WIKI_ROOT}/LOG.md" <<EOF
# LLM Wiki Log

> Append-only log of context-spine updates.

## [${TODAY}] create | LLM wiki initialized
- Vault: ${VAULT_ROOT}
EOF
  created=1
fi

PROJECT_PAGE="${PROJECTS_DIR}/${PROJECT}.md"
if [[ ! -f "$PROJECT_PAGE" ]]; then
  cat > "$PROJECT_PAGE" <<EOF
---
type: project
project: ${PROJECT}
created: ${TODAY}
updated: ${TODAY}
tags: [llm-wiki, context, ${PROJECT}]
---

# ${PROJECT}

## Startup Capsule
- Project-specific compiled context has not been captured yet.
- Use this page for stable conventions that should be available at session start.

## Key Links
- Captures: [[projects/${PROJECT}/captures]]

## Context Notes
- Keep this page short. Move details to captures and link them from INDEX.md.
EOF
  if ! grep -Fq "[[projects/${PROJECT}]]" "${WIKI_ROOT}/INDEX.md"; then
    printf -- '- [[projects/%s]] — Project startup capsule.\n' "$PROJECT" >> "${WIKI_ROOT}/INDEX.md"
  fi
  printf '\n## [%s] create | project %s\n- Created project capsule.\n' "$TODAY" "$PROJECT" >> "${WIKI_ROOT}/LOG.md"
  created=1
fi

if [[ "$created" -eq 1 ]]; then
  echo "INITIALIZED:${WIKI_ROOT}"
else
  echo "EXISTS:${WIKI_ROOT}"
fi
