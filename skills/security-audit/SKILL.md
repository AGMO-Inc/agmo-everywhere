---
name: security-audit
description: Use to perform a security audit of the codebase. Triggers on "보안 점검", "security audit". Delegates to architect agent.
---

# Security Audit — 4-Domain Static Analysis

## Overview

A read-only security audit across four domains. This skill reports findings only — it does NOT auto-fix anything. All investigation uses local tools (grep, git, file reads); no external security tools (snyk, trivy, etc.) are required.

## Delegation

Delegate the full audit to the `agmo:architect` agent. Provide the repository root path and the four domain checklists below as context. The architect performs the investigation and returns a structured findings report.

## Domain 1: Secrets Archaeology

Search git history and the working tree for leaked credentials and sensitive data.

### Procedure

1. Scan git log for sensitive file commits:
   ```
   git log --all --full-history -- "*.env" "*.pem" "*.key" "*.p12" "*.pfx" ".env*"
   ```

2. Search commit diffs for high-signal secret patterns:
   ```
   git log -p --all | grep -iE \
     "(api[_-]?key|secret[_-]?key|access[_-]?token|client[_-]?secret|password|passwd|private[_-]?key)\s*[:=]\s*['\"][^'\"]{8,}"
   ```

3. Grep working tree for hardcoded secrets:
   ```
   grep -rniE \
     "(api[_-]?key|secret|token|password|passwd)\s*[:=]\s*['\"][A-Za-z0-9+/=_\-]{16,}" \
     --include="*.ts" --include="*.js" --include="*.java" --include="*.kt" \
     --include="*.py" --include="*.go" --include="*.yaml" --include="*.yml" \
     --exclude-dir=node_modules --exclude-dir=.git
   ```

4. Check for .env files tracked in git:
   ```
   git ls-files | grep -E "^\.env"
   ```

5. Search for AWS/GCP/Azure key patterns:
   ```
   grep -rniE "(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z\-_]{35}|ya29\.[0-9A-Za-z\-_]+)" \
     --exclude-dir=node_modules --exclude-dir=.git
   ```

## Domain 2: Supply Chain

Check declared dependencies for known vulnerable or suspicious packages.

### Procedure

1. Locate dependency manifests:
   ```
   find . -name "package.json" -not -path "*/node_modules/*" \
          -o -name "build.gradle" -o -name "build.gradle.kts" \
          -o -name "pom.xml" -o -name "requirements.txt" \
          -o -name "go.mod" -o -name "Gemfile"
   ```

2. For each `package.json`, check for:
   - Packages pinned to `*` or `latest` (no version lock)
   - `postinstall` / `preinstall` scripts that run shell commands
   - Typosquatting candidates: compare package names against top-100 npm names for single-char differences

3. For `build.gradle` / `build.gradle.kts`, check for:
   - Dependencies loaded over plain `http://` (not https)
   - `SNAPSHOT` versions in production configurations

4. Flag packages with known CVEs by cross-referencing the [OSV advisory list](https://osv.dev) (manual lookup — no external tool call). Focus on categories: RCE, SSRF, path traversal, prototype pollution.

5. Check for `package-lock.json` or `yarn.lock` presence. If absent, flag as MEDIUM (reproducible builds at risk).

## Domain 3: CI/CD

Audit GitHub Actions workflows for over-privileged permissions and secret exposure.

### Procedure

1. List all workflow files:
   ```
   find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null
   ```

2. Check top-level and job-level `permissions` blocks:
   - `permissions: write-all` → CRITICAL
   - `contents: write` combined with `pull-request` triggers → HIGH
   - Missing `permissions` block entirely (inherits max permissions) → MEDIUM

3. Search for secret exposure patterns:
   ```
   grep -n "secrets\." .github/workflows/*.yml
   ```
   - Secrets passed via `env:` to `run:` blocks → review each one
   - Secrets echoed or printed in run steps → CRITICAL

4. Check for third-party actions pinned to mutable refs:
   ```
   grep -nE "uses:\s+[^@]+@(main|master|HEAD|v\d+)" .github/workflows/*.yml
   ```
   Mutable ref (branch name or floating major tag without SHA pin) → HIGH

5. Check for `pull_request_target` with `${{ github.event.pull_request.head.sha }}` checkout — classic TOCTOU attack vector → CRITICAL

6. Review `on:` triggers for `workflow_dispatch` with unvalidated inputs used in `run:` steps (injection risk).

## Domain 4: OWASP Top 10

Scan the codebase for common vulnerability patterns.

### Procedure

1. **Injection (A03)**
   ```
   grep -rniE "(query|exec|eval|execute)\s*\(\s*['\"].*\+|`[^`]*\$\{" \
     --include="*.ts" --include="*.js" --include="*.java" --include="*.kt" \
     --exclude-dir=node_modules
   ```
   Look for raw string concatenation into SQL queries, OS commands, or `eval`.

2. **XSS (A03)**
   ```
   grep -rniE "(innerHTML|outerHTML|document\.write|dangerouslySetInnerHTML)" \
     --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
     --exclude-dir=node_modules
   ```

3. **Broken Auth / Missing Auth Check (A07)**
   ```
   grep -rniE "@(Public|PermitAll|AllowAnonymous|NoAuth)" \
     --include="*.ts" --include="*.java" --include="*.kt"
   ```
   Verify each unauthenticated endpoint is intentional.

4. **Sensitive Data Exposure (A02)**
   ```
   grep -rniE "(console\.(log|debug|info)|System\.out\.print|fmt\.Print)\s*\(.*password" \
     --include="*.ts" --include="*.js" --include="*.java" --include="*.kt" \
     --exclude-dir=node_modules
   ```

5. **Security Misconfiguration (A05)**
   ```
   grep -rniE "(cors\(|Access-Control-Allow-Origin:\s*\*|allowedOrigins\s*=\s*['\"]?\*)" \
     --include="*.ts" --include="*.js" --include="*.java" --include="*.kt" \
     --exclude-dir=node_modules
   ```

6. **Insecure Deserialization (A08)**
   ```
   grep -rniE "(ObjectInputStream|pickle\.loads|unserialize|yaml\.load\s*\()" \
     --include="*.ts" --include="*.js" --include="*.java" --include="*.kt" --include="*.py" \
     --exclude-dir=node_modules
   ```

## Severity Classification

| Severity | Criteria | Response SLA |
|----------|----------|--------------|
| CRITICAL | Direct secret exposure, RCE vector, auth bypass, TOCTOU in CI/CD | Fix before next deploy |
| HIGH | Mutable action refs, wildcard CORS, SQL injection candidates, hardcoded tokens in history | Fix within current sprint |
| MEDIUM | Missing lockfiles, floating dep versions, over-broad CI permissions, console.log of PII | Schedule in next sprint |
| LOW | Informational findings, best-practice gaps, style-only issues | Backlog |

## Output Format

The architect produces one report structured as follows:

```
## Security Audit Report
Audit Date: YYYY-MM-DD
Repository: <repo root>

---

### Domain 1: Secrets Archaeology
#### Findings
- [SEVERITY] <file or git ref>: <description>
  Recommendation: <action>

#### Summary
- CRITICAL: N  HIGH: N  MEDIUM: N  LOW: N

---

### Domain 2: Supply Chain
#### Findings
- [SEVERITY] <package>@<version>: <description>
  Recommendation: <action>

#### Summary
- CRITICAL: N  HIGH: N  MEDIUM: N  LOW: N

---

### Domain 3: CI/CD
#### Findings
- [SEVERITY] <workflow file>:<line>: <description>
  Recommendation: <action>

#### Summary
- CRITICAL: N  HIGH: N  MEDIUM: N  LOW: N

---

### Domain 4: OWASP Top 10
#### Findings
- [SEVERITY] <file>:<line> (<category>): <description>
  Recommendation: <action>

#### Summary
- CRITICAL: N  HIGH: N  MEDIUM: N  LOW: N

---

### Overall Risk Summary
| Domain | CRITICAL | HIGH | MEDIUM | LOW |
|--------|----------|------|--------|-----|
| Secrets Archaeology | N | N | N | N |
| Supply Chain | N | N | N | N |
| CI/CD | N | N | N | N |
| OWASP Top 10 | N | N | N | N |
| **Total** | **N** | **N** | **N** | **N** |

### Top Priority Actions
1. [CRITICAL] <action>
2. [HIGH] <action>
...
```

> Note: This skill reports only. No files are modified. Remediation must be performed separately via a dedicated implementation plan.
