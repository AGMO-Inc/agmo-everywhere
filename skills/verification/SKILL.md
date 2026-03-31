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

Re-collect evidence after each TODO completes. Never reuse results from a previous TODO or a previous session.

## Delegation

Dispatch `architect` agent to perform verification:
- Run build command
- Run test suite (or relevant subset)
- Check linting / type checking
- Verify acceptance criteria from the TODO

## Codex Cross-Verification (Optional)

> Requires **codex-plugin-cc** installed. Check `hud.json` → `codex` field. If `false`, skip this section entirely and use the architect's verdict as final.

After the architect agent completes verification with a PASS verdict, invoke `/codex:review` (codex-plugin-cc slash command) for an independent code quality review from a different model. If the architect verdict is FAIL, skip Codex entirely — there is no value in a second opinion when the primary check already failed.

### Verdict Merge Table

Codex verdict is interpreted as ALLOW (no issues found) or BLOCK (issues found that should prevent merge).

| Architect Verdict | Codex Verdict | Final Verdict |
|-------------------|---------------|---------------|
| PASS | ALLOW | **PASS** |
| PASS | BLOCK | **FAIL** — include Codex feedback in retry context |
| FAIL | (any) | **FAIL** — Architect verdict takes precedence |
| PASS | Skip (unavailable) | **PASS** — proceed with Architect verdict only |

### Codex Fallback Rules

- **Auth failure (401/403)**: Disable Codex for the entire session. All subsequent gates skip Codex.
- **Rate limit (429)**: Skip this gate only. Retry at next verification gate.
- **Timeout**: Skip. Use Architect verdict only.
- **Partial response (JSON unparseable)**: Treat as timeout — skip. A valid Codex verdict must be a complete, parseable JSON response.

### Key Constraint

Codex can only raise the quality bar, never lower it. If Architect says FAIL, the final verdict is always FAIL regardless of Codex opinion.

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
