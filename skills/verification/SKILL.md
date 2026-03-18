---
name: verification
description: Use to verify a claim of completion with evidence. Auto-triggered after each TODO in execute. Triggers on "검증", "verify", "확인해줘".
---

# Verification — Evidence Before Claims

## Iron Law

**No completion claim without fresh verification evidence.** No exceptions.

## Gate Function

Every verification follows this sequence:

1. **IDENTIFY** — What command or check proves this claim?
2. **RUN** — Execute the verification command
3. **READ** — Check the output carefully
4. **VERIFY** — Does the evidence support the claim?
5. **CLAIM** — State the result WITH the evidence

## Red Flag Detection

If you catch yourself using these words, **STOP and gather evidence**:
- "should work"
- "probably"
- "seems to"
- "looks good"
- "I think"

These are signals that verification has not been done.

## Evidence Requirements

| Claim | Required Evidence |
|-------|-------------------|
| "Fixed" | Test output showing it passes now |
| "Implemented" | Build clean + tests pass + acceptance criteria met |
| "Refactored" | All existing tests still pass |
| "Debugged" | Root cause identified with file:line reference |
| "Complete" | All of the above that apply |

## Freshness

Evidence older than **5 minutes** must be re-collected. Do not reuse stale results.

## Delegation

Dispatch `architect` agent to perform verification:
- Run build command
- Run test suite (or relevant subset)
- Check linting / type checking
- Verify acceptance criteria from the TODO

## Output Format

```
## Verification: [TODO title]
- Evidence: [command run and output summary]
- Result: PASS / FAIL
- Details: [what passed, what failed]
```

If FAIL, include:
- What specifically failed
- Error message or output
- Suggested fix direction
