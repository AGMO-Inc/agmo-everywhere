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
