#!/bin/bash
# pre-clear-handoff.sh — /clear 인터셉트 → HANDOFF.md 자동 저장

source "$HOME/.claude/hooks/memory-lib.sh" 2>/dev/null || true

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('prompt', '').strip())
except:
    pass
" 2>/dev/null || echo "")

# /clear 명령이 아니면 통과
if ! echo "$PROMPT" | grep -qE '^\s*/clear\s*$'; then
  exit 0
fi

# /clear 시 context-cost-monitor 카운터 리셋
rm -f "$HOME/.claude/cache"/msg-count-*.txt 2>/dev/null

# HANDOFF.md가 최근 90초 내 작성됐으면 두 번째 /clear → 통과
HANDOFF=".claude/HANDOFF.md"
if [ -f "$HANDOFF" ]; then
  LAST_MOD=$(stat -f %m "$HANDOFF" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  DIFF=$((NOW - LAST_MOD))
  if [ "$DIFF" -lt 90 ]; then
    exit 0
  fi
fi

# Detect current branch for active context path hint
ACTIVE_HINT=""
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  CURR_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ -n "$CURR_BRANCH" ]; then
    SLUG=$(branch_slug "$CURR_BRANCH" 2>/dev/null || echo "$CURR_BRANCH" | sed 's|/|--|g' | sed 's|[^a-zA-Z0-9._-]||g')
    ACTIVE_HINT="
2. memory/active/${SLUG}.md (현재 브랜치 작업 컨텍스트):
   ## Why — 왜 이 작업을 하는지
   ## Progress — 체크리스트 (완료/미완료)
   ## Next — 다음 할 일
   ## Open Questions — 미해결 질문"
  fi
fi

# /clear 차단 + HANDOFF 저장 지시
echo "STOP: /clear 실행 전 아래 파일을 작성하세요:

1. .claude/HANDOFF.md (아래 구조 필수):
   ## Status: [IN_PROGRESS | BLOCKED | REVIEW_NEEDED]
   ## Current Task
   - 무엇을 하고 있었는가 (1-2줄)
   ## Completed
   - [x] 완료한 항목
   ## Remaining
   - [ ] 미완료 항목
   ## Key Decisions
   - 결정사항 + 이유 (최대 3개)
   ## Resume Point
   - 다음 세션에서 첫 번째로 할 일 (1줄)
   ## Files Modified
   - 변경된 파일 경로 목록
${ACTIVE_HINT}

작성 완료 후 '저장완료. 이제 /clear 하세요.' 라고 안내하세요."
exit 2
