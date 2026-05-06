# Agent Orchestration

## Agent Catalog

두 실행면을 함께 관리한다.

- Claude runtime: `~/.claude/agents/*.md`
- Codex runtime: 루트 `AGENTS.md`의 역할 정의 + native subagent catalog

이 문서는 카탈로그를 중복 나열하기보다 선택 기준과 handoff 규약을 고정한다.

## Agent 선택 가이드

```
사용자 요청 → 어떤 에이전트?
├─ "탐색/검색" → explore
├─ "설계/아키텍처" → architect
├─ "계획 세워줘" → planner
├─ "구현/수정" → executor
├─ "리뷰" → reviewer / Expert Pool (아래 참조)
├─ "버그 수정" → debugger → executor
├─ "테스트/검증" → test-engineer 또는 verifier
├─ "빌드 실패" → build-fixer
└─ "문서" → writer
```

모델 티어보다 역할 적합성을 먼저 본다. 고위험 작업은 `reviewer`/`verifier`를 구현 경로와 분리한다.

## Review Expert Pool (규모 + 민감도 기반)

리뷰는 항상 다수 병렬이 아니라, **변경 규모와 민감도**에 따라 선택한다.

| 변경 규모 | 리뷰어 | 근거 |
|-----------|--------|------|
| 소규모 (≤2파일, <50줄) | reviewer 1명 또는 로컬 2차 점검 | 빠른 sanity check면 충분 |
| 중규모 (3-5파일, 50-200줄) | reviewer + verifier | 구현/검증 분리 필요 |
| 대규모 (6+파일, 200줄+) | reviewer + verifier + security/architect 추가 검토 | 전면 리뷰 필요 |

### 보안 민감 경로 예외 (규모 무관 security-reviewer 필수)

아래 경로가 변경에 포함되면 **규모와 무관하게** security-reviewer를 추가한다:
- `client/` (외부 API 클라이언트 15개)
- `*Security*`, `*Auth*`, `*Token*` 패턴
- `config/application*.yml` (시크릿/인증 설정)
- `*Vault*`, `*Credential*` 패턴

## Structured Response Contract

구현·분석·검증 서브에이전트는 아래 형식을 따른다.

- **결과**: `SUCCESS | PARTIAL | FAILED`
- **변경 파일**: 경로 목록 또는 `없음`
- **핵심 내용**: 1-3줄
- **미해결 사항**: 없으면 `없음`
- **검증**: 수행한 확인 또는 `없음`

형식이 비어 있거나 핵심 항목이 누락되면 메인 에이전트가 추가 확인한다.

## Parallel Execution

독립 작업은 반드시 병렬 Task 호출. 순차 실행이 필요한 경우는 CLAUDE.md §2 참조.

## Immediate Agent Usage (사용자 요청 없이 자동 실행)

1. 복잡한 기능 요청 → **planner**
2. 코드 작성/수정 완료 → **reviewer** 또는 적절한 review expert
3. 버그 수정/신규 기능 → TDD 스킬 (`/springboot-tdd`, `/tdd`)
4. 아키텍처 결정 → **architect**
5. 구현 완료 보고 시 → **verifier** (표준 이상 변경에서 권장, 고위험 변경에서는 사실상 필수)

검증 프로토콜 → `rules/common/verification.md` 참조
