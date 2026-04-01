---
name: debugging
description: Use for systematic debugging. Auto-triggered when verification fails 3 times. Triggers on "디버깅", "debug", "왜 안 돼".
---

# Debugging — Systematic Root Cause Analysis

## 3-Fix Limit Rule

If a fix has been attempted **3 times without success**, do NOT try a 4th fix. Instead, escalate to Phase 4.5 (architecture review).

## Scope Lock

Before starting any phase, lock the original issue scope:
- Write down the **exact symptom** being debugged in one sentence
- If an unrelated problem is discovered during investigation, log it separately and do NOT pivot — return to the original issue
- Scope creep is the #1 cause of debugging sessions that never resolve

## Process

### Phase 1: Reproduce

Confirm the failure is reproducible. Run the failing command/test and capture the exact error.

### Prior Learnings

Before isolating, search for related prior knowledge:
- Use `scripts/vault-read.sh` to directly read vault wisdom files (`learnings.md`, `issues.md`)
- Or invoke `agmo:vault-search` skill with relevant keywords (e.g., error message, module name, symptom)
- If a prior learning matches the current issue, apply it before proceeding to avoid repeat investigation

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

### Pattern Analysis

Classify the error type before attempting a fix:

| Type | Description | Data to Collect |
|------|-------------|-----------------|
| syntax | Invalid code structure caught at parse/compile time | File, line number, exact parse error message |
| runtime | Valid code that fails during execution | Stack trace, input values, execution context |
| logic | Code runs but produces wrong output | Expected vs actual values, affected code path |
| config | Wrong or missing configuration values | Config file path, key, expected vs actual value |
| dependency | External package or service mismatch | Package name, version, error from dependency |

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

#### Codex Rescue (Optional)

> Requires **codex-plugin-cc** installed. Check `hud.json` → `codex` field. If `false`, skip Codex rescue and proceed with architect's analysis only.

After the architect completes the architecture review, dispatch `codex:codex-rescue` agent to get a fresh perspective from a different model. Pass the architect's analysis as context so Codex can build on it rather than starting from scratch.

**How to dispatch:**

```
Agent(subagent_type="codex:codex-rescue", prompt="""
A debugging effort has failed 3 times. The architect has reviewed the architecture.
Provide a fresh perspective on the root cause and suggest alternative fix approaches.

Architect's analysis:
{architect_analysis}

Error context:
{error_details_and_prior_attempts}
""")
```

**Sequential execution order:**
1. Architect architecture review (existing Phase 4.5 behavior)
2. `codex:codex-rescue` agent dispatch with architect's findings as input context

**Handling Codex rescue results:**
- Codex rescue output is **advisory only** — treat as "reference opinion"
- The architect makes the final decision on which suggestions to apply
- If Codex is unavailable/timeout/error → proceed with architect's analysis only, no error raised

**Rationale:** When the same model fails 3 times on the same issue, a different model's perspective can identify blind spots that repeated attempts with the same model cannot.

### Phase 5: Verify

After the fix, run verification. The fix is not done until verification passes.

### Learnings Capture

After Phase 5 verification passes, automatically record the resolved issue:
- Invoke `agmo:wisdom` with the issue summary, root cause, and fix applied
- This ensures future debugging sessions can benefit from prior knowledge lookup

## Defense in Depth

4 layers of validation:
1. **Type safety** — does it compile / pass type checking?
2. **Unit tests** — does the specific function work?
3. **Integration** — does it work with the rest of the system?
4. **Acceptance** — does it satisfy the TODO's criteria?
