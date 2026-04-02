#!/usr/bin/env python3
"""
observer-analyzer.py — Behavioral pattern extraction from observations.

Reads JSONL observations from stdin, detects meaningful patterns:
  1. Session boundary detection (date change or 30min gap)
  2. Tool sequence patterns within sessions
  3. Project-level workflow patterns

Output: TSV to stdout
  type\tname\tcount\tdomain\tdescription\ttrigger\taction\tproject
"""

import json
import sys
from collections import Counter, defaultdict

# ---------------------------------------------------------------------------
# Known sequence patterns (neutral labels, no success/failure assumption)
# ---------------------------------------------------------------------------

SEQUENCE_PATTERNS = {
    # length-3 sequences
    ("Edit", "Bash:build", "Edit"): {
        "name": "build-check-cycle",
        "domain": "sequence",
        "trigger": "코드 수정 후 빌드 확인이 필요할 때",
        "action": "Edit→Build→Edit 사이클 인식. 3회 이상 반복 시 접근법 재검토 권장.",
    },
    ("Edit", "Bash:test", "Edit"): {
        "name": "test-check-cycle",
        "domain": "sequence",
        "trigger": "테스트 기반 수정 작업 시",
        "action": "Edit→Test→Edit 사이클 인식. TDD 워크플로우에 가까운 패턴.",
    },
    ("Edit", "Bash:build", "Bash:test"): {
        "name": "edit-build-test",
        "domain": "sequence",
        "trigger": "기능 수정 후 빌드와 테스트를 순차 실행할 때",
        "action": "Edit→Build→Test 워크플로우. 안정적인 검증 패턴.",
    },
    # length-2 sequences
    ("Edit", "Bash:build"): {
        "name": "edit-then-build",
        "domain": "sequence",
        "trigger": "코드 수정 직후",
        "action": "수정 후 빌드 확인 습관. 빈번하면 IDE 자동 빌드 고려.",
    },
    ("Edit", "Bash:test"): {
        "name": "edit-then-test",
        "domain": "sequence",
        "trigger": "코드 수정 직후",
        "action": "수정 후 테스트 실행 습관. TDD 지향 워크플로우.",
    },
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def time_gap_minutes(ts1: str, ts2: str) -> float:
    """Calculate gap in minutes between two HH:MM:SS timestamps."""
    try:
        parts1 = ts1.split(":")
        parts2 = ts2.split(":")
        sec1 = int(parts1[0]) * 3600 + int(parts1[1]) * 60 + int(parts1[2])
        sec2 = int(parts2[0]) * 3600 + int(parts2[1]) * 60 + int(parts2[2])
        return (sec2 - sec1) / 60.0
    except (ValueError, IndexError):
        return -1  # treat parse errors as session boundary


def normalize_tool(obs: dict) -> str:
    """Normalize observation to a tool key for sequence matching.
    Edit -> 'Edit', Bash(build) -> 'Bash:build', Write -> 'Write', etc."""
    tool = obs.get("tool", "")
    if tool == "Bash":
        category = obs.get("category", "")
        return f"Bash:{category}" if category else "Bash"
    return tool


# ---------------------------------------------------------------------------
# 1. Session boundary detection
# ---------------------------------------------------------------------------

def detect_sessions(observations: list) -> list:
    """Split observations into sessions.
    Session boundary = date change OR 30+ minute gap OR time reversal."""
    sessions = []
    current = []

    for obs in observations:
        if current:
            prev = current[-1]
            # Different date = new session
            if obs.get("date") and prev.get("date") and obs["date"] != prev["date"]:
                sessions.append(current)
                current = [obs]
                continue
            # Time gap check (30 min or reversal)
            if prev.get("ts") and obs.get("ts"):
                gap = time_gap_minutes(prev["ts"], obs["ts"])
                if gap > 30 or gap < 0:
                    sessions.append(current)
                    current = [obs]
                    continue
        current.append(obs)

    if current:
        sessions.append(current)
    return sessions


# ---------------------------------------------------------------------------
# 2. Sequence pattern extraction
# ---------------------------------------------------------------------------

def extract_sequences(session: list) -> Counter:
    """Extract known tool sequence patterns from a single session."""
    patterns = Counter()
    normalized = [normalize_tool(obs) for obs in session]

    # Sliding window: length 3 then 2
    for window_size in (3, 2):
        for i in range(len(normalized) - window_size + 1):
            window = tuple(normalized[i:i + window_size])
            if window in SEQUENCE_PATTERNS:
                patterns[window] += 1

    # Special: repeated edit on same file (3+ within session)
    file_edits = Counter()
    for obs in session:
        if obs.get("tool") in ("Edit", "Write") and obs.get("file"):
            file_edits[obs["file"]] += 1
    for filepath, count in file_edits.items():
        if count >= 3:
            patterns[("repeated-edit",)] += 1

    # Special: commit at end of session
    if normalized and normalized[-1] == "Bash:git":
        patterns[("commit-and-done",)] += 1

    # Special: multi-file create (3+ consecutive Writes)
    consecutive_writes = 0
    for n in normalized:
        if n == "Write":
            consecutive_writes += 1
            if consecutive_writes >= 3:
                patterns[("multi-file-create",)] += 1
                consecutive_writes = 0  # reset to avoid over-counting
        else:
            consecutive_writes = 0

    return patterns


# ---------------------------------------------------------------------------
# 3. Project-level patterns
# ---------------------------------------------------------------------------

def extract_project_patterns(sessions: list) -> list:
    """Extract per-project workflow characteristics."""
    project_stats = defaultdict(
        lambda: {"tools": Counter(), "sequences": Counter(), "sessions": 0}
    )

    for session in sessions:
        # Determine project from first observation with a project field
        project = "unknown"
        for obs in session:
            p = obs.get("project")
            if p and p != "unknown":
                project = p
                break
        stats = project_stats[project]
        stats["sessions"] += 1
        for obs in session:
            stats["tools"][obs.get("tool", "unknown")] += 1
        stats["sequences"] += extract_sequences(session)

    results = []
    for project, stats in project_stats.items():
        if stats["sessions"] < 2:
            continue
        # Dominant tool ratio
        total = sum(stats["tools"].values())
        if total == 0:
            continue
        for tool, count in stats["tools"].most_common(3):
            ratio = count / total
            if ratio > 0.5:
                results.append({
                    "type": "project-tool-dominance",
                    "name": f"{project}-{tool.lower()}-heavy",
                    "count": count,
                    "domain": "project-workflow",
                    "description": f"{project}에서 {tool}이 {ratio:.0%} 비중 ({count}/{total})",
                    "trigger": f"{project} 프로젝트 작업 시",
                    "action": f"{tool} 중심 워크플로우. 해당 도구 최적화 우선.",
                    "project": project,
                })
        # Dominant sequences
        for seq, count in stats["sequences"].most_common(3):
            if count >= 3:
                seq_name = SEQUENCE_PATTERNS.get(seq, {}).get("name", str(seq))
                if isinstance(seq, tuple) and len(seq) == 1:
                    seq_name = seq[0]  # special patterns like repeated-edit
                results.append({
                    "type": "project-sequence",
                    "name": f"{project}-{seq_name}",
                    "count": count,
                    "domain": "project-workflow",
                    "description": f"{project}에서 {seq_name} 시퀀스 {count}회",
                    "trigger": f"{project} 프로젝트 작업 시",
                    "action": f"{seq_name} 패턴이 빈번. 워크플로우 자동화 고려.",
                    "project": project,
                })
    return results


# ---------------------------------------------------------------------------
# 4. Aggregate global sequence patterns
# ---------------------------------------------------------------------------

def aggregate_sequence_patterns(sessions: list) -> list:
    """Aggregate sequence patterns across all sessions."""
    global_sequences = Counter()
    project_breakdown = defaultdict(lambda: Counter())

    for session in sessions:
        project = "unknown"
        for obs in session:
            p = obs.get("project")
            if p and p != "unknown":
                project = p
                break
        seq_counts = extract_sequences(session)
        global_sequences += seq_counts
        for seq, count in seq_counts.items():
            project_breakdown[seq][project] += count

    results = []
    for seq, count in global_sequences.most_common(20):
        if count < 2:
            continue
        meta = SEQUENCE_PATTERNS.get(seq, {})
        # Handle special single-element patterns
        if isinstance(seq, tuple) and len(seq) == 1:
            name = seq[0]
            domain = "sequence"
            if name == "repeated-edit":
                trigger = "같은 파일을 반복 편집할 때"
                action = "삽질 가능성. 3회 이상이면 접근법 재검토."
            elif name == "commit-and-done":
                trigger = "작업 완료 시"
                action = "커밋 후 세션 종료 패턴. 자연스러운 작업 마무리."
            elif name == "multi-file-create":
                trigger = "새 기능 scaffolding 시"
                action = "다중 파일 연속 생성. 템플릿/제너레이터 활용 고려."
            else:
                trigger = f"{name} 상황 발생 시"
                action = f"{name} 패턴 인식."
        else:
            name = meta.get("name", "->".join(seq) if isinstance(seq, tuple) else str(seq))
            domain = meta.get("domain", "sequence")
            trigger = meta.get("trigger", f"{name} 상황 발생 시")
            action = meta.get("action", f"{name} 패턴 인식.")

        # Project breakdown string
        breakdown = project_breakdown[seq]
        proj_str = ", ".join(f"{p}: {c}" for p, c in breakdown.most_common(5))
        projects_list = ", ".join(p for p, _ in breakdown.most_common(5))

        results.append({
            "type": "sequence",
            "name": f"sequence-{name}",
            "count": count,
            "domain": domain,
            "description": f"{name} 시퀀스 {count}회 관찰 ({proj_str})",
            "trigger": trigger,
            "action": action,
            "project": projects_list,
        })

    return results


# ---------------------------------------------------------------------------
# Main: read stdin, analyze, output TSV
# ---------------------------------------------------------------------------

def main():
    observations = []
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            observations.append(json.loads(line))
        except json.JSONDecodeError:
            continue

    if not observations:
        sys.exit(0)

    sessions = detect_sessions(observations)

    # Collect all patterns
    all_patterns = []
    all_patterns.extend(aggregate_sequence_patterns(sessions))
    all_patterns.extend(extract_project_patterns(sessions))

    # Output TSV: type, name, count, domain, description, trigger, action, project
    for p in all_patterns:
        cols = [
            p.get("type", ""),
            p.get("name", ""),
            str(p.get("count", 0)),
            p.get("domain", ""),
            p.get("description", ""),
            p.get("trigger", ""),
            p.get("action", ""),
            p.get("project", ""),
        ]
        print("\t".join(cols))


if __name__ == "__main__":
    main()
