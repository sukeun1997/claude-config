#!/usr/bin/env bash
# memory-sync.sh — 회사↔집 메모리 데이터 동기화
#
# 사용법:
#   memory-sync.sh push   — 로컬 데이터를 관리 레포에 복사 + push
#   memory-sync.sh pull   — 관리 레포에서 로컬로 가져오기
#   memory-sync.sh status — 동기화 상태 확인
#
# 동기화 대상:
#   - memory/metrics/sessions.jsonl (세션 메트릭)
#   - memory/topics/failure-log.md (삽질 패턴)
#   - homunculus/observations.jsonl (observer 데이터)
#   - memory/skill-usage/*.jsonl (스킬 사용 통계)

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
MGMT_REPO="$HOME/IdeaProjects/관리"
SYNC_DIR="$MGMT_REPO/.harness-sync"

if [ ! -d "$MGMT_REPO/.git" ]; then
  echo "ERROR: 관리 레포 없음 ($MGMT_REPO)"
  exit 1
fi

CMD="${1:-status}"

sync_push() {
  mkdir -p "$SYNC_DIR/metrics" "$SYNC_DIR/daily" "$SYNC_DIR/homunculus" "$SYNC_DIR/skill-usage"

  # Metrics
  [ -f "$CLAUDE_DIR/memory/metrics/sessions.jsonl" ] && \
    cp "$CLAUDE_DIR/memory/metrics/sessions.jsonl" "$SYNC_DIR/metrics/"

  # Failure log
  [ -f "$CLAUDE_DIR/memory/topics/failure-log.md" ] && \
    cp "$CLAUDE_DIR/memory/topics/failure-log.md" "$SYNC_DIR/"

  # Observations (observer pipeline data)
  [ -f "$CLAUDE_DIR/homunculus/observations.jsonl" ] && \
    cp "$CLAUDE_DIR/homunculus/observations.jsonl" "$SYNC_DIR/homunculus/"

  # Skill usage
  if [ -d "$CLAUDE_DIR/memory/skill-usage" ]; then
    cp "$CLAUDE_DIR/memory/skill-usage"/*.jsonl "$SYNC_DIR/skill-usage/" 2>/dev/null || true
  fi

  # Recent daily logs (7일)
  CUTOFF=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d)
  for log in "$CLAUDE_DIR/memory/daily"/*.md; do
    [ -f "$log" ] || continue
    date_only=$(basename "$log" | head -c 10)
    if [[ "$date_only" > "$CUTOFF" ]] 2>/dev/null; then
      cp "$log" "$SYNC_DIR/daily/"
    fi
  done

  # Git commit + push
  cd "$MGMT_REPO"
  git add .harness-sync/
  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "chore: sync harness data [$(hostname -s)]" 2>/dev/null
    git push origin main 2>/dev/null
    echo "PUSH: 동기화 완료 ($(date +%H:%M))"
  else
    echo "PUSH: 변경 없음"
  fi
}

sync_pull() {
  cd "$MGMT_REPO"
  git pull --rebase origin main 2>/dev/null || true

  if [ ! -d "$SYNC_DIR" ]; then
    echo "PULL: 동기화 데이터 없음"
    return
  fi

  MERGED=0

  # Merge sessions.jsonl (append unique lines)
  REMOTE_METRICS="$SYNC_DIR/metrics/sessions.jsonl"
  LOCAL_METRICS="$CLAUDE_DIR/memory/metrics/sessions.jsonl"
  if [ -f "$REMOTE_METRICS" ]; then
    mkdir -p "$(dirname "$LOCAL_METRICS")"
    touch "$LOCAL_METRICS"
    # Append only new lines (dedup by full line content)
    comm -13 <(sort "$LOCAL_METRICS") <(sort "$REMOTE_METRICS") >> "$LOCAL_METRICS" 2>/dev/null || true
    MERGED=$((MERGED + 1))
  fi

  # Merge observations.jsonl
  REMOTE_OBS="$SYNC_DIR/homunculus/observations.jsonl"
  LOCAL_OBS="$CLAUDE_DIR/homunculus/observations.jsonl"
  if [ -f "$REMOTE_OBS" ]; then
    mkdir -p "$(dirname "$LOCAL_OBS")"
    touch "$LOCAL_OBS"
    comm -13 <(sort "$LOCAL_OBS") <(sort "$REMOTE_OBS") >> "$LOCAL_OBS" 2>/dev/null || true
    MERGED=$((MERGED + 1))
  fi

  # Merge skill-usage
  if [ -d "$SYNC_DIR/skill-usage" ]; then
    mkdir -p "$CLAUDE_DIR/memory/skill-usage"
    for f in "$SYNC_DIR/skill-usage"/*.jsonl; do
      [ -f "$f" ] || continue
      LOCAL_F="$CLAUDE_DIR/memory/skill-usage/$(basename "$f")"
      touch "$LOCAL_F"
      comm -13 <(sort "$LOCAL_F") <(sort "$f") >> "$LOCAL_F" 2>/dev/null || true
      MERGED=$((MERGED + 1))
    done
  fi

  echo "PULL: ${MERGED}개 파일 머지 완료"
}

sync_status() {
  echo "=== Harness Data Sync Status ==="
  echo ""

  # Local data
  echo "[로컬 데이터]"
  if [ -f "$CLAUDE_DIR/memory/metrics/sessions.jsonl" ]; then
    LINES=$(wc -l < "$CLAUDE_DIR/memory/metrics/sessions.jsonl" | tr -d ' ')
    echo "  sessions.jsonl: ${LINES}건"
  else
    echo "  sessions.jsonl: 없음"
  fi

  if [ -f "$CLAUDE_DIR/homunculus/observations.jsonl" ]; then
    LINES=$(wc -l < "$CLAUDE_DIR/homunculus/observations.jsonl" | tr -d ' ')
    echo "  observations.jsonl: ${LINES}건"
  else
    echo "  observations.jsonl: 없음"
  fi

  if [ -d "$CLAUDE_DIR/memory/skill-usage" ]; then
    FILES=$(ls "$CLAUDE_DIR/memory/skill-usage"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')
    echo "  skill-usage: ${FILES}개 월별 파일"
  else
    echo "  skill-usage: 없음"
  fi

  echo ""

  # Remote data
  echo "[원격 데이터 ($SYNC_DIR)]"
  if [ -d "$SYNC_DIR" ]; then
    if [ -f "$SYNC_DIR/metrics/sessions.jsonl" ]; then
      LINES=$(wc -l < "$SYNC_DIR/metrics/sessions.jsonl" | tr -d ' ')
      echo "  sessions.jsonl: ${LINES}건"
    fi
    if [ -f "$SYNC_DIR/homunculus/observations.jsonl" ]; then
      LINES=$(wc -l < "$SYNC_DIR/homunculus/observations.jsonl" | tr -d ' ')
      echo "  observations.jsonl: ${LINES}건"
    fi
  else
    echo "  (동기화 이력 없음)"
  fi
}

case "$CMD" in
  push) sync_push ;;
  pull) sync_pull ;;
  status) sync_status ;;
  *) echo "Usage: $0 {push|pull|status}"; exit 1 ;;
esac
