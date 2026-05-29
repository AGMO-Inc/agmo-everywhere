# LLM Wiki Context Budgeter Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Add an llm-wiki-style compiled context layer to agmo-everywhere so Obsidian remains the human-facing vault while Claude Code receives only bounded, high-signal agent context.

**Architecture:** Keep existing vault notes and wisdom files as source-of-truth. Add a generated vault spine under `.agmo/llm-wiki/` with `SCHEMA.md`, `INDEX.md`, `LOG.md`, and project pages. Add `wiki-context.sh` as the context budgeter consumed by `hooks/session-start`, with wisdom fallback and strict character budgets.

**Tech Stack:** Bash scripts, Python 3 for deterministic JSON/budget processing, existing `AGMO_VAULT_ROOT` / `~/.agmo/config` vault discovery.

---

### TODO 1: Add llm-wiki initialization script

- **What**: Create `scripts/wiki-init.sh` to initialize `.agmo/llm-wiki` inside the configured vault and create a project page idempotently.
- **File(s)**: `scripts/wiki-init.sh`
- **Tags**: [config, test]
- **Must NOT**: Do not require Obsidian CLI. Do not overwrite existing SCHEMA/INDEX/LOG/project pages.
- **Acceptance**: Running with a temp `AGMO_VAULT_ROOT` creates expected files and rerunning is idempotent.
- **QA**: `AGMO_VAULT_ROOT=$(mktemp -d) bash scripts/wiki-init.sh --project demo` creates `.agmo/llm-wiki/projects/demo.md`.

### TODO 2: Add bounded context reader

- **What**: Create `scripts/wiki-context.sh` that emits markdown or JSON context within a character budget, prioritizing schema/index/project/log then project/shared wisdom.
- **File(s)**: `scripts/wiki-context.sh`
- **Tags**: [config, test]
- **Must NOT**: Do not dump entire vault. Do not fail when wiki files are absent; return a small fallback section.
- **Acceptance**: `--format json` parses, `--budget` is respected, project content precedes shared wisdom.
- **QA**: With a temp vault containing oversized captures, `wiki-context.sh --budget 1000` outputs bounded content and lists omissions.

### TODO 3: Add capture script for durable agent-facing pages

- **What**: Create `scripts/wiki-capture.sh` to write durable project captures under `.agmo/llm-wiki/projects/<project>/captures/` and append index/log entries.
- **File(s)**: `scripts/wiki-capture.sh`
- **Tags**: [config, test]
- **Must NOT**: Do not overwrite duplicates; return `DUPLICATE:` with exit code 2.
- **Acceptance**: Captures file/stdin content with frontmatter, updates INDEX/LOG, preserves Unicode/Markdown.
- **QA**: Duplicate title returns exit 2 and original file remains unchanged.

### TODO 4: Wire session-start to compiled context

- **What**: Replace the raw wisdom injection block in `hooks/session-start` with `scripts/wiki-context.sh --project "$PROJECT_NAME" --budget "$AGMO_CONTEXT_BUDGET_CHARS"`, while preserving using-plugin context and vault warnings.
- **File(s)**: `hooks/session-start`
- **Tags**: [config, test]
- **Must NOT**: Do not break JSON hook output. Do not require initialized wiki.
- **Acceptance**: Hook emits valid JSON with `additionalContext` and includes bounded `## LLM Wiki Context` when vault is present.
- **QA**: Pipe `{"session_id":"test"}` into hook with temp vault and parse with `python3 -m json.tool`.

### TODO 5: Add regression tests and docs updates

- **What**: Add a Bash test runner for wiki scripts and update README/setup/wisdom/vault-search/save-impl docs to explain Obsidian vs llm-wiki vs wisdom context roles.
- **File(s)**: `tests/wiki-context.test.sh`, `README.md`, `skills/setup/SKILL.md`, `skills/wisdom/SKILL.md`, `skills/vault-search/SKILL.md`, `skills/save-impl/SKILL.md`, `ref/cli-reference.md`
- **Tags**: [test, documentation]
- **Must NOT**: Do not describe llm-wiki as replacing Obsidian or wisdom.
- **Acceptance**: Tests pass, shell syntax checks pass, docs clearly describe context-window discipline.
- **QA**: `bash tests/wiki-context.test.sh` and `bash -n scripts/*.sh hooks/* hud/*.sh` pass.
