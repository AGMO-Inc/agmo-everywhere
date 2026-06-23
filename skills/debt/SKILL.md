---
name: debt
description: Use to harvest `debt:` markers across the repo into a debt ledger and optionally persist it to the Obsidian vault. Triggers on "부채", "기술부채", "debt", "지름길 정리", "/debt". Read-only — does not modify code.
---

# Debt — Harvest Debt Markers into a Ledger

Harvest the `# debt:` / `// debt:` markers that executor leaves for intentional simplifications, and turn them into a ledger. Read and report only — never modify code. One-shot.

## Process

1. **Identify project** — run `scripts/identify-project.sh` to resolve PROJECT.

2. **Grep the repo** for debt markers (exclude `node_modules`, `.git`, and build artifacts):
   ```bash
   grep -rnE '(#|//) ?debt:' . --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build
   ```
   You may delegate this grep to the `explore` agent (quick category).

3. **Build the ledger**, one line per marker, grouped by file:
   ```
   <file>:<line>, <what was simplified>. ceiling: <stated limitation>. upgrade: <re-review trigger>.
   ```
   For markers without a stated limitation or trigger, tag them `no-trigger` (silent-rot risk).

4. **Summarize** at the end:
   - `<N> markers, <M> with no trigger.`
   - If none found: `No debt markers. Clean ledger.`

5. **Persist only on request.** Output the ledger to the user. If the user asks to persist it, delegate to the `archivist` agent (haiku) to save it to vault `{PROJECT}/debt-ledger.md` using `scripts/vault-save.sh` (or `scripts/vault-update.sh` to append). Never auto-save.

6. **Honesty boundary.** Never emit fabricated savings figures like "saved N lines in this repo" — code that was never written has no baseline. The only real numbers are the counts in the ledger.

## Handoff (optional)

After presenting the ledger, scan each marker's `upgrade:` trigger. If any trigger now appears met (e.g. the named threshold is likely crossed, or the user says they want to act on it), **offer — do not auto-run** — to resolve the selected items:

> "다음 항목들의 트리거가 충족된 것으로 보입니다: [목록]. 이 중 처리할 항목을 `agmo:plan`으로 넘길까요?"

On explicit user confirmation, hand the chosen ledger rows to `agmo:plan` (each row's `file:line` + ceiling + upgrade trigger becomes the design input); the normal plan → execute pipeline does the actual fixing. For a single trivial row, the user may instead route straight to the `executor` agent.

This handoff is a routing offer only — this skill still never modifies code itself. Surfacing debt and resolving it stay separate steps; the skill only connects them when the user opts in.

## Constraints

- Read-only. Do not modify any code or marker — the optional handoff only routes to `agmo:plan`, it never edits code in this skill.
- One-shot. Do not loop or re-scan.
- Do not introduce new hooks, flags, or marker conventions — only the `debt:` convention documented in `agents/executor.md`.
