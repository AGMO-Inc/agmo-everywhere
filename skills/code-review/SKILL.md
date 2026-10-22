---
name: code-review
description: Use when code review is needed. Triggers on "코드 리뷰", "리뷰해줘", "code review", or at completion of implementation.
---

# Code Review — 2-Stage Structured Review

## Overview

Code review happens in two separated stages. This separation prevents mixing concerns and ensures thorough coverage.

## Arguments

- (none) → Stage 2 runs critic alone. Default path; agent call count unchanged.
- `--panel` → Stage 2 runs two reviewers in one message: `Agent(subagent_type="agmo:critic", prompt=<Stage 2 brief>)` and a second reviewer. Read `hud.json` (`${AGMO_STATE_DIR:-$HOME/.agmo/state}/sessions/${CLAUDE_CODE_SESSION_ID}/hud.json`) → `codex` field: `true` → `Agent(subagent_type="codex:codex-rescue", prompt=<Stage 2 brief, ask for findings with severity>)`; `false` or unreadable → `Agent(subagent_type="agmo:architect", prompt=<Stage 2 brief>)` and add one line to the report: `Panel: critic + architect (codex unavailable)`. If one reviewer fails or times out, downgrade to the single remaining review and state it in the report.

## Stage 1: Spec Compliance

Delegate to `critic` agent.

If no plan exists (standalone code review), skip Stage 1. Instead, use `git diff` to identify changed files as the review scope.

For each TODO in the plan:
- Does the implementation match the TODO's "What" description?
- Are all acceptance criteria met?
- Are all "Must NOT" constraints respected?
- Does the QA scenario pass?
- Comment hygiene (changed files only): list every comment outside the five exceptions in executor Rule 3 (`agents/executor.md`), every step-narrating comment, and every correctness-related suppression (`@ts-ignore`, `@ts-expect-error`, `eslint-disable` on a bug-catching rule). `// debt:` markers are exempt. Report as `Cleanup` lines: `<file:line>: <comment text, 40 chars> → delete | rename/extract/type | fix cause`. Severity MINOR, except a correctness suppression is IMPORTANT. Cleanup never makes Stage 1 NON-COMPLIANT.

Output:
```
## Stage 1: Spec Compliance
- TODO 1: PASS / FAIL — [details]
- TODO 2: PASS / FAIL — [details]
- Cleanup: [N comments] — [lines] (or none)
Overall: COMPLIANT / NON-COMPLIANT
```

If NON-COMPLIANT: stop here, fix spec violations before proceeding to Stage 2.

## Stage 1.5: Scope Drift Detection

Skip this stage if no plan is provided.

Procedure:
1. Collect the list of changed files via `git diff --name-only` (or `git diff HEAD --name-only` for committed changes).
2. Extract all `File(s)` entries referenced across every TODO in the plan.
3. Compare the two sets. Any changed file not referenced in any TODO's `File(s)` is an **Unplanned Change**.

Output format when unplanned changes are found:
```
### Unplanned Changes
- path/to/unexpected/file.ts — not referenced in any TODO
```

If no unplanned changes are detected, output:
```
### Unplanned Changes
None detected.
```

This stage reports only. Scope drift does not block progression to Stage 2.

## Stage 2: Code Quality

Delegate to `critic` agent.

The critic reads `${CLAUDE_PLUGIN_ROOT}/skills/using-plugin/references/review-judgment.md` and tags every finding with a bucket: Act on / Consider / Noted / Dismissed (filter number). The orchestrator may re-bucket with a one-line reason. Only Act on findings are dispatched to executor for fixes; CRITICAL is always Act on.

Review for:
1. **Logic correctness** — edge cases, off-by-one, null handling
2. **Security** — injection, XSS, auth bypass, secrets in code
3. **Performance** — obvious N+1 queries, unnecessary loops, missing indexes
4. **Consistency** — follows existing codebase patterns and conventions
5. **Over-engineering lens** — a separate axis from correctness/security/performance. Scan for needless complexity using these tags, one finding per line:
   - `delete:` — dead code or speculative feature (replacement: none)
   - `stdlib:` — hand-rolled standard library (name the stdlib function)
   - `native:` — work the platform already does (name the native feature)
   - `yagni:` — abstraction or config with a single implementation
   - `shrink:` — same logic, fewer lines
   Format each line as: `<location>: <tag> <what>. <replacement>.`
   End with `net: -N lines possible.`, or `Lean already.` if nothing to cut.
   Classify these findings as IMPORTANT or MINOR only — never CRITICAL. They do NOT block approval (the zero-CRITICAL = APPROVE rule stands).

Do NOT review:
- Style preferences (formatting, naming) unless inconsistent with codebase
- Missing features not in the plan
- Hypothetical future concerns

### Panel synthesis (`--panel` only)

The orchestrator, not a reviewer, merges the two reports:
1. Build the Agreement Map from `review-judgment.md` (one row per distinct finding; `-` when a reviewer did not raise it).
2. Consensus findings keep the higher severity and bucket Act on unless a filter applies.
3. Single-reviewer findings are bucketed with the five filters; the filter number goes in Note.
4. Severity disagreements are resolved by the orchestrator; the reason goes in Note. Never average.
5. Dispatch executor for Act on rows only.

## Stage 3: Plan Completion Audit

Skip this stage if no plan is provided.

For each TODO in the plan, check whether the implementation exists in the changed files:
- ✅ Implemented — changes found that satisfy the TODO
- ❌ Missing — no relevant changes found in the specified files
- ⚠️ Partial — some changes found but acceptance criteria not fully met

Output format:
```
### Plan Completion Audit
- [x] TODO 1: title — Implemented
- [ ] TODO 3: title — Missing (no changes found in specified files)
- [~] TODO 5: title — Partial (acceptance criteria X not met)
```

## Investigation Depth

Each file in the review scope should be examined at an appropriate depth based on its type and sensitivity.

| Depth | Criteria | Examples |
|-------|----------|----------|
| surface | Config, docs, formatting | .json, .md, .yaml |
| moderate | Standard business logic | services, controllers |
| deep | Security, auth, data, payment | auth/*, payment/*, migrations |

Apply **deep** review to any file touching authentication, authorization, payment processing, or database migrations. Apply **surface** review to configuration and documentation files unless they contain secrets or critical values.

## Output Format

```
## Code Review Summary
Overall: APPROVE / REQUEST_CHANGES
Panel: critic (default) | critic + architect | critic + codex | critic + architect (codex unavailable) | single (one reviewer failed: <which>)

### Stage 1: Spec Compliance
[findings]
- Cleanup: [N comments] — [file:line → action] (or none)

### Stage 1.5: Unplanned Changes
[list or None detected.]

### Stage 2: Code Quality
#### Act on
- [CRITICAL|IMPORTANT] [finding]: [action needed]
#### Consider
- [IMPORTANT|MINOR] [finding]: [action needed]
#### Noted
- [finding]
#### Dismissed
- [finding] — filter N: [one line]

#### Agreement Map (--panel only)
| # | Finding | critic | architect / codex | Bucket | Note |

#### Over-engineering Lens
- <location>: <tag> <what>. <replacement>.
net: -N lines possible.   (or: Lean already.)

### Stage 3: Plan Completion Audit
- [x] TODO 1: title — Implemented
- [ ] TODO N: title — Missing / Partial

### What Works Well
- [positive feedback]
```
