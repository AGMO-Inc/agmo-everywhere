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

### What Works Well
- [positive feedback]
```
