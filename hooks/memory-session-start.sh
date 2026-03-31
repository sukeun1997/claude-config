#!/usr/bin/env bash
# memory-session-start.sh — SessionStart hook
# Injects daily log context and memory status into the session.
# Output is captured by Claude Code and injected as additionalContext.

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

MEM_DIR=$(get_memory_dir)
ensure_dirs "$MEM_DIR"

TODAY=$(today)
YESTERDAY=$(yesterday)

# --- Generate stable session ID for edit-tracker and other hooks ---
SESSION_ID_DIR="$HOME/.claude/memory/sessions"
mkdir -p "$SESSION_ID_DIR"
SESSION_ID="$(date +%Y%m%d-%H%M%S)-$$"
echo "$SESSION_ID" > "$SESSION_ID_DIR/.current-session-id"

# --- Flush previous session's pending captures (runs on /clear too) ---
# 1. Flush tool capture JSONL → daily log summary
if command -v python3 &>/dev/null && [ -f "$HOME/.claude/hooks/memory-post-tool.py" ]; then
  CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}" \
    python3 "$HOME/.claude/hooks/memory-post-tool.py" flush 2>/dev/null || true
fi

# 2. Clean up stale state files
find "$MEM_DIR/daily" -name ".summarizer-state-*.json" -delete 2>/dev/null || true

CONTEXT=""

# --- Session metadata (CWD, git branch) ---
CONTEXT+="# Session: ${TODAY}
- CWD: ${PWD}
"
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  CONTEXT+="- Branch: ${BRANCH}
"
fi
CONTEXT+="
"

# --- Load HANDOFF.md if exists (작업 맥락 복원) ---
HANDOFF_FILE="${PWD}/.claude/HANDOFF.md"
if [ -f "$HANDOFF_FILE" ] && [ -s "$HANDOFF_FILE" ]; then
  CONTEXT+="# Active Work Context (from last /clear)
$(safe_read_limited "$HANDOFF_FILE" 50)

"
fi

# --- Git branch context (자동) ---
if [ -n "${BRANCH:-}" ] && command -v git &>/dev/null; then
  # Detect base branch: prefer develop (git-flow), then main, then master
  BASE_BRANCH=""
  for candidate in develop main master; do
    if git show-ref --verify --quiet "refs/heads/$candidate" 2>/dev/null || \
       git show-ref --verify --quiet "refs/remotes/origin/$candidate" 2>/dev/null; then
      BASE_BRANCH="$candidate"
      break
    fi
  done
  BASE_BRANCH="${BASE_BRANCH:-main}"
  AHEAD_COUNT=$(git rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "0")
  if [ "$AHEAD_COUNT" -gt 0 ]; then
    CONTEXT+="# Branch Context (${BRANCH}, ${AHEAD_COUNT} commits ahead of ${BASE_BRANCH})
"
    CONTEXT+="Recent commits:
$(git log --oneline -5 "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "(none)")

"
    CHANGED=$(git diff --stat "${BASE_BRANCH}..HEAD" 2>/dev/null | tail -1)
    if [ -n "$CHANGED" ]; then
      CONTEXT+="Changes: ${CHANGED}
"
    fi
    CONTEXT+="
"
  fi
fi

# --- Auto-create active context for feature branches ---
if [ -f "$HOME/.claude/hooks/memory-active-context.sh" ]; then
  CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}" \
    bash "$HOME/.claude/hooks/memory-active-context.sh" init 2>/dev/null || true
fi

# --- Load active context file for current branch ---
if [ -n "${BRANCH:-}" ]; then
  SLUG=$(branch_slug "$BRANCH")
  ACTIVE_FILE="$MEM_DIR/active/${SLUG}.md"
  if [ -f "$ACTIVE_FILE" ] && [ -s "$ACTIVE_FILE" ]; then
    CONTEXT+="# Active Work Context (branch-specific)
$(safe_read_limited "$ACTIVE_FILE" 40)

"
  fi
fi

# --- Load today's daily log (max 20 lines = ~400 tokens) ---
TODAY_LOG="$MEM_DIR/daily/${TODAY}.md"
if [ -f "$TODAY_LOG" ] && [ -s "$TODAY_LOG" ]; then
  CONTEXT+="# Daily Log: ${TODAY} (last 20 lines, use Read tool for full log)
$(tail -20 "$TODAY_LOG")

"
fi

# --- Yesterday's log: skipped for context savings (read manually if needed) ---
YESTERDAY_LOG="$MEM_DIR/daily/${YESTERDAY}.md"

# --- [PROMOTE] auto-detection from yesterday's log (lightweight check, no content load) ---
if [ -f "$YESTERDAY_LOG" ]; then
  PROMOTE_COUNT=$(grep -c '^\- \[PROMOTE\]' "$YESTERDAY_LOG" 2>/dev/null || echo "0")
  if [ "$PROMOTE_COUNT" -gt 0 ]; then
    CONTEXT+="ACTION NEEDED: ${PROMOTE_COUNT} [PROMOTE] item(s) in yesterday's Daily Log (${YESTERDAY}) awaiting promotion to MEMORY.md.
"
  fi
fi

# --- Check MEMORY.md line count ---
MEMORY_FILE="$MEM_DIR/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
  LINES=$(line_count "$MEMORY_FILE")
  if [ "$LINES" -gt 150 ]; then
    CONTEXT+="WARNING: MEMORY.md is ${LINES} lines (soft limit: 150). Consider moving detailed content to memory/topics/*.md files.

"
  fi
fi

# --- List available topic files ---
TOPICS_DIR="$MEM_DIR/topics"
if [ -d "$TOPICS_DIR" ]; then
  TOPIC_FILES=$(find "$TOPICS_DIR" -name "*.md" -type f 2>/dev/null | sort)
  if [ -n "$TOPIC_FILES" ]; then
    CONTEXT+="Available topic files (read on demand with Read tool):
"
    while IFS= read -r f; do
      CONTEXT+="- memory/topics/$(basename "$f")
"
    done <<< "$TOPIC_FILES"
    CONTEXT+="
"
  fi
fi

# --- Load GEMINI_API_KEY (hook runs as non-login bash, .zshrc not sourced) ---
load_gemini_key

# --- Semantic search availability ---
if command -v python3 &>/dev/null && [ -f "$HOME/.claude/hooks/memory-search.py" ]; then
  if [ -n "${GEMINI_API_KEY:-}" ]; then
    CONTEXT+="Semantic memory search available: \`python3 ~/.claude/hooks/memory-search.py search \"query\"\` (searches all dates including archived)
Modes: --mode hybrid (default, BM25+Vector RRF) | vector | bm25. Options: --mmr (diversity), --compact (brief output)
"
  fi
fi

# --- Memory system reminder ---
if [ -n "$CONTEXT" ]; then
  CONTEXT+="Memory system active: Write important decisions, debugging insights, and patterns to memory/daily/${TODAY}.md during this session. Use [PROMOTE] tag for items that should be promoted to MEMORY.md."
fi

# Output context (plain text — Claude Code captures stdout)
# Opus Architect directive: limit SessionStart output to ~2000 chars to prevent token explosion
if [ -n "$CONTEXT" ]; then
  BYTE_COUNT=${#CONTEXT}
  if [ "$BYTE_COUNT" -gt 2000 ]; then
    echo "${CONTEXT:0:1900}"
    echo ""
    echo "(... SessionStart output truncated: ${BYTE_COUNT} → 2000 chars. Use Read tool for full context.)"
  else
    echo "$CONTEXT"
  fi
fi

exit 0
