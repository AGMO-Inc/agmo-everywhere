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

Other args:
- `--panel` → remembered for section 5 (Completion). After save-impl, invoke `Skill(skill="agmo:code-review", args="--panel")`. Without `--panel`, execute does not invoke code-review (unchanged).

**Direct mode:** when the user already has a plan path and a clear, scoped request, start here. No brainstorming or plan skill first.

**Path resolution:**
1. If `--plan-path` is provided in args → Read the plan directly using Read tool from the vault path
   - The vault path format is an absolute path, e.g.: `agmo-everywhere/plans/[Plan]-제목.md`
   - Resolve to full path: `{AGMO_VAULT_ROOT}/{vault_path}` (e.g., `{AGMO_VAULT_ROOT}/agmo-everywhere/plans/[Plan]-제목.md`)
2. If no path provided → invoke `agmo:vault-search` to find the most recent plan for the current project
3. If Read fails (file not found) → invoke `agmo:vault-search` as fallback

Parse all TODOs into a work queue.

Classify each TODO:
- **Category**: quick / standard / complex (determines model)
- **Dependencies**: which TODOs must complete first
- **Parallelizable**: can this run concurrently with others?

Read `${CLAUDE_PLUGIN_ROOT}/skills/handoff/SKILL.md` once now (Process step 3 holds the resume.md heredoc that Execute TODOs step 5 (Record) below reuses at every TODO boundary).

### 2. Execute TODOs

For each TODO (respecting dependency order):

````
1. Dispatch executor agent with category routing
   - quick (haiku): simple file changes, config updates
   - standard (sonnet): feature implementation, most work
   - complex (opus): complex logic, architectural changes
   The prompt is this brief. Every field is filled; a field you cannot fill means the TODO is not ready to dispatch.
   ```
   GOAL         <one sentence: the outcome, executable by a stranger with no chat access>
   SCOPE        may write: <TODO File(s)>; may NOT write: <everything else, name known neighbors>
   CONTEXT      plan: <vault path>; design: <vault path or none>; related files: <paths>;
                reports of TODOs this one depends on, pasted in full
   ACCEPTANCE   <one checkable criterion per line, copied from the TODO>
   VERIFY       <exact commands from the TODO's Acceptance/QA, plus known gotchas>
   TIMEBOX      <cap as a tool-call budget, e.g. 25 tool calls>; on expiry return partial findings and stop
   FORBIDDEN    no commits, no pushes, no fixes outside SCOPE, no new dependencies, no tests run (verification's job),
                plus the TODO's Must NOT lines
   REPORT       status (DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT); files changed; each ACCEPTANCE line met/unmet with evidence;
                what you actually ran; deviations; decision (one line: what you chose and why, feeds the decision log); follow-ups
   ```
   Size the brief to the TODO: a one-file edit collapses to a paragraph that still names GOAL, SCOPE, VERIFY and REPORT.

2. Executor completes the TODO and reports results

3. Auto-trigger agmo:verification
   - If FAIL → collect failure context (approach taken + verification judgment)
   - Retry with accumulated feedback (up to 3 attempts):
     Retries reuse the same brief; the 이전 시도 block below is appended to CONTEXT.
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
     → Mark TODO complete, proceed to step 5 (Record)

5. Record (after PASS, before the next TODO; failures here never block the TODO)
   - One decision row, taken from the executor REPORT's `decision` line:
     `bash "${CLAUDE_PLUGIN_ROOT}/scripts/decision-log.sh" execute "TODO {N}" "{decision}" "{why}" "{verification evidence, one line}" "{DONE|DONE_WITH_CONCERNS}"`
     On non-zero exit: print one warning line and continue.
   - Refresh resume.md with the heredoc from the handoff skill (`skills/handoff/SKILL.md`, Process step 3, read in step 1). Fields: intent = user request + plan path; progress = `TODO {N}/{M} done`; verified = TODOs that passed with the evidence command; next = `TODO {N+1}: {title}` or `architect final verification`; gotchas = failed approaches from retries, files not to touch. Each field at most 2 lines.
````

### Completion Status

When a TODO is marked complete (after step 3 PASS and step 4 post-processing), report one of the following statuses:

| Status | When to use |
|--------|-------------|
| `DONE` | All acceptance criteria met, no known issues |
| `DONE_WITH_CONCERNS` | Functionally complete but has known limitations or warnings |
| `BLOCKED` | Cannot proceed due to missing dependency or external blocker |
| `NEEDS_CONTEXT` | Requires clarification or additional context from the user |

**Output format per TODO:**

```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
Evidence: [Brief summary of how completion was verified]
```

For `DONE_WITH_CONCERNS`, also include:
```
Concerns:
  - [Concern description]
Follow-up: [Recommended next steps]
```

For `BLOCKED`, also include:
```
Reason: [Why it is blocked]
Blocker: [What needs to be resolved]
Next-Steps: [What must happen to unblock]
```

For `NEEDS_CONTEXT`, also include:
```
Question: [What clarification is needed]
Options: [Possible approaches, if applicable]
```

**Behavior by status:**

- **DONE**: Proceed to the next TODO immediately.
- **DONE_WITH_CONCERNS**: Log the concerns, report to the user, then proceed to the next TODO. Do not halt execution.
- **BLOCKED**: Report the blocker to the user and wait. Do not auto-proceed to the next TODO.
- **NEEDS_CONTEXT**: Ask the user the clarifying question and wait for their response. Do not auto-proceed.

**Connection to verification:**

- Verification PASS + no concerns → `DONE`
- Verification PASS + known limitations or warnings → `DONE_WITH_CONCERNS`
- Verification FAIL after 3 retries → debugging invoked; status resolved after debugging resolves
- Dependency missing or external blocker encountered → `BLOCKED`
- Acceptance criteria ambiguous before or during execution → `NEEDS_CONTEXT`

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
   save-impl attaches decisions.tsv as a "결정 로그" table when the file has rows.
2. If significant learnings occurred, suggest `agmo:wisdom` recording
3. Report completion to user
4. If `--panel` was passed → `Skill(skill="agmo:code-review", args="--panel")`. Without it, do not invoke code-review (unchanged).

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
