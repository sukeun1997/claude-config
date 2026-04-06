---
name: sync-pr
description: "sukeun1997 계정으로 브랜치 생성 → 푸시 → PR 생성 후 sukeun8로 복귀. Use when user says '/sync-pr', 'PR 만들어줘', 'push하고 PR', '브랜치 PR'"
---

# Sync PR — GitHub 계정 전환 브랜치 PR 워크플로우

현재 main의 최신 커밋(들)을 별도 브랜치로 push하고 PR을 생성한 뒤, 원래 계정으로 복귀한다.

## 파라미터

- `$ARGUMENTS`: 브랜치 이름 (선택). 없으면 최신 커밋 메시지에서 자동 생성
  - 예: `/sync-pr fix/memory-leak` → `fix/memory-leak` 브랜치 사용

## 실행 흐름

### Step 1: 사전 확인

```bash
# 현재 브랜치가 main인지 확인
git branch --show-current  # main이 아니면 사용자에게 확인

# push할 커밋 확인 (origin/main 대비)
git log origin/main..HEAD --oneline

# 현재 활성 GitHub 계정 확인
gh auth status
```

- push할 커밋이 없으면 → "push할 커밋이 없습니다" 출력 후 종료
- 현재 계정이 이미 `sukeun1997`이면 전환 생략

### Step 2: 계정 전환

```bash
gh auth switch --user sukeun1997
```

### Step 3: 브랜치 생성 + Push

브랜치 이름 결정:
- `$ARGUMENTS`가 있으면 그대로 사용
- 없으면 최신 커밋 메시지에서 생성: `<type>/<핵심-키워드>` 형태
  - 예: `absorb: Context Mode ...` → `absorb/context-mode`
  - 예: `fix: 메모리 누수 해결` → `fix/memory-leak`

```bash
git checkout -b <branch-name> main
git push -u origin <branch-name>
```

### Step 4: PR 생성

```bash
gh pr create --title "<커밋 타입: 요약>" --body "$(cat <<'EOF'
## Summary
<커밋 메시지 기반 1-3줄 요약>

## Changes
<변경 파일 목록>

EOF
)" --base main
```

- PR 제목: 최신 커밋 메시지의 첫 줄 사용 (70자 이하로 truncate)
- PR body: `git log origin/main..HEAD`의 전체 커밋 히스토리 분석

### Step 5: 복귀

```bash
git checkout main
gh auth switch --user sukeun8
```

### Step 6: 결과 보고

```
PR 생성 완료: <PR URL>
브랜치: <branch-name>
계정: sukeun8 (복귀 완료)
```

## 주의사항

- `gh auth switch` 실패 시 → 수동 전환 안내 (`! gh auth switch --user sukeun1997`)
- push 실패 시 → 계정 복귀 먼저 실행 후 에러 보고
- main에 uncommitted changes가 있어도 브랜치 생성은 가능 (staged 상태 유지)
- 브랜치가 이미 존재하면 → suffix 추가 (`-2`, `-3`)
