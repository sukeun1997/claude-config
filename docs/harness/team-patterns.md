# Team Architecture Patterns

새 워크플로우/스킬 설계 시 참조 (CLAUDE.md §8에서 이동 — 온디맨드 문서).

| 패턴 | 적합 상황 | 현재 사용처 |
|------|----------|------------|
| Pipeline | 순차 단계, 게이트 필요 | `/review`, `/feature` |
| Fan-out | 독립 태스크 병렬 실행 | `subagent-driven-development` |
| Producer-Reviewer | 구현 후 검증 루프 | 리뷰 Phase 3→4 |
| Expert Pool | 조건별 전문가 선택 | §4 리뷰 수준 자동 판단 |
| Supervisor | 위임+모니터링 | `deep-executor` |
| Hierarchical | 3계층+ 대규모 작업 | Team → 서브에이전트 |
