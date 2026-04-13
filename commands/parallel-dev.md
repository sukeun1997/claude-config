# 워크트리 브랜치 생성 및 이동

`$ARGUMENTS`로 브랜치명을 받아 워크트리를 생성한다.

## 워크트리 경로

**고정 경로**: `/Users/sukeunpark/IdeaProjects/banking-loan-worktrees/<브랜치명의 슬래시를 하이픈으로 변환>/`

> `EnterWorktree` 도구는 사용하지 않는다 (경로 커스텀 불가).

## 실행 흐름

### 1. Base 브랜치 최신화

```bash
git fetch origin develop
git merge --ff-only origin/develop  # 현재 develop에 있을 때
# 또는 다른 브랜치에 있을 때:
# git fetch origin develop (fetch만)
```

### 2. 워크트리 디렉토리 준비

```bash
mkdir -p /Users/sukeunpark/IdeaProjects/banking-loan-worktrees
```

### 3. 워크트리 생성

```bash
git worktree add /Users/sukeunpark/IdeaProjects/banking-loan-worktrees/<slug> -b <브랜치명>
```

- `<slug>`: 브랜치명의 `/`를 `-`로 변환한 값 (예: `feature/foo` → `feature-foo`)
- `-b <브랜치명>`: 원래 브랜치명 그대로 사용

### 4. 완료 보고

```
✅ 워크트리 생성 완료
- 브랜치: <브랜치명>
- 경로: /Users/sukeunpark/IdeaProjects/banking-loan-worktrees/<slug>
- 이동: `cd /Users/sukeunpark/IdeaProjects/banking-loan-worktrees/<slug>` 후 새 세션 시작
```

## 서브커맨드

### `/parallel-dev list`
```bash
git worktree list
```

### `/parallel-dev remove <이름>`
1. 미커밋 변경사항 확인 (있으면 경고)
2. `git worktree remove /Users/sukeunpark/IdeaProjects/banking-loan-worktrees/<slug>` 실행
3. 로컬 브랜치 삭제 여부 확인

### `/parallel-dev cleanup`
`/Users/sukeunpark/IdeaProjects/banking-loan-worktrees/` 하위 모든 워크트리 삭제 (미커밋 있으면 사용자 확인 필수).

$ARGUMENTS
