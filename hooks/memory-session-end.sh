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

# ── Session metrics snapshot ──
METRICS_DIR="$MEM_DIR/metrics"
mkdir -p "$METRICS_DIR"
METRICS_FILE="$METRICS_DIR/sessions.jsonl"
DATE_STR=$(today)
PROJECT=$(detect_project)

# Session ID: prefer $1 (captured inline before async, race-safe) over file read
if [ -n "${1:-}" ] && [ "$1" != "unknown" ]; then
  SESSION_ID="$1"
else
  SESSION_ID_FILE="$MEM_DIR/sessions/.current-session-id"
  if [ -f "$SESSION_ID_FILE" ]; then
    SESSION_ID=$(cat "$SESSION_ID_FILE" 2>/dev/null || echo "unknown")
  else
    SESSION_ID="fallback-${PPID:-unknown}"
  fi
fi
# Session start timestamp: prefer $2 (captured inline, race-safe)
CAPTURED_START_TS="${2:-0}"
TRACK_FILE_PATH="/tmp/claude-edit-tracker-${SESSION_ID}"

# Collect metrics from edit-tracker
TOTAL_EDITS=0
FRICTION_COUNT=0
UNIQUE_FILES=0
if [ -f "$TRACK_FILE_PATH" ]; then
  TOTAL_EDITS=$(wc -l < "$TRACK_FILE_PATH" | tr -d ' ')
  UNIQUE_FILES=$(sort -u "$TRACK_FILE_PATH" | wc -l | tr -d ' ')
  FRICTION_COUNT=$(sort "$TRACK_FILE_PATH" | uniq -c | awk '$1 >= 3' | wc -l | tr -d ' ')
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
TODAY_FILENAME=$(daily_log_filename "$DATE_STR")
TODAY_LOG="$DAILY_DIR/${TODAY_FILENAME}"
LOG_LINES=0
if [ -f "$TODAY_LOG" ]; then
  LOG_LINES=$(grep -cvE '^\s*$|^# Daily Log:' "$TODAY_LOG" 2>/dev/null) || LOG_LINES=0
fi

# Write JSONL metric — skip noise sessions (short + no edits + no log)
# Filter: duration >= 5min AND (edits OR log content). Pure Q&A sessions excluded
if [ "$DURATION_MIN" -ge 5 ] && { [ "$TOTAL_EDITS" -gt 0 ] || [ "${LOG_LINES:-0}" -gt 0 ]; }; then
  echo "{\"date\":\"${DATE_STR}\",\"project\":\"${PROJECT}\",\"duration_min\":${DURATION_MIN},\"total_edits\":${TOTAL_EDITS},\"unique_files\":${UNIQUE_FILES},\"friction_files\":${FRICTION_COUNT},\"log_lines\":${LOG_LINES:-0}}" >> "$METRICS_FILE"
fi

# ── Friction pattern detection ──
# Check edit-tracker temp files for repeated edits (3+ on same file)
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
        echo "| $DATE_STR | ${FNAME} ${COUNT}회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |" >> "$FRICTION_LOG"
      done <<< "$FRICTION_FILES"
    fi
    # Queue for next session start (model will see this)
    echo "$FRICTION_FILES" > "$MEM_DIR/sessions/.friction-queue"
  fi
  rm -f "$TRACK_FILE"
fi

# ── Sync metrics + daily logs to git repo (for remote agent access) ──
MGMT_REPO="$HOME/IdeaProjects/관리"
if [ -d "$MGMT_REPO/.git" ]; then
  SYNC_DIR="$MGMT_REPO/.harness-sync"
  mkdir -p "$SYNC_DIR/metrics" "$SYNC_DIR/daily"

  # Copy metrics
  [ -f "$METRICS_DIR/sessions.jsonl" ] && cp "$METRICS_DIR/sessions.jsonl" "$SYNC_DIR/metrics/"

  # Copy recent daily logs (last 7 days only)
  for log_file in "$DAILY_DIR"/*.md; do
    [ -f "$log_file" ] || continue
    filename=$(basename "$log_file")
    date_only="${filename:0:10}"
    if [[ "$date_only" > "$CUTOFF" ]] 2>/dev/null; then
      cp "$log_file" "$SYNC_DIR/daily/"
    fi
  done

  # Copy failure-log
  [ -f "$MEM_DIR/topics/failure-log.md" ] && cp "$MEM_DIR/topics/failure-log.md" "$SYNC_DIR/"

  # Auto-commit and push (silent, best-effort)
  (
    cd "$MGMT_REPO"
    git add .harness-sync/ 2>/dev/null
    if ! git diff --cached --quiet 2>/dev/null; then
      git commit -m "chore: sync harness metrics [auto]" 2>/dev/null
      git push origin main 2>/dev/null
    fi
  ) &>/dev/null || true
fi

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

exit 0
