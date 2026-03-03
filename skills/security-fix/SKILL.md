---
name: security-fix
description: "End-to-end security review → fix → verify → commit pipeline. Runs code-reviewer + security-reviewer in parallel, filters CRITICAL/HIGH, dispatches executor agents for fixes, verifies with fresh build/test, then commits. Use when user says '/security-fix', '보안 리뷰 후 수정', 'security review and fix'."
---

> ⚠️ **DEPRECATED**: 이 스킬은 `/review --security`로 대체되었습니다.
> `/review --security`를 사용하세요. 이 스킬은 2026-03-08 이후 삭제 예정입니다.

# Security Fix Pipeline — 리뷰 → 평가 → 수정 → 검증 → 커밋

보안/코드 리뷰부터 수정, 검증, 커밋까지 한 번의 스킬 호출로 실행하는 자동화 파이프라인.

## When to Apply

- 프로젝트 보안 점검이 필요할 때
- 코드 리뷰 후 일괄 수정이 필요할 때
- `/security-fix` 또는 `/security-fix server/` (특정 디렉토리)

## Arguments

- `<path>` (optional): 리뷰 대상 디렉토리. 미지정 시 프로젝트 전체.
- `--dry-run`: Phase 1-2만 실행 (리뷰+평가까지, 수정 안 함)
- `--skip-deploy`: 커밋까지만, 배포 생략

## Pipeline

```
Phase 1: Review (병렬)
  ├─ code-reviewer (Sonnet) — 코드 품질, 버그, 안티패턴
  └─ security-reviewer (Sonnet) — OWASP Top 10, 인젝션, 인증, 비밀값

Phase 2: Evaluate (receiving-code-review 원칙)
  → CRITICAL/HIGH 필터링
  → 각 항목 기술적 검증 (실제 코드베이스에서 재현 가능한지)
  → false positive 제거
  → 수정 계획 수립 + 사용자 확인

Phase 3: Fix (병렬 executor)
  → 관련 항목 그룹핑 (파일/도메인 기준)
  → executor (Sonnet) N개 병렬 디스패치
  → 각 executor는 최소 diff만 적용

Phase 4: Verify (verification-before-completion 원칙)
  → tsc (또는 프로젝트 빌드 명령) — exit 0 필수
  → 테스트 실행 — 새 실패 0건 필수
  → 기존 실패와 새 실패 구분 (stash 비교)
  → 증거 없이 "통과" 주장 금지

Phase 5: Commit + Deploy (선택)
  → 커밋 메시지: "fix: 보안 리뷰 CRITICAL/HIGH N건 수정"
  → scripts/deploy.sh 사용 (수동 rsync 금지)
  → Notion 업데이트 (프로젝트 페이지에 결과 기록)
```

## Phase 1: Review — 병렬 리뷰 디스패치

```
Task(code-reviewer, model=sonnet):
  "프로젝트 {path} 코드 리뷰. 심각도별 분류 (CRITICAL/HIGH/MEDIUM/LOW).
   각 항목: 파일:라인, 설명, 수정 제안."

Task(security-reviewer, model=sonnet):
  "프로젝트 {path} 보안 리뷰. OWASP Top 10 기준.
   각 항목: 파일:라인, 취약점 유형, 심각도, 수정 제안."
```

두 에이전트는 **반드시 병렬** 실행. 3-Tier 기준 Sonnet 사용.

## Phase 2: Evaluate — 비판적 평가 (receiving-code-review)

리뷰 결과를 **맹목적으로 수용하지 않는다**. 각 항목에 대해:

1. **기술 검증**: 해당 코드를 직접 읽고 실제 취약점인지 확인
2. **YAGNI 체크**: 사용되지 않는 코드의 "개선" 제안은 제외
3. **false positive 제거**: 프레임워크가 이미 처리하는 경우, 내부 전용 API 등
4. **충돌 체크**: 수정 항목 간 충돌 여부 확인
5. **그룹핑**: 파일/도메인 기준으로 executor 배분 계획

### 사용자 확인 (필수)

```
"CRITICAL N건, HIGH N건 발견. 수정 계획:"
| # | 심각도 | 파일 | 내용 | executor 배분 |
|---|--------|------|------|--------------|
| 1 | CRITICAL | server/x.ts:42 | SQL injection | executor 1 |
| ... |

"진행할까요?"
```

**사용자 승인 없이 Phase 3 진입 금지.**

## Phase 3: Fix — 병렬 executor 디스패치

```
# 그룹별 executor 디스패치 (Sonnet)
Task(executor, model=sonnet):
  "다음 보안 이슈를 수정하세요:
   1. {파일}:{라인} — {설명} → {수정 방향}
   2. ...
   최소 diff만 적용. 관련 없는 코드 수정 금지."
```

### executor 규칙
- **최소 diff**: 보안 수정만, 리팩토링/개선 금지
- **파일 범위**: 할당된 파일만 수정
- **충돌 방지**: executor 간 같은 파일 수정 금지 (Phase 2에서 배분)

## Phase 4: Verify — 증거 기반 검증 (verification-before-completion)

### 4-1. 빌드 검증
```bash
# 프로젝트별 빌드 명령 실행
tsc --noEmit          # TypeScript
./gradlew build       # Kotlin/Java
pnpm build            # Frontend
```
**exit 0이 아니면 Phase 3으로 돌아가 수정.**

### 4-2. 테스트 검증
```bash
# 전체 테스트 실행
pnpm test             # Node.js
./gradlew test        # Kotlin/Java
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
✅ "tsc exit 0, 테스트 34/34 pass" (실제 출력 인용)
```

## Phase 5: Commit + Deploy

### 커밋
```bash
git add <수정된 파일들만>
git commit -m "fix: 보안 리뷰 CRITICAL/HIGH N건 수정

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
- 프로젝트 페이지 하위에 "보안 리뷰 YYYY-MM-DD" 페이지 생성
- 발견 항목, 수정 내역, 검증 결과 기록

## 중단 조건

다음 상황에서 **즉시 중단하고 사용자에게 보고**:
- CRITICAL이 5건 이상 (구조적 문제 가능성)
- 수정이 10개 이상 파일에 영향 (범위 초과)
- 빌드가 3회 연속 실패 (근본적 문제)
- executor 간 파일 충돌 발생

## 프로젝트별 빌드 명령 매핑

| 프로젝트 | 빌드 | 테스트 | 배포 |
|---------|------|--------|------|
| building-manager | `pnpm build:web` | `pnpm test` | `scripts/deploy.sh` |
| todo-app (backend) | `./gradlew build` | `./gradlew test` | - |
| todo-app (iOS) | `xcodebuild` | `xcodebuild test` | - |

## Example

```
사용자: /security-fix server/

Phase 1: code-reviewer(Sonnet) + security-reviewer(Sonnet) 병렬 실행
  → CRITICAL 2, HIGH 4, MEDIUM 8 발견

Phase 2: 각 항목 코드 확인 → false positive 1건 제거
  → "CRITICAL 2 + HIGH 3 수정 계획입니다. 진행할까요?"
  → 사용자: "ㅇㅇ"

Phase 3: executor 3개 병렬 디스패치
  → executor 1: rate limit + input validation (2파일)
  → executor 2: auth + injection fix (2파일)
  → executor 3: type safety + config (3파일)

Phase 4: tsc exit 0, 테스트 27/34 pass (7건 기존 실패 확인)
  → "빌드 통과. 테스트 7건 실패는 기존 mock 이슈 (stash 비교 확인)."

Phase 5: git commit + deploy.sh + Notion 업데이트
```

## Important Rules

1. **Phase 2 사용자 확인 필수** — 자동으로 코드 수정 진행 금지
2. **최소 diff 원칙** — 보안 수정만, 리팩토링/개선은 범위 밖
3. **증거 기반 검증** — 실제 명령 출력 없이 "통과" 주장 금지
4. **false positive 필터링** — 리뷰어를 맹신하지 않음
5. **deploy.sh 강제** — 수동 배포 명령 금지
