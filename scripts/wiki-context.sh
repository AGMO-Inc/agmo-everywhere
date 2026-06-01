#!/usr/bin/env bash
# wiki-context.sh — Emit bounded llm-wiki context for Claude Code session-start.
# Usage: wiki-context.sh --project <PROJECT> [--budget <CHARS>] [--format markdown|json] [--manifest|--full]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/obsidian-common.sh"

PROJECT="" BUDGET="${AGMO_CONTEXT_BUDGET_CHARS:-6000}" FORMAT="markdown" MODE="full"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="${2:-}"; shift 2 ;;
    --budget) BUDGET="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-}"; shift 2 ;;
    --manifest) MODE="manifest"; shift ;;
    --full) MODE="full"; shift ;;
    --help|-h)
      echo "Usage: wiki-context.sh --project <PROJECT> [--budget <CHARS>] [--format markdown|json] [--manifest|--full]" >&2
      exit 0 ;;
    *) _log ERROR "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROJECT" ]]; then
  _log ERROR "Missing required argument: --project"
  exit 1
fi

if ! [[ "$BUDGET" =~ ^[0-9]+$ ]] || [[ "$BUDGET" -le 0 ]]; then
  _log ERROR "Invalid --budget: $BUDGET"
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

# --manifest mode: emit compact metadata-only summary (≤800 chars) then exit
if [[ "$MODE" == "manifest" ]]; then
python3 - "$VAULT_ROOT" "$PROJECT" <<'MANIFEST_PY'
import os
import re
import sys
from pathlib import Path

vault = Path(sys.argv[1])
project = sys.argv[2]
wiki = vault / ".agmo" / "llm-wiki"
captures_dir = wiki / "projects" / project / "captures"
capsule_path = wiki / "projects" / f"{project}.md"

frontmatter_re = re.compile(r"^---\n(.*?)\n---\n", re.S)

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

def capture_title(path):
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
        fm = parse_frontmatter(text)
        if fm.get("title"):
            return fm["title"]
    except Exception:
        pass
    name = path.stem
    name = re.sub(r"^\[Wiki\]\s*", "", name)
    return name

lines = []
lines.append(f"## LLM Wiki Manifest ({project})")
lines.append("")

# --- cwd project detail ---
if capsule_path.is_file():
    try:
        fm = parse_frontmatter(capsule_path.read_text(encoding="utf-8", errors="replace"))
        updated = fm.get("updated", "")
    except Exception:
        updated = ""
    capsule_info = f"- capsule: 있음 (updated: {updated})" if updated else "- capsule: 있음"
else:
    capsule_info = f"- capsule 없음 — 누적되면 wiki-init.sh/wiki-capture.sh로 시작"

lines.append(f"### {project}")
lines.append(capsule_info)

if captures_dir.is_dir():
    all_captures = sorted(captures_dir.glob("*.md"), key=lambda p: (p.stat().st_mtime, p.name), reverse=True)
    count = len(all_captures)
    lines.append(f"- captures: {count}건")
    top3 = [capture_title(p) for p in all_captures[:3]]
    for t in top3:
        lines.append(f"  - {t}")
else:
    lines.append("- captures: 0건")

lines.append("")

# --- other projects (1 line each) ---
projects_dir = wiki / "projects"
if projects_dir.is_dir():
    others = []
    for entry in sorted(projects_dir.iterdir()):
        if entry.is_dir() and entry.name != project:
            c_dir = entry / "captures"
            cnt = len(list(c_dir.glob("*.md"))) if c_dir.is_dir() else 0
            others.append((entry.name, cnt))
        elif entry.is_file() and entry.suffix == ".md" and entry.stem != project:
            # capsule-only project (no captures dir)
            name = entry.stem
            c_dir = projects_dir / name / "captures"
            cnt = len(list(c_dir.glob("*.md"))) if c_dir.is_dir() else 0
            # avoid duplicate if already found via dir
            if not any(o[0] == name for o in others):
                others.append((name, cnt))
    if others:
        lines.append("### 다른 프로젝트")
        for name, cnt in others:
            lines.append(f"- {name} ({cnt}건)")
        lines.append("")

# --- lookup guide ---
lines.append(f"전체 본문: `wiki-context.sh --project {project} --full`, 검색: `vault-search.sh`, 페이지 읽기: `vault-read.sh`")
lines.append("")
lines.append("_본문 전체 컨텍스트는 AGMO_CONTEXT_MODE=full 로 세션을 시작하면 주입됩니다._")

output = "\n".join(lines)
print(output, end="")
MANIFEST_PY
_manifest_exit=$?

# Append high-severity health warning only when AGMO_MANIFEST_HEALTH=1 (opt-in)
if [[ "${AGMO_MANIFEST_HEALTH:-0}" == "1" ]]; then
  _wm_json=$(bash "${SCRIPT_DIR}/wiki-maintain.sh" --project "$PROJECT" --format json 2>/dev/null) || true
  if [[ -n "$_wm_json" ]]; then
    _high_count=$(python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
print(sum(1 for i in data.get('issues', []) if i.get('severity') == 'high'))
" <<< "$_wm_json" 2>/dev/null) || _high_count=0
    if [[ -n "$_high_count" ]] && [[ "$_high_count" -gt 0 ]]; then
      printf "\n⚠ high-severity wiki 이슈 %s건 — wiki-maintain 스킬로 점검하세요.\n" "$_high_count"
    fi
  fi
fi

exit $_manifest_exit
fi

python3 - "$VAULT_ROOT" "$PROJECT" "$BUDGET" "$FORMAT" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

vault = Path(sys.argv[1])
project = sys.argv[2]
budget = int(sys.argv[3])
fmt = sys.argv[4]
wiki = vault / ".agmo" / "llm-wiki"

candidates = []
included = []
omitted = []
sections = []
chars_used = 0

def add(path, label, priority, max_chars=None):
    candidates.append({"path": path, "label": label, "priority": priority, "max_chars": max_chars})

add(wiki / "SCHEMA.md", "LLM Wiki Schema", 10, 1800)
add(wiki / "INDEX.md", "LLM Wiki Index", 20, 2200)
add(wiki / "projects" / f"{project}.md", f"Project Capsule: {project}", 30, 2400)
add(wiki / "LOG.md", "Recent LLM Wiki Log", 40, 1800)

captures_dir = wiki / "projects" / project / "captures"
if captures_dir.is_dir():
    all_captures = sorted(captures_dir.glob("*.md"), key=lambda p: (p.stat().st_mtime, p.name), reverse=True)
    frontmatter_re = re.compile(r"^---\n(.*?)\n---\n", re.S)
    superseded = set()
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
    for path in all_captures:
        fm = parse_frontmatter(path.read_text(encoding="utf-8", errors="replace"))
        supersedes = fm.get("supersedes", "").strip()
        if supersedes:
            superseded.add(supersedes)
            superseded.add(str(path.parent / supersedes))
            superseded.add(str((vault / supersedes).resolve()))
    captures = []
    for path in all_captures:
        rel_path = str(path.relative_to(vault))
        if rel_path in superseded or str(path) in superseded or str(path.resolve()) in superseded:
            omitted.append({"path": rel_path, "reason": "superseded"})
            continue
        captures.append(path)
    for i, path in enumerate(captures[:8]):
        add(path, f"Recent Capture: {path.name}", 50 + i, 1800)

for rel, label, priority in [
    (f"{project}/wisdom/learnings.md", f"{project} Wisdom: Learnings", 70),
    (f"{project}/wisdom/decisions.md", f"{project} Wisdom: Decisions", 71),
    (f"{project}/wisdom/issues.md", f"{project} Wisdom: Issues", 72),
    ("shared/wisdom/learnings.md", "Shared Wisdom: Learnings", 80),
    ("shared/wisdom/decisions.md", "Shared Wisdom: Decisions", 81),
    ("shared/wisdom/issues.md", "Shared Wisdom: Issues", 82),
]:
    add(vault / rel, label, priority, 1800)

header = f"## LLM Wiki Context ({project})\n\n"
chars_used += len(header)

for item in sorted(candidates, key=lambda d: d["priority"]):
    path = item["path"]
    if not path.is_file():
        omitted.append({"path": str(path.relative_to(vault)) if str(path).startswith(str(vault)) else str(path), "reason": "missing"})
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    if item["label"] == "Recent LLM Wiki Log":
        lines = text.splitlines()
        text = "\n".join(lines[-40:])
    max_chars = item["max_chars"]
    truncated = False
    if max_chars is not None and len(text) > max_chars:
        text = text[:max_chars].rstrip() + "\n… [truncated]"
        truncated = True
    rel = str(path.relative_to(vault))
    section = f"### {item['label']}\n_Source: `{rel}`_\n\n{text.strip()}\n\n"
    if chars_used + len(section) > budget:
        omitted.append({"path": rel, "reason": "budget"})
        continue
    sections.append(section)
    chars_used += len(section)
    included.append({"path": rel, "chars": len(section), "truncated": truncated})

if not sections:
    fallback = (
        "### Context Spine Not Initialized\n"
        "No bounded llm-wiki context was available. Use `scripts/wiki-init.sh --project " + project + "` "
        "and capture durable summaries with `scripts/wiki-capture.sh`.\n\n"
    )
    if chars_used + len(fallback) <= budget:
        sections.append(fallback)
        chars_used += len(fallback)

visible_omissions = [o for o in omitted if o["reason"] == "budget"]
if visible_omissions:
    omission_lines = ["### Omitted Due To Budget"]
    for o in visible_omissions[:12]:
        omission_lines.append(f"- `{o['path']}`")
    omission = "\n".join(omission_lines) + "\n"
    if chars_used + len(omission) <= budget:
        sections.append(omission)
        chars_used += len(omission)

context = header + "".join(sections)
if len(context) > budget:
    context = context[: max(0, budget - 20)].rstrip() + "\n… [budget cut]"
    chars_used = len(context)

result = {
    "project": project,
    "budget": budget,
    "chars_used": len(context),
    "included": included,
    "omitted": omitted,
    "context": context,
}

if fmt == "json":
    print(json.dumps(result, ensure_ascii=False, indent=2))
else:
    print(context, end="")
PY
