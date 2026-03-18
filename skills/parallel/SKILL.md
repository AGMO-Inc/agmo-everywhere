---
name: parallel
description: Use to dispatch multiple independent TODOs concurrently. Invoked by execute skill when independent TODOs are detected.
---

# Parallel — Concurrent Agent Dispatch

## Overview

Run multiple independent TODOs simultaneously by dispatching multiple executor agents. Each agent gets exclusive file ownership to prevent conflicts.

## Process

### 1. Identify Parallel Candidates

From the TODO list, select TODOs that:
- Have no dependency on each other
- Do NOT modify the same files
- Can be verified independently
- Do NOT modify files connected by import/export chains (e.g., if TODO A modifies src/auth/service.ts which imports src/models/user.ts, and TODO B modifies src/models/user.ts, they are NOT parallel candidates)

Files connected by import/export chains may break if modified concurrently, since each executor cannot see the other's changes.

### 2. Assign File Ownership

Each executor gets exclusive ownership of its files:

```
Executor A: owns src/auth/login.ts, src/auth/login.test.ts
Executor B: owns src/api/orders.ts, src/api/orders.test.ts
Executor C: owns src/utils/validation.ts
```

**Rule**: No two executors may modify the same file.
If files are connected by import/export relationships, assign them to the same executor or schedule their TODOs sequentially.

### 3. Handle Shared Files

If a file is needed by multiple TODOs:
- **Read-only sharing is OK** — multiple agents can read the same file
- **Write conflict** — split into sequential phases:
  1. Phase 1: parallel TODOs that don't touch the shared file
  2. Phase 2: sequential TODOs that modify the shared file

### 4. Dispatch

Launch all independent TODOs as separate Agent tool calls in a single response:

```
Agent(subagent_type="agmo:executor", model="sonnet", prompt="TODO 1...")
Agent(subagent_type="agmo:executor", model="sonnet", prompt="TODO 2...")
Agent(subagent_type="agmo:executor", model="haiku", prompt="TODO 3...")
```

Claude Code executes these concurrently when issued in the same message.

### 5. Integration Phase

After all parallel agents complete:
1. Verify no file conflicts occurred (check for overlapping modifications)
2. Run build to check everything compiles together
3. Run tests for all modified areas
4. Run `agmo:verification` on the combined result

Build and tests (steps 2-3) are essential because parallel executors cannot see each other's changes — the integration phase is the first point where incompatibilities become visible.

#### Fallback on Build/Test Failure

If build or tests fail in steps 2-3:
1. Discard all parallel changes (`git reset` to the pre-parallel snapshot)
2. Re-execute the failing TODOs sequentially, following the execute skill's standard path (verification + retry + debugging)
3. After sequential re-execution, repeat the Integration Phase from step 1

## Limits

- Maximum **5 concurrent agents** to avoid rate limits
- If more than 5 parallel TODOs, batch them in groups of 5
