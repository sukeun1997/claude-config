#!/usr/bin/env python3
"""
failure-log-classify.py — failure-log 자동 분류 + dedup (self-healing)

배경: failure-log.md에 "미분류"/"(추정)" 행이 적체되면 instinct-boost가
unconfirmed 행을 skip하여 자기진화 루프가 멈춘다 (L5 병목).
이 스크립트는 명확한 단일 패턴을 자동 확정하고 중복 행을 제거하여 큐를 작게 유지한다.

분류 휴리스틱 (반복 편집 증상 한정):
  - 메타 파일 (SKILL.md, ecr.md, *.QUICKREF.md, MEMORY.md, CLAUDE.md, AGENTS.md) → Harness (meta)
    (의도된 튜닝 반복 — 실패 신호 아님)
  - 문서/스펙/플랜 (.md, .d2 + spec/plan/analysis/정산/상환/인수인계 또는 6회+) → Prompt
    (스코프 미확정 상태에서 반복 편집 = 지시문/요구사항 문제)
  - 소스/설정 (.py .kt .ts .tsx .swift .css .json .yml .js .sql) → Context
    (관련 파일/타입 정의 선행 Read 미흡)

dedup: 동일 (날짜, 증상) **정확매치** 행만 제거 (진짜 중복). 횟수가 다르면 별개 이벤트로 보존.
       보존 행은 원본에서 이미 확정된 행을 우선 (사람 분류 보존), 없으면 첫 행.

안전장치:
  - 반복 편집("N회 반복 편집") 증상만 자동 분류. 그 외 증상(에러/사고 등)은 미분류로 남겨 사용자 큐 유지.
  - --auto: 변경 적용. --dry-run(기본): 변경 미적용, 요약만 출력.

Usage:
  failure-log-classify.py                  # dry-run (요약만, 라이브 파일)
  failure-log-classify.py --auto           # 적용 (라이브 파일)
  failure-log-classify.py --file PATH       # 다른 파일 대상 (테스트)
"""
import re
import sys
from pathlib import Path

DEFAULT_LOG = Path.home() / ".claude/memory/topics/failure-log.md"


def resolve_log() -> Path:
    if "--file" in sys.argv:
        i = sys.argv.index("--file")
        if i + 1 < len(sys.argv):
            return Path(sys.argv[i + 1])
    return DEFAULT_LOG

ROW_RE = re.compile(r"^\|\s*(\d{4}-\d{2}-\d{2})\s*\|(.+?)\|(.+?)\|(.*?)\|\s*$")

# 자동 분류 대상: 반복 편집 증상만
REPEAT_EDIT_RE = re.compile(r"(\d+)\s*회 반복 편집")

# 메타 파일 (의도된 튜닝 — 실패 신호 아님)
META_FILES = re.compile(
    r"(SKILL\.md|ecr\.md|\.QUICKREF\.md|MEMORY\.md|CLAUDE\.md|AGENTS\.md)$"
)
# 문서/스펙/플랜 → Prompt
DOC_FILE = re.compile(
    r"(spec|plan|analysis|as-is|to-be|정산|상환|인수인계|diagram)",
    re.IGNORECASE,
)
DOC_EXT = re.compile(r"\.(md|d2)$", re.IGNORECASE)
# 소스/설정 → Context
SRC_EXT = re.compile(
    r"\.(py|kt|ts|tsx|js|jsx|swift|css|scss|json|yml|yaml|sql)$", re.IGNORECASE
)

# 분류 미확정 마커
UNCLASSIFIED = ("미분류", "(추정)")


def is_confirmed(layer: str) -> bool:
    """확정 레이어 = 미분류/추정 없음."""
    return not any(m in layer for m in UNCLASSIFIED)


def extract_filename(symptom: str) -> str:
    """증상 텍스트에서 파일명 토큰 추출 (dedup 키)."""
    m = re.search(r"([^\s|]+\.[A-Za-z0-9]+)", symptom)
    if m:
        return m.group(1)
    return symptom.strip().split()[0] if symptom.strip() else symptom


def classify(symptom: str, filename: str):
    """(layer, hint) 반환. 자동 분류 불가 시 (None, None)."""
    cm = REPEAT_EDIT_RE.search(symptom)
    if not cm:
        return None, None  # 반복 편집 증상 아님 → 자동 분류 안 함
    count = int(cm.group(1))

    if META_FILES.search(filename):
        return "Harness (meta)", "스킬/설정 정의 튜닝 — 의도된 반복 (실패 신호 아님)"

    if DOC_EXT.search(filename) and (DOC_FILE.search(filename) or count >= 6):
        if count >= 6:
            return (
                "Prompt",
                f"{count}회 — 스코프 미확정 반복. 3줄 룰(AC/Out-of-scope/Done-when) 선행 필요",
            )
        return "Prompt", "스코프 미확정 상태 문서 반복 — 요구사항 확정 후 작성"

    if SRC_EXT.search(filename):
        if count >= 5:
            return "Context (강)", f"{count}회+ — 파일 전체 Read(limit 없이) 후 재접근"
        return "Context", "관련 파일/타입 정의 선행 Read 미흡"

    # 확장자 없는 모호 케이스 (예: "정산관련") — 반복 편집이면 Context 추정
    return "Context", "반복 편집 — 관련 파일/타입 정의 선행 Read 필요"


def main():
    auto = "--auto" in sys.argv
    failure_log = resolve_log()
    if not failure_log.exists():
        print("NO_FILE")
        return 0

    lines = failure_log.read_text().splitlines()

    # --- 파싱: 테이블 행을 구조화 (원본 확정 상태 보존) ---
    parsed = []  # {idx, date, symptom, layer, hint, orig_confirmed} or {raw}
    for line in lines:
        m = ROW_RE.match(line)
        if not m:
            parsed.append({"raw": line})
            continue
        date, symptom_raw, layer_raw, hint_raw = m.groups()
        symptom, layer, hint = symptom_raw.strip(), layer_raw.strip(), hint_raw.strip()
        if "[EXTERNAL]" in symptom:
            parsed.append({"raw": line})
            continue
        parsed.append({
            "date": date, "symptom": symptom, "layer": layer, "hint": hint,
            "orig_confirmed": is_confirmed(layer),
        })

    # --- Pass 1: dedup by (date, symptom) 정확매치, 원본 확정 행 우선 보존 ---
    survivor = {}  # (date, symptom) -> parsed index to keep
    for i, row in enumerate(parsed):
        if "raw" in row:
            continue
        key = (row["date"], row["symptom"])
        if key not in survivor:
            survivor[key] = i
        else:
            prev = parsed[survivor[key]]
            # 현재가 원본 확정인데 보존된 게 미확정이면 교체
            if row["orig_confirmed"] and not prev["orig_confirmed"]:
                survivor[key] = i

    deduped = 0
    drop = set()
    for i, row in enumerate(parsed):
        if "raw" in row:
            continue
        key = (row["date"], row["symptom"])
        if survivor[key] != i:
            drop.add(i)
            deduped += 1

    # --- Pass 2: 생존 행 중 원본 미확정만 재분류 ---
    reclassified = 0
    kept_unclassified = 0
    for i, row in enumerate(parsed):
        if "raw" in row or i in drop:
            continue
        if not row["orig_confirmed"]:
            new_layer, new_hint = classify(row["symptom"], extract_filename(row["symptom"]))
            if new_layer:
                row["layer"], row["hint"] = new_layer, new_hint
                reclassified += 1
            else:
                kept_unclassified += 1

    # --- 출력 재구성 (순서 보존, drop 제외) ---
    out = []
    for i, row in enumerate(parsed):
        if i in drop:
            continue
        if "raw" in row:
            out.append(row["raw"])
        else:
            out.append(f"| {row['date']} | {row['symptom']} | {row['layer']} | {row['hint'] or '-'} |")

    print(f"reclassified={reclassified} deduped={deduped} kept_unclassified={kept_unclassified}")

    if auto:
        failure_log.write_text("\n".join(out) + "\n")
        print(f"WROTE {failure_log}")
    else:
        print("DRY-RUN (--auto 로 적용)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
