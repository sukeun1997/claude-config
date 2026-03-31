# Skill Auto-Routing (자동 스킬 선택 가이드)

스킬 호출 시 작업 컨텍스트에 맞는 스킬을 자동으로 선택한다.
사용자가 명시적으로 스킬을 지정하지 않은 경우, 아래 라우팅 테이블을 따른다.

## 프로젝트 타입별 기본 스킬

현재 프로젝트의 기술 스택을 감지하여 적절한 스킬을 자동 선택한다.

| 감지 기준 | 기본 스킬 세트 |
|-----------|---------------|
| `build.gradle.kts` + Spring Boot | `/springboot-tdd`, `/springboot-verification`, `/springboot-security`, `/jpa-patterns` |
| `go.mod` | `/go-test`, `/go-review`, `/go-build`, `/golang-patterns` |
| `requirements.txt` / `pyproject.toml` + Django | `/django-tdd`, `/django-verification`, `/django-patterns`, `/python-review` |
| `package.json` + React/Next.js | `/frontend-patterns`, `/e2e-testing`, `/coding-standards` |

## 작업 트리거별 스킬 라우팅

### 구현 작업

| 트리거 | 자동 실행 스킬 |
|--------|---------------|
| 새 기능 구현 시작 | `/plan` → 승인 후 `/springboot-tdd` |
| API 엔드포인트 추가/수정 | `/api-design` + `/springboot-security` |
| DB 스키마/마이그레이션 변경 | `/database-migrations` + `/jpa-patterns` |
| Kafka/Avro 관련 변경 | `/avro-plan` (banking-loan 전용) |
| EmbeddedKafka 테스트 작성 | `/kafka-test` |
| 새 기능 브랜치 생성 | `/new-feature` |
| 독립 작업 병렬 개발 | `/parallel-dev` |

### 검증 작업

| 트리거 | 자동 실행 스킬 |
|--------|---------------|
| 구현 완료 후 검증 | `/springboot-verification` (Spring Boot) |
| 코드 품질/중복/효율 리뷰 | `/simplify` (3 에이전트 병렬 리뷰) |
| PR 생성 전 | `/vc` (verification-before-completion) |
| PR 작성/업데이트 | `/update-pr` |
| 머지 전 안전성 확인 | `/merge-check` |
| 모듈별 테스트 실행 | `/test-module` |
| 특정 테스트 클래스 실행 | `/test-class` |

### 세션 관리 & 보호

| 트리거 | 자동 실행 스킬 |
|--------|---------------|
| 세션 종료 / 긴 작업 완료 | `/reflect` (세션 회고 — 자동 제안) |
| 파일 수정 전 보호 확인 | `/freeze` (frozen 파일 자동 검사) |
| 보호 영역 관리 | `/freeze add/remove/check` |
| 외부 글/링크에서 설정 개선 검토 | `/absorb` (GAP 분석 + Opus 심층 검증 + 시스템 최적화) |

### 리뷰 & 디버깅

| 트리거 | 자동 실행 스킬 |
|--------|---------------|
| 코드 리뷰 요청 시 | `/reqc` (requesting-code-review) |
| 코드 리뷰 피드백 반영 시 | `/recc` (receiving-code-review) |
| 버그 수정 | `debugger` 에이전트 → `/springboot-tdd` (실패 재현) |
| 보안 민감 코드 수정 | `/security-review` |
| Sentry 로깅/예외 전달 관련 | `/sentry-check` |

## 비활성 스킬 (현재 프로젝트에서 사용하지 않음)

아래 스킬은 현재 기술 스택(Kotlin + Spring Boot)에 해당하지 않으므로 무시한다:

- **Go 계열**: `go-review`, `go-build`, `go-test`, `golang-patterns`, `golang-testing`
- **Python 계열**: `python-review`, `python-patterns`, `python-testing`
- **Django 계열**: `django-security`, `django-tdd`, `django-patterns`, `django-verification`
- **C++ 계열**: `cpp-testing`, `cpp-coding-standards`
- **Swift 계열**: `swift-protocol-di-testing`, `swift-actor-persistence`
- **Frontend 계열**: `frontend-patterns`, `e2e-testing`, `coding-standards` (TS/JS), `backend-patterns` (Node.js)
- **기타**: `clickhouse-io`, `nutrient-document-processing`, `cost-aware-llm-pipeline`, `regex-vs-llm-structured-text`

## 적극 사용해야 하는 스킬

| 스킬 | 언제 사용 | 왜 중요 |
|------|-----------|---------|
| `/simplify` | 구현 완료 후 코드 품질 리뷰 | 3개 에이전트가 중복 코드, 불필요 쿼리, 죽은 변수를 병렬 탐지 |
| `/context7` | 라이브러리 API 확인 시 | Spring, Kafka 등 최신 문서를 코드 내에서 바로 조회 |
| `/jpa-patterns` | Entity/QueryDSL 작업 시 | N+1, 트랜잭션, 인덱싱 베스트 프랙티스 |
| `/springboot-security` | 인증/인가 관련 코드 | Spring Security 패턴 가이드 |
| `/strategic-compact` | 긴 세션 (50+ 메시지) | 자동 compaction 전에 수동으로 컨텍스트 정리 |
| `/api-design` | 새 API 엔드포인트 설계 | RESTful 설계 + 프로젝트 API 컨벤션 보완 |
| `/database-migrations` | Flyway 마이그레이션 작성 | zero-downtime, rollback 패턴 |
| `/sentry-check` | 로깅/에러 처리 작업 시 | Throwable 누락, 중복 captureException 탐지 |
| `/reflect` | 세션 종료 시 (5+ 구현 작업 후) | 3L 회고로 학습 영속화, 반복 실수 방지 |
| `/freeze` | 파일 수정 전 자동 확인 | 보호 영역 위반 방지, build.gradle.kts 등 |
