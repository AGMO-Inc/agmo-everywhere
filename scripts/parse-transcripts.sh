#!/usr/bin/env bash
# parse-transcripts.sh — Parse Claude Code JSONL transcripts for plugin-review analysis
# Usage: bash scripts/parse-transcripts.sh --project-key "{project-key}" --days {N}

set -euo pipefail

# ── Dependency check ────────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found. Install jq to use this script." >&2
  exit 1
fi

# ── Argument parsing ─────────────────────────────────────────────────────────
PROJECT_KEY=""
DAYS=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-key)
      PROJECT_KEY="$2"
      shift 2
      ;;
    --days)
      DAYS="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_KEY" ]]; then
  echo "Error: --project-key is required." >&2
  exit 1
fi

# ── Path setup ───────────────────────────────────────────────────────────────
PROJECTS_DIR="$HOME/.claude/projects/$PROJECT_KEY"

EMPTY_RESULT=$(jq -n \
  --argjson days "$DAYS" \
  '{
    period: { days: $days, sessions: 0 },
    skills: {},
    agents: {},
    tokens: {
      total_input: 0,
      total_output: 0,
      cache_read: 0,
      cache_creation: 0
    }
  }')

if [[ ! -d "$PROJECTS_DIR" ]]; then
  echo "$EMPTY_RESULT"
  exit 0
fi

# Collect top-level JSONL files (main session transcripts)
ALL_JSONL=()
while IFS= read -r line; do
  ALL_JSONL+=("$line")
done < <(find "$PROJECTS_DIR" -maxdepth 1 -name "*.jsonl" 2>/dev/null | sort)

if [[ ${#ALL_JSONL[@]} -eq 0 ]]; then
  echo "$EMPTY_RESULT"
  exit 0
fi

# ── Date threshold (seconds since epoch) ─────────────────────────────────────
# Calculate cutoff as DAYS ago from now (portable: works on macOS and Linux)
if date -v -"${DAYS}"d +%s &>/dev/null 2>&1; then
  # macOS BSD date
  CUTOFF_EPOCH=$(date -v -"${DAYS}"d +%s)
else
  # GNU date
  CUTOFF_EPOCH=$(date -d "${DAYS} days ago" +%s)
fi

# ── Filter sessions by first-line timestamp ───────────────────────────────────
FILTERED_JSONL=()
for f in "${ALL_JSONL[@]}"; do
  FIRST_LINE=$(head -1 "$f" 2>/dev/null) || continue
  [[ -z "$FIRST_LINE" ]] && continue

  # Extract timestamp field from first JSON line
  TS=$(echo "$FIRST_LINE" | jq -r '.timestamp // empty' 2>/dev/null) || continue
  [[ -z "$TS" ]] && continue

  # Convert ISO8601 timestamp to epoch
  if date -j -f "%Y-%m-%dT%H:%M:%S" "${TS%%.*}" +%s &>/dev/null 2>&1; then
    # macOS BSD date
    FILE_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${TS%%.*}" +%s 2>/dev/null) || continue
  else
    # GNU date
    FILE_EPOCH=$(date -d "$TS" +%s 2>/dev/null) || continue
  fi

  if [[ "$FILE_EPOCH" -ge "$CUTOFF_EPOCH" ]]; then
    FILTERED_JSONL+=("$f")
  fi
done

SESSION_COUNT=${#FILTERED_JSONL[@]}

if [[ "$SESSION_COUNT" -eq 0 ]]; then
  echo "$EMPTY_RESULT"
  exit 0
fi

# ── Build list of all JSONL files to process (main + subagents) ──────────────
ALL_FILES_TO_PROCESS=()
for f in "${FILTERED_JSONL[@]}"; do
  ALL_FILES_TO_PROCESS+=("$f")
  # Derive session-id from filename (strip directory and .jsonl extension)
  SESSION_ID=$(basename "$f" .jsonl)
  SUBAGENT_DIR="$PROJECTS_DIR/$SESSION_ID/subagents"
  if [[ -d "$SUBAGENT_DIR" ]]; then
    SUB_JSONL=()
    while IFS= read -r line; do
      SUB_JSONL+=("$line")
    done < <(find "$SUBAGENT_DIR" -name "*.jsonl" 2>/dev/null | sort)
    for sf in "${SUB_JSONL[@]}"; do
      ALL_FILES_TO_PROCESS+=("$sf")
    done
  fi
done

# ── Process all files with jq ─────────────────────────────────────────────────
# Pass all files to a single jq invocation for efficiency
RESULT=$(jq -n \
  --argjson days "$DAYS" \
  --argjson sessions "$SESSION_COUNT" \
  '
  {
    period: { days: $days, sessions: $sessions },
    skills: {},
    agents: {},
    tokens: {
      total_input: 0,
      total_output: 0,
      cache_read: 0,
      cache_creation: 0
    }
  }
  ' )

# Process each file individually and accumulate into a temp JSON file
ACCUMULATOR=$(echo "$RESULT")

for f in "${ALL_FILES_TO_PROCESS[@]}"; do
  FILE_DATA=$(jq -sc '
    reduce .[] as $line (
      { skills: {}, agents: {}, tokens: { total_input: 0, total_output: 0, cache_read: 0, cache_creation: 0 } };

      # Token extraction
      if ($line | has("message")) and ($line.message | has("usage")) then
        .tokens.total_input          += ($line.message.usage.input_tokens                // 0) |
        .tokens.total_output         += ($line.message.usage.output_tokens               // 0) |
        .tokens.cache_read           += ($line.message.usage.cache_read_input_tokens     // 0) |
        .tokens.cache_creation       += ($line.message.usage.cache_creation_input_tokens // 0)
      else . end |

      # Assistant lines: tool_use extraction
      if $line.type == "assistant" and ($line.content | type) == "array" then
        reduce $line.content[] as $item (.;
          # Skill tool call
          if $item.type == "tool_use" and $item.name == "Skill" then
            ( $item.input.skill // "unknown" ) as $skill |
            .skills[$skill].count           = ((.skills[$skill].count           // 0) + 1) |
            .skills[$skill].sources.tool_call = ((.skills[$skill].sources.tool_call // 0) + 1)
          # Agent dispatch
          elif $item.type == "tool_use" and $item.name == "Agent" then
            ( $item.input.subagent_type // "unknown" ) as $agent |
            ( $item.input.model         // "unknown" ) as $model |
            .agents[$agent].count              = ((.agents[$agent].count              // 0) + 1) |
            .agents[$agent].models[$model]     = ((.agents[$agent].models[$model]     // 0) + 1)
          else . end
        )
      else . end |

      # User lines: slash command extraction from <command-name> tags
      if $line.type == "user" and ($line.content | type) == "array" then
        reduce $line.content[] as $item (.;
          if ($item.type // "") == "text" or ($item | type) == "string" then
            ( if ($item | type) == "string" then $item else $item.text // "" end ) as $text |
            ( [ $text | scan("<command-name>(?:agmo:)?([^<]+)</command-name>") ] | flatten ) as $cmds |
            if ($cmds | length) > 0 then
              reduce $cmds[] as $skill (.;
                .skills[$skill].count                  = ((.skills[$skill].count                  // 0) + 1) |
                .skills[$skill].sources.slash_command  = ((.skills[$skill].sources.slash_command  // 0) + 1)
              )
            else . end
          else . end
        )
      else . end
    )
  ' "$f" 2>/dev/null) || continue

  # Merge FILE_DATA into ACCUMULATOR
  ACCUMULATOR=$(echo "$ACCUMULATOR $FILE_DATA" | jq -s '
    .[0] as $acc | .[1] as $new |
    {
      period: $acc.period,
      skills: (
        ( [$acc.skills, $new.skills] | add ) |
        to_entries |
        map(
          .key as $k |
          {
            key: $k,
            value: {
              count: (($acc.skills[$k].count // 0) + ($new.skills[$k].count // 0)),
              sources: {
                tool_call:     (($acc.skills[$k].sources.tool_call     // 0) + ($new.skills[$k].sources.tool_call     // 0)),
                slash_command: (($acc.skills[$k].sources.slash_command // 0) + ($new.skills[$k].sources.slash_command // 0))
              }
            }
          }
        ) |
        from_entries
      ),
      agents: (
        ( [$acc.agents, $new.agents] | add ) |
        to_entries |
        map(
          .key as $k |
          {
            key: $k,
            value: {
              count: (($acc.agents[$k].count // 0) + ($new.agents[$k].count // 0)),
              models: (
                [ ($acc.agents[$k].models // {}), ($new.agents[$k].models // {}) ] |
                add |
                to_entries |
                map({ key: .key, value: (($acc.agents[$k].models[.key] // 0) + ($new.agents[$k].models[.key] // 0)) }) |
                from_entries
              )
            }
          }
        ) |
        from_entries
      ),
      tokens: {
        total_input:   ($acc.tokens.total_input   + $new.tokens.total_input),
        total_output:  ($acc.tokens.total_output  + $new.tokens.total_output),
        cache_read:    ($acc.tokens.cache_read    + $new.tokens.cache_read),
        cache_creation:($acc.tokens.cache_creation+ $new.tokens.cache_creation)
      }
    }
  ') || continue
done

echo "$ACCUMULATOR"
