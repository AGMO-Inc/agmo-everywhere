---
name: execute
description: Use when the user wants to run an implementation plan. Triggers on "실행해줘", "구현해줘", "시작해줘", "execute", or after plan approval.
---

# Execute — Plan-Based Implementation with Auto-Ralph

## Overview

Process all TODOs from a plan by dispatching executor agents with category routing. Automatically links ralph for persistent completion.

## Activation

When this skill is invoked, ralph is **automatically activated**. The execution loop continues until all TODOs are complete and final verification passes.

## Process

### 1. Load Plan

Read the plan from the vault path provided via skill args (e.g., `--plan-path {VAULT_PATH}`).

**Path resolution:**
1. If `--plan-path` is provided in args → Read the plan directly using Read tool from the vault path
   - The vault path format is an absolute path, e.g.: `agmo-everywhere/plans/[Plan]-제목.md`
   - Resolve to full path: `{AGMO_VAULT_ROOT}/{vault_path}` (e.g., `/Users/sungmincho/sungmin/agmo-everywhere/plans/[Plan]-제목.md`)
2. If no path provided → invoke `agmo:vault-search` to find the most recent plan for the current project
3. If Read fails (file not found) → invoke `agmo:vault-search` as fallback

Parse all TODOs into a work queue.

Classify each TODO:
- **Category**: quick / standard / complex (determines model)
- **Dependencies**: which TODOs must complete first
- **Parallelizable**: can this run concurrently with others?

### 2. Execute TODOs

For each TODO (respecting dependency order):

```
1. Dispatch executor agent with appropriate category
   - quick (haiku): simple file changes, config updates
   - standard (sonnet): feature implementation, most work
   - complex (opus): complex logic, architectural changes

2. Executor completes the TODO and reports results

3. Auto-trigger agmo:verification
   - If FAIL → collect failure context (approach taken + verification judgment)
   - Retry with accumulated feedback (up to 3 attempts):
     Each retry prompt MUST include ALL prior failure context:
     ```
     이전 시도 #{N}:
     - 접근법: {what was changed}
     - 실패 원인: {verification judgment summary}
     - 금지: 위 접근법 재시도
     ```
     (2nd retry includes attempt #1; 3rd retry includes attempts #1 + #2)
   - If 3 failures → auto-trigger agmo:debugging (include all failure contexts)
   - If PASS → proceed to step 4

4. Tag-based post-processing
   - Check the TODO's Tags field
   - If Tags contain `frontend` or `ui`:
     → Invoke agmo:accessibility with the TODO's changed files
     → If CRITICAL issues found → dispatch executor to fix → re-verify from step 3
     → If MINOR only → log summary, mark TODO complete
   - If Tags do not contain `frontend` or `ui`:
     → Mark TODO complete, proceed to next
```

### 3. Parallel Execution

If multiple TODOs are independent (no dependency, no shared files, and no import/export dependencies between their target files):
- Invoke `agmo:parallel` to dispatch multiple executors concurrently
- Each executor gets exclusive file ownership
- Integration phase after parallel batch completes

### 4. Final Verification

After all TODOs are complete:
- Dispatch `architect` agent for final verification
- Verify: build passes, tests pass, all acceptance criteria met
- If any failure → address it and re-verify

### 5. Completion

When architect approves final verification:
1. Invoke `agmo:save-impl` to save implementation summary to Obsidian
2. If significant learnings occurred, suggest `agmo:wisdom` recording
3. Report completion to user

## TDD Integration

If the plan specifies TDD:
- Before each TODO, invoke `agmo:tdd` to enforce RED → GREEN → REFACTOR
- Executor writes failing test first, then implementation

## Error Handling

| Situation | Action |
|-----------|--------|
| TODO acceptance criteria unclear | Ask user for clarification |
| 3 consecutive verification failures | Invoke `agmo:debugging` (3-fix limit) |
| Dependency deadlock | Report to user, suggest plan revision |
| Build broken mid-execution | Stop, fix build, then resume |
| Tags missing from TODO | Log warning, attempt fallback by file extension (.tsx/.jsx/.css/.html → treat as frontend). If ambiguous, skip post-processing |
