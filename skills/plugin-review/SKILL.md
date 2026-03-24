---
name: plugin-review
description: Use to analyze plugin usage patterns and suggest improvements. Triggers on "플러그인 리뷰", "plugin review", "사용 패턴 분석".
---

# Plugin Review — Self-Improvement Analysis

## Process

### 1. Collect Data

Run the bundled parsing script to aggregate usage across ALL projects:

```bash
python3 {skill_base_dir}/scripts/parse-transcripts.py --all-projects --days 30
```

This scans every `~/.claude/projects/*/` directory, parses JSONL transcripts, and outputs a single JSON summary to stdout. Stderr shows progress.

The script automatically extracts:
- **Skill invocations** — both Skill tool calls and `/slash-command` usage, deduplicated
- **Agent dispatches** — agent type + model for each Agent tool call
- **Token usage** — input/output/cache tokens, split by main vs sub-agent, by model
- **Skill chains** — 2-gram sequences showing common skill workflows
- **Per-project breakdown** — which projects use which skills/agents

### 2. Analyze Patterns

Delegate to `architect` agent with the JSON output. The architect should analyze:

#### Skill Usage
- Frequency ranking — which skills are most/least used
- Unused skills (0 invocations) — candidates for removal or trigger adjustment
- Slash command vs tool call ratio — indicates whether users invoke directly or the LLM routes
- Most common skill chains (e.g., brainstorming → plan → execute)

#### Agent & Model Distribution
- Agent dispatch counts by type
- Model distribution: haiku% / sonnet% / opus%
- Category routing accuracy: are executor/explore/archivist routed to appropriate model tiers?
- Naming consistency: detect `agmo:` prefix vs bare name dispatches

#### Token Usage
- Total tokens (input + output + cache)
- Main session vs sub-agent token split
- Cache hit ratio: `cache_read / (input + cache_read)`
- Model-wise cost distribution
- Outlier sessions consuming disproportionate tokens

#### Per-Project Breakdown
- Session count per project
- Top skills and agents per project
- Projects with plugin installed but barely used

### 3. Generate Report

Structure the report as:

```
## Plugin Review — {start_date} ~ {end_date}

### Usage Summary
- Sessions: N (across M projects)
- Top skills: skill1 (X), skill2 (Y), skill3 (Z)
- Agent distribution: executor (A%), explore (B%), architect (C%)
- Model distribution: haiku (X%), sonnet (Y%), opus (Z%)

### Per-Project Breakdown
| Project | Sessions | Top Skills | Top Agents |
|---------|----------|-----------|------------|
| {name}  | N        | skill1    | executor   |

### Skill Analysis
- Full frequency table with slash/tool breakdown
- Unused skills list
- Chain patterns

### Recommendations

#### Skills
- "{skill}" used 0 times → adjust trigger or remove
- "{skill}" triggered N times but cancelled M times → trigger too sensitive

#### Routing
- executor:opus used N times → review if sonnet suffices
- explore:sonnet used N times → most explores are quick, default haiku

#### Tokens
- Average session cost: ~N tokens
- Cache hit ratio: Z%
- Agent token overhead: N% of total

#### Wisdom
- {N} wisdom entries → prune if >50
```

### 4. Save Review

Invoke `agmo:save-note` to save as:
```
vault/shared/plugin-reviews/[Review] {YYYY-MM-DD} Plugin Review.md
```

### 5. Suggest Skill Updates

If specific skills need modification:
- Describe the proposed change clearly
- Ask user for approval before making modifications
