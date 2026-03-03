#!/usr/bin/env bash
# memory-stop-guard.sh — Stop hook
# Blocks session stop if today's daily log has no real content (only header line).
# Returns JSON {"ok": false} to prevent stopping and prompt Claude to write a summary.

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

MEM_DIR=$(get_memory_dir)
TODAY=$(today)
TODAY_LOG="$MEM_DIR/daily/${TODAY}.md"

# Count non-empty, non-header lines (real content)
CONTENT_LINES=0
if [ -f "$TODAY_LOG" ]; then
  # Exclude blank lines and the "# Daily Log:" header
  CONTENT_LINES=$(grep -cvE '^\s*$|^# Daily Log:' "$TODAY_LOG" 2>/dev/null || true)
  CONTENT_LINES=$(echo "$CONTENT_LINES" | tr -d '[:space:]')
  CONTENT_LINES="${CONTENT_LINES:-0}"
fi

if [ "$CONTENT_LINES" -ge 2 ]; then
  # Has meaningful content — OK to stop
  exit 0
else
  # No real content — block and remind
  cat <<EOF
이 세션에서 daily log가 작성되지 않았습니다.
세션 종료 전에 오늘 작업 내용을 daily log에 기록해주세요.

파일 경로: $TODAY_LOG
포맷: ### HH:MM - [Topic]

작성 후 다시 종료해주세요.
EOF
  exit 1
fi
