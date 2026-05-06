#!/usr/bin/env python3
"""friction-rule-scanner — Analyze failure-log.md to identify recurring friction patterns.

Reframing: 기존 가설은 "어떤 규칙이 friction을 유발했는가"였으나, sessions.jsonl에
"세션 중 활성 규칙" 정보가 없어 차단됐다. 대신 failure-log.md의 해법 컬럼이
'룰 언급 + 재발 빈도'를 이미 담고 있으므로, "어떤 규칙이 friction 방지에 실패했는가"로
전환하여 같은 데이터에서 분석 가능.

Usage:
  friction-rule-scanner.py              # stdout
  friction-rule-scanner.py --write      # write to memory/metrics/friction-YYYY-MM-DD.md
"""
from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path

HOME = Path.home()
FAILURE_LOG = HOME / ".claude/memory/topics/failure-log.md"
METRICS_DIR = HOME / ".claude/memory/metrics"

RULE_PATTERNS: list[tuple[str, str]] = [
    ("반복 편집 방지 (전체 Read 선행)", r"편집\s*전.*Read|전체\s*Read|limit\s*없[이는].*Read|선행\s*Read|Read\s*선행"),
    ("/feature brainstorming 게이트", r"/feature|brainstorming"),
    ("부모/자식 컴포넌트 선행 Read", r"부모.*컴포넌트.*Read|상위\s*컴포넌트.*Read|관련.*컴포넌트"),
    ("edit-tracker 필터/정확 매칭", r"edit-tracker|tracker.*(필터|정확|매칭)"),
    ("settings integrity / hook 검증", r"settings.*integrity|hooks?\s*검증|frozen"),
    ("재현 후 수정 (디버깅 증거)", r"재현.*수정|증거\s*먼저|재현\s*→\s*진단"),
    ("active-context handoff", r"active[\- ]context.*handoff|handoff"),
    ("Read:Edit 비율 / 관련 파일", r"Read:Edit|관련\s*파일|엔티티/DTO\s*선행"),
]

FILE_PATTERN = re.compile(
    r"([A-Za-z0-9_.\-/]+\.(?:tsx?|jsx?|py|kt|java|md|json|css|ya?ml|sh|mjs|avsc))"
)


def parse_table(content: str) -> list[dict]:
    rows: list[dict] = []
    in_table = False
    for line in content.splitlines():
        if not line.startswith("|"):
            in_table = False
            continue
        parts = [c.strip() for c in line.strip("|").split("|")]
        if len(parts) != 4:
            continue
        if parts[0] in ("날짜", "") or parts[0].startswith("---") or set(parts[0]) <= {"-"}:
            in_table = True
            continue
        if not in_table:
            continue
        if not re.match(r"\d{4}-\d{2}-\d{2}", parts[0]):
            continue
        rows.append({
            "date": parts[0],
            "symptom": parts[1],
            "layer": parts[2],
            "solution": parts[3],
        })
    return rows


def normalize_layer(raw: str) -> str:
    return re.split(r"\s*[\(（]", raw)[0].strip() or "미분류"


def analyze(rows: list[dict]) -> str:
    total = len(rows)
    out: list[str] = []
    out.append("# Friction Analysis Report")
    out.append(f"Generated: {datetime.now():%Y-%m-%d %H:%M}")
    out.append(f"Source: `memory/topics/failure-log.md` ({total} entries)\n")

    layer_counts: Counter[str] = Counter()
    file_counts: Counter[str] = Counter()
    file_meta: dict[str, list[str]] = {}
    rule_failures: Counter[str] = Counter()
    rule_dates: dict[str, list[str]] = {}

    for r in rows:
        layer = normalize_layer(r["layer"])
        layer_counts[layer] += 1
        for m in FILE_PATTERN.finditer(r["symptom"]):
            fname = m.group(1)
            file_counts[fname] += 1
            file_meta.setdefault(fname, []).append(r["date"])
        for rule_name, pat in RULE_PATTERNS:
            if re.search(pat, r["solution"], re.IGNORECASE):
                rule_failures[rule_name] += 1
                rule_dates.setdefault(rule_name, []).append(r["date"])

    out.append("## 1. 원인 계층 분포")
    for layer, cnt in layer_counts.most_common():
        pct = 100 * cnt / total if total else 0
        out.append(f"- **{layer}**: {cnt}건 ({pct:.0f}%)")

    out.append("\n## 2. 재발 파일 (2회+ 등장)")
    recurring = [(f, c) for f, c in file_counts.items() if c >= 2]
    recurring.sort(key=lambda x: (-x[1], x[0]))
    if recurring:
        for fname, cnt in recurring[:10]:
            dates = sorted(set(file_meta[fname]))
            out.append(f"- `{fname}` — {cnt}회 ({', '.join(dates)})")
    else:
        out.append("- (없음 — 모두 1회성)")

    out.append("\n## 3. 규칙 효과 — 해법 반복 언급 = 룰 방지 실패")
    if rule_failures:
        for rule, cnt in rule_failures.most_common():
            dates = sorted(set(rule_dates[rule]))
            first, last = dates[0], dates[-1]
            status = "⚠️ 반복" if cnt >= 3 else "관찰중"
            out.append(f"- **{rule}** — {cnt}건 ({first} ~ {last}) [{status}]")
    else:
        out.append("- (해법 컬럼에서 알려진 규칙 패턴 미매칭)")

    out.append("\n## 4. 제안")
    suggestions: list[str] = []
    if recurring and recurring[0][1] >= 3:
        top = recurring[0]
        suggestions.append(
            f"- `{top[0]}` {top[1]}회 재발 — 해당 파일/디렉토리에 특화 규칙 또는 skill 검토"
        )
    ctx_ratio = layer_counts.get("Context", 0) / total if total else 0
    if ctx_ratio > 0.5:
        suggestions.append(
            f"- Context 원인 {ctx_ratio*100:.0f}% — 파일 Read 선행 규칙을 훅으로 강제화 검토 (예: 3회+ 편집 감지 시 자동 Read trigger)"
        )
    prompt_ratio = layer_counts.get("Prompt", 0) / total if total else 0
    if prompt_ratio > 0.25:
        suggestions.append(
            f"- Prompt 원인 {prompt_ratio*100:.0f}% — skill/CLAUDE.md 지시문 모호성 점검, /review-week에서 지시문 리팩토링 후보 도출"
        )
    for rule, cnt in rule_failures.most_common():
        if cnt >= 3:
            suggestions.append(
                f"- `{rule}` {cnt}건 재등장 — 룰 강도 상향 또는 자동화(훅)로 전환 검토"
            )
    if suggestions:
        out.extend(suggestions)
    else:
        out.append("- 특이사항 없음 — 현 규칙셋이 효과적")

    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write", action="store_true", help="write report to metrics dir")
    args = ap.parse_args()

    if not FAILURE_LOG.exists():
        print(f"error: failure-log not found at {FAILURE_LOG}", file=sys.stderr)
        return 1

    rows = parse_table(FAILURE_LOG.read_text(encoding="utf-8"))
    if not rows:
        print("error: no parseable rows in failure-log", file=sys.stderr)
        return 1

    report = analyze(rows)

    if args.write:
        METRICS_DIR.mkdir(parents=True, exist_ok=True)
        out_path = METRICS_DIR / f"friction-{datetime.now():%Y-%m-%d}.md"
        out_path.write_text(report, encoding="utf-8")
        print(f"wrote {out_path}")
    else:
        sys.stdout.write(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
