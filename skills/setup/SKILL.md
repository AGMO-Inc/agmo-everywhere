---
name: setup
description: Use for first-time plugin configuration. Triggers on "setup", "설정", "초기 설정".
---

# Setup — Plugin Configuration

## Process

### Step 0. Check Existing Configuration

Read `~/.agmo/config` if it exists.

- **If the file does NOT exist** → proceed to Step 1.
- **If the file exists**, display the current settings:
  ```
  현재 설정:
    vault_root: <value>
    initialized_at: <value>
  변경하시겠습니까? (yes/no)
  ```
  - If user answers **no** → skip to Step 3 (statusLine setup).
  - If user answers **yes** → proceed to Step 1 (overwrite flow).

---

### Step 1. Collect Vault Path

Ask the user:
```
Obsidian vault 경로를 입력해 주세요 (예: /Users/<username>/MyVault):
```

After receiving the path:
1. Verify the path exists on disk using `ls "<path>"`.
2. If the path does NOT exist, inform the user and ask again.
3. Once a valid path is confirmed, proceed to Step 2.

---

### Step 2. Save Configuration

Create the directory and write the config file:

```bash
mkdir -p ~/.agmo
```

Write `~/.agmo/config` with the following JSON content (use the actual vault path and current ISO-8601 timestamp):

```json
{
  "vault_root": "<validated_vault_path>",
  "initialized_at": "<ISO-8601 timestamp>"
}
```

Use the Bash tool to write the file:
```bash
cat > ~/.agmo/config << 'EOF'
{
  "vault_root": "<validated_vault_path>",
  "initialized_at": "<current_timestamp>"
}
EOF
```

Confirm the file was written successfully.

---

### Step 3. Configure statusLine in ~/.claude/settings.json

Determine the plugin cache path by running:
```bash
ls ~/.claude/plugins/
```

Find the agmo plugin directory (e.g., `agmo@agmo-local` or similar). The statusLine script path will be:
```
~/.claude/plugins/<agmo-plugin-dir>/hooks/statusLine.js
```

Read `~/.claude/settings.json` (create it as `{}` if it does not exist), then set the `statusLine` field to the resolved absolute path:

```bash
# Example: resolve the plugin directory name
PLUGIN_DIR=$(ls ~/.claude/plugins/ | grep agmo | head -1)
STATUS_LINE_PATH="$HOME/.claude/plugins/$PLUGIN_DIR/hooks/statusLine.js"
echo $STATUS_LINE_PATH
```

Update `~/.claude/settings.json` using the Bash tool with `node -e` or `jq` to merge the `statusLine` key:

```bash
node -e "
const fs = require('fs');
const path = '${HOME}/.claude/settings.json';
const existing = fs.existsSync(path) ? JSON.parse(fs.readFileSync(path, 'utf8')) : {};
existing.statusLine = '${STATUS_LINE_PATH}';
fs.writeFileSync(path, JSON.stringify(existing, null, 2));
console.log('statusLine set to:', existing.statusLine);
"
```

Confirm the statusLine field is written.

---

### Step 4. Create Shared Vault Directories

Using the vault_root from config, create required directories:

```bash
VAULT=$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.env.HOME+'/.agmo/config','utf8')).vault_root)")
mkdir -p "$VAULT/shared/wisdom"
mkdir -p "$VAULT/shared/plugin-reviews"
```

---

### Step 5. Initialize Wisdom Files

Create empty wisdom files if they do not exist:
```
<vault_root>/shared/wisdom/learnings.md
<vault_root>/shared/wisdom/decisions.md
<vault_root>/shared/wisdom/issues.md
```

---

### Step 6. Verify Plugin Installation

```bash
claude plugin list
```

Confirm `agmo@agmo-local` (or the detected agmo plugin) is listed and enabled.

---

### Step 7. Report

```
## Setup Complete

- Config:        ~/.agmo/config (vault_root, initialized_at)
- Vault:         <vault_root>
- Shared wisdom: initialized
- statusLine:    ~/.claude/plugins/<agmo-plugin-dir>/hooks/statusLine.js → set in ~/.claude/settings.json
- Plugin:        agmo@agmo-local enabled

Ready to use. Say "brainstorming" to start a new project,
or "plan" to create an implementation plan.
```

---

## Migration

### From v0.1.x (usage-log.json)

If `shared/plugin-analytics/usage-log.json` exists in your vault:

```bash
mv "<vault_root>/shared/plugin-analytics/usage-log.json" "<vault_root>/shared/plugin-analytics/usage-log.archived.json"
```

This file is no longer used. Plugin review now parses Claude Code transcripts directly.
