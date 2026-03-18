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
3. Present candidates for removal
4. Remove only with user approval

## Injection

Wisdom injection is handled by the `session-start` hook, NOT by this skill. This skill only handles recording and pruning.
