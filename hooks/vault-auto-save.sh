#!/usr/bin/env bash
# vault-auto-save.sh — PostToolUse Hook
# superpowers가 생성한 spec/plan 파일을 ~/vault/{project}/{branch}/ 에 자동 복사
# 비매칭 시 아무 동작 안 함 (exit 0)

set -euo pipefail

TOOL_NAME="${TOOL_NAME:-}"
TOOL_INPUT="${TOOL_INPUT:-}"

# Write/Edit 도구에서만 동작
case "$TOOL_NAME" in
  Write|Edit) ;;
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

# 패턴 매칭: superpowers가 생성하는 spec/plan 파일만 대상
VAULT_TYPE=""
case "$FILE_PATH" in
  */docs/superpowers/specs/*-design.md)
    VAULT_TYPE="spec"
    ;;
  */docs/superpowers/plans/*.md)
    VAULT_TYPE="plan"
    ;;
  *)
    exit 0
    ;;
esac

# 파일이 실제 존재하는지 확인
[ ! -f "$FILE_PATH" ] && exit 0

# 프로젝트 감지 (memory-lib.sh 재사용)
source "$HOME/.claude/hooks/memory-lib.sh" 2>/dev/null || true
PROJECT=$(detect_project 2>/dev/null || echo "global")

# 브랜치 감지
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# 브랜치 슬러그 결정
case "$BRANCH" in
  main|master|develop)
    DEST_DIR="$HOME/vault/${PROJECT}"
    ;;
  *)
    BRANCH_SLUG=$(echo "$BRANCH" | sed 's|/|--|g')
    DEST_DIR="$HOME/vault/${PROJECT}/${BRANCH_SLUG}"
    ;;
esac

# 디렉토리 생성
mkdir -p "$DEST_DIR"

# 원본에서 제목 추출
TITLE=$(grep -m1 '^# ' "$FILE_PATH" | sed 's/^# //' || echo "Untitled")
TODAY=$(date +%Y-%m-%d)

# 같은 이름 파일이 이미 있으면 topic suffix 추가
DEST_FILE="${DEST_DIR}/${VAULT_TYPE}.md"
if [ -f "$DEST_FILE" ]; then
  # 원본 파일에서 topic slug 추출 (첫 헤딩의 2-3단어)
  TOPIC_SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | cut -d'-' -f1-3 | sed 's/[^a-z0-9-]//g')
  DEST_FILE="${DEST_DIR}/${VAULT_TYPE}-${TOPIC_SLUG}.md"
fi

# frontmatter 주입 + 복사 (환경변수로 전달하여 injection 방지)
SRC="$FILE_PATH" DST="$DEST_FILE" TITLE="$TITLE" \
  VAULT_TYPE="$VAULT_TYPE" PROJECT="$PROJECT" \
  BRANCH="$BRANCH" TODAY="$TODAY" \
  python3 << 'PYEOF'
import os

src = os.environ['SRC']
dst = os.environ['DST']
title = os.environ['TITLE']
vault_type = os.environ['VAULT_TYPE']
project = os.environ['PROJECT']
branch = os.environ['BRANCH']
today = os.environ['TODAY']

with open(src, 'r') as f:
    content = f.read()

# 기존 frontmatter 제거
if content.startswith('---'):
    parts = content.split('---', 2)
    if len(parts) >= 3:
        content = parts[2].lstrip('\n')

# 새 frontmatter 생성
frontmatter = f"""---
title: "{title}"
type: {vault_type}
project: {project}
branch: {branch}
created: {today}
status: active
---

"""

with open(dst, 'w') as f:
    f.write(frontmatter + content)
PYEOF

# 성공 메시지 (stderr → Claude에 피드백)
echo "[vault] Saved: ${DEST_FILE/#$HOME/~}" >&2

exit 0
