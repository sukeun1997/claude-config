---
name: review-week
description: "Claude Code 주간 활용 리뷰. 메모리에서 이번 주 작업 패턴을 분석하여 프롬프트 품질, 워크플로우 비효율, 기술 성장 포인트, 액션 아이템을 도출. Use when user says '/review-week', '주간 리뷰', 'weekly review'."
---

# Claude Code 주간 활용 리뷰 — 자기 진단 스킬

매주 메모리 기반으로 사용 패턴을 분석하고, 비판적 피드백과 구체적 액션 아이템을 제공하는 스킬.

## When to Apply

- 사용자가 `/review-week` 또는 "주간 리뷰" 요청 시
- 주 1회 (금요일 또는 주말) 실행 권장

## Pipeline

```
Phase 0: Failure-Log Gate (미분류·추정 점검)
  → failure-log.md 스캔 → 3건 이상이면 리뷰 선행 분류 요구
  → --skip-gate 플래그 시 우회

Phase 1: Data Collection (메모리 검색)
  → memory_search로 이번 주 작업 패턴 수집
  → notepad, plans, project-memory 포함

Phase 2: Analysis (4개 축 분석)
  → 프롬프트 품질 진단
  → 워크플로우 비판적 리뷰
  → 기술 성장 포인트
  → 액션 아이템 도출

Phase 3: Output (결과 출력)
  → 대화에 전체 리뷰 표시
  → vault에 자동 저장 (Codex 리포트 컨벤션 미러)
  → 사용자 요청 시 Notion에 기록

Phase 4: Memory (핵심 발견 저장)
  → 반복되는 패턴을 auto memory에 기록
```

## Phase 0: Failure-Log Gate

미분류/추정 항목이 적체된 상태에서 KPI 분석을 하면 피드백 루프 단절 지점이 가려진다. 분석 전에 이 병목부터 해소한다.

### 게이트 실행

```bash
python3 << 'EOF'
import re
from pathlib import Path
p = Path.home() / '.claude/memory/topics/failure-log.md'
if not p.exists(): exit(0)
lines = p.read_text().splitlines()
row_re = re.compile(r'^\|\s*\d{4}-\d{2}-\d{2}\s*\|')
pending = []
for i, line in enumerate(lines, 1):
    if not row_re.match(line): continue
    cells = [c.strip() for c in line.split('|')]
    if len(cells) < 5: continue
    if '[EXTERNAL]' in cells[2]:  # cells[2] = 증상 열 (날짜|증상|원인|해법 4열 테이블)
        continue  # 외부 사례는 자체 friction 카운트에서 제외 (rules/common/verification.md § 테스트 불변성 4주 friction 0건 트리거 보호)
    layer = cells[3]
    if '미분류' in layer or '(추정' in layer:  # '(추정·N회)' pre-fill 포맷 포함 매칭 (2026-07-12 게이트 거짓 통과 수정)
        pending.append((i, cells[2], layer))
print(f'PENDING_COUNT={len(pending)}')
for row in pending[:10]:
    print(f'  L{row[0]}: {row[1]} → {row[2]}')
EOF
```

### 게이트 판단

- **PENDING_COUNT < 3**: 게이트 통과, Phase 1로 진행
- **PENDING_COUNT >= 3** AND `--skip-gate` 없음:
  → 사용자에게 먼저 분류 요청
  → "failure-log에 N건의 미분류/추정 항목이 있습니다. 리뷰 전에 분류하는 것이 피드백 루프 정확도를 높입니다."
  → 표시된 행 리스트 제공
  → 사용자 선택지:
    (A) 지금 분류 (Read failure-log.md → 직접 수정 → /review-week 재호출)
    (B) `--skip-gate`로 강제 진행
    (C) 리뷰 취소

### 게이트 스킵 조건

- 사용자가 명시적으로 `/review-week --skip-gate` 호출
- 이전 세션에서 스킵 합의가 있었음을 사용자가 언급

### 근거

"(추정)" 행은 모델이 경로/횟수 휴리스틱으로 pre-fill한 것 — 사용자 검증이 없으면 instinct confidence 부스팅 경로(failure-log-instinct-boost.py)가 작동하지 않아 자기진화 루프가 멈춘다. 이는 하네스 성숙도 L5 진입의 병목이다. KPI 분석(Phase 2 축 2)은 이 신호가 반영된 후에 해야 의미가 있다.

---

## Phase 1: Data Collection

### 필수 검색 쿼리 (3개 병렬 실행)

```
memory_search("프롬프트 사용 패턴 워크플로우 작업", top_k=10)
memory_search("토큰 비용 컨텍스트 최적화 비효율", top_k=10)
memory_search("설정 구성 변경 디버깅 구현", top_k=10)
```

### 추가 데이터 소스

- `.omc/notepad.md` — 최근 세션 기록
- `.omc/plans/*.md` — 이번 주 생성된 플랜 파일
- `project-memory.json` — 프로젝트별 컨텍스트
- MEMORY.md — 영구 메모리
- **Codex 세션**: 각 날짜에 대해 `python3 ~/.claude/scripts/codex-harvest.py --date {YYYY-MM-DD} --json` 실행 (주간 7일분)
- **Friction 분석**: `python3 ~/.claude/scripts/friction-rule-scanner.py --write` 실행 → `memory/metrics/friction-YYYY-MM-DD.md` 생성. 원인 계층 분포 + 재발 파일 + 룰 방지 실패 횟수가 포함된다. Phase 2 축 2 근거로 직접 인용.

### 수집할 정보

1. **이번 주 작업 목록** — 어떤 프로젝트에서 무엇을 했는지
2. **사용한 에이전트/모드** — ralph, ralplan, autopilot, team 등
3. **반복된 패턴** — 같은 유형의 작업을 여러 번 했는지
4. **설정 변경 이력** — CLAUDE.md, MCP 라우팅 등 메타 작업

## Phase 2: Analysis

### 분석 프레임워크 (4개 축)

수집된 데이터를 아래 4개 축으로 분석한다. **칭찬보다 개선점 위주, 추상적 조언 금지, 모든 제안에 구체적 예시 포함.**

---

### 축 1: 프롬프트 품질 진단

메모리에서 추출한 실제 사용 패턴을 분석.

**체크리스트:**
- [ ] 스코프가 명확한가? ("~해줘" vs "~만 해줘. 다른 건 건드리지 마")
- [ ] 컨텍스트 전달이 충분한가? (도메인 용어, 제약조건, 기대 출력 형식)
- [ ] 불필요한 대화형 논의가 있는가? (선언적으로 끝낼 수 있는 것)
- [ ] 세션 분리가 되어 있는가? (대규모 작업을 한 세션에 넣지 않았는지)

**출력 형식:**

| 패턴 | Before | After | 효과 |
|------|--------|-------|------|
| 패턴명 | 실제 사용한 프롬프트 | 개선된 버전 | 기대 효과 |

---

### 축 2: 워크플로우 비판적 리뷰

**체크리스트:**
- [ ] 메타 작업 비율 — 도구 설정 vs 실제 개발 작업 비율
- [ ] 토큰 낭비 지점 — 불필요한 tool call, 과도한 에이전트 사용
- [ ] 세션 관리 — 한 세션에 너무 많은 것을 넣지 않았는지
- [ ] 모델 선택 — Opus가 필요하지 않은 곳에 Opus를 쓰지 않았는지
- [ ] CLAUDE.md 무게 — 시스템 프롬프트가 과도하지 않은지
- [ ] 자동화 가능한 반복 작업이 있는지
- [ ] Convention Drift — 최근 커밋 diff에서 CLAUDE.md §5 위반 샘플링 (축약 변수명, 하드코딩, 50줄+ 함수, Read:Edit 비율 하락 추세)
- [ ] Friction Rule Effectiveness — friction-rule-scanner.py 출력의 `§3. 규칙 효과` 섹션에서 3건+ 재등장 룰 식별. 해당 룰은 **방지 실패** 상태로 보고 (a) 룰 강도 상향, (b) 훅으로 자동화 전환, (c) 은퇴 중 하나를 축 4 액션 아이템에 반영
- [ ] **Test Inviolability 효과성** — failure-log에서 `[EXTERNAL]` 태그를 제외한 자체 friction 중 "테스트 변조" 관련 행 개수. 4주 연속 0건이면 verification.md § 테스트 불변성 섹션을 **은퇴 후보**로 액션 아이템에 등록 (eval-based harness evolution). 카운트 시 외부 사례 행은 노이즈이므로 반드시 분리
- [ ] Codex vs Claude 작업 분배 — Codex로 위임 가능한 작업을 Claude에서 직접 처리하지 않았는지
- [ ] Codex 세션 효율 — tool_call_count=0 세션 비율, 같은 프로젝트 동시 작업 시 충돌 여부

**출력 형식:**

토큰/비용 낭비 TOP 3를 순위표로:

| 순위 | 원인 | 상세 |
|------|------|------|
| 1위 | ... | ... |

자동화 가능한 반복 작업:

| 반복 작업 | 현재 | 자동화 방안 |
|-----------|------|------------|
| ... | ... | ... |

---

### 축 3: 기술 성장 포인트

**체크리스트:**
- [ ] AI에 과도하게 의존하는 영역 (코드 안 읽고 커밋, 디버깅 위임 등)
- [ ] 테스트 작성 여부
- [ ] 디버깅 시 근본 원인 분석 습관
- [ ] 아키텍처 결정의 주체성 (AI가 판단 vs 본인이 판단)
- [ ] 회사 활용 시 주의점 (개인 프로젝트 습관의 위험)

**개인 vs 회사 전략 비교표 (매주 업데이트):**

| 항목 | 개인 프로젝트 | 회사 |
|------|-------------|------|
| AI 역할 | Lv.4 증폭기 | Lv.2 파트너 |
| 코드 리뷰 | AI → 커밋 | AI → 직접 읽기 → 커밋 |
| 모델 | Opus | Sonnet |
| OMC | 적극 사용 | 사용 금지 |
| 커밋 | 자동 가능 | 반드시 diff 확인 |

**보강 기술 영역:**

| 영역 | 현재 문제 | 개선 방향 |
|------|----------|----------|
| ... | ... | ... |

---

### 축 4: 다음 주 액션 아이템

수집된 분석을 기반으로 도출:

1. **즉시 적용할 프롬프트 개선 3개** — Before/After 형식
2. **바꿔야 할 습관 1개** — 구체적 행동 수준
3. **새로 만들거나 개선할 워크플로우 1개** — 구현 방법 포함

**출력 형식:**

| # | 개선 | Before | After |
|---|------|--------|-------|
| 1 | ... | ... | ... |

---

### 축 5: 성숙도 점수 (8축 + L1-L5 병기)

**왜 양쪽 점수가 필요한가**: 8축 가중평균은 각 영역의 발전을 보여주지만 약한 고리 부재를 가린다. L1-L5는 약한 고리가 등급을 결정하므로 self-healing 갭을 즉시 노출. 같은 "성숙도" 단어를 둘 다 쓰면 4.7→3.5 같은 척도 혼동이 발생하므로 **반드시 두 점수를 함께 출력**한다.

**8축 모델** (가중평균 0-5):

| 축 | 측정 항목 | 점수 (이번주 / 지난주) |
|---|---|---|
| 1. 메모리 | MEMORY.md 정합성, topics 활용, [PROMOTE] 처리율 | / |
| 2. 운영 | governance.yml 매칭, state 일관성, hook 건강성 | / |
| 3. 스킬 | auto-routing 정확도, 스킬 중복/충돌, 신규 흡수 | / |
| 4. 에이전트/오케스트레이션 | model 티어 정확도, 병렬화, 위임 비율 | / |
| 5. 검증 | Sprint Contract 적용률, verifier PASS율, 경계면 발견 | / |
| 6. 자기진화 | sessions.jsonl 연속성, instinct confidence, friction 은퇴 | / |
| 7. 토큰 효율 | MCP 출력 절감, 서브에이전트 위임률, 중복 Read 비율 | / |
| 8. 훅 인프라 | settings.json 무결성, hook 실패율, captures→metrics 정합 | / |
| **종합 (가중평균)** | | **/ 5.0** |

**L1-L5 모델** (가장 약한 고리가 등급 결정):

| 등급 | 기준 | 충족 여부 |
|---|---|---|
| L1 | 기본 에이전트 카탈로그 + 메모리 | ☐ |
| L2 | 자동 라우팅 + 생산/검증 분리 | ☐ |
| L3 | KPI 정의 + Eval 기반 자기 진화 트리거 존재 | ☐ |
| L4 | 측정 인프라 self-healing + 자동 cleanup + 갭 자동 에스컬레이션 | ☐ |
| L5 | 완전 자율 진화 (룰/스킬 자동 생성·은퇴) | ☐ |
| **현재 등급** | | **L?.?** |

**산출 규칙**:
- 8축: 각 축의 KPI 측정값 → 0-5 정규화 → 가중평균. 측정 불가 축은 직전 주 값 carry-over하고 표시
- L1-L5: 모든 하위 등급 기준 충족 시에만 다음 등급. 한 항목 미충족이면 0.5 단위 감점 (예: L4 절반 충족 → 3.5)
- **갭 분석**: 8축 종합과 L1-L5 차이가 1.0+ 이면 "약한 고리 우선 개선" 권장 — 가중평균이 가린 self-healing 갭이 큰 신호

**점수 이력 갱신**: `memory/topics/l5-roadmap.md` 의 점수 이력 표에 한 줄 추가 (8축 종합과 L1-L5 양쪽).

---

## Phase 3: Output

### 대화 출력

전체 리뷰를 마크다운으로 대화에 표시. 구조:

```
# Claude Code 주간 활용 리뷰 — {연도}년 {월}월 {주}주차 ({시작일}~{종료일})

### 이번 주 작업 요약
...

### 1. 프롬프트 품질 진단
(표 포함)

### 2. 워크플로우 비판적 리뷰
(표 포함)

### 3. 기술 성장 + 회사 활용 방향
(표 포함)

### 4. 다음 주 액션 아이템
(표 포함)

### 5. 성숙도 점수 (8축 / L1-L5)
(양쪽 표 + 갭 분석 1-2줄)

> **핵심 한 줄**: ...
```

### Vault 저장 (자동 — Codex 리포트 컨벤션 미러)

대화 출력 후, 리뷰 전문을 아래 경로에 저장한다 (디렉토리 없으면 생성):

```
~/vault/30 학습/개념/하네스 개선/Claude/{YYYY-MM-DD}-claude-weekly-review.md
```

- 파일 헤더: `# Claude Weekly Review` + Generated/Window/Score 요약 (Codex `self-improvement/reports/*-codex-weekly-review.md` 형식과 통일)
- `## Summary`에 Score(8축/L1-L5), Main pattern, Biggest wasted loop, Best leverage 4줄 포함
- 경로에 공백 포함 — bash 사용 시 `"$HOME/vault/30 학습/..."` 인용 필수
- 저장은 사용자 요청 불필요 (Notion 기록과 달리 기본 동작)

### Notion 기록 (사용자 요청 시)

사용자가 "노션에도 정리해줘"라고 하면:

1. `search_notion("AI")` → "AI" 페이지 찾기
2. "AI 주간 분석" 헤더 아래에 내용 추가
3. 별도 하위 페이지로 생성: `{연도}년 {월}월 {주}주차 ({시작일}~{종료일})`
4. 비교 부분은 모두 Notion 네이티브 표로 변환

## Phase 4: Memory

### 리뷰 후 저장할 것

- 이번 주 발견된 **새로운 비효율 패턴** → auto memory에 기록
- **지난주 액션 아이템 실행 여부** 추적 → 다음 주 리뷰에서 확인
- 반복되는 문제는 CLAUDE.md에 규칙으로 승격

## Output Rules

1. **칭찬보다 개선점 위주**. 비판적이고 솔직하게.
2. **추상적 조언 금지**. 모든 제안에 구체적 예시 포함.
3. **Before/After 형식 적극 활용**.
4. **비교하는 모든 부분은 표(table) 형식으로**.
5. 핵심 한 줄 요약으로 마무리.

## Prerequisites

- memory-search MCP 서버 활성화 (memory_search, memory_index)
- Notion 기록 시: `plugin:Notion:notion` MCP 서버 연결 확인 (`/mcp`)
