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

# --- Load today's daily log (max 100 lines = ~2000 tokens) ---
TODAY_LOG="$MEM_DIR/daily/${TODAY}.md"
if [ -f "$TODAY_LOG" ] && [ -s "$TODAY_LOG" ]; then
  CONTEXT+="# Daily Log: ${TODAY}
$(safe_read_limited "$TODAY_LOG" 100)

"
fi

# --- Load yesterday's daily log (max 50 lines = ~1000 tokens) ---
YESTERDAY_LOG="$MEM_DIR/daily/${YESTERDAY}.md"
if [ -f "$YESTERDAY_LOG" ] && [ -s "$YESTERDAY_LOG" ]; then
  CONTEXT+="# Daily Log: ${YESTERDAY} (yesterday)
$(safe_read_limited "$YESTERDAY_LOG" 50)

"
fi

# --- [PROMOTE] auto-detection from yesterday's log ---
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
if [ -n "$CONTEXT" ]; then
  echo "$CONTEXT"
fi

exit 0
