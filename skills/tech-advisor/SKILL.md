---
name: tech-advisor
description: "구현 요청 시 기술/설계 선택이 필요한 경우 대안 기술/패턴/아키텍처/설계전략을 조사하여 비교 제시. feature/plan 워크플로우에서도 자동 삽입. Use when user says '/tech-advisor', '기술 추천', '어떤 방식이 좋을까', '방법 비교', '아키텍처', '패턴 추천', 또는 구현 요청에 기술/설계 선택이 포함된 경우."
---

# Tech Advisor — 기술 선택 어드바이저

사용자가 모르는 더 나은 기술/패턴/라이브러리가 있을 때, 구현 전에 대안을 조사하여 비교 제시한다.
"내가 모르는 걸 모른다" 문제를 해결하는 proactive advisor.

## When to Apply

### 독립 트리거
- `/tech-advisor {주제}` 명시 호출
- 구현 요청에 기술 선택이 포함된 경우 (DB 접근, 캐시, 테스트, 동시성, API 설계 등)
- "어떤 방식이 좋을까", "방법 비교", "기술 추천"

### Feature/Plan 삽입 트리거
- `feature` 스킬의 Phase 1(brainstorming) **시작 전** — 기술 스택 선택을 먼저 확정
- Plan 모드 진입 시 — 구현 계획에 기술 선택이 포함된 경우
- Spec 문서 작성 시 — 기술 결정이 스펙에 영향을 주는 경우

## Pipeline

```
Step 0: 호출 시점 판별
   → 구현 "전" 호출 → 정상 파이프라인 (Step 1~5)
   → 구현 "중" 호출 (N+1, 성능 병목 등 발견) → 전환 비용 분석 모드
     : 현재 접근법 유지 비용 vs 전환 비용 비교 → 전환 권고 또는 유지 권고
   │
Step 1: 도메인 식별
   → 요청에서 기술 도메인 추출
     (도구: DB, 캐시, 테스트, 동시성, API, 메시징, 인프라, 모니터링,
            직렬화, 유효성검증, 마이그레이션, 배치/스케줄링)
     (설계: 아키텍처 패턴, 설계 전략/패러다임, 디자인 패턴)
   │
Step 2: 현재 프로젝트 스택 확인
   → build.gradle.kts, package.json 등에서 이미 사용 중인 기술 확인
   → 기존 코드 패턴 빠르게 스캔 (Explore 에이전트)
   → 팀 컨텍스트 질문 (필요 시): "이 기술을 팀에서 사용 중인가, 첫 도입인가?"
   │
Step 3: 대안 조사
   → Context7으로 관련 기술 최신 문서 확인
   → 토픽 파일 참조 (있으면): memory/topics/{domain}-tech-landscape.md
   → 없으면 WebSearch로 비교 자료 수집
   │
Step 4: 비교표 제시
   → 사용자에게 옵션 제시 (최대 3개)
   → 사용자 선택 대기
   │
Step 5: 선택 반영
   → 선택된 기술로 후속 워크플로우 진행
   → 새로 알게 된 기술 정보는 토픽 파일에 추가
   → 중요 선택(아키텍처, 설계 전략, 프레임워크)은 ADR 생성 제안
     (architecture-decision-records 스킬 연계)
```

## Step 4 비교표 포맷

```markdown
### {도메인} 기술 옵션

| | 옵션 A: {이름} | 옵션 B: {이름} | 옵션 C: {이름} |
|---|---|---|---|
| **핵심** | 1줄 설명 | 1줄 설명 | 1줄 설명 |
| **장점** | ... | ... | ... |
| **단점** | ... | ... | ... |
| **현재 프로젝트 호환** | 높음/보통/낮음 | ... | ... |
| **학습 곡선** | 낮음/보통/높음 | ... | ... |
| **추천 상황** | ... | ... | ... |

💡 **권장**: 옵션 {X} — {1줄 근거}

어떤 옵션으로 진행할까요? (1/2/3)
```

## 도메인별 체크리스트

### DB/ORM
- [ ] JPA (Hibernate) — 현재 사용 중?
- [ ] Exposed (Kotlin DSL) — 타입 안전 + 경량
- [ ] JDSL (Kotlin JPQL DSL) — JPA 위에 DSL
- [ ] jOOQ — SQL 중심, 타입 안전
- [ ] Spring Data JDBC — ORM 없는 경량 접근
- Context7: `spring-data-jpa`, `exposed`, `kotlin-jdsl`, `jooq`

### 캐시
- [ ] Redis — 분산 캐시 표준
- [ ] Caffeine — 로컬 캐시 (JVM)
- [ ] Dragonfly — Redis 호환 고성능 대체 (⚠️ Spring Data Redis 완전 호환 미보장, 국내 사례 희박 — Redis 대안 검토 시에만)
- [ ] Spring Cache + @Cacheable — 추상화 레이어
- Context7: `spring-cache`, `caffeine`

### 테스트
- [ ] Unit Test — 단일 함수/클래스 격리
- [ ] Integration Test — 의존성 포함 (DB, API 등)
- [ ] Contract Test (Pact) — API 소비자-제공자 계약 (⚠️ 팀 10명+ 또는 마이크로서비스 3개+ 환경에서 효용)
- [ ] Property-Based Test (Kotest) — 속성 기반 랜덤 입력
- [ ] Mutation Test (Pitest) — 테스트 품질 검증
- [ ] Architecture Test (ArchUnit) — 의존성 규칙 검증
- [ ] Snapshot Test — 출력 스냅샷 비교
- [ ] Load/Stress Test (k6, Gatling) — 성능 한계 확인
- Context7: `kotest`, `mockk`, `archunit`, `pact-jvm`

### 동시성
- [ ] Kotlin Coroutines — 구조화된 동시성
- [ ] Virtual Thread (Java 21+) — 가벼운 스레드
- [ ] CompletableFuture — Java 표준 비동기
- [ ] Reactor/WebFlux — 리액티브 스트림
- Context7: `kotlinx-coroutines`, `virtual-threads`

### API 설계
- [ ] REST + OpenAPI — 표준, 도구 풍부
- [ ] GraphQL — 유연한 쿼리, 오버페칭 방지
- [ ] gRPC — 고성능, 스키마 강제
- [ ] Server-Sent Events — 단방향 스트리밍
- Context7: `spring-web`, `graphql-kotlin`, `grpc-kotlin`

### 메시징/이벤트
- [ ] Kafka — 대용량 이벤트 스트리밍
- [ ] RabbitMQ — 전통적 메시지 브로커
- [ ] Redis Streams — 경량 이벤트 스트리밍
- [ ] AWS SQS/SNS — 관리형 메시징
- Context7: `spring-kafka`, `spring-amqp`

### 인프라/배포
- [ ] Docker Compose — 로컬/소규모 배포
- [ ] Kubernetes (EKS/GKE) — 오케스트레이션
- [ ] AWS ECS/Fargate — 관리형 컨테이너
- [ ] Lambda/Cloud Functions — 서버리스
- [ ] OCI Always Free — 개인/사이드 프로젝트
- Context7: `docker`, `kubernetes`

### 모니터링/관찰가능성
- [ ] Prometheus + Grafana — 메트릭 수집/시각화
- [ ] Loki — 로그 집계
- [ ] Tempo/Jaeger — 분산 트레이싱
- [ ] Sentry — 에러 트래킹
- [ ] Spring Boot Actuator + Micrometer — 애플리케이션 메트릭
- Context7: `micrometer`, `opentelemetry`

### 직렬화
- [ ] Jackson (Spring 기본) — 풍부한 어노테이션, Java 생태계 표준
- [ ] kotlinx.serialization — Kotlin 네이티브, multiplatform 공유 DTO 가능
- [ ] Moshi — Kotlin 친화적 Jackson 대안
- Context7: `jackson`, `kotlinx-serialization`

### 유효성 검증
- [ ] Jakarta Bean Validation (@Valid, @NotNull) — Spring 통합, 선언적
- [ ] 도메인 내부 검증 (Result/Either 반환) — 함수형, 테스트 용이
- [ ] Valiktor — Kotlin DSL 기반 검증
- 판단 기준: 검증 위치(컨트롤러 vs 도메인), 에러 메시지 커스터마이징 요구

### 스키마 마이그레이션
- [ ] Flyway — SQL 기반, 단순, Spring Boot 자동 설정
- [ ] Liquibase — XML/YAML/JSON, 롤백 지원, 다중 DB
- Context7: `flyway`, `liquibase`

### 배치/스케줄링
- [ ] Spring Batch — 대규모 배치 처리, chunk/tasklet 모델
- [ ] @Scheduled + TaskScheduler — 단순 주기 작업
- [ ] Quartz Scheduler — 복잡한 스케줄링, 클러스터 지원
- Context7: `spring-batch`, `quartz`

### 아키텍처 패턴
- [ ] Layered (Controller → Service → Repository) — 전통적, 팀 익숙도 높음
- [ ] Hexagonal (Ports & Adapters) — 도메인 격리, 테스트 용이
- [ ] Clean Architecture — 의존성 역전, 프레임워크 독립
- [ ] CQRS — 읽기/쓰기 모델 분리
- [ ] Event Sourcing — 상태 변화를 이벤트로 저장 (⚠️ 시스템 전체 재설계 수준, 신규 기능 단위 적용 부적합)
- [ ] Modular Monolith — 마이크로서비스 전 단계, 모듈 경계 명확
- 판단 기준: 팀 규모, 도메인 복잡도, 변경 빈도, 현재 구조, **데이터 일관성 요구 수준**, **현재 코드베이스 패턴과의 거리(전환 비용)**, 외부 API 의존도

### 설계 전략/패러다임
- [ ] OOP + Rich Domain Model — 도메인 로직이 엔티티에 위치
- [ ] Functional Core / Imperative Shell — 순수 함수 코어 + I/O 쉘 분리
- [ ] DDD (Domain-Driven Design) — Aggregate, Value Object, Domain Event
- [ ] Transaction Script — 절차적, 단순 CRUD에 적합
- [ ] Reactive (Flow/Reactor) — 배압 처리, 비동기 스트림
- 판단 기준: 도메인 복잡도, 불변성 요구 수준, 부수효과 관리 필요성

### 디자인 패턴 (구현 수준)
- [ ] Strategy — 알고리즘 교체 가능
- [ ] Template Method — 공통 흐름 + 세부 구현 위임
- [ ] Observer / Event-Driven — 느슨한 결합
- [ ] Builder / DSL — 복잡한 객체 생성
- [ ] State Machine — 상태 전이 명시적 관리
- [ ] Specification — 비즈니스 규칙 조합
- [ ] Circuit Breaker — 외부 서비스 장애 격리
- 판단 기준: 변경 축(어떤 부분이 자주 바뀌는가), 조합 필요성, 테스트 용이성

## Feature/Plan 연동

### Feature 스킬과의 통합

feature 스킬 Phase 1(brainstorming) 시작 **전**에 tech-advisor가 실행될 때:

1. 사용자의 기능 요청에서 기술 선택이 필요한 부분을 식별
2. 비교표 제시 → 사용자 선택
3. 선택 결과를 brainstorming 인자에 포함:
   ```
   [기술 결정]
   - ORM: Exposed (tech-advisor 선택)
   - 캐시: Caffeine local + Redis 분산 (tech-advisor 선택)
   ```
4. 이후 brainstorming → planning → execution이 확정된 기술 기반으로 진행

### Plan/Spec 문서 반영

spec 또는 plan 문서 작성 시, tech-advisor 결과를 **기술 결정(Tech Decisions)** 섹션으로 포함:

```markdown
## Tech Decisions
| 영역 | 선택 | 근거 | 대안 |
|------|------|------|------|
| ORM | Exposed | 타입 안전 + 경량 | JPA, JDSL |
| 캐시 | Caffeine | 로컬 전용, 외부 의존성 불필요 | Redis |
```

## 토픽 파일 관리

- 조사 결과 중 재사용 가치가 있는 비교 정보는 `memory/topics/{domain}-tech-landscape.md`에 저장
- 다음 세션에서 같은 도메인 질문 시 Context7 재조사 없이 토픽 파일 먼저 참조
- 토픽 파일이 6개월+ 오래되면 Context7으로 갱신

## 제약사항

1. **비교 없이 구현 시작 금지** — 기술 선택이 필요한 경우 반드시 비교표 제시
2. **3개 이하 옵션** — 선택지가 많으면 결정 피로, 핵심 3개로 압축
3. **현재 프로젝트 호환성 필수 표기** — 이론상 좋아도 현재 스택과 안 맞으면 단점 명시
4. **사용자 선택 존중** — 권장과 다른 선택을 해도 그대로 진행
5. **단순 작업 스킵** — CRUD, 설정 변경 등 기술 선택이 불필요한 작업은 이 스킬 불필요
