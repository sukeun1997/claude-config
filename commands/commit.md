프로젝트 컨벤션에 맞는 안전한 커밋 워크플로우를 실행합니다.

## Steps

1. **현재 브랜치 확인**
   - `git branch --show-current` 실행
   - 사용자에게 브랜치 확인

2. **변경 사항 확인**
   - `git status` 로 변경 파일 목록 확인
   - `git diff --stat` 으로 변경 규모 파악
   - 변경 내용 요약을 사용자에게 제시

3. **ktlint 포맷팅**
   - `./gradlew ktlintFormat -x ktlintCheck` 실행
   - 포맷팅 변경이 있으면 사용자에게 알림

4. **빌드 검증**
   - `./gradlew build -x ktlintCheck -x ktlintMainSourceSetCheck -x ktlintTestSourceSetCheck -PskipFetchAvro` 실행
   - 빌드 실패 시 원인 분석 후 사용자에게 보고 (자동 수정하지 않음)

5. **커밋 메시지 작성**
   - 변경 내용 분석하여 conventional commit 형식 메시지 제안
   - 형식: `<type>: <description>` (feat/fix/refactor/docs/test/chore/perf/ci)
   - 사용자 승인 또는 수정 후 커밋

6. **커밋 실행**
   - 관련 파일만 `git add` (git add -A 사용 금지)
   - `.env`, credentials, secrets 파일 포함 여부 확인
   - 커밋 실행

7. **푸시 여부 확인**
   - 사용자에게 push 여부 질문
   - 승인 시 `git push -u origin <branch>` 실행
