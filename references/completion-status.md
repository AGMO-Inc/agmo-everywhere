# Completion Status Protocol

All skills must use one of the four completion statuses defined below to communicate task outcomes. This protocol ensures consistent status reporting across the entire plugin ecosystem.

## Status Definitions

### DONE

**Definition**
The task has been completed successfully with no outstanding issues or concerns.

**Usage Conditions**
- All acceptance criteria met
- No known bugs or edge cases
- All related tests pass (if applicable)
- Output is production-ready
- No follow-up actions required

**Output Format**
```
Status: DONE
Evidence: [Brief summary of how completion was verified]
```

Example:
```
Status: DONE
Evidence: All 4 acceptance criteria verified; tests pass; file exists with expected structure
```

---

### DONE_WITH_CONCERNS

**Definition**
The task is functionally complete but has known limitations, warnings, or minor issues that do not block usage.

**Usage Conditions**
- Core functionality is working
- Known issues are documented and acknowledged
- Workarounds exist or issues are low-impact
- Follow-up work is recommended but not required for current use
- May include: performance notes, browser compatibility caveats, edge cases, or technical debt

**Output Format**
```
Status: DONE_WITH_CONCERNS
Evidence: [Summary of what works and what concerns remain]
Concerns:
  - [Concern 1]
  - [Concern 2]
Follow-up: [Recommended next steps]
```

Example:
```
Status: DONE_WITH_CONCERNS
Evidence: Feature implemented and tested; design matches Figma mockups
Concerns:
  - Edge case: form submission fails with non-ASCII characters (rare)
  - Performance: initial render takes 2.5s with large datasets
Follow-up: Add unicode sanitization and pagination for large datasets in Phase 2
```

---

### BLOCKED

**Definition**
The task cannot be completed due to external dependencies, missing information, or unresolved blockers.

**Usage Conditions**
- External dependency is not available (API, library, design asset)
- Prerequisite task must complete first
- Required context or decision is missing
- Technical blocker prevents progress
- Task is waiting on another team or person

**Output Format**
```
Status: BLOCKED
Reason: [Specific reason why task is blocked]
Blocker: [What needs to be resolved]
Blocked-By: [Task ID, issue number, or resource name]
Next-Steps: [What needs to happen to unblock]
```

Example:
```
Status: BLOCKED
Reason: Cannot implement authentication flow without backend API specification
Blocker: Auth API contract not finalized
Blocked-By: Backend-Team/auth-api-spec#42
Next-Steps: Waiting for API spec review to complete; estimate 2 days
```

---

### NEEDS_CONTEXT

**Definition**
The task requires clarification, additional context, or decisions from the user or stakeholder before work can proceed.

**Usage Conditions**
- Acceptance criteria are ambiguous
- Multiple valid implementation approaches exist; design choice needed
- User intent is unclear
- Conflicting requirements need reconciliation
- Assumptions need validation

**Output Format**
```
Status: NEEDS_CONTEXT
Question: [What clarification is needed]
Options: [If applicable, list possible approaches or interpretations]
Dependency: [What decision/clarification unblocks this]
```

Example:
```
Status: NEEDS_CONTEXT
Question: Should the notification system use polling or WebSocket?
Options:
  1. Polling every 5 seconds (simpler, higher latency)
  2. WebSocket (real-time, more infrastructure)
  3. Server-Sent Events (middle ground)
Dependency: Need product/architecture decision on real-time vs. eventual consistency tradeoff
```

---

## Transition Rules

```
PENDING → DONE [all criteria met]
       → DONE_WITH_CONCERNS [functional but has known issues]
       → BLOCKED [external dependency]
       → NEEDS_CONTEXT [needs clarification]
```

Transitions between BLOCKED/NEEDS_CONTEXT and DONE happen when blockers are resolved or context is provided.

## Usage in Skills

When a skill completes a task, it must include one of these four statuses in its final output:

1. **Always present** one status section
2. **Always include** the mandatory fields for that status (Evidence, Reason, Question)
3. **Optional** fields (Concerns, Options, etc.) may be omitted if not applicable
4. Use the exact format shown above for consistency

## Examples Across Status Types

See individual status sections above for formatted examples.

