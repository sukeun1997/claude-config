#!/usr/bin/env bash
# agent-usage-tracker.sh — PostToolUse Hook
# Agent 도구 사용을 월별 JSONL로 기록
# skill-usage-tracker.sh가 Skill 도구를 추적하는 것과 보완 관계

set -euo pipefail

TOOL_NAME="${TOOL_NAME:-}"

# Agent 도구에서만 동작
[ "$TOOL_NAME" != "Agent" ] && exit 0

TOOL_INPUT="${TOOL_INPUT:-}"

# subagent_type과 model, description 추출
IFS=$'\t' read -r AGENT_TYPE AGENT_MODEL AGENT_DESC <<< "$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    agent_type = data.get('subagent_type', 'general-purpose') or 'general-purpose'
    model = data.get('model', '') or ''
    # description은 prompt 앞 80자 요약
    prompt = data.get('prompt', '') or ''
    desc = prompt[:80].replace('\n', ' ').strip()
    print(agent_type, model, desc, sep='\t')
except:
    print('general-purpose\t\t', end='')
" 2>/dev/null)"

# 저장 디렉토리
METRICS_DIR="$HOME/.claude/memory/metrics"
mkdir -p "$METRICS_DIR"

# 월별 JSONL 파일
MONTH_FILE="$METRICS_DIR/agent-usage-$(date +%Y-%m).jsonl"

# JSONL 한 줄 추가 (env vars로 전달하여 shell injection 방지)
AGENT_TYPE="$AGENT_TYPE" AGENT_MODEL="$AGENT_MODEL" AGENT_DESC="$AGENT_DESC" \
python3 -c "
import json, datetime, os
record = {
    'date': datetime.date.today().isoformat(),
    'time': datetime.datetime.now().strftime('%H:%M'),
    'agent': os.environ.get('AGENT_TYPE', 'general-purpose'),
    'model': os.environ.get('AGENT_MODEL', ''),
    'description': os.environ.get('AGENT_DESC', '')
}
print(json.dumps(record, ensure_ascii=False))
" >> "$MONTH_FILE" 2>/dev/null || true

exit 0
