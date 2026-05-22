# Harness KPI (이상 상태 정의)

/review-week 축 "이상 갭 분석"에서 참조. 첫 4주는 baseline 측정, 이후 gap 분석 시작.

| KPI | 이상값 | 측정 방법 | 비고 |
|-----|--------|-----------|------|
| executor 1차 성공률 | 80% | verifier PASS / 전체 executor 위임 | agent-usage-tracker 기준 |
| 삽질 없는 세션 비율 | 90% | friction_files=0 세션 / 전체 | sessions.jsonl 기준 |
| 규칙 friction 발생률 | <5% | 훅 경고 발생 세션 / 전체 | 낮을수록 규칙이 내재화됨 |
| Read:Edit ratio | ≥2.0 (baseline 누적 중) | sessions.jsonl total_reads/total_edits | 낮으면 파일 Read 선행 규칙 미작동 신호 |

## 진화 규칙
- 4주 연속 이상값 달성 시 → 이상값 5%p 상향 (지속 개선)
- baseline 측정 시작: 2026-04-04

## 주간 실측값

| 주차 | 삽질없는세션% | 총세션 | friction세션 | Read:Edit | 비고 |
|------|-------------|--------|------------|-----------|------|
| 2026-04-27~05-07 | 47.4% | 57 | 30 | 2.47 | prev week |
| 2026-05-01~05-07 | 51.6% | 31 | 15 | 2.86 | analysis week |
| 2026-05-15~05-22 | 25.0% | 4 | 3 | 1.35 | sessions 트래커 복구 직후 (5/8~5/15 8일 공백 제외) |

## 트래커 유효성 진단
- sessions.jsonl 마지막 기록 일자가 **3일 이상** 오래되면 세션 트래커 중단 의심 (7일+ 이면 긴급)
- /review-week 시 가장 먼저 확인: `tail -1 memory/metrics/sessions.jsonl | jq .date`
- 공백 발견 시 hooks/tool-tracker.sh 또는 settings.json hooks 섹션 점검
