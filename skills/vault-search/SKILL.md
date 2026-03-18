---
name: vault-search
description: Use to search Obsidian vault by keyword. Triggers on "옵시디언에서 찾아", "vault 검색", "관련 노트", "이전에 작성한", "예전에 정리한".
---

# Vault Search — Search Obsidian Vault

## Process

Delegate to `archivist` agent (haiku):

1. **Search** — `scripts/vault-search.sh --query "{keyword}" [--project {PROJECT}] [--limit 10]`
   - If current project context is known, add `--project {PROJECT}`
2. **Parse results** — Parse the JSON array and display in numbered format:
   ```
   ### Search Results: "{keyword}" (N found)
   1. `project/type/title.md` — matching context summary
   2. ...
   ```
3. **Read selected note** — When the user selects a specific note:
   `scripts/vault-read.sh read --path {NOTE_PATH}`
4. **Backlinks** — When the user requests linked documents:
   `scripts/vault-read.sh backlinks --path {NOTE_PATH}`
5. **Offer next** — "Let me know if you'd like to read any of these notes in detail."

## Empty Results — Retry Strategy

| Step | Method | Example |
|------|--------|---------|
| 1 | Split keyword | "제품주문 관리" → search "제품주문" and "관리" separately |
| 2 | Translate between English/Korean | "IAM" ↔ "권한", "order" ↔ "주문" |
| 3 | Browse by project folder | `scripts/vault-search.sh --query "{keyword}" --project "{project}"` |
| 4 | Search by tag | `scripts/vault-search.sh --query "tag: {tag}"` |

## Reference
- `ref/cli-reference.md` — Obsidian CLI commands (for understanding internal script behavior)

## Search Scope
Default: entire vault
If user specifies project: add `--project {PROJECT}`

DO NOT include any Grep/Glob direct tool call instructions. All search goes through scripts.
