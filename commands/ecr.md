# Kotlin/Spring Boot 올인원 코드 리뷰

Kotlin + Spring Boot 프로젝트에 특화된 종합 코드 리뷰 오케스트레이터.
기존 에이전트(`code-reviewer`, `security-reviewer`, `api-reviewer`, `verifier`)를 활용하여 병렬 리뷰를 수행한다.

## 1. 입력 모드 감지

`$ARGUMENTS`를 분석하여 모드를 결정한다:

- **PR 모드**: GitHub PR URL이 포함된 경우 (`github.com/.../pull/NNN`)
  → `gh pr diff <URL>`로 diff 수집. 빌드/테스트 검증은 생략.
  → `gh pr view <URL>`로 PR 설명도 함께 읽어 컨텍스트 파악.
- **파일 모드**: 파일 경로가 포함된 경우
  → 해당 파일의 git diff 또는 전체 내용 읽기.
- **로컬 모드** (인수 없음):
  → `git diff --staged` + `git diff`로 변경 내역 수집.
  → diff 없으면 `git log --oneline -5` + `git diff HEAD~1`로 최근 커밋 확인.

## 2. 규모별 에이전트 배정

변경 규모를 파악한 후 에이전트를 배정한다. **모든 에이전트는 model: sonnet으로 오버라이드** (비용 절감).

### 소규모 (≤2파일, <100줄 변경)
→ `code-reviewer` **1개만** 실행. 아래 보완 체크리스트를 프롬프트에 추가 주입.

### 중규모 (3-5파일 or 100-300줄)
→ **병렬 2개**: `code-reviewer` + `security-reviewer`

### 대규모 (6+파일 or 300줄+)
→ **병렬 3개**: `code-reviewer` + `security-reviewer` + `api-reviewer`
→ 로컬 모드면 `verifier`도 추가 (빌드/테스트 증거 수집)

## 3. 에이전트별 추가 주입 지시

각 에이전트 호출 시, 에이전트 기본 프롬프트에 더해 아래 내용을 **추가 지시로 주입**한다.

### code-reviewer 추가 지시

```
추가 리뷰 항목 (기존 체크리스트에 더해 반드시 확인):

[Behavioral Risk — 잠재적 동작 위험성]
- 기존 API 계약 변경: 응답 필드 삭제/타입 변경, 필수 파라미터 추가 (하위 호환성 파괴)
- 트랜잭션 경계 변경: @Transactional 추가/제거/전파 변경으로 인한 데이터 정합성 위험
- 이벤트 발행 순서/조건 변경: Kafka 메시지 구조, 발행 시점이 Consumer에 미치는 영향
- 동시성 문제: 공유 상태 변경, 락 누락, race condition
- null 안전성 파괴: nullable → non-null, !! 사용, 플랫폼 타입 방치
- 예외 처리 변경: catch 범위 변경으로 상위 호출부 영향
- DB 마이그레이션 위험: 컬럼 삭제, NOT NULL 추가의 무중단 배포 호환성
- Enum/sealed class when 절 분기 누락

[YAGNI]
- 미사용 코드/기능 추가를 감지하면 지적: "이 코드를 호출하는 곳이 있는가?"
- grep으로 실제 사용처 확인 후 판단

[Production Readiness]
- Flyway 마이그레이션이 필요한 변경인데 마이그레이션 파일이 없는 경우
- 설정/프로퍼티 변경이 필요한데 누락된 경우
- 로깅이 충분한가 (에러 경로에 log 없음)
- Sentry에 전달해야 할 예외가 누락되었는가

[Strengths]
- 반드시 잘한 부분을 2-3개 구체적으로 언급 (file:line 포함)

[근거 필수 — Evidence-Based Findings]
모든 CRITICAL/HIGH/MEDIUM 이슈에 대해 아래 구조를 따라 보고:
- **문제**: 무엇이 잘못되었거나 위험한가 (1줄)
- **근거**: 왜 문제인가. 다음 중 하나 이상 포함:
  - 코드 증거: 실제 코드 라인 인용 (file:line + 해당 코드 스니펫)
  - 호출 흐름: 이 코드가 호출되는 경로와 영향 범위 (caller → callee 체인)
  - 데이터 흐름: 잘못된 값이 어디서 시작되어 어디까지 전파되는가
  - 외부 영향: API 소비자, 다른 서비스, DB에 미치는 구체적 영향
- **수정 방향**: 구체적 코드 수정 예시 포함. 아래 형태로 작성:
  ```kotlin
  // Before (현재 코드)
  fun processPayment(amount: Long) { ... }
  
  // After (권장 수정)
  fun processPayment(amount: Long) {
      require(amount > 0) { "amount must be positive: $amount" }
      ...
  }
  ```
  - 수정 예시가 불가능한 설계 이슈는 대안 접근법을 설명
  - 여러 수정 방안이 있으면 trade-off와 함께 1순위 추천

SUGGEST 이슈는 근거를 간략히 1줄로 작성해도 된다.
"80% 확신" 미만이면 보고하지 않는다 — 근거가 약한 이슈를 올리지 말 것.
```

### verifier 추가 지시 (로컬 모드만)

```
Kotlin/Spring Boot 프로젝트 검증:
1. 변경된 모듈 감지: git diff --name-only에서 모듈 경로 추출
2. 빌드: ./gradlew :<모듈>:compileKotlin -x ktlintCheck -x ktlintMainSourceSetCheck -x ktlintTestSourceSetCheck -x ktlintFormat --no-daemon
3. 관련 테스트 실행: 변경된 클래스명으로 테스트 탐색 후 실행
   ./gradlew :<모듈>:test --tests "*변경클래스명*" -x ktlintCheck -x ktlintMainSourceSetCheck -x ktlintTestSourceSetCheck -x ktlintFormat --no-daemon
4. 결과를 증거와 함께 보고 (exit code, 테스트 수, 실패 수)
```

## 3.5 Opus 검증 단계 (Critical/High 이슈 교차 검증)

리뷰 에이전트들의 결과 수집 후, **CRITICAL 또는 HIGH 이슈가 1건 이상** 있으면:

1. `critic` (model: opus) 서브에이전트를 실행하여 해당 이슈들을 교차 검증한다
2. critic에게 전달하는 프롬프트:

```
아래는 코드 리뷰에서 발견된 CRITICAL/HIGH 이슈 목록이다.
각 이슈에 대해 아래를 판정하라:

1. **CONFIRMED** — 근거가 타당하고 실제 문제가 맞음
2. **DOWNGRADE** — 이슈이긴 하나 심각도가 과대평가됨 (적정 심각도 제시)
3. **DISMISSED** — false positive이거나 근거가 불충분함 (이유 명시)

판정 시 반드시:
- 리뷰어가 인용한 코드를 직접 읽어 확인 (Read 도구 사용)
- 호출 흐름과 실제 영향 범위를 직접 추적
- 리뷰어 주장의 전제가 사실인지 검증

판정 결과만 간결하게 보고. 형식:
| # | 원래 Severity | 판정 | 이유 (1줄) |
```

3. critic 판정 결과를 최종 보고에 반영:
   - **CONFIRMED**: 그대로 유지
   - **DOWNGRADE**: 심각도 조정 후 최종 보고에 `(↓ critic 조정)` 표시
   - **DISMISSED**: 최종 보고에서 제거하고, "Dismissed by Critic" 섹션에 별도 기록

> CRITICAL/HIGH가 없으면 이 단계를 건너뛴다 (비용 절감).

## 4. 결과 통합 출력

모든 에이전트 결과 + critic 검증을 수집한 뒤, 아래 형식으로 통합 보고한다.

```
## Code Review Summary

### Strengths
- [잘한 부분 1] (file:line)
- [잘한 부분 2] (file:line)

### Issues

각 이슈는 아래 형식으로 상세 기술한다 (테이블 요약 + 상세 블록):

**요약 테이블**
| # | Severity | Category | File:Line | Issue |
|---|----------|----------|-----------|-------|
| 1 | CRITICAL (↓ critic 조정) | Behavioral Risk | ... | 1줄 요약 |
| 2 | HIGH | SOLID/SRP | ... | 1줄 요약 |

**상세 (CRITICAL/HIGH/MEDIUM 각각)**

#### Issue #1 — [1줄 제목]
- **Severity**: CRITICAL → HIGH (↓ critic 조정) _또는_ CRITICAL (confirmed)
- **문제**: 무엇이 잘못되었거나 위험한가
- **근거**: 왜 문제인가
  - 코드 증거: `file:line` — 해당 코드 인용
  - 호출/데이터 흐름: caller → callee 체인 또는 값 전파 경로
  - 외부 영향: API 소비자, DB, 다른 서비스에 미치는 구체적 영향
- **수정 방향**:
  ```kotlin
  // Before
  기존 코드
  
  // After (권장)
  수정 코드
  ```
  - trade-off가 있으면 대안과 함께 설명
- **코멘트 초안**: (PR 모드 시) 아래 §4.5 가이드에 따른 PR 코멘트 초안

### Dismissed by Critic
critic이 DISMISSED 판정한 이슈를 여기에 기록한다 (투명성).
| # | 원래 Severity | 판정 | 이유 |
|---|--------------|------|------|

### Architecture Direction (설계 개선 제안)
- [제안 1]: 현재 → 개선안 + 이유
- [제안 2]: ...

### Build & Test Verification (로컬 모드만)
- Build: PASS/FAIL (exit code, 모듈명)
- Tests: X passed, Y failed (테스트 클래스명)

### LOC Delta
- `git diff --stat`으로 변경 줄 수를 표시
- 형식: `+{추가} / -{삭제} = net {순증감}`
- 순증감이 양수이면: "코드가 늘었습니다. `/simplify`로 줄일 수 있는지 확인을 권장합니다."
- 순증감이 음수이면: "코드가 줄었습니다. 좋은 신호입니다."

### PR Comment Guide (PR 모드 전용)

각 이슈에 대해 PR에 남길 코멘트 초안을 제공한다. 사용자가 복사-붙여넣기 또는 수정하여 바로 사용할 수 있도록 작성.

**코멘트 톤/형식 가이드 (severity별)**

| Severity | 접두어 | 톤 | 예시 |
|----------|--------|-----|------|
| CRITICAL | `🔴 [CRITICAL]` | 단호하되 건설적. 머지 차단 사유 명시 | "이 부분은 머지 전 수정이 필요합니다. ~한 이유로 프로덕션에서 ~한 문제가 발생할 수 있습니다." |
| HIGH | `🟠 [HIGH]` | 명확한 문제 지적 + 대안 제시 | "~하면 ~한 위험이 있습니다. 대안으로 ~를 고려해주세요." |
| MEDIUM | `💡 [suggestion]` | 제안 형태. 선택권을 줌 | "~하면 ~한 이점이 있을 것 같습니다. 어떻게 생각하시나요?" |
| SUGGEST | `💭 [nit]` | 가벼운 제안. 무시 가능 표시 | "nit: ~하면 가독성이 좋아질 것 같습니다. (무시해도 됩니다)" |

**코멘트 구조** (CRITICAL/HIGH):
```
🔴 [CRITICAL] {1줄 요약}

**문제**: {무엇이 잘못되었는가}
**영향**: {발생 시 어떤 결과가 오는가 — 사용자/시스템/데이터 관점}

**수정 제안**:
\```kotlin
// 권장 수정 코드
\```

> 참고: {관련 문서/컨벤션/이전 사례 링크가 있으면}
```

**코멘트 작성 원칙**:
- 질문이 아니라 관찰 + 제안으로 작성 ("이거 맞나요?"보다 "~한 문제가 있고, ~하면 해결됩니다")
- 작성자의 의도를 존중: "이 부분의 의도가 ~라면" 형태로 가정을 명시
- 여러 곳에 같은 패턴이면 한 곳에만 상세 코멘트 + 나머지는 "위와 동일 패턴입니다" 참조

### Recurring Pattern Detection
- 이번 리뷰에서 **동일 패턴의 이슈가 3곳 이상** 발견된 경우 이 섹션을 출력
- 형식:
  ```
  | 반복 패턴 | 발생 횟수 | 제안 액션 |
  |-----------|-----------|-----------|
  | [패턴 설명] | N곳 | CLAUDE.md에 규칙 추가 / governance.yml에 감시 추가 |
  ```
- 제안 액션 기준:
  - 코딩 컨벤션 위반 반복 → CLAUDE.md 또는 모듈 CLAUDE.md에 규칙 추가 제안
  - 특정 파일 유형 변경 시 반복 실수 → governance.yml에 패턴 추가 제안
  - 테스트 패턴 반복 누락 → 테스트 컨벤션에 추가 제안
- "이 패턴을 규칙으로 등록할까요?" 질문으로 마무리

### Verdict
| Severity | Count | Status |
|----------|-------|--------|
| CRITICAL | 0 | PASS |
| HIGH | 0 | PASS |
| MEDIUM | 0 | INFO |
| SUGGEST | 0 | NOTE |

**APPROVE / WARNING / BLOCK**
- APPROVE: CRITICAL/HIGH 이슈 없음
- WARNING: HIGH 이슈만 존재
- BLOCK: CRITICAL 이슈 존재
```

## 5. 리뷰 원칙

- 80% 이상 확신하는 이슈만 보고 (noise 방지)
- 동일 패턴 반복 → 통합 보고 ("5곳에서 동일 패턴")
- 변경되지 않은 코드는 CRITICAL 보안 이슈 외 리뷰하지 않음
- 이슈 지적 + **"이렇게 하면 더 좋다"** 대안 반드시 포함
- 단순 스타일/포맷 이슈는 리뷰하지 않음 (ktlint 영역)

$ARGUMENTS
