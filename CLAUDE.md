# Global Claude Code Configuration

## 0. Primary Tech Stack & Approach

기본 기술 스택은 **Kotlin + Spring Boot + Gradle** (멀티모듈). 프로젝트별 `.claude/CLAUDE.md`에 구체적인 빌드/테스트 명령이 정의되어 있으면 반드시 그것을 우선 사용한다.

### Kotlin/Spring Boot 기본 컨벤션
- **테스트**: kotest + mockk (mockito 사용 금지)
- **빌드**: `./gradlew` 사용, ktlint 관련 태스크는 항상 skip (`-x ktlintCheck -x ktlintMainSourceSetCheck -x ktlintTestSourceSetCheck -x ktlintFormat`)
- **모듈 테스트**: 변경된 모듈만 `./gradlew :<모듈>:test` 실행 (전체 빌드 지양)
- **Immutability**: data class의 `copy()` 활용, var 대신 val 우선
- **TDD 스킬**: `/springboot-tdd` (Spring Boot), `/tdd` (일반)
- **리뷰 스킬**: `/springboot-verification` (Spring Boot 전용 검증 루프)

### Approach Constraints (CRITICAL — 1위 마찰 원인 대응)
- **build 파일 보호**: 명시적 요청 없이 build.gradle.kts 수정 금지. 데몬 재시작, 환경변수, 런타임 설정 등 비침투적 해결 우선
- **테스트 우회 금지**: 실패 테스트 수정 시 @Ignore, skip, 비활성화 절대 금지. 실제로 통과시킬 것
- **질문 먼저, 파일 나중**: 추천/분석/설명 요청 시 텍스트로 먼저 답변. 확인 후에만 파일 생성/편집
- **빠른 실행**: 탐색 최소화. 2-3회 도구 호출 후 진전 없으면 현재까지 파악한 내용 공유
- **macOS GUI PATH**: IntelliJ 등 GUI 앱은 셸 PATH 미상속. launchctl setenv, /etc/paths.d 우선 확인
- **로컬 파일 제외**: .gitignore 대신 .git/info/exclude 사용
- **디버깅 수렴**: 동일 이슈에 3회 다른 접근 실패 시 → 시도 내역 요약 후 사용자에게 방향 확인

---

## 1. Plan-First Mandate (CRITICAL)

모든 구현 작업은 반드시 계획을 먼저 수립하고 승인 후 실행한다.

### 자동 플래닝 트리거 조건
아래 조건 중 하나라도 해당하면 **즉시 EnterPlanMode 또는 /plan 스킬 실행**:
- 새로운 기능 구현 요청
- 2개 이상 파일 수정이 예상되는 작업
- 리팩토링 또는 아키텍처 변경
- 버그 수정 시 원인 파악이 필요한 경우
- 사용자가 "구현해줘", "만들어줘", "추가해줘" 등의 구현 키워드 사용

### 플래닝 워크플로우
```
1. EnterPlanMode → 코드베이스 탐색 → 영향 범위 파악
2. 단계별 구현 계획 작성 (TaskCreate로 태스크 목록 생성)
3. 사용자 승인 대기 (ExitPlanMode) → 승인 후에만 구현 시작
```

### 예외 (플래닝 생략 가능)
- 단일 파일 내 5줄 이하 수정
- 오타 수정, 변수명 변경 등 명확한 단순 작업
- 사용자가 명시적으로 "바로 해줘" 요청

---

## 2. Parallel Execution Protocol (CRITICAL)

### 병렬 실행 규칙
| 조건 | 실행 방식 |
|------|-----------|
| 독립 작업 2개 이상 | 무조건 병렬 Task 호출 |
| 독립 작업 3개 이상 | Team 모드 자동 전환 |
| 파일 탐색 + 분석 | explore + architect 병렬 |
| 코드 리뷰 | code-reviewer + security-reviewer + quality-reviewer 병렬 |
| 멀티모듈 테스트 | 독립 모듈은 병렬 `./gradlew :<모듈>:test` |

### 절대 병렬 금지 (순차 실행)
- 파일 쓰기 → 같은 파일 읽기
- 빌드 → 빌드 결과에 의존하는 테스트
- git add → git commit → git push
- Plan 승인 → 구현 시작

---

## 3. Post-Implementation Verification Flow (CRITICAL)

코드 구현 완료 후 아래 검증 체인을 **자동으로** 실행한다. 빌드/테스트 명령은 프로젝트 `.claude/CLAUDE.md` 우선.

### 검증 체인
1. **빌드 검증** (순차): 프로젝트 빌드 명령 (기본: `./gradlew build` + ktlint skip) → 실패 시 build-fixer 자동 투입
2. **코드 품질** (병렬): code-reviewer + security-reviewer + quality-reviewer
3. **테스트** (순차): 변경 모듈만 테스트 → 실패 시 수정 → 커버리지 80% 미달 시 test-code-generator 보완
4. **결과 보고**: CRITICAL/HIGH 이슈 요약 → 사용자에게 보고

### 프로젝트별 검증 스킬
| 프로젝트 타입 | 사용 스킬 |
|--------------|-----------|
| Spring Boot (Kotlin/Java) | `/springboot-verification` |
| Django (Python) | `/django-verification` |
| Go | `/go-build` → `/go-review` |
| 일반 | `/verification-loop` |

### 검증 생략 조건
- 문서/설정 파일만 수정한 경우
- 사용자가 명시적으로 "검증 스킵" 요청

---

## 4. Feature Design (FD) System

설계 결정을 마크다운 파일로 영속화하여 과거 결정이 축적되고, 새 에이전트의 계획 품질이 향상되는 시스템.

### FD 라이프사이클
```
Planned → Design → Open → In Progress → Pending Verification → Complete
                                                              → Deferred / Closed
```

### FD 슬래시 명령어
| 명령어 | 기능 |
|--------|------|
| `/fd-new` | 아이디어에서 새 FD 파일 생성, 인덱스에 등록 |
| `/fd-status` | 전체 FD 상태 대시보드 |
| `/fd-explore` | 세션 부트스트랩: 프로젝트 컨텍스트 + 활성 FD 로드 |
| `/fd-deep` | 4개 Opus 에이전트 병렬 다관점 설계 탐색 |
| `/fd-verify` | 구현 검수 + 검증 계획 실행 |
| `/fd-close` | FD 아카이빙, 인덱스/변경로그 업데이트 |

### FD 규칙
- **FD 파일 위치**: `docs/features/FD-{NNN}.md` (프로젝트별)
- **인덱스**: `docs/features/FEATURE_INDEX.md`
- **아카이브**: `docs/features/archive/`
- **커밋 prefix**: `FD-{NNN}: {description}`
- **인라인 피드백**: `%% 코멘트` 형태로 FD 파일에 직접 기록
- Plan-First(§1)와 통합: EnterPlanMode 결과를 FD 파일로 영속화

### FD 통합 워크플로우
```
Feature: /fd-new → /fd-explore → /fd-deep(복잡시) → 구현 → /fd-verify → /fd-close
Bug:     탐색 → /fd-new(원인 기록) → 수정 → /fd-verify → /fd-close
```

---

## 5. Skill Automation Chains

### Feature 구현 플로우
```
/fd-new → /fd-explore → 설계 → /springboot-tdd → 구현 → /fd-verify → /update-pr → /merge-check → /fd-close
```

### 버그 수정 플로우
```
탐색 (explore + debugger 병렬) → 원인 보고 → /fd-new(원인 기록) → /springboot-tdd (실패 재현) → 수정 → /fd-verify
```

---

## 6. Communication & Output

- **한국어 우선**: 사용자와의 대화는 한국어로 진행
- **코드/기술 용어**: 영어 원문 유지 (번역하지 않음)
- **Insight 제공**: 구현 전후 교육적 설명 포함 (explanatory mode)
- **진행 상황**: TaskCreate/TaskUpdate로 추적, 단계 완료마다 보고

---

## 7. Model Routing & Agent Catalog (CRITICAL — 메인/서브 에이전트 공통)

> 이 섹션은 메인 에이전트와 모든 서브 에이전트에서 동일하게 적용된다.

### Model Routing

Task 호출 시 `model` 파라미터를 아래 기준으로 설정:

| 모델 | 용도 | 기준 |
|------|------|------|
| **haiku** | 빠른 조회, 탐색, 문서 작성 | 단순 검색/읽기, 비용 효율 필요 |
| **sonnet** | 표준 구현, 리뷰, 디버깅 | 코드 작성/수정, 대부분의 작업 |
| **opus** | 아키텍처, 심층 분석, 플래닝 | 깊은 추론, 복잡한 의사결정 |

### Direct Write Permissions

아래 경로는 에이전트가 직접 Write/Edit 가능 (Task 위임 불필요):
- `~/.claude/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`

### Agent Delegation Rules (CRITICAL — 비용 절감)

메인 세션(Opus)이 직접 툴을 호출하는 대신, 반드시 에이전트에 위임한다.

| 작업 유형 | 직접 툴 사용 금지 | 위임 에이전트 |
|-----------|-------------------|--------------|
| 파일 탐색 (3개 이상) | Glob/Grep/Read | `Explore` |
| 코드 구현/수정 | Write/Edit | `executor` |
| 코드 리뷰 | 직접 분석 | `code-reviewer` + `quality-reviewer` |
| 디버깅 | 직접 탐색 | `debugger` |
| 빌드 오류 수정 | 직접 수정 | `build-fixer` |
| 아키텍처 설계 / 기술 결정 | 직접 판단 | `architect` |
| 복잡한 플래닝 (멀티파일 구현) | 직접 계획 | `planner` |
| 복잡한 자율 작업 (멀티스텝) | 직접 실행 | `deep-executor` |

> 각 에이전트의 모델(haiku/sonnet/opus) 상세는 `rules/common/agents.md` 참조.

**예외 (직접 툴 사용 허용):**
- 단일 파일 1-2회 읽기 (파악용)
- `~/.claude/**`, `.claude/**` 설정 파일 수정
- git 명령어 (add/commit/push)

### Agent Catalog

상세 에이전트 카탈로그 및 선택 가이드는 `rules/common/agents.md` 참조.
