---
name: wisdom
description: Use to record a significant learning, decision, or issue to Obsidian vault. Triggers on "기억해", "이거 기록해", "wisdom", or when a significant learning occurs during debugging/verification.
---

# Wisdom — Intentional Knowledge Accumulation

## When to Record

Record wisdom ONLY at these moments:
- **Verification failure resolved** — the root cause and fix are worth remembering
- **Architecture decision made** — a deliberate choice with tradeoffs
- **Repeated mistake caught** — something that was wrong twice
- **User explicitly requests** — "이거 기억해", "기록해줘" (user asks to remember or record)

Do NOT auto-collect at session end. Do NOT record routine work.

## One-Line Principle

Each wisdom entry is **1-2 lines maximum**. If more context is needed, link to an Obsidian note.

```markdown
# Good
- CORS must be configured in SecurityFilterChain, not WebMvcConfigurer (filter order issue)

# Bad (too long)
- When using Spring Security, CORS configuration should be placed in the SecurityFilterChain
  bean rather than WebMvcConfigurer because the security filter chain runs before the MVC
  dispatcher servlet, which means preflight OPTIONS requests get rejected with 403...
```

## Storage

Delegate to `archivist` agent (haiku).

**CRITICAL: Wisdom entries are ALWAYS appended to existing category files (learnings.md, decisions.md, issues.md). NEVER create independent files like `[Wisdom] title.md`. The session-start hook only reads the 3 category files — independent files are never injected into sessions.**

### Project-specific wisdom
```
vault/{project}/wisdom/
  learnings.md   — technical discoveries, patterns
  decisions.md   — architecture and design decisions (include date)
  issues.md      — known issues and workarounds
```

### Shared wisdom (cross-project)
```
vault/shared/wisdom/
  learnings.md   — applies to all projects
  decisions.md   — org-wide decisions
  issues.md      — common pitfalls
```

### Recording Process

1. **Identify project** — `scripts/identify-project.sh` → PROJECT
2. **Choose category** — learnings / decisions / issues
3. **Choose scope** — project or shared (see "Choosing Project vs Shared" table)
4. **Build path** — project: `{PROJECT}/wisdom/{category}.md`, shared: `shared/wisdom/{category}.md`
5. **Ensure directory** — if file doesn't exist, create parent directory and initial file with `# {Category}` header
6. **Append entry** — `scripts/vault-update.sh append --path {WISDOM_PATH} --content "- [{YYYY-MM-DD}] {entry}"`
7. **Report** — confirm recording

## Recording Format
Append to the appropriate file:
```markdown
- [YYYY-MM-DD] Entry content here — optional [[link to detailed note]]
```

Optionally add metadata on the same line for traceability:
```markdown
- [YYYY-MM-DD] Entry content (confidence: high) (source: debugging) (ref: SecurityConfig.kt:42)
```

### Metadata Fields

| Field | Values | When to Use |
|-------|--------|-------------|
| **confidence** | `high` \| `medium` \| `low` | `high`: Verified through testing/direct evidence. `medium`: Reasonable inference from code review or multiple observations. `low`: Unconfirmed hypothesis or educated guess. |
| **source** | `debugging` \| `review` \| `user` \| `execute` | `debugging`: Root cause found during troubleshooting. `review`: Discovered during code review. `user`: User reported or requested. `execute`: Observed during implementation/verification. |
| **ref** | `file.ext:line` | Reference to specific code location (file path and line number) that demonstrates or validates this wisdom. |

**Note:** All metadata fields are optional. Include only what's relevant. Existing entries without metadata are valid and do not require retroactive updates.

### Examples

Good entries with metadata:
```markdown
- [2026-04-02] CORS must be configured in SecurityFilterChain, not WebMvcConfigurer (confidence: high) (source: debugging) (ref: SecurityConfig.kt:42)
- [2026-04-01] Spring autowiring fails if bean methods lack @Bean annotation (confidence: high) (source: review)
- [2026-03-30] React re-render issue might be caused by unstable object refs (confidence: low) (source: execute)
```

## Choosing Project vs Shared

| If the wisdom... | Store in... |
|------------------|-------------|
| Is specific to this project's codebase | Project wisdom |
| Applies to the tech stack generally (Kotlin, Spring, React) | Shared wisdom |
| Is an org-wide decision | Shared wisdom |

## Pruning

On user request ("wisdom 정리해줘" — user asks to clean up wisdom):
1. Read all wisdom files
2. Identify outdated, duplicate, or resolved entries
3. Prioritize removal candidates:
   - **High priority:** Entries with `confidence: low` (unverified hypotheses)
   - **Medium priority:** Outdated or superseded entries
   - **Low priority:** Duplicates that don't add new context
4. Present candidates for removal (sorted by priority)
5. Remove only with user approval

## Injection

Wisdom injection is handled by the `session-start` hook, NOT by this skill. This skill only handles recording and pruning.
