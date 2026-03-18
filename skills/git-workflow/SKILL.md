---
name: git-workflow
description: Use for git operations — commit, PR, branch management. Triggers on "커밋", "commit", "PR 만들어", "브랜치".
---

# Git Workflow — Commit, PR, Branch Management

## Commit

Delegate to `executor` agent (quick/haiku category):

1. **Stage specific files** — never use `git add -A` or `git add .`
2. **Write commit message**:
   - Summarize the "why", not the "what"
   - 1-2 sentences, concise
   - Follow existing repo conventions (check `git log` for style)
3. **Never skip hooks** — no `--no-verify`
4. **Never amend** unless explicitly asked — always create new commits

## Pull Request

Delegate to `executor` agent (standard/sonnet category):

1. **Check branch status** — is it pushed? up to date?
2. **Analyze all commits** on the branch (not just the latest)
3. **Create PR**:
   ```bash
   gh pr create --title "short title" --body "$(cat <<'EOF'
   ## Summary
   - bullet points

   ## Test plan
   - [ ] verification steps
   EOF
   )"
   ```
4. **Return PR URL** to user

## Branch Management

- **Create**: `git checkout -b feature/description`
- **Clean up**: after merge, delete the branch locally and remotely
- **Never force push to main/master** — warn user if requested

## Safety

- Never commit `.env`, credentials, or secrets
- Check `git status` before every commit
- Check `git diff` to review what will be committed
