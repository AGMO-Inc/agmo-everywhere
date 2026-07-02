# Category Routing (Detail)

## Category Routing

**agmo:planner, agmo:critic** are model-fixed to **claude-fable-5**. **agmo:architect, agmo:frontend, agmo:android-specialist** are model-fixed to **opus**. Do NOT pass `model` parameter for any of them — they use their own.

**agmo:executor, agmo:explore, agmo:archivist** use category routing — pass `model` explicitly:

### agmo:executor routing

| Category | Model | Use when... |
|----------|-------|-------------|
| `quick` | `haiku` | 1-line change, file save, Obsidian operations, config edits |
| `standard` | `sonnet` | Feature implementation, multi-file changes, most coding work |
| `complex` | `opus` | Architecture-sensitive changes, complex refactoring |

### agmo:explore routing

**Default to `haiku` for explore.** Most exploration is file lookup and content search — haiku handles this well. Only escalate when deeper analysis is needed.

| Category | Model | Use when... |
|----------|-------|-------------|
| `quick` | `haiku` | **Default.** File search, pattern matching, reading files, Obsidian vault search, symbol lookup, git log/blame |
| `standard` | `sonnet` | Cross-file dependency analysis, understanding complex architecture, multi-step investigation requiring reasoning |
| `complex` | `opus` | Deep architectural analysis spanning 10+ files, security audit-level codebase scanning |

### agmo:archivist routing

**Default to `haiku` for archivist.** Most vault operations are mechanical file save and search. Only note-to-issue requires sonnet for GitHub API and reasoning.

| Category | Model | Use when... |
|----------|-------|-------------|
| `quick` | `haiku` | **Default.** save-plan, save-impl, save-note, vault-search, wisdom |
| `standard` | `sonnet` | note-to-issue (GitHub Issue creation, frontmatter parsing, reasoning) |

```
# agmo:executor — route by task complexity
Agent(subagent_type="agmo:executor", model="haiku", prompt="...")   # quick
Agent(subagent_type="agmo:executor", model="sonnet", prompt="...")  # standard

# agmo:explore — default to haiku, escalate only when needed
Agent(subagent_type="agmo:explore", model="haiku", prompt="...")    # default
Agent(subagent_type="agmo:explore", model="sonnet", prompt="...")   # complex investigation only

# agmo:archivist — default to haiku, sonnet only for note-to-issue
Agent(subagent_type="agmo:archivist", model="haiku", prompt="...")    # default
Agent(subagent_type="agmo:archivist", model="sonnet", prompt="...")   # note-to-issue only

# agmo:planner, agmo:critic — model-fixed to claude-fable-5, do NOT pass model
Agent(subagent_type="agmo:planner", prompt="...")
Agent(subagent_type="agmo:critic", prompt="...")

# agmo:architect — model-fixed to opus, do NOT pass model
Agent(subagent_type="agmo:architect", prompt="...")

# agmo:frontend — model-fixed to opus, do NOT pass model
Agent(subagent_type="agmo:frontend", prompt="...")

# agmo:android-specialist — model-fixed to opus, do NOT pass model
Agent(subagent_type="agmo:android-specialist", prompt="...")
```
