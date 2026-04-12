#!/usr/bin/env bash
# memory-active-context.sh — Auto-manage branch-specific active context files
#
# Usage:
#   memory-active-context.sh init     — Create skeleton if not exists (SessionStart)
#   memory-active-context.sh update   — Update from git state + daily log (Stop hook)
#
# Active context file: memory/active/{branch-slug}.md
# Contains: Why (purpose), Progress (checklist), Next (next steps), Open Questions

set -euo pipefail
source "$HOME/.claude/hooks/memory-lib.sh"

CMD="${1:-init}"
MEM_DIR=$(get_memory_dir)
ensure_dirs "$MEM_DIR"

# Get current branch
if ! command -v git &>/dev/null || ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ]; then
  exit 0
fi

# Skip main/develop/master except for allowlisted projects
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
ALLOW_MAIN_ACTIVE=false
case "$PROJECT_ROOT" in
  *"391"*|*"팬시"*) ALLOW_MAIN_ACTIVE=true ;;
esac

if [ "$ALLOW_MAIN_ACTIVE" = false ] && { [ "$BRANCH" = "develop" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; }; then
  exit 0
fi

SLUG=$(branch_slug "$BRANCH")
ACTIVE_FILE="$MEM_DIR/active/${SLUG}.md"

# Detect base branch
BASE_BRANCH=""
for candidate in develop main master; do
  if git show-ref --verify --quiet "refs/heads/$candidate" 2>/dev/null || \
     git show-ref --verify --quiet "refs/remotes/origin/$candidate" 2>/dev/null; then
    BASE_BRANCH="$candidate"
    break
  fi
done
BASE_BRANCH="${BASE_BRANCH:-main}"

case "$CMD" in
  init)
    # Only create if file doesn't exist
    if [ -f "$ACTIVE_FILE" ]; then
      exit 0
    fi

    # Gather git context for initial population
    AHEAD_COUNT=$(git rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "0")
    RECENT_COMMITS=$(git log --oneline -5 "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "(no commits yet)")
    DIFF_STAT=$(git diff --stat "${BASE_BRANCH}..HEAD" 2>/dev/null | tail -1 || echo "")

    # Extract purpose from first commit message (more meaningful than branch slug)
    TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' || echo "")
    FIRST_COMMIT_MSG=$(git log --format=%s -1 "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "")
    BRANCH_DESC=$(echo "$BRANCH" | sed 's|^[a-z]*/||' | sed 's|[-_]| |g')
    PURPOSE="${FIRST_COMMIT_MSG:-${BRANCH_DESC}}"

    cat > "$ACTIVE_FILE" << EOF
# Active Context: ${BRANCH}

## Why
${TICKET:+- Ticket: ${TICKET}}
- Branch: \`${BRANCH}\` (${AHEAD_COUNT} commits ahead of ${BASE_BRANCH})
- Purpose: ${PURPOSE}

## Progress
${RECENT_COMMITS}
${DIFF_STAT:+Stats: ${DIFF_STAT}}

## Next
- (수동 갱신 필요 — 다음 작업 단계를 기록하세요)

## Open Questions
- (수동 갱신 필요)

---
*Auto-generated on $(date +%Y-%m-%d\ %H:%M). Update manually or via \`/clear\`.*
EOF
    ;;

  update)
    # Update existing active context with latest git state
    if [ ! -f "$ACTIVE_FILE" ]; then
      # Create if missing
      exec "$0" init
    fi

    AHEAD_COUNT=$(git rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "0")
    RECENT_COMMITS=$(git log --oneline -5 "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "(no commits yet)")
    DIFF_STAT=$(git diff --stat "${BASE_BRANCH}..HEAD" 2>/dev/null | tail -1 || echo "")

    # Read existing file, preserve Why/Next/Open Questions sections, update Progress
    EXISTING=$(cat "$ACTIVE_FILE")

    # Extract user-written sections (Why, Next, Open Questions) — preserve them
    WHY_SECTION=$(echo "$EXISTING" | sed -n '/^## Why/,/^## /{ /^## Why/d; /^## [^W]/d; p; }')
    NEXT_SECTION=$(echo "$EXISTING" | sed -n '/^## Next/,/^## /{ /^## Next/d; /^## [^N]/d; p; }')
    QUESTIONS_SECTION=$(echo "$EXISTING" | sed -n '/^## Open Questions/,/^---/{ /^## Open Questions/d; /^---/d; p; }')

    cat > "$ACTIVE_FILE" << EOF
# Active Context: ${BRANCH}

## Why
${WHY_SECTION}

## Progress
${RECENT_COMMITS}
${DIFF_STAT:+Stats: ${DIFF_STAT}}

## Next
${NEXT_SECTION}

## Open Questions
${QUESTIONS_SECTION}

---
*Last updated: $(date +%Y-%m-%d\ %H:%M)*
EOF
    ;;

  *)
    echo "Usage: $0 {init|update}"
    exit 1
    ;;
esac
