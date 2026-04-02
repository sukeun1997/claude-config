#!/usr/bin/env python3
"""
memory-post-tool.py — PostToolUse auto-capture hook

Captures significant tool executions to a daily JSONL buffer.
Flushed to daily log summary by memory-session-end.sh.

Usage:
  (stdin JSON)  — PostToolUse hook mode (called by Claude Code)
  flush          — Summarize captures → append to daily log
  stats          — Show today's capture stats

Captured events:
  Write/Edit : file path + change size
  Bash       : gradle build/test, git operations
  Task       : agent type + description

Skipped (noise):
  Read, Grep, Glob, ToolSearch, and trivial Bash commands
"""

import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CAPTURE_TOOLS = {"Write", "Edit", "Bash", "Task", "Skill"}

SKIP_TOOLS = {
    "Read", "Grep", "Glob", "ToolSearch",
    "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "TaskOutput", "TaskStop",
    "AskUserQuestion", "EnterPlanMode", "ExitPlanMode", "NotebookEdit",
    "SendMessage", "ListMcpResourcesTool", "ReadMcpResourceTool",
    "EnterWorktree", "WebFetch", "WebSearch",
}

# Bash command prefixes worth capturing
BASH_CAPTURE_PATTERNS = [
    "./gradlew", "gradlew", "gradle",
    "git commit", "git push", "git merge", "git rebase", "git checkout -b",
    "git cherry-pick", "git tag",
    "docker", "kubectl",
    "npm run", "npm test", "yarn ", "bun run", "bun test",
    "pytest", "cargo test", "go test", "mvn ",
    "gh pr create", "gh pr merge",
]

# Bash commands to always skip (read-only / trivial)
BASH_SKIP_PATTERNS = [
    "cat ", "ls ", "head ", "tail ", "echo ", "pwd", "which ", "wc ",
    "find ", "grep ", "rg ", "sed -n", "awk ", "sort ", "uniq ",
    "gh pr view", "gh pr diff", "gh api", "gh pr list",
    "python3 -m json.tool", "python3 -c", "jq ",
    "date ", "stat ", "du ", "df ",
]

DEDUP_WINDOW_SEC = 60
MAX_DAILY_CAPTURES = 200


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

def get_memory_dir() -> Path:
    return Path.home() / ".claude" / "memory"


def detect_project() -> str:
    """Detect project name from CWD, mirroring memory-lib.sh detect_project()."""
    cwd = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    # Check for .claude-project file walking up
    check_dir = Path(cwd)
    while check_dir != check_dir.parent:
        proj_file = check_dir / ".claude-project"
        if proj_file.exists():
            return proj_file.read_text().strip().split("\n")[0].strip()
        check_dir = check_dir.parent
    # Fallback: path-based mapping
    cwd_lower = cwd.lower()
    mapping = {
        "maple": "maple", "todo-app": "haru", "building-manager": "building",
        "lendit": "lendit", "ktx_reservation": "ktx", "my-game": "game",
        "news": "news",
    }
    for key, name in mapping.items():
        if key in cwd_lower:
            return name
    if "/.claude" in cwd:
        return "global"
    return "global"


def daily_log_filename(date_str: str) -> str:
    """Return project-aware daily log filename."""
    project = detect_project()
    if project == "global":
        return f"{date_str}.md"
    return f"{date_str}-{project}.md"


def get_capture_file(mem_dir: Path) -> Path:
    today = datetime.now().strftime("%Y-%m-%d")
    daily_dir = mem_dir / "daily"
    daily_dir.mkdir(parents=True, exist_ok=True)
    return daily_dir / f".captures-{today}.jsonl"


def get_dedup_file(mem_dir: Path) -> Path:
    return mem_dir / "daily" / ".dedup-state.json"


def shorten_path(path: str) -> str:
    cwd = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    if path.startswith(cwd):
        return path[len(cwd):].lstrip("/")
    home = str(Path.home())
    if path.startswith(home):
        return "~" + path[len(home):]
    return path


# ---------------------------------------------------------------------------
# Deduplication
# ---------------------------------------------------------------------------

def check_dedup(dedup_file: Path, key: str) -> bool:
    """Returns True if this key was seen within DEDUP_WINDOW_SEC (= skip)."""
    now = time.time()
    state = {}
    if dedup_file.exists():
        try:
            state = json.loads(dedup_file.read_text())
        except (json.JSONDecodeError, OSError):
            state = {}

    # Evict expired entries
    state = {k: v for k, v in state.items() if now - v < DEDUP_WINDOW_SEC}

    if key in state:
        return True

    state[key] = now
    try:
        dedup_file.write_text(json.dumps(state))
    except OSError:
        pass
    return False


# ---------------------------------------------------------------------------
# Bash classification
# ---------------------------------------------------------------------------

def classify_bash(command: str) -> "str | None":
    """Classify Bash command. Returns category or None to skip."""
    cmd = command.strip()

    for skip in BASH_SKIP_PATTERNS:
        if cmd.startswith(skip):
            return None

    for pat in BASH_CAPTURE_PATTERNS:
        if pat in cmd:
            if "gradlew" in cmd or "gradle" in cmd:
                if "test" in cmd:
                    return "test"
                if "build" in cmd or "compile" in cmd:
                    return "build"
                return "gradle"
            if "git " in cmd:
                return "git"
            if "gh pr" in cmd:
                return "git"
            if "docker" in cmd:
                return "docker"
            return "command"

    return None


def extract_bash_summary(command: str, output: str, category: str) -> dict:
    """Extract concise summary from Bash execution."""
    summary = {"command": command[:200], "category": category}

    if not output:
        return summary

    output_lower = output.lower()
    # "0 failures" / "0 failed" are success indicators, exclude them
    cleaned = output_lower.replace("0 failures", "").replace("0 failed", "")
    fail_keywords = ("failed", "failure", "error:", "exception", "fatal", "build_failed")
    if any(kw in cleaned for kw in fail_keywords):
        summary["status"] = "FAILED"
        lines = [l.strip() for l in output.strip().split("\n") if l.strip()]
        error_lines = [
            l for l in lines[-15:]
            if any(kw in l.lower() for kw in ("error", "fail", "exception", "unresolved"))
        ]
        summary["error"] = "\n".join(error_lines[:3]) if error_lines else (lines[-1][:200] if lines else "")
    else:
        summary["status"] = "SUCCESS"
        if category == "test":
            for line in reversed(output.split("\n")):
                if "test" in line.lower() and any(c.isdigit() for c in line):
                    summary["result"] = line.strip()[:200]
                    break
        elif category == "build":
            for line in reversed(output.split("\n")):
                if "build successful" in line.lower() or "build_successful" in line.lower():
                    summary["result"] = line.strip()[:200]
                    break

    return summary


# ---------------------------------------------------------------------------
# Capture (PostToolUse mode)
# ---------------------------------------------------------------------------

def cmd_capture():
    """Read tool event from stdin, filter, and append to capture buffer."""
    raw = sys.stdin.read()
    if not raw.strip():
        return

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return

    tool = data.get("tool_name", data.get("tool", ""))

    if tool in SKIP_TOOLS or tool not in CAPTURE_TOOLS:
        return

    tool_input = data.get("tool_input", data.get("input", {}))
    tool_output = data.get("tool_output", data.get("output", ""))

    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input)
        except (json.JSONDecodeError, TypeError):
            tool_input = {"raw": tool_input}

    if isinstance(tool_output, dict):
        tool_output = json.dumps(tool_output, ensure_ascii=False)
    tool_output = str(tool_output) if tool_output else ""

    mem_dir = get_memory_dir()
    capture_file = get_capture_file(mem_dir)
    dedup_file = get_dedup_file(mem_dir)

    # Daily cap check
    if capture_file.exists():
        try:
            line_count = sum(1 for _ in open(capture_file))
            if line_count >= MAX_DAILY_CAPTURES:
                return
        except OSError:
            pass

    now = datetime.now()
    entry = {
        "ts": now.strftime("%H:%M:%S"),
        "date": now.strftime("%Y-%m-%d"),
        "tool": tool,
        "project": detect_project(),
    }

    # --- Write / Edit ---
    if tool in ("Write", "Edit"):
        fp = tool_input.get("file_path", tool_input.get("path", ""))
        if not fp:
            return
        short = shorten_path(fp)
        if check_dedup(dedup_file, f"{tool}:{short}"):
            return
        entry["file"] = short
        if tool == "Edit":
            old = tool_input.get("old_string", "")
            new = tool_input.get("new_string", "")
            if old and new:
                entry["delta"] = f"-{len(old.splitlines())}L +{len(new.splitlines())}L"

    # --- Bash ---
    elif tool == "Bash":
        command = tool_input.get("command", "")
        category = classify_bash(command)
        if category is None:
            return
        summary = extract_bash_summary(command, tool_output, category)
        entry.update(summary)
        if check_dedup(dedup_file, f"Bash:{category}:{command[:80]}"):
            return

    # --- Skill ---
    elif tool == "Skill":
        skill_name = tool_input.get("skill", "unknown")
        entry["skill"] = skill_name
        if check_dedup(dedup_file, f"Skill:{skill_name}"):
            return

    # --- Task (agent) ---
    elif tool == "Task":
        agent_type = tool_input.get("subagent_type", tool_input.get("type", "unknown"))
        description = tool_input.get("description", "")
        entry["agent"] = agent_type
        entry["description"] = description[:100]
        if tool_output:
            entry["result_preview"] = tool_output[:300]

    else:
        return

    line = json.dumps(entry, ensure_ascii=False) + "\n"

    try:
        with open(capture_file, "a") as f:
            f.write(line)
    except OSError:
        pass

    # Dual-write to observations.jsonl for observer-runner → instinct pipeline
    obs_file = Path.home() / ".claude" / "homunculus" / "observations.jsonl"
    try:
        obs_file.parent.mkdir(parents=True, exist_ok=True)
        with open(obs_file, "a") as f:
            f.write(line)
    except OSError:
        pass


# ---------------------------------------------------------------------------
# Flush (SessionEnd mode)
# ---------------------------------------------------------------------------

def cmd_flush():
    """Summarize today's captures and append to daily log."""
    mem_dir = get_memory_dir()
    today = datetime.now().strftime("%Y-%m-%d")
    capture_file = mem_dir / "daily" / f".captures-{today}.jsonl"
    daily_log = mem_dir / "daily" / daily_log_filename(today)

    if not capture_file.exists():
        return

    entries = []
    for line in capture_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue

    if not entries:
        capture_file.unlink(missing_ok=True)
        return

    # --- Group by category ---
    files_modified = []
    files_created = []
    builds = []
    tests = []
    git_ops = []
    agents = []
    other_cmds = []

    seen_files = set()
    for e in entries:
        tool = e.get("tool", "")
        if tool == "Write":
            f = e.get("file", "")
            if f and f not in seen_files:
                seen_files.add(f)
                files_created.append(f)
        elif tool == "Edit":
            f = e.get("file", "")
            if f and f not in seen_files:
                seen_files.add(f)
                files_modified.append(f)
        elif tool == "Bash":
            cat = e.get("category", "")
            status = e.get("status", "")
            cmd = e.get("command", "")[:100]
            if cat == "build":
                builds.append(f"`{cmd}` → {status}")
            elif cat == "test":
                result = e.get("result", status)
                tests.append(f"`{cmd}` → {result}")
            elif cat == "git":
                git_ops.append(f"`{cmd}`")
            else:
                other_cmds.append(f"`{cmd}` → {status}")
        elif tool == "Task":
            agent = e.get("agent", "unknown")
            desc = e.get("description", "")
            agents.append(f"{agent}: {desc}")

    # --- Build compact summary ---
    lines = []
    now_str = datetime.now().strftime("%H:%M")
    lines.append(f"### {now_str} - [Auto] Session ({len(entries)} events)")

    # Files: compact, show only count + key files (max 4)
    all_files = list(dict.fromkeys(files_created + files_modified))  # dedupe, preserve order
    if all_files:
        # Show only filenames (not full paths) for brevity
        short_names = [f.split("/")[-1] for f in all_files[:4]]
        extra = f" +{len(all_files) - 4}" if len(all_files) > 4 else ""
        lines.append(f"- **Files** ({len(all_files)}): {', '.join(short_names)}{extra}")

    # Build/Test: only final status, not every command
    build_success = sum(1 for b in builds if "SUCCESS" in b)
    build_fail = sum(1 for b in builds if "FAILED" in b)
    if builds:
        lines.append(f"- **Build**: {build_success} ok, {build_fail} fail" if build_fail else f"- **Build**: {build_success} ok")

    test_success = sum(1 for t in tests if "SUCCESS" in t or "pass" in t.lower())
    test_fail = sum(1 for t in tests if "FAILED" in t or "fail" in t.lower())
    if tests:
        lines.append(f"- **Test**: {test_success} ok, {test_fail} fail" if test_fail else f"- **Test**: {test_success} ok")

    # Git: only commits (skip add, push is implicit)
    commit_ops = [g for g in git_ops if "commit" in g]
    if commit_ops:
        lines.append(f"- **Git**: {len(commit_ops)} commit(s)")

    # Agents: compact
    if agents:
        agent_summary = ", ".join(set(a.split(":")[0].strip() for a in agents))
        lines.append(f"- **Agents**: {agent_summary}")

    if len(lines) <= 1:
        capture_file.unlink(missing_ok=True)
        return

    summary = "\n".join(lines) + "\n\n"

    # Append to daily log
    try:
        with open(daily_log, "a") as f:
            f.write(summary)
    except OSError as e:
        print(f"Error writing to daily log: {e}", file=sys.stderr)
        return

    # Clean up
    capture_file.unlink(missing_ok=True)
    dedup_file = get_dedup_file(mem_dir)
    dedup_file.unlink(missing_ok=True)

    print(f"Flushed {len(entries)} captures to {daily_log.name}")


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

def cmd_stats():
    """Show today's capture statistics."""
    mem_dir = get_memory_dir()
    today = datetime.now().strftime("%Y-%m-%d")
    capture_file = mem_dir / "daily" / f".captures-{today}.jsonl"

    if not capture_file.exists():
        print("No captures today.")
        return

    entries = []
    for line in capture_file.read_text().splitlines():
        if line.strip():
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    tool_counts = {}
    for e in entries:
        t = e.get("tool", "unknown")
        tool_counts[t] = tool_counts.get(t, 0) + 1

    print(f"Date: {today}")
    print(f"Total: {len(entries)} captures")
    print(f"Size: {capture_file.stat().st_size / 1024:.1f} KB")
    for t, c in sorted(tool_counts.items(), key=lambda x: -x[1]):
        print(f"  {t}: {c}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "flush":
            cmd_flush()
        elif cmd == "stats":
            cmd_stats()
        else:
            print(f"Unknown command: {cmd}")
            print("Usage: memory-post-tool.py [flush|stats]")
            print("  (no args) = PostToolUse capture mode (reads stdin)")
            sys.exit(1)
    else:
        cmd_capture()


if __name__ == "__main__":
    main()
