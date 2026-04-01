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

### Pre-PR Test Gate

Before creating a PR, ensure the build and tests pass:

1. **Auto-detect build/test commands** — check for:
   - `package.json` scripts (`npm test`, `npm run build`)
   - `Makefile` targets
   - `gradle` or `maven` commands
   - Other project-specific build tools
2. **Run build and tests** — execute the detected commands in order
3. **Handle missing tests**:
   - If no build/test commands found, log a warning and skip (do not fail)
4. **On failure**:
   - Stop and report the failure details to the user
   - Do not proceed with PR creation until tests pass
5. **On success** — proceed to PR creation step

### CHANGELOG Update

If the PR contains user-facing changes (new features, bug fixes, breaking changes):

1. **Check for CHANGELOG.md** — if the file exists in the project root:
   - Add a checklist item: `- [ ] CHANGELOG.md updated`
   - Include in PR body under "Test plan"
2. **If CHANGELOG.md does not exist** — skip this step (no action required)
3. **Format** — follow the project's existing CHANGELOG pattern (if present)

### Create PR

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
