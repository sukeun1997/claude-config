#!/usr/bin/env bash
# memory-session-end.sh — SessionEnd hook (async)
# Archives daily logs older than 14 days to archive/YYYY-MM/ subdirectories.

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

MEM_DIR=$(get_memory_dir)
DAILY_DIR="$MEM_DIR/daily"
ARCHIVE_DIR="$MEM_DIR/archive"

# Skip if no daily directory
[ -d "$DAILY_DIR" ] || exit 0

# Calculate cutoff date (14 days ago)
if date -v-14d +%Y-%m-%d >/dev/null 2>&1; then
  # macOS
  CUTOFF=$(date -v-14d +%Y-%m-%d)
else
  # Linux
  CUTOFF=$(date -d "14 days ago" +%Y-%m-%d)
fi

# Archive old daily logs
ARCHIVED=0
for log_file in "$DAILY_DIR"/*.md; do
  [ -f "$log_file" ] || continue

  filename=$(basename "$log_file")
  # Extract date from filename (YYYY-MM-DD.md or YYYY-MM-DD-{project}.md)
  log_date="${filename%.md}"

  # Validate date format (with optional project suffix)
  if ! echo "$log_date" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
    continue
  fi

  # Extract just the date portion for comparison (first 10 chars: YYYY-MM-DD)
  date_only="${log_date:0:10}"

  # Compare dates (string comparison works for YYYY-MM-DD format)
  if [[ "$date_only" < "$CUTOFF" ]]; then
    # Extract YYYY-MM for archive subdirectory
    archive_month="${date_only:0:7}"
    target_dir="$ARCHIVE_DIR/$archive_month"
    mkdir -p "$target_dir"
    mv "$log_file" "$target_dir/"
    ARCHIVED=$((ARCHIVED + 1))
  fi
done

if [ "$ARCHIVED" -gt 0 ]; then
  echo "Archived $ARCHIVED daily log(s) older than 14 days."
fi

# ── Archive stale active context files (7+ day mtime, untracked only) ──
ACTIVE_DIR="$MEM_DIR/active"
ACTIVE_ARCHIVE_DIR="$ACTIVE_DIR/archive"
if [ -d "$ACTIVE_DIR" ]; then
  STALE_COUNT=0
  mkdir -p "$ACTIVE_ARCHIVE_DIR"
  while IFS= read -r -d '' active_file; do
    [ -f "$active_file" ] || continue
    # Defensive: skip if somehow git-tracked (all should be gitignored)
    REPO_ROOT="$HOME/.claude"
    REL_PATH="${active_file#$REPO_ROOT/}"
    if (cd "$REPO_ROOT" && git ls-files --error-unmatch "$REL_PATH" &>/dev/null); then
      continue
    fi
    mv "$active_file" "$ACTIVE_ARCHIVE_DIR/" && STALE_COUNT=$((STALE_COUNT + 1))
  done < <(find "$ACTIVE_DIR" -maxdepth 1 -type f -name '*.md' -mtime +7 -print0 2>/dev/null)
  if [ "$STALE_COUNT" -gt 0 ]; then
    echo "Archived $STALE_COUNT stale active context file(s) (7+ day mtime)."
  fi
fi

# ── Session metrics snapshot ──
METRICS_DIR="$MEM_DIR/metrics"
mkdir -p "$METRICS_DIR"
METRICS_FILE="$METRICS_DIR/sessions.jsonl"
DATE_STR=$(today)
PROJECT=$(detect_project)

# Session ID: prefer $1 (captured inline before async, race-safe) over file read
# Fallback chain: $1 → .previous-session-id → .current-session-id → PPID
if [ -n "${1:-}" ] && [ "$1" != "unknown" ]; then
  SESSION_ID="$1"
else
  PREVIOUS_ID_FILE="$MEM_DIR/sessions/.previous-session-id"
  SESSION_ID_FILE="$MEM_DIR/sessions/.current-session-id"
  if [ -f "$PREVIOUS_ID_FILE" ]; then
    SESSION_ID=$(cat "$PREVIOUS_ID_FILE" 2>/dev/null || echo "unknown")
  elif [ -f "$SESSION_ID_FILE" ]; then
    SESSION_ID=$(cat "$SESSION_ID_FILE" 2>/dev/null || echo "unknown")
  else
    SESSION_ID="fallback-${PPID:-unknown}"
  fi
fi
# Session start timestamp: prefer $2 (captured inline, race-safe)
CAPTURED_START_TS="${2:-0}"
TRACK_FILE_PATH="/tmp/claude-edit-tracker-${SESSION_ID}"
READ_TRACK_FILE="/tmp/claude-read-tracker-${SESSION_ID}"

# Collect metrics from tool-tracker (primary) or captures fallback
TOTAL_EDITS=0
FRICTION_COUNT=0
UNIQUE_FILES=0
TOTAL_READS=0
if [ -f "$TRACK_FILE_PATH" ]; then
  TOTAL_EDITS=$(wc -l < "$TRACK_FILE_PATH" | tr -d ' ')
  UNIQUE_FILES=$(sort -u "$TRACK_FILE_PATH" | wc -l | tr -d ' ')
  FRICTION_COUNT=$(sort "$TRACK_FILE_PATH" | uniq -c | awk '$1 >= 3' | wc -l | tr -d ' ')
fi
# Fallback: read from captures JSONL if tracker file missing/empty
if [ "$TOTAL_EDITS" -eq 0 ]; then
  CAPTURES_FILE="$MEM_DIR/daily/.captures-${DATE_STR}.jsonl"
  if [ -f "$CAPTURES_FILE" ]; then
    TOTAL_EDITS=$(grep -c '"tool":"Edit\|"tool":"Write' "$CAPTURES_FILE" 2>/dev/null || echo "0")
    TOTAL_EDITS=$(echo "$TOTAL_EDITS" | tr -d '[:space:]')
    TOTAL_EDITS="${TOTAL_EDITS:-0}"
  fi
fi
if [ -f "$READ_TRACK_FILE" ]; then
  TOTAL_READS=$(wc -l < "$READ_TRACK_FILE" | tr -d ' ')
fi

# Session duration estimate (from session marker)
SESSION_MARKER="$MEM_DIR/sessions/.last-session-ts"
DURATION_MIN=0
if [ -f "$SESSION_MARKER" ]; then
  START_TS=$(cat "$SESSION_MARKER" 2>/dev/null || echo "0")
  NOW_TS=$(date +%s)
  DURATION_MIN=$(( (NOW_TS - START_TS) / 60 ))
fi

# Daily log content lines (proxy for productivity)
# Exclude: blank lines, header, [Auto] hook output, Compaction Checkpoint
TODAY_FILENAME=$(daily_log_filename "$DATE_STR")
TODAY_LOG="$DAILY_DIR/${TODAY_FILENAME}"
LOG_LINES=0
if [ -f "$TODAY_LOG" ]; then
  LOG_LINES=$(grep -cvE '^\s*$|^# Daily Log:|^\#\#\# .* - \[Auto\]|^\- \*\*Files\*\*|^\- \*\*Build\*\*|^\- \*\*Test\*\*|^\- \*\*Git\*\*|Compaction Checkpoint|컴팩션|자동 컴팩션|세션 재개 후' "$TODAY_LOG" 2>/dev/null) || LOG_LINES=0
fi

# Write JSONL metric — skip noise sessions
# Filter: (duration >= 5min AND (edits OR log)) OR (edits > 0 regardless of duration)
if { [ "$DURATION_MIN" -ge 5 ] && { [ "$TOTAL_EDITS" -gt 0 ] || [ "${LOG_LINES:-0}" -gt 0 ]; }; } || [ "$TOTAL_EDITS" -gt 0 ]; then
  echo "{\"date\":\"${DATE_STR}\",\"project\":\"${PROJECT}\",\"duration_min\":${DURATION_MIN},\"total_edits\":${TOTAL_EDITS},\"total_reads\":${TOTAL_READS},\"unique_files\":${UNIQUE_FILES},\"friction_files\":${FRICTION_COUNT},\"log_lines\":${LOG_LINES:-0}}" >> "$METRICS_FILE"
fi

# ── Friction pattern detection ──
# Check edit-tracker temp files for repeated edits (3+ on same file)
# Pre-fill 원인 계층(Prompt/Context/Harness) — 경로 + 횟수 휴리스틱
classify_friction() {
  local path="$1" count="$2" layer hint
  if [ "$count" -ge 7 ]; then
    echo "Prompt (추정·${count}회)|접근법 오류 가능성 — 초기화 후 재설계 권장"
    return
  fi
  case "$path" in
    */hooks/*.sh|*/hooks/*.py|*/hooks/*.mjs|*settings.json|*settings.base.json|*governance.yml|*policy-*.json)
      layer="Harness (추정)"; hint="훅/설정 반복 — settings integrity + hook exec path 확인" ;;
    */agents/*.md|*/skills/*/SKILL.md|*/commands/*.md|*CLAUDE.md|*/rules/**/*.md)
      layer="Prompt (추정)"; hint="지시문/스킬 정의 반복 — description/triggers 모호성 점검" ;;
    *.tsx|*.ts|*.jsx|*.js|*.kt|*.java|*.py|*.go|*.rb)
      if [ "$count" -ge 5 ]; then
        layer="Context (추정·강)"; hint="소스 ${count}회+ — 파일 전체 Read 후 재접근 권장"
      else
        layer="Context (추정)"; hint="소스 반복 — 관련 파일/타입 정의 확인 필요"
      fi ;;
    *.css|*.scss|*.yml|*.yaml|*.toml|*.json)
      layer="Context (추정)"; hint="설정/스타일 반복 — 기존 값과 원하는 값 명확화" ;;
    *)
      layer="미분류"; hint="다음 세션에서 원인 분석 필요" ;;
  esac
  echo "${layer}|${hint}"
}

TRACK_FILE="$TRACK_FILE_PATH"
if [ -f "$TRACK_FILE" ]; then
  DATE_STR=$(today)
  # Find files edited 3+ times
  FRICTION_FILES=$(sort "$TRACK_FILE" | uniq -c | sort -rn | awk '$1 >= 3 {print $1, $2}')
  if [ -n "$FRICTION_FILES" ]; then
    FRICTION_LOG="$MEM_DIR/topics/failure-log.md"
    if [ -f "$FRICTION_LOG" ]; then
      while IFS= read -r line; do
        COUNT=$(echo "$line" | awk '{print $1}')
        FPATH=$(echo "$line" | awk '{print $2}')
        FNAME=$(basename "$FPATH")
        CLASS=$(classify_friction "$FPATH" "$COUNT")
        LAYER="${CLASS%%|*}"
        HINT="${CLASS#*|}"
        echo "| $DATE_STR | ${FNAME} ${COUNT}회 반복 편집 | ${LAYER} | ${HINT} |" >> "$FRICTION_LOG"
      done <<< "$FRICTION_FILES"
    fi
    # Queue for next session start (model will see this)
    echo "$FRICTION_FILES" > "$MEM_DIR/sessions/.friction-queue"
  fi
  rm -f "$TRACK_FILE"
fi

# ── Clean up empty daily logs (header-only files) ──
for log_file in "$DAILY_DIR"/*.md; do
  [ -f "$log_file" ] || continue
  # Count non-empty, non-header lines
  real_lines=$(grep -cvE '^\s*$|^# Daily Log:' "$log_file" 2>/dev/null) || real_lines=0
  if [ "$real_lines" -eq 0 ]; then
    rm -f "$log_file"
  fi
done

# (관리 레포 sync 블록 제거 — auto-sync가 claude-config 레포로 직접 push)

# ── Save current session JSONL path for next session's digest ──
PROJ_JSONL_DIR=$(find_project_jsonl_dir)
if [ -n "$PROJ_JSONL_DIR" ]; then
  # Most recently modified JSONL = current session (actively being written)
  CURRENT_JSONL=$(ls -t "$PROJ_JSONL_DIR"/*.jsonl 2>/dev/null | head -1)
  if [ -n "$CURRENT_JSONL" ] && [ -f "$CURRENT_JSONL" ]; then
    echo "$CURRENT_JSONL" > "$MEM_DIR/sessions/.last-session-jsonl"
  fi
fi

# Clean up session marker — only if it still belongs to our session (race-safe)
SESSION_MARKER="$MEM_DIR/sessions/.last-session-ts"
if [ -f "$SESSION_MARKER" ]; then
  CURRENT_TS=$(cat "$SESSION_MARKER" 2>/dev/null || echo "0")
  if [ "$CURRENT_TS" = "$CAPTURED_START_TS" ] || [ "$CAPTURED_START_TS" = "0" ]; then
    rm -f "$SESSION_MARKER" 2>/dev/null || true
  fi
fi

# ── Auto-sync: commit + push tracked changes (allowlist) ──
(
  cd "$HOME/.claude"
  git add hooks/ skills/ rules/ scripts/ agents/ commands/ docs/ \
    memory/MEMORY.md memory/topics/ memory/metrics/ memory/skill-usage/ \
    settings.base.json CLAUDE.md .gitignore sync-data/ 2>/dev/null
  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "chore: auto-sync [$(hostname -s)] $(date +%Y-%m-%d)" 2>/dev/null
    git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=5 push origin main 2>/dev/null || true
  fi
) &>/dev/null || true

exit 0
