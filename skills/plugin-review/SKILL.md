---
name: plugin-review
description: Use to analyze plugin usage patterns and suggest improvements. Triggers on "플러그인 리뷰", "plugin review", "사용 패턴 분석".
---

# Plugin Review — Self-Improvement Analysis

## Process

Delegate to `architect` agent:

### 1. Parse Claude Code Transcripts

**Quick start:** Run the bundled parsing script first:
`bash scripts/parse-transcripts.sh --project-key "{project-key}" --days 30`

This outputs a JSON summary of skills, agents, and tokens. Use this as the primary data source for analysis. The manual extraction steps below are for reference only.

Transcripts are stored in JSONL format under `~/.claude/projects/{project-key}/`.

**project-key derivation:** Replace every `/` in the project's absolute path with `-`.
Example: `/home/user/projects/my-project` → `-home-user-projects-my-project`

**Main session transcripts:**
`~/.claude/projects/{project-key}/{session-id}.jsonl`

**Sub-agent transcripts:**
`~/.claude/projects/{project-key}/{session-id}/subagents/*.jsonl`
`~/.claude/projects/{project-key}/{session-id}/subagents/*.meta.json`

#### Session Filtering

Read the first line of each `.jsonl` file to obtain the timestamp. Use that timestamp to filter sessions within the requested date range (default: last 30 days).

#### Skill Invocation Extraction

**Method 1 — Skill tool calls (LLM-initiated):**
For each line where `type == "assistant"`, inspect every item in the `content` array. For items where `type == "tool_use"` and `name == "Skill"`, extract `input.skill`. Tag source as `tool_call`.

**Method 2 — Slash commands (user-initiated):**
For each line where `type == "user"`, inspect every item in the `content` array. For text items, search for the pattern `<command-name>/?(agmo:)?(.+?)</command-name>` using regex. Extract the skill name (group 2). Tag source as `slash_command`.

Deduplicate: if both a slash command and a tool call for the same skill appear in the same turn (adjacent user + assistant messages), count it once and prefer the `slash_command` source.

#### Agent Invocation Extraction

For each line where `type == "assistant"`, inspect every item in the `content` array. For items where `type == "tool_use"` and `name == "Agent"`, extract `input.subagent_type` and `input.model`.

#### Token Extraction

For each line that contains a `message` object, read `message.usage`:
- `input_tokens`
- `output_tokens`
- `cache_read_input_tokens`
- `cache_creation_input_tokens`

Also read `message.model` to record which model produced the response.

#### Sub-agent Aggregation

For each `*.meta.json` file, read `agentType` to identify the agent type. For the corresponding `*.jsonl` file, aggregate tokens and model using the same extraction rules above.

### 2. Analyze Patterns

#### Skill Usage
- Frequency: which skills are used most/least?
- Unused skills (0 invocations in the period) — candidates for removal or trigger adjustment
- Most common skill chains (e.g., brainstorming → plan → execute)

#### Agent & Model Distribution
- Agent dispatch counts by type (executor, explore, architect, planner, critic, etc.)
- Model distribution: haiku% / sonnet% / opus%
- Category routing accuracy: are tasks being routed to the right model tier?

#### Token Usage
- Total tokens per session (input + output)
- Agent vs main token distribution
- Cache hit ratio: `cache_read_input_tokens / (input_tokens + cache_read_input_tokens)`
- Cost estimation trends

### 3. Generate Recommendations

For each finding, provide an actionable suggestion:

```
## Plugin Review — {date range}

### Usage Summary
- Sessions: N
- Top skills: skill1 (X), skill2 (Y), skill3 (Z)
- Agent distribution: executor (A%), explore (B%), architect (C%)
- Model distribution: haiku (X%), sonnet (Y%), opus (Z%)

### Recommendations

#### Skills
- "{skill}" used 0 times in 30 days → consider adjusting trigger conditions or removing
- "{skill}" triggered N times but cancelled M times → trigger too sensitive

#### Routing
- executor:opus used N times → review if standard category would suffice
- explore:sonnet used N times → most explores are quick, consider defaulting to haiku

#### Tokens
- Average session cost: ~N tokens (input: X, output: Y)
- Cache hit ratio: Z% → {good/needs improvement}
- Agent token overhead: N% of total

#### Wisdom
- {N} wisdom entries accumulated → consider pruning if >50
- Project "{name}" has 0 wisdom entries → normal or underdocumented?
```

### 4. Save Review

Invoke `agmo:save-note` to save as:
```
vault/shared/plugin-reviews/[Review] {YYYY-MM-DD} Plugin Review.md
```

### 5. Suggest Skill Updates

If a specific skill needs modification:
- Describe the proposed change and ask user for approval before making modifications.
