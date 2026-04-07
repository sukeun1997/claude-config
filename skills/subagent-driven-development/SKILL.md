---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the current session
---

# Subagent-Driven Development (병렬 최적화 버전)

플랜의 태스크를 독립성 기준으로 분류하여, 독립 태스크는 병렬 서브에이전트로 동시 실행하고 의존 태스크는 순차 실행한다.
각 태스크 완료 후 기존과 동일하게 spec + quality 2단계 리뷰를 수행하고, 전체 완료 후 final code reviewer도 실행한다.

**Core principle:** 독립 태스크 → 병렬 서브에이전트 동시 디스패치 + per-task 2단계 리뷰 유지.

## 프로세스

### Step 1 — 플랜 분석 및 태스크 그룹화

플랜 파일을 한 번 읽고 모든 태스크를 추출한다.
각 태스크에 대해 "이 태스크가 다른 태스크 결과물에 의존하는가?" 를 판단하여:

- **독립 그룹 (parallel)**: 서로 의존성 없는 태스크들 → 동시 디스패치
- **순차 체인 (sequential)**: A 완료 후 B 실행이 필요한 태스크들 → 순서대로

TodoWrite로 모든 태스크를 등록할 때 그룹 정보를 표시한다.

예시:
```
[PARALLEL GROUP 1]  Task 1: NPC 스크립트 작성
[PARALLEL GROUP 1]  Task 2: 포탈 스크립트 작성
[PARALLEL GROUP 1]  Task 3: 드롭 테이블 추가
[SEQUENTIAL]        Task 4: DB 마이그레이션 (Task 3 완료 후)
[SEQUENTIAL]        Task 5: 통합 테스트
```

### Step 2 — 병렬 그룹 실행

독립 태스크들을 **단일 메시지에서 Agent 도구를 여러 번 호출**하여 동시 디스패치한다.

```
[Task 1, 2, 3이 독립적]
→ 단일 응답에서:
   Agent("Task 1 구현...")  ← 동시 시작
   Agent("Task 2 구현...")  ← 동시 시작
   Agent("Task 3 구현...")  ← 동시 시작
```

각 서브에이전트 프롬프트에 포함할 것:
- 태스크 전체 텍스트 (플랜에서 복사)
- 프로젝트 컨텍스트 (언어, 빌드 방법, 주요 경로)
- 워크트리 경로 (있다면)
- "구현 완료 후 커밋까지 진행할 것 (self-review 금지 — 검증은 별도 verifier가 수행)"
- "스펙이 모호하거나 해석이 2가지 이상 가능한 부분은 자의적 해석 없이 질문으로 보고할 것"

모든 병렬 구현이 완료되면, **각 태스크에 대해 순서대로** spec + quality 2단계 리뷰를 진행한다.

```
[병렬 구현 완료 후]
→ Task 1 spec reviewer → quality reviewer → fix if needed
→ Task 2 spec reviewer → quality reviewer → fix if needed
→ Task 3 spec reviewer → quality reviewer → fix if needed
```

### Step 3 — 순차 태스크 실행

병렬 그룹 + 리뷰 완료 후, 의존성 있는 태스크를 순서대로 실행한다.
각 태스크는 개별 서브에이전트로 디스패치 → spec + quality 리뷰 진행.

### Step 4 — Final Code Review + 완료

모든 태스크 + per-task 리뷰 완료 후:
1. Final code reviewer 서브에이전트 디스패치 (전체 구현 대상)
2. 이슈 발견 시 implementer 수정 → re-review
3. 승인 후 `superpowers:finishing-a-development-branch` 사용

## 서브에이전트 프롬프트 예시

```
[프로젝트 컨텍스트]
- 언어: Java 17, MapleStory v273 서버
- 빌드: javac + jar 수동 (Gradle 사용 불가)
- 워크트리: .worktrees/haja-server

[태스크]
{플랜에서 해당 태스크 전체 텍스트}

[지침]
1. 구현 완료 후 git commit까지 진행
2. 파일을 수정하기 전 반드시 먼저 읽을 것
3. 완료 후: 수정한 파일 목록과 커밋 해시 보고
```

## 태스크 독립성 판단 기준

**독립 (병렬 가능):**
- 서로 다른 파일/디렉토리 수정
- 공유 상태 없음 (같은 DB 테이블 동시 ALTER 등은 제외)
- 실행 순서가 결과에 영향 없음

**의존 (순차 필요):**
- Task A가 생성한 클래스를 Task B가 import
- Task A의 DB 스키마를 Task B가 사용
- Task A의 설정값을 Task B가 읽음

## Red Flags

**하지 말 것:**
- 같은 파일을 수정하는 태스크를 병렬로 디스패치 (merge conflict)
- 플랜 파일을 서브에이전트에게 직접 읽게 하기 (컨텍스트 낭비, 직접 텍스트 전달)
- 모든 태스크를 무조건 병렬로 실행 (의존성 무시)
- master/main 브랜치에서 직접 작업 (worktree 사용)

**해야 할 것:**
- 구현 전 태스크 간 의존성 명시적으로 분석하고 공지
- 각 서브에이전트에게 충분한 컨텍스트 제공
- 병렬 완료 후 결과 취합하여 충돌 여부 확인

## Integration

- **superpowers:using-git-worktrees** — 시작 전 워크트리 설정
- **superpowers:writing-plans** — 이 스킬이 실행할 플랜 생성
- **superpowers:requesting-code-review** — spec/quality reviewer 서브에이전트 템플릿
- **superpowers:finishing-a-development-branch** — final review 통과 후 브랜치 완료
