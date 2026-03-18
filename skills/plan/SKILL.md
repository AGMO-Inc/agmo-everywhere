---
name: plan
description: Use when the user needs a structured implementation plan with concrete TODOs. Triggers on "플랜", "계획", "plan", or after brainstorming completes.
---

# Plan — Structured Implementation Planning

## Overview

Create an implementation plan with concrete, agent-executable TODOs. The plan must be detailed enough that an executor agent can complete each TODO without human intervention.

## Process

### 1. Gather Context

Delegate to `explore` agent (standard category):
- Read existing codebase structure
- Identify files that will be affected
- Find existing patterns and conventions

If a design document exists (from brainstorming), read it first.

### 2. Interview (if needed)

If requirements are unclear, ask the user — **one question at a time**, prefer multiple choice.

Only ask about **user preferences**, not technical details you can discover from the codebase:
- "테스트 프레임워크는 기존 프로젝트에서 사용하는 걸 그대로 쓸까?"
- "API 엔드포인트 이름은 어떤 컨벤션으로?"

Skip the interview if requirements are already clear from the design document.

### 3. Create Plan

Delegate to `planner` agent (standard or complex category).

#### TODO Structure

Each TODO must contain:

```markdown
### TODO N: [Short title]
- **What**: Exactly what to do (1-2 sentences)
- **File(s)**: Exact file paths to create or modify
- **Tags**: [frontend | ui | backend | config | test] (1개 이상 필수)
- **Must NOT**: Explicit constraints
- **Acceptance**: How to verify completion
- **QA**: Concrete test scenario (exact inputs → expected outputs)
```

#### Plan Rules

1. Each TODO = 2-5 minutes of executor agent work
2. Every TODO references specific file paths
3. Acceptance criteria must be agent-executable (no human judgment needed)
4. QA scenarios use concrete data ("test@example.com", not "[email]")
5. Dependencies between TODOs are explicitly noted
6. Independent TODOs are marked for potential parallel execution

### 4. Self-Review

Before presenting to the user, verify:
- [ ] All TODOs have concrete acceptance criteria
- [ ] File references exist or are clearly marked as "to be created"
- [ ] No unvalidated assumptions
- [ ] Scope is clear (in AND out)
- [ ] No YAGNI violations

### 5. Save

After user approval, the planner agent saves the plan directly to vault using vault-save.sh via Bash tool:

1. Write plan content to a temp file
2. Run: `bash scripts/vault-save.sh --project "{PROJECT}" --type "plan" --title "{TITLE}" --file "$tmp_file"`
3. Handle response:
   - `CREATED:{path}` → extract vault path. Return this path to the orchestrator.
   - `DUPLICATE:{path}` → ask user whether to update or skip
   - Error (exit code != 0) → return error message to orchestrator
4. Clean up temp file

**WARNING**: NEVER include `[Plan]` prefix in `--title` — vault-save.sh adds it automatically.

## Optional: Plan Review

If the plan is complex or the user requests it, invoke `agmo:plan-review` for a planner ↔ critic validation loop.

## Transition to Execution

After the plan is approved and saved to vault:
- User says "실행해줘" / "구현해줘" / "시작해줘" → invoke `agmo:execute` with the vault path: `Skill(skill="agmo:execute", args="--plan-path {VAULT_PATH}")`
- The vault path format is an absolute path, e.g.: `agmo-everywhere/plans/[Plan]-제목.md`
- Execute automatically links ralph for persistent completion
