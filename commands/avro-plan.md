# Avro Event Migration SPIKE Analysis

InAPI JSON 이벤트를 Glue(Avro)로 전환하기 위한 체계적 분석을 수행하고 Notion 페이지에 문서화합니다.
**SPIKE의 최종 목적**: 이후 스프린트에서 실제 작업할 때 참고할 문서. 각 이벤트별로 "무엇을 해야 하는지", "블로커는 무엇인지", "어떤 순서로 해야 하는지"가 명확해야 함.

## 입력

사용자로부터 아래 정보를 받습니다:
1. **이벤트명**: JSON 토픽명 / Glue 토픽명 (예: `overdue_end` / `overdue_ended`)
2. **소비자 목록**: 서비스별 컨슈머와 역할 (예: `investment: on_loan_overdue_end (funding)`)
3. **Notion 페이지 URL** (선택): 결과를 작성할 페이지

## Known Issues (반복 발견된 공통 이슈)

분석 시 아래 이슈를 항상 체크합니다. 해당되면 분석 결과에 명시적으로 언급합니다.

| 이슈 | 영향 | 해결 방안 |
|------|------|-----------|
| GlueKafkaConfig `earliest` 하드코딩 | 새 Glue 컨슈머가 기존 메시지 전체 소비 | consumer group offset 사전 설정 (`latest`로 pre-set) |
| CMS `deduplicationId`에 topicName 포함 | JSON/Glue 동시 운영 시 dedup 실패 (다른 topicName) | topicName 제거 필요 |
| Investment Faust `json` serializer | Avro 메시지 파싱 불가 | Avro deserializer 추가 필요 |
| `loan_product_application_id` 부재 | institution/embedded_finance 핸들러에서 별도 API 호출 필요 | 스키마에 nullable 추가 제안 |
| `INAPI_OUTBOXTABLE_ID` 헤더 의존 | banking-loan 발행 시 헤더 미존재 가능 | 헤더 세팅 확인 또는 대체 키 사용 |
| DLT Handler 헤더 차이 | Publisher: `OUTBOXTABLE_ID`, INAPI: `INAPI_OUTBOXTABLE_ID` | 양쪽 모두 지원하도록 수정 |

## 분석 체크리스트

아래 항목을 순서대로 분석합니다. **반드시 실제 코드를 확인한 후 작성** (추측 금지).

### Phase 1: 발행 측 분석 + 이관 가능성 판단

병렬로 탐색 에이전트를 실행합니다:

#### 1-A. InAPI 이벤트 정의 — `~/IdeaProjects/inapi` 에서:
- JSON 이벤트 클래스 (필드 목록)
- Glue 이벤트 스키마 (필드 목록)
- Producer 위치 (JSON + Glue)
- 발행 트리거 (어떤 비즈니스 로직에서 발행되는지)
- 발행 시점의 멱등성 보장 방식

#### 1-B. banking-loan 현황 — `~/IdeaProjects/banking-loan` 에서:
- Avro 스키마 존재 여부 (`common/kafka/src/main/avro/`)
- 관련 도메인 로직 존재 여부
- 이벤트 발행 코드 or TODO 존재 여부
- 컨슈머 존재 여부

#### 1-C. 발행 이관 가능성 판단 (CRITICAL)

아래 체크리스트로 이관 가능 여부를 판단합니다:

```
이관 가능 조건 (모두 충족해야 함):
□ banking-loan에 해당 도메인 로직이 존재하는가?
□ Avro 스키마의 모든 필드를 banking-loan에서 채울 수 있는가?
□ 발행 트리거 시점이 inapi와 동일하거나 대체 가능한가?
□ 멱등성이 보장되는가?
```

판단 결과를 3단계로 분류:

| 분류 | 설명 | 판단 기준 |
|------|------|-----------|
| **A. Glue 전환만** | inapi에서 계속 발행, banking-loan은 JSON→Glue 컨슈머 전환만 | 이관 조건 1개 이상 미충족 |
| **B. banking-loan 이관** | banking-loan에서 발행 인수 | 이관 조건 모두 충족 |
| **C. 컨슈머 없음/불필요** | 전환 작업 자체가 불필요하거나 최소 | banking-loan에 소비자가 없음 |

> 예시:
> - `loan_executed`: **A** — 대출 실행 자체가 inapi에서 발생 + 35개 필드 중 ~11개 banking-loan 부재
> - `overdue_started`: **B** — banking-loan에 연체 감지 로직 존재, 모든 필드 채울 수 있음
> - `loan_closed`: **C** — 현재 banking-loan에 소비자 없음 (신규 소비 시작에 해당)

### Phase 2: 소비자 분석 + banking-loan 내부 Glue 준비도

#### 2-A. 외부 소비자 분석

사용자가 알려준 소비자 각각에 대해:

1. **실제 코드 확인** (탐색 에이전트):
   - 핸들러 코드 전문
   - 소비하는 토픽명 (JSON? Glue?)
   - Consumer Group
   - 사용하는 이벤트 필드 목록
   - 처리 로직 (DB write, API 호출, 상태 변경 등)

2. **멱등성 분석**:
   - dedup 메커니즘 존재 여부
   - 동일 이벤트 2번 소비 시 부작용
   - JSON + Glue 동시 운영 시 안전한지

3. **JSON → Glue 전환 영향** (CRITICAL):
   - **스키마 차이**: JSON에는 있지만 Glue에는 없는 필드 → 소비자 동작 불가 여부
   - **토픽명 변경**: `{event}.v1` → `{event_past_tense}.v1` 패턴
   - **직렬화 포맷**: JSON deserializer → Avro deserializer 변경 필요 여부
   - **auto.offset.reset**: 새 토픽 + 새 consumer group → offset 정책 주의
     - investment(Faust): `latest` (안전)
     - banking-report GlueKafkaConfig: `earliest` (위험 — Known Issues 참조)

#### 2-B. banking-loan 내부 컨슈머 Glue 준비도

banking-loan 자체 모듈의 Glue 전환 상태를 확인합니다:

```
| 모듈 | Glue 컨슈머 존재 | 멱등성 보장 | 필요 작업 |
|------|:----------------:|:----------:|-----------|
| repayment | 있음 (disabled) | O | 활성화 |
| settlement | 없음 | X | 신규 구현 + 멱등성 추가 |
| cms | 없음 | △ | 신규 구현 + deduplicationId 수정 |
| loan | 없음 | - | 해당 없음 |
```

> 위 표는 예시입니다. 실제 코드를 탐색하여 정확한 상태를 기입합니다.

### Phase 3: Cross-event 의존성 분석

개별 이벤트만 분석하지 않고, **같이 이관해야 하는 이벤트 그룹**을 식별합니다:

```
의존성 체크:
□ 같은 consumer group으로 여러 토픽 소비?
  (예: sync-overdue → overdue_start + overdue_end)
□ 같은 도메인 로직에서 여러 이벤트 발행?
  (예: 연체 시작/해소가 같은 배치)
□ 같은 선행 작업 필요?
  (예: overdue_start_seq/overdue_end_seq 필드 추출이 둘 다 필요)
□ 소비자가 여러 이벤트를 조합하여 처리?
  (예: overdue_started 수신 후 overdue_ended로 해소 판단)
```

→ 의존성이 발견되면 **그룹으로 묶어서** 이관 전략을 수립합니다.

### Phase 4: 스키마 필드 추가 제안

**간단한 필드(1~2개) 추가로 소비자의 별도 API 호출을 줄일 수 있는 경우를 적극 제시:**

1. Glue 스키마에 없지만 소비자가 필요로 하는 필드 식별
2. 소비자가 현재 별도 API 호출로 가져오는 정보 식별
3. 추가 시 하위 호환성 (nullable + default null) 확인
4. 다른 이벤트 스키마에 동일 필드가 있는 선례 확인 (예: `loan_executed`에 `loan_product_application_id` 존재)

### Phase 5: 이관 전략 수립

1. **선행 작업** (banking-loan 측)
2. **스키마 불일치 해결** (있는 경우)
3. **동시 발행 검증** (dev 환경)
4. **inapi 발행 중단** (소비자 전환 완료 후)
5. **JSON 토픽 제거**

**각 단계에 난이도/블로커/의존성을 태깅합니다:**

```
| 단계 | 작업 내용 | 난이도 | 블로커 | 의존성 |
|------|-----------|:------:|--------|--------|
| 1 | Glue 컨슈머 구현 | M | 없음 | - |
| 2 | deduplicationId 수정 | S | 없음 | - |
| 3 | dev 환경 동시 발행 테스트 | M | dev 배포 필요 | 1, 2 |
| 4 | 소비자 전환 확인 | S | 외부 팀 확인 | 3 |
| 5 | inapi JSON 발행 중단 | S | 4 완료 필수 | 4 |
```

## 출력 형식

분석 결과를 아래 구조로 정리합니다:

```
# 변경
- 요약 bullet points

# 분류: A/B/C (Glue 전환만 / banking-loan 이관 / 컨슈머 없음)
- 판단 근거

# 현황
## inapi (발행 측)
- JSON/Glue 토픽, 트리거, 멱등성
- JSON/Glue 페이로드 비교

## banking-loan
- 관련 로직 및 이벤트 발행 상태
- 내부 컨슈머 Glue 준비도 (표)

# 판단
## 컨슈머 전환
## 발행 이관

# JSON → Glue 전환 시 소비자 영향 분석
## 스키마 차이 (표)
## 토픽명 변경
## 직렬화 포맷 변경
## 소비자별 멱등성 & 동시 운영 안전성 (표)

# Known Issues 해당 여부
- 위 Known Issues 중 이 이벤트에 해당하는 항목 명시

# Cross-event 의존성
- 같이 이관해야 하는 이벤트 그룹 (해당 시)

# 스키마 필드 추가 제안 (해당 시)

# 이관 전략
## Phase 1~5 (난이도/블로커/의존성 표)

# 스프린트 플래닝 요약

### 즉시 가능 (블로커 없음)
- [ ] 작업A (난이도: S/M/L)

### 블로커 있음
- [ ] 작업B — 블로커: XXX 해결 후 가능

### 다른 이벤트와 묶어서 진행
- [ ] 작업C + 작업D — 이유: 공통 선행 작업 공유
```

## 작업 흐름

1. **코드 분석 먼저** → 3개 병렬 탐색 (InAPI, banking-loan, 소비자 서비스)
2. **사용자에게 분석 결과 제시** (Notion 작성 전)
3. **사용자 확인 후** Notion 페이지에 작성
4. 사용자가 수정 요청하면 반영

## 주요 참조

- InAPI 프로젝트: `~/IdeaProjects/inapi`
- Banking-loan 프로젝트: `~/IdeaProjects/banking-loan`
- Banking-report 프로젝트: `~/IdeaProjects/banking-report`
- Investment 프로젝트: `~/IdeaProjects/investment`
- Avro 스키마: `banking-loan/common/kafka/src/main/avro/`
- SPIKE Notion 상위 페이지: `320705665ab6802388a5ffd38f793976`
- 작업고민 Notion 페이지: `321705665ab680bba21cfb37c4dd8bf1`

## 기억할 규칙

- **Notion 작성 전 반드시 사용자에게 내용 먼저 제시**
- **코드 검증 후 작성** — 추측 금지
- **의문점은 의문문으로** 남기기 (단정짓지 않기)
- **`auto.offset.reset = earliest` 경고** — 모든 새 Glue 컨슈머에 대해 언급
- **필드 추가 제안** — 간단한 필드 추가로 API 호출 줄일 수 있으면 적극 제시
- **Known Issues 체크** — 분석 시 Known Issues 테이블을 항상 대조
- **Cross-event 의존성** — 개별 이벤트 분석 후 반드시 그룹 묶기 시도
- **스프린트 플래닝 요약** — 출력 마지막에 즉시 가능/블로커 있음/묶어서 진행 분류 필수
