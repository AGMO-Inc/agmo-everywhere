# Principles (on demand)

Load this file only when a decision needs a stated rationale: a design choice in brainstorming or plan, a disputed review finding, a stuck debugging loop. Do not load it at session start. Each entry: when to apply, then the rule.

## attack-the-premise
When two or more fixes that share one premise have failed the same gate. Write the premise down in one sentence. Find an observation that would differ if the premise were false and make it before the next fix. Follow the evidence: if it contradicts the premise, the cause is elsewhere. Do not start the next fix before the premise is written down and tested.

## never-block-on-the-human
When tempted to ask "should I do X?" on reversible work. Proceed, then present the result and the reason. Irreversible actions (force-push, deleting production data, external messages) still need confirmation. Product direction comes from the human; execution should not block on them.

## guard-the-context-window
When context is filling up: large outputs, long files, repeated reads, fan-out planning. Route bulk reading to subagents and keep summaries in the main thread, not raw payloads. Size phases, cap files per phase, and set turn budgets.

## encode-lessons-in-structure
When you write the same instruction a second time or notice a recurring correction. Encode the rule as a lint, a metadata flag, a runtime check or a script instead of more text. If the lesson needs judgment and cannot be encoded, make the instruction more prominent and add an example of the failure. If a structural fix exists, use only the structural fix.

## sequence-verifiable-units
For multi-step work (sweeps, migrations, runs of similar edits) and for how commits and PRs stack. Break work into small units that each end in a checkable state, verify each before the next, and order delivery so a reviewer can replay it: the failing test first, then the fix on top.

## explain-the-number
Before you trust, report or act on a measured number (speedup, regression, throughput, latency, eval score). Name the resource or code path that bounds it ("why not double?"). List what else the number could be measuring (errors, cached or skipped work, code that never ran, an untuned side, noise) and rule each out with evidence. Keep run count, spread and limiter next to the number.

## separate-before-serializing-shared-state
When concurrent actors might write the same file, branch, key or state object. First eliminate the sharing: give each actor its own owned file, key or branch and merge at the read boundary. Serialize structurally (lockfile, sequential phases, single writer) only when one shared writer is a real invariant. Instructions and conventions are not concurrency control.

## make-operations-idempotent
When designing commands, lifecycle steps or processing loops that run amid crashes, restarts and retries. Derive each step from the state that exists, not from what the previous run meant to do. Anything a run leaves behind (lock, temp file, half-written record) must be recognizable as stale by the next run. Test: what happens if this runs twice, and if the previous run crashed at every possible point?

## model-the-domain
When writing stateful logic, or when code branches a lot or repeats a shape assumption across files. Encode the domain in a data structure (state machine, typed model, lookup table, discriminated union, reducer) instead of scattered conditionals, so invalid states are unrepresentable. Do not force an abstraction onto code that is already clear, local and unlikely to grow. The sign you skipped this: a feature that adds one more branch to an if/else chain, or a second boolean that must stay in sync with the first.

## subtract-before-you-add
When sequencing an addition, refactor or rewrite. Remove dead code, redundant validators and stub references first, then build on the simpler base. Cut before you polish. Design for observed usage, not speculative edge cases. When a reference has no novel content, delete it rather than leaving a stub.
