# Runtime Coexistence

Claude와 Codex(`.omx`) 두 런타임이 동일 워크스페이스를 공유할 때 발생하는 충돌을 회피하기 위한 규칙.

## 적용 시점

- 같은 저장소에서 두 런타임 세션을 동시 또는 인접 시점에 사용할 때
- 운영 자원(DB, 시크릿, 공유 메모리)에 영향이 있는 변경을 할 때
- 멀티-머신/멀티-세션 환경에서 워크트리를 사용할 때

## Shared Resource Inventory

두 런타임이 같은 자원을 참조하는 경우 충돌·사고 위험이 높다. 아래 자원은 **단일 소스**이며 한쪽 런타임의 변경이 다른 쪽에 즉시 영향을 준다. 변경 시 두 런타임 모두 영향 평가 필요.

| 자원 | 위치 | 공유 위험 | 작업 규칙 |
|------|------|----------|----------|
| 운영 DB | `DATABASE_URL`이 가리키는 host | `pnpm prisma migrate dev`가 pending 마이그를 전부 적용 (4/24 사고 직접 원인) | 마이그레이션은 메인 세션 직접 실행. 서브에이전트 위임 금지. 두 런타임 동시에 같은 운영 DB 마이그 시도 금지 |
| `.env` (DATABASE_URL, API_KEY) | 프로젝트 루트 | 한 런타임의 `.env` 수정이 다른 런타임에 즉시 반영 | `LOCAL_*`/`PROD_*` 접두사 분리 (`rules/mcp/mysql-setup.md`). 실행 전 `echo $DATABASE_URL` 출력 |
| `.mcp.json` | `~/.claude/.mcp.json` | 평문 시크릿 노출 시 git push로 공개 노출 | env 값은 `${ENV_VAR}` 참조만. `~/.zshrc`에 export |
| `_prisma_migrations` 테이블 | DB | "applied" 기록만 남고 DDL 미실행 사례 (4/21 P2022 사고) | `deploy.sh` smoke test 필수 (`/api/...` 200 확인) |
| Active Context | `memory/active/{branch}.md` | 두 런타임이 같은 브랜치에서 작업 시 덮어쓰기 | 한 브랜치 = 한 런타임. 다른 런타임은 별도 워크트리 |
| `failure-log.md` | `memory/topics/failure-log.md` | session-end 훅이 양쪽에서 행 추가 시 중복 | `(date, fname, count)` 키 dedup (2026-04-25 적용) |

## 충돌 회피 원칙

1. **한 브랜치 = 한 런타임**: 동일 브랜치에서 두 런타임이 동시에 작업하지 않는다. 다른 런타임은 `git worktree add ../<branch>-codex`로 별도 워크트리 사용.
2. **마이그레이션은 메인 세션**: DB 스키마 변경(`prisma migrate`, `migration*.sql`)은 서브에이전트에 위임하지 않는다. 위임이 불가피하면 governance.yml의 마이그 가드 4항목을 프롬프트에 prepend.
3. **시크릿은 참조만**: `.env`/`.mcp.json`에 평문 시크릿 금지. `${ENV_VAR}` 참조만 사용하고 `~/.zshrc`에 export.
4. **Active Context는 단일 라이터**: 다른 런타임이 같은 브랜치의 active context를 갱신하고 있으면 직접 편집 대신 handoff 노트(`.omx/notepad.md` 또는 daily log)로 의사소통.

## 작업 시작 전 체크리스트

- [ ] 어느 런타임이 운영 DB를 만지는지 명시했는가
- [ ] 다른 런타임 세션이 동일 브랜치에서 활성 상태인지 확인했는가 (활성이면 워크트리 분리)
- [ ] 시크릿 변경 시 `${ENV_VAR}` 참조 패턴을 따르는가

## 레퍼런스

- 실행 오버레이: [`AGENTS.md`](../../AGENTS.md) — Codex 측 같은 정책 표
- 거버넌스 패턴: [`.claude/governance.yml`](../../.claude/governance.yml) — `.env`, `.mcp.json`, `prisma/migrations/**` 가드
- DB MCP 설정: [`rules/mcp/mysql-setup.md`](../mcp/mysql-setup.md) — `LOCAL_*`/`PROD_*` 분리 패턴
- 메모리 계층: [`rules/common/memory.md`](memory.md) — Active Context 갱신 정책
- 검증 정책: [`rules/common/verification.md`](verification.md) — 멀티런타임 변경 시 Standard 이상 검증
