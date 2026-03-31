#!/usr/bin/env bash
# memory-session-end.sh — SessionEnd hook (async)
# Archives daily logs older than 14 days to archive/YYYY-MM/ subdirectories.

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

MEM_DIR=$(get_memory_dir)
DAILY_DIR="$MEM_DIR/daily"
ARCHIVE_DIR="$MEM_DIR/archive"

# Skip if no daily directory
[ -d "$DAILY_DIR" ] || exit 0

# Calculate cutoff date (14 days ago)
if date -v-14d +%Y-%m-%d >/dev/null 2>&1; then
  # macOS
  CUTOFF=$(date -v-14d +%Y-%m-%d)
else
  # Linux
  CUTOFF=$(date -d "14 days ago" +%Y-%m-%d)
fi

# Archive old daily logs
ARCHIVED=0
for log_file in "$DAILY_DIR"/*.md; do
  [ -f "$log_file" ] || continue

  filename=$(basename "$log_file")
  # Extract date from filename (YYYY-MM-DD.md)
  log_date="${filename%.md}"

  # Validate date format
  if ! echo "$log_date" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    continue
  fi

  # Compare dates (string comparison works for YYYY-MM-DD format)
  if [[ "$log_date" < "$CUTOFF" ]]; then
    # Extract YYYY-MM for archive subdirectory
    archive_month="${log_date:0:7}"
    target_dir="$ARCHIVE_DIR/$archive_month"
    mkdir -p "$target_dir"
    mv "$log_file" "$target_dir/"
    ARCHIVED=$((ARCHIVED + 1))
  fi
done

if [ "$ARCHIVED" -gt 0 ]; then
  echo "Archived $ARCHIVED daily log(s) older than 14 days."
fi

# Clean up active context for merged/deleted branches
ACTIVE_DIR="$MEM_DIR/active"
if [ -d "$ACTIVE_DIR" ]; then
  for f in "$ACTIVE_DIR"/*.md; do
    [ -f "$f" ] || continue
    SLUG=$(basename "$f" .md)
    BRANCH_NAME=$(echo "$SLUG" | sed 's|--|/|g')
    # If branch no longer exists locally, archive the active context
    if ! git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" 2>/dev/null; then
      mkdir -p "$ARCHIVE_DIR"
      mv "$f" "$ARCHIVE_DIR/" 2>/dev/null || true
    fi
  done
fi

# Clean up summarizer state files older than 2 hours
find "$DAILY_DIR" -name ".summarizer-state-*.json" -mmin +120 -delete 2>/dev/null || true

# Load GEMINI_API_KEY (hook runs as non-login bash, .zshrc not sourced)
load_gemini_key

# Flush auto-captured tool events to daily log summary
if command -v python3 &>/dev/null && [ -f "$HOME/.claude/hooks/memory-post-tool.py" ]; then
  CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}" \
    python3 "$HOME/.claude/hooks/memory-post-tool.py" flush 2>/dev/null || true
fi

# Incremental indexing: index today's daily log for semantic search
if command -v python3 &>/dev/null && [ -f "$HOME/.claude/hooks/memory-search.py" ] && [ -n "${GEMINI_API_KEY:-}" ]; then
  TODAY_LOG="$DAILY_DIR/$(date +%Y-%m-%d).md"
  if [ -f "$TODAY_LOG" ]; then
    CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}" \
      python3 "$HOME/.claude/hooks/memory-search.py" index --file "$TODAY_LOG" 2>/dev/null || true
  fi
fi

exit 0
