---
name: setup
description: Use for first-time plugin configuration. Triggers on "setup", "설정", "초기 설정".
---

# Setup — First-Time Plugin Configuration

## Process

### 1. Verify Obsidian Vault

Check that the vault path exists:
```
${AGMO_VAULT_ROOT}/
```

If not found, ask user for the correct vault path.

### 2. Create Shared Directories

```bash
mkdir -p ${AGMO_VAULT_ROOT}/shared/wisdom
mkdir -p ${AGMO_VAULT_ROOT}/shared/plugin-reviews
```

### 3. Initialize Wisdom Files

Create empty wisdom files if they do not exist:
```
shared/wisdom/learnings.md
shared/wisdom/decisions.md
shared/wisdom/issues.md
```

### 4. Verify Plugin Installation

```bash
claude plugin list
```

Confirm `agmo@agmo-local` is listed and enabled.

### 5. Report

```
## Setup Complete

- Obsidian vault: ${AGMO_VAULT_ROOT}/
- Shared wisdom: initialized
- Plugin: agmo@agmo-local enabled (verify version with plugin list)

Ready to use. Say "brainstorming" to start a new project,
or "plan" to create an implementation plan.
```

## Migration

### From v0.1.x (usage-log.json)

If `shared/plugin-analytics/usage-log.json` exists in your vault:

```bash
mv "${AGMO_VAULT_ROOT}/shared/plugin-analytics/usage-log.json" "${AGMO_VAULT_ROOT}/shared/plugin-analytics/usage-log.archived.json"
```

This file is no longer used. Plugin review now parses Claude Code transcripts directly.
