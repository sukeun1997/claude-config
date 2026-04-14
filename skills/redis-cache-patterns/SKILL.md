---
name: redis-cache-patterns
description: Redis 캐시 전략, 키 설계, 무효화 패턴. Spring Boot + Redis 캐시 작업 시 자동 적용.
triggers:
  - "캐시 관련 코드 작성/수정"
  - "Redis 설정 변경"
  - "@Cacheable, CacheManager 사용"
user-invocable: false
---

# Redis Cache Patterns — Haru 프로젝트 가이드

## 1. Haru 캐시 전략 (현재)

### TTL 정책 (docs/plans에서 확정)
```
parse       → 24시간  (자연어 파싱 결과, 동일 입력 = 동일 출력)
classify    → 12시간  (할일 분류, 반일 유지)
top3        → 30분    (우선순위 추천, 자주 변경)
breakdown   → 7일     (할일 분해, 거의 변경 없음)
refine      → 24시간  (구체화 제안)
whatnow     → 없음    (실시간 컨텍스트 의존)
```

### 키 네이밍 규칙
```
haru:{domain}:{userId}:{identifier}

예시:
haru:ai:parse:{userId}:{inputHash}
haru:ai:top3:{userId}
haru:ai:breakdown:{userId}:{todoId}
haru:quota:ai:{userId}:{date}       ← 일일 쿼터
haru:quota:ai:global:{date}         ← 글로벌 쿼터
```

## 2. Spring Boot + Redis 통합

### 설정
```kotlin
@Configuration
@EnableCaching
class RedisConfig(
    @Value("\${spring.data.redis.host}") private val host: String,
    @Value("\${spring.data.redis.port}") private val port: Int,
) {
    @Bean
    fun cacheManager(connectionFactory: RedisConnectionFactory): RedisCacheManager {
        val defaults = RedisCacheConfiguration.defaultCacheConfig()
            .serializeValuesWith(SerializationPair.fromSerializer(GenericJackson2JsonRedisSerializer()))
            .entryTtl(Duration.ofHours(1)) // 기본 TTL

        val configs = mapOf(
            "ai:parse" to defaults.entryTtl(Duration.ofHours(24)),
            "ai:classify" to defaults.entryTtl(Duration.ofHours(12)),
            "ai:top3" to defaults.entryTtl(Duration.ofMinutes(30)),
            "ai:breakdown" to defaults.entryTtl(Duration.ofDays(7)),
        )

        return RedisCacheManager.builder(connectionFactory)
            .cacheDefaults(defaults)
            .withInitialCacheConfigurations(configs)
            .build()
    }
}
```

### @Cacheable 사용
```kotlin
@Cacheable(
    cacheNames = ["ai:parse"],
    key = "'haru:ai:parse:' + #userId + ':' + T(org.springframework.util.DigestUtils).md5DigestAsHex(#input.toByteArray())"
)
suspend fun parseNaturalLanguage(userId: UUID, input: String): ParseResult
```

### 캐시 무효화
```kotlin
// 단건 무효화
@CacheEvict(cacheNames = ["ai:top3"], key = "'haru:ai:top3:' + #userId")
fun evictTop3(userId: UUID)

// 할일 변경 시 관련 캐시 일괄 무효화
@CacheEvict(cacheNames = ["ai:top3", "ai:classify"], allEntries = false,
    key = "'haru:ai:*:' + #userId")  // ⚠️ 패턴 삭제는 별도 처리 필요
fun onTodoChanged(userId: UUID) {
    // RedisTemplate으로 패턴 삭제
    val keys = redisTemplate.keys("haru:ai:*:$userId:*")
    if (keys.isNotEmpty()) redisTemplate.delete(keys)
}
```

## 3. 캐시 패턴

### Cache-Aside (기본)
```
읽기: 캐시 확인 → miss → DB/API 조회 → 캐시 저장 → 반환
쓰기: DB 업데이트 → 캐시 무효화 (write-through 아님)
```

### 쿼터 카운터 (Atomic)
```kotlin
fun incrementQuota(userId: UUID, date: LocalDate): Long {
    val key = "haru:quota:ai:$userId:$date"
    val count = redisTemplate.opsForValue().increment(key) ?: 1L
    if (count == 1L) {
        redisTemplate.expire(key, Duration.ofDays(2)) // 여유 있게 2일
    }
    return count
}
```

### Stampede Prevention (핫키 보호)
```kotlin
// 동시 다발 캐시 미스 방지: @Cacheable(sync = true)
@Cacheable(cacheNames = ["ai:top3"], sync = true, ...)
suspend fun getTop3(userId: UUID): List<Todo>
```

## 4. 운영 주의사항

### Docker Compose (OCI 환경)
```yaml
redis:
  image: redis:7-alpine
  command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru
  volumes:
    - redis-data:/data
```
- `allkeys-lru`: 메모리 초과 시 LRU로 자동 제거 (OCI Free Tier 메모리 제한)
- RDB 스냅샷 기본 활성화 (재시작 시 캐시 유지)

### 모니터링
- `redis-cli INFO memory` → used_memory 확인
- `redis-cli INFO stats` → keyspace_hits/misses → hit rate 계산
- 캐시 히트율 80% 미만 시 TTL 조정 검토

### 주의
- `KEYS *` 프로덕션 금지 → `SCAN` 사용
- 직렬화: Jackson JSON (GenericJackson2JsonRedisSerializer)
- Redis 다운 시 fallback: DB 직접 조회 (캐시 없이 동작 가능해야 함)
