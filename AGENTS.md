# Codex Harness Contract

This workspace uses a Codex-native execution overlay on top of the existing `.claude` harness.

- `AGENTS.md` defines Codex execution flow: planning, delegation, verification, governance, and completion.
- `CLAUDE.md` and `rules/common/*.md` remain the domain and policy source of truth.
- When both apply, use `AGENTS.md` for execution behavior and `CLAUDE.md` for repo-specific constraints.

## Operating Principles

- 한국어 우선, 코드/기술 용어는 원문 유지
- 읽지 않은 파일은 추측하지 않음
- 작고 되돌리기 쉬운 변경은 직접 처리
- 표준 이상 변경은 생산과 검증을 분리
- unrelated cleanup 금지, 기존 스타일 우선
- 차단보다 경고와 검증 추천을 우선

## Layered Context

| Layer | Surface | Purpose |
|------|---------|---------|
| Global | 사용자 전역 `AGENTS.md`, `CLAUDE.md`, `rules/common/` | 공통 실행 규약과 전역 정책 |
| Project | 저장소 루트 `AGENTS.md`, `CLAUDE.md` | 프로젝트 전체 운영 계약 |
| Module | 하위 디렉터리 `AGENTS.md`/`CLAUDE.md` | 모듈별 예외, 불변식, 진입점 |

해석 우선순위:

`Module > Project > Global`

## Document Roles

| File | Role |
|------|------|
| `AGENTS.md` | Codex execution overlay. 작업 흐름, 위임, 검증, 완료 조건 |
| `CLAUDE.md` | 도메인 정책, 레거시 Claude runtime 규칙, 전역 행위 기준 |
| `rules/common/*.md` | 세부 규칙 모듈. layered context, memory, governance, verification, agents |

## Memory Mapping

Codex/OMX에서는 아래를 기본 메모리 계층으로 사용한다.

| Layer | File/Path | Purpose |
|------|-----------|---------|
| Active | `.omx/state/` | 현재 작업 상태, phase, runtime flags |
| Hot | `.omx/notepad.md` | handoff, 현재 리스크, 다음 단계 |
| Always | `.omx/project-memory.json` | 프로젝트 구조, 장기 지침, 지속 기억 |
| Cold | `memory/topics/*.md` | 긴 참고 자료, 회고, 상세 배경 |

규칙:

- 세션이 길어지거나 압축 위험이 있으면 `.omx/notepad.md`에 현재 handoff를 남긴다.
- 반복적으로 재사용할 구조/지침은 `.omx/project-memory.json`에 승격한다.
- 상세 배경과 장문 회고는 `memory/topics/*.md`로 보낸다.

## Execution Protocol

1. 편집 전 짧은 계획을 세운다.
2. 하네스 문서나 훅을 바꿀 때는 관련 규칙 문서를 먼저 읽는다.
3. 단일 파일의 작고 가역적인 수정은 직접 처리한다.
4. 독립적인 병렬 조사나 검증은 native subagent를 사용한다.
5. 구현이 끝나면 변경 규모와 민감도에 맞는 검증을 수행한다.

기본 역할:

- `explore`: 빠른 경로/심볼/파일 조사
- `planner`: 구현 전 계획과 완료 조건 정리
- `executor`: 실제 수정
- `reviewer`: 로직/리스크 검토
- `verifier`: 검증 증거 점검

## Subagent Contract

구현·분석·검증 서브에이전트에는 아래 형식을 요구한다.

- 결과: `SUCCESS | PARTIAL | FAILED`
- 변경 파일: 경로 목록 또는 `없음`
- 핵심 내용: 1-3줄
- 미해결 사항: 없으면 `없음`
- 검증: 실행한 확인 사항 또는 `없음`

메인 에이전트는 이 형식이 없으면 결과를 그대로 신뢰하지 않는다.

## Verification Policy

검증 수준은 변경량보다도 리스크를 우선한다.

| Level | Trigger | Minimum checks |
|------|---------|----------------|
| Light | 문서/단일 파일/저위험 수정 | diff 점검, 문법 또는 렌더링 sanity check |
| Standard | 2-5파일, 동작 변경, 훅/스크립트 변경 | 관련 명령 실행, 대상 범위 리뷰, 필요 시 reviewer/verifier 분리 |
| Full | 인증/보안/배포/스키마/메모리 계약/6+파일 변경 | build or lint equivalent + targeted tests + reviewer/verifier or security review |

원칙:

- 구현자가 빠른 sanity check를 수행할 수는 있다.
- 완료 선언은 표준 이상 변경에서 별도 리뷰 경로를 거친 뒤 한다.
- 실패한 검증은 숨기지 않고 수정 후 다시 확인한다.

## Governance Warnings

아래 경로는 차단 대신 검증 추천을 띄운다.

- `AGENTS.md`, `CLAUDE.md`, `rules/common/*.md`: 상호 일관성 리뷰
- `.claude/governance.yml`: 규칙 중복/누락 점검
- `.omx/*.json`, `.omx/notepad.md`: 형식 및 로더 호환성 확인
- `hooks/*`, `scripts/*`: 문법 검사와 관련 스모크 테스트
- `settings*.json`: JSON 검증과 실제 로딩 경로 확인
- `prisma/migrations/**`, `**/migration*.sql`: 타겟 DB 확인 + dry-run + 사용자 승인 (4/21·4/24 사고 대응)
- `**/.env`, `**/.mcp.json`: 평문 시크릿 차단 (`${ENV_VAR}` 참조만), DATABASE_URL 변경 시 LOCAL_*/PROD_* 분리 확인

## Shared Resource Inventory (Codex ↔ Claude 공유 상태)

두 런타임이 같은 자원을 참조하는 경우 충돌/사고 위험이 높다. 아래 자원은 **단일 소스**이며 한쪽 런타임의 변경이 다른 쪽에 즉시 영향을 준다. 변경 시 두 런타임 모두 영향 평가 필요.

| 자원 | 위치 | 공유 위험 | 작업 규칙 |
|------|------|----------|----------|
| 운영 DB | DATABASE_URL이 가리키는 host | `pnpm prisma migrate dev`가 pending 마이그 전부 적용 (4/24 사고 직접 원인) | 마이그레이션은 메인 세션 직접 실행. 서브에이전트 위임 금지. 두 런타임이 동시에 같은 운영 DB에 마이그 시도 금지 |
| `.env` (DATABASE_URL, API_KEY) | 프로젝트 루트 | 한 런타임의 .env 수정이 다른 런타임에 즉시 반영 | LOCAL_*/PROD_* 접두사 분리 (`rules/mcp/mysql-setup.md`). 실행 전 `echo $DATABASE_URL` 출력 |
| `.mcp.json` | `~/.claude/.mcp.json` | 평문 시크릿 노출 시 git push로 공개 노출 | env 값은 `${ENV_VAR}` 참조만. `~/.zshrc`에 export |
| `_prisma_migrations` 테이블 | DB | "applied" 기록만 남고 DDL 미실행 사례 (4/21 P2022 사고) | deploy.sh smoke test 필수 (`/api/...` 200 확인) |
| Active Context | `memory/active/{branch}.md` | 두 런타임이 같은 브랜치에서 작업 시 덮어쓰기 | 한 브랜치 = 한 런타임. 다른 런타임은 별도 워크트리 |
| `failure-log.md` | `memory/topics/failure-log.md` | session-end 훅이 양쪽에서 행 추가 시 중복 | (date,fname,count) 키 dedup (2026-04-25 적용) |

작업 시작 전 체크:

- 마이그레이션/배포 작업 → 어느 런타임이 운영 DB를 만지는지 명시
- 다른 런타임 세션이 활성 상태면 동시 마이그 금지 (`.env`의 DATABASE_URL 같으면 충돌 가능)
- 시크릿 변경 → `.zshrc` 환경변수 + `${ENV_VAR}` 참조 패턴 강제

## Completion

완료 전 확인:

- 변경이 사용자 의도와 일치하는가
- 관련 규칙 문서와 충돌하지 않는가
- 필요한 검증을 실제로 실행했는가
- 남은 리스크를 명시했는가
