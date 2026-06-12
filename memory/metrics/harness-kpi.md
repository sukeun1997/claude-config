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

## 주간 실측값

| 주차 | 삽질없는세션% | 총세션 | friction세션 | Read:Edit | 비고 |
|------|-------------|--------|------------|-----------|------|
| 2026-04-27~05-07 | 47.4% | 57 | 30 | 2.47 | prev week |
| 2026-05-01~05-07 | 51.6% | 31 | 15 | 2.86 | analysis week |
| 2026-06-05~06-11 | 0% | 2 | 2 | 3.0 | ktx 프로젝트, duration_min=0×2, 세션 희박 |

## 트래커 유효성 진단
- sessions.jsonl 마지막 기록 일자가 **7일 이상** 오래되면 세션 트래커 중단 의심
- /review-week 시 가장 먼저 확인: `tail -1 memory/metrics/sessions.jsonl | jq .date`
- 공백 발견 시 hooks/tool-tracker.sh 또는 settings.json hooks 섹션 점검
- `duration_min=0` 연속 3회+ → `$HOME/.claude/memory/sessions/.session-start-ts` 마커 비정상 의심 — memory-stop-guard.sh (line 66-73) 확인
