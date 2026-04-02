# Observer Analyzer 패턴 추출 품질 개선

**Date**: 2026-04-02
**Status**: Approved (Opus 검증 완료)
**Scope**: v1 — 시퀀스 패턴 + 프로젝트별 패턴

---

## 문제

`observer-runner.sh`의 패턴 추출이 단순 빈도 카운팅(`Counter()` + `tool:{tool}`)으로, 생성된 instinct가 "Bash used 48 times" 수준의 자명한 패턴. L5 자기 진화 병목.

## 목표

observations.jsonl에서 **행동 수준**의 의미 있는 패턴을 추출하여 instinct 품질 향상.

## v1 범위

1. 시퀀스 패턴 탐지 (중립 라벨)
2. 프로젝트별 패턴 그룹핑
3. 데이터 소스 보강 (date, project, Skill 이벤트)

## v2 (향후)

- Bash status 필드 디버깅 → 성공/실패 라벨 추가
- failure-log.md 교차 분석 (시간 정밀도 확보 후)

---

## 변경 파일

| 파일 | 변경 | 유형 |
|------|------|------|
| `hooks/memory-post-tool.py` | date + project 필드 추가, Skill 캡처 활성화 | 수정 |
| `hooks/observer-analyzer.py` | 시퀀스 + 프로젝트 패턴 분석기 | 신규 |
| `hooks/observer-runner.sh` | 인라인 Python → analyzer 호출 | 수정 |
| `homunculus/instincts/personal/*.md` | 기존 3개 삭제 | 삭제 |
| `homunculus/.observer-cursor` | 리셋 (현재 라인으로) | 수정 |

---

## 1. 데이터 보강 (memory-post-tool.py)

### 1.1 entry에 date + project 추가

```python
# 기존 (line 270)
entry = {"ts": now.strftime("%H:%M:%S"), "tool": tool}

# 변경
entry = {
    "ts": now.strftime("%H:%M:%S"),
    "date": now.strftime("%Y-%m-%d"),
    "tool": tool,
    "project": detect_project(),
}
```

### 1.2 Skill 이벤트 캡처 활성화

```python
# CAPTURE_TOOLS에 Skill 추가
CAPTURE_TOOLS = {"Write", "Edit", "Bash", "Task", "Skill"}

# SKIP_TOOLS에서 Skill 제거
SKIP_TOOLS = {
    "Read", "Grep", "Glob", "ToolSearch",
    # "Skill" 제거
    ...
}
```

### 1.3 Skill 이벤트 처리 블록 추가

```python
elif tool == "Skill":
    skill_name = tool_input.get("skill", "unknown")
    entry["skill"] = skill_name
    if check_dedup(dedup_file, f"Skill:{skill_name}"):
        return
```

---

## 2. observer-analyzer.py (신규)

### 입력
- observations.jsonl의 새 관찰 (cursor 이후)
- stdin으로 전달 (observer-runner.sh가 tail로 추출)

### 출력
- stdout에 TSV: `{pattern_type}\t{pattern_name}\t{count}\t{domain}\t{description}\t{trigger}\t{action}\t{project}`

### 2.1 세션 경계 탐지

```python
def detect_sessions(observations: list[dict]) -> list[list[dict]]:
    """날짜 변경 또는 30분 이상 시간 갭 = 세션 경계"""
    sessions = []
    current = []
    for obs in observations:
        if current:
            prev = current[-1]
            # 날짜 다르면 새 세션
            if obs.get("date") != prev.get("date"):
                sessions.append(current)
                current = [obs]
                continue
            # 같은 날이면 시간 갭 체크 (30분 이상 = 새 세션)
            gap = time_gap_minutes(prev["ts"], obs["ts"])
            if gap > 30 or gap < 0:  # 역행도 세션 경계
                sessions.append(current)
                current = [obs]
                continue
        current.append(obs)
    if current:
        sessions.append(current)
    return sessions
```

### 2.2 시퀀스 패턴 탐지

세션 내에서 길이 2-4의 슬라이딩 윈도우로 도구 시퀀스 추출.

**패턴 정의** (중립 라벨, status 무관):

| 시퀀스 | 패턴명 | 의미 |
|--------|--------|------|
| `Edit→Bash(build)→Edit` | `build-check-cycle` | 빌드 확인 후 수정 반복 |
| `Edit→Bash(test)→Edit` | `test-check-cycle` | 테스트 확인 후 수정 반복 |
| `Write→Write→Write` (3+ 연속) | `multi-file-create` | 다중 파일 생성 |
| `Edit(같은파일)→Edit(같은파일)→Edit(같은파일)` | `repeated-edit` | 같은 파일 반복 수정 (삽질 후보) |
| `Edit→Bash(build)→Bash(test)` | `edit-build-test` | 수정→빌드→테스트 워크플로우 |
| `Bash(git)` 후 세션 종료 | `commit-and-done` | 커밋 후 세션 종료 |

**구현**:
```python
def extract_sequences(session: list[dict]) -> Counter:
    """세션 내 도구 시퀀스 추출"""
    patterns = Counter()
    for window_size in (2, 3):
        for i in range(len(session) - window_size + 1):
            window = session[i:i + window_size]
            seq = normalize_sequence(window)
            if seq in KNOWN_PATTERNS:
                patterns[seq] += 1
    # 같은 파일 반복 편집
    file_edits = Counter()
    for obs in session:
        if obs["tool"] in ("Edit", "Write") and "file" in obs:
            file_edits[obs["file"]] += 1
    for f, count in file_edits.items():
        if count >= 3:
            patterns["repeated-edit"] += 1
    return patterns
```

### 2.3 프로젝트별 패턴

세션을 project 기반으로 그룹핑 후, 프로젝트별 도구 사용 비율 분석.

```python
def extract_project_patterns(sessions: list[list[dict]]) -> list[dict]:
    """프로젝트별 워크플로우 특성 추출"""
    project_stats = defaultdict(lambda: {"tools": Counter(), "sequences": Counter(), "sessions": 0})
    for session in sessions:
        project = session[0].get("project", "unknown") if session else "unknown"
        stats = project_stats[project]
        stats["sessions"] += 1
        for obs in session:
            stats["tools"][obs["tool"]] += 1
        stats["sequences"] += extract_sequences(session)

    patterns = []
    for project, stats in project_stats.items():
        if stats["sessions"] < 2:
            continue
        # 지배적 도구 비율
        total = sum(stats["tools"].values())
        for tool, count in stats["tools"].most_common(3):
            ratio = count / total
            if ratio > 0.5:
                patterns.append({
                    "type": "project-tool-dominance",
                    "name": f"{project}-{tool.lower()}-heavy",
                    "project": project,
                    "description": f"{project}에서 {tool}이 {ratio:.0%} 비중",
                })
        # 지배적 시퀀스
        for seq, count in stats["sequences"].most_common(3):
            if count >= 3:
                patterns.append({
                    "type": "project-sequence",
                    "name": f"{project}-{seq}",
                    "project": project,
                    "description": f"{project}에서 {seq} 시퀀스 {count}회",
                })
    return patterns
```

### 2.4 도메인 세분화

| 패턴 유형 | domain |
|-----------|--------|
| 시퀀스 패턴 | `sequence` |
| 프로젝트별 패턴 | `project-workflow` |
| Skill 사용 패턴 | `skill-routing` |
| 에이전트 위임 패턴 | `delegation` |

evolve 조건(같은 domain 3개+)을 만족하려면 같은 종류의 패턴이 충분히 쌓여야 함.

### 2.5 instinct 포맷 (개선)

```yaml
---
name: sequence-build-check-cycle
description: "Edit→Bash(build)→Edit 시퀀스가 12회 관찰 (haru 8회, building 4회)"
domain: "sequence"
confidence: 0.45
source: observer-analyzer.py
observed_count: 12
created: 2026-04-02
trigger: "코드 수정 후 빌드 확인이 필요할 때"
action: "Edit→Build→확인→수정 사이클을 의식적으로 사용. 3회 이상 반복되면 접근법 재검토."
projects: "haru, building"
---

## Pattern
- **Type**: sequence
- **Sequence**: Edit → Bash(build) → Edit
- **Total Count**: 12
- **By Project**: haru: 8, building: 4
```

---

## 3. observer-runner.sh 변경

### 3.1 인라인 Python → analyzer 호출

```bash
# 기존: 인라인 Python Counter 블록 (line 39-70)
# 변경: observer-analyzer.py 호출
tail -n +"$((CURSOR + 1))" "$OBS_FILE" | \
  python3 "$HOME/.claude/hooks/observer-analyzer.py" > "$PATTERNS_FILE" 2>/dev/null || true
```

### 3.2 TSV 파싱 변경

analyzer 출력 포맷: `type\tname\tcount\tdomain\tdescription\ttrigger\taction\tproject`

instinct 생성 로직에서 domain/trigger/action을 analyzer 출력에서 직접 사용.

---

## 4. 마이그레이션

1. 기존 instinct 3개 삭제: `rm homunculus/instincts/personal/tool-*.md`
2. cursor를 현재 라인(151)으로 유지 (기존 데이터 건너뛰기)
3. 새 데이터부터 analyzer 적용

---

## 5. 완료 기준

1. 새 observations에 `date`, `project` 필드가 기록된다
2. Skill 이벤트가 observations.jsonl에 기록된다
3. 20건+ 새 관찰 후 SessionEnd에서 observer-analyzer.py가 실행된다
4. 생성된 instinct가 "행동 수준" (시퀀스명 + 프로젝트 + 횟수)이다
5. 기존 자명한 instinct(tool-Bash 등)가 재생성되지 않는다
6. instinct-evolve.sh와 호환된다 (domain/confidence 필드 존재)

## 6. 테스트 전략

- observer-analyzer.py를 직접 실행하여 샘플 데이터로 패턴 추출 확인
- 단위 테스트: 세션 경계 탐지, 시퀀스 패턴 매칭, 프로젝트 그룹핑
