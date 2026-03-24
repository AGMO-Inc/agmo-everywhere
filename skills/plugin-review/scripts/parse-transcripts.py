#!/usr/bin/env python3
"""
parse-transcripts.py

Parses Claude Code JSONL transcripts and outputs a JSON summary of
skill invocations, agent invocations, token usage, and skill chains.
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone, timedelta
from pathlib import Path
from glob import glob


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def eprint(*args, **kwargs):
    """Print progress messages to stderr."""
    print(*args, file=sys.stderr, **kwargs)


def parse_project_name(raw_key: str) -> str:
    """
    Convert a Claude project directory key to a human-readable name.
    The key encodes the absolute path by replacing '/' with '-'.
    e.g. '-Users-sungmincho-Desktop-Front-sdm-app' -> 'Front/sdm-app'
    """
    # Strip leading dash
    key = raw_key.lstrip("-")

    # Known path segments to strip (home dir + Desktop prefix)
    # Try to find 'Desktop' boundary first
    parts = key.split("-")
    desktop_idx = None
    for i, p in enumerate(parts):
        if p == "Desktop":
            desktop_idx = i
            break

    if desktop_idx is not None:
        # Take segments after Desktop, group by known depth patterns
        # e.g. [Front, sdm, app] -> "Front/sdm-app"
        # Heuristic: first segment after Desktop is the top-level folder (Front, Backend, etc.)
        # Second segment is the project name (may contain dashes)
        after = parts[desktop_idx + 1:]
        if len(after) >= 2:
            top_folder = after[0]  # e.g. "Front", "Backend"
            project = "-".join(after[1:])  # e.g. "sdm-app", "agmo-everywhere"
            return f"{top_folder}/{project}"
        elif len(after) == 1:
            return after[0]

    # Fallback: try to find username boundary
    # Pattern: Users-{username}-...
    if key.startswith("Users-"):
        # Find the third segment onwards
        segments = key.split("-", 2)
        if len(segments) >= 3:
            return segments[2].replace("-", "/", 1) if "-" in segments[2] else segments[2]

    # Last resort
    return key


def find_session_jsonls(projects_root: Path) -> list[tuple[str, Path]]:
    """
    Return a list of (project_name, jsonl_path) for all session JSONL files
    under the given projects root.

    Actual layout on disk:
      ~/.claude/projects/{project-key}/{uuid}.jsonl          <- session transcript
      ~/.claude/projects/{project-key}/{uuid}/subagents/     <- optional subagent dir
    """
    results = []
    for project_dir in sorted(projects_root.iterdir()):
        if not project_dir.is_dir():
            continue
        project_name = parse_project_name(project_dir.name)
        for jsonl_file in sorted(project_dir.glob("*.jsonl")):
            if jsonl_file.is_file():
                results.append((project_name, jsonl_file))
    return results


def get_session_timestamp(jsonl_path: Path) -> datetime | None:
    """
    Read the first line containing a 'timestamp' field and return a UTC datetime.
    Returns None if not found or unparseable.
    """
    try:
        with open(jsonl_path, "r", encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                raw = raw.strip()
                if not raw.startswith("{"):
                    continue
                try:
                    obj = json.loads(raw)
                except json.JSONDecodeError:
                    continue
                ts = obj.get("timestamp")
                if ts:
                    try:
                        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                        return dt.astimezone(timezone.utc)
                    except ValueError:
                        return None
    except OSError:
        pass
    return None


# Regex for slash-command detection inside message content
_COMMAND_RE = re.compile(r"<command-name>/?(agmo:)?(.+?)</command-name>")

# Built-in CLI commands that are NOT skills — exclude from skill tracking
_BUILTIN_COMMANDS = {
    "clear", "help", "exit", "quit", "login", "logout", "status",
    "config", "settings", "plugin", "plugins", "model", "cost",
    "memory", "compact", "bug", "review", "vim", "init",
    "terminal-setup", "listen", "fast", "add-dir",
}


def extract_slash_skill(text: str) -> str | None:
    """Return the full skill name from a <command-name> tag, or None."""
    m = _COMMAND_RE.search(text)
    if not m:
        return None
    prefix = m.group(1) or ""
    name = m.group(2)
    full_name = (prefix + name).strip()
    # Filter out built-in CLI commands
    base_name = full_name.split(":")[-1] if ":" in full_name else full_name
    if base_name in _BUILTIN_COMMANDS:
        return None
    return full_name


def content_to_text(content) -> str:
    """Flatten message content (str or list of items) to plain text."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                parts.append(item.get("text", ""))
        return "\n".join(parts)
    return ""


# ---------------------------------------------------------------------------
# Per-session parsing
# ---------------------------------------------------------------------------

def parse_session(
    jsonl_path: Path,
    project_name: str,
    cutoff: datetime,
    summary: dict,
) -> bool:
    """
    Parse a single session JSONL file and accumulate stats into summary.
    Returns True if the session was in range and processed, False otherwise.
    """
    ts = get_session_timestamp(jsonl_path)
    summary["total_scanned"] += 1

    if ts is None or ts < cutoff:
        return False

    summary["in_range"] += 1
    summary["by_project"][project_name] = summary["by_project"].get(project_name, 0) + 1

    skills_this_session: list[str] = []  # ordered skill sequence for chain analysis

    # Track pending slash commands (by skill name) from user lines so we can
    # dedup adjacent user slash_command + assistant tool_call pairs.
    pending_slash: set[str] = set()

    try:
        with open(jsonl_path, "r", encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                raw = raw.strip()
                if not raw.startswith("{"):
                    continue
                try:
                    obj = json.loads(raw)
                except json.JSONDecodeError:
                    continue

                msg_type = obj.get("type")
                message = obj.get("message", {})
                content = message.get("content", []) if isinstance(message, dict) else []
                model = message.get("model") if isinstance(message, dict) else None

                # -- Token usage --
                if isinstance(message, dict):
                    usage = message.get("usage", {})
                    if usage:
                        bucket = summary["tokens"]["main"]
                        for field in ("input_tokens", "output_tokens",
                                      "cache_read_input_tokens", "cache_creation_input_tokens"):
                            bucket[field] = bucket.get(field, 0) + (usage.get(field) or 0)
                        if model:
                            bm = bucket.setdefault("by_model", {})
                            bm[model] = bm.get(model, 0) + sum(
                                usage.get(f) or 0 for f in (
                                    "input_tokens", "output_tokens",
                                    "cache_read_input_tokens", "cache_creation_input_tokens",
                                )
                            )

                # -- User lines: slash commands --
                if msg_type == "user":
                    text = content_to_text(content)
                    skill_name = extract_slash_skill(text)
                    if skill_name:
                        pending_slash.add(skill_name)
                        _record_skill(summary, skill_name, "slash_command", project_name)
                        skills_this_session.append(skill_name)

                # -- Assistant lines: tool_use items --
                elif msg_type == "assistant":
                    if not isinstance(content, list):
                        continue
                    for item in content:
                        if not isinstance(item, dict) or item.get("type") != "tool_use":
                            continue
                        tool_name = item.get("name")
                        tool_input = item.get("input") or {}

                        # Skill tool_call
                        if tool_name == "Skill":
                            skill_name = tool_input.get("skill", "")
                            if not skill_name:
                                continue
                            # Dedup: if this skill was already recorded as slash_command
                            if skill_name in pending_slash:
                                pending_slash.discard(skill_name)
                                # Already counted once; skip
                                continue
                            _record_skill(summary, skill_name, "tool_call", project_name)
                            skills_this_session.append(skill_name)

                        # Agent tool_use
                        elif tool_name == "Agent":
                            agent_type = tool_input.get("subagent_type", "unknown")
                            agent_model = tool_input.get("model") or "unknown"
                            _record_agent(summary, agent_type, agent_model, project_name)

                    # After processing assistant line, clear pending slash tracking
                    # (they are only adjacent for one turn)
                    pending_slash.clear()

    except OSError as exc:
        eprint(f"  [WARN] Cannot read {jsonl_path}: {exc}")
        return False

    # -- Sub-agent transcripts --
    # Layout: {project-key}/{uuid}.jsonl -> subagents at {project-key}/{uuid}/subagents/
    subagents_dir = jsonl_path.parent / jsonl_path.stem / "subagents"
    if subagents_dir.is_dir():
        _parse_subagents(subagents_dir, summary)

    # -- Skill chains (2-grams) --
    for i in range(len(skills_this_session) - 1):
        chain = (skills_this_session[i], skills_this_session[i + 1])
        summary["skill_chains"][chain] = summary["skill_chains"].get(chain, 0) + 1

    return True


def _record_skill(summary: dict, skill_name: str, tag: str, project_name: str):
    skills = summary["skills"]
    entry = skills.setdefault(skill_name, {"total": 0, "tool_call": 0, "slash_command": 0, "by_project": {}})
    entry["total"] += 1
    entry[tag] = entry.get(tag, 0) + 1
    bp = entry["by_project"]
    bp[project_name] = bp.get(project_name, 0) + 1


def _record_agent(summary: dict, agent_type: str, model: str, project_name: str):
    agents = summary["agents"]
    entry = agents.setdefault(agent_type, {"total": 0, "by_model": {}, "by_project": {}})
    entry["total"] += 1
    bm = entry["by_model"]
    bm[model] = bm.get(model, 0) + 1
    bp = entry["by_project"]
    bp[project_name] = bp.get(project_name, 0) + 1


def _parse_subagents(subagents_dir: Path, summary: dict):
    """Parse all sub-agent meta + jsonl files and accumulate token stats."""
    for meta_file in subagents_dir.glob("*.meta.json"):
        stem = meta_file.stem  # e.g. "abc123.meta"
        # The corresponding jsonl has the same stem without '.meta'
        base = stem[: -len(".meta")] if stem.endswith(".meta") else stem
        jsonl_file = subagents_dir / f"{base}.jsonl"

        agent_type = "unknown"
        try:
            with open(meta_file, "r", encoding="utf-8", errors="replace") as fh:
                meta = json.load(fh)
                agent_type = meta.get("agentType", "unknown")
        except (OSError, json.JSONDecodeError):
            pass

        if not jsonl_file.exists():
            continue

        try:
            with open(jsonl_file, "r", encoding="utf-8", errors="replace") as fh:
                for raw in fh:
                    raw = raw.strip()
                    if not raw.startswith("{"):
                        continue
                    try:
                        obj = json.loads(raw)
                    except json.JSONDecodeError:
                        continue
                    message = obj.get("message", {})
                    if not isinstance(message, dict):
                        continue
                    usage = message.get("usage", {})
                    if not usage:
                        continue
                    model = message.get("model") or "unknown"
                    bucket = summary["tokens"]["subagent"]
                    for field in ("input_tokens", "output_tokens",
                                  "cache_read_input_tokens", "cache_creation_input_tokens"):
                        bucket[field] = bucket.get(field, 0) + (usage.get(field) or 0)
                    bm = bucket.setdefault("by_model", {})
                    bm[model] = bm.get(model, 0) + sum(
                        usage.get(f) or 0 for f in (
                            "input_tokens", "output_tokens",
                            "cache_read_input_tokens", "cache_creation_input_tokens",
                        )
                    )
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def build_summary_skeleton() -> dict:
    return {
        # Temporary working fields (not in final output)
        "total_scanned": 0,
        "in_range": 0,
        "by_project": {},
        "skills": {},
        "agents": {},
        "tokens": {
            "main": {
                "input_tokens": 0,
                "output_tokens": 0,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "by_model": {},
            },
            "subagent": {
                "input_tokens": 0,
                "output_tokens": 0,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "by_model": {},
            },
        },
        "skill_chains": {},  # (a, b) -> count
    }


def main():
    parser = argparse.ArgumentParser(
        description="Parse Claude Code transcripts and output a JSON summary."
    )
    parser.add_argument("--days", type=int, default=30,
                        help="Only process sessions from the last N days (default: 30)")
    parser.add_argument("--all-projects", action="store_true",
                        help="Scan all ~/.claude/projects/* directories")
    parser.add_argument("--project-key", type=str, default=None,
                        help="Scan a specific project key only")
    args = parser.parse_args()

    claude_dir = Path.home() / ".claude" / "projects"
    if not claude_dir.exists():
        eprint(f"[ERROR] Claude projects directory not found: {claude_dir}")
        sys.exit(1)

    # Build list of (project_name, jsonl_path) to process
    # Layout: ~/.claude/projects/{project-key}/{uuid}.jsonl
    sessions: list[tuple[str, Path]] = []

    if args.all_projects:
        eprint(f"[INFO] Scanning all projects under {claude_dir}")
        sessions = find_session_jsonls(claude_dir)
    elif args.project_key:
        project_dir = claude_dir / args.project_key
        if not project_dir.exists():
            eprint(f"[ERROR] Project directory not found: {project_dir}")
            sys.exit(1)
        project_name = parse_project_name(args.project_key)
        eprint(f"[INFO] Scanning project: {project_name} ({project_dir})")
        for jsonl_file in sorted(project_dir.glob("*.jsonl")):
            if jsonl_file.is_file():
                sessions.append((project_name, jsonl_file))
    else:
        eprint(f"[INFO] Scanning all projects under {claude_dir} (no flag specified, defaulting to all)")
        sessions = find_session_jsonls(claude_dir)

    # Compute time cutoff
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=args.days)
    period_start = cutoff.strftime("%Y-%m-%d")
    period_end = now.strftime("%Y-%m-%d")
    eprint(f"[INFO] Period: {period_start} to {period_end} ({args.days} days)")
    eprint(f"[INFO] Found {len(sessions)} session JSONL files to check")

    summary = build_summary_skeleton()

    for i, (project_name, jsonl_path) in enumerate(sessions):
        parse_session(jsonl_path, project_name, cutoff, summary)
        if (i + 1) % 50 == 0:
            eprint(f"[INFO] Progress: {i + 1}/{len(sessions)} files checked")

    eprint(f"[INFO] Done. Scanned: {summary['total_scanned']}, In range: {summary['in_range']}")

    # -- Build final output --
    # Skill chains: convert tuple keys to list, sort by count desc, top N
    chains_list = [
        {"chain": list(k), "count": v}
        for k, v in sorted(summary["skill_chains"].items(), key=lambda x: -x[1])
    ]

    output = {
        "period": {
            "start": period_start,
            "end": period_end,
        },
        "sessions": {
            "total_scanned": summary["total_scanned"],
            "in_range": summary["in_range"],
            "by_project": summary["by_project"],
        },
        "skills": summary["skills"],
        "agents": summary["agents"],
        "tokens": summary["tokens"],
        "skill_chains": chains_list,
    }

    print(json.dumps(output, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
