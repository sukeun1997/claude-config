---
name: kotlin-patterns
description: Kotlin 관용구, 코루틴, Spring Boot 통합 패턴. Kotlin 백엔드 코드 작성/리뷰 시 자동 적용.
triggers:
  - "*.kt 파일 작성/수정"
  - "Spring Boot 백엔드 구현"
  - "코루틴, 확장함수, DSL 관련 작업"
---

# Kotlin Patterns — Haru 프로젝트 가이드

## 1. Kotlin 관용구

### Scope Functions 선택 기준
```
let   → nullable 체인 (.let { })
run   → 객체 초기화 + 결과 반환
apply → 객체 설정 (빌더 패턴 대체)
also  → 사이드 이펙트 (로깅, 검증)
with  → 이미 non-null인 객체 다수 접근
```

### Data Class 활용
- DTO는 항상 `data class` + suffix `Request`/`Response`
- `copy()` 로 불변 업데이트 (기존 객체 변경 금지)
- Destructuring은 2-3 필드까지만 (가독성)

### Sealed Class / Sealed Interface
- API 응답 분기: `sealed interface ApiResult<out T>`
- 도메인 이벤트: `sealed class DomainEvent`
- `when` 절에서 `else` 없이 exhaustive 매칭 강제

### Extension Functions
- 유틸 함수는 extension으로 (StringUtils 같은 클래스 금지)
- 범위 제한: `internal` 또는 패키지 내 사용
- 기존 라이브러리 클래스 확장 시 접두사로 네이밍 충돌 방지

### Null Safety
- `!!` 사용 금지 (테스트 코드 예외)
- `?.let { }` 또는 `?: return` / `?: throw` 패턴
- 외부 API 응답은 항상 nullable로 수신 후 검증

## 2. 코루틴 패턴

### 구조적 동시성
```kotlin
// ✅ 올바른 패턴: coroutineScope로 구조적 동시성
suspend fun loadDashboard(userId: UUID): Dashboard = coroutineScope {
    val todos = async { todoService.findByUser(userId) }
    val stats = async { statsService.calculate(userId) }
    Dashboard(todos.await(), stats.await())
}

// ❌ 금지: GlobalScope
GlobalScope.launch { ... }
```

### Dispatcher 선택
```
Dispatchers.IO     → DB 쿼리, 파일 I/O, HTTP 호출
Dispatchers.Default → CPU 집약 (AI 응답 파싱, 대량 데이터 처리)
Dispatchers.Main   → 사용하지 않음 (서버 사이드)
```

### Spring Boot + 코루틴
- `suspend fun` 컨트롤러 메서드 → Spring WebFlux 불필요, MVC에서 지원
- `@Transactional` + `suspend` → 주의: JPA는 코루틴 직접 지원 안함
- 트랜잭션 내부에서 `async` 금지 → 별도 스레드에서 커넥션 공유 불가

## 3. Spring Boot + Kotlin 통합

### 생성자 주입 (val 사용)
```kotlin
// ✅ Kotlin 스타일
@Service
class TodoService(
    private val todoRepository: TodoRepository,
    private val cacheManager: CacheManager,
)

// ❌ @Autowired field injection 금지
```

### JPA Entity
```kotlin
@Entity
@Table(name = "todos")
class Todo(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    var title: String,

    // ... mutable 필드는 var, 식별자는 val
) : BaseTimeEntity()
```
- `data class`를 Entity로 사용 금지 (equals/hashCode 문제)
- `open class` 또는 `allOpen` 플러그인 사용
- `lateinit var` 지양 → 생성자 파라미터 우선

### 에러 처리
```kotlin
// 도메인 예외: sealed class 계층
sealed class HaruException(message: String) : RuntimeException(message) {
    class NotFound(resource: String, id: Any) : HaruException("$resource not found: $id")
    class Forbidden(message: String = "접근 권한이 없습니다") : HaruException(message)
    class QuotaExceeded(limit: Int) : HaruException("일일 쿼터 초과: $limit")
}

// @RestControllerAdvice에서 매핑
@ExceptionHandler(HaruException.NotFound::class)
fun handleNotFound(e: HaruException.NotFound) = ResponseEntity.status(404).body(ErrorResponse(e))
```

### 테스트
- Kotest 5 + MockK (JUnit 5 + Mockito 대신)
- `StringSpec` 또는 `FunSpec` 스타일
- `every { }` / `coEvery { }` 로 모킹
- `verify(exactly = 1) { }` / `coVerify { }` 로 검증

## 4. Gradle Kotlin DSL
- `plugins { }` 블록에 버전 명시 (version catalog 권장)
- `dependencies { }` 에서 `implementation()` / `testImplementation()`
- `kotlin("jvm")`, `kotlin("plugin.spring")`, `kotlin("plugin.jpa")` 필수

## 적용 시점
- Kotlin 파일(.kt) 작성 또는 수정 시 이 패턴 참고
- 코드 리뷰 시 위 컨벤션 위반 체크
- 새 서비스/컨트롤러 생성 시 템플릿으로 활용
