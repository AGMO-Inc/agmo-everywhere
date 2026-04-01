---
name: note-to-issue
description: Use to convert an Obsidian note into a GitHub Issue. Triggers on "노트로 이슈 만들어", "이슈로 변환", "이거 이슈로", "노트 이슈화". Only use when user explicitly references an Obsidian note as the source. For creating issues from conversation context (without a note), use create-issue instead.
---

# Note to Issue — Obsidian Note to GitHub Issue

## Process

Delegate to `archivist` agent (sonnet):

### Phase 1: Gather info (parallel)
A) **Read note** — `scripts/vault-read.sh read --path {NOTE_PATH}` → parse frontmatter + body
B) **Project info** — frontmatter `project` field or `scripts/identify-project.sh`
C) **Assignee** — `gh api user --jq '.login'`

### Phase 2: User confirmation (single prompt)
- If `issue-type` is missing → ask for type (feature / task / bug)
- If `issue-type: task` → ask for parent Feature issue number
- If status is unset → ask for status (Todo / In Progress / Weekly Done)
- Collect all missing items and ask in one prompt

### Phase 3: Create issue
- Template mapping: see `ref/issue-template-mapping.md`
- `gh issue create --repo {OWNER}/{PROJECT} --title "{title}" --body "{body}" --assignee {ASSIGNEE}`
- First line of body: `> 🤖 **AI created** — Converted from Obsidian note`

### Phase 4: Link to project
- `gh project item-add {PROJECT_NUMBER} --owner {OWNER} --url {ISSUE_URL}`
- Set Status field (gh project item-edit)
- If task, link parent: `gh issue edit {N} --repo {REPO} --add-parent {PARENT_N}`

### Phase 5: Update source note
- `scripts/vault-update.sh property-set --path {NOTE_PATH} --key issue --value "#{N}"`
- `scripts/vault-update.sh property-set --path {NOTE_PATH} --key status --value issued`
- `scripts/vault-update.sh append --path {NOTE_PATH} --content "---\n> GitHub Issue: [#{N}]({ISSUE_URL})"`

### Phase 6: Report result
- Issue URL, project registration status, assignee, parent link, note update status

## References
- `ref/issue-template-mapping.md` — template mapping by issue type
- `ref/frontmatter-schema.md` — frontmatter field definitions

## Safety
- If `issue` field already has a value, warn about duplicate and do not proceed without user confirmation
- If `issue-type` is missing, ask the user before proceeding
- All AI-generated text must include the `AI created` marker
