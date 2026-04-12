#!/usr/bin/env python3
"""Codex session harvester — parse Codex CLI session JSONL and extract work summaries.

Usage:
    codex-harvest.py [--date YYYY-MM-DD] [--json] [--project FILTER]
    codex-harvest.py --session SESSION_FILE [--json]

Output: Markdown summary suitable for daily log, or JSON for programmatic use.
"""

import argparse
import json
import os
import sys
from datetime import date, datetime
from pathlib import Path
from typing import Optional

CODEX_DIR = Path.home() / ".codex"
SESSIONS_DIR = CODEX_DIR / "sessions"
ARCHIVE_DIR = CODEX_DIR / "archived_sessions"


def find_sessions(target_date: date) -> list[Path]:
    """Find all session JSONL files for a given date."""
    day_dir = SESSIONS_DIR / str(target_date.year) / f"{target_date.month:02d}" / f"{target_date.day:02d}"
    files = sorted(day_dir.glob("rollout-*.jsonl")) if day_dir.exists() else []
    # Also check archived sessions for that date
    date_str = target_date.strftime("%Y-%m-%d")
    for f in sorted(ARCHIVE_DIR.glob(f"rollout-{date_str}*.jsonl")):
        if f not in files:
            files.append(f)
    return files


def parse_session(path: Path) -> Optional[dict]:
    """Parse a single Codex session JSONL into a structured summary."""
    meta = {}
    user_prompts = []
    assistant_outputs = []
    tool_calls = []
    files_touched = set()
    model = None

    try:
        with open(path) as f:
            for line in f:
                entry = json.loads(line)
                etype = entry.get("type")
                payload = entry.get("payload", {})

                if etype == "session_meta":
                    meta = {
                        "id": payload.get("id", ""),
                        "cwd": payload.get("cwd", ""),
                        "cli_version": payload.get("cli_version", ""),
                        "source": payload.get("source", ""),
                        "timestamp": payload.get("timestamp", entry.get("timestamp", "")),
                    }

                elif etype == "turn_context":
                    if not model:
                        model = payload.get("model")

                elif etype == "response_item":
                    item = payload.get("item", payload)
                    role = item.get("role", "")
                    item_type = item.get("type", "")
                    content = item.get("content", [])

                    if item_type == "function_call":
                        name = item.get("name", "")
                        args_raw = item.get("arguments", "")
                        call_info = {"name": name}
                        try:
                            args = json.loads(args_raw) if args_raw else {}
                        except (json.JSONDecodeError, TypeError):
                            args = {}

                        # Extract file paths from common tool patterns
                        for key in ("file_path", "path", "filepath"):
                            if key in args:
                                files_touched.add(args[key])
                        if "cmd" in args:
                            cmd = args["cmd"]
                            call_info["cmd"] = cmd[:200]
                            # Detect file writes from shell commands
                            for token in cmd.split():
                                if "/" in token and not token.startswith("-"):
                                    if any(token.endswith(ext) for ext in (".ts", ".tsx", ".js", ".py", ".kt", ".swift", ".gd", ".json", ".yaml", ".yml", ".toml", ".md", ".css", ".html")):
                                        files_touched.add(token)

                        tool_calls.append(call_info)

                    elif item_type == "function_call_output":
                        output = item.get("output", "")
                        # Extract file paths from apply_diff / write outputs
                        if isinstance(output, str) and "Applied diff to" in output:
                            for part in output.split("Applied diff to"):
                                p = part.strip().split("\n")[0].strip().rstrip(".")
                                if p and "/" in p:
                                    files_touched.add(p)

                    elif isinstance(content, list):
                        for c in content:
                            ct = c.get("type", "")
                            text = c.get("text", "")
                            if not text:
                                continue
                            # Skip system/developer instructions
                            if ct == "input_text" and role == "user":
                                if not text.startswith(("<", "# AGENTS.md")):
                                    user_prompts.append(text.strip())
                            elif ct == "output_text" and role == "assistant":
                                assistant_outputs.append(text.strip())

    except Exception as e:
        print(f"WARN: Failed to parse {path}: {e}", file=sys.stderr)
        return None

    if not meta:
        return None

    # Skip very short sessions (no real work)
    if not user_prompts and not tool_calls:
        return None

    # Derive project name from cwd
    cwd = meta.get("cwd", "")
    project = os.path.basename(cwd) if cwd else "unknown"

    # Clean up file paths (make relative to cwd)
    rel_files = set()
    for fp in files_touched:
        if cwd and fp.startswith(cwd):
            fp = fp[len(cwd):].lstrip("/")
        rel_files.add(fp)

    return {
        "session_id": meta.get("id", ""),
        "timestamp": meta.get("timestamp", ""),
        "project": project,
        "cwd": cwd,
        "model": model or "unknown",
        "source": meta.get("source", ""),
        "user_prompts": user_prompts,
        "assistant_summary": assistant_outputs[:5],  # First 5 outputs as summary
        "tool_call_count": len(tool_calls),
        "tool_names": list({tc["name"] for tc in tool_calls}),
        "files_touched": sorted(rel_files),
    }


def format_markdown(sessions: list[dict], target_date: date) -> str:
    """Format parsed sessions as markdown for daily log."""
    if not sessions:
        return f"### Codex Activity ({target_date})\nNo Codex sessions found.\n"

    # Group by project
    by_project: dict[str, list[dict]] = {}
    for s in sessions:
        by_project.setdefault(s["project"], []).append(s)

    lines = [f"### Codex Activity ({target_date})", ""]

    for project, proj_sessions in sorted(by_project.items()):
        lines.append(f"**{project}** ({len(proj_sessions)} sessions)")

        for s in proj_sessions:
            ts = s["timestamp"]
            if isinstance(ts, str) and "T" in ts:
                ts = ts.split("T")[1][:5]  # HH:MM

            # Summarize user intent
            prompt_summary = ""
            for p in s["user_prompts"][:2]:
                cleaned = p.replace("\n", " ").strip()
                if len(cleaned) > 120:
                    cleaned = cleaned[:117] + "..."
                prompt_summary += f" \"{cleaned}\""

            lines.append(f"- `{ts}` [{s['model']}] ({s['tool_call_count']} tools){prompt_summary}")

            if s["files_touched"]:
                files_str = ", ".join(s["files_touched"][:8])
                if len(s["files_touched"]) > 8:
                    files_str += f" +{len(s['files_touched']) - 8}"
                lines.append(f"  - Files: {files_str}")

        lines.append("")

    total_tools = sum(s["tool_call_count"] for s in sessions)
    total_files = len({f for s in sessions for f in s["files_touched"]})
    lines.append(f"**Total**: {len(sessions)} sessions, {total_tools} tool calls, {total_files} files touched")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Harvest Codex session data")
    parser.add_argument("--date", default=date.today().isoformat(), help="Date to harvest (YYYY-MM-DD)")
    parser.add_argument("--session", help="Parse a single session file")
    parser.add_argument("--json", action="store_true", help="Output JSON instead of markdown")
    parser.add_argument("--project", help="Filter by project name")
    args = parser.parse_args()

    if args.session:
        path = Path(args.session)
        result = parse_session(path)
        if result:
            if args.json:
                print(json.dumps(result, ensure_ascii=False, indent=2))
            else:
                print(format_markdown([result], date.today()))
        else:
            print("No data extracted from session.", file=sys.stderr)
            sys.exit(1)
        return

    target = date.fromisoformat(args.date)
    session_files = find_sessions(target)

    if not session_files:
        print(f"No Codex sessions found for {target}", file=sys.stderr)
        sys.exit(0)

    sessions = []
    for sf in session_files:
        parsed = parse_session(sf)
        if parsed:
            if args.project and args.project.lower() not in parsed["project"].lower():
                continue
            sessions.append(parsed)

    if args.json:
        print(json.dumps(sessions, ensure_ascii=False, indent=2))
    else:
        print(format_markdown(sessions, target))


if __name__ == "__main__":
    main()
