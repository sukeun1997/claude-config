# Sentry 로깅 누락 패턴 탐지

프로젝트 전체에서 Sentry로 예외 스택트레이스가 전달되지 않는 로깅 패턴을 탐지하고 수정 방안을 제시합니다.

## 탐지 대상 패턴

### HIGH: Throwable 객체 누락 (Sentry에 스택트레이스 미전달)
```kotlin
// BAD: 문자열 보간으로 예외 전달 → Sentry에 스택트레이스 없음
logger.error("에러 발생: $e")
logger.error("에러 발생: ${e.message}")
logger.error("에러: {}", e.message)

// GOOD: Throwable을 마지막 인자로 전달
logger.error("에러 발생: {}", e.message, e)
logger.error("에러 발생", e)
```

### MEDIUM: Sentry.captureException 중복 호출
```kotlin
// BAD: SentryAppender가 이미 ERROR 로그를 Sentry로 전달하는데 중복 호출
logger.error("에러 발생", e)
Sentry.captureException(e)  // 중복!

// GOOD: logger.error만으로 충분 (SentryAppender가 처리)
logger.error("에러 발생", e)
```

### LOW: catch 블록에서 로깅 없음
```kotlin
// BAD: 예외를 삼킴
catch (e: Exception) {
    // nothing
}
```

## 실행 방법

1. Explore 에이전트로 프로젝트 전체 `logger.error` / `logger.warn` 패턴 탐색
2. 위 패턴별로 분류하여 테이블로 보고
3. 수정 방안 제시 (사용자 승인 후 수정)

## 출력 형식

| 우선순위 | 파일 | 라인 | 현재 패턴 | 수정 방안 |
|----------|------|------|-----------|-----------|
| HIGH | `CmsBatchFacade.kt` | 240 | `logger.error("...$e")` | `logger.error("...", e)` |

$ARGUMENTS
