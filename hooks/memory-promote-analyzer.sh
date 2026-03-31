#!/usr/bin/env bash
# memory-promote-analyzer.sh — Auto-promote [PROMOTE] items from daily logs to MEMORY.md
# Hook: SessionStart (runs after memory-session-start.sh)
# Reads daily/*.md, extracts [PROMOTE] items, appends to MEMORY.md, marks as [PROMOTED]

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

# Resolve project memory directory
MEM_DIR=$(get_memory_dir "${CLAUDE_PROJECT_DIR:-$PWD}")
DAILY_DIR="$MEM_DIR/daily"
MEMORY_FILE="$MEM_DIR/MEMORY.md"

# Exit early if no daily directory
[ -d "$DAILY_DIR" ] || exit 0

# Create MEMORY.md skeleton if missing
if [ ! -f "$MEMORY_FILE" ]; then
  cat > "$MEMORY_FILE" << 'SKELETON'
# Project Memory

## Decisions & Patterns
<!-- Auto-populated from [PROMOTE] items in daily logs -->

---
*Auto-maintained by memory-promote-analyzer.sh*
SKELETON
fi

# Collect all [PROMOTE] items from daily logs (not already [PROMOTED])
PROMOTE_ITEMS=()
PROMOTE_FILES=()

for daily_file in "$DAILY_DIR"/*.md; do
  [ -f "$daily_file" ] || continue
  filename=$(basename "$daily_file" .md)

  while IFS= read -r line; do
    # Normalize: extract content after [PROMOTE] marker
    content=""
    if [[ "$line" =~ ^-\ \[PROMOTE\]\ (.+)$ ]]; then
      content="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\[PROMOTE\]\ -\ (.+)$ ]]; then
      content="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\[PROMOTE\]\ (.+)$ ]]; then
      content="${BASH_REMATCH[1]}"
    elif [[ "$line" == "[PROMOTE]" ]]; then
      # Standalone [PROMOTE] tag — skip (no content)
      continue
    else
      continue
    fi

    # Skip if already in MEMORY.md (simple substring match)
    if grep -qF "$content" "$MEMORY_FILE" 2>/dev/null; then
      continue
    fi

    PROMOTE_ITEMS+=("$content")
    PROMOTE_FILES+=("$daily_file")
  done < "$daily_file"
done

# Exit if nothing to promote
if [ ${#PROMOTE_ITEMS[@]} -eq 0 ]; then
  exit 0
fi

# Append promoted items to MEMORY.md (before the footer line)
{
  echo ""
  echo "### Promoted $(today)"
  for item in "${PROMOTE_ITEMS[@]}"; do
    echo "- $item"
  done
} >> "$MEMORY_FILE"

# Mark promoted items in daily logs: [PROMOTE] → [PROMOTED]
for file in $(printf '%s\n' "${PROMOTE_FILES[@]}" | sort -u); do
  # Only replace [PROMOTE] (not [PROMOTED]) — idempotent
  sed -i '' 's/\[PROMOTE\]/[PROMOTED]/g' "$file" 2>/dev/null || \
  sed -i 's/\[PROMOTE\]/[PROMOTED]/g' "$file" 2>/dev/null || true
done

# Check MEMORY.md size
LINE_COUNT=$(wc -l < "$MEMORY_FILE" | tr -d ' ')
PROMOTED_COUNT=${#PROMOTE_ITEMS[@]}

# Output status (captured by Claude Code as SessionStart context)
echo "${PROMOTED_COUNT} item(s) promoted to MEMORY.md"
if [ "$LINE_COUNT" -gt 150 ]; then
  echo "WARNING: MEMORY.md is ${LINE_COUNT} lines (limit: 150). Consider archiving older items."
fi

exit 0
