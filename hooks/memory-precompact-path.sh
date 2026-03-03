#!/usr/bin/env bash
# memory-precompact-path.sh — PreCompact command hook
# 1) Outputs DAILY_LOG_PATH for agent hooks (additional context)
# 2) Writes a compaction marker directly to daily log (fallback if agent fails)

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

MEM_DIR=$(get_memory_dir)
ensure_dirs "$MEM_DIR"
TODAY=$(today)
NOW=$(now_time)
DAILY_LOG="$MEM_DIR/daily/${TODAY}.md"

# Ensure file exists
if [ ! -f "$DAILY_LOG" ]; then
  echo "# Daily Log: ${TODAY}" > "$DAILY_LOG"
fi

# Write compaction marker directly (reliable — no agent dependency)
cat >> "$DAILY_LOG" << EOF

### ${NOW} - [Compaction Checkpoint]
- 자동 컴팩션 발생 — 이전 대화 컨텍스트가 압축됨
- 이 시점까지의 작업 내용이 있다면 세션 재개 후 daily log 업데이트 필요
EOF

# Output path for any downstream agent hooks
echo "DAILY_LOG_PATH=${DAILY_LOG}"
echo "CURRENT_TIME=${NOW}"
echo "Compaction marker written to ${DAILY_LOG}"
