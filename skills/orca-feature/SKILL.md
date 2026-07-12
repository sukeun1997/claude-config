---
name: orca-feature
description: Use when user says '/orca-feature', 'codex로 구현', 'sol로 작업해줘', 'orca로 위임', 'sol에게 시켜', or wants a feature built by Codex workers while Claude orchestrates. Requires Orca app running. Not for DB migrations or single-file quick fixes.
---

# Orca Feature — Codex 위임 파이프라인

Claude(이 세션) = 오케스트레이터·설계·검증, Codex sol(Orca 워커) = plan·구현.
설계와 판단 게이트는 Claude가, 자율 실행 구간은 Codex가 맡는다. 생산-검증이 벤더 수준에서 분리된다.

## 작업 크기별 구성

에이전트 수는 파일 수가 아니라 **독립적인 검증 축의 수**로 결정한다. 구현자는 항상 SOL 워커 1명 (같은 파일 동시 수정 금지).

| 규모 | 구성 |
|------|------|
| 소규모 (단일 파일, 100줄 이하) | 이 스킬 스킵 — CLAUDE.md §2 직접 실행 또는 executor |
| 기본 (기능/버그, 2+파일) | 아래 Phase 1~6 그대로 (SOL 1명: plan+구현) |
| 고위험 (금융/동시성/DB/이벤트) | Phase 2에 **SOL 탐색 워커**(read-only 영향도 조사) 병렬 추가, Phase 5에 **SOL 검증 워커**(테스트/재현 실행) 추가. 단 **판정은 항상 Claude** — SOL이 SOL을 판정하면 같은 모델 계열 맹점을 공유하므로, SOL은 증거 수집까지만 |

## 사전 조건

```bash
orca status   # runtimeReachable: true 확인
```

- 실패 시: 사용자에게 Orca 앱 실행 요청. 대안으로 기존 `/feature`(Claude 단독) 제안
- DB 마이그레이션 포함 작업이면 이 스킬 사용 금지 — 마이그레이션은 메인 세션 직접 실행 (runtime-coexistence 규칙)

## Phase 1 — Spec (Claude, 사용자와 함께)

1. `superpowers:brainstorming` invoke → 인터뷰
2. spec 작성 — 3줄 룰 게이트: 최상단에 **AC**(동사 3개) / **Out-of-scope**(명사 3개) / **Done-when**(1줄)
3. 사용자 승인 (Gate 1)

## Phase 2 — 워커 생성 + Plan 위임

```bash
# 워커 터미널 생성 (Orca UI에 에이전트로 노출됨)
orca terminal create --worktree path:<프로젝트경로> --title "sol-worker: <기능명>" --command "codex" --json
# → result.terminal.handle 저장 (term_xxx)

orca orchestration task-create --task-title "plan: <기능명>" \
  --spec "<spec 파일 경로를 읽고 구현 plan을 <plan 파일 경로>에 작성. 코드 수정 금지." --json
# → task id 저장 (task_xxx)

orca orchestration dispatch --task task_xxx --to term_xxx --inject --json
```

## Phase 3 — Plan 게이트 (Claude critic)

1. 완료 감지 (아래 완료 감지 절 참조) 후 plan 파일 Read
2. `critic`(opus) 서브에이전트로 adversarial 검토
3. REJECT → findings를 같은 태스크 흐름으로 re-dispatch (1회). 재REJECT 시 사용자 보고
4. 사용자 승인 (Gate 2)

## Phase 4 — 구현 위임 (같은 워커 재사용)

같은 터미널에 dispatch하면 plan 컨텍스트가 유지된다. 태스크 spec에 Sprint Contract를 반드시 포함:

```bash
orca orchestration task-create --task-title "impl: <기능명>" --spec "$(cat <<'SPEC'
<plan 파일 경로>를 실행하라.
완료 조건:
1. [기능적 조건]: <spec의 AC>
2. [기술적 조건]: 빌드/테스트 통과. 기존 테스트 변경 금지, 추가만 허용
3. [제외 범위]: <spec의 Out-of-scope>
4. [의도 상태]: <사용자 관점 1줄>
SPEC
)" --json
orca orchestration dispatch --task task_yyy --to term_xxx --inject --json
```

## 완료 감지

`terminal wait --for tui-idle`은 주입 직후 조기 반환된다 — 신뢰 시그널은 **worker_done 메시지**다.
dispatch preamble이 워커에게 `orchestration send --type worker_done` 보고를 시키므로:

```bash
orca orchestration check --terminal <내 터미널 핸들> --json   # 폴링 (30s 간격 권장)
orca terminal read --terminal term_xxx                        # 상세 출력/RESULT 확인
```

worker_done 수신 → 본문에서 결과 파싱. 5분+ 무응답이면 `terminal read`로 상태 직접 확인 (승인 대기·에러 멈춤 감지).

### 워커 상호작용 (완료 외 메시지 타입)

워커는 블랙박스가 아니다 — check 폴링에서 타입별로 분기한다:

| 타입 | 의미 | 오케스트레이터 대응 |
|------|------|------|
| `worker_done` | 작업 완료 + 결과 | 결과 파싱 → Phase 5 진입 |
| `ask` | 워커가 질문 | 사실 질문이면 직접 `reply`. 결정(AC/스코프/트레이드오프)이면 사용자에게 AskUserQuestion 후 답 전달 |
| `decision_gate` | 태스크 블로킹 결정 대기 | `gate-list`로 확인 → 사용자 확인 → `gate-resolve` |
| `escalation` | 범위/권한/장애 보고 | 작업 중단 판단 + 사용자 보고 |
| `heartbeat` | 진행 상태 | 대응 불필요 (무응답 타이머만 리셋) |

워커가 사용자 UI(AskUserQuestion 등)를 직접 띄울 수는 없다 — 질문은 항상 이 메시지 경로를 경유한다.

## Phase 5 — 검증 (Claude)

1. `git diff` — 보고된 변경과 실제 diff 대조, scope 이탈 플래그
2. §4 리뷰 정책대로 `code-reviewer` (+민감 경로면 security-reviewer 등 자동 추가)
3. verifier — 테스트 변조 검사 (삭제/skip/assertion 약화)
4. findings → 같은 워커에 re-dispatch (최대 2라운드, 초과 시 사용자 에스컬레이션)

## Phase 6 — 종료

1. 검증 통과 → 워커에 `orchestration reply`로 ACK → 커밋 제안
2. `orca terminal close --terminal term_xxx` — 워커 정리. 단 **후속 작업이 예정되어 있으면 close하지 않고 warm 재사용** — 실비용은 dispatch가 아니라 세션 초기화(터미널 부팅·MCP/훅 로딩)이므로 워커 재사용이 하이브리드 손익분기점을 크게 낮춘다
3. daily log 기록

## Quick Reference

| 동작 | 명령 |
|------|------|
| 워커 생성 | `orca terminal create --worktree path:X --command codex --json` |
| 태스크 생성 | `orca orchestration task-create --spec "..." --json` |
| 위임 | `orca orchestration dispatch --task T --to term_X --inject` |
| 완료 폴링 | `orca orchestration check` / `orca orchestration inbox --json` |
| 출력 확인 | `orca terminal read --terminal term_X` |
| 회신 | `orca orchestration reply --id msg_X --body "..."` |
| 정리 | `orca terminal close --terminal term_X` |

## Common Mistakes

| 실수 | 결과 | 교정 |
|------|------|------|
| tui-idle로 완료 판정 | 주입 직후 조기 반환 → 빈 결과 | worker_done 메시지 기준 |
| 워커 자가보고(SUCCESS)를 그대로 신뢰 | 집계 오류·scope 이탈 통과 | git diff + 독립 리뷰로 대조 |
| plan/impl을 다른 터미널에 dispatch | plan 컨텍스트 유실 | 같은 term_xxx 재사용 |
| Sprint Contract 누락 | Codex가 verification.md 규약을 모름 | 태스크 spec에 완료 조건 4항목 명시 |
| 워커 터미널 방치 | Orca에 좀비 에이전트 누적 | Phase 6에서 close (후속 작업 있으면 warm 재사용) |
| ask/decision_gate 메시지 방치 | 워커 무한 블로킹 | check 폴링에서 타입별 분기 (워커 상호작용 표) |
| `terminal stop --worktree` 사용 | 같은 워크트리의 내 세션도 종료됨 | 개별 handle로 close |
