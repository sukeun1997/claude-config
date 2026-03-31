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

## 4. 결과 통합 출력

모든 에이전트 결과를 수집한 뒤, 아래 형식으로 통합 보고한다.

```
## Code Review Summary

### Strengths
- [잘한 부분 1] (file:line)
- [잘한 부분 2] (file:line)

### Issues

| # | Severity | Category | File:Line | Issue | Fix |
|---|----------|----------|-----------|-------|-----|
| 1 | CRITICAL | Behavioral Risk | ... | ... | ... |
| 2 | HIGH | SOLID/SRP | ... | ... | ... |

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
