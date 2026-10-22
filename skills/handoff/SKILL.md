---
name: handoff
description: Use when the user wants to pause and leave a resume point for a later session or after /compact. Triggers on "핸드오프", "이어서 할 수 있게 정리해", "handoff", "여기까지 정리".
---

# Handoff — Write a Resume Point

## Overview

Writes `resume.md` into the session state directory so the next session (or this session after `/compact`) can continue from `next` without re-verifying `verified`. `hooks/session-start` injects this file automatically when `source` is `compact` or `resume`. The execute and ralph skills refresh the same file at every TODO boundary; this skill is the manual trigger for everything else.

## Process

1. Stop at a safe boundary. Finish or back out of the current atomic step. Start nothing new.
2. Collect state with Bash only: `git status --short`, `git log --oneline -5`, the active plan path, the current TODO number, and the open question (if any).
3. Write the file. Each field is at most 2 lines. Keep the whole file under 1,200 characters (the hook truncates at 1,500 characters).

   ```bash
   D="${AGMO_STATE_DIR:-$HOME/.agmo/state}/sessions/${CLAUDE_CODE_SESSION_ID:?no session id}" && mkdir -p "$D" && cat > "$D/resume.md" <<'EOF'
   # Resume
   - intent: <what the user asked for, one sentence; plan or design vault path if any>
   - progress: <done so far; TODO n/m if executing a plan>
   - verified: <claims that passed verification, with the evidence command; do not re-verify on resume>
   - next: <the first action on resume, exact skill or command>
   - gotchas: <traps, failed approaches, files not to touch>
   EOF
   ```
4. If `CLAUDE_CODE_SESSION_ID` is empty, report that no session id is available and print the resume content in the reply instead of writing the file.

## Output

```
## Handoff written
- File: ~/.agmo/state/sessions/<id>/resume.md (<N> chars)
- Next on resume: <the next field>
Resume with /resume or continue after /compact; the hook injects this file.
```
