#!/usr/bin/env python3
"""
read-edit-gate.py — PreToolUse(Edit) 차단 훅

배경: "반복 편집 방지(Read 선행)" 프롬프트 룰이 60회 방지 실패 (friction §3:
Read:Edit 34회 + 반복 편집 26회 재등장). 사후 경고로는 못 막아, PreToolUse 차단으로
승격한다 (eval-based harness evolution: 경고@2 → 차단@3 사다리).

차단 조건 (모두 충족 시 exit 2):
  1. tool == Edit  (Write=신규 생성은 컨텍스트 보유로 제외)
  2. 대상이 소스 코드 파일 (.py .kt .ts .tsx 등 — 문서/설정/메타 제외)
  3. 이번 세션 Edit 카운트 >= BLOCK_AT (기본 2 = 3회째 편집)
  4. 이번 세션 read-tracker에 해당 파일 없음 (= 한 번도 Read 안 함)

Edit 카운트는 자체 트래커(/tmp/claude-readeditgate-*)로 관리해 Write를 섞지 않는다.
차단된 시도는 카운트하지 않으므로, Read하기 전까지 계속 차단된다.
오탐(방금 만든 파일 등) 시 Read 1회면 즉시 해제 — 비용 작고 규율에 부합.

Note: read-tracker(/tmp/claude-read-tracker-*)는 memory-post-tool.py(PostToolUse)가 기록.
"""
import json
import sys
from pathlib import Path

# 게이트 발동 임계값: 이미 N회 편집했을 때 다음(N+1회째) 편집을 차단. 2 = 3회째부터 차단.
BLOCK_AT = 2

SRC_EXT = {
    ".py", ".kt", ".kts", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".swift", ".css", ".scss", ".vue", ".go", ".rs", ".java", ".rb", ".php",
}


def session_id():
    f = Path.home() / ".claude/memory/sessions/.current-session-id"
    try:
        return f.read_text().strip()
    except OSError:
        return None


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0

    if data.get("tool_name", "") != "Edit":
        return 0

    fp = (data.get("tool_input") or {}).get("file_path", "")
    if not fp or Path(fp).suffix.lower() not in SRC_EXT:
        return 0

    sid = session_id()
    if not sid:
        return 0

    gate_tracker = Path(f"/tmp/claude-readeditgate-{sid}")
    read_tracker = Path(f"/tmp/claude-read-tracker-{sid}")

    edit_count = 0
    if gate_tracker.exists():
        try:
            edit_count = sum(1 for ln in gate_tracker.read_text().splitlines() if ln == fp)
        except OSError:
            pass

    read_done = False
    if read_tracker.exists():
        try:
            read_done = any(ln == fp for ln in read_tracker.read_text().splitlines())
        except OSError:
            pass

    if edit_count >= BLOCK_AT and not read_done:
        sys.stderr.write(
            f"[read-edit-gate] {fp} 를 {edit_count + 1}회째 편집하려 하지만 이번 세션에 "
            f"한 번도 Read하지 않았습니다.\n"
            f"먼저 이 파일을 limit 없이 Read(+ 호출하는/호출되는 파일 1개)한 뒤 재편집하세요 "
            f"(CLAUDE.md '반복 편집 방지'). Read 1회면 게이트가 해제됩니다.\n"
        )
        return 2

    # 통과: 이번 편집을 카운트에 기록
    try:
        with open(gate_tracker, "a") as f:
            f.write(fp + "\n")
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
