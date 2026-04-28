현재 브랜치의 PR을 아래 템플릿 형식으로 작성하거나 업데이트해줘.
PR 번호가 주어지면 해당 PR을, 아니면 현재 브랜치의 PR을 찾아서 업데이트해.

## 작업 순서

1. 베이스 브랜치 판별: `develop` 브랜치가 있으면 develop, 없으면 `main` 사용
2. `gh pr view`로 현재 PR 정보 확인
3. `gh pr diff --name-only`로 변경 파일 목록 확인
4. `git log {base}..HEAD --oneline`으로 커밋 히스토리 확인
5. 변경 내용을 분석하여 아래 템플릿에 맞게 PR 제목과 본문 작성
6. **본문 파일 작성 후 `gh pr edit --body-file`로 PR 업데이트** — Write 도구로 `/tmp/pr_body_<num>.md`에 본문 작성 → `gh pr edit <num> --body-file /tmp/pr_body_<num>.md`. `--body "$(cat <<EOF ... EOF)"` 형태는 금지 (백틱 escape 문제로 코드블록/인라인 코드 깨짐). 신규 PR 생성 시 `gh pr create --body-file` 동일 적용.
7. 업데이트 직후 `gh pr view <num> --json body --jq .body | head`로 백틱/코드블록 정상 렌더 검증

## PR 템플릿

```
## 요약

- [변경 사항을 1-3줄로 요약]

### 주요 변경사항

**[모듈명]** ([변경 카테고리]):
- [구체적인 변경 내용]

### 테스트

| 모듈 | 테스트 클래스 | 검증 항목 |
|------|-------------|----------|
| `모듈명` | `테스트클래스명` | 검증 내용 |

## 필요 작업

- [x] 완료된 작업
- [ ] 미완료 작업

## 참고 링크

JIRA [TICKET-ID](URL) (있는 경우)
```

## 규칙

- PR 제목은 conventional commit 형식: `feat:`, `fix:`, `refactor:`, `test:`, `chore:` 등
- PR 제목은 70자 이내로 간결하게
- 주요 변경사항은 모듈별로 그룹핑
- 테스트 테이블은 테스트가 있는 경우만 포함
- 참고 링크는 JIRA 티켓이 있는 경우만 포함

$ARGUMENTS
