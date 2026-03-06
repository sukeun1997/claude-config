#!/bin/bash
# pre-clear-handoff.sh — /clear 인터셉트 → HANDOFF.md 자동 저장

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

# /clear 차단 + HANDOFF 저장 지시
echo "STOP: /clear 실행 전 .claude/HANDOFF.md를 지금 즉시 작성하세요 (Bash 도구로 직접 파일 생성):
- 현재 진행 중인 작업
- 미완료 사항 및 다음 할 일
- 핵심 결정 사항
- 다음 세션 시작 포인트
작성 완료 후 '저장완료. 이제 /clear 하세요.' 라고 안내하세요."
exit 2
