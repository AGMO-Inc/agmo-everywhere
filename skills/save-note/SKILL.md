---
name: save-note
description: Use to save a design, research, meeting, or memo note to Obsidian vault. Triggers on "옵시디언에 저장", "노트 저장", "기록해줘", "정리해줘".
---

# Save Note — General Notes to Obsidian Vault

## Supported Types

| Type | Prefix | Path | Use for |
|------|--------|------|---------|
| design | `[Design]` | `{PROJECT}/designs/` | Design documents, requirement analysis |
| research | `[Research]` | `{PROJECT}/research/` | Technical research, comparisons |
| meeting | `[Meeting]` | `{PROJECT}/meetings/` | Meeting notes, decision records |
| memo | `[Memo]` | `{PROJECT}/memos/` | Free-form notes, ideas |
| plugin-review | `[Review]` | `shared/plugin-reviews/` | Plugin usage review reports |

## Process

Delegate to `archivist` agent (haiku):

1. **Identify project** — `scripts/identify-project.sh` → PROJECT, OWNER
2. **Ensure project index** — `scripts/ensure-project-index.sh PROJECT OWNER`
3. **Determine type** — infer from context (design/research/meeting/memo/plugin-review). If unclear, ask user.
4. **Create tmpfile** — write frontmatter + body to `/tmp/agmo-vault-{uuid}.md`
   - Frontmatter: see `ref/frontmatter-schema.md` for the type's schema
   - Body: see `ref/note-templates.md` for the type's template
   - First body line: `> Project: [[{PROJECT}]]`
5. **Save note** — `scripts/vault-save.sh --type {type} --project {PROJECT} --title "{title}" --file /tmp/agmo-vault-{uuid}.md`
   - If `DUPLICATE:` response → ask user before overwriting
6. **Ensure section** — `scripts/vault-update.sh section-ensure --path {PROJECT}/{PROJECT}.md --section {SectionName}`
   - SectionName mapping: design→Designs, research→Research, meeting→Meetings, memo→Memos, plugin-review→Plugin Reviews
7. **Update index** — `scripts/vault-update.sh section-append --path {PROJECT}/{PROJECT}.md --section {SectionName} --content "- [[{PROJECT}/{subdir}/[{Prefix}] {title}]]"`
8. **Cleanup** — `rm /tmp/agmo-vault-{uuid}.md`
9. **Report** — output the saved file path

## Title Derivation

Archivist MUST derive the title deterministically using these rules (in priority order):

1. **Orchestrator override** — if the orchestrator explicitly provides a title in the prompt, use it as-is
2. **Content heading** — use the first `#` heading from the note content
3. **Conversation topic** — use the main topic being discussed (e.g., brainstorming subject, research topic, meeting agenda)

Archivist MUST NOT invent a creative title. The title must be traceable to its source.

**CRITICAL: Do NOT include the type prefix in --title.** `vault-save.sh` adds the prefix (e.g., `[Design]`, `[Memo]`) automatically. Passing `--title "[Design] foo"` results in `[Design]-[Design]-foo`.

## Safety

- If a note with the same title exists, ask user before overwriting
- Never delete existing index entries

## Saving Multiple Notes at Once

When saving multiple notes, repeat the Process above in order for each note.
