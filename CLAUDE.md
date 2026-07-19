# Global Claude Code Configuration

## Core Rules
- 한국어 우선, 코드/기술 용어는 영어 원문 유지

> 빠른 결정 트리 요약: [CLAUDE.QUICKREF.md](CLAUDE.QUICKREF.md) (세션 후반/컨텍스트 재로딩 시 온디맨드 Read)

## Codex/OMX Interop
- Codex 세션의 실행 규약은 `AGENTS.md`가 담당하고, 이 파일은 정책/제약의 소스 역할을 유지
- 메모리 기본 매핑: Active=`.omx/state/`, Hot=`.omx/notepad.md`, Always=`.omx/project-memory.json`, Cold=`memory/topics/*.md`
- 변경 감시는 `.claude/governance.yml`의 경고 규칙을 우선 사용 (설계 배경: [docs/harness/governance-hooks.md](docs/harness/governance-hooks.md))
- 멀티런타임 충돌 회피 상세: [rules/common/runtime-coexistence.md](rules/common/runtime-coexistence.md)

## Profile & Persona
- 세션 시작 시 `memory/topics/user-profile.md` 참조 (필요 시 Read)

---

## 1. Session Rules

- **1세션 = 1주제**. 주제 전환 시 `/clear` 안내. 제안 기준: 도구 30회+/대화 20턴+, 같은 방향 수정 2회+ 빗나감, 문맥 오염/핵심 판단 흐려짐
- Insight 제공: 구현 전후 교육적 설명 간결히 포함
- URL 제공 시 자동 WebFetch / SDK·API 구현 전 문서 조사 (Context7 MCP)
- **배포**: `scripts/deploy.sh` 사용 필수 (없는 프로젝트는 예외)
- **Plan/Spec 저장 경로 (저장소 금지 — vault에 직접 Write)**: spec/plan/design 등 superpowers 산출물은 저장소(`docs/superpowers/**`)에 만들지 않고 vault에 직접 저장한다. 프로젝트 코드베이스 작업 → `~/vault/20 프로젝트/{project}/{branch-slug}/`, 프로젝트 무관 업무 → `~/vault/10 업무/{category}/`. 공백 포함 경로 — bash에서 `"$HOME/vault/20 프로젝트/..."` 인용 필수. `{project}`는 새로 만들지 말고 기존 폴더에서 근접 매칭하여 재사용 (애매하면 1-tap 확인). 저장소엔 절대 커밋하지 않는다

### 컨텍스트 절약
- 파일 3개+ 탐색 → Explore 서브에이전트 위임 (직접 Read는 1-2개 파일, 경로 확정 시)
- **MCP 출력 최소화**: 필요한 필드/범위 한정 요청, 목록은 limit 사용, 원시 JSON 전체를 컨텍스트에 유지하지 않음
- **Notion I/O 서브에이전트 위임**: Notion MCP 호출(fetch/update/create)은 서브에이전트에 위임. 메인은 마크다운 준비 + page ID(`projects.json` 캐시) 전달. 단순 append 1건은 메인 직접 가능
- **에이전트 결과 크기 제한**: Explore/트레이스 에이전트에 "report in under 3000 characters" 지시. 핵심(경로+호출체인+1줄 요약)만

### 프롬프팅 톤 (하네스/스킬 작성 시)
- 강조 표현(MUST, CRITICAL 등) 최소화 — 과도한 강조는 overtriggering 유발. 트리거는 "~할 때 사용" 조건부 안내
- 모델 업그레이드 시 전체 규칙 재검토 (§운영 "하네스 진화 검토")

### 학습 모드 (Learning Mode)
- **기본 ON**: 구현 요청에 기술 선택이 포함되면 단일 후보 언급이어도 `tech-advisor` 트리거. 기존 스택은 그대로 진행하되 현 스택 내 더 적합한 라이브러리/패턴이 있으면 1줄 + 트레이드오프 1줄 언급
- **OFF**: §9 라우팅의 "미확정" 케이스만 tech-advisor 트리거
- **전환**: "학습 모드 OFF/ON", "바로 해줘"(해당 요청만 임시 OFF). 스킵: 1-2줄 수정, 기존 패턴 동일 추가, 버그 픽스, 사용자가 이미 대안 비교 후 선택

### 코드 응답 원칙
- **사실 vs 결정**: 사실은 자체 확인, 결정은 항상 사용자
  - 매니페스트(package.json/build.gradle.kts 등) **단일 정확매치**는 1줄 알림 후 자동 확정 — 예: `ℹ️ 자동 확정: Kotlin 1.9 (build.gradle.kts)`
  - 코드 추론/다중 후보/외부 사실(API·버전·요금)은 수집(WebFetch/Context7) 후 1-tap 확인
  - 목표/AC/UX/트레이드오프 등 **결정**은 묵시적 선택 금지, 후보 제시 후 사용자 선택
- **반복 편집 방지**: 동일 파일 2회+ 편집 시도 시 → 파일 전체 Read + 호출/피호출 파일 1개+ Read 후 재시도
- **대형 산출물(1MB+ 단일 HTML/생성 파일) 직접 Edit 금지**: 원본 백업 + 빌드 스크립트(read→재조립, idempotent)로만 수정. 스크립트는 버전 파일 증식 대신 단일 파일 + git 이력 관리
- **재수집 비용 큰 자산은 vault에 저장**: 발표 캡처·이미지 등은 scratchpad(휘발)가 아닌 vault 산출물 폴더에
- **간단한 길 pushback**: 코드량/의존성/단계가 절반 이하로 줄어드는 방법이 있으면 구현 전 1-2문장 제안 (트레이드오프 포함)
- 결정 전에는 묻고, 결정 후에는 밀고 나감 — 새 정보가 기존 판단을 직접 부정하지 않는 한 재검토 않음

### 메모리
- compaction 후 / 이전 작업 이어갈 때 → memory_search 먼저
- 4계층: Active(`active/`) → Hot(`daily/`) → Always(`MEMORY.md`) → Cold(`topics/`). `[PROMOTE]` → MEMORY.md 승격
- Active Context: subtask 완료·`/clear`·PreCompact 시 갱신, 20줄 이하, Handoff(바뀐 것/안 된 것/다음 파일/남은 위험) 필수
- Daily Log: 세션 종료 전 1회 배치 기록, 메인 세션 직접 수행. `/clear` 전: active context → daily log 순
- 경로·포맷 상세 → `rules/common/memory.md`

---

## 2. Task Routing & Delegation

메인 세션 = 오케스트레이터. 멀티파일 작업/복잡한 탐색은 서브에이전트에 위임.

### 직접 허용
`~/.claude/**` 설정 파일, daily log, 경로 확정 1-2개 파일 Read, git 상태 확인, 단일 파일 100줄 이하 수정

### 작업 판단 플로우
1. **단순 작업** (단일 파일, 100줄 이하) → 직접 실행
2. **버그 수정** → `/sdebug` invoke → Phase 1 증거 수집 → **가설 2개+ 또는 원인 모호 시 `/triage` 분기** (병렬 발산 → 심판 수렴) → sdebug Phase 2 복귀 → 원인 격리 → 최소 수정 → `superpowers:verification-before-completion`. 재현 없이 수정 코드 작성 금지. Sentry URL/ID 시 `sentry-debug` 우선
3. **설계 결정 필요** → 인터뷰 먼저
   - **큰 아키텍처 변경 5축 게이트** (데이터 흐름/영속성 모델/외부 의존성/동기·비동기 전환): ①직접 영향 ②운영 영향(장애 복구·모니터링) ③데이터 영향(스키마 호환·마이그레이션·기록 보존) ④롤백 시나리오 ⑤더 작은 변경 대안 1개 — 체크 후 권장안 1줄 제시
4. **구현 작업** (2개+ 파일) → Plan-First
   - **3줄 룰 (spec/plan 본문 작성 전 강제)**: frontmatter 바로 아래 **AC**(동사 3개) / **Out-of-scope**(명사 3개) / **Done-when**(1줄)을 먼저 기록. 안 모이면 명확화 인터뷰, 본문 작성 금지
   - plan이 6+파일/200줄+ 변경 포함 시: `critic`이 adversarial 검증 → user approval. REJECT 시 planner 1회 수정 → 재REJECT 시 사용자 보고. 소/중규모는 바로 user approval
5. **기타** → 적절한 에이전트에 위임 (`rules/common/agents.md`)

---

## 3. Model Routing

- Agent 호출 시 `model`은 **기본 생략** (세션 모델 상속 — 대부분 정답)
- 예외만 지정: 기계적 검색/수집 → haiku, 대량 병렬 실행 등 비용 민감한 단순 구현 → sonnet
- 판단/설계/리뷰 계열은 상속 유지 (다운그레이드 금지)

---

## 4. Post-Implementation (코드 구현 완료 후)

구현 완료 후 자동으로 리뷰 수준 판단 + 고지 (예: "기본 리뷰를 실행합니다. 전체로 변경하시려면 알려주세요."):

| 조건 | 리뷰 수준 | 에이전트 |
|------|----------|---------|
| Security/인증/인가, DB 스키마, 아키텍처 변경 | 전체 | `code-reviewer` + `security-reviewer` + `quality-reviewer` + `architect` |
| Python 변경 3파일+ 또는 동작 변경 | 전체+심층 | `python-deep-review` |
| Python 소규모 수정 (1-2파일 단순 변경) | 기본 | `code-reviewer` |
| `/review` 명시 호출 | 전체 | Kotlin/Spring → `/ecr`, Python → `python-deep-review`, 그 외 전체 세트 |
| 그 외 일반 수정 | 기본 | `code-reviewer` |
| `--quick` | 최소 | `code-reviewer`만 |

- **리뷰 필수 관점 + 검증 루프 + 경계면 교차 검증** → `rules/common/verification.md` (PR 단위 리뷰 시 4관점 프롬프트 포함 필수)
- **생산-검증 분리**: 메인 세션이 직접 리뷰/검증하지 않음 — 별도 서브에이전트(verifier/critic)에 위임. 장기 작업은 중간 마일스톤마다 검증
- 빌드 실패 → `build-fixer` 자동 투입. 변경 범위 테스트 커버리지 80% 미달 시 보완
- Plan/스펙에 완료 기준·검증 방법 포함 — 리뷰어는 사전 합의 기준으로 평가

### 배포 검증 (Deployment Verification)

`deploy.sh` exit 0 ≠ 배포 성공. `/deploy-verified`가 자동화하는 3단계를 모두 확인해야 "수정이 라이브":
1. **아티팩트 포함 확인**: JAR/번들 빌드 타임스탬프가 현재 커밋 이후인지, 수정 시그니처가 바이너리에 존재하는지 (`unzip -p <jar> | grep <signature>`)
2. **로그 경로 선확인 후 tail**: 디버깅 전 실제 로그 파일 경로 먼저 확인
3. **시그니처 grep**: 새 코드 실행을 증명하는 고유 로그 라인을 라이브 로그에서 발견해야 통과

**DB 마이그레이션 추가 가드** (4/21·4/24 운영 사고 대응):
- 실행 전 `.env` DB host/name 출력해 타겟(로컬 vs 서버) 확인
- 건드릴 모든 테이블 `DESCRIBE`로 실제 컬럼 확인 (컬럼명 가정 금지)
- dry-run 먼저 실행, 예상 행 수 보고 후 사용자 승인
- idempotency 키/체크섬으로 중복 실행 방지
- **서브에이전트 위임 금지** (불가피하면 가드 4항목 + "prisma migrate dev는 pending 전부 적용" 프롬프트에 prepend). 메인 세션 직접 실행 우선

생략: 문서/설정만 수정, 사용자 "검증 스킵" 요청

---

## 5. Coding Standards

- **불변성 우선**: DTO/값 객체/응답 객체는 불변. ORM Entity 등 프레임워크 요구 시 예외
- **파일 크기**: 200-400줄 적정, 800줄 최대 / **함수**: 50줄 이하, 중첩 4단계 이하
- **에러 처리**: 명시적 처리, 사용자 친화적 메시지, 조용한 무시 금지
- **입력 검증**: 시스템 경계에서 반드시 검증 / **하드코딩 금지**: 상수 또는 설정 사용
- **주석/docstring은 핵심 WHY만 짧게**: WHAT(code-evident) 서술 금지. 수치·메트릭·벤치마크 등 휘발성 데이터 금지 — 결정 배경·측정은 PR/커밋 메시지에. docstring은 **한 줄 기본, 최대 2줄** — 3줄+ 설명형은 축약 대상. 좋은 예: "호출 위치 불변식: X보다 앞에서 호출 (과거 사고/제약)"
- **기존 주석 보존**: 기능 추출·이동 시 원본 주석 함께 이동. 요청과 무관한 영문화/재작성/삭제 금지

### 변경 최소화 (Surgical Changes)
- **Filler 금지**: 추측성 helper·placeholder·"혹시 모를" 에러 핸들링·dummy 섹션으로 채우지 않음. Less is more
- 인접 코드/주석/포맷 "개선" 금지, 미파손 코드 리팩토링 금지 (사용자 요청 시에만. 보안/데이터 손상 위험은 §7)
- 기존 파일 스타일 매치 (단 §5 위반 스타일은 매치 대상 아님)
- 무관한 dead code: 언급만, 삭제하지 않음. 내 변경이 고아로 만든 import/변수만 제거
- 자가 테스트: 변경된 모든 줄이 사용자 요청으로 직접 추적 가능한가?

---

## 6. Git Workflow

**커밋**: `<type>: <description>` (feat/fix/refactor/docs/test/chore/perf/ci)
**PR**: 전체 커밋 히스토리 분석 → 종합 요약 → 테스트 플랜 포함

### PR 코멘트/리뷰 응답 금지 (절대 규칙)
- **PR 리뷰 코멘트에 절대 답글을 남기지 않는다.** `gh api .../replies`, `gh pr review`, `gh pr comment` 등 일체 금지
- 코드 수정만 수행, 리뷰 답변은 사용자가 직접 작성. 초안 요청 시 채팅으로만 제공
- 예외: 사용자가 명시적으로 "PR에 댓글 달아라" 지시한 경우만

### PR body 안전 입력 (필수)
- `gh pr create`/`edit` 본문은 **`--body-file`** 사용 — 임시 파일에 Write 후 경로 전달
- `--body "$(cat <<'EOF' ...)"` 패턴 금지 — 백틱 escape로 코드블록 깨짐 (PR #17099 재현)
- 작성 후 `gh pr view <num> --json body --jq .body | head`로 escape 여부 검증
- 코드 스니펫 없는 한두 줄 본문은 `--body "..."` 직접 전달 가능

---

## 7. Security

- **민감 파일**: `.env`, `credentials.json`, `*.pem`, `*.key` — 존재 확인만, 내용은 사용자가 직접 관리
- **Git/DB 명령**: push는 일반 모드만, reset은 `--soft`만, 삭제는 대상 파일 명시하여 실행
- **비밀값**: 환경변수 또는 시크릿 매니저로 참조
- **의존성 변경**: 새 패키지/메이저 업그레이드 시 사용자 확인 필수
- 보안 이슈 발견 시 즉시 중단 → `security-reviewer`

---

## 8. Parallel Execution

- 독립 작업 2개+ → 병렬 Task. 순차 필수: 파일 쓰기→읽기, 빌드→테스트, git add→commit→push
- 팀 아키텍처 패턴 (Pipeline/Fan-out/Producer-Reviewer 등) → 워크플로우/스킬 설계 시 [docs/harness/team-patterns.md](docs/harness/team-patterns.md) 참조

### 서브에이전트 가드레일
- 단일 서브에이전트 도구 15회+ 호출 → 중간 결과 보고 후 계속 여부 판단
- 재귀 위임은 1단계까지만. 같은 에러/패턴 3회 반복 → 자동 종료 + 원인 보고

---

## 9. Auto Skill Routing

작업 컨텍스트에 따라 관련 스킬을 자동 invoke. 각 스킬의 description 트리거가 1차이고, 아래는 description만으로 판단이 어려운 라우팅.

### 파일/언어 기반
| 트리거 | 스킬 |
|--------|------|
| `.kt` 작성/수정 | `kotlin-patterns` |
| `.swift` 작성/수정 | `everything-claude-code:swiftui-patterns` |
| `.py` 변경 → 리뷰 단계 | §4 표 기준 (`python-deep-review`는 3파일+/동작 변경 시) |
| JPA Entity/Repository 변경 | `everything-claude-code:jpa-patterns` |
| `@Cacheable`, Redis 설정 변경 | `redis-cache-patterns` |
| Security 설정, 인증/인가 코드 | `security-fix` |
| haru 프로젝트 배포/Docker/Nginx/OCI | `haru-infra` |

### 워크플로우 기반 (비자명 라우팅만)
| 트리거 | 처리 |
|--------|------|
| 새 기능 구현 시작 | `feature` (tech-advisor → brainstorming → plans → execution) |
| "codex로 구현", "sol로 작업", "orca로 위임" | `orca-feature` |
| 설계/분석 문서 **신규 생성** (spec/plan/analysis) — vault/.omx/active/daily 경로·brainstorming 산출물 제외 | `feature` brainstorming 게이트 선행 |
| 업무 기술(Spring/Kafka 등) + "가이드/학습/정리" | `master-guide` / 일반 주제 + "노션에 정리" → `research-to-notion` / 업무 기술 + "노션에 정리"(단순 리서치 의도)는 분기 질문 |
| Slack URL (pfcoworkspace) | `slack_read_thread`로 컨텍스트 확보 후 코드 추적 |
| GitHub PR + "리뷰" 의도 | Kotlin/Spring → `/ecr`, 그 외 → `/review`. verifier 디폴트 포함 ("opus 검증" 별도 명시 불필요) |
| plan/spec 저장, "docs에 저장", "옵시디언" | `docs-save` |

### Plan 모드 라우팅
- "새 기능 구현"이면 Plan 모드 대신 `feature` 스킬 먼저. Plan 모드는 리팩토링/마이그레이션/설정 변경 등에만

### 규칙
- 스킬은 참고 자료로 로드, 간결히 적용. "스킬 스킵"/"바로 해줘" 시 생략
- 충돌 시 우선순위: 프로젝트 > 글로벌 / 워크플로우 > 파일·언어 / 좁은 범위 > 넓은 범위 / 특정 문구 명시 > 범용 키워드

## 운영
- 테스트 실패 방치 금지: 즉시 수정 또는 이슈 등록
- **삽질 감지 시 기록**: 같은 파일 3회+ 수정, 접근법 변경 반복 → `memory/topics/failure-log.md`에 1줄 (날짜/증상/원인/해법). 미분류 5건+ 누적 시 첫 여유 시점에 batch 분류
- **반복 작업 자동화 감지**: 세션 내 유사 작업 3회+ → daily log에 `[AUTOMATE]` 태그
- Notion: MCP 우선. 작업일지는 메인 페이지가 아닌 작업 일지 페이지에
- **하네스 진화**: 모델 업그레이드 시 전체 규칙 재검토 (모든 규칙은 "모델이 못하는 것"에 대한 가정). /review-week에서 friction 추이(0인 규칙 4주 지속 → 은퇴)·KPI 갭·MCP 도구 중복 점검
