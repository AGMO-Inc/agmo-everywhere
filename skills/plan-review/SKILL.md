---
name: plan-review
description: Use when a plan needs validation through a planner-critic loop. Triggers on "플랜 리뷰", "plan review", or when explicitly requested.
---

# Plan Review — Planner ↔ Critic Validation Loop

## Overview

Iterative refinement of a plan through structured debate between planner and critic agents. Runs until the critic approves or max iterations reached.

## Process

### Phase 1: Critic Review

Delegate to `critic` agent (complex category):

Review the plan against:
- [ ] All TODOs have concrete acceptance criteria
- [ ] File references are correct
- [ ] No unvalidated assumptions
- [ ] Scope is clear
- [ ] QA scenarios are agent-executable
- [ ] Dependencies identified
- [ ] No YAGNI violations

Output structured findings (CRITICAL / IMPORTANT / MINOR), then judge:
- **APPROVE** if zero CRITICAL findings remain — IMPORTANT and MINOR findings may still exist but do not block approval. Note them as recommendations in the approval.
- **REQUEST_CHANGES** if any CRITICAL finding exists.

### Phase 2: User Feedback

If the critic has findings, present them to the user. Ask if they agree with the critique.

### Phase 3: Planner Revision

If changes are needed, delegate to `planner` agent (complex category):
- Address each CRITICAL finding (mandatory)
- Address IMPORTANT findings (recommended)
- MINOR findings are optional
- Steelman the critic's concerns before dismissing any

### Phase 4: Re-Review

Loop back to Phase 1 with the revised plan.

**Max iterations: 5.** If CRITICAL findings persist after 5 rounds, present the best version to the user with remaining CRITICAL concerns noted and let the user decide whether to proceed or continue refining.

### Phase 5: Finalize

When critic outputs APPROVE:
1. Present final plan to user
2. The planner agent saves the revised plan directly to vault using vault-save.sh (same pattern as plan skill). Return the vault path to the orchestrator.
3. Ready for execution

## When to Use

- Complex plans with multiple components
- Plans that touch critical systems (auth, payments, data migration)
- When the user explicitly requests review ("plan review", "플랜 리뷰")
- NOT needed for simple, single-feature plans
