---
name: L5 성숙도 로드맵
description: "하네스 4.5→5.0 달성을 위한 단계별 액션. 자기 진화(4.0→5.0)가 핵심 병목."
type: project
---

# L5 성숙도 로드맵

**현재**: 4.5/5.0 (2026-04-01 기준)
**병목**: 자기 진화 4.0 — 나머지 6개 평균 4.58

## 3단계 로드맵

### 1단계: 데이터 축적 (자연 달성 ~2주)
- 평소처럼 사용하면 observations.jsonl + agent-usage 자동 축적
- instinct confidence 0.65 → 0.7 도달 시 evolved skill 자동 생성
- **Why:** 파이프라인은 완성, 데이터만 부족
- **How to apply:** 별도 작업 불필요, 회사+집 양쪽 사용으로 가속

### 2단계: instinct 품질 개선 ✅ (2026-04-02 완료)
- observer-analyzer.py 도입: 빈도 카운팅 → 시퀀스/프로젝트 패턴 분석
- memory-post-tool.py 보강: date, project, Skill 필드 추가
- 기존 자명한 instinct 3개(tool-Bash/Edit/Write) 삭제 후 리셋
- 첫 행동 수준 instinct 생성 확인: `sequence-edit-then-build` (haru, count:3)
- **검증**: Opus critic → 설계 검증, E2E 파이프라인 테스트 통과

### 3단계: 피드백 루프 자동화
- failure-log ↔ /review-week 자동 연계
- friction=0 규칙 자동 감지 (은퇴 후보)
- Self-Absorb 제안의 자동 적용
- **Why:** 수동 의존 구간이 남아있음
- **How to apply:** evolved skill 첫 생성 확인 후 진행

## 점수 이력
| 날짜 | 종합 | 자기 진화 | 비고 |
|------|------|-----------|------|
| 2026-03-29 | 4.3 | 3.5 | 최초 Opus 평가 |
| 2026-03-30 | 4.3 | 4.0 | 훅/자기진화 각 +0.5 |
| 2026-04-01 | 4.5 | 4.0 | agent-tracker 등록 + failure-log 7건 |
