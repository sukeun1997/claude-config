# Global Claude Code Configuration

## Core Rules (앵커링 — primacy bias 활용)
- 한국어 우선, 코드/기술 용어는 영어 원문 유지
- 열지 않은 파일/코드에 대해 추측하지 않음 — Read 후 답변
- 토큰 예산 부족으로 작업을 일찍 마무리하지 않음 — 끝까지 진행

## Codex/OMX Interop
- Codex 세션의 실행 규약은 `AGENTS.md`가 담당하고, 이 파일은 정책/제약의 소스 역할을 유지
- 메모리 기본 매핑: Active=`.omx/state/`, Hot=`.omx/notepad.md`, Always=`.omx/project-memory.json`, Cold=`memory/topics/*.md`
- 변경 감시는 `.claude/governance.yml`의 경고 규칙을 우선 사용하고, 훅이 없을 때도 같은 검증 추천을 수동 적용

## Profile & Persona
- 세션 시작 시 `memory/topics/user-profile.md` 참조 (필요 시 Read)

---

## 1. Session Rules

- **1세션 = 1주제**. 주제 전환 시 `/clear` 안내
- `/clear` 제안 기준:
  - 도구 30회+ / 대화 20턴+
  - 같은 방향 수정이 2회 이상 빗나감 (접근법 재검토 신호)
  - 원래 작업과 무관한 설명이 늘어남 (문맥 오염 신호)
  - 핵심 판단이 흐려지거나 이전 결정을 잊음 (compaction 한계 신호)
- Insight 제공: 구현 전후 교육적 설명 포함
- URL 제공 시 자동 WebFetch / SDK·API 구현 전 문서 조사 (Context7 MCP)
- **배포**: `scripts/deploy.sh` 사용 필수 (없는 프로젝트는 예외)
- **Plan/Spec 저장 경로**: `~/vault/{project}/{branch-slug}/` (superpowers 생성 파일은 vault-auto-save 훅이 자동 이동 + 원본 삭제)

### 컨텍스트 절약
- 파일 3개+ 탐색 → Explore 서브에이전트 위임
- 직접 Read: 1-2개 파일, 경로 확정 시만
- 이미 아는 내용 재확인 금지
- **탐색/계획 상한**: 탐색·계획 도구 호출이 연속 5회 초과 시 → 즉시 구현 착수. 추가 정보는 구현 중 점진적으로 수집. 단, 버그 수정 시(§2 #2) 증거 수집 및 critic 검증(§2 #4) 진행 중일 때 예외
- **조기 중단 금지**: 토큰 예산 부족으로 작업을 일찍 마무리하지 않음 — compaction이 자동 처리하므로 끝까지 진행. 한계 접근 시 진행 상태를 메모리에 저장
  - 금지 표현: "should I continue?", "good stopping point", "continue in a new session", "not caused by my changes", "known limitation". 이러한 자가 중단/책임 회피 표현 대신 작업을 계속 진행하거나, 실제 블로커가 있으면 구체적으로 보고
- **MCP 출력 최소화**: MCP 도구 호출 시 필요한 필드/범위를 한정하여 요청. 목록 조회는 limit 파라미터 사용, 결과에서 필요한 속성만 추출하여 후속 작업에 전달. 원시 JSON 전체를 컨텍스트에 유지하지 않음
- **Notion I/O 서브에이전트 위임**: Notion MCP 호출(fetch/update/create)은 서브에이전트에 위임. 메인에서는 마크다운 콘텐츠만 준비하고, page ID(`projects.json` 캐시)와 함께 전달. search 대신 캐시된 ID 직접 사용. 단순 append 1건은 메인에서 직접 가능
- **에이전트 결과 크기 제한**: Explore/코드 트레이스 에이전트에 "report in under 3000 characters" 지시. 핵심(파일 경로 + 호출 체인 + 1줄 요약)만 요청하고, 상세는 필요 시 직접 Read

### 프롬프팅 톤 (4.6 최적화)
- 강조 표현(MUST, CRITICAL, MANDATORY 등) 최소화 — 4.6은 일반 표현으로 충분히 따르며, 과도한 강조는 overtriggering 유발
- 도구/스킬 트리거: "~할 때 사용" 형태의 조건부 안내. "반드시", "의심되면 사용" 등 이전 모델용 강제 표현 지양

### 코드 응답 원칙
- **추측 금지**: 열지 않은 파일/코드에 대해 추측하지 않음. 참조된 파일은 Read 후 답변
- **반복 편집 방지**: 동일 파일을 2회+ 편집하려 할 때 → 파일 전체 Read(limit 없이) + 호출하는/호출되는 최소 1개 파일 Read 후 재시도. W16 주간 분석 1위 원인(Context 9건, 파일 Read 선행 미흡) 대응
- **디버깅 증거 먼저**: 에러 로그, 스택 트레이스, 실제 출력을 먼저 확인 후 진단. 가설 기반 추측 진단 금지. 사용자가 "안 돼", "에러 나" 등만 보고해도 → 직접 로그/출력/상태를 수집하여 진단 (증거 요청 대신 자체 수집)
- **환경 확인 우선**: DB/API 결과가 예상과 다를 때 → 환경(.env, 연결 정보, 마이그레이션 상태) 먼저 확인. 코드 원인만 의심하지 않음
- **모호한 요구사항 명시**: 요구사항이 모호할 때 → 모호한 부분을 구체적으로 지목하여 질문 (예: "X는 A인가 B인가?"). "알아서 처리" 금지. (증거/환경 부족 → 자체 수집. 요구사항/의도 모호 → 질문. 두 축 혼동 금지)
- **복수 해석 처리**: 요청에 2개 이상 해석 가능할 때 → 묵시적 선택 금지, 후보 제시 후 사용자 선택
- **간단한 길 pushback**: 요청한 접근법보다 코드량/의존성/단계 수가 절반 이하로 줄어드는 방법이 있을 때 → 구현 전 1-2문장으로 제안 (트레이드오프 포함)
- 접근법 결정 후 밀고 나감 — 새 정보가 기존 판단을 직접 부정하지 않는 한 재검토 않음 (결정 전에는 묻고, 결정 후에는 밀고 나감)

### 메모리
- compaction 후 / 이전 작업 이어갈 때 → memory_search 먼저
- 4계층: Active(`active/` + `sessions/`) → Hot(`daily/`) → Always(`MEMORY.md`) → Cold(`topics/`)
- `[PROMOTE]` 태그 → MEMORY.md 승격, 상세는 topics/로

### Active Context (세션 연속성 핵심)
- subtask 완료 시 Status 갱신, `/clear`·PreCompact 시 즉시 갱신
- 20줄 이하 유지, 완전 종료 시 파일 삭제
- Handoff 필수: 바뀐 것 / 안 된 것 / 다음 파일 / 남은 위험
- 경로·포맷·자동화 상세 → `rules/common/memory.md`

### Daily Log
- 세션 종료 전 1회 배치 기록, 메인 세션이 직접 수행 (위임 금지)
- `/clear` 전: active context 갱신 → daily log 작성 (이 순서)
- 경로·포맷·작성 시점 상세 → `rules/common/memory.md`

---

## 2. Task Routing & Delegation

### 메인 세션 = 오케스트레이터
멀티파일 작업이나 복잡한 탐색은 서브에이전트에 위임.

### 직접 허용
- `~/.claude/**` 설정 파일 읽기/수정, daily log 작성
- 경로 확정된 파일 1-2개 Read
- git status/log 등 상태 확인
- **단일 파일 100줄 이하 수정** (사용자 명시 "바로 해줘" 포함)
- Agent 도구로 서브에이전트 위임

### 작업 판단 플로우
1. **단순 작업** (단일 파일, 100줄 이하) → 직접 실행
2. **버그 수정** → `superpowers:systematic-debugging` 스킬 invoke → 재현 확인 → 원인 격리 → 최소 수정 → `superpowers:verification-before-completion`으로 검증. 재현 없이 수정 코드 작성 금지
3. **설계 결정 필요** → 인터뷰 먼저
4. **구현 작업** (2개+ 파일) → Plan-First
   - planner의 plan이 6+파일, 200줄+ 변경을 포함하면: `critic`(opus)이 plan을 adversarial 검증 → user approval. critic REJECT 시 planner 1회 수정 → 재REJECT 시 사용자 보고
   - 소/중규모: 기존대로 바로 user approval
5. **기타** → 적절한 에이전트에 위임

에이전트 선택·실패 처리·검증 루프 → `rules/common/agents.md` 참조

---

## 3. Model Routing

Agent 호출 시 `model` 파라미터 필수 지정.

| 티어 | 에이전트 |
|------|---------|
| **haiku** | `explore`, `writer`, `style-reviewer` |
| **sonnet** | `executor`, `debugger`, `build-fixer`, `test-engineer`, `designer`, `qa-tester`, `document-specialist`, `git-master`, `information-architect`, `api-reviewer`, `performance-reviewer`, `product-analyst`, `product-manager`, `scientist`, `ux-researcher`, `vision` |
| **opus** | `architect`, `planner`, `analyst`, `critic`, `deep-executor`, `quality-reviewer`, `security-reviewer`, `code-reviewer`, `verifier` |

미등록 에이전트: 판단/설계→opus, 실행/구현→sonnet, 검색/수집→haiku

---

## 4. Post-Implementation (코드 구현 완료 후)

### 리뷰 정책 (자동 판단 + 고지)

구현 완료 후 **자동으로 리뷰 수준을 판단**하고 고지:

| 조건 | 리뷰 수준 | 에이전트 |
|------|----------|---------|
| Security/인증/인가, DB 스키마, 아키텍처 변경 | **전체** (자동) | `code-reviewer` + `security-reviewer` + `quality-reviewer` + `architect` |
| `/review` 명시 호출 | **전체** | 위와 동일 |
| 그 외 일반 수정 | **기본** (자동) | `code-reviewer` |
| `--quick` | **최소** | `code-reviewer`만 |

> 고지 예시: "기본 리뷰를 실행합니다. 전체로 변경하시려면 알려주세요."
> 전체 예시: "전체 리뷰를 실행합니다 (Security 변경 감지). 기본으로 변경하시려면 알려주세요."

### 장기 작업 중간 검증
- `deep-executor` 등 장기 에이전트 작업 시 구현과 검증을 분리
- 자체 평가에 의존하지 않음 — 별도 검증 단계(코드 리뷰 에이전트 또는 실행 테스트)로 품질 확인
- 중간 마일스톤마다 검증 후 다음 단계 진행
- **생산-검증 분리 원칙**: 메인 세션이 직접 리뷰/검증하지 않음. 같은 컨텍스트에서 생산과 검증을 겸하면 동의 편향 발생. 리뷰/평가는 별도 Opus 서브에이전트에 위임하여 독립적으로 판단

### 빌드 검증
프로젝트 빌드 명령 → 실패 시 build-fixer 자동 투입

### 테스트
변경 범위 테스트 → 커버리지 80% 미달 시 보완

### 검증 기준 사전 합의
- Plan/스펙에 **완료 기준**과 **검증 방법**을 포함 — 구현 전에 "무엇이 성공인지" 정의
- 리뷰어는 Plan에 명시된 기준으로 평가 (구현자의 자체 판단이 아닌 사전 합의 기준)

### 경계면 교차 검증
리뷰/QA 시 경계면 불일치를 확인 (각 리뷰어의 단일 관점 검증을 보완):
- API 응답 shape ↔ 클라이언트 호출 타입 (래핑, camelCase/snake_case)
- Entity/DTO ↔ DB 스키마/마이그레이션
- 상태 전이 설계 ↔ 실제 분기 로직
- 환경 설정(.env) ↔ 코드 참조

### 배포 검증 (Deployment Verification)

`deploy.sh`가 exit 0으로 끝나도 배포 **성공이 아님**. 아래 3단계를 모두 확인해야 "수정이 라이브"임을 선언할 수 있다. `/deploy-verified` 스킬이 자동화한다.

1. **아티팩트 포함 확인**: 배포된 JAR/번들의 빌드 타임스탬프가 현재 커밋 이후인지, 수정한 메서드/문자열 시그니처가 바이너리에 존재하는지 (`unzip -p <jar> | grep <signature>` 또는 `strings`)
2. **로그 경로 선확인 후 tail**: 디버깅 전에 서버의 실제 로그 파일 경로를 먼저 확인. 잘못된 로그를 tail하여 "수정이 안 들어간 줄 알았지만 다른 로그였던" 루프 방지
3. **시그니처 grep**: 새 코드 실행을 증명하는 고유 로그 라인(수정된 메서드명, 새 버전 태그, 추가한 DEBUG 로그)을 라이브 로그에서 발견해야 통과

**DB 마이그레이션 전용 추가 가드** (reporter.html이 식별한 4회 반복 마찰):
- 실행 전 `.env`의 DB host/name을 출력해 의도한 타겟(로컬 vs 서버) 확인
- 건드릴 모든 테이블을 `DESCRIBE`로 실제 컬럼 확인 (컬럼명 가정 금지)
- dry-run을 먼저 실행하여 예상 행 수 보고 후 사용자 승인
- idempotency 키 또는 체크섬으로 중복 실행 방지

**생략**: 문서/설정만 수정, 사용자 "검증 스킵" 요청

---

## 5. Coding Standards

- **불변성 우선**: DTO/값 객체/응답 객체는 불변. ORM Entity 등 프레임워크가 요구하는 경우 예외 (변경 범위 최소화)
- **파일 크기**: 200-400줄 적정, 800줄 최대
- **함수 크기**: 50줄 이하, 중첩 4단계 이하
- **에러 처리**: 명시적 처리, 사용자 친화적 메시지, 조용한 무시 금지
- **입력 검증**: 시스템 경계에서 반드시 검증
- **하드코딩 금지**: 상수 또는 설정 사용

### 변경 최소화 (Surgical Changes)
- **Filler 금지 (1000 no's for every yes)**: 모든 줄/함수/파일은 자기 자리값을 해야 함. 빈 공간은 레이아웃·구성으로 풀고, 추측성 helper·placeholder·"혹시 모를" 에러 핸들링·dummy 섹션으로 채우지 않음. Less is more
- 인접 코드/주석/포맷 "개선" 금지 — 사용자 요청과 무관하면 손대지 않음
- 미파손 코드 리팩토링 금지 — "더 나은 구조"는 사용자 요청 시에만 (보안/데이터 손상 위험은 §7에 따라 즉시 보고)
- 기존 파일 스타일 매치 — 내 취향 강제 금지. 단 §5 다른 규칙(빈 catch, 거대 함수 등) 위반 스타일은 매치 대상이 아님
- 관련 없는 dead code: **언급만 하고 삭제하지 않음** (사용자 판단 위임)
- 내 변경이 고아로 만든 import/변수/함수만 제거, 기존 dead code는 그대로
- 자가 테스트: 변경된 모든 줄이 사용자 요청으로 직접 추적 가능한가?

---

## 6. Git Workflow

**커밋**: `<type>: <description>` (feat/fix/refactor/docs/test/chore/perf/ci)
**PR**: 전체 커밋 히스토리 분석 → 종합 요약 → 테스트 플랜 포함

---

## 7. Security

- **민감 파일**: `.env`, `credentials.json`, `*.pem`, `*.key` — 존재 확인만, 내용은 사용자가 직접 관리
- **Git/DB 명령**: push는 일반 모드만, reset은 `--soft`만, 삭제는 대상 파일 명시하여 실행
- **비밀값**: API 키, 토큰, 비밀번호는 환경변수 또는 시크릿 매니저로 참조
- **의존성 변경**: 새 패키지/메이저 업그레이드 시 사용자 확인 필수
- 보안 이슈 발견 시 즉시 중단 → `security-reviewer` 에이전트

---

## 8. Parallel Execution

| 조건 | 실행 방식 |
|------|-----------|
| 독립 작업 2개+ | 병렬 Task |
| 순차 필수 | 파일 쓰기→읽기, 빌드→테스트, git add→commit→push |

### 팀 아키텍처 패턴
새 워크플로우/스킬 설계 시 참조:

| 패턴 | 적합 상황 | 현재 사용처 |
|------|----------|------------|
| Pipeline | 순차 단계, 게이트 필요 | `/review`, `/feature` |
| Fan-out | 독립 태스크 병렬 실행 | `subagent-driven-development` |
| Producer-Reviewer | 구현 후 검증 루프 | 리뷰 Phase 3→4 |
| Expert Pool | 조건별 전문가 선택 | §4 리뷰 수준 자동 판단 |
| Supervisor | 위임+모니터링 | `deep-executor` |
| Hierarchical | 3계층+ 대규모 작업 | Team → 서브에이전트 |

### 서브에이전트 가드레일
- 단일 서브에이전트 도구 15회+ 호출 → 중간 결과 보고 후 계속 여부 판단
- 재귀 위임 (서브에이전트→서브에이전트) → 1단계까지만 허용
- 같은 에러/패턴 3회 반복 → 자동 종료 + 원인 보고 + 필요 시 architect 에스컬레이션

---

## 9. Auto Skill Routing

작업 컨텍스트에 따라 관련 스킬을 **자동으로 invoke** (사용자 요청 불필요).

### 파일/언어 기반 (프로젝트 공통)
| 트리거 | 스킬 |
|--------|------|
| `.kt` 파일 작성/수정 | `kotlin-patterns` |
| `.swift` 파일 작성/수정 | `everything-claude-code:swiftui-patterns` |
| JPA Entity / Repository 변경 | `everything-claude-code:jpa-patterns` |
| `@Cacheable`, Redis 설정 변경 | `redis-cache-patterns` |
| SQL 마이그레이션 / 스키마 변경 | `everything-claude-code:postgres-patterns` + `everything-claude-code:database-migrations` |
| Security 설정, 인증/인가 코드 | `everything-claude-code:springboot-security` + `everything-claude-code:security-review` |

### 워크플로우 기반
| 트리거 | 스킬 |
|--------|------|
| 구현 요청에 **미확정** 기술/설계 선택이 포함된 경우 (기존 스택으로 자연스럽게 결정되면 스킵) | `tech-advisor` (대안 비교 → 사용자 선택 → 구현 진행) |
| 새 기능 구현 시작 | `feature` (tech-advisor → brainstorming → plans → execution) |
| 기술 뉴스/동향 요청 | `daily-briefing` (quick/deep 모드) |
| 테스트 코드 작성 | `everything-claude-code:springboot-tdd` (백엔드) / `everything-claude-code:swift-protocol-di-testing` (iOS) |
| PR 전 최종 검증 | `everything-claude-code:springboot-verification` (백엔드) / `superpowers:verification-before-completion` |
| 버그 수정/디버깅 시작 | `superpowers:systematic-debugging` (증거 기반 진단 후 debugger 에이전트) |
| 버그 수정 코드 작성 완료 | `superpowers:verification-before-completion` (수정 결과 실행 확인) |
| 빌드 실패 | `build-fixer` 에이전트 (스킬 아닌 에이전트) |
| LLM API 비용/쿼터 관련 | `everything-claude-code:cost-aware-llm-pipeline` |
| 아키텍처 다이어그램 요청 | `arch-diagram` |
| 업무 기술 + "가이드/학습/마스터/정리" | `master-guide` (심층 학습 가이드) |
| 업무 기술 + "업데이트" | `master-guide` (update 모드) |
| 일반 주제 + "노션에 정리/분석" | `research-to-notion` (일반 리서치) |
| 업무 기술 + "노션에 정리" (단순 리서치 의도) | 사용자에게 분기 질문 |
| URL 분석 + 설정 적용 요청 | `absorb` (주 2회 배치 — 화/금 권장, 초과 시 북마크) |
| Sentry URL 또는 이슈 ID 제공 시 | `sentry-debug` |
| plan/spec 저장, "docs에 저장", "옵시디언" | `docs-save` |

> 프로젝트별 추가 라우팅은 각 프로젝트 CLAUDE.md에서 정의

### Plan 모드 라우팅
- Plan 모드 진입 전, 작업이 "새 기능 구현"에 해당하면 → `feature` 스킬을 먼저 invoke (Plan 모드 대신)
- Plan 모드는 `feature`에 해당하지 않는 작업(리팩토링, 마이그레이션, 설정 변경 등)에만 직접 사용
- `PreToolUse` 훅이 `EnterPlanMode` 시 리마인드를 제공하므로, 이를 참고하여 판단

### 규칙
- 스킬은 **참고 자료로 로드**. 작업 흐름을 방해하지 않도록 간결히 적용
- 동시에 2개+ 스킬이 해당되면 아래 우선순위로 1개만 invoke
- 사용자가 "스킬 스킵" 또는 "바로 해줘" 시 생략 가능
- **스킬 description 작성**: `"Use when user says '<trigger1>', '<trigger2>'"` 패턴 포함. 한/영 키워드 모두 기재하여 트리거 확률 확보

### 스킬 우선순위 (충돌 시)
1. 프로젝트별 CLAUDE.md 스킬 > 글로벌 CLAUDE.md 스킬
2. 워크플로우 기반 > 파일/언어 기반
3. 좁은 범위 (jpa-patterns) > 넓은 범위 (kotlin-patterns)

## 운영
- 테스트 실패 방치 금지: 즉시 수정 또는 이슈 등록
- **삽질 감지 시 자동 기록**: 같은 파일 3회+ 수정, 접근법 변경, 예상과 다른 결과 반복 → 원인 파악 후 `memory/topics/failure-log.md`에 1줄 추가 (날짜/증상/원인 계층/해법)
- **반복 작업 자동화 감지**: 세션 내 유사 작업(같은 구조 파일 생성, 같은 유형 수정 등) 3회+ 반복 인식 시 → daily log에 `[AUTOMATE]` 태그로 기록. /review-week 축 2에서 분석
- **MCP 도구 감사**: /review-week 시 활성 MCP 서버의 도구 수와 중복을 점검. 중복 도구(동일 기능의 다른 MCP 서버)는 하나만 유지. 비활성 서버의 도구가 다른 플러그인을 통해 로드되는지 확인
- Notion: MCP 우선
- 노션 작업일지: 메인 페이지에 일일 로그 금지, 작업 일지 페이지에 기록
- **하네스 진화 검토**: 모델 업그레이드 시 기존 규칙이 아직 필요한지 재검토. 모든 규칙은 "모델이 못하는 것"에 대한 가정
- **Eval 기반 하네스 진화**: /review-week 시 아래 2가지를 분석
  - friction 추이: sessions.jsonl 기반 마찰 빈도. friction=0 규칙 4주 지속 시 은퇴 후보
  - 이상 갭 분석: `memory/metrics/harness-kpi.md` 정의 KPI 대비 현재 달성률. 미달 KPI에 대해 원인 가설 + 개선 제안 생성
- **Self-Absorb 루프**: Stop 훅이 삽질 감지 시 원인 분류 + 개선 제안 요청 → 다음 세션에서 제안 리뷰
