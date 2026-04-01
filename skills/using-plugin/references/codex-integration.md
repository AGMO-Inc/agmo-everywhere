# Codex Integration (Optional)

> Requires **codex-plugin-cc** plugin installed separately. Codex integration is entirely optional — when not installed, all Codex-related steps are automatically skipped with zero impact on existing workflows.

## Prerequisites

- Install [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) (Codex CLI bridge for Claude Code)
- Codex CLI must be on PATH (`command -v codex` succeeds)
- OpenAI API key configured for Codex

## Detection

At session start, `hooks/session-start` checks `command -v codex` and writes the result to `hud.json`:
- `"codex": true` → `codex:codex-rescue` agent available
- `"codex": false` → All Codex gates skipped silently

All skills that use Codex MUST check `hud.json` → `codex` field before dispatching the agent.

## Gate Integration Points

All three gates use the same agent type (`codex:codex-rescue`) with different prompts to differentiate roles.

| Gate | Skill | Dispatch | Role |
|------|-------|----------|------|
| Plan Review | `plan-review` Phase 1.5 | `Agent(subagent_type="codex:codex-rescue")` | Challenge plan design from a different model's perspective |
| Verification | `verification` Codex Cross-Verification | `Agent(subagent_type="codex:codex-rescue")` | Independent code quality review after architect PASS |
| Debugging | `debugging` Phase 4.5 | `Agent(subagent_type="codex:codex-rescue")` | Fresh debugging perspective after 3 fix failures |

## Prompt Patterns

Each gate injects different context into the `codex:codex-rescue` agent prompt:

### Plan Review (Adversarial)

```
Agent(subagent_type="codex:codex-rescue", prompt="""
You are reviewing a plan document as an adversarial reviewer.
Your job is to challenge the plan, find pitfalls, and identify hidden assumptions.

Focus on:
- Practical pitfalls the reviewer may have missed
- Alternative architectures worth considering
- Hidden assumptions in the plan
- Real-world failure modes

Plan content:
{plan_content}

Return your findings as structured JSON:
{ "verdict": "ALLOW" | "BLOCK", "findings": [...] }
""")
```

### Verification (Code Review)

```
Agent(subagent_type="codex:codex-rescue", prompt="""
You are performing an independent code quality review.
Review the following code changes for bugs, security issues, performance problems, and design flaws.

Code context:
{code_diff_or_changed_files_summary}

Return your findings as structured JSON:
{ "verdict": "ALLOW" | "BLOCK", "findings": [...] }
""")
```

### Debugging (Rescue)

```
Agent(subagent_type="codex:codex-rescue", prompt="""
A debugging effort has failed 3 times. The architect has reviewed the architecture.
Provide a fresh perspective on the root cause and suggest alternative fix approaches.

Architect's analysis:
{architect_analysis}

Error context:
{error_details_and_prior_attempts}
""")
```

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
