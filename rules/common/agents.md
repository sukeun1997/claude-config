# Agent Orchestration

에이전트 목록/설명은 시스템이 세션마다 주입한다 (Claude: `~/.claude/agents/*.md`, Codex: 루트 `AGENTS.md`). 이 문서는 선택 기준과 handoff 규약만 고정한다. 모델 티어보다 역할 적합성을 먼저 보고, 고위험 작업은 `reviewer`/`verifier`를 구현 경로와 분리한다.

## Review Expert Pool (규모 + 민감도 기반)

리뷰는 항상 다수 병렬이 아니라, **변경 규모와 민감도**에 따라 선택한다.

| 변경 규모 | 리뷰어 | 근거 |
|-----------|--------|------|
| 소규모 (≤2파일, <50줄) | reviewer 1명 또는 로컬 2차 점검 | 빠른 sanity check면 충분 |
| 중규모 (3-5파일, 50-200줄) | reviewer + verifier | 구현/검증 분리 필요 |
| 대규모 (6+파일, 200줄+) | reviewer + verifier + security/architect 추가 검토 | 전면 리뷰 필요 |

### 보안 민감 경로 예외 (규모 무관 security-reviewer 필수)

아래 경로가 변경에 포함되면 **규모와 무관하게** security-reviewer를 추가한다:
- `client/` (외부 API 클라이언트)
- `*Security*`, `*Auth*`, `*Token*`, `*Vault*`, `*Credential*` 패턴
- `config/application*.yml` (시크릿/인증 설정)

## Structured Response Contract

응답 형식 정본은 [verification.md § 구조화된 응답 강제](verification.md)를 따른다. 형식이 비거나 핵심 항목이 누락되면 메인 에이전트가 추가 확인한다.

## Immediate Agent Usage (사용자 요청 없이 자동 실행)

1. 복잡한 기능 요청 → **planner**
2. 코드 작성/수정 완료 → 적절한 review expert (위 Pool 기준)
3. 버그 수정/신규 기능 → TDD 스킬 (`/springboot-tdd`, `/tdd`)
4. 아키텍처 결정 → **architect**
5. 구현 완료 보고 시 → **verifier** (표준 이상 변경에서 권장, 고위험 변경은 사실상 필수)

검증 프로토콜 → `rules/common/verification.md` 참조
