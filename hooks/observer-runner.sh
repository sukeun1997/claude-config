#!/usr/bin/env bash
# observer-runner.sh — Analyze accumulated observations and generate/update instincts
# Hook: SessionEnd (async, runs after memory-session-end.sh)
# Reads observations.jsonl, detects patterns, creates/updates instinct files

set -euo pipefail

HOMUNCULUS_DIR="$HOME/.claude/homunculus"
OBS_FILE="$HOMUNCULUS_DIR/observations.jsonl"
CURSOR_FILE="$HOMUNCULUS_DIR/.observer-cursor"
INSTINCTS_DIR="$HOMUNCULUS_DIR/instincts/personal"
MIN_NEW_OBS=10  # Minimum new observations before triggering analysis (lowered from 20 for faster evolution)

# Exit early if no observations file
[ -f "$OBS_FILE" ] || exit 0
mkdir -p "$INSTINCTS_DIR"

# Get current observation count
TOTAL_LINES=$(wc -l < "$OBS_FILE" | tr -d ' ')

# Read cursor (last processed line number)
CURSOR=0
if [ -f "$CURSOR_FILE" ]; then
  CURSOR=$(cat "$CURSOR_FILE" | tr -d ' ')
fi

# Check if enough new observations
NEW_OBS=$((TOTAL_LINES - CURSOR))
if [ "$NEW_OBS" -lt "$MIN_NEW_OBS" ]; then
  exit 0
fi

# Extract patterns from new observations
# Focus on tool usage patterns: repeated tool+arg combinations
PATTERNS_FILE=$(mktemp)
trap "rm -f '$PATTERNS_FILE'" EXIT

# Extract patterns from new observations using analyzer
ANALYZER="$HOME/.claude/hooks/observer-analyzer.py"
if [ ! -f "$ANALYZER" ]; then
  echo "observer-analyzer.py not found" >&2
  exit 1
fi

tail -n +"$((CURSOR + 1))" "$OBS_FILE" | \
  python3 "$ANALYZER" > "$PATTERNS_FILE" 2>/dev/null || true

# Concurrency lock (mkdir-based, macOS compatible)
LOCK_DIR="$HOMUNCULUS_DIR/.observer-runner.lock"
mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap "rmdir '$LOCK_DIR' 2>/dev/null; rm -f '$PATTERNS_FILE'" EXIT

# Update instinct confidence OR create new instincts from analyzer output
# TSV format: type\tname\tcount\tdomain\tdescription\ttrigger\taction\tproject
while IFS=$'\t' read -r ptype pname pcount pdomain pdesc ptrigger paction pproject; do
  # Skip empty lines
  [ -z "$pname" ] && continue

  # Skip low-count patterns
  [ "$pcount" -lt 2 ] 2>/dev/null && continue

  # Find matching instinct by name
  MATCHED=false
  for instinct_file in "$INSTINCTS_DIR"/*.md; do
    [ -f "$instinct_file" ] || continue
    if grep -Fq "name: $pname" "$instinct_file" 2>/dev/null; then
      MATCHED=true
      # Bump confidence — scaled by observed count (log2), cap at 0.95
      current=$(sed -n 's/^confidence: *\([0-9.]*\).*/\1/p' "$instinct_file" 2>/dev/null | head -1)
      current="${current:-0.5}"
      new_conf=$(python3 -c "import math; bump=min(0.15, 0.03+0.02*math.log2(max(1,$pcount))); print(round(min(0.95, $current+bump), 2))" 2>/dev/null || echo "$current")
      if [ "$new_conf" != "$current" ]; then
        escaped_current=$(echo "$current" | sed 's/\./\\./g')
        sed -i '' "s/^confidence: ${escaped_current}$/confidence: ${new_conf}/" "$instinct_file" 2>/dev/null || \
        sed -i "s/^confidence: ${escaped_current}$/confidence: ${new_conf}/" "$instinct_file" 2>/dev/null || true
      fi
      # Update observed_count
      sed -i '' "s/^observed_count: .*/observed_count: ${pcount}/" "$instinct_file" 2>/dev/null || \
      sed -i "s/^observed_count: .*/observed_count: ${pcount}/" "$instinct_file" 2>/dev/null || true
      break
    fi
  done

  # Create new instinct if no match and count >= 3
  if [ "$MATCHED" = false ] && [ "$pcount" -ge 3 ] 2>/dev/null; then
    SAFE_NAME=$(echo "$pname" | sed 's/[^a-zA-Z0-9_-]/_/g' | head -c 60)
    INSTINCT_FILE="$INSTINCTS_DIR/${SAFE_NAME}.md"
    if [ ! -f "$INSTINCT_FILE" ]; then
      # Initial confidence: 0.3 base + 0.02 per count above 3, cap at 0.55
      INIT_CONF=$(python3 -c "print(round(min(0.55, 0.3 + ($pcount - 3) * 0.02), 2))" 2>/dev/null || echo "0.35")
      cat > "$INSTINCT_FILE" << INSTEOF
---
name: ${pname}
description: "${pdesc}"
domain: "${pdomain}"
confidence: ${INIT_CONF}
source: observer-analyzer.py
observed_count: ${pcount}
created: $(date +%Y-%m-%d)
trigger: "${ptrigger}"
action: "${paction}"
projects: "${pproject}"
---

## Pattern
- **Type**: ${ptype}
- **Name**: ${pname}
- **Count**: ${pcount}
- **Projects**: ${pproject}
INSTEOF
    fi
  fi
done < "$PATTERNS_FILE"

# Update cursor
echo "$TOTAL_LINES" > "$CURSOR_FILE"

# Apply failure-log human-verified boosts (runs regardless of volume)
BOOST_SCRIPT="$HOME/.claude/hooks/failure-log-instinct-boost.py"
if [ -f "$BOOST_SCRIPT" ]; then
  python3 "$BOOST_SCRIPT" 2>/dev/null || true
fi

# Run instinct evolution check
EVOLVE_SCRIPT="$HOME/.claude/hooks/instinct-evolve.sh"
if [ -f "$EVOLVE_SCRIPT" ] && [ -x "$EVOLVE_SCRIPT" ]; then
  bash "$EVOLVE_SCRIPT" 2>/dev/null || true
fi

exit 0
