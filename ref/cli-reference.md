# Obsidian CLI Reference

Requires Obsidian app to be running.

## Search

```bash
# Text search (JSON)
obsidian search query="{keyword}" format=json

# With matching line context
obsidian search:context query="{keyword}" format=json

# Scoped to folder
obsidian search query="{keyword}" path="{folder}" format=json

# Limit results
obsidian search query="{keyword}" limit=10 format=json

# Case sensitive
obsidian search query="{keyword}" case format=json
```

## Read/Write

```bash
# Read file (wikilink style)
obsidian read file="{note_name}"

# Read by path
obsidian read path="{folder/filename.md}"

# Create file
obsidian create name="{name}" path="{path}" content="{content}"

# Append content
obsidian append file="{note_name}" content="{content}"

# Prepend content
obsidian prepend file="{note_name}" content="{content}"
```

## llm-wiki Context Scripts

These scripts do not require the Obsidian CLI. They use the configured vault root from `AGMO_VAULT_ROOT` or `~/.agmo/config`.

```bash
# Initialize agent-facing compiled context spine
scripts/wiki-init.sh --project "{project}"

# Capture durable agent-facing context from a file
scripts/wiki-capture.sh --project "{project}" --title "{title}" --type decision --source "plan" --file /tmp/summary.md

# Capture from stdin
printf '%s\n' "Durable summary" | scripts/wiki-capture.sh --project "{project}" --title "{title}"

# Emit bounded markdown context for session-start
scripts/wiki-context.sh --project "{project}" --budget 6000

# Emit parseable JSON with included/omitted metadata
scripts/wiki-context.sh --project "{project}" --budget 6000 --format json

# Audit compiled context for stale, low-confidence, contested, or broken entries
scripts/wiki-maintain.sh --project "{project}" --max-age-days 90
scripts/wiki-maintain.sh --project "{project}" --max-age-days 90 --format json
```

## Metadata

```bash
# Search by tag
obsidian tag name="{tag}" verbose

# List tags
obsidian tags counts sort=count

# Read property
obsidian property:read name="{property}" file="{note_name}"

# Set property
obsidian property:set name="{property}" value="{value}" file="{note_name}"
```

## Navigation

```bash
# Get backlinks
obsidian backlinks file="{note_name}" format=json

# Get outgoing links
obsidian links file="{note_name}"

# List files in folder
obsidian files folder="{folder_name}"

# File info
obsidian file file="{note_name}"
```
