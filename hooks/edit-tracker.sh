#!/usr/bin/env bash
# edit-tracker.sh — PostToolUse hook for Edit|Write
# Tracks per-file edit counts per session. Warns model at 3+ edits on same file.

set -euo pipefail

# Session-level tracking file — uses stable session ID from session-start hook
# PPID is unreliable across async hooks; file-based ID is consistent
SESSION_ID_FILE="$HOME/.claude/memory/sessions/.current-session-id"
if [ -f "$SESSION_ID_FILE" ]; then
  SESSION_ID=$(cat "$SESSION_ID_FILE" 2>/dev/null || echo "unknown")
else
  SESSION_ID="fallback-${PPID:-unknown}"
fi
TRACK_FILE="/tmp/claude-edit-tracker-${SESSION_ID}"

# Extract file_path from TOOL_INPUT (JSON)
FILE_PATH=""
if [ -n "${TOOL_INPUT:-}" ]; then
  FILE_PATH=$(echo "$TOOL_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
fi

# Skip if no file path detected
[ -z "$FILE_PATH" ] && exit 0

# Initialize tracking file if needed
touch "$TRACK_FILE"

# Count previous edits to this file
COUNT=$(grep -cxF "$FILE_PATH" "$TRACK_FILE" 2>/dev/null || echo "0")

# Record this edit
echo "$FILE_PATH" >> "$TRACK_FILE"

# Warn at 3+ edits
NEW_COUNT=$((COUNT + 1))
if [ "$NEW_COUNT" -eq 3 ]; then
  echo "같은 파일을 3회 수정했습니다: $FILE_PATH — 삽질 패턴일 수 있습니다. 접근법을 재검토하고, 원인을 memory/topics/failure-log.md에 기록하세요."
elif [ "$NEW_COUNT" -eq 5 ]; then
  echo "같은 파일을 5회 수정했습니다: $FILE_PATH — 접근법 변경을 강력히 권장합니다. failure-log.md 기록 필수."
fi

exit 0
