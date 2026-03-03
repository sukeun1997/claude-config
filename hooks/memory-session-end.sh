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

# Note: Indexing is handled by memory-search MCP server (auto-indexing on search)

exit 0
