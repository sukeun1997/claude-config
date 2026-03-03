---
name: update-pr
description: "현재 브랜치의 PR을 템플릿 형식으로 작성하거나 업데이트해줘. 이벤트 소싱 프로젝트 특화 PR 템플릿 적용."
triggers:
  - "update pr"
  - "pr 업데이트"
  - "pr 작성"
  - "pull request 업데이트"
---

# Update PR Skill

현재 브랜치의 Pull Request를 pfct-ifis 프로젝트 템플릿에 맞춰 작성/업데이트합니다.

## 실행 단계

### 1. 현재 브랜치 확인 및 변경사항 분석

```bash
# 현재 브랜치와 베이스 브랜치(develop) 비교
git diff develop...HEAD --stat

# 커밋 히스토리 확인
git log develop..HEAD --oneline

# 변경된 파일 목록
git diff develop...HEAD --name-only
```

### 2. 이벤트 소싱 변경사항 분석

**체크리스트**:
- [ ] 새로운 도메인 이벤트 추가? (domain/event/)
- [ ] 이벤트 핸들러 변경? (adapter/)
- [ ] Aggregate 로직 변경? (domain/model/)
- [ ] Use Case 추가/변경? (application/usecase/)
- [ ] Projection 변경? (adapter/projection/)
- [ ] Rehydration 로직 변경? (domain/rehydrator/)
- [ ] Kafka 토픽 설정 변경?
- [ ] 스냅샷 전략 변경?

### 3. PR 템플릿 생성

```markdown
## 📝 Summary
[1-2문장으로 이 PR의 핵심 목적 설명]

## 🎯 Changes

### Domain Events
- [ ] `EventName`: [이벤트 설명 및 목적]

### Aggregates
- [ ] `AggregateName`: [변경 내용]

### Use Cases
- [ ] `UseCaseName`: [기능 설명]

### Infrastructure
- [ ] Kafka: [토픽/컨슈머 변경사항]
- [ ] Projection: [프로젝션 업데이트]
- [ ] Snapshot: [스냅샷 전략 변경]

## 🧪 Testing

### Event Handler Tests
```bash
./gradlew :adapter:test --tests "*EventHandlerTest"
```

### Use Case Tests
```bash
./gradlew :application:test --tests "*UseCaseTest"
```

### Integration Tests
```bash
./gradlew :bootstrap:test
```

## 🔍 Event Schema Compatibility

- [ ] 기존 이벤트 구조 변경 없음 (Breaking Change 없음)
- [ ] 새 이벤트 타입만 추가 (하위 호환)
- [ ] ⚠️ Breaking Change 있음: [마이그레이션 계획 명시]

## 📊 Performance Impact

- [ ] 이벤트 쿼리 성능 영향 없음
- [ ] 스냅샷 생성 주기 적절
- [ ] Projection 재계산 필요 여부: [Yes/No]

## 🚀 Deployment Notes

### Before Deploy
- [ ] 데이터 마이그레이션 스크립트 실행 필요?
- [ ] Kafka 토픽 생성 필요?
- [ ] 환경변수 추가 필요?

### After Deploy
- [ ] Projection 재구축 필요?
- [ ] 스냅샷 재생성 필요?

## 📚 Related Issues

Closes #[issue-number]
Related to #[issue-number]

---

🤖 Generated with [pfct-ifis update-pr skill](https://claude.com/claude-code)
```

### 4. PR 생성/업데이트 실행

```bash
# 기존 PR이 있으면 업데이트, 없으면 생성
gh pr view || gh pr create --title "[제목]" --body "[위 템플릿]"
```

## 자동화 포인트

1. **이벤트 변경 감지**: `domain/event/` 디렉토리 변경사항 자동 감지
2. **테스트 실행**: PR 생성 전 자동으로 관련 테스트 실행
3. **Breaking Change 경고**: 기존 이벤트 파일 수정 시 경고
4. **Commit Convention 체크**: feat|fix|refactor 형식 확인

## 사용 예시

**User**: "update pr"

**Action**:
1. 현재 브랜치의 변경사항 분석
2. 이벤트 소싱 관련 변경사항 식별
3. 템플릿에 맞춰 PR body 생성
4. gh CLI로 PR 생성/업데이트

## Token 최적화

- 변경된 파일만 읽기 (전체 프로젝트 탐색 X)
- 이벤트 파일은 클래스 선언부만 읽기 (전체 읽지 않음)
- 커밋 메시지로 변경 의도 파악 (파일 내용 최소화)
