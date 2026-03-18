---
name: cancel
description: Use when the user wants to stop current execution. Triggers on "취소", "중단", "그만", "cancel", "stop".
---

# Cancel — Stop Active Execution

## Limitation

Claude Code cannot programmatically abort an Agent call that is already in flight. This skill stops the orchestrator from dispatching further TODOs and reports status after the currently running agent completes.

## Process

1. Identify what is currently active (ralph loop, execute/ralph, parallel execution, plan-review loop)
2. Stop the active process
3. Report what was completed and what remains
4. Do NOT discard completed work — partial progress is preserved

## Output

```
## Cancelled
- Mode: [ralph / execute / parallel / plan-review]
- Completed: [N/M TODOs]
- Remaining: [list of pending TODOs]
- Files modified: [list]

Partial progress has been preserved.
- ralph/execute: Say "실행해줘" to resume.
- parallel: Say "병렬 실행 계속" to resume.
- plan-review: Say "플랜 리뷰 계속" to resume.
```
