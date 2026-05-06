---
name: triage
description: "버그 트리아지 — 5개 서브에이전트 병렬로 다른 가설 조사(타입/레이스/마이그레이션/환경/상류) 후 심판이 순위화된 근본 원인 리포트 생성. Use when user says '/triage', '버그 트리아지', '원인 분석', '왜 안 돼', 같은 수정이 2회 이상 빗나갔을 때."
---

# /triage — 병렬 버그 트리아지 (Fan-out Diagnosis)

버그 증상을 받아 5개 가설을 **병렬 경쟁**시키고 심판이 순위화한다. 순차 가설 테스트("첫 수정 실패 → 다른 수정 시도") 대신 진단 먼저 수렴.

report.html(2026-04-18)이 식별한 공략 대상: **잘못된 접근 34건, 버그 코드 32건**. "시그널 레이스로 오진했지만 실제는 타입 미스매치" 같은 1순위 오진 패턴을 직공.

## When to Apply

- `/triage` 또는 `/triage <증상 설명>`
- 버그 증상이 있고 근본 원인이 확정되지 않았을 때
- 첫 수정이 실패하여 "다른 수정 시도" 직전 (이 경우 강제 트리거 권장)
- `/review`로는 부적합(원인 불명) — /review는 "이 코드 괜찮나?", /triage는 "왜 안 되나?"

## /review vs /triage 구분

| 축 | /review | /triage |
|---|---|---|
| 입력 | 이미 쓴 코드 (diff) | 증상/에러 로그 |
| 에이전트 | code/security/quality/architect — 같은 코드에 다른 렌즈 | 타입/레이스/데이터/환경/상류 — 다른 가설에 배타적 조사 |
| 출력 | AUTO-FIX/ASK 이슈 테이블 | 순위화된 근본 원인 + 신뢰도 |
| 다음 행동 | executor 수정 | 심판 승인 후에만 수정 |

## Arguments

- `<증상 설명>` (optional): 자유 형식 증상. 미지정 시 사용자에게 인터뷰.
- `--hypotheses <list>`: 가설 커스터마이즈 (기본 5개 대신). 예: `--hypotheses=타입,레이스,환경`
- `--no-judge`: 심판 생략, 5개 리포트만 반환 (수근이 직접 판단)
- `--fix-ok`: 심판 승인 후 자동으로 executor 디스패치 (기본은 수근 승인 대기)

## Pipeline

```
Phase 0: Symptom Capture (증상 수집)
  → 증상 + 재현 단계 + 관련 에러 로그 + 최근 커밋 확정
  ↓
Phase 1: Fan-out Diagnosis (병렬 가설 조사)
  → 5개 서브에이전트 병렬 — 각자 다른 가설 클래스 조사
  → .claude/triage/<ts>/<hypothesis>.md 에 리포트 기록
  ↓
Phase 2: Judge (심판 종합)
  → 5개 리포트 읽고 순위화, 신뢰도, 리스크 레벨 산출
  ↓
Phase 3: User Approval Gate
  → 수근이 심판 진단 승인/기각
  → 승인 시에만 코드 수정 허용
  ↓
Phase 4 (optional, --fix-ok): Fix Dispatch
  → 승인된 진단 기반 executor 디스패치
```

## Phase 0: Symptom Capture

아래 4개를 확정하지 않으면 Phase 1 진입 금지. 부족한 항목은 수근에게 질문:

1. **증상 (Observable)**: 무엇이 일어나거나 일어나지 않는가? (사용자 관점)
2. **재현 단계**: 증상을 발생시키는 최소 절차
3. **에러/로그**: 스택 트레이스 또는 로그 라인 (있으면)
4. **범위**: 언제부터? 최근 커밋 SHA / 배포 시점

이 정보는 `triage/<ts>/symptom.md`에 저장해 5개 에이전트가 공유한다.

## Phase 1: Fan-out — 5개 가설 에이전트 (병렬)

모든 에이전트 동시 디스패치 (Agent 도구 5개를 single message에). 각자 **자기 가설에 유리한/불리한 증거만** 조사, 타 가설 영역 침범 금지.

### H1: 타입/계약 미스매치 (executor-sonnet, 또는 debugger-sonnet)
```
프로젝트 증상:
  {symptom.md}

조사 영역:
- 타입 미스매치: DTO ↔ Entity, API 응답 shape ↔ 클라이언트 타입
- null/undefined 경로: Optional 해제, 기본값 누락
- 제네릭/와일드카드 타입 유실
- 프로토콜/인터페이스 계약 변경 (메서드 시그니처 diff)

조사 방법:
- 에러 메시지에서 타입 이름 추출 → 정의 파일 Read
- 최근 커밋에서 타입 변경 diff 확인
- 호출자/구현자 양쪽 타입 대조

출력 (.claude/triage/{ts}/type-mismatch.md):
- 가설 재진술: "증상이 X 타입의 Y 필드 미스매치에서 발생한다"
- 찬성 증거 (파일:라인 인용 필수, 최소 2개)
- 반대 증거 (이 가설이 틀릴 수 있는 이유)
- 재현 단계: 타입 레벨에서 증상 트리거하는 최소 테스트
- 신뢰도: 0-100 (증거 강도 기반)
- 예상 수정 범위: 파일 N개, 추정 라인 수
```

### H2: 레이스/비동기 순서 (executor-sonnet)
```
조사 영역:
- async/await 누락, Promise 체인 단절
- 이벤트 핸들러 순서 (SwiftUI, React, Kafka)
- 공유 상태 동시 수정
- 트랜잭션 경계 vs 외부 I/O

조사 방법:
- 재현이 간헐적/타이밍 의존적인지 확인 (증상 재현율)
- 공유 상태/리소스 접근 경로 map
- @Async, coroutine launch, dispatch_async 등 비동기 경계 나열

출력 (.claude/triage/{ts}/race-condition.md): H1과 동일 스키마
```

### H3: 데이터/마이그레이션 드리프트 (executor-sonnet)
```
조사 영역:
- DB 스키마 vs 코드 Entity 불일치
- 마이그레이션 미실행/중복 실행
- 레거시 데이터가 새 코드 가정 위반 (nullable 컬럼 실제 값, enum 확장)
- 테이블/컬럼명 misspell (Bkmemo vs Bkjukyo 같은 패턴)

조사 방법:
- 마이그레이션 히스토리 vs Entity 정의 비교
- 문제 레코드의 실제 DB 값 조회 (가능하면 MySQL MCP 활용)
- .env의 DB 타겟 확인 (로컬 vs 프로덕션)

출력: H1과 동일 스키마
```

### H4: 환경/설정/배포 아티팩트 (executor-sonnet)
```
조사 영역:
- 환경변수 누락, 잘못된 값
- 배포된 아티팩트가 최신 코드 미포함 (JAR 캐시)
- 서로 다른 환경(로컬/스테이징/프로덕션) 간 차이
- LaunchAgent, cron, 중복 실행 프로세스
- 런타임 버전 (bun, node, jdk, python)

조사 방법:
- .env 파일 나열, 필수 키 확인
- `ps aux | grep <process>`, launchctl list 등으로 중복 프로세스 확인
- 배포 로그 + 아티팩트 타임스탬프 대조 (/deploy-verified 재사용 가능)

출력: H1과 동일 스키마
```

### H5: 상류/외부 의존성 변경 (executor-sonnet)
```
조사 영역:
- 외부 API 응답 shape/필드 변경
- 의존성 패키지 업데이트 (package-lock, gradle lock)
- 서드파티 서비스 장애/rate limit
- SDK 메이저 업그레이드 (Spring Boot 3.x, Swift 6 등)

조사 방법:
- 최근 package-lock.json/gradle.lock diff
- 외부 API 응답 실제 캡처 (curl/http로 raw 응답)
- 의존성 breaking change 노트 조사 (Context7 MCP)

출력: H1과 동일 스키마
```

### 에이전트 공통 규칙
- **가설에 유리/불리 증거 모두 수집**. 확증 편향 금지.
- **파일:라인 인용 필수**. "looks related" 금지.
- **자기 가설만 조사**. 타 가설을 비판하지 않음 — 심판의 역할.
- **리포트 상한 3000자** (컨텍스트 보호).

## Phase 2: Judge — 심판 종합 (critic-opus)

```
Agent(critic, model=opus, name="triage-judge"):
  "5개 진단 리포트를 종합하여 근본 원인 순위를 매기세요.

   입력:
   - .claude/triage/{ts}/symptom.md
   - .claude/triage/{ts}/type-mismatch.md
   - .claude/triage/{ts}/race-condition.md
   - .claude/triage/{ts}/data-drift.md
   - .claude/triage/{ts}/env-artifact.md
   - .claude/triage/{ts}/upstream-dep.md

   평가 기준:
   1. 증거 강도: 인용된 파일:라인이 실제로 가설을 뒷받침하는가?
   2. 재현 설명력: 이 가설이 증상을 재현 단계 수준에서 설명하는가?
   3. 반증 내성: 반대 증거가 있어도 가설이 버티는가?
   4. 수정 범위 타당성: 제안된 수정이 증상을 해소하는가?
   5. 가설 상호작용: 복합 원인(H1 + H3 같은)인가 단일 원인인가?

   출력 형식 (.claude/triage/{ts}/verdict.md):

   ## 순위
   1위: <가설명> (신뢰도 N%) — <한 줄 요약>
   2위: ...
   3위: ...

   ## 1위 상세
   - 가설: ...
   - 핵심 증거 (3개): 파일:라인 인용
   - 재현 경로: ...
   - 수정 제안: 파일 N개, 예상 라인
   - 리스크: LOW/MEDIUM/HIGH
   - 부작용: ...

   ## 기각된 가설
   가설명 — 기각 사유 (반대 증거)

   ## 복합 원인 여부
   N위와 M위가 동시에 기여하는 경우: ...

   ## 불확실성
   - 추가 조사 필요 사항 (있다면)
   - 재현 실패 시 fallback 플랜

   순위 1위가 신뢰도 70% 이상일 때만 'CLEAR'.
   여러 가설이 비슷하게 약하면 'INCONCLUSIVE' — 추가 정보 요청."
```

## Phase 3: User Approval Gate

심판의 verdict.md를 수근에게 제시:

```
[진단 결과]
1위: 타입 미스매치 (신뢰도 82%)
  - 증거: PaymentDto.java:45 vs PaymentResponse.ts:12 필드명 불일치
  - 재현: curl POST /payment → 200이지만 amount undefined
  - 수정: 2개 파일, ~8줄
  - 리스크: LOW

2위: 환경 (신뢰도 31%)
3위: 레이스 (신뢰도 15%)

기각: 데이터 드리프트 (DB 실제 값 확인 결과 정상)
기각: 상류 의존성 (recent lock diff 없음)

→ 1위 가설 기반 수정을 진행할까요?
  - "승인" → executor 디스패치 (--fix-ok 없으면 여전히 승인 후 대기)
  - "거부" → verdict 재검토 or 추가 조사 요청
  - "2위도 병행" → 복합 원인 가정하고 두 가설 동시 수정
  - "재조사 H_N" → 해당 가설 에이전트 재실행
```

**수근 승인 없이 Phase 4 진입 금지.**

## Phase 4 (optional, --fix-ok): Fix Dispatch

승인된 진단을 바탕으로 executor 디스패치. `/review` Phase 3과 동일한 패턴.

```
Agent(executor, model=sonnet):
  "진단 결과 1위 가설: {가설}
   수정 범위: {파일 목록}
   핵심 증거: {파일:라인 인용}
   최소 diff만 적용. 수정 후 재현 단계로 검증."
```

수정 후 자동으로 `/deploy-verified`(배포 필요 시) 또는 `verifier` 서브에이전트로 검증 연결.

## Important Rules

1. **5개 에이전트 병렬** — 순차 실행 금지 (순차는 편향 유발)
2. **에이전트는 자기 가설만** — 타 가설 영역 침범 금지
3. **심판 전에 편집 금지** — Phase 3 승인 전 어떤 코드도 수정하지 않음
4. **증거 없는 순위 금지** — 심판은 각 순위에 파일:라인 증거 제시
5. **INCONCLUSIVE 존중** — 심판이 결정 못 하면 "추가 정보 요청"으로 종료, 억지 결론 금지
6. **복합 원인 허용** — 1위가 70% 미만이고 2위도 40%+면 복합 가설 제시

## 중단 조건

- Phase 0에서 증상 재현 불가 (3회 시도) → 수근에게 재현 환경 요청
- Phase 1에서 5개 에이전트 모두 신뢰도 < 30% → "가설 공간 확장 필요" 보고, 수근에게 추가 가설 요청
- Phase 2 심판이 INCONCLUSIVE 2회 연속 → Opus architect 에스컬레이션

## Example

```
사용자: /triage 결제 요청이 200 반환하지만 amount 필드가 프론트에서 undefined로 찍힘

Phase 0: 증상 캡처
  - 재현: POST /payment, curl은 {"amount": 1000} 반환, React 앱은 undefined
  - 최근 커밋: a3b4c5 (3일 전 PaymentDto 리팩터)

Phase 1: 5개 에이전트 병렬 (4분 소요)
  - H1 타입: 82% — PaymentDto.java:45 'amountKrw' vs TypeScript 'amount' 불일치
  - H2 레이스: 15% — 재현이 100% 일관됨, 비동기 레이스 불가
  - H3 데이터: 22% — DB 값 정상, 스키마 일치
  - H4 환경: 31% — 빌드 타임스탬프 정상, 배포 최신
  - H5 상류: 5% — 의존성 변경 없음

Phase 2: 심판
  verdict: 1위 H1 타입 미스매치 (82%)
  기각: H2/H5, H3/H4는 보조 증거만

Phase 3: 수근 승인
  → "승인"

Phase 4 (--fix-ok): executor가 PaymentResponse.ts의 필드명 수정
  → verifier가 재현 단계 실행 → PASS
```
