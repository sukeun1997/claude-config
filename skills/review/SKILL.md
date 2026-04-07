---
name: review
description: "올인원 종합 리뷰 파이프라인. 구현 인터뷰 → 병렬 리뷰(code/security/quality/architect) → critic 반론 → 평가 → 수정 → 검증 → 커밋. Use when user says '/review', '리뷰', 'code review', '코드 리뷰'."
---

# /review — 올인원 종합 리뷰 파이프라인

구현 인터뷰부터 리뷰, 반론, 수정, 검증, 커밋까지 하나의 스킬로 실행하는 자동화 파이프라인.

## When to Apply

- 기능 구현 완료 후 종합 리뷰가 필요할 때
- `/review` 또는 `/review src/` (특정 디렉토리)
- `/review --security` (보안 특화, 기존 /security-fix 대체)
- `/review --quick` (간단한 변경, code-reviewer만)

## Arguments

- `<path>` (optional): 리뷰 대상 디렉토리. 미지정 시 프로젝트 전체.
- `--security`: 보안 특화 모드 (code + security + critic만)
- `--quick`: 빠른 모드 (code-reviewer만, Phase 0/1.5 생략)
- `--skip-interview`: Phase 0 구현 인터뷰 생략
- `--dry-run`: Phase 0~2만 실행 (리뷰+평가까지, 수정 안 함)
- `--skip-deploy`: 커밋까지만, 배포 생략
## 프로필별 에이전트 구성

| 에이전트 | 모델 | `/review` | `--security` | `--quick` |
|---|---|---|---|---|
| analyst (Phase 0) | Opus | ✅ | ✅ | ❌ |
| **review-aggregator** (Phase 1) | Opus (deep-executor) | ✅ | ✅ | ❌ |
| └ code-reviewer | Sonnet | (내부) | (내부) | ❌ |
| └ security-reviewer | Sonnet | (내부) | (내부) | ❌ |
| └ quality-reviewer | Sonnet | (내부) | ❌ | ❌ |
| └ architect | Opus | (내부) | ❌ | ❌ |
| code-reviewer (--quick only) | Opus | ❌ | ❌ | ✅ |

**Aggregator 패턴**: `/review`, `--security` 모드에서는 메인 세션이 리뷰어를 직접 호출하지 않음. review-aggregator가 내부에서 리뷰어를 병렬 실행하고, critic 분석(중복 제거 + 누락 탐지 + 모순 감지)을 수행한 뒤, **압축된 요약만** 메인 컨텍스트에 반환. 메인 컨텍스트 소비를 1/4~1/5로 절감.

`--quick` 모드는 code-reviewer 1개만 직접 호출 (aggregator 오버헤드 불필요).

**모델 라우팅 참고**: `/review` 스킬 내 에이전트 모델 배정은 이 테이블이 authority. CLAUDE.md §3은 일반 에이전트 라우팅이며, `/review` 파이프라인에서는 이 테이블이 우선한다. Aggregator 내부 리뷰어는 비용 최적화를 위해 sonnet 유지 (opus aggregator가 종합/비판). `--quick` 모드는 aggregator 없이 직접 호출하므로 §3 기준(opus) 적용.

## Pipeline

```
Phase 0: Implementation Interview (구현 인터뷰)
  → analyst (Opus): diff 분석 → 핵심 결정 포인트 추출 → 사용자 승인/수정
  ↓
Phase 1: Aggregated Review (리뷰 + 반론 통합)
  → review-aggregator (Opus, deep-executor)
    내부 병렬: code / security / quality / architect
    → 중복 제거 + critic 분석 → 압축 요약만 메인에 반환
  ↓
Phase 2: Evaluate (평가 + AUTO-FIX/ASK 분리 + 사용자 확인)
  → AUTO-FIX: 기본 수락 (거부만 명시) / ASK: 개별 승인
  ↓
Phase 3: Fix (병렬 수정)
  → executor (Sonnet) × N — 최소 diff만 적용
  ↓
Phase 4: Verify (증거 기반 검증)
  → 빌드(exit 0) + 테스트(새 실패 0건) + stash 비교
  ↓
Phase 5: Commit
  → git commit + 선택적 deploy
```

## Phase 0: Implementation Interview — 구현 인터뷰

### 목적
수근이 모든 코드를 읽을 수 없으니, AI가 구현 중 내린 핵심 결정들을 정리해서 제시.
수근은 번호별로 승인/수정만 하면 됨.

### 스킵 조건
- `--skip-interview` 플래그 사용 시
- `--quick` 모드 시
- diff가 3파일 이하 + 50줄 이하일 때 자동 스킵 (사소한 변경)

### 동작

```
Task(analyst, model=opus):
  "아래 diff를 분석하여 핵심 설계 결정 포인트를 추출하세요.

  대상: git diff {base}...HEAD (또는 지정된 path의 변경사항)

  설계 결정이 포함된 변경을 식별:
  - 새 클래스/인터페이스 생성
  - 기존 구조 변경 (메서드 시그니처, 상속 관계, 패키지 이동)
  - 외부 의존성 추가/변경
  - 에러 처리 전략 선택
  - 데이터 모델 변경 (Entity, DTO, 스키마)
  - 비즈니스 로직 핵심 분기

  각 결정을 아래 형식으로 정리:

  ### N. [결정 제목]
  **구현**: (무엇을 어떻게 구현했는지)
  **근거**: (왜 이 방식을 선택했는지)
  **대안**: A방식 vs B방식
  **판단 필요**: 현재 구현 승인 or 변경?"
```

### 사용자 응답 처리
- 사용자가 번호별 응답: "1. 승인 2. B방식으로 3. 승인"
- "전체 승인" → 모든 결정 승인으로 처리
- 수정 요청 시 → 즉시 executor 디스패치로 반영 후 해당 부분만 재확인
- **사용자 승인 없이 Phase 1 진입 금지**

## Phase 1: Aggregated Review — 리뷰 + 반론 통합

### 기본 모드 (`/review`, `--security`)

메인 세션은 review-aggregator 1개만 호출. 내부에서 리뷰어 병렬 실행 + critic 분석을 수행하고 압축 결과만 반환.

```
Agent(deep-executor, model=opus, name="review-aggregator"):
  "프로젝트 {path}에 대한 종합 코드 리뷰를 수행하세요.

   ## Step 1: 리뷰어 병렬 실행

   아래 4개 리뷰 에이전트를 **동시에** 실행하세요{security_mode_note}:

   Agent(code-reviewer, model=sonnet):
     '프로젝트 {path} 코드 리뷰. 심각도별 분류 (CRITICAL/HIGH/MEDIUM/LOW).
      각 항목: 파일:라인 | 심각도 | 카테고리 | 설명 | fixability(AUTO-FIX/ASK) | 수정 코드/선택지 | 증거
      fixability: AUTO-FIX=정답 하나+동작 불변, ASK=설계 선택/트레이드오프 필요
      암묵적 가정을 식별하고, 깨지는 상황과 결과 명시.
      증거 없는 looks fine 금지.'

   Agent(security-reviewer, model=sonnet):
     '프로젝트 {path} 보안 리뷰. OWASP Top 10 기준.
      각 항목: 파일:라인 | 심각도 | 취약점 유형 | 설명 | fixability(AUTO-FIX/ASK) | 수정 코드/선택지 | 증거
      fixability: AUTO-FIX=보안 best practice 명확, ASK=보안-사용성 트레이드오프
      증거 없는 looks fine 금지.'

   Agent(quality-reviewer, model=sonnet):  {quality_note}
     '프로젝트 {path} 품질 리뷰. SOLID, 안티패턴, 코드 중복, 로직 결함.
      각 항목: 파일:라인 | 심각도 | 카테고리 | 설명 | fixability(AUTO-FIX/ASK) | 수정 코드/선택지 | 증거
      fixability: AUTO-FIX=네이밍/미사용 import/명백한 중복, ASK=구조 변경/패턴 도입
      증거 없는 looks fine 금지.'

   Agent(architect, model=opus):  {architect_note}
     '프로젝트 {path} 아키텍처 리뷰. 레이어 위반, 순환 의존성, 패키지 구조, 확장성.
      각 항목: 파일:라인 | 심각도 | 카테고리 | 설명 | fixability(AUTO-FIX/ASK) | 수정 코드/선택지+트레이드오프 | 증거
      fixability: AUTO-FIX=명백한 구조 오류, ASK=아키텍처 트레이드오프
      증거 없는 looks fine 금지.'

   ## Step 2: Critic 분석 (리뷰어 결과 수집 후)

   모든 리뷰어 결과를 수집한 뒤, 직접 critic 역할을 수행하세요:
   1. **중복 제거**: 같은 파일 ±5줄의 동일 이슈 → 가장 정확한 리뷰어 것만 유지
   2. **누락 탐지**: 리뷰어 전원이 놓친 이슈? 특히 동시성, 멱등성, 에러 전파, 리소스 누수
   3. **모순 감지**: 리뷰어 간 상충 판단 → 어느 쪽이 맞는지 판정
   4. **false negative**: 리뷰어가 '정상' 판단했지만 실제 문제인 곳

   ## Step 3: 압축 출력 (반드시 이 형식으로만 반환)

   아래 형식으로만 결과를 반환하세요. 리뷰어 원본 결과는 포함하지 마세요:

   [리뷰 요약]
   총 N건 (CRITICAL N, HIGH N, MEDIUM N, LOW N)
   리뷰어별: code N건, security N건, quality N건, architect N건
   중복 제거: N건, critic 추가: N건

   [AUTO-FIX] N건
   | # | 심각도 | 파일:라인 | 내용 | 수정 코드 | 출처 |

   [ASK] N건
   | # | 심각도 | 파일:라인 | 내용 | 선택지 | 출처 |

   [Critic 추가 이슈] N건 / 없음
   | # | 파일:라인 | 내용 | fixability |

   [리뷰어 간 모순] N건 / 없음
   | reviewer A 판단 | reviewer B 판단 | critic 결론 |

   CRITICAL/HIGH 항목은 수정 코드/선택지를 상세히.
   MEDIUM/LOW 항목은 한 줄 요약으로 축약."
```

**모드별 리뷰어 구성**:
- `/review`: 4개 전부 (code + security + quality + architect)
- `--security`: code + security만 (`{quality_note}`, `{architect_note}` 자리에 해당 Agent 블록 제거)
- `{security_mode_note}`: `--security` 시 "code-reviewer와 security-reviewer 2개만 실행하세요"로 대체

### --quick 모드 (aggregator 미사용)

code-reviewer 1개만 메인 세션에서 직접 호출. aggregator 오버헤드 불필요.

```
Agent(code-reviewer, model=opus):
  "프로젝트 {path} 코드 리뷰. 심각도별 분류 (CRITICAL/HIGH/MEDIUM/LOW).
   각 항목: 파일:라인 | 심각도 | 카테고리 | 설명 | fixability(AUTO-FIX/ASK) | 수정 코드/선택지 | 증거
   CRITICAL/HIGH만 상세, MEDIUM/LOW는 한 줄 요약.
   최대 10건, 심각도 순 우선."
```

## Phase 2: Evaluate — Opus 독립 평가

review-aggregator 반환 결과를 **별도 Opus critic 서브에이전트**에 위임하여 평가. 메인 세션이 직접 평가하면 이미 컨텍스트를 아는 상태에서 동의 편향이 발생하므로, 독립 에이전트가 원본 코드와 리뷰 결과만으로 판단한다.

### 평가 에이전트 (Agent, model: opus, subagent_type: critic)
프롬프트에 포함:
- review-aggregator 전체 결과
- 변경된 파일 경로 목록

평가 기준:
1. **기술 검증**: 해당 코드를 직접 읽고 실제 이슈인지 확인
2. **YAGNI 체크**: 사용 안 되는 코드의 "개선" 제안 제외
3. **false positive 제거**: 프레임워크가 이미 처리하는 경우, 내부 전용 API 등
4. **충돌 체크**: 수정 항목 간 충돌 여부 확인
5. **그룹핑**: 파일/도메인 기준으로 executor 배분 계획
6. **fixability 검증**: aggregator의 AUTO-FIX/ASK 분류를 재확인. 의심스러운 AUTO-FIX는 ASK로 격상

### 사용자 확인 (필수)

```
[Phase 0 결과] 결정 포인트 N건 — 전체 승인됨 ✅

[Phase 1 리뷰 결과] (aggregator 요약)
  총 N건 (CRITICAL N, HIGH N, MEDIUM N, LOW N)
  리뷰어별: code N건, security N건, quality N건, architect N건
  critic 추가: N건, 리뷰어 간 모순: N건

[평가 후] false positive N건 제거

[AUTO-FIX] 기계적 수정 N건 — 자동 적용 예정
| # | 심각도 | 파일:라인 | 내용 |
|---|--------|----------|------|

[ASK] 판단 필요 N건 — 번호별 승인/거부/수정 요청
| # | 심각도 | 파일:라인 | 내용 | 선택지 |
|---|--------|----------|------|--------|

AUTO-FIX 항목을 확인 후 진행할까요?
(개별 항목 거부 가능: "AF3 빼줘", "전체 진행")
```

### 사용자 응답 처리

```
인식 패턴:
  "전체 진행"          → AUTO-FIX 전체 수락 + ASK 전체 승인
  "AF3 빼줘"           → AUTO-FIX #3만 제외, 나머지 수락
  "AF 3, 5 제외"       → AUTO-FIX #3, #5 제외
  "ASK1 A"             → ASK #1에서 선택지 A 선택
  "ASK2 스킵"          → ASK #2 수정하지 않음
  "ASK 전체 스킵"      → ASK 항목 전부 수정하지 않음

거부된 AUTO-FIX → 삭제 (ASK로 이동하지 않음, 수정 안 함)
스킵된 ASK → 삭제 (이번 리뷰에서 수정 안 함)
```

**사용자 승인 없이 Phase 3 진입 금지.**
`--dry-run` 모드에서는 여기서 종료.

## Phase 3: Fix — 병렬 executor 디스패치

```
# 그룹별 executor 디스패치 (Sonnet)
Task(executor, model=sonnet):
  "다음 이슈를 수정하세요:
   1. {파일}:{라인} — {설명} → {수정 방향}
   2. ...
   최소 diff만 적용. 관련 없는 코드 수정 금지."
```

### executor 규칙
- **최소 diff**: 리뷰 이슈 수정만, 리팩토링/개선 금지
- **파일 범위**: 할당된 파일만 수정
- **충돌 방지**: executor 간 같은 파일 수정 금지 (Phase 2에서 배분)

## Phase 4: Verify — Opus verifier 서브에이전트에 위임

메인 세션이 직접 빌드/테스트를 실행하지 않는다. 별도 Opus verifier에 위임하여 객관적으로 검증.

```
Agent(verifier, model=opus):
  "Phase 3에서 리뷰 이슈 수정이 완료되었습니다.
   변경 파일: {수정된 파일 목록}
   수정 내용: {AUTO-FIX N건, ASK N건 반영}

   아래 항목을 증거 기반으로 검증하세요:

   1. 빌드 검증: 프로젝트 빌드 명령 실행 (exit 0 필수)
   2. 테스트 검증: 전체 테스트 실행
   3. 새 실패 vs 기존 실패 구분:
      - git stash → 동일 테스트 → git stash pop → 비교
      - 새 실패 > 0 → FAIL
   4. diff 검증: executor 보고와 실제 변경 일치 여부

   FAIL 시 구체적 실패 원인과 파일:라인을 보고하세요.

   응답 형식:
   - **결과**: SUCCESS | PARTIAL | FAILED
   - **변경 파일**: [파일 경로 목록]
   - **핵심 내용**: 1-3줄 요약
   - **미해결 사항**: 완료하지 못한 부분 (없으면 '없음')"
```

### 결과 처리
- **SUCCESS** → Phase 5 진행
- **FAILED** → Phase 3으로 돌아가 수정 (최대 1회 재시도)
- **PARTIAL** → 미해결 사항을 사용자에게 보고 후 판단

### Iron Law
```
❌ "should pass", "looks correct", "빌드 성공한 것 같습니다"
✅ "gradlew test exit 0, 테스트 30/30 pass" (verifier 실제 출력 인용)
```

## Phase 5: Commit + Deploy

### 커밋
```bash
git add <수정된 파일들만>
git commit -m "fix: 코드 리뷰 CRITICAL/HIGH N건 수정

- C1: {요약}
- H1: {요약}
...

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

### 배포 (--skip-deploy가 아닌 경우)
```bash
# deploy.sh 사용 필수. 수동 rsync 금지.
bash scripts/deploy.sh
```

### Notion 업데이트 (프로젝트 Notion 페이지가 있는 경우)
- 버그 트래커에 리뷰 발견 항목 기록

## 중단 조건

다음 상황에서 **즉시 중단하고 사용자에게 보고**:
- CRITICAL이 5건 이상 (구조적 문제 가능성)
- diff가 500줄 이상 (디렉토리/모듈 단위로 분할하여 순차 리뷰로 전환)
- 수정이 10개 이상 파일에 영향 (범위 초과)
- 빌드가 3회 연속 실패 (근본적 문제)
- executor 간 파일 충돌 발생
- Phase 0에서 사용자가 설계 방향 전면 변경 요청

## 프로젝트별 빌드 명령 매핑

| 프로젝트 | 빌드 | 테스트 | 배포 |
|---------|------|--------|------|
| todo-app (backend) | `./gradlew build` | `./gradlew test` | `scripts/deploy.sh` |
| todo-app (iOS) | `xcodebuild` | `xcodebuild test` | - |
| building-manager | `pnpm build:web` | `pnpm test` | `scripts/deploy.sh` |

## Important Rules

1. **Phase 0 + Phase 2 사용자 확인 필수** — 자동으로 코드 수정 진행 금지
2. **최소 diff 원칙** — 리뷰 이슈 수정만, 리팩토링/개선은 범위 밖
3. **증거 기반 검증** — 실제 명령 출력 없이 "통과" 주장 금지
4. **false positive 필터링** — 리뷰어를 맹신하지 않음
5. **deploy.sh 강제** — 수동 배포 명령 금지
6. **critic 분석은 aggregator 내부에서 수행** — critic 추가 이슈도 AUTO-FIX/ASK로 분류되어 반환
7. **증거 기반 리뷰** — 리뷰어의 모든 판단에 라인 번호 + 근거 필수. 증거 없는 "looks fine" 금지

## Example

```
사용자: /review src/

Phase 0: diff 분석 → 결정 포인트 4건 추출
  1. TodoService에 IN_PROGRESS 상태 추가 → 상태 전이 확장
  2. shiftSortOrder 벌크 쿼리 도입 → 개별 UPDATE 대체
  3. smartFilter가 isSmart=false일 때 null 강제
  4. @Modifying(clearAutomatically=true) 추가
  → 사용자: "전체 승인"

Phase 1: review-aggregator (4개 리뷰어 + critic 통합)
  → 총 12건 (CRITICAL 1, HIGH 3, MEDIUM 7, LOW 1)
  → 중복 제거 1건, critic 추가 1건 (동시 reorder sortOrder 충돌)
  → AUTO-FIX 7건, ASK 4건 (압축 요약으로 반환)

Phase 2: false positive 2건 제거
  [AUTO-FIX] 7건 — 자동 적용 예정
  [ASK] 4건 — 사용자 확인 필요
  → 사용자: "AF 전체 수락. ASK1 A, ASK2 스킵, ASK3 B, ASK4 A"

Phase 3: executor 3개 병렬 수정
Phase 4: ./gradlew test 30/30 pass
Phase 5: git commit
```
