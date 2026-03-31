# Codex Bridge — AI 간 자동 위임

Codex CLI에 작업을 위임합니다. plan 작성 → tmux 주입 → 완료 감지 → 리뷰까지 자동.
프로젝트 무관 범용 도구.

## 플래그 파싱

`$ARGUMENTS`에서 플래그를 먼저 확인:
- `--status` → 상태 확인 모드로 전환
- `--cancel` → 취소 모드로 전환
- `--dry` → plan만 생성, 주입 안 함
- 그 외 → 위임 모드 (기본)

## 상태 확인 모드 (--status)

`~/.claude/scripts/handoff.sh status` 실행 후 결과를 사용자에게 보고.

## 취소 모드 (--cancel)

`~/.claude/scripts/handoff.sh cancel` 실행 후 결과를 사용자에게 보고.

## 위임 모드 (기본)

### 1단계: 자동 초기화
- `.handoff/config.json` 존재 여부 확인
- 없으면 `~/.claude/scripts/handoff.sh init` 자동 실행
- init 실패 시 사용자에게 tmux pane ID 요청

### 2단계: Plan 작성
작업 요청을 분석하여 `.handoff/queue/task-{id}.md`를 생성합니다.

task ID는 3자리 순번 (001, 002, ...). 기존 queue 파일에서 마지막 번호 +1.

task 파일 포맷:

```
---
id: "{id}"
created: "{ISO8601 timestamp}"
status: "pending"
scope: ["대상 파일 경로 목록"]
---

## 목표
{사용자의 작업 설명에서 도출한 구현 목표}

## 구현 지침
{구체적인 구현 단계. 코드 레벨 지침 포함.}
{현재 프로젝트의 CLAUDE.md가 있으면 관련 규칙을 여기에 반영.}

## 완료 조건
{충족해야 할 조건 목록}

## 완료 시 해야 할 것
작업이 끝나면 반드시 아래 명령을 실행하세요:
cat > .handoff/result/result-{id}.json << 'HANDOFF_EOF'
{
  "id": "{id}",
  "status": "done",
  "files_changed": ["변경한 파일 경로를 여기에 나열"],
  "summary": "무엇을 했는지 한 줄 요약",
  "errors": null
}
HANDOFF_EOF
```

### 3단계: --dry 체크
`--dry`가 있으면 plan만 생성하고 중단.
"Plan 생성 완료: .handoff/queue/task-{id}.md"

### 4단계: Codex에 주입
```bash
~/.claude/scripts/handoff.sh inject {id}
```

### 5단계: 완료 대기
```bash
~/.claude/scripts/handoff.sh poll {id}
```
이 명령을 백그라운드로 실행하고, 완료 시 결과를 분석합니다.

### 6단계: 리뷰
poll 결과에 따라:

**DONE (시그널 파일 있음)**:
1. result JSON에서 `files_changed` 읽기
2. 각 파일에 대해 `git diff` 확인
3. scope 벗어난 변경 플래그
4. code-reviewer 에이전트로 리뷰 실행
5. 리뷰 통과 → 사용자에게 보고
6. 리뷰 이슈 → `.handoff/review/review-{id}.md` 작성 후 Codex에 재주입
   - 최대 2라운드 → 초과 시 사용자에게 에스컬레이션

**DONE_NO_SIGNAL (tmux fallback)**:
1. `git diff` 로 실제 변경 확인
2. 리뷰 진행 (위와 동일)

**TIMEOUT**:
사용자에게 보고: "Codex가 300초 내에 완료하지 못했습니다. 계속 기다릴까요, 취소할까요?"

### 7단계: 완료 보고
리뷰 통과 시:
- 변경 파일 목록 + diff 요약
- "커밋할까요?" 질문

## 안전장치
- 주입 전 uncommitted 변경이 있으면 `git stash` → 작업 후 `git stash pop`
- lock 존재 시 새 위임 거부
- 보안/DB/아키텍처 변경 감지 시 전체 리뷰 수준 적용

$ARGUMENTS
