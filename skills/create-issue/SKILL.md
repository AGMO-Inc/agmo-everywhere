---
name: create-issue
description: Create a GitHub Issue following org templates (Feature/Task/Bug), auto-map to GitHub Project, auto-assign current gh user, and link parent for Task issues. Triggers on "이슈 만들어", "이슈 생성", "깃허브 이슈", "create issue", "new issue", "피처 이슈", "태스크 이슈", "버그 이슈", "이슈 발행". Use this when creating issues from conversation context or user input. If the user references an Obsidian note as the source, use note-to-issue instead.
---

# Create GitHub Issue

End-to-end workflow: create a GitHub Issue in the current session's repo, register it to the GitHub Project board, and link parent issues when applicable.

## Issue Types

| Type | Title format | GitHub Issue Type | Template |
|------|-------------|-------------------|----------|
| Feature | `[Feature] {summary}` | Feature | `01-기능-개발.yml` |
| Task | `[Task] {parent feature} - {summary}` | Task | `02-기능-개발---하위-태스크.yml` |
| Bug | `[Bug] {summary}` | Bug | `03-버그-리포트.yml` |

## Workflow

### Phase 1: Gather project info

Collect from the current session's project repo:

**A) Parse `## 레포/프로젝트 정보` section from CLAUDE.md:**
- `조직` → OWNER (e.g. `AGMO-Inc`)
- `프로젝트명` → PROJECT_NAME
- `프로젝트 url` → PROJECT_URL → extract project number (e.g. `/projects/2` → `2`)
- `레포` → REPO (e.g. `AGMO-Inc/monitor-server`)

If CLAUDE.md is missing or lacks this section, extract OWNER/REPO from git remote and ask the user for the project number.

**B) Resolve current user:**
```bash
ASSIGNEE=$(gh api user --jq '.login')
```
Use the gh CLI authenticated user as assignee. If lookup fails, ask the user for their GitHub username.

### Phase 2: Collect user input (single prompt)

Identify what the user already provided, then ask for missing items **in one prompt**.

**Required:**
1. **Issue type** — feature / task / bug (ask only if not already specified)
2. **Issue content** — map user's description to template sections

**Conditional:**
- **If Task:** parent Feature issue number (e.g. `#100`) — **must ask, required for parent linking**

**Always ask:**
- **Project Status** — ask user to choose: `Todo` / `In Progress` / `Weekly Done`. Default to `Todo` if user does not specify.

This is the single user-facing prompt. Collect everything at once, never ask multiple rounds:
> "이슈 생성 전 확인:
> 1. 상위 Feature 이슈 번호는? (예: #100)
> 2. Project Status: Todo / In Progress / Weekly Done (기본: Todo)"

### Phase 3: Create issue

Build the issue body following the org template. Fill required sections from user input; use reasonable defaults for optional sections. See `references/issue-templates.md` for required/optional sections per type.

**Feature issue body:**
```
> 🤖 **AI created**

### 1. 한 줄 요약
{summary}

### 2. 배경/문제
{background}

### 3. 요구 사항
{requirements — checkbox format}

### 4. 작업 항목
{tasks — checkbox format}

### 5. 참고
{references — optional}

### 6. 수용 기준 (선택)
{acceptance criteria — optional}
```

**Task issue body:**
```
> 🤖 **AI created**

### 상위 Feature
#{parent_number}

### 1. 작업 요약
{summary}

### 2. 체크리스트
{checklist — checkbox format}

### 3. 참고 (선택)
{references}
```

**Bug issue body:**
```
> 🤖 **AI created**

### 1. 증상 한 줄 요약
{summary}

### 2. 기대 동작
{expected behavior}

### 3. 실제 동작
{actual behavior}

### 4. 재현 방법 (Optional)
{reproduction steps}

### 5. 빈도
{항상/가끔/특정 조건에서만/재현 불가}

### 6. 사용자 영향
{치명/높음/중간/낮음}

### 7. 해결 방법
{resolution}
```

**Create command:**
```bash
gh issue create --repo "$REPO" \
  --title "{title per template format}" \
  --body "$BODY" \
  --assignee "$ASSIGNEE" \
  --type "{Feature|Task|Bug}"
```

Capture the created issue URL and number.

### Phase 4: Project integration (sequential)

**4-1. Add to project:**
```bash
gh project item-add {PROJECT_NUMBER} --owner "{OWNER}" --url "{ISSUE_URL}"
```

**4-2. Set Status:**
```bash
# Get project node ID
PROJECT_ID=$(gh project view {PROJECT_NUMBER} --owner "{OWNER}" --format json --jq '.id')

# Get item ID
ITEM_ID=$(gh project item-list {PROJECT_NUMBER} --owner "{OWNER}" --format json \
  --jq ".items[] | select(.content.url == \"{ISSUE_URL}\") | .id")

# Get Status field ID and option ID
FIELD_DATA=$(gh project field-list {PROJECT_NUMBER} --owner "{OWNER}" --format json \
  --jq '.fields[] | select(.name == "Status")')
FIELD_ID=$(echo "$FIELD_DATA" | jq -r '.id')
OPTION_ID=$(echo "$FIELD_DATA" | jq -r ".options[] | select(.name == \"{STATUS}\") | .id")

# Set status
gh project item-edit \
  --project-id "$PROJECT_ID" \
  --id "$ITEM_ID" \
  --field-id "$FIELD_ID" \
  --single-select-option-id "$OPTION_ID"
```

**4-3. Link parent (Task only):**
```bash
gh issue edit {NEW_ISSUE_NUMBER} --repo "$REPO" --add-parent {PARENT_ISSUE_NUMBER}
```

If `--add-parent` is not supported by the gh version, use GraphQL fallback:
```bash
PARENT_ID=$(gh issue view {PARENT_NUMBER} --repo "$REPO" --json id --jq '.id')
CHILD_ID=$(gh issue view {NEW_NUMBER} --repo "$REPO" --json id --jq '.id')

gh api graphql -f query='
  mutation {
    addSubIssue(input: { issueId: "'"$PARENT_ID"'", subIssueId: "'"$CHILD_ID"'" }) {
      issue { id }
    }
  }'
```

### Phase 5: Report

Summarize all results:
- Issue URL (clickable link)
- Issue type + title
- Assignee: {ASSIGNEE}
- Project: {PROJECT_NAME} — Status: {STATUS}
- Parent link: #{PARENT_NUMBER} (Task only)

## Completion checklist

Before reporting success, verify every item:

- [ ] Title follows template format (`[Feature]`, `[Task]`, `[Bug]`)
- [ ] Body includes all required sections for the issue type
- [ ] Assignee is set to current gh user
- [ ] Issue is registered to the project board
- [ ] Project Status is set to the user-selected value
- [ ] Parent Feature issue is linked (Task only)
- [ ] `--type` flag sets the correct Issue Type

## Safety

- Do not create the issue if project info cannot be resolved — ask user first
- Do not proceed with Task type if parent Feature number is missing
- First line of body must include `AI created` marker
- On failure, report the error and ask whether to retry
