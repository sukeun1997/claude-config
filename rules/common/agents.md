# Agent Orchestration

## Agent Catalog

**Source of Truth**: `~/.claude/agents/*.md` (28개 정의 파일)

각 에이전트의 역할·모델·도구 제약은 해당 `.md` 파일의 YAML frontmatter에 정의되어 있다.
이 문서에는 카탈로그를 중복 유지하지 않는다.

## Agent 선택 가이드

```
사용자 요청 → 어떤 에이전트?
├─ "탐색/검색" → Explore (haiku)
├─ "설계/아키텍처" → architect (opus)
├─ "계획 세워줘" → planner (opus)
├─ "구현/수정" → executor (sonnet) 또는 deep-executor (opus)
├─ "리뷰" → Expert Pool (아래 참조)
├─ "버그 수정" → debugger (sonnet) → executor (sonnet)
├─ "테스트" → test-engineer (sonnet)
├─ "빌드 실패" → build-fixer (sonnet)
└─ "문서" → writer (haiku)
```

## Review Expert Pool (변경 규모별 리뷰어 선택)

리뷰 시 항상 3명 병렬이 아니라, **변경 규모에 따라 최적 리뷰어를 선택**한다.

| 변경 규모 | 리뷰어 | 근거 |
|-----------|--------|------|
| 소규모 (≤2파일, <50줄) | code-reviewer 1명 | 보안/품질 이슈 가능성 낮음 |
| 중규모 (3-5파일, 50-200줄) | code-reviewer + quality-reviewer | 로직 결함 가능성 증가 |
| 대규모 (6+파일, 200줄+) | code-reviewer + security-reviewer + quality-reviewer (병렬) | 전면 리뷰 필요 |

### 보안 민감 경로 예외 (규모 무관 security-reviewer 필수)

아래 경로가 변경에 포함되면 **규모와 무관하게** security-reviewer를 추가한다:
- `client/` (외부 API 클라이언트 15개)
- `*Security*`, `*Auth*`, `*Token*` 패턴
- `config/application*.yml` (시크릿/인증 설정)
- `*Vault*`, `*Credential*` 패턴

## Parallel Execution

독립 작업은 반드시 병렬 Task 호출. 순차 실행이 필요한 경우는 CLAUDE.md §2 참조.

## Immediate Agent Usage (사용자 요청 없이 자동 실행)

1. 복잡한 기능 요청 → **planner**
2. 코드 작성/수정 완료 → **code-reviewer**
3. 버그 수정/신규 기능 → TDD 스킬 (`/springboot-tdd`, `/tdd`)
4. 아키텍처 결정 → **architect**
5. 구현 완료 보고 시 → **verifier** (아래 자동 검증 위임 참조)

검증 프로토콜 → `rules/common/verification.md` 참조
