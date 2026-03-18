---
name: save-plan
description: Use to save a plan to Obsidian vault. Auto-triggered at the end of the plan skill. Triggers on "플랜 저장", "save plan".
---

> **⚠️ Legacy Skill** — 이 스킬은 레거시입니다. 일반적으로 plan 스킬이 직접 vault에 저장합니다. 수동으로 플랜을 저장할 때만 사용하세요.

# Save Plan — Plan to Obsidian Vault

## Process

Delegate to `archivist` agent (haiku):

1. **Identify project** — `scripts/identify-project.sh` → PROJECT, OWNER
2. **Read source** — Read the most recently modified `.md` file in `.plans/`. If none exists, collect from conversation context
3. **Ensure project index** — `scripts/ensure-project-index.sh PROJECT OWNER`
4. **Create tmpfile** — write to `/tmp/agmo-vault-{uuid}.md`:
   - Frontmatter (see `ref/frontmatter-schema.md` plan schema):
     ```yaml
     ---
     type: plan
     project: {PROJECT}
     issue: null
     issue-type: feature
     status: draft
     created: {YYYY-MM-DD}
     tags:
       - plan
       - {PROJECT}
     ---
     ```
   - Body: `> Project: [[{PROJECT}]]` then plan content
5. **Save** — `scripts/vault-save.sh --type plan --project {PROJECT} --title "{title}" --file /tmp/agmo-vault-{uuid}.md`
   - If `DUPLICATE:` → ask user
6. **Update index** — `scripts/vault-update.sh section-append --path {PROJECT}/{PROJECT}.md --section Plans --content "- [[{PROJECT}/plans/[Plan] {title}]]"`
7. **Issue link** — If TODO-Issue.md has issue number, `scripts/vault-update.sh property-set --path {NOTE_REL_PATH} --key issue --value "#{number}"`
8. **Cleanup** — `rm /tmp/agmo-vault-{uuid}.md`
9. **Report** — output saved file path, suggest `obsidian-to-issue` or implementation

## Vault Path

`${AGMO_VAULT_ROOT}/{PROJECT}/plans/[Plan] {title}.md`

## Title Derivation

Archivist MUST derive the title deterministically using these rules (in priority order):

1. **Orchestrator override** — if the orchestrator explicitly provides a title in the prompt, use it as-is
2. **Plan heading** — use the first `#` heading from the plan content (e.g., `# 인증 시스템 구현 계획` → "인증 시스템 구현 계획")
3. **Feature name** — from the conversation context, use the feature/task name being planned

Archivist MUST NOT invent a creative title. The title must be traceable to its source.

**CRITICAL: Do NOT include the type prefix in --title.** `vault-save.sh` adds the `[Plan]` prefix automatically. Passing `--title "[Plan] foo"` results in `[Plan]-[Plan]-foo`.

## Safety

- If a note with the same title exists, ask user before overwriting
- Never delete existing index entries (append only)
