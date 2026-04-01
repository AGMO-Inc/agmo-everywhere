---
name: code-review
description: Use when code review is needed. Triggers on "코드 리뷰", "리뷰해줘", "code review", or at completion of implementation.
---

# Code Review — 2-Stage Structured Review

## Overview

Code review happens in two separated stages. This separation prevents mixing concerns and ensures thorough coverage.

## Stage 1: Spec Compliance

Delegate to `critic` agent.

If no plan exists (standalone code review), skip Stage 1. Instead, use `git diff` to identify changed files as the review scope.

For each TODO in the plan:
- Does the implementation match the TODO's "What" description?
- Are all acceptance criteria met?
- Are all "Must NOT" constraints respected?
- Does the QA scenario pass?

Output:
```
## Stage 1: Spec Compliance
- TODO 1: PASS / FAIL — [details]
- TODO 2: PASS / FAIL — [details]
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

Review for:
1. **Logic correctness** — edge cases, off-by-one, null handling
2. **Security** — injection, XSS, auth bypass, secrets in code
3. **Performance** — obvious N+1 queries, unnecessary loops, missing indexes
4. **Consistency** — follows existing codebase patterns and conventions
5. **Simplicity** — no over-engineering, no unnecessary abstractions

Do NOT review:
- Style preferences (formatting, naming) unless inconsistent with codebase
- Missing features not in the plan
- Hypothetical future concerns

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

### Stage 1: Spec Compliance
[findings]

### Stage 2: Code Quality
#### CRITICAL
- [finding]: [action needed]

#### IMPORTANT
- [finding]: [action needed]

#### MINOR
- [finding]: [action needed]

### Stage 3: Plan Completion Audit
- [x] TODO 1: title — Implemented
- [ ] TODO N: title — Missing / Partial

### What Works Well
- [positive feedback]
```
