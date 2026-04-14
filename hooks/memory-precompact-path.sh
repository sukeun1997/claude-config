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

# Output path for debugging (stderr — not injected into model context)
echo "DAILY_LOG_PATH=${DAILY_LOG}" >&2
echo "CURRENT_TIME=${NOW}" >&2
echo "Compaction marker written to ${DAILY_LOG}" >&2

# --- Active context: check branch-based first, then project-based ---
CONTEXT_FILE=""
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  _BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ -n "$_BRANCH" ] && [ "$_BRANCH" != "HEAD" ] && [ "$_BRANCH" != "main" ] && [ "$_BRANCH" != "master" ] && [ "$_BRANCH" != "develop" ]; then
    _SLUG=$(branch_slug "$_BRANCH")
    _BRANCH_FILE="$MEM_DIR/active/${_SLUG}.md"
    [ -f "$_BRANCH_FILE" ] && CONTEXT_FILE="$_BRANCH_FILE"
  fi
fi
if [ -z "$CONTEXT_FILE" ]; then
  CONTEXT_FILENAME=$(active_context_filename)
  CONTEXT_FILE="$MEM_DIR/sessions/${CONTEXT_FILENAME}"
fi

echo ""
echo "⚠️ Compaction 임박 — active context를 지금 즉시 갱신하세요."
echo "경로: $CONTEXT_FILE"

# Re-inject active context content for compaction survival
# Compaction summarizes current messages — this content will be included in the summary
if [ -f "$CONTEXT_FILE" ] && [ -s "$CONTEXT_FILE" ]; then
  echo ""
  echo "--- Active Context (re-injected for compaction survival) ---"
  safe_read_context "$CONTEXT_FILE"
  echo "--- end ---"
fi

if [ -f "$CONTEXT_FILE" ] && is_context_fresh "$CONTEXT_FILE" 1; then
  echo "STATUS: active context 존재 (fresh). compaction 진행."
  # exit 0 (implicit) — compaction 허용
else
  echo "STATUS: active context 없음 또는 stale. 아래 템플릿으로 작성 후 compaction이 재시도됩니다."
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
  # exit 2 — compaction 차단. 모델이 active context를 먼저 갱신하도록 강제.
  exit 2
fi
