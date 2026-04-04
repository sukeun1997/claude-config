# Global Claude Code Configuration

## Core Rules (앵커링 — primacy bias 활용)
- 한국어 우선, 코드/기술 용어는 영어 원문 유지
- 열지 않은 파일/코드에 대해 추측하지 않음 — Read 후 답변
- 토큰 예산 부족으로 작업을 일찍 마무리하지 않음 — 끝까지 진행

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

### 컨텍스트 절약
- 파일 3개+ 탐색 → Explore 서브에이전트 위임
- 직접 Read: 1-2개 파일, 경로 확정 시만
- 이미 아는 내용 재확인 금지
- **탐색/계획 상한**: 탐색·계획 도구 호출이 연속 5회 초과 시 → 즉시 구현 착수. 추가 정보는 구현 중 점진적으로 수집. 단, 버그 수정 시(§2 #2) 증거 수집이 완료될 때까지 예외
- **조기 중단 금지**: 토큰 예산 부족으로 작업을 일찍 마무리하지 않음 — compaction이 자동 처리하므로 끝까지 진행. 한계 접근 시 진행 상태를 메모리에 저장

### 프롬프팅 톤 (4.6 최적화)
- 강조 표현(MUST, CRITICAL, MANDATORY 등) 최소화 — 4.6은 일반 표현으로 충분히 따르며, 과도한 강조는 overtriggering 유발
- 도구/스킬 트리거: "~할 때 사용" 형태의 조건부 안내. "반드시", "의심되면 사용" 등 이전 모델용 강제 표현 지양

### 코드 응답 원칙
- **추측 금지**: 열지 않은 파일/코드에 대해 추측하지 않음. 참조된 파일은 Read 후 답변
- **디버깅 증거 먼저**: 에러 로그, 스택 트레이스, 실제 출력을 먼저 확인 후 진단. 가설 기반 추측 진단 금지. 사용자가 "안 돼", "에러 나" 등만 보고해도 → 직접 로그/출력/상태를 수집하여 진단 (증거 요청 대신 자체 수집)
- **환경 확인 우선**: DB/API 결과가 예상과 다를 때 → 환경(.env, 연결 정보, 마이그레이션 상태) 먼저 확인. 코드 원인만 의심하지 않음
- 접근법 결정 후 밀고 나감 — 새 정보가 기존 판단을 직접 부정하지 않는 한 재검토 않음

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

**생략**: 문서/설정만 수정, 사용자 "검증 스킵" 요청

---

## 5. Coding Standards

- **불변성 우선**: DTO/값 객체/응답 객체는 불변. ORM Entity 등 프레임워크가 요구하는 경우 예외 (변경 범위 최소화)
- **파일 크기**: 200-400줄 적정, 800줄 최대
- **함수 크기**: 50줄 이하, 중첩 4단계 이하
- **에러 처리**: 명시적 처리, 사용자 친화적 메시지, 조용한 무시 금지
- **입력 검증**: 시스템 경계에서 반드시 검증
- **하드코딩 금지**: 상수 또는 설정 사용

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
| 새 기능 구현 시작 | `feature` (brainstorming → plans → execution 2-gate 래퍼) |
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
| URL 분석 + 설정 적용 요청 | `absorb` |

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
- Notion: MCP 우선
- 노션 작업일지: 메인 페이지에 일일 로그 금지, 작업 일지 페이지에 기록
- **하네스 진화 검토**: 모델 업그레이드 시 기존 규칙이 아직 필요한지 재검토. 모든 규칙은 "모델이 못하는 것"에 대한 가정
- **Eval 기반 하네스 진화**: /review-week 시 아래 2가지를 분석
  - friction 추이: sessions.jsonl 기반 마찰 빈도. friction=0 규칙 4주 지속 시 은퇴 후보
  - 이상 갭 분석: `memory/metrics/harness-kpi.md` 정의 KPI 대비 현재 달성률. 미달 KPI에 대해 원인 가설 + 개선 제안 생성
- **Self-Absorb 루프**: Stop 훅이 삽질 감지 시 원인 분류 + 개선 제안 요청 → 다음 세션에서 제안 리뷰
