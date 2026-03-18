#!/usr/bin/env bash
# Ensure project index note exists in Obsidian vault
# Usage: ensure-project-index.sh <PROJECT> <OWNER> [VAULT_ROOT]
PROJECT="$1"
OWNER="$2"
VAULT_ROOT="${3:-${AGMO_VAULT_ROOT:-}}"
INDEX_FILE="${VAULT_ROOT}/${PROJECT}/${PROJECT}.md"

if [ -f "$INDEX_FILE" ]; then
  echo "EXISTS"
  exit 0
fi

mkdir -p "${VAULT_ROOT}/${PROJECT}/plans" "${VAULT_ROOT}/${PROJECT}/implementations" "${VAULT_ROOT}/${PROJECT}/designs" "${VAULT_ROOT}/${PROJECT}/research" "${VAULT_ROOT}/${PROJECT}/meetings" "${VAULT_ROOT}/${PROJECT}/memos" "${VAULT_ROOT}/${PROJECT}/wisdom"
cat > "$INDEX_FILE" << EOF
---
type: project-index
project: ${PROJECT}
repo: ${OWNER}/${PROJECT}
project-url:
tags:
  - project
---

# ${PROJECT}

- repo: [${OWNER}/${PROJECT}](https://github.com/${OWNER}/${PROJECT})

## Plans

## Implementations

## Designs

## Research

## Meetings

## Memos

## Wisdom
EOF

echo "CREATED"
