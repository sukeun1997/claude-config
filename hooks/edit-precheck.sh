#!/usr/bin/env bash
# edit-precheck.sh — PreToolUse hook for Edit|Write|Read
#
# Why this exists (W26 review): the PostToolUse edit-tracker warning fired 70+
# times across friction history (Read:Edit 42건 + 반복편집 28건) without
# preventing repeat-edit churn. A post-edit warning lands after the model has
# already committed to the edit. This pre-edit hook surfaces the same remedy
# at the decision point AND, crucially, goes quiet the moment the documented
# remedy (limit 없이 전체 Read) is actually followed — so churn-without-Read
# keeps getting nagged while a proper Read silences it.
#
# Non-blocking by design (always exit 0). A blocking hook on a personal global
# harness has too large a blast radius (could deadlock edits across every
# project); the count-reset-on-full-Read loop gives teeth without that risk.
#
# No separate read-marker is kept: a full Read resets the file's edit count to
# 0, and edit-tracker.sh (PostToolUse) re-increments on subsequent edits. So
# the count alone tracks "edits since the last full Read" — a Read at hour 1
# does not permanently silence churn at hour 5.

set -euo pipefail

SESSION_ID_FILE="$HOME/.claude/memory/sessions/.current-session-id"
if [ -f "$SESSION_ID_FILE" ]; then
  SESSION_ID=$(cat "$SESSION_ID_FILE" 2>/dev/null || echo "unknown")
else
  SESSION_ID="fallback-${PPID:-unknown}"
fi
TRACK_FILE="/tmp/claude-edit-tracker-${SESSION_ID}"   # shared with edit-tracker.sh (PostToolUse writer)

TOOL_NAME="${TOOL_NAME:-}"
TOOL_INPUT="${TOOL_INPUT:-}"
[ -z "$TOOL_INPUT" ] && exit 0

FILE_PATH=$(echo "$TOOL_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
[ -z "$FILE_PATH" ] && exit 0

case "$TOOL_NAME" in
  Read)
    # A full read (no "limit" field) is the documented remedy for repeat-edit
    # churn. Reset this file's edit count so the escalation clears and the next
    # churn cycle is measured from a fresh full read.
    if ! echo "$TOOL_INPUT" | grep -q '"limit"'; then
      if [ -f "$TRACK_FILE" ]; then
        grep -vxF "$FILE_PATH" "$TRACK_FILE" > "${TRACK_FILE}.tmp" 2>/dev/null && mv "${TRACK_FILE}.tmp" "$TRACK_FILE" || true
      fi
    fi
    exit 0
    ;;
  Edit|Write|MultiEdit)
    [ -f "$TRACK_FILE" ] || exit 0
    COUNT=$(grep -cxF "$FILE_PATH" "$TRACK_FILE" 2>/dev/null || echo "0")
    COUNT=$(echo "$COUNT" | tr -d '[:space:]'); COUNT="${COUNT:-0}"
    # COUNT = edits since the last full Read. >=2 means a 3rd edit is imminent.
    if [ "$COUNT" -ge 2 ]; then
      NEXT=$((COUNT + 1))
      echo "✋ 편집 전 점검 — $(basename "$FILE_PATH") 을(를) 이미 ${COUNT}회 수정했고 이번이 ${NEXT}회차입니다. 이번 Edit 전에 limit 없이 파일 전체 Read 1회 + 호출/피호출 파일 1개 Read를 먼저 하세요 (CLAUDE.md '반복 편집 방지'). 전체 Read를 하면 이 점검은 자동으로 조용해집니다."
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
