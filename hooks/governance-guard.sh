#!/usr/bin/env bash
# governance-guard.sh — PostToolUse Hook
# 파일 변경 시 governance.yml 규칙과 매칭하여 경고 출력
# 차단하지 않음 (exit 0), stderr로 경고만 출력

set -euo pipefail

# PostToolUse에서 전달되는 환경변수
TOOL_NAME="${TOOL_NAME:-}"
TOOL_INPUT="${TOOL_INPUT:-}"

# Write/Edit 도구에서만 동작
case "$TOOL_NAME" in
  Write|Edit|NotebookEdit) ;;
  *) exit 0 ;;
esac

# 변경된 파일 경로 추출
FILE_PATH=$(echo "$TOOL_INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('file_path', ''))
except:
    print('')
" 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

# 프로젝트 디렉토리의 governance.yml 찾기
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
GOVERNANCE_FILE="$PROJECT_DIR/.claude/governance.yml"

[ ! -f "$GOVERNANCE_FILE" ] && exit 0

# 파일명만 추출
BASENAME=$(basename "$FILE_PATH")
RELPATH="${FILE_PATH#$PROJECT_DIR/}"

# governance.yml 파싱 및 패턴 매칭
python3 -c "
import sys, os, fnmatch

governance_file = '$GOVERNANCE_FILE'
relpath = '$RELPATH'
basename = os.path.basename(relpath)

try:
    import yaml
    with open(governance_file) as f:
        config = yaml.safe_load(f)
except ImportError:
    # PyYAML 없으면 간단한 파싱
    import re
    config = {'rules': []}
    with open(governance_file) as f:
        content = f.read()
    # 간단한 YAML 파싱 (pattern, message, recommend, severity)
    current_rule = {}
    for line in content.split('\n'):
        line = line.strip()
        if line.startswith('- pattern:'):
            if current_rule:
                config['rules'].append(current_rule)
            current_rule = {'pattern': line.split(':', 1)[1].strip().strip('\"').strip(\"'\")}
        elif line.startswith('message:') and current_rule:
            current_rule['message'] = line.split(':', 1)[1].strip().strip('\"').strip(\"'\")
        elif line.startswith('recommend:') and current_rule:
            current_rule['recommend'] = line.split(':', 1)[1].strip().strip('\"').strip(\"'\")
        elif line.startswith('severity:') and current_rule:
            current_rule['severity'] = line.split(':', 1)[1].strip().strip('\"').strip(\"'\")
    if current_rule:
        config['rules'].append(current_rule)

if not config or 'rules' not in config:
    sys.exit(0)

matched = []
for rule in config['rules']:
    pattern = rule.get('pattern', '')
    # fnmatch으로 basename과 relpath 모두 매칭
    if fnmatch.fnmatch(basename, pattern) or fnmatch.fnmatch(relpath, pattern):
        matched.append(rule)

if matched:
    print()
    print('[Governance] 변경 감지:')
    for rule in matched:
        severity = rule.get('severity', 'warn').upper()
        message = rule.get('message', '파일 변경 감지')
        recommend = rule.get('recommend', '')
        print(f'  [{severity}] {message}: {relpath}')
        if recommend:
            print(f'  -> 추천: {recommend}')
    print()
" 2>/dev/null || true

exit 0
