#!/usr/bin/env bash
# tool-tracker.sh — PostToolUse hook for Edit|Write|Read
# Tracks per-file edit/read counts per session.
# - Edit/Write 3+회 same file → 삽질 경고
# - 세션 종료 시 Read:Edit 비율 계산용 데이터 수집

set -euo pipefail

# Session ID
SESSION_ID_FILE="$HOME/.claude/memory/sessions/.current-session-id"
if [ -f "$SESSION_ID_FILE" ]; then
  SESSION_ID=$(cat "$SESSION_ID_FILE" 2>/dev/null || echo "unknown")
else
  SESSION_ID="fallback-${PPID:-unknown}"
fi

EDIT_FILE="/tmp/claude-edit-tracker-${SESSION_ID}"
READ_FILE="/tmp/claude-read-tracker-${SESSION_ID}"

# Determine tool type from TOOL_NAME
TOOL_NAME="${TOOL_NAME:-}"

# Extract file_path from TOOL_INPUT (JSON)
FILE_PATH=""
if [ -n "${TOOL_INPUT:-}" ]; then
  FILE_PATH=$(echo "$TOOL_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
fi

[ -z "$FILE_PATH" ] && exit 0

if [ "$TOOL_NAME" = "Read" ]; then
  # Track reads
  touch "$READ_FILE"
  echo "$FILE_PATH" >> "$READ_FILE"
else
  # Track edits (Edit|Write)
  touch "$EDIT_FILE"

  # Bug fix: grep -c exits 1 when count=0, causing || echo "0" to append extra "0"
  COUNT=$(grep -cxF "$FILE_PATH" "$EDIT_FILE" 2>/dev/null) || COUNT=0
  echo "$FILE_PATH" >> "$EDIT_FILE"

  NEW_COUNT=$((COUNT + 1))
  if [ "$NEW_COUNT" -eq 3 ]; then
    echo "같은 파일을 3회 수정했습니다: $FILE_PATH — 삽질 패턴일 수 있습니다. 접근법을 재검토하고, 원인을 memory/topics/failure-log.md에 기록하세요."
  elif [ "$NEW_COUNT" -eq 5 ]; then
    echo "같은 파일을 5회 수정했습니다: $FILE_PATH — 접근법 변경을 강력히 권장합니다. failure-log.md 기록 필수."
  fi
fi

exit 0
