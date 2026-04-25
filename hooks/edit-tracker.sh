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
  echo "같은 파일을 3회 수정했습니다: $FILE_PATH — 다음 Edit 전에 limit 없이 파일 전체를 Read 1회 + 호출하는/호출되는 파일 1개 Read 후 재시도 (CLAUDE.md '반복 편집 방지'). 접근법 재검토 + 원인을 memory/topics/failure-log.md에 기록."
elif [ "$NEW_COUNT" -eq 5 ]; then
  echo "같은 파일을 5회 수정했습니다: $FILE_PATH — 접근법 오류 신호. 파일 분리/스코프 재정의 또는 brainstorming 재시작 권장. failure-log.md 기록 필수."
fi

exit 0
