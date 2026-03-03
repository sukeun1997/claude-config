# Avro Schema-to-Mapper Field Validation

**Extracted:** 2026-02-27
**Context:** Kafka Avro 이벤트 매핑의 완전성/정확성 검증 시

## Problem

Avro 스키마(Schema Registry) → 생성된 Java 클래스 → Kotlin Mapper 간 필드 매핑이 누락되거나 잘못된 타입으로 변환되는 경우를 탐지해야 한다.

## Solution

**3계층 교차 검증**:

1. **Avro 필드 목록 추출**: 생성된 Java 클래스에서 setter 패턴 검색
   ```
   Grep pattern: "public .* set\w+\("
   Path: build/generated-main-avro-java/.../*.java
   ```
   - 스키마 JSON 파싱보다 정확하고 빠름
   - instance setter와 Builder setter 모두 나오므로 중복 제거 필요

2. **Mapper 코드 분석**: 매퍼의 `.setXxx()` 호출 목록과 1번 결과 비교
   - 누락: Avro에 있으나 매퍼에서 set 안 하는 필드
   - 초과: 매퍼에서 set하지만 Avro에 없는 필드 (컴파일 에러로 잡힘)

3. **도메인 엔티티 대조**: 매퍼의 소스 필드가 도메인 엔티티의 올바른 필드인지 확인
   - 의도적 미포함 판별: 부모에 중복, 유도 가능, 이벤트 성격상 불필요

**검증 체크리스트**:
- [ ] 모든 Avro 필드가 매퍼에서 set되는지
- [ ] nullable 필드의 default 값이 스키마에 정의되어 있는지 (미설정 시 안전한지)
- [ ] 타입 변환 일관성:
  - Long(금액) → `BigDecimal.valueOf(value).setScale(2)` → decimal(18,2)
  - BigDecimal(비율) → 직접 전달 → decimal(18,6)
  - LocalDate/LocalDateTime → `.toString()` → string
  - Enum → `.name` → string
  - Boolean/Int → 직접 전달 (auto-boxing)
- [ ] computed property 사용 시 의미 정확한지 (예: `totalAmount`이 net 값인지 raw 값인지)

## Example

```kotlin
// 금액 필드: Long → BigDecimal(scale=2)
.setTotalAmount(toLong2Decimal(totalAmount))

// 비율 필드: BigDecimal 직접 전달 (Avro가 scale=6으로 변환)
.setOverdueInterestRate(overdueInterestRate)

// 날짜 필드: toString()으로 ISO-8601 문자열 변환
.setValidDate(validDate.toString())

// nullable 날짜: safe call
.setLastRepaidDatetime(lastRepaidDatetime?.toString())

// 외부 참조 필드: scheduleMap에서 조회
.setAgreedInterestStartDate(schedule?.scheduleStartDate?.toString())
```

## When to Use

- Avro 이벤트 매퍼를 새로 작성하거나 수정한 후
- Avro 스키마 버전 업그레이드 (v1 → v2) 시 필드 매핑 검증
- 코드 리뷰에서 Avro 매퍼 변경이 포함된 경우
- `invoice_created`, `loan_executed` 등 도메인 이벤트 매핑 확인 시
