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

After the architect agent completes verification with a PASS verdict, dispatch `codex:codex-rescue` agent for an independent code quality review from a different model. If the architect verdict is FAIL, skip Codex entirely — there is no value in a second opinion when the primary check already failed.

**How to dispatch:**

```
Agent(subagent_type="codex:codex-rescue", prompt="""
You are performing an independent code quality review.
Review the following code changes for bugs, security issues, performance problems, and design flaws.

Code context:
{code_diff_or_changed_files_summary}

Return your findings as structured JSON:
{ "verdict": "ALLOW" | "BLOCK", "findings": [...] }
""")
```

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

### Completion Status Mapping

The verification result (PASS/FAIL) maps to one of four completion statuses as follows:

#### PASS → DONE (No Warnings)
When the PASS verdict is achieved with no known warnings or concerns:
```
Status: DONE
Evidence: [Brief summary of how completion was verified]
```
Example: "All 4 acceptance criteria verified; build clean; tests pass"

#### PASS + Warnings → DONE_WITH_CONCERNS
When the PASS verdict is achieved but there are known warnings or edge cases:
```
Status: DONE_WITH_CONCERNS
Evidence: [Summary of what works]
Concerns:
  - [Warning 1]
  - [Warning 2]
Follow-up: [Recommended next steps]
```
Example: "Feature implemented and tests pass; edge case with non-ASCII input not handled; recommend unicode sanitization in Phase 2"

#### FAIL + External Dependency → BLOCKED
When verification fails due to unavailable external dependencies or prerequisites:
```
Status: BLOCKED
Reason: [Specific reason why verification failed]
Blocker: [What external dependency is missing]
Blocked-By: [Dependency name, service, or resource]
Next-Steps: [What needs to happen to unblock]
```
Example: "Cannot verify API integration; required backend service is not running; need to start dev server before re-running verification"

#### FAIL + Insufficient Information → NEEDS_CONTEXT
When verification cannot proceed due to missing information or ambiguous acceptance criteria:
```
Status: NEEDS_CONTEXT
Question: [What information is missing or unclear]
Evidence: [Why verification cannot proceed]
Dependency: [What clarification or decision is needed]
```
Example: "Cannot verify performance requirement; acceptance criteria does not specify target response time; need to clarify SLA before validating"

#### FAIL + Fixable Issue → Retry
When verification fails due to actual implementation issues (not external dependencies or missing information), the executor should fix the issue and retry:
- Document the failure clearly
- Suggest fix direction
- Re-run verification after fix is applied
- (Existing PASS/FAIL logic remains unchanged)

## Escalation Protocol

This section defines an extension of the **Output Format** for verification. It specifies the structured halt report format that verification outputs when a single TODO receives 3 consecutive FAIL verdicts.

### When This Applies

After the **3rd consecutive FAIL verdict** on the same TODO:
- The executor has attempted three distinct approaches, each resulting in FAIL
- Verification cannot clear the gate with current methodologies
- The issue requires deeper diagnosis beyond immediate retry cycles

### Important Scope Notes

- The **actual retry logic** (3-attempt cycle before escalation) is implemented in the `execute` skill, not here
- The **transition to debugging** (dispatch to `agmo:debugging` agent) is also handled by `execute`, not here
- This section defines **only the structured output format** that verification produces when reporting the halt

### Halt Report Format

When 3 consecutive FAILs are recorded, output the following structured report:

```
## Halt Report — [TODO title]

| Attempt | Approach | Failure Reason |
|---------|----------|----------------|
| 1 | [Describe approach #1] | [Root cause of failure #1] |
| 2 | [Describe approach #2] | [Root cause of failure #2] |
| 3 | [Describe approach #3] | [Root cause of failure #3] |

**Verdict**: This TODO cannot be resolved with the current approaches.
**Recommendation**: Escalate to agmo:debugging for root cause analysis.
```

### Example

```
## Halt Report — Implement user authentication

| Attempt | Approach | Failure Reason |
|---------|----------|----------------|
| 1 | Add JWT middleware to routes | Missing SECRET_KEY environment variable; tests fail |
| 2 | Mock SECRET_KEY in test setup | Import cycle detected in auth module; build fails |
| 3 | Refactor auth module structure | Breaking change to existing API; downstream tests fail |

**Verdict**: This TODO cannot be resolved with the current approaches.
**Recommendation**: Escalate to agmo:debugging for root cause analysis.
```

### Required Elements

1. **Attempts Table**: All 3 attempts with distinct approaches and specific failure reasons (not generic "test failed")
2. **Verdict**: Explicit statement that the TODO cannot be resolved with current methods
3. **Recommendation**: Clear pointer to escalation (agmo:debugging)
