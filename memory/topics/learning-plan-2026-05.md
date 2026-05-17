---
name: 2026-05 학습 플랜
description: 12주 백엔드 깊이 보강 — 스코프/DB/DDD/Kafka. 2026-05-17 자기평가에서 도출된 4개 보완점 중 1/5/2/4 진행.
type: project
status: active
created: 2026-05-17
target_completion: 2026-08-09
---

# 2026-05 학습 플랜 (12주)

## 배경
2026-05-17 자기 평가 — 종합 6.8/10, 미들 중상위, 시니어 미달.
4개 약점 중 외부 노출(3번) 제외하고 학습 깊이 4개 진행.

## 큰 그림

```
Week →  1   2   3   4   5   6   7   8   9   10  11  12
1번    ████████████████████████████████████████████████  매 PR 지속
5번    ████████████████████████████████████████████      매일 30분 누적
2번            ████████████████████████                  Week 3-7 회사 매각
4번                    ████████████████████              Week 5-8 회사 Consumer
```

## 항목별 KPI

| 항목 | 시작 | 종료 | KPI | 측정 위치 |
|------|------|------|-----|-----------|
| 1. 스코프 (AC/Out-of-scope/Done-when) | W1 | 지속 | 단일 spec 10회+ 반복편집 0건 | failure-log.md |
| 5. DB (Use The Index Luke + EXPLAIN) | W1 | W12 | 케이스 8건+, PR 인덱스 추가 2건+ | topics/db-query-cases.md |
| 2. DDD (이벤트 스토밍 + Vernon 4ch) | W3 | W7 | 매각 BC 재정렬 제안서 1건 | topics/learning-ddd.md |
| 4. Kafka (Idempotent/Outbox/DLT) | W5 | W8 | 회사 PR or 제안 4건 | topics/learning-kafka.md |

## 주차별 트래킹

### Week 1 (2026-05-17 ~ 2026-05-23)
- [ ] 1번: 다음 spec/plan부터 3줄 룰 적용 (CLAUDE.md §2 #4 발효)
- [ ] 5번: Use The Index Luke Ch.1 (Anatomy of an Index) — 45분
- [ ] 5번: 회사 banking-loan 슬로우 쿼리 1개 EXPLAIN 케이스 — 45분

### Week 2 (~ 2026-05-30)
- [ ] 5번: UTI Ch.2 (Where Clause) + 케이스 1
- [ ] 1번: 주간 KPI 점검 (`/review-week` 축에 통합 검토)

### Week 3 (~ 2026-06-06)
- [ ] 2번: 회사 매각/EOD/Loss 도메인 이벤트 스토밍 (A4, 2시간)
- [ ] 5번: UTI Ch.3 (Performance and Scalability) + 케이스 1

### Week 4 (~ 2026-06-13)
- [ ] 2번: Vernon "IDDD" Ch.1 Getting Started
- [ ] 5번: UTI Ch.4 + 케이스 1
- [ ] 🔍 1차 자기 평가 (1번 KPI / 5번 진도)

### Week 5 (~ 2026-06-20)
- [ ] 2번: Vernon Ch.2 Domains/Subdomains
- [ ] 4번: Idempotent Consumer 패턴 학습 + SaleSyncConsumer 적용 검토
- [ ] 5번: UTI Ch.5 + 케이스 1

### Week 6 (~ 2026-06-27)
- [ ] 2번: Vernon Ch.5 Entities
- [ ] 4번: Outbox 패턴 + 매각 상태 변경 적용 검토
- [ ] 5번: UTI Ch.6 + 케이스 1

### Week 7 (~ 2026-07-04)
- [ ] 2번: Vernon Ch.10 Aggregates + 매각 BC 재정렬 제안서 작성
- [ ] 4번: DLT + Retry Topic 패턴
- [ ] 5번: UTI Ch.7 + 케이스 1

### Week 8 (~ 2026-07-11)
- [ ] 4번: EOS 트레이드오프 정리 (적용 X, 이해만)
- [ ] 5번: 케이스 1
- [ ] 🔍 2차 자기 평가 (2번/4번 진도)

### Week 9-12 (~ 2026-08-09)
- 5번 누적 케이스 + 1번 KPI 유지
- W12: 종합 자기 평가 — 4개 항목 점수 변화 비교 (base: 6.8/10)

## 메타 룰

- 매주 일요일 `/review-week` 시 학습 플랜 점검을 축 추가
- 학습 노트는 도메인별 `topics/*.md`에 분리, 본 파일은 트래킹만
- 책 욕심 금지 — 4개 끝나기 전 다른 책 사지 않음
- 사이드 프로젝트(Haru/building)에 학습 적용 X — 회사 도메인에만 묶음 (강도 차이)

## 평가 이력

| 날짜 | 1번 KPI | 5번 누적 | 2번 진도 | 4번 진도 | 비고 |
|------|---------|----------|----------|----------|------|
| 2026-05-17 | base | 0건 | - | - | 시작 — 자기평가 종합 6.8/10 |
