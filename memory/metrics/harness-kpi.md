# Harness KPI (이상 상태 정의)

/review-week 축 "이상 갭 분석"에서 참조. 첫 4주는 baseline 측정, 이후 gap 분석 시작.

| KPI | 이상값 | 측정 방법 | 비고 |
|-----|--------|-----------|------|
| executor 1차 성공률 | 80% | verifier PASS / 전체 executor 위임 | agent-usage-tracker 기준 |
| 삽질 없는 세션 비율 | 90% | friction_files=0 세션 / 전체 | sessions.jsonl 기준 |
| 규칙 friction 발생률 | <5% | 훅 경고 발생 세션 / 전체 | 낮을수록 규칙이 내재화됨 |

## 진화 규칙
- 4주 연속 이상값 달성 시 → 이상값 5%p 상향 (지속 개선)
- baseline 측정 시작: 2026-04-04
