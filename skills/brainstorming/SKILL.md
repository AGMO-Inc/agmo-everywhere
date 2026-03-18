---
name: brainstorming
description: Use when the user wants to explore an idea, design an approach, or think through a problem before implementing. Triggers on "고민", "논의", "아이디어", "brs".
---

# Brainstorming — From Idea to Design

## Hard Gate

**DO NOT write any code, scaffold any project, or invoke any implementation skill until the user explicitly approves the design.** No exceptions, no matter how simple the task appears.

## Process

### 1. Understand Context

Before asking questions:
- Read relevant files in the current project (package.json, README, recent changes)
- If the user references prior work, invoke `agmo:vault-search` to find related Obsidian notes
- Delegate exploration to the `explore` agent (quick category) if needed

### 2. Clarify the Idea

Ask questions **one at a time**. Prefer multiple choice when possible.

Focus on:
- **Purpose**: What problem does this solve?
- **Constraints**: What must NOT happen?
- **Success criteria**: How do we know it works?

Do NOT ask about implementation details yet — understand the "what" before the "how".

### 3. Propose Approaches

Once the idea is clear, present **2-3 approaches** with tradeoffs:

```
## Approach A: [Name] (Recommended)
- How: [1-2 sentences]
- Pro: [key advantage]
- Con: [key disadvantage]

## Approach B: [Name]
- How: [1-2 sentences]
- Pro: [key advantage]
- Con: [key disadvantage]
```

State your recommendation and why.

### 4. Present Design

After the user picks an approach, present the design in sections. After each section, ask "여기까지 괜찮아?":

- **Architecture** — components and their relationships
- **Data flow** — how data moves through the system
- **Error handling** — what can go wrong and how to handle it
- **Scope boundaries** — what is explicitly OUT of scope (YAGNI)

Scale each section to complexity: a simple feature gets 2-3 sentences per section, a complex system gets a paragraph.

### 5. Save and Transition

Once the user approves the design:

1. **Save design to vault directly** — The planner agent saves the design using vault-save.sh via Bash tool:
   - Write design content to a temp file
   - Run: `bash scripts/vault-save.sh --project "{PROJECT}" --type "design" --title "{TITLE}" --file "$tmp_file"`
   - On `CREATED:{path}` → extract vault path
   - On `DUPLICATE:{path}` → ask user whether to update or skip
   - On error (exit code != 0) → return error message to orchestrator
   - **WARNING**: NEVER include `[Design]` prefix in `--title` — vault-save.sh adds it automatically
   - Return the vault path to the orchestrator

2. **Complexity re-check** — determine the next step:
   - **Light** (all changes are mechanical — renaming, config edits, pattern replication with no judgment calls) → skip plan, delegate to executor agent (sonnet) directly for implementation. Do NOT invoke execute skill.
   - **Heavy** (any change requires design judgment — new logic, API design, error handling strategy, data model decisions) → invoke `agmo:plan` with the vault path: `Skill(skill="agmo:plan", args="--design-path {VAULT_PATH}")`
3. If Heavy, ask: "구현 계획으로 넘어갈까?"

## Principles

- **One question at a time** — never overwhelm with multiple questions
- **YAGNI** — remove any feature that is not explicitly requested
- **Alternatives first** — always propose 2-3 approaches before deciding
- **Incremental approval** — present design in sections, get approval per section
