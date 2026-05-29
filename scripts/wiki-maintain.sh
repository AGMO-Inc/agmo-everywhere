#!/usr/bin/env bash
# wiki-maintain.sh — Audit llm-wiki context for stale, low-confidence, contested, or broken entries.
# Usage: wiki-maintain.sh --project <PROJECT> [--max-age-days <N>] [--format markdown|json]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/obsidian-common.sh"

PROJECT="" MAX_AGE_DAYS="90" FORMAT="markdown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --max-age-days) MAX_AGE_DAYS="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --help|-h)
      echo "Usage: wiki-maintain.sh --project <PROJECT> [--max-age-days <N>] [--format markdown|json]" >&2
      exit 0 ;;
    *) _log ERROR "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROJECT" ]]; then
  _log ERROR "Missing required argument: --project"
  exit 1
fi

if ! [[ "$MAX_AGE_DAYS" =~ ^[0-9]+$ ]] || [[ "$MAX_AGE_DAYS" -le 0 ]]; then
  _log ERROR "Invalid --max-age-days: $MAX_AGE_DAYS"
  exit 3
fi

if [[ "$FORMAT" != "markdown" && "$FORMAT" != "json" ]]; then
  _log ERROR "Invalid --format: $FORMAT. Use markdown or json."
  exit 1
fi

VAULT_ROOT="$(_vault_root)"
if [[ -z "$VAULT_ROOT" ]]; then
  echo "[ERROR] Vault not configured. Run setup skill or set AGMO_VAULT_ROOT." >&2
  exit 1
fi

python3 - "$VAULT_ROOT" "$PROJECT" "$MAX_AGE_DAYS" "$FORMAT" <<'PY'
import json
import os
import re
import sys
from datetime import date, datetime
from pathlib import Path

vault = Path(sys.argv[1])
project = sys.argv[2]
max_age_days = int(sys.argv[3])
fmt = sys.argv[4]
wiki = vault / ".agmo" / "llm-wiki"
project_root = wiki / "projects" / project
paths = []
for path in [wiki / "SCHEMA.md", wiki / "INDEX.md", wiki / "LOG.md", wiki / "projects" / f"{project}.md"]:
    if path.is_file():
        paths.append(path)
if project_root.is_dir():
    paths.extend(sorted(project_root.rglob("*.md")))
for rel_wisdom in [
    f"{project}/wisdom/learnings.md",
    f"{project}/wisdom/decisions.md",
    f"{project}/wisdom/issues.md",
    "shared/wisdom/learnings.md",
    "shared/wisdom/decisions.md",
    "shared/wisdom/issues.md",
]:
    p = vault / rel_wisdom
    if p.is_file():
        paths.append(p)

frontmatter_re = re.compile(r"^---\n(.*?)\n---\n", re.S)
link_re = re.compile(r"\[\[([^\]]+)\]\]")
issues = []
seen = set()
superseded_targets = set()
frontmatters = {}
texts = {}

def rel(path):
    try:
        return str(path.relative_to(vault))
    except ValueError:
        return str(path)

def add_issue(kind, path, message, severity="medium"):
    key = (kind, rel(path), message)
    if key in seen:
        return
    seen.add(key)
    issues.append({"kind": kind, "severity": severity, "path": rel(path), "message": message})

def parse_frontmatter(text):
    m = frontmatter_re.match(text)
    if not m:
        return {}
    data = {}
    for line in m.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip('"').strip("'")
    return data

def parse_date(value):
    if not value:
        return None
    value = value.strip()
    for fmt_ in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            return datetime.strptime(value[:19], fmt_).date()
        except ValueError:
            continue
    return None

for path in paths:
    text = path.read_text(encoding="utf-8", errors="replace")
    texts[path] = text
    fm = parse_frontmatter(text)
    frontmatters[path] = fm
    supersedes = fm.get("supersedes", "").strip()
    if supersedes:
        superseded_targets.add(supersedes)
        superseded_targets.add(str((vault / supersedes).resolve()))
        superseded_targets.add(str(path.parent / supersedes))

for path in paths:
    text = texts[path]
    fm = frontmatters[path]
    is_wisdom = "/wisdom/" in rel(path)
    if path.name not in {"SCHEMA.md", "INDEX.md", "LOG.md"} and not is_wisdom and not fm:
        add_issue("MISSING_FRONTMATTER", path, "Page has no YAML frontmatter.", "medium")
    if rel(path) in superseded_targets or str(path) in superseded_targets or str(path.resolve()) in superseded_targets:
        add_issue("SUPERSEDED", path, "Page is superseded by a newer capture; avoid injecting or relying on it.", "medium")
    confidence = fm.get("confidence", "").lower()
    if confidence == "low":
        add_issue("LOW_CONFIDENCE", path, "Low-confidence page must be verified or superseded.", "high")
    contested = fm.get("contested", "").lower()
    contradictions = fm.get("contradictions", "")
    if contested in {"true", "yes"} or contradictions:
        add_issue("CONTESTED", path, "Page is marked contested or has contradictions; reconcile before relying on it.", "high")
    updated = parse_date(fm.get("updated") or fm.get("created"))
    if updated:
        age = (date.today() - updated).days
        if age > max_age_days:
            add_issue("STALE", path, f"Page is {age} days old; review for drift.", "medium")
    for raw_link in link_re.findall(text):
        link = raw_link.split("|", 1)[0].split("#", 1)[0].strip()
        if not link or link.endswith("/"):
            continue
        candidates = []
        if link.endswith(".md"):
            candidates.append(vault / link)
            candidates.append(wiki / link)
        else:
            candidates.append(path.parent / f"{link}.md")
            candidates.append(vault / f"{link}.md")
            candidates.append(wiki / f"{link}.md")
        if not any(c.exists() for c in candidates):
            add_issue("BROKEN_WIKILINK", path, f"Broken wikilink: [[{raw_link}]]", "low")

result = {
    "project": project,
    "max_age_days": max_age_days,
    "issue_count": len(issues),
    "issues": issues,
}

if fmt == "json":
    print(json.dumps(result, ensure_ascii=False, indent=2))
else:
    print(f"## LLM Wiki Maintenance ({project})")
    print(f"- Issues: {len(issues)}")
    if not issues:
        print("- Status: clean")
    else:
        for issue in issues:
            print(f"- [{issue['severity']}] {issue['kind']}: `{issue['path']}` — {issue['message']}")
PY
