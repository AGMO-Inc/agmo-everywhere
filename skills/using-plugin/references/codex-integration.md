# Codex Integration (Optional)

> Requires **codex-plugin-cc** plugin installed separately. Codex integration is entirely optional — when not installed, all Codex-related steps are automatically skipped with zero impact on existing workflows.

## Prerequisites

- Install [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) (Codex CLI bridge for Claude Code)
- Codex CLI must be on PATH (`command -v codex` succeeds)
- OpenAI API key configured for Codex

## Detection

At session start, `hooks/session-start` checks `command -v codex` and writes the result to `hud.json`:
- `"codex": true` → Codex slash commands available
- `"codex": false` → All Codex gates skipped silently

All skills that use Codex MUST check `hud.json` → `codex` field before invoking any `/codex:*` command.

## Gate Integration Points

| Gate | Skill | Codex Command | Role |
|------|-------|---------------|------|
| Plan Review | `plan-review` Phase 1.5 | `/codex:adversarial-review` | Challenge plan design from a different model's perspective |
| Verification | `verification` Codex Cross-Verification | `/codex:review` | Independent code quality review after architect PASS |
| Debugging | `debugging` Phase 4.5 | `/codex:rescue` | Fresh debugging perspective after 3 fix failures |

## Verdict Merge Logic

When both Agmo (architect) and Codex produce verdicts, merge as follows:

| Agmo Verdict | Codex Verdict | Final Verdict |
|--------------|---------------|---------------|
| PASS | ALLOW | **PASS** |
| PASS | BLOCK | **FAIL** — retry with Codex feedback |
| FAIL | (any) | **FAIL** — Agmo verdict takes precedence |
| PASS | (skipped) | **PASS** — proceed without Codex |

**Principle:** Codex can only raise the quality bar, never lower it.

## Fallback Rules

| Scenario | Action | Scope |
|----------|--------|-------|
| Codex not installed | All gates skip Codex | Session-wide (detected at SessionStart) |
| Auth failure (401/403) | Disable Codex | Session-wide (no retry) |
| Rate limit (429) | Skip this gate | Single gate (retry at next gate) |
| Timeout | Skip this gate | Single gate |
| Partial response (JSON unparseable) | Treat as timeout, skip | Single gate |

## Codex Guidelines

1. **Codex is advisory, not authoritative.** It provides a second opinion; Agmo workflows make the final decision.
2. **Graceful degradation.** Codex failure NEVER blocks or breaks existing workflows.
3. **Self-review bias reduction.** The primary value is having a different model review what Claude produced.
