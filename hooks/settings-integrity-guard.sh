#!/bin/bash
# settings-integrity-guard.sh — settings.json의 hooks 섹션 무결성 검증
# UserPromptSubmit hook에서 실행. hooks 누락 시 sync-settings.sh 자동 실행.
# 결정적 출력: 정상 시 stdout 없음, 비정상 시 stderr로 경고 + 자동 복구.

DIR="$HOME/.claude"
SETTINGS="$DIR/settings.json"
BASE="$DIR/settings.base.json"
SYNC="$DIR/scripts/sync-settings.sh"

# settings.json이 없으면 sync 실행
if [ ! -f "$SETTINGS" ]; then
  bash "$SYNC" >/dev/null 2>&1
  echo "settings.json missing — recreated via sync" >&2
  exit 0
fi

# hooks 섹션 존재 여부를 빠르게 검증 (python3 없이 grep으로)
if ! grep -q '"hooks"' "$SETTINGS" 2>/dev/null; then
  # hooks 섹션이 없음 — 자동 복구
  bash "$SYNC" >/dev/null 2>&1
  echo "hooks missing from settings.json — auto-restored via sync-settings.sh" >&2
  exit 0
fi

# hooks 섹션이 있지만 비어있는지 확인 (최소 1개 이벤트 타입 필요)
HOOK_COUNT=$(python3 -c "
import json, sys
try:
    d = json.load(open('$SETTINGS'))
    h = d.get('hooks', {})
    if not isinstance(h, dict):
        print(0)
    else:
        print(len(h))
except:
    print(-1)
" 2>/dev/null)

if [ "${HOOK_COUNT:-0}" -lt 3 ]; then
  bash "$SYNC" >/dev/null 2>&1
  echo "hooks section incomplete (${HOOK_COUNT} events) — auto-restored via sync" >&2
  exit 0
fi

# 정상 — 출력 없음 (결정적 출력 원칙)
exit 0
