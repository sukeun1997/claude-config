---
name: freeze
description: Manage frozen (protected) files/directories that must not be modified without explicit permission
user_invocable: true
---

# Freeze Skill

특정 파일/디렉토리를 "변경 금지(frozen)" 상태로 지정하거나 해제합니다.

## Usage

```
/freeze                          # 현재 frozen 목록 표시
/freeze add <path> [reason]      # 경로를 frozen에 추가
/freeze remove <path>            # frozen에서 제거
/freeze check                    # 현재 변경 사항 중 frozen 파일 위반 검사
```

## Steps

### 1. Freeze 파일 관리

Frozen 목록은 `.claude/frozen.yml`에 저장:

```yaml
# .claude/frozen.yml
# 명시적 요청 없이 수정 금지된 파일/패턴 목록
frozen:
  - path: "build.gradle.kts"
    reason: "빌드 설정 보호 - 데몬 재시작, 환경변수 등 비침투적 해결 우선"
  - path: "**/build.gradle.kts"
    reason: "모듈 빌드 설정 보호"
  - path: "settings.gradle.kts"
    reason: "프로젝트 구조 보호"
```

### 2. 명령별 동작

#### `/freeze` (목록 표시)
- `.claude/frozen.yml` 읽기
- 테이블로 표시:
  ```
  | # | Path | Reason | Since |
  |---|------|--------|-------|
  | 1 | build.gradle.kts | 빌드 설정 보호 | 2026-03-23 |
  ```

#### `/freeze add <path> [reason]`
- `.claude/frozen.yml`에 항목 추가
- glob 패턴 지원 (`**/*.avsc`, `ops/**/*` 등)
- 추가 후 목록 표시

#### `/freeze remove <path>`
- `.claude/frozen.yml`에서 항목 제거
- 제거 전 사용자 확인

#### `/freeze check`
- `git diff --name-only` 로 변경된 파일 목록 확인
- frozen 패턴과 매칭하여 위반 파일 표시
- 위반 있으면 경고 + 변경 사유 확인 요청

### 3. 자동 보호 동작 (CRITICAL)

코드를 수정하기 전, 대상 파일이 frozen 목록에 해당하는지 **반드시 확인**:

- **frozen 파일 수정 요청 시**: 사용자에게 해당 파일이 frozen임을 알리고, 수정 사유와 승인을 받은 후에만 진행
- **frozen 파일의 우회 해결**: frozen 파일 수정 없이 문제를 해결할 수 있는 대안을 먼저 제시

### 4. 초기 설정

`/freeze` 최초 실행 시 `.claude/frozen.yml`이 없으면 CLAUDE.md의 기존 보호 규칙에서 자동 생성:
- `build.gradle.kts` (Approach Constraints에서)
- 사용자에게 추가할 파일/패턴 질문
