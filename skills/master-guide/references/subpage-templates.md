# Subpage Templates

각 서브페이지 템플릿은 `---` 구분자로 분리됩니다.

---

## [1] Quick Start (Spring+Kotlin)

# {기술명} — Quick Start (Spring+Kotlin)

## 의존성 추가

```kotlin
// build.gradle.kts
dependencies {
    implementation("{group}:{artifact}:{version}")
    testImplementation("{group}:{artifact}-test:{version}")
}
```

## application.yml 핵심 설정

```yaml
# application.yml
{기술명-소문자}:
  {key1}: {value1}
  {key2}: {value2}
  {key3}: {value3}
```

## Producer / Publisher 코드

```kotlin
@Service
class {Tech}Producer(
    private val {client}: {ClientType}
) {
    fun send(payload: {PayloadType}): {ResultType} {
        // 핵심 코드
    }
}
```

## Consumer / Subscriber 코드

```kotlin
@Component
class {Tech}Consumer {
    @{ListenerAnnotation}
    fun handle(message: {MessageType}) {
        // 핵심 코드
    }
}
```

## Testcontainers 로컬 환경

```kotlin
// src/test/kotlin/.../TestcontainersConfig.kt
@TestConfiguration
class TestcontainersConfig {
    @Bean
    fun {tech}Container(): {ContainerType} {
        return {ContainerType}("{image}")
            .withExposedPorts({port})
            .also { it.start() }
    }
}
```

## 동작 확인 방법

```bash
# 로컬 실행
./gradlew bootRun

# 연결 확인
{확인 명령어}

# 기본 동작 테스트
{테스트 명령어}
```

---

## [2] 프로덕션 체크리스트

# {기술명} — 프로덕션 체크리스트

## 보안

### 인증 / TLS / ACL
- [ ] TLS/SSL 활성화 확인
- [ ] 인증 방식 설정 (SASL/SCRAM, mTLS 등)
- [ ] ACL 또는 Role 기반 권한 설정
- [ ] 관리자 자격증명 기본값 변경

### 네트워크 격리
- [ ] 프로덕션 포트 외부 노출 차단
- [ ] VPC / 보안 그룹 설정
- [ ] 내부 통신 전용 엔드포인트 사용

### 환경변수 관리
- [ ] 민감 설정값 Secrets Manager / Vault 이동
- [ ] `.env` / 설정 파일 Git 미포함 확인
- [ ] 환경별 설정 분리 (dev / staging / prod)

---

## 모니터링

### 필수 메트릭
| 메트릭명 | 설명 | 임계값 기준 |
|---------|------|-----------|
| {metric1} | {desc1} | {threshold1} |
| {metric2} | {desc2} | {threshold2} |
| {metric3} | {desc3} | {threshold3} |

### 알림 임계값 (권장)
- 경고: {warning_condition}
- 위험: {critical_condition}
- 페이지: {page_condition}

### Actuator / Micrometer 설정

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, metrics, prometheus
  metrics:
    tags:
      application: ${spring.application.name}
```

---

## 테스트

### Testcontainers 통합 테스트
- [ ] 컨테이너 기반 통합 테스트 작성 완료
- [ ] 테스트 격리 확인 (각 테스트 독립 실행)
- [ ] CI 파이프라인 통합 확인

### 장애 시나리오 테스트
- [ ] 연결 끊김 → 재연결 동작 확인
- [ ] 타임아웃 → 적절한 에러 처리 확인
- [ ] 용량 초과 → 백프레셔 또는 거절 동작 확인

---

## 운영

### 백업 / 복구
- [ ] 백업 주기 설정 (데이터 중요도에 따라)
- [ ] 복구 절차 문서화 및 드릴 실행
- [ ] RTO / RPO 목표 정의

### 로그
- [ ] 구조화 로그 (JSON) 출력
- [ ] 로그 레벨 환경별 설정
- [ ] 민감 정보 로그 마스킹

### Graceful Shutdown
```yaml
server:
  shutdown: graceful
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```

---

## [3] 실전 패턴 & 안티패턴

# {기술명} — 실전 패턴 & 안티패턴

## 권장 패턴

### 패턴 1: {패턴명}

**문제**: {어떤 상황에서 필요한가}

**해결**:
```kotlin
// Good: {설명}
{코드 예시}
```

**효과**: {왜 이 방법이 좋은가}

---

### 패턴 2: {패턴명}

**문제**: {어떤 상황에서 필요한가}

**해결**:
```kotlin
// Good: {설명}
{코드 예시}
```

**효과**: {왜 이 방법이 좋은가}

---

### 패턴 3: {패턴명}

**문제**: {어떤 상황에서 필요한가}

**해결**:
```kotlin
// Good: {설명}
{코드 예시}
```

**효과**: {왜 이 방법이 좋은가}

---

## 안티패턴

### ❌ 안티패턴 1: {안티패턴명}

**증상**: {어떤 증상이 나타나는가}

**문제**:
```kotlin
// Bad: {왜 나쁜가}
{나쁜 코드 예시}
```

**올바른 방법**:
```kotlin
// Good: {올바른 방법}
{좋은 코드 예시}
```

---

### ❌ 안티패턴 2: {안티패턴명}

**증상**: {어떤 증상이 나타나는가}

**문제**:
```kotlin
// Bad: {왜 나쁜가}
{나쁜 코드 예시}
```

**올바른 방법**:
```kotlin
// Good: {올바른 방법}
{좋은 코드 예시}
```

---

### ❌ 안티패턴 3: {안티패턴명}

**증상**: {어떤 증상이 나타나는가}

**문제**:
```kotlin
// Bad: {왜 나쁜가}
{나쁜 코드 예시}
```

**올바른 방법**:
```kotlin
// Good: {올바른 방법}
{좋은 코드 예시}
```

---

## [4] 트러블슈팅 (증상별 의사결정 트리)

# {기술명} — 트러블슈팅

## 증상별 의사결정 트리

### 증상 1: 메시지/데이터가 안 들어온다

```
메시지/데이터가 안 들어온다
│
├─ 연결 자체가 안 되는가?
│  ├─ Yes → 네트워크/방화벽 확인 → 포트 개방 여부 → 자격증명 확인
│  └─ No → 아래 계속
│
├─ 연결은 되는데 데이터가 없는가?
│  ├─ 소스(Producer/Publisher) 동작 확인
│  ├─ 토픽/큐/키 이름 오타 확인
│  └─ 파티션/라우팅 설정 확인
│
└─ 일부만 수신되는가?
   ├─ Consumer Group / 구독 설정 확인
   └─ 오프셋/ACK 설정 확인
```

### 증상 2: 성능이 느리다

```
성능이 느리다 (지연 / 처리량 부족)
│
├─ 지연(Latency)이 높은가?
│  ├─ 배치 크기 / flush 설정 확인
│  ├─ 네트워크 레이턴시 확인
│  └─ 직렬화/역직렬화 비용 확인
│
└─ 처리량(Throughput)이 낮은가?
   ├─ 파티션 / 샤드 수 확인
   ├─ Consumer 병렬도 확인
   └─ 리소스(CPU/메모리/디스크) 포화 확인
```

### 증상 3: 연결이 자꾸 끊긴다

```
연결이 자꾸 끊긴다
│
├─ 타임아웃 오류인가?
│  ├─ 타임아웃 설정값 확인 (heartbeat, session timeout 등)
│  └─ GC pause / 부하 스파이크 확인
│
├─ 재연결 루프인가?
│  ├─ Backoff 설정 확인
│  └─ 자격증명 만료 확인
│
└─ 브로커/서버 문제인가?
   ├─ 서버 로그 확인
   └─ 리소스 포화 확인
```

---

## FAQ

| 증상 | 원인 | 해결 |
|------|------|------|
| {symptom1} | {cause1} | {solution1} |
| {symptom2} | {cause2} | {solution2} |
| {symptom3} | {cause3} | {solution3} |
| {symptom4} | {cause4} | {solution4} |

---

## 디버깅 명령어

```bash
# 연결 상태 확인
{connection_check_cmd}

# 로그 확인
{log_check_cmd}

# 메트릭 확인
{metrics_check_cmd}

# 상태 확인
{status_check_cmd}
```

---

## [5] 스케일링 가이드

# {기술명} — 스케일링 가이드

## 중규모 (트래픽 10x 증가 기준)

### 설정 변경점

```yaml
# application.yml — 중규모 설정
{key1}: {mid_value1}
{key2}: {mid_value2}
{key3}: {mid_value3}
```

### 아키텍처 변경점
- {change1}: {이유}
- {change2}: {이유}
- {change3}: {이유}

### 주의사항
- {caution1}
- {caution2}

---

## 대규모 (트래픽 100x+ 기준)

### 클러스터링 / 분산 구성

```yaml
# 클러스터 구성 예시
{cluster_config}
```

**구성 포인트**:
- 최소 노드 수: {min_nodes}
- 복제 계수: {replication_factor}
- 샤드/파티션 수 산정 기준: {sharding_guide}

### 샤딩 / 파티셔닝 전략
- {strategy1}: {설명}
- {strategy2}: {설명}

### 비용 최적화
| 항목 | 소규모 | 중규모 | 대규모 |
|------|--------|--------|--------|
| {cost_item1} | {small1} | {mid1} | {large1} |
| {cost_item2} | {small2} | {mid2} | {large2} |
| {cost_item3} | {small3} | {mid3} | {large3} |

**절감 전략**:
- {saving_tip1}
- {saving_tip2}

### 운영 자동화
- [ ] Auto-scaling 설정 (CPU/메모리/큐 깊이 기준)
- [ ] 자동 재시작 / 자가 복구
- [ ] 카나리 배포 지원 확인

---

## [6] 버전 히스토리

# {기술명} — 버전 히스토리

## 현재 권장 버전

| 구분 | 버전 | Spring Boot 호환 | 비고 |
|------|------|-----------------|------|
| 안정 (권장) | {stable_version} | {spring_compat} | 프로덕션 권장 |
| 최신 | {latest_version} | {latest_spring_compat} | 신기능 포함 |
| LTS | {lts_version} | {lts_spring_compat} | 장기 지원 |

> 기준일: {date}

---

## 버전별 상세

### {version_n} ({release_date_n})

**주요 변경**:
- {change1}
- {change2}

**Breaking Changes**:
- {breaking1}

**Spring Boot 호환**: {spring_compat_n}

**마이그레이션 가이드**: {migration_url_n}

---

### {version_n-1} ({release_date_n-1})

**주요 변경**:
- {change1}
- {change2}

**Breaking Changes**:
- (없음)

**Spring Boot 호환**: {spring_compat_n-1}

---

### {version_n-2} ({release_date_n-2})

**주요 변경**:
- {change1}
- {change2}

**Breaking Changes**:
- {breaking1}

**Spring Boot 호환**: {spring_compat_n-2}

---

## 업그레이드 권장 경로

```
{old_version} → {intermediate} → {current_stable}
```

**주의 사항**: {upgrade_caution}
