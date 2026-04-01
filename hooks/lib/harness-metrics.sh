#!/usr/bin/env bash
# harness-metrics.sh — Analyze session metrics for harness health
# Called by review-week skill or directly: bash ~/.claude/hooks/lib/harness-metrics.sh [days]

set -euo pipefail

METRICS_FILE="$HOME/.claude/memory/metrics/sessions.jsonl"
DAYS="${1:-7}"

if [ ! -f "$METRICS_FILE" ]; then
  echo "No session metrics found yet. Metrics will accumulate after sessions with the updated hooks."
  exit 0
fi

# Calculate cutoff date
if date -v-${DAYS}d +%Y-%m-%d >/dev/null 2>&1; then
  CUTOFF=$(date -v-${DAYS}d +%Y-%m-%d)
else
  CUTOFF=$(date -d "${DAYS} days ago" +%Y-%m-%d)
fi

# Filter recent sessions
RECENT=$(awk -F'"date":"' '{split($2,a,"\""); if(a[1] >= "'"$CUTOFF"'") print}' "$METRICS_FILE")

if [ -z "$RECENT" ]; then
  echo "No sessions in the last ${DAYS} days."
  exit 0
fi

TOTAL_SESSIONS=$(echo "$RECENT" | wc -l | tr -d ' ')
TOTAL_FRICTION=$(echo "$RECENT" | grep -o '"friction_files":[0-9]*' | awk -F: '{s+=$2} END {print s+0}')
TOTAL_EDITS=$(echo "$RECENT" | grep -o '"total_edits":[0-9]*' | awk -F: '{s+=$2} END {print s+0}')
TOTAL_DURATION=$(echo "$RECENT" | grep -o '"duration_min":[0-9]*' | awk -F: '{s+=$2} END {print s+0}')
AVG_DURATION=$((TOTAL_DURATION / TOTAL_SESSIONS))

# Friction rate
if [ "$TOTAL_SESSIONS" -gt 0 ]; then
  FRICTION_SESSIONS=$(echo "$RECENT" | grep -c '"friction_files":[1-9]' 2>/dev/null || true)
  FRICTION_SESSIONS="${FRICTION_SESSIONS:-0}"
  FRICTION_SESSIONS=$(echo "$FRICTION_SESSIONS" | tr -d '[:space:]')
  FRICTION_RATE=$((FRICTION_SESSIONS * 100 / TOTAL_SESSIONS))
else
  FRICTION_SESSIONS=0
  FRICTION_RATE=0
fi

cat <<EOF
## Harness Health Report (last ${DAYS} days)

| Metric | Value |
|--------|-------|
| Sessions | ${TOTAL_SESSIONS} |
| Total edits | ${TOTAL_EDITS} |
| Avg duration | ${AVG_DURATION}min |
| Friction sessions | ${FRICTION_SESSIONS:-0} / ${TOTAL_SESSIONS} (${FRICTION_RATE}%) |
| Total friction files | ${TOTAL_FRICTION} |

### Friction Trend
EOF

# Per-day friction breakdown
echo "$RECENT" | grep -o '"date":"[^"]*".*"friction_files":[0-9]*' | \
  sed 's/.*"date":"\([^"]*\)".*"friction_files":\([0-9]*\).*/\1 \2/' | \
  sort | while read -r day count; do
    bar=""
    for ((i=0; i<count; i++)); do bar+="█"; done
    [ -z "$bar" ] && bar="·"
    echo "  $day $bar ($count)"
  done

# Project breakdown
echo ""
echo "### By Project"
echo "$RECENT" | grep -o '"project":"[^"]*"' | sort | uniq -c | sort -rn | \
  while read -r cnt proj; do
    proj_name=$(echo "$proj" | sed 's/"project":"//;s/"//')
    echo "  - ${proj_name}: ${cnt} sessions"
  done
