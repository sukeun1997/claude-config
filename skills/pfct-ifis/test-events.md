---
name: test-events
description: "이벤트 핸들러와 관련된 테스트를 빠르게 실행해줘."
triggers:
  - "test events"
  - "테스트 실행"
  - "이벤트 테스트"
  - "run event tests"
---

# Test Events Skill

이벤트 소싱 관련 테스트를 효율적으로 실행합니다.

## 실행 단계

### 1. 테스트 범위 결정

**User 입력 분석**:
- "test events" → 모든 이벤트 관련 테스트
- "test LoanCreated" → 특정 이벤트 테스트만
- "test domain" → Domain 모듈만
- "test all" → 전체 테스트

### 2. 병렬 테스트 실행 (성능 최적화)

#### A. Domain 테스트 (이벤트 + Aggregate)

```bash
# Domain 모듈 테스트 (병렬 실행)
./gradlew :domain:test --parallel --max-workers=4

# 특정 테스트 클래스만 (더 빠름)
./gradlew :domain:test --tests "*EventTest" --tests "*AggregateTest"
```

#### B. Application 테스트 (Use Cases)

```bash
# Use Case 테스트
./gradlew :application:test --parallel --max-workers=4

# 특정 Use Case만
./gradlew :application:test --tests "*LoanUseCaseTest"
```

#### C. Adapter 테스트 (Event Handlers, Projections)

```bash
# Event Handler 테스트
./gradlew :adapter:test --tests "*EventHandlerTest" --parallel

# Projection 테스트
./gradlew :adapter:test --tests "*ProjectionTest" --parallel
```

#### D. 전체 이벤트 플로우 테스트

```bash
# 모든 이벤트 관련 테스트를 병렬로 실행
./gradlew :domain:test :application:test :adapter:test --parallel --max-workers=6
```

### 3. 테스트 결과 분석

```bash
# 테스트 실패 요약
./gradlew test --continue | grep "FAILED"

# 상세 리포트 (HTML)
open domain/build/reports/tests/test/index.html
open application/build/reports/tests/test/index.html
open adapter/build/reports/tests/test/index.html
```

### 4. 실패한 테스트 재실행 (빠른 피드백)

```bash
# 실패한 테스트만 재실행
./gradlew test --rerun-tasks --tests "*FailedTestName"

# 캐시 무시하고 재실행
./gradlew cleanTest :domain:test :application:test
```

## 테스트 패턴별 전략

### Event Rehydration 테스트
```kotlin
given("이벤트 스트림이 주어지고") {
    val events = listOf(
        LoanCreated(...),
        RepaymentRecorded(...),
        InterestAccrued(...)
    )

    `when`("rehydrate를 실행하면") {
        val aggregate = rehydrator.rehydrate(events)

        then("상태가 정확히 복원된다") {
            aggregate.balance shouldBe expectedBalance
            aggregate.status shouldBe LoanStatus.ACTIVE
        }
    }
}
```

**테스트 전략**:
- ✅ 이벤트 순서대로 적용
- ✅ 각 이벤트 타입별로 상태 변화 검증
- ✅ Edge case (빈 이벤트 리스트, 순서 바뀜 등)

### Event Handler 테스트
```kotlin
given("LoanCreated 이벤트가 발행되면") {
    val event = LoanCreated(loanId, amount, rate)

    `when`("핸들러가 처리하면") {
        handler.handle(event)

        then("스냅샷이 생성된다") {
            verify { snapshotRepository.save(any()) }
        }
    }
}
```

**테스트 전략**:
- ✅ MockK로 repository 모킹
- ✅ verify로 호출 검증
- ✅ 이벤트별로 독립적인 테스트

### Projection 테스트
```kotlin
given("이벤트 스트림이 있고") {
    val events = listOf(LoanCreated(...), RepaymentRecorded(...))

    `when`("projection을 실행하면") {
        projectionService.project(events)

        then("read model이 업데이트된다") {
            val readModel = readModelRepository.findById(loanId)
            readModel.balance shouldBe expectedBalance
        }
    }
}
```

**테스트 전략**:
- ✅ In-memory DB 사용 (H2)
- ✅ 실제 이벤트 스트림으로 테스트
- ✅ Checkpoint 로직 검증

## 성능 최적화 팁

### 1. Gradle 병렬 실행

```bash
# gradle.properties에 추가
org.gradle.parallel=true
org.gradle.workers.max=8
org.gradle.caching=true
```

### 2. 테스트 그룹화

```bash
# 빠른 테스트만 먼저 실행
./gradlew :domain:test --tests "*UnitTest"

# 느린 통합 테스트는 나중에
./gradlew :bootstrap:test --tests "*IntegrationTest"
```

### 3. 테스트 캐싱 활용

```bash
# 변경된 테스트만 실행 (Gradle 기본 동작)
./gradlew test

# 강제 재실행이 필요한 경우만
./gradlew cleanTest test
```

## 테스트 리포트 생성

```markdown
# 🧪 Test Execution Report

## ✅ Test Results
- **Total Tests**: XXX
- **Passed**: XXX ✅
- **Failed**: XXX ❌
- **Skipped**: XXX ⏭️
- **Duration**: XX.Xs

## 📊 Module Breakdown
| Module | Tests | Passed | Failed | Duration |
|--------|-------|--------|--------|----------|
| domain | XX | XX | XX | X.Xs |
| application | XX | XX | XX | X.Xs |
| adapter | XX | XX | XX | X.Xs |
| bootstrap | XX | XX | XX | X.Xs |

## ❌ Failed Tests
1. `TestClassName.testMethodName`
   - **Error**: [Error message]
   - **Location**: [File:Line]
   - **Fix**: [Suggested fix]

## 📝 Recommendations
- [ ] Fix failing tests before merge
- [ ] Add missing test coverage for new events
- [ ] Review slow tests (>5s)

---

🤖 Generated with [pfct-ifis test-events skill](https://claude.com/claude-code)
```

## Token 최적화

- 병렬 테스트 실행으로 시간 단축
- 변경된 파일의 테스트만 실행 (전체 X)
- 테스트 리포트는 요약만 분석 (전체 로그 X)
- 실패한 테스트만 상세 분석

## 사용 예시

**User**: "test events"

**Action**:
1. 이벤트 관련 모든 테스트 실행
2. 병렬로 domain, application, adapter 테스트
3. 결과 요약 리포트 생성
4. 실패한 테스트 분석 및 fix 제안

**User**: "test LoanCreated"

**Action**:
1. LoanCreated 관련 테스트만 필터링
2. Domain, Application, Adapter에서 해당 테스트 실행
3. 빠른 피드백 제공
