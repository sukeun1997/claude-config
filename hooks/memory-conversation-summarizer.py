#!/usr/bin/env python3
"""
memory-conversation-summarizer.py — PostToolUse hook for conversation summarization

Fast-path entry point (2s timeout). Filters significant tool events,
manages debounce state, and spawns memory-conversation-worker.py in background.

Reads PostToolUse JSON from stdin.
"""

import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Tools that indicate significant work (trigger summarization)
SIGNIFICANT_TOOLS = {
    "Write", "Edit",  # Code changes
    "Task",  # Agent completions
}

# Bash commands that indicate significant work
BASH_SIGNIFICANT_PATTERNS = [
    "gradlew", "gradle", "pytest", "go test", "cargo test", "npm test",
    "git commit", "git push", "git merge",
    "docker", "kubectl",
]

# Tools that are purely read-only (never trigger)
SKIP_TOOLS = {
    "Read", "Grep", "Glob", "ToolSearch",
    "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "TaskOutput", "TaskStop",
    "AskUserQuestion", "EnterPlanMode", "ExitPlanMode", "NotebookEdit",
    "SendMessage", "ListMcpResourcesTool", "ReadMcpResourceTool",
    "EnterWorktree", "WebFetch", "WebSearch", "Skill",
}

# Debounce: minimum seconds between worker spawns
DEBOUNCE_SEC = 300  # 5분 — 30초는 같은 주제가 반복 기록되는 원인

# Force trigger if this many turns accumulated regardless of debounce
FORCE_TRIGGER_TURNS = 20  # 5는 너무 빈번 → 20으로 유의미한 작업 묶음 단위

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

WORKER_SCRIPT = Path(__file__).parent / "memory-conversation-worker.py"


def get_memory_dir() -> Path:
    cwd = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    project_id = cwd.replace("/", "-")
    return Path.home() / ".claude" / "projects" / project_id / "memory"


def get_daily_dir(mem_dir: Path) -> Path:
    d = mem_dir / "daily"
    d.mkdir(parents=True, exist_ok=True)
    return d


def get_state_file(daily_dir: Path, session_id: str) -> Path:
    return daily_dir / f".summarizer-state-{session_id}.json"


def get_daily_log(daily_dir: Path) -> Path:
    return daily_dir / f"{datetime.now().strftime('%Y-%m-%d')}.md"


# ---------------------------------------------------------------------------
# State management
# ---------------------------------------------------------------------------

def load_state(state_file: Path) -> dict:
    if state_file.exists():
        try:
            return json.loads(state_file.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return {"last_offset": 0, "last_run_ts": 0.0, "pending_turns": 0}


def save_state(state_file: Path, state: dict) -> None:
    try:
        state_file.write_text(json.dumps(state))
    except OSError:
        pass


# ---------------------------------------------------------------------------
# Significance check
# ---------------------------------------------------------------------------

def is_significant_tool(tool_name: str, tool_input: dict) -> bool:
    """Check if this tool execution represents significant work."""
    if tool_name in SIGNIFICANT_TOOLS:
        return True

    if tool_name == "Bash":
        command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
        return any(pat in command for pat in BASH_SIGNIFICANT_PATTERNS)

    return False


def is_skip_tool(tool_name: str) -> bool:
    """Check if this tool should be completely ignored."""
    return tool_name in SKIP_TOOLS


# ---------------------------------------------------------------------------
# Find transcript path
# ---------------------------------------------------------------------------

def find_transcript(session_id: str) -> str | None:
    """Find the transcript JSONL file for the given session."""
    cwd = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    project_id = cwd.replace("/", "-")
    project_dir = Path.home() / ".claude" / "projects" / project_id

    # Try exact session ID match
    candidate = project_dir / f"{session_id}.jsonl"
    if candidate.exists():
        return str(candidate)

    # Fallback: find most recently modified JSONL
    jsonl_files = sorted(project_dir.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    if jsonl_files:
        return str(jsonl_files[0])

    return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    # Read PostToolUse hook payload from stdin
    raw = sys.stdin.read()
    if not raw.strip():
        return

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return

    tool_name = data.get("tool_name", data.get("tool", ""))
    session_id = data.get("session_id", "unknown")
    tool_input = data.get("tool_input", data.get("input", {}))

    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input)
        except (json.JSONDecodeError, TypeError):
            tool_input = {}

    # Skip read-only tools entirely
    if is_skip_tool(tool_name):
        return

    mem_dir = get_memory_dir()
    daily_dir = get_daily_dir(mem_dir)
    state_file = get_state_file(daily_dir, session_id)
    state = load_state(state_file)

    now = time.time()
    significant = is_significant_tool(tool_name, tool_input)

    # Increment pending turns for non-skip tools
    state["pending_turns"] = state.get("pending_turns", 0) + 1

    # Determine if we should trigger the worker
    elapsed = now - state.get("last_run_ts", 0)
    should_trigger = False

    if significant and elapsed >= DEBOUNCE_SEC:
        should_trigger = True
    elif state["pending_turns"] >= FORCE_TRIGGER_TURNS and elapsed >= DEBOUNCE_SEC:
        should_trigger = True

    if not should_trigger:
        # Just save updated pending count
        save_state(state_file, state)
        return

    # Find transcript file
    transcript_path = find_transcript(session_id)
    if not transcript_path:
        save_state(state_file, state)
        return

    # Check that worker script exists
    if not WORKER_SCRIPT.exists():
        return

    daily_log = get_daily_log(daily_dir)
    offset = state.get("last_offset", 0)

    # Update state before spawning (mark as triggered)
    state["last_run_ts"] = now
    state["pending_turns"] = 0
    save_state(state_file, state)

    # Spawn worker as detached background process
    try:
        subprocess.Popen(
            [
                sys.executable,
                str(WORKER_SCRIPT),
                "--transcript", transcript_path,
                "--offset", str(offset),
                "--daily-log", str(daily_log),
                "--session-id", session_id,
                "--state-file", str(state_file),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError as e:
        print(f"Failed to spawn worker: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
