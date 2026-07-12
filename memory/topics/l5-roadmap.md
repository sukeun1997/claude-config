---
name: L5 성숙도 로드맵
description: "하네스 4.5→5.0 달성을 위한 단계별 액션. 자기 진화(4.0→5.0)가 핵심 병목."
type: project
---

# L5 성숙도 로드맵

**현재**: 4.5/5.0 (2026-04-10 Opus critic 검증)
**병목**: 자기 진화 4.2 — evolved skill 미발동 + friction 기반 은퇴 실적 0건

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
| 2026-04-10 | 4.5 | 4.2 | Opus critic 조정: 오케스트레이션 4.7(5.0→), 자기진화 4.2(4.5→). evolved skill 미발동 + friction 은퇴 0건 |
| 2026-04-12 | - | - | 주간 리뷰 적용: SessionEnd 레이스 수정, confidence bump log2 스케일링, review-week codex 통합, dead code 정리 |
| 2026-04-18 | 4.7 | 4.6 | evolved skill 실적 + 관측 파이프 복구로 자기진화 4.2→4.6 |
| 2026-04-25 | 4.7→5.0 작업중 | - | 공유 상태 가드 적용 (4.7→5.0 갭 작업) |
| 2026-05-16 | 4.6 (8축) / L3.5 (L1-L5) | 4.3 | tool-tracker deprecated 후 captures fallback grep 패턴 불일치 → sessions.jsonl 5/8~5/15 공백 발견. 4건 패치 + 5건 backfill로 측정 파이프 복구. **이번 회차부터 8축 + L1-L5 양쪽 병기** (척도 혼동 방지). 자기진화 축 회귀(4.6→4.3) 후 패치 반영 시 4.6 복귀 예상 |
| 2026-05-23 | 4.4→4.6 (8축) / L3.0→L3.5 | 4.0→4.5 | 주간 리뷰: failure-log 미분류/추정 52건 적체(자기진화 4.0/L3.0 회귀). Context 55% + Read:Edit 룰 34회·반복편집 룰 26회 방지실패 = 프롬프트 룰 한계 확인. **조치**: (1) failure-log-classify.py self-healing 자동분류 52→0 + observer-runner 조기배치(재적체 방지, L4 자동cleanup 진입), (2) read-edit-gate.py PreToolUse 차단(경고@2→차단@3) = **friction 룰 첫 코드 enforcement 승격**(로드맵 "friction 은퇴/승격 0건" 병목 해소), (3) MEMORY 177→43줄. instinct(sequence-repeated-edit)는 이미 0.95 cap → confidence 아닌 자동화/enforcement가 실제 레버였음 |
| 2026-07-12 | 4.2 (8축) / L3.5 | 3.5 | 7주 리뷰 공백 후 재개. 하네스 감사→PR #23: agent-model-guard 훅 enforcement 승격(2호), 상시 로드 13% 절감, 죽은 훅 4개 정리, MCP 중복 3건 제거. 자기진화 3.5 회귀(리뷰 루프 7주 정지가 원인 — self-healing 분류는 작동, 미분류 0건). §9 자동 라우팅 스킬 9개 사용 0건 은퇴 검토 개시
