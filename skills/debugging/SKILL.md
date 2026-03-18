---
name: debugging
description: Use for systematic debugging. Auto-triggered when verification fails 3 times. Triggers on "디버깅", "debug", "왜 안 돼".
---

# Debugging — Systematic Root Cause Analysis

## 3-Fix Limit Rule

If a fix has been attempted **3 times without success**, do NOT try a 4th fix. Instead, escalate to Phase 4.5 (architecture review).

## Process

### Phase 1: Reproduce

Confirm the failure is reproducible. Run the failing command/test and capture the exact error.

### Phase 2: Isolate

Narrow down the scope:
- Which file? Which function? Which line?
- What changed recently that could cause this?
- Does the problem exist on a clean state?

Delegate to `explore` agent (standard) to search for related code.

### Phase 3: Trace Root Cause

5-step root cause tracing:
1. **Start from the error** — read the stack trace or error message
2. **Follow the data** — trace the data flow backwards from the error point
3. **Check assumptions** — what does the code assume that might be wrong?
4. **Verify dependencies** — are external services, configs, types correct?
5. **Identify the root** — the actual cause, not a symptom

Delegate to `architect` agent for analysis.

### Phase 4: Fix

Delegate to `executor` agent to implement the fix. Then run `agmo:verification`.

### Phase 4.5: Architecture Review (Escalation)

If 3 fixes have failed:
1. **STOP fixing code**
2. Delegate to `architect` agent:
   - Is the approach fundamentally wrong?
   - Are we solving the right problem?
   - Should the TODO or plan be revised?
3. Present findings to user
4. Revise approach before attempting more fixes

### Phase 5: Verify

After the fix, run verification. The fix is not done until verification passes.

## Defense in Depth

4 layers of validation:
1. **Type safety** — does it compile / pass type checking?
2. **Unit tests** — does the specific function work?
3. **Integration** — does it work with the rest of the system?
4. **Acceptance** — does it satisfy the TODO's criteria?
