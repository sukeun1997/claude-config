#!/usr/bin/env bash
# memory-precompact-path.sh — PreCompact command hook
# Project-aware: writes compaction marker to the correct daily log.

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

MEM_DIR=$(get_memory_dir)
ensure_dirs "$MEM_DIR"
TODAY=$(today)
NOW=$(now_time)
PROJECT=$(detect_project)
TODAY_FILENAME=$(daily_log_filename "$TODAY")
DAILY_LOG="$MEM_DIR/daily/${TODAY_FILENAME}"

# Ensure file exists
if [ ! -f "$DAILY_LOG" ]; then
  if [ "$PROJECT" = "global" ]; then
    echo "# Daily Log: ${TODAY}" > "$DAILY_LOG"
  else
    echo "# Daily Log: ${TODAY} [${PROJECT}]" > "$DAILY_LOG"
  fi
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

# --- Active context: format template for immediate update ---
CONTEXT_FILENAME=$(active_context_filename)
CONTEXT_FILE="$MEM_DIR/sessions/${CONTEXT_FILENAME}"

echo ""
echo "⚠️ Compaction 임박 — active context를 지금 즉시 갱신하세요."
echo "경로: $CONTEXT_FILE"

if [ -f "$CONTEXT_FILE" ] && is_context_fresh "$CONTEXT_FILE" 1; then
  echo "STATUS: active context 존재 (fresh). 현재 작업 상태로 갱신해주세요."
else
  echo "STATUS: active context 없음 또는 stale. 아래 템플릿으로 새로 작성해주세요."
  cat << TMPL

---
project: ${PROJECT}
updated: $(date +%Y-%m-%dT%H:%M+09:00)
---
## Goal
{현재 목표}
## Status
{완료/미완료 체크리스트}
## Next
{다음 할 일}
## Key Decisions
{주요 결정}
## Handoff
- 바뀐 것: {변경 사항}
- 안 된 것: {미완료}
- 다음 파일: {파일 경로}
- 남은 위험: {이슈}
TMPL
fi
