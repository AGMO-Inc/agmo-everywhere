# Review Judgment

Shared by `agents/critic.md` and `skills/code-review/SKILL.md`. Every finding carries a severity (CRITICAL / IMPORTANT / MINOR) and a bucket. Severity decides approval (zero CRITICAL = APPROVE). The bucket decides what happens next.

## Buckets

| Bucket | Meaning | What happens |
|---|---|---|
| Act on | Concrete problem on a real execution path, or a spec / acceptance violation | Dispatched to executor for a fix. CRITICAL before approval, IMPORTANT in the same round |
| Consider | Real but optional improvement. Fixing it is a judgment call | Reported. The orchestrator decides and records the reason either way |
| Noted | True observation with no action now (known gap, follow-up, `debt:` marker) | Reported for the record. No dispatch |
| Dismissed | Fails one of the filters below | Reported with the filter number in one line |

Rules:
- A CRITICAL finding is always Act on.
- Only Act on findings are dispatched for fixes. Consider, Noted and Dismissed never block approval.
- Every Dismissed finding names the filter that dismissed it.
- When a reviewer self-assigns a bucket, the orchestrator may re-bucket with a one-line reason.

## Filters (reasons to dismiss)

1. **Nitpick gravity.** Reviewers fill their review. If every finding is a nit or a style preference, the code is fine. Say so instead of inflating nits.
2. **Hypothetical vs actual.** "What if X is null?" is a finding only when a caller can actually pass null. Trace the call site. Upstream validation or the type system dismisses it.
3. **Premature abstraction.** Extracting a function, interface or layer is a finding only when the code must change in a second way now. Simple inline code that works beats a clean abstraction with one caller.
4. **"I would have done it differently."** A preference is not a bug, not a design flaw and not actionable. Dismiss unless the reviewer shows a concrete problem with the current approach.
5. **Missing context.** Dismiss findings that touch code the author did not change, flag patterns consistent with the rest of the codebase, or recommend something that conflicts with a known constraint.

When reviewers are right: more than one reviewer flags the same issue independently; the finding names a concrete execution path; the finding reveals a gap in your model of the code. Security and correctness findings get extra scrutiny before dismissal, even from a single reviewer.

## Agreement Map (panel reviews)

When two reviewers run (`code-review --panel`), list every finding once with who raised it. `-` means not raised.

```
| # | Finding (location, one line) | critic | architect / codex | Bucket | Note |
|---|---|---|---|---|---|
| 1 | src/x.ts:42 null deref on empty list | CRITICAL | CRITICAL | Act on | consensus |
| 2 | src/y.ts:10 extract helper | - | MINOR | Dismissed | filter 3 |
| 3 | src/z.ts:7 retry without backoff | IMPORTANT | - | Consider | single reviewer, real path |
```

A disagreement on severity or bucket is resolved by the orchestrator with the filters above. The reason goes in Note. Consensus on a finding is a strong signal to Act on.

## Design red flags (plan review)

Screen every plan for these. A red flag is a reason to revise the shape before execution.

1. **Shallow module.** Large interface, little hidden complexity. Signs: callers coordinate several methods for one operation; public options expose internal stages; learning the interface does not save learning the implementation.
2. **Information leakage.** The same representation, policy or protocol detail appears in more than one module, so one change needs coordinated edits. Keep storage schemas, wire types and framework objects private.
3. **Temporal decomposition.** Modules split by execution order (load, validate, transform, save) instead of by the knowledge they own. Group by domain ownership.
4. **Pass-through method.** Forwards the same arguments to another method of the same shape without adding policy or adaptation. Remove it or move the responsibility.
5. **Split ownership.** More than one module writes the same state or keeps its own copy. Give each piece of state one owner.
6. **Two ways to do one task.** The design supports more than one path for the same task. Keep one, move callers, delete the rest in the same change.
7. **Importable internals.** A caller can import a module's internals, so they become the interface. Make internals unreachable from outside.
8. **Hand-synced list.** Two or more places list the same items. Keep one list and derive the others, or fail the build when they disagree.
