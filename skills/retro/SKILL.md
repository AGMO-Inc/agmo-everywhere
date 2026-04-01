---
name: retro
description: Use to generate a weekly retrospective by analyzing git log. Triggers on "회고", "retro", "이번 주 정리". Only runs on explicit user request — never auto-triggered.
---

# Retro — Weekly Retrospective from Git Log

## When to Run

Run ONLY when the user explicitly requests:
- "회고", "retro", "이번 주 정리"

Do NOT auto-trigger at session end or after execute completes.

## Input

- **Period** — defaults to the current week (Monday 00:00 to now). Accept user override (e.g., "지난주", "2025-W13").
- **Source** — git log only. Do NOT analyze issues, PRs, or external trackers.

## Process

Delegate git analysis to `architect` agent (sonnet), then vault storage to `archivist` agent (haiku).

### Step 1 — Identify project and period

- Run `scripts/identify-project.sh` → PROJECT, OWNER
- Determine `--since` date:
  - Default: Monday of the current week at 00:00 local time
  - If user specifies a week (e.g., "지난주"): compute the Monday of that week
- Compute week number: `date -d {MONDAY} +%Y-W%V` (or equivalent on macOS: `date -j -f "%Y-%m-%d" {MONDAY} +%Y-W%V`)

### Step 2 — Collect commit data

Delegate to `architect` agent:

```bash
# Commit list with stats
git log --since="{SINCE}" --until="{UNTIL}" --pretty=format:"%h %ad %s" --date=short

# Change statistics
git log --since="{SINCE}" --until="{UNTIL}" --shortstat

# Files changed
git log --since="{SINCE}" --until="{UNTIL}" --name-only --pretty=format:""
```

### Step 3 — Compute change statistics

Architect aggregates from `--shortstat` output:
- Total commits
- Total files changed
- Total lines added
- Total lines deleted

### Step 4 — Summarize key work and identify strengths/improvements

Architect analyzes commit messages and changed files to produce:

- **Key work** — group commits by theme (feature, fix, refactor, docs, etc.)
- **잘한 점 (Strengths)** — positive patterns (e.g., consistent commits, clear messages, test coverage)
- **개선점 (Improvements)** — gaps or concerns (e.g., large single commits, missing tests, unclear messages)

### Step 5 — Save to Obsidian vault

Delegate to `archivist` agent (haiku):

1. Build file path: `{vault_root}/{PROJECT}/retros/[Retro] {YYYY-WNN}.md`
2. Create tmpfile `/tmp/agmo-vault-{uuid}.md` with the content below
3. Ensure directory exists: create `{PROJECT}/retros/` if absent
4. Save file directly (vault-save.sh does not support `retro` type — write file manually via archivist)
5. Update index: `scripts/vault-update.sh section-ensure --path {PROJECT}/{PROJECT}.md --section Retros`
6. `scripts/vault-update.sh section-append --path {PROJECT}/{PROJECT}.md --section Retros --content "- [[{PROJECT}/retros/[Retro] {YYYY-WNN}]]"`
7. Cleanup: `rm /tmp/agmo-vault-{uuid}.md`
8. Report saved path

## Output Format

````markdown
---
type: retro
project: {PROJECT}
period: {YYYY-WNN}
since: {SINCE}
until: {UNTIL}
---

> Project: [[{PROJECT}]]

# [Retro] {YYYY-WNN}

## Stats

| Metric | Value |
|--------|-------|
| Commits | {N} |
| Files changed | {N} |
| Lines added | +{N} |
| Lines deleted | -{N} |

## Key Work

- **{theme}** — {commit summaries}
- ...

## 잘한 점

- {strength 1}
- {strength 2}

## 개선점

- {improvement 1}
- {improvement 2}
````

## Vault Path

`{vault_root}/{PROJECT}/retros/[Retro] YYYY-WNN.md`

Example: `{vault_root}/agmo-everywhere/retros/[Retro] 2025-W13.md`

## Safety

- Only analyze commits within the specified period. Do not read commits outside the range.
- Do not fetch or analyze GitHub issues, PRs, or any external data source.
- If no commits exist in the period, report "해당 기간에 커밋이 없습니다" and do not create a file.
- If a retro for the same week already exists, ask user before overwriting.
