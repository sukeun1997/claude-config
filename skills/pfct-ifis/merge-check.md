---
name: merge-check
description: "현재 브랜치를 베이스 브랜치(develop)에 머지해도 안전한지 영향도 분석을 수행해줘."
triggers:
  - "merge check"
  - "머지 체크"
  - "merge safety"
  - "can I merge"
---

# Merge Check Skill

현재 브랜치를 develop에 머지할 때의 안전성을 이벤트 소싱 관점에서 분석합니다.

## 실행 단계

### 1. Git 상태 확인

```bash
# 현재 브랜치와 develop 비교
git fetch origin develop
git diff origin/develop...HEAD --stat

# Conflict 여부 체크
git merge-base origin/develop HEAD
git merge --no-commit --no-ff origin/develop && git merge --abort || echo "Merge conflicts detected"
```

### 2. Critical Checks (이벤트 소싱 특화)

#### A. Event Schema Breaking Change 체크

```bash
# 기존 이벤트 파일 수정 여부 확인
git diff origin/develop...HEAD --name-status | grep "^M.*domain/.*event.*\.kt$"
```

**분석 항목**:
- [ ] 기존 Event 클래스의 필드 삭제/타입 변경 (🚨 CRITICAL)
- [ ] Event 클래스명 변경 (🚨 CRITICAL)
- [ ] 새로운 필수 필드 추가 (⚠️ WARNING)
- [ ] Optional 필드 추가만 (✅ SAFE)

**판단 기준**:
```kotlin
// 🚨 BREAKING - 필드 삭제
data class LoanCreated(
    val loanId: Long,
    // val amount: BigDecimal  <- 삭제됨
)

// 🚨 BREAKING - 타입 변경
data class LoanCreated(
    val loanId: Long,
    val amount: String  // BigDecimal -> String 변경
)

// ⚠️ WARNING - 필수 필드 추가
data class LoanCreated(
    val loanId: Long,
    val amount: BigDecimal,
    val newField: String  // 기존 이벤트가 이 필드 없음
)

// ✅ SAFE - Optional 필드 추가
data class LoanCreated(
    val loanId: Long,
    val amount: BigDecimal,
    val newField: String? = null  // nullable with default
)
```

#### B. Aggregate Rehydration Logic 체크

```bash
# Rehydrator 변경 확인
git diff origin/develop...HEAD domain/rehydrator/
```

**분석 항목**:
- [ ] 기존 이벤트 처리 로직 변경 (⚠️ WARNING)
- [ ] 새로운 이벤트 타입 처리 추가 (✅ SAFE)

#### C. Projection Compatibility 체크

```bash
# Projection 변경 확인
git diff origin/develop...HEAD adapter/projection/
```

**분석 항목**:
- [ ] Projection 스키마 변경 → 재구축 필요? (⚠️ WARNING)
- [ ] Checkpoint 로직 변경 (⚠️ WARNING)

#### D. Kafka Topic/Consumer 변경

```bash
# Kafka 설정 변경 확인
git diff origin/develop...HEAD | grep -E "kafka|topic|consumer"
```

**분석 항목**:
- [ ] 토픽명 변경 (🚨 CRITICAL)
- [ ] Consumer group ID 변경 (⚠️ WARNING)
- [ ] 새 토픽 추가 (✅ SAFE - 배포 전 생성 필요)

### 3. Test Coverage 확인

```bash
# 변경된 코드에 대한 테스트 실행
./gradlew test

# 변경된 모듈만 테스트 (성능 최적화)
CHANGED_MODULES=$(git diff origin/develop...HEAD --name-only | grep "^[^/]*/" | sort -u | sed 's#/.*##' | uniq)
for module in $CHANGED_MODULES; do
    if [ -d "$module/src/test" ]; then
        ./gradlew :$module:test
    fi
done
```

### 4. Code Quality 확인

```bash
# Ktlint 체크
./gradlew ktlintCheck

# Build 성공 여부
./gradlew build --parallel
```

### 5. 머지 안전성 리포트 생성

```markdown
# 🔍 Merge Safety Report

## ✅ Safe to Merge: [YES/NO/WITH_CAUTION]

## 📊 Summary
- **Branch**: feature/core-XXX
- **Base**: develop
- **Changed Files**: X files
- **Commits**: X commits
- **Test Status**: ✅ Passing

## 🚨 Critical Issues (Blockers)
- [ ] Event schema breaking changes detected
- [ ] Rehydration logic breaking changes
- [ ] Kafka topic name changes

## ⚠️ Warnings (Action Required)
- [ ] Projection rebuild needed after deploy
- [ ] New Kafka topic creation required
- [ ] Database migration script needed

## ✅ Safe Changes
- [ ] New event types added (backward compatible)
- [ ] New use cases added
- [ ] Test coverage added

## 📋 Pre-Merge Checklist
- [ ] All tests passing
- [ ] No merge conflicts
- [ ] Ktlint checks passed
- [ ] PR approved by reviewer
- [ ] Event schema compatibility verified
- [ ] Deployment notes documented

## 🚀 Post-Merge Actions
1. [ ] Deploy to staging first
2. [ ] Verify event consumers are processing
3. [ ] Check projection sync status
4. [ ] Monitor error logs for 1 hour

## 📝 Recommendation
[MERGE NOW / MERGE WITH CAUTION / DO NOT MERGE]

**Reason**: [설명]
```

## 판단 로직

### ❌ DO NOT MERGE if:
- Event schema breaking changes detected
- Tests failing
- Merge conflicts present
- Rehydration logic breaks existing events

### ⚠️ MERGE WITH CAUTION if:
- Projection rebuild required
- New Kafka topics needed
- Database migration needed
- Performance impact suspected

### ✅ SAFE TO MERGE if:
- Only new events/use cases added
- All tests passing
- No schema changes
- Backward compatible

## Token 최적화

- 변경된 파일의 diff만 분석 (전체 파일 읽기 X)
- Event 클래스는 data class 선언부만 비교
- 테스트는 변경된 모듈만 실행
- Parallel 실행으로 분석 시간 단축

## 사용 예시

**User**: "merge check"

**Action**:
1. Git diff 분석
2. Event schema breaking change 검사
3. 테스트 실행 (변경 모듈만)
4. 안전성 리포트 생성
5. 머지 권장사항 제시
