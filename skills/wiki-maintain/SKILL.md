---
name: wiki-maintain
description: Use to audit and repair the llm-wiki context spine by detecting stale, low-confidence, contested, or broken entries. Triggers on "위키 점검", "wiki maintain", "wiki audit", "컨텍스트 정리", "wiki 오염", "모순 감지".
---

# Wiki Maintain — LLM-Wiki Context Audit and Repair

## When to Use

- User requests a wiki health check or context audit.
- You detect context drift, outdated pages, or contradictions during a session.
- A newly captured page conflicts with existing wiki content.

## Workflow

### 1. Run Audit

```bash
bash scripts/wiki-maintain.sh --project {PROJECT} --format json
```

Use `--max-age-days {N}` to override the default staleness threshold (90 days).
Use `--format markdown` for a human-readable summary instead.

### 2. Classify by Severity

Parse the returned issue list and sort:

- **high** — address first (LOW_CONFIDENCE, CONTESTED)
- **medium** — address next
- **low** — address last or skip if low risk

### 3. Remediate Each Issue

Three remediation actions are available. Map each issue kind to the appropriate action — see `reference.md` for the full kind × action table.

**Supersede** — write a corrected capture that replaces the old page:
```bash
bash scripts/wiki-capture.sh --supersedes "{old/relative/path.md}" \
  --project {PROJECT} --title "{Corrected Title}" \
  --confidence high --content "{verified content}"
```

**Contest** — mark a page as contested when a contradiction exists but cannot yet be resolved:
```bash
bash scripts/wiki-capture.sh --contested \
  --project {PROJECT} --title "{Title — Contested}" \
  --content "{description of contradiction and known evidence}"
```

**Recapture / Verify** — refresh or add missing frontmatter by re-running `wiki-capture.sh` with updated content; for MISSING_FRONTMATTER pages, edit the file directly to add the YAML block.

### 4. Report

After remediation, re-run the audit and confirm issue count decreased. Report remaining issues and any that require user input.

## Guard Rules

- **Never supersede or contest without confirmation.** Verify the contradiction against code, reality, or explicit user correction before acting.
- **Do not batch-supersede.** Assess each issue individually.
- **Preserve contested pages** when the truth is uncertain — do not delete them.
- For issue-kind-to-action mapping details, consult `skills/wiki-maintain/reference.md`.
