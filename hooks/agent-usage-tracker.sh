#!/usr/bin/env bash
# agent-usage-tracker.sh — PostToolUse Hook
# Agent 도구 사용을 월별 JSONL로 기록
# skill-usage-tracker.sh가 Skill 도구를 추적하는 것과 보완 관계

set -euo pipefail

TOOL_NAME="${TOOL_NAME:-}"

# Agent 도구에서만 동작
[ "$TOOL_NAME" != "Agent" ] && exit 0

TOOL_INPUT="${TOOL_INPUT:-}"
METRICS_DIR="$HOME/.claude/memory/metrics"
mkdir -p "$METRICS_DIR"

MONTH_FILE="$METRICS_DIR/agent-usage-$(date +%Y-%m).jsonl"

# Python 단일 블록으로 파싱+기록 (bash read의 IFS 문제 회피)
echo "$TOOL_INPUT" | python3 -c "
import sys, json, datetime, pathlib

month_file = '$MONTH_FILE'
try:
    data = json.load(sys.stdin)
except:
    data = {}

record = {
    'date': datetime.date.today().isoformat(),
    'time': datetime.datetime.now().strftime('%H:%M'),
    'agent': data.get('subagent_type', 'general-purpose') or 'general-purpose',
    'model': data.get('model', '') or '',
    'description': (data.get('description', '') or data.get('prompt', '') or '')[:80].replace('\n', ' ').strip()
}

with open(month_file, 'a') as f:
    f.write(json.dumps(record, ensure_ascii=False) + '\n')
" 2>/dev/null || true

exit 0
