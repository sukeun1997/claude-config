# CLAUDE QUICKREF

> **정본**: [CLAUDE.md](CLAUDE.md). 본 문서는 빠른 결정 트리 요약 — drift 발견 시 정본 우선.
> **사용 시점**: 세션이 길어졌거나 컨텍스트 재로딩 후 핵심 규칙만 빠르게 재조회할 때 온디맨드 Read.

## Operating Principles

- 한국어 우선, 코드/기술 용어는 영어 원문 유지
- 작고 가역적인 변경은 직접 처리, 표준 이상은 생산-검증 분리
- 차단보다 경고와 검증 추천을 우선
- Filler 금지 — 모든 줄/함수/파일은 자기 자리값을 함

## Task Routing 결정 트리

| 작업 | 다음 행동 |
|------|----------|
| 단일 파일 ≤100줄 | 직접 실행 |
| 버그 수정 | `/sdebug` → 가설 2+개 시 `/triage` → 최소 수정 → `vc` |
| 설계 결정 필요 | 인터뷰 먼저 (모호 부분 지목 후 질문) |
| 2+파일 구현 | Plan-First. 6+파일·200줄+은 critic 검증 후 user approval |
| 사실 확인 | 매니페스트 정확매치 자동 / 코드 추론 1-tap / 외부 사실 WebFetch. 결정은 항상 사용자 |

## Verification Levels

| Level | Trigger | Minimum |
|-------|---------|---------|
| Light | 단일 문서/저위험 | diff + 문법 sanity |
| Standard | 2-5파일, 동작 변경 | 명령 실행 + reviewer 또는 verifier 분리 |
| Full | 6+파일, 200줄+, 인증/보안/스키마/메모리 계약/배포 | build/lint + targeted test + reviewer/verifier 분리 |

> 민감 경로(인증·DB·.env·.mcp.json·hooks·migrations·rules/common)는 규모 무관 Full.

## Memory Layers

| Layer | 위치 | 용도 |
|-------|------|------|
| Active | `memory/active/{branch}.md` | 현재 작업 (≤20줄) |
| Hot | `memory/daily/YYYY-MM-DD.md` | 당일 로그 |
| Always | `memory/MEMORY.md` (≤150줄) | 핵심 장기 기억 |
| Cold | `memory/topics/*.md` | 도메인 상세 (온디맨드) |

> Codex/OMX 매핑: Active=`.omx/state/`, Hot=`.omx/notepad.md`, Always=`.omx/project-memory.json`, Cold 공유.

## Subagent Contract (Structured Response)

서브에이전트 응답은 5필드 필수:
- **결과**: SUCCESS | PARTIAL | FAILED
- **변경 파일**: 경로 목록 또는 "없음"
- **핵심 내용**: 1-3줄
- **미해결 사항**: 없으면 "없음"
- **검증**: 수행한 확인 또는 "없음"

비어 있거나 누락이면 결과를 그대로 신뢰하지 않음.

## Auto Skill Routing (핵심)

| 트리거 | 스킬/에이전트 |
|--------|--------------|
| 새 기능 구현 시작 | `feature` (tech-advisor → bs → plans → execution) |
| 버그 수정 시작 | `/sdebug` → 가설 2+개면 `/triage` → 결과로 sdebug 복귀 |
| 빌드 실패 | `build-fixer` 에이전트 |
| 구현 후 일반 변경 | `code-reviewer` 자동 |
| 보안/인증/DB 스키마/아키텍처 변경 | code-reviewer + security-reviewer + quality-reviewer + architect 자동 |
| Sentry URL 또는 issue ID | `sentry-debug` |
| `.kt` / `.swift` 작성·수정 | `kotlin-patterns` / `everything-claude-code:swiftui-patterns` |
| JPA Entity·Repository | `everything-claude-code:jpa-patterns` |
| DB 마이그레이션 | §4 마이그 가드 4항목 + 메인 세션 직접 실행 |
| 기술 선택 포함 (학습 모드 ON) | `tech-advisor` (현 스택 내 라이브러리/패턴 대안 1-2개 제시) |
| URL 분석 + 설정 적용 | `absorb` (주 2회 배치) |
| plan/spec 저장 | `docs-save` (vault) |

> 학습 모드 OFF: 미확정 케이스만 tech-advisor. 명백한 1-2줄 수정·기존 패턴 추가는 ON이어도 스킵.

## Sensitive Path 가드 (governance.yml 핵심)

| 패턴 | 행동 |
|------|------|
| `**/.env`, `**/.mcp.json` | 평문 시크릿 금지, `${ENV_VAR}` 참조만 |
| `prisma/migrations/**`, `**/migration*.sql` | `echo $DATABASE_URL` + dry-run + 사용자 승인. 메인 세션 직접 |
| `*Test*.{kt,java,ts,...}`, `*.test.ts`, `test_*.py` | 테스트 불변성 — skip/disable/약화 검출 |
| `AGENTS.md`, `CLAUDE.md`, `rules/common/*.md` | 상호 일관성 리뷰 |
| `hooks/*`, `scripts/*`, `settings*.json` | 문법 검사 + 스모크 테스트 |

> Active Context 멀티런타임 충돌은 governance.yml 가드 없음 — `rules/common/runtime-coexistence.md` 본문이 직접 적용 규칙. Stop 훅 자동 갱신 false positive 회피 목적.

## 트리거 안내

본 문서는 시스템 프롬프트 상시 로드 대상이 아니다. 아래 상황에서 Read:
- 세션 후반(20+턴) 결정 트리 재조회
- 컴팩션 직후 핵심 규칙 회복
- 신규 작업 시작 시 라우팅 1회 확인
- 사용자가 "QUICKREF"·"요약 규칙"·"빠른 참조" 언급
