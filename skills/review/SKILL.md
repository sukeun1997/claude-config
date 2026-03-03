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
| code-reviewer | Sonnet | ✅ | ✅ | ✅ |
| security-reviewer | Sonnet | ✅ | ✅ | ❌ |
| quality-reviewer | Sonnet | ✅ | ❌ | ❌ |
| architect | Opus | ✅ | ❌ | ❌ |
| critic (Phase 1.5) | Opus | ✅ | ✅ | ❌ |

## Pipeline

```
Phase 0: Implementation Interview (구현 인터뷰)
  → analyst (Opus): diff 분석 → 핵심 결정 포인트 추출 → 사용자 승인/수정
  ↓
Phase 1: Review (병렬 리뷰)
  ├─ code-reviewer (Sonnet)     — 버그, 안티패턴, 코드 품질
  ├─ security-reviewer (Sonnet) — OWASP Top 10, 인젝션, 비밀값
  ├─ quality-reviewer (Sonnet)  — OOP, SOLID, 구조, 중복
  └─ architect (Opus)           — 레이어 위반, 의존성 방향, 확장성
  ↓
Phase 1.5: Critic (적대적 반론)
  → critic (Opus) — 리뷰 결과의 누락/모순/false negative 탐지
  ↓
Phase 2: Evaluate (평가 + 사용자 확인)
  → false positive 제거 + 그룹핑 + 수정 계획 → 사용자 승인
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

## Phase 1: Review — 병렬 리뷰

### 기본 모드 (4개 병렬)

```
Task(code-reviewer, model=sonnet):
  "프로젝트 {path} 코드 리뷰. 심각도별 분류 (CRITICAL/HIGH/MEDIUM/LOW).
   각 항목: 파일:라인, 설명, 수정 제안.
   이 코드/설계가 암묵적으로 가정하는 것을 식별하고,
   각 가정이 깨지는 상황과 결과를 명시하세요."

Task(security-reviewer, model=sonnet):
  "프로젝트 {path} 보안 리뷰. OWASP Top 10 기준.
   각 항목: 파일:라인, 취약점 유형, 심각도, 수정 제안."

Task(quality-reviewer, model=sonnet):
  "프로젝트 {path} 품질 리뷰. SOLID 원칙, 안티패턴, 코드 중복, 로직 결함.
   각 항목: 파일:라인, 카테고리, 심각도, 수정 제안."

Task(architect, model=opus):
  "프로젝트 {path} 아키텍처 리뷰. 레이어 위반, 순환 의존성, 패키지 구조, 확장성.
   각 항목: 파일:라인, 카테고리, 심각도, 수정 제안, 트레이드오프."
```

### --security 모드 (2개 병렬)
code-reviewer + security-reviewer만 실행. quality-reviewer, architect 생략.

### --quick 모드 (1개)
code-reviewer만 실행. Phase 1.5도 생략.

모든 에이전트는 **반드시 병렬** 실행. 3-Tier 기준에 따라 모델 지정.

## Phase 1.5: Critic — 적대적 반론

`--quick` 모드에서는 생략.

```
Task(critic, model=opus):
  "아래는 Phase 1에서 리뷰어들이 작성한 리뷰 결과입니다.
   리뷰 대상 코드와 함께 검토하여 다음 3가지를 수행하세요:

   1. **누락 탐지**: 리뷰어 전원이 놓친 이슈가 있는가?
      특히 동시성, 멱등성, 에러 전파, 리소스 누수에 주목.

   2. **false negative**: 리뷰어가 '정상'으로 판단했지만 실제로 문제인 곳은?
      코드를 직접 읽고 리뷰어의 판단이 맞는지 재검증.

   3. **모순 감지**: 리뷰어 간 상충되는 판단이 있는가?
      예: code-reviewer는 OK, security-reviewer는 위험 → 어느 쪽이 맞는지 판정.

   출력 형식:
   ⚠️ 놓친 것 같은 이슈 N건:
     1. [파일:라인] — [설명] — 리뷰어가 미검토한 이유 추정

   ✅ 리뷰어 간 모순: N건 / 없음
     1. [reviewer A: 판단] vs [reviewer B: 판단] — critic 판단: [결론]

   --- 리뷰 결과 ---
   {Phase 1 code-reviewer 결과}
   {Phase 1 security-reviewer 결과}
   {Phase 1 quality-reviewer 결과}
   {Phase 1 architect 결과}"
```

## Phase 2: Evaluate — 비판적 평가

Phase 1 + Phase 1.5 결과를 통합하여 사용자에게 제시.

### 평가 기준 (receiving-code-review 원칙 내장)
1. **기술 검증**: 해당 코드를 직접 읽고 실제 이슈인지 확인
2. **YAGNI 체크**: 사용 안 되는 코드의 "개선" 제안 제외
3. **false positive 제거**: 프레임워크가 이미 처리하는 경우, 내부 전용 API 등
4. **충돌 체크**: 수정 항목 간 충돌 여부 확인
5. **그룹핑**: 파일/도메인 기준으로 executor 배분 계획

### 사용자 확인 (필수)

```
[Phase 0 결과] 결정 포인트 N건 — 전체 승인됨 ✅

[Phase 1 리뷰 결과]
  code-reviewer:     CRITICAL N, HIGH N, MEDIUM N
  security-reviewer: CRITICAL N, HIGH N, MEDIUM N
  quality-reviewer:  CRITICAL N, HIGH N, MEDIUM N
  architect:         CRITICAL N, HIGH N, MEDIUM N

[Phase 1.5 critic 반론]
  ⚠️ 추가 이슈 N건
  ✅ 리뷰어 간 모순: N건 / 없음

[평가 후] false positive N건 제거

수정 계획:
| # | 심각도 | 카테고리 | 파일 | 내용 | executor |
|---|--------|----------|------|------|----------|

진행할까요?
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

## Phase 4: Verify — 증거 기반 검증

### 4-1. 빌드 검증
```bash
# 프로젝트별 빌드 명령 실행
./gradlew build       # Kotlin/Java
tsc --noEmit          # TypeScript
pnpm build            # Frontend
```
**exit 0이 아니면 Phase 3으로 돌아가 수정.**

### 4-2. 테스트 검증
```bash
./gradlew test        # Kotlin/Java
pnpm test             # Node.js
```

### 4-3. 새 실패 vs 기존 실패 구분
```
IF 테스트 실패 있음:
  1. git stash (우리 변경 임시 제거)
  2. 동일 테스트 실행
  3. git stash pop
  4. 비교: 새 실패 = 우리 변경 때문, 기존 실패 = 무관

  새 실패 > 0 → Phase 3 재실행
  기존 실패만 → 진행 가능 (기존 실패 목록 기록)
```

### 4-4. Iron Law
```
❌ "should pass", "looks correct", "빌드 성공한 것 같습니다"
✅ "gradlew test exit 0, 테스트 30/30 pass" (실제 출력 인용)
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
6. **critic 반론은 Phase 1 결과와 동등 취급** — critic이 발견한 이슈도 수정 대상

## Example

```
사용자: /review src/

Phase 0: diff 분석 → 결정 포인트 4건 추출
  1. TodoService에 IN_PROGRESS 상태 추가 → 상태 전이 확장
  2. shiftSortOrder 벌크 쿼리 도입 → 개별 UPDATE 대체
  3. smartFilter가 isSmart=false일 때 null 강제
  4. @Modifying(clearAutomatically=true) 추가
  → 사용자: "전체 승인"

Phase 1: 4개 리뷰어 병렬 실행
  code-reviewer:     HIGH 2, MEDIUM 4
  security-reviewer: CRITICAL 1, HIGH 1
  quality-reviewer:  MEDIUM 3
  architect:         HIGH 1

Phase 1.5: critic 반론
  ⚠️ 놓친 이슈 1건: 동시 reorder 호출 시 sortOrder 충돌
  ✅ 모순 없음

Phase 2: false positive 2건 제거 → 수정 계획 제시
  → 사용자: "진행"

Phase 3: executor 3개 병렬 수정
Phase 4: ./gradlew test 30/30 pass
Phase 5: git commit
```
