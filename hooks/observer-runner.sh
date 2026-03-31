#!/usr/bin/env bash
# observer-runner.sh — Analyze accumulated observations and generate/update instincts
# Hook: SessionEnd (async, runs after memory-session-end.sh)
# Reads observations.jsonl, detects patterns, creates/updates instinct files

set -euo pipefail

HOMUNCULUS_DIR="$HOME/.claude/homunculus"
OBS_FILE="$HOMUNCULUS_DIR/observations.jsonl"
CURSOR_FILE="$HOMUNCULUS_DIR/.observer-cursor"
INSTINCTS_DIR="$HOMUNCULUS_DIR/instincts/personal"
MIN_NEW_OBS=20  # Minimum new observations before triggering analysis

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

# Parse new observations for frequent tool patterns
tail -n +"$((CURSOR + 1))" "$OBS_FILE" | \
  python3 -c "
import sys, json
from collections import Counter

patterns = Counter()
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obs = json.loads(line)
        tool = obs.get('tool', '')
        # Track tool usage patterns
        if tool in ('Bash', 'Edit', 'Write', 'Read', 'Grep', 'Glob'):
            patterns[f'tool:{tool}'] += 1
        # Track skill usage
        if tool == 'Skill':
            skill = obs.get('args', {}).get('skill', 'unknown')
            patterns[f'skill:{skill}'] += 1
        # Track agent delegation
        if tool == 'Agent':
            agent_type = obs.get('args', {}).get('subagent_type', 'general')
            patterns[f'agent:{agent_type}'] += 1
    except (json.JSONDecodeError, KeyError):
        continue

# Output patterns with count >= 3
for pattern, count in patterns.most_common(20):
    if count >= 3:
        print(f'{pattern}\t{count}')
" > "$PATTERNS_FILE" 2>/dev/null || true

# Update instinct confidence for matching patterns
while IFS=$'\t' read -r pattern count; do
  category="${pattern%%:*}"
  name="${pattern#*:}"

  # Find matching instinct
  for instinct_file in "$INSTINCTS_DIR"/*.md; do
    [ -f "$instinct_file" ] || continue
    # Check if instinct mentions this pattern
    if grep -qi "$name" "$instinct_file" 2>/dev/null; then
      # Bump confidence by 0.05 (cap at 0.95)
      current=$(grep -oP 'confidence:\s*\K[0-9.]+' "$instinct_file" 2>/dev/null || echo "0.5")
      new_conf=$(python3 -c "print(min(0.95, $current + 0.05))" 2>/dev/null || echo "$current")
      if [ "$new_conf" != "$current" ]; then
        # macOS sed compatibility
        sed -i '' "s/confidence: $current/confidence: $new_conf/" "$instinct_file" 2>/dev/null || \
        sed -i "s/confidence: $current/confidence: $new_conf/" "$instinct_file" 2>/dev/null || true
      fi
    fi
  done
done < "$PATTERNS_FILE"

# Update cursor
echo "$TOTAL_LINES" > "$CURSOR_FILE"

# Run instinct evolution check
EVOLVE_SCRIPT="$HOME/.claude/hooks/instinct-evolve.sh"
if [ -f "$EVOLVE_SCRIPT" ] && [ -x "$EVOLVE_SCRIPT" ]; then
  bash "$EVOLVE_SCRIPT" 2>/dev/null || true
fi

exit 0
