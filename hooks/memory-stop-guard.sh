#!/usr/bin/env bash
# memory-stop-guard.sh — Stop hook
# Warns if today's project daily log has no real content.
# Project-aware: checks the correct daily log file based on CWD.

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

MEM_DIR=$(get_memory_dir)
TODAY=$(today)
PROJECT=$(detect_project)
TODAY_FILENAME=$(daily_log_filename "$TODAY")
TODAY_LOG="$MEM_DIR/daily/${TODAY_FILENAME}"

# --- Active context check (branch-based first, then project-based fallback) ---
CONTEXT_FILE=""
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  _BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ -n "$_BRANCH" ] && [ "$_BRANCH" != "HEAD" ] && [ "$_BRANCH" != "main" ] && [ "$_BRANCH" != "master" ] && [ "$_BRANCH" != "develop" ]; then
    _SLUG=$(branch_slug "$_BRANCH")
    _BRANCH_FILE="$MEM_DIR/active/${_SLUG}.md"
    [ -f "$_BRANCH_FILE" ] && [ -s "$_BRANCH_FILE" ] && CONTEXT_FILE="$_BRANCH_FILE"
  fi
fi
if [ -z "$CONTEXT_FILE" ]; then
  CONTEXT_FILENAME=$(active_context_filename)
  CONTEXT_FILE="$MEM_DIR/sessions/${CONTEXT_FILENAME}"
fi
CONTEXT_OK=false

if [ -f "$CONTEXT_FILE" ] && [ -s "$CONTEXT_FILE" ]; then
  NOW=$(now_time)
  sed -i '' "s/^updated: .*/updated: ${TODAY}T${NOW}+09:00/" "$CONTEXT_FILE" 2>/dev/null || true

  # Check handoff section exists
  if grep -q '^## Handoff' "$CONTEXT_FILE" 2>/dev/null; then
    CONTEXT_OK=true
  else
    cat <<EOF
⚠️ [${PROJECT}] Active context에 Handoff 섹션이 없습니다.
다음 세션 복구를 위해 Handoff를 작성해주세요.

포맷:
## Handoff
- 바뀐 것: {오늘 변경한 핵심 사항}
- 안 된 것: {미완료 항목}
- 다음 파일: {이어서 볼 파일 경로}
- 남은 위험: {알려진 이슈/주의사항}
EOF
  fi
else
  cat <<EOF
⚠️ [${PROJECT}] Active context가 없습니다.
세션 종료 전에 active context를 작성해주세요.

경로: $CONTEXT_FILE
EOF
fi

# ── Long session detection (leaked session guard) ──
# 4/24-5/7 리포트에서 14299m·17059m·8954m leaked 세션 다수 감지됨.
# 워크트리/IDE 백그라운드에서 Claude가 살아있다 종료되는 패턴 방지.
SESSION_START_FILE="$MEM_DIR/sessions/.session-start-ts"
NOW_TS=$(date +%s)
SESSION_START_TS=0
if [ -f "$SESSION_START_FILE" ]; then
  SESSION_START_TS=$(cat "$SESSION_START_FILE" 2>/dev/null || echo "0")
fi

# 처음 보거나 8시간+ 오래됐으면 새 세션으로 간주하고 갱신
# (갱신 임계값을 240분 강한 경고보다 크게 두어 dead-code 방지)
if [ "$SESSION_START_TS" -eq 0 ] || [ $((NOW_TS - SESSION_START_TS)) -gt 28800 ]; then
  echo "$NOW_TS" > "$SESSION_START_FILE"
  SESSION_START_TS=$NOW_TS
fi

DURATION_SEC=$((NOW_TS - SESSION_START_TS))
DURATION_MIN=$((DURATION_SEC / 60))

# 240분(4시간)+ → 강한 경고 (leaked 의심)
if [ "$DURATION_MIN" -ge 240 ]; then
  cat <<LEAKED_CRIT
🚨 [Leaked Session 의심] 세션 duration ${DURATION_MIN}분 — 워크트리/IDE 백그라운드 leak 가능성
- 즉시 /clear 또는 세션 종료 권장
- daily log 강제 플러시 + Active Context handoff 작성 후 정리
LEAKED_CRIT
# 60분+ → 일반 경고
elif [ "$DURATION_MIN" -ge 60 ]; then
  cat <<LEAKED
⚠️ [Long Session] 세션 duration ${DURATION_MIN}분 (60분+ 초과)
- 주제 전환이 있었으면 /clear로 새 세션 시작 (1세션 1주제 원칙)
- Active Context Handoff 갱신 권장
LEAKED
fi

# ── Self-absorb: friction 감지 시 개선 제안 요청 ──
# Read stable session ID (matches tool-tracker)
_SID_FILE="$MEM_DIR/sessions/.current-session-id"
if [ -f "$_SID_FILE" ]; then
  _SID=$(cat "$_SID_FILE" 2>/dev/null || echo "unknown")
else
  _SID="fallback-${PPID:-unknown}"
fi
TRACK_FILE="/tmp/claude-edit-tracker-${_SID}"
if [ -f "$TRACK_FILE" ]; then
  FRICTION_FILES=$(sort "$TRACK_FILE" | uniq -c | sort -rn | awk '$1 >= 3 {print $1, $2}')
  if [ -n "$FRICTION_FILES" ]; then
    cat <<SELF_ABSORB

🔄 [Self-Absorb] 이번 세션에서 삽질 패턴이 감지되었습니다:
SELF_ABSORB
    while IFS= read -r line; do
      F_COUNT=$(echo "$line" | awk '{print $1}')
      F_PATH=$(echo "$line" | awk '{print $2}')
      echo "  - $(basename "$F_PATH"): ${F_COUNT}회 반복 편집"
    done <<< "$FRICTION_FILES"
    cat <<SELF_ABSORB

세션 마무리 전에 아래를 수행하세요:
1. 삽질 원인 분류 (Prompt/Context/Harness 중 택1)
2. failure-log.md에 원인+해법 기록
3. CLAUDE.md 또는 훅에 재발 방지 규칙이 필요하면 제안 (사용자 승인 후 적용)
   → 제안은 memory/sessions/.improvement-suggestions.md에 저장

SELF_ABSORB
  fi
fi

# Count non-empty, non-header, non-compaction lines (real content only)
CONTENT_LINES=0
if [ -f "$TODAY_LOG" ]; then
  CONTENT_LINES=$(grep -cvE '^\s*$|^# Daily Log:|Compaction Checkpoint|컴팩션|자동 컴팩션|세션 재개 후' "$TODAY_LOG" 2>/dev/null || true)
  CONTENT_LINES=$(echo "$CONTENT_LINES" | tr -d '[:space:]')
  CONTENT_LINES="${CONTENT_LINES:-0}"
fi

if [ "$CONTENT_LINES" -ge 2 ]; then
  exit 0
else
  cat <<EOF
⚠️ [${PROJECT}] 이 세션에서 daily log가 작성되지 않았습니다.
세션 종료 전에 오늘 작업 내용을 daily log에 기록해주세요.

파일 경로: $TODAY_LOG
포맷: ### HH:MM - [${PROJECT}] 작업 제목
EOF
  exit 0
fi
