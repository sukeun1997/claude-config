#!/usr/bin/env bash
# skill-usage-tracker.sh — PostToolUse Hook
# Skill 도구 사용을 월별 JSONL로 기록
# memory-post-tool.py가 Write/Edit/Bash/Task를 추적하는 것과 보완 관계

set -euo pipefail

TOOL_NAME="${TOOL_NAME:-}"

# Skill 도구에서만 동작
[ "$TOOL_NAME" != "Skill" ] && exit 0

TOOL_INPUT="${TOOL_INPUT:-}"

# 스킬명 추출
SKILL_NAME=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # skill_name 또는 name 필드에서 추출
    name = data.get('skill', data.get('skill_name', data.get('name', data.get('skillName', ''))))
    print(name)
except:
    print('')
" 2>/dev/null)

[ -z "$SKILL_NAME" ] && exit 0

# 저장 디렉토리
USAGE_DIR="$HOME/.claude/memory/skill-usage"
mkdir -p "$USAGE_DIR"

# 월별 JSONL 파일
MONTH_FILE="$USAGE_DIR/$(date +%Y-%m).jsonl"

# 프로젝트 디렉토리에서 프로젝트명 추출
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# JSONL 한 줄 추가 (env vars로 전달하여 shell injection 방지)
SKILL_NAME="$SKILL_NAME" PROJECT_NAME="$PROJECT_NAME" PROJECT_DIR="$PROJECT_DIR" \
python3 -c "
import json, datetime, os
record = {
    'timestamp': datetime.datetime.now().isoformat(),
    'skill': os.environ.get('SKILL_NAME', ''),
    'project': os.environ.get('PROJECT_NAME', ''),
    'project_dir': os.environ.get('PROJECT_DIR', '')
}
print(json.dumps(record))
" >> "$MONTH_FILE" 2>/dev/null || true

exit 0
