# Agent Orchestration

## Agent Catalog (subagent_type + model)

Task 호출 시 `subagent_type`과 `model` 파라미터를 아래 카탈로그에 맞춰 사용한다.

### Build & Analysis

| subagent_type | model | 용도 |
|---------------|-------|------|
| `Explore` | haiku | 코드베이스 탐색, 심볼/파일 매핑 |
| `analyst` | opus | 요구사항 명확화, 수용 기준 정의 |
| `planner` | opus | 태스크 시퀀싱, 실행 계획 |
| `architect` | opus | 시스템 설계, 경계/인터페이스 정의 |
| `debugger` | sonnet | 근본 원인 분석, 회귀 격리 |
| `executor` | sonnet | 코드 구현, 리팩토링 |
| `deep-executor` | opus | 복잡한 자율적 목표 지향 작업 |
| `verifier` | sonnet | 완료 증거 검증, 주장 검증 |

### Review

| subagent_type | model | 용도 |
|---------------|-------|------|
| `quality-reviewer` | sonnet | 로직 결함, 유지보수성, 안티패턴, 성능 |
| `security-reviewer` | sonnet | 취약점, 신뢰 경계, 인증/인가 |
| `code-reviewer` | opus | 종합 리뷰, API 계약, 하위 호환성 |
| `critic` | opus | 계획/설계 비판적 검토 |

### Domain Specialists

| subagent_type | model | 용도 |
|---------------|-------|------|
| `test-engineer` | sonnet | 테스트 전략, 커버리지, flaky 테스트 |
| `build-fixer` | sonnet | 빌드/툴체인/타입 오류 수정 |
| `designer` | sonnet | UX/UI 아키텍처, 인터랙션 설계 |
| `writer` | haiku | 문서, 마이그레이션 노트, 가이드 |
| `qa-tester` | sonnet | 인터랙티브 CLI/서비스 런타임 검증 |
| `scientist` | sonnet | 데이터/통계 분석 |
| `document-specialist` | sonnet | 외부 문서/레퍼런스 조회 |
| `git-master` | sonnet | git 작업, 커밋 이력 관리 |

## Agent 선택 가이드

```
사용자 요청 → 어떤 에이전트?
├─ "탐색/검색" → Explore (haiku)
├─ "설계/아키텍처" → architect (opus)
├─ "계획 세워줘" → planner (opus)
├─ "구현/수정" → executor (sonnet) 또는 deep-executor (opus)
├─ "리뷰" → code-reviewer + security-reviewer + quality-reviewer (병렬)
├─ "버그 수정" → debugger (sonnet) → executor (sonnet)
├─ "테스트" → test-engineer (sonnet)
├─ "빌드 실패" → build-fixer (sonnet)
└─ "문서" → writer (haiku)
```

## Parallel Execution

독립 작업은 반드시 병렬 Task 호출. 순차 실행이 필요한 경우는 CLAUDE.md §2 참조.

## Immediate Agent Usage (사용자 요청 없이 자동 실행)

1. 복잡한 기능 요청 → **planner**
2. 코드 작성/수정 완료 → **code-reviewer**
3. 버그 수정/신규 기능 → TDD 스킬 (`/springboot-tdd`, `/tdd`)
4. 아키텍처 결정 → **architect**
