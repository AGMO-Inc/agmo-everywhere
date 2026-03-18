---
name: ralph
description: Persistent execution loop that continues until all work is verified complete. Auto-linked by execute skill. Triggers on "끝까지 해줘", "멈추지 마", "ralph".
---

# Ralph — Persistent Completion Loop

## Overview

A persistence mechanism that ensures work continues until fully verified complete. Automatically linked when `agmo:execute` is invoked.

## Loop Logic

```
WHILE work remains:
  1. Check TODO list — any pending or failed?
  2. If pending → dispatch executor with category routing
  3. After each TODO → run verification
  4. If verification fails:
     - Collect failure context:
       - Approach taken (1-line summary of what was changed)
       - Failure reason (1-2 line verification judgment summary)
     - Attempt fix with accumulated feedback (up to 3 times):
       Each retry prompt MUST include ALL prior failure context:
       ```
       이전 시도 #{N}:
       - 접근법: {what was changed}
       - 실패 원인: {verification judgment summary}
       - 금지: 위 접근법 재시도
       ```
       (2nd retry includes attempt #1; 3rd retry includes attempts #1 + #2)
     - If 3 failures → invoke debugging skill (include all 3 failure contexts)
     - If debugging resolves → continue
     - If debugging fails → report to user, pause
  5. If all TODOs complete → run final verification (architect)
  6. If final verification passes → EXIT LOOP
  7. If final verification fails → address issues, re-verify
```

## Exit Conditions

The loop exits ONLY when:
1. **All TODOs complete** AND **architect final verification passes**
2. **User invokes cancel** ("취소", "중단", `agmo:cancel`)
3. **Unrecoverable error** that requires user input

## State Tracking

Ralph tracks progress simply:
- Current TODO index
- Completed TODO count / total
- Retry count per TODO
- Overall iteration count

No complex JSON state files — progress is tracked in conversation context.

## Rules

1. **Never claim completion without architect verification**
2. **Never skip a TODO** — each must pass verification
3. **3-fix limit per TODO** — escalate to debugging after 3 failures
4. **Report progress** — after each TODO, briefly state progress (e.g., "3/8 TODO 완료")
5. **Respect cancel** — immediately stop when user requests cancellation
