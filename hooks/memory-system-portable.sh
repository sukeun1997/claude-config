#!/usr/bin/env bash
# memory-system-portable.sh — Memory Search System 이식 자동화
#
# Usage:
#   ./memory-system-portable.sh export              # 현재 머신에서 아카이브 생성
#   ./memory-system-portable.sh import <archive>    # 새 머신에서 설치
#   ./memory-system-portable.sh verify              # 설치 검증
#
# Export 결과: ~/claude-memory-system.tar.gz (스크립트 + 규칙 + hooks 설정)
# 데이터(Daily Log, MEMORY.md)는 프로젝트별이므로 포함하지 않음

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks"
RULES_DIR="$CLAUDE_DIR/rules/common"
SETTINGS="$CLAUDE_DIR/settings.json"
ARCHIVE_NAME="claude-memory-system.tar.gz"
ARCHIVE_PATH="$HOME/$ARCHIVE_NAME"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

# ─────────────────────────────────────────────────
# EXPORT: 현재 머신에서 아카이브 생성
# ─────────────────────────────────────────────────
cmd_export() {
    info "Memory System Export 시작..."

    local tmpdir
    tmpdir=$(mktemp -d)
    local staging="$tmpdir/claude-memory-system"
    mkdir -p "$staging/hooks" "$staging/rules" "$staging/config"

    # 1. Hook 스크립트 복사
    local hook_files=(
        "memory-lib.sh"
        "memory-search.py"
        "memory-session-start.sh"
        "memory-session-end.sh"
    )
    local copied=0
    for f in "${hook_files[@]}"; do
        if [ -f "$HOOKS_DIR/$f" ]; then
            cp "$HOOKS_DIR/$f" "$staging/hooks/"
            ok "hooks/$f"
            copied=$((copied + 1))
        else
            fail "hooks/$f 없음 — 건너뜀"
        fi
    done

    if [ "$copied" -eq 0 ]; then
        fail "복사할 hook 스크립트가 없습니다. ~/.claude/hooks/ 경로를 확인하세요."
        rm -rf "$tmpdir"
        exit 1
    fi

    # 2. 규칙 파일 복사
    if [ -f "$RULES_DIR/memory.md" ]; then
        cp "$RULES_DIR/memory.md" "$staging/rules/"
        ok "rules/common/memory.md"
    else
        warn "rules/common/memory.md 없음 — 건너뜀 (선택 사항)"
    fi

    # 3. settings.json에서 hooks 섹션만 추출
    if [ -f "$SETTINGS" ] && command -v python3 &>/dev/null; then
        SETTINGS_PATH="$SETTINGS" python3 - "$staging/config/hooks.json" << 'PYEOF'
import json, os, sys

settings_path = os.environ["SETTINGS_PATH"]
output_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
memory_hooks = {}

def is_memory_hook(h):
    cmd = h.get("command", "")
    prompt = h.get("prompt", "")
    status = h.get("statusMessage", "")
    return (
        "memory-" in cmd
        or "memory" in status.lower()
        or "Daily Log" in prompt
        or "daily log" in prompt.lower()
    )

for key in ("SessionStart", "PreCompact", "Stop", "SessionEnd"):
    if key not in hooks:
        continue
    filtered = []
    for entry in hooks[key]:
        hook_list = entry.get("hooks", [])
        mem_hooks = [h for h in hook_list if is_memory_hook(h)]
        if mem_hooks:
            filtered.append({**entry, "hooks": mem_hooks})
    if filtered:
        memory_hooks[key] = filtered

with open(output_path, "w") as f:
    json.dump(memory_hooks, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF
        ok "config/hooks.json (settings.json hooks 섹션 추출)"
    else
        warn "settings.json 또는 python3 없음 — hooks 설정 수동 병합 필요"
    fi

    # 4. 설치 안내 README 생성
    cat > "$staging/README.md" << 'README'
# Claude Code Memory Search System

## 빠른 설치
```bash
./memory-system-portable.sh import claude-memory-system.tar.gz
```

## 수동 설치
1. hooks/ → ~/.claude/hooks/ 복사 + chmod +x
2. rules/ → ~/.claude/rules/common/ 복사
3. config/hooks.json → ~/.claude/settings.json에 병합
4. pip install google-genai
5. export GEMINI_API_KEY="your-key" >> ~/.zshrc

## 검증
```bash
./memory-system-portable.sh verify
```

## 구성 요소
- memory-lib.sh: 공용 유틸리티
- memory-search.py: Hybrid BM25+Vector+MMR 검색 엔진
- memory-session-start.sh: 세션 시작 시 Daily Log 주입
- memory-session-end.sh: 세션 종료 시 아카이빙 + 인덱싱
- memory.md: Claude에게 메모리 사용법을 안내하는 규칙
- hooks.json: settings.json에 병합할 hooks 설정
README

    # 5. 이 스크립트 자체도 포함
    cp "${BASH_SOURCE[0]}" "$staging/"

    # 6. 아카이브 생성
    tar czf "$ARCHIVE_PATH" -C "$tmpdir" "claude-memory-system"
    rm -rf "$tmpdir"

    echo ""
    ok "Export 완료: $ARCHIVE_PATH"
    info "파일 크기: $(du -h "$ARCHIVE_PATH" | cut -f1)"
    echo ""
    info "새 노트북으로 전송 후 실행:"
    echo "  ./memory-system-portable.sh import ~/claude-memory-system.tar.gz"
}

# ─────────────────────────────────────────────────
# IMPORT: 새 머신에서 설치
# ─────────────────────────────────────────────────
cmd_import() {
    local archive="${1:-}"
    if [ -z "$archive" ]; then
        # 기본 경로 시도
        if [ -f "$ARCHIVE_PATH" ]; then
            archive="$ARCHIVE_PATH"
        else
            fail "Usage: $0 import <archive.tar.gz>"
            exit 1
        fi
    fi

    if [ ! -f "$archive" ]; then
        fail "아카이브 없음: $archive"
        exit 1
    fi

    info "Memory System Import 시작..."
    echo ""

    local tmpdir
    tmpdir=$(mktemp -d)
    tar xzf "$archive" -C "$tmpdir"

    local src="$tmpdir/claude-memory-system"
    if [ ! -d "$src" ]; then
        fail "아카이브 구조 오류: claude-memory-system/ 디렉토리 없음"
        rm -rf "$tmpdir"
        exit 1
    fi

    # 1. 디렉토리 생성
    mkdir -p "$HOOKS_DIR" "$RULES_DIR"

    # 2. Hook 스크립트 설치
    info "Step 1/5: Hook 스크립트 설치..."
    local installed=0
    for f in "$src/hooks/"*; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f")
        if [ -f "$HOOKS_DIR/$name" ]; then
            warn "$name 이미 존재 — 백업 후 덮어쓰기"
            cp "$HOOKS_DIR/$name" "$HOOKS_DIR/${name}.bak"
        fi
        cp "$f" "$HOOKS_DIR/$name"
        chmod +x "$HOOKS_DIR/$name"
        ok "  $name"
        installed=$((installed + 1))
    done
    ok "Hook 스크립트 ${installed}개 설치 완료"
    echo ""

    # 3. 규칙 파일 설치
    info "Step 2/5: 규칙 파일 설치..."
    if [ -f "$src/rules/memory.md" ]; then
        if [ -f "$RULES_DIR/memory.md" ]; then
            warn "memory.md 이미 존재 — 백업 후 덮어쓰기"
            cp "$RULES_DIR/memory.md" "$RULES_DIR/memory.md.bak"
        fi
        cp "$src/rules/memory.md" "$RULES_DIR/"
        ok "  rules/common/memory.md"
    else
        warn "  규칙 파일 없음 — 건너뜀"
    fi
    echo ""

    # 4. settings.json hooks 병합
    info "Step 3/5: settings.json hooks 병합..."
    if [ -f "$src/config/hooks.json" ]; then
        if [ ! -f "$SETTINGS" ]; then
            # settings.json이 없으면 새로 생성
            echo '{}' > "$SETTINGS"
            info "  settings.json 새로 생성"
        fi

        # 백업
        cp "$SETTINGS" "${SETTINGS}.bak"
        ok "  settings.json 백업 → settings.json.bak"

        # Python으로 hooks 병합
        SETTINGS_PATH="$SETTINGS" HOOKS_JSON="$src/config/hooks.json" python3 << 'PYEOF'
import json, os

settings_path = os.environ["SETTINGS_PATH"]
hooks_json_path = os.environ["HOOKS_JSON"]

with open(settings_path) as f:
    settings = json.load(f)

with open(hooks_json_path) as f:
    new_hooks = json.load(f)

if "hooks" not in settings:
    settings["hooks"] = {}

for key, entries in new_hooks.items():
    if key not in settings["hooks"]:
        settings["hooks"][key] = entries
        print(f"  + {key}: 새로 추가")
    else:
        existing_cmds = set()
        for entry in settings["hooks"][key]:
            for h in entry.get("hooks", []):
                existing_cmds.add(h.get("command", "") + h.get("prompt", "")[:50])

        added = 0
        for entry in entries:
            for h in entry.get("hooks", []):
                sig = h.get("command", "") + h.get("prompt", "")[:50]
                if sig not in existing_cmds:
                    settings["hooks"][key].append(entry)
                    added += 1
                    break
        if added:
            print(f"  + {key}: {added}개 훅 추가")
        else:
            print(f"  = {key}: 이미 존재 — 건너뜀")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF
        ok "  settings.json hooks 병합 완료"
    else
        warn "  hooks.json 없음 — 수동 병합 필요"
    fi
    echo ""

    # 5. Python 의존성 확인/설치
    info "Step 4/5: Python 의존성 확인..."
    if command -v python3 &>/dev/null; then
        ok "  python3 발견: $(python3 --version 2>&1)"
        if python3 -c "from google import genai" 2>/dev/null; then
            ok "  google-genai 이미 설치됨"
        else
            info "  google-genai 설치 중..."
            if pip3 install google-genai 2>/dev/null || pip install google-genai 2>/dev/null; then
                ok "  google-genai 설치 완료"
            else
                warn "  google-genai 설치 실패 — 수동 설치 필요: pip install google-genai"
            fi
        fi
    else
        fail "  python3 미설치 — 설치 후 'pip install google-genai' 실행 필요"
    fi
    echo ""

    # 6. GEMINI_API_KEY 확인
    info "Step 5/5: GEMINI_API_KEY 확인..."
    local has_key=false
    if [ -n "${GEMINI_API_KEY:-}" ]; then
        ok "  환경 변수에 설정됨"
        has_key=true
    elif [ -f "$HOME/.zshrc" ] && grep -q 'GEMINI_API_KEY' "$HOME/.zshrc" 2>/dev/null; then
        ok "  .zshrc에 설정됨"
        has_key=true
    elif [ -f "$HOME/.bashrc" ] && grep -q 'GEMINI_API_KEY' "$HOME/.bashrc" 2>/dev/null; then
        ok "  .bashrc에 설정됨"
        has_key=true
    fi

    if [ "$has_key" = false ]; then
        warn "  GEMINI_API_KEY 미설정"
        echo ""
        echo -e "${YELLOW}  다음 명령으로 설정하세요:${NC}"
        echo '  echo '\''export GEMINI_API_KEY="your-key-here"'\'' >> ~/.zshrc'
        echo '  source ~/.zshrc'
        echo ""
        echo "  키 발급: https://aistudio.google.com/apikey"
    fi

    rm -rf "$tmpdir"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ok "Import 완료!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "검증하려면: $0 verify"
    info "Claude Code를 재시작하면 메모리 시스템이 활성화됩니다."
}

# ─────────────────────────────────────────────────
# VERIFY: 설치 검증
# ─────────────────────────────────────────────────
cmd_verify() {
    info "Memory System 설치 검증..."
    echo ""
    local errors=0

    # 1. Hook 스크립트 존재 + 실행 권한
    info "1. Hook 스크립트 검증"
    for f in memory-lib.sh memory-search.py memory-session-start.sh memory-session-end.sh; do
        if [ -f "$HOOKS_DIR/$f" ]; then
            if [ -x "$HOOKS_DIR/$f" ]; then
                ok "  $f (실행 가능)"
            else
                warn "  $f (실행 권한 없음 — chmod +x 필요)"
                errors=$((errors + 1))
            fi
        else
            fail "  $f 없음"
            errors=$((errors + 1))
        fi
    done
    echo ""

    # 2. 규칙 파일
    info "2. 규칙 파일 검증"
    if [ -f "$RULES_DIR/memory.md" ]; then
        ok "  rules/common/memory.md"
    else
        warn "  rules/common/memory.md 없음 (선택 사항)"
    fi
    echo ""

    # 3. settings.json hooks
    info "3. settings.json hooks 검증"
    if [ -f "$SETTINGS" ]; then
        for hook_type in SessionStart PreCompact Stop SessionEnd; do
            if SETTINGS_PATH="$SETTINGS" HOOK_TYPE="$hook_type" python3 -c '
import json, os
with open(os.environ["SETTINGS_PATH"]) as f:
    s = json.load(f)
hooks = s.get("hooks", {}).get(os.environ["HOOK_TYPE"], [])
found = any(
    "memory" in h.get("command", "").lower()
    or "memory" in h.get("statusMessage", "").lower()
    or "daily log" in h.get("prompt", "").lower()
    or "Daily Log" in h.get("prompt", "")
    for entry in hooks
    for h in entry.get("hooks", [])
)
exit(0 if found else 1)
' 2>/dev/null; then
                ok "  $hook_type hook 등록됨"
            else
                fail "  $hook_type hook 미등록"
                errors=$((errors + 1))
            fi
        done
    else
        fail "  settings.json 없음"
        errors=$((errors + 1))
    fi
    echo ""

    # 4. Python 의존성
    info "4. Python 의존성 검증"
    if command -v python3 &>/dev/null; then
        ok "  python3: $(python3 --version 2>&1)"
    else
        fail "  python3 미설치"
        errors=$((errors + 1))
    fi

    if python3 -c "from google import genai" 2>/dev/null; then
        ok "  google-genai 설치됨"
    else
        fail "  google-genai 미설치 — pip install google-genai"
        errors=$((errors + 1))
    fi
    echo ""

    # 5. GEMINI_API_KEY
    info "5. GEMINI_API_KEY 검증"
    local key_found=false
    if [ -n "${GEMINI_API_KEY:-}" ]; then
        ok "  환경 변수 설정됨 (${#GEMINI_API_KEY}자)"
        key_found=true
    fi
    if [ -f "$HOME/.zshrc" ] && grep -q 'GEMINI_API_KEY' "$HOME/.zshrc" 2>/dev/null; then
        ok "  .zshrc에 등록됨"
        key_found=true
    fi
    if [ "$key_found" = false ]; then
        fail "  GEMINI_API_KEY 미설정"
        errors=$((errors + 1))
    fi
    echo ""

    # 6. memory-search.py self-test
    info "6. memory-search.py self-test"
    if [ -f "$HOOKS_DIR/memory-search.py" ]; then
        if python3 "$HOOKS_DIR/memory-search.py" self-test 2>/dev/null; then
            ok "  self-test 통과"
        else
            fail "  self-test 실패"
            errors=$((errors + 1))
        fi
    fi
    echo ""

    # 결과
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "$errors" -eq 0 ]; then
        ok "모든 검증 통과! Claude Code를 재시작하면 메모리 시스템이 활성화됩니다."
    else
        fail "${errors}개 항목 실패. 위의 메시지를 참고하여 수정하세요."
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return "$errors"
}

# ─────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────
case "${1:-}" in
    export)
        cmd_export
        ;;
    import)
        cmd_import "${2:-}"
        ;;
    verify)
        cmd_verify
        ;;
    *)
        echo "Claude Code Memory Search System — 이식 자동화"
        echo ""
        echo "Usage:"
        echo "  $0 export              현재 머신에서 아카이브 생성"
        echo "  $0 import <archive>    새 머신에서 설치"
        echo "  $0 verify              설치 상태 검증"
        echo ""
        echo "Workflow:"
        echo "  1. 현재 머신:  $0 export"
        echo "  2. 파일 전송:  scp ~/claude-memory-system.tar.gz user@new-host:~/"
        echo "  3. 새 머신:    $0 import ~/claude-memory-system.tar.gz"
        echo "  4. 새 머신:    $0 verify"
        ;;
esac
