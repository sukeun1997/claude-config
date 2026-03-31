# 병렬 개발 — 독립 작업을 워크트리에서 동시 수행

주어진 작업을 분석하여 독립적인 단위로 분할하고, 각각을 별도 git worktree + 브랜치에서 병렬로 개발한다.

## 입력

`$ARGUMENTS`를 분석하여 병렬화 가능한 독립 작업을 식별한다.

## 실행 흐름

### Phase 1: 작업 분석 및 분할

1. 요청된 작업을 독립 단위로 분할
2. 각 단위 간 의존성 그래프 작성
3. 의존성 없는 단위끼리 병렬 그룹으로 묶기
4. 사용자에게 분할 계획 제시 후 승인 대기

### Phase 1.5: Base 브랜치 최신화

워크트리 생성 전, base 브랜치(기본: `develop`)를 최신 상태로 pull한다:

```bash
# develop 최신화 (fetch + fast-forward)
git fetch origin develop
git branch -f develop origin/develop
```

> **주의**: `git checkout develop && git pull` 대신 `git fetch + branch -f`를 사용한다.
> 이유: 현재 작업 중인 브랜치에서 checkout하지 않아도 되므로 uncommitted changes 충돌을 방지한다.

### Phase 2: 워크트리 환경 격리

각 worktree에 대해 아래 격리를 자동 수행:

```
worktree-1 (branch: feature/task-1)
├── 환경 격리: 테스트 DB 포트/이름 자동 분리
├── Spring 테스트: server.port=0 (랜덤 포트)
└── H2 인메모리 DB: 워크트리별 독립 인스턴스 (기본 동작)

worktree-2 (branch: feature/task-2)
├── 동일 격리 적용
└── ...
```

#### 포트/리소스 충돌 방지 규칙

| 리소스 | 격리 방법 |
|--------|-----------|
| Spring 서버 포트 | `server.port=0` (랜덤) — 테스트에서는 기본 동작 |
| H2 인메모리 DB | 각 JVM 프로세스가 독립 인스턴스 사용 — 충돌 없음 |
| EmbeddedKafka | 테스트별 별도 토픽 사용 (기존 컨벤션) |
| TestContainers | 각 프로세스가 독립 컨테이너 생성 — 충돌 없음 |
| Gradle 빌드 | `--no-daemon` 사용 시 프로세스 독립, daemon 사용 시 동일 daemon 공유 (안전) |

> banking-loan 프로젝트는 H2 인메모리 + EmbeddedKafka 기반이므로 포트 충돌 위험이 낮다.
> 단, TestContainers 사용 시 Docker 리소스(CPU/메모리) 경합에 주의.

### Phase 2.5: 세션 디렉토리 이동

Worktree 생성 후 **반드시 현재 세션의 작업 디렉토리를 이동**한다.

| 모드 | 동작 |
|------|------|
| **단일 worktree** (브랜치 1개) | 해당 worktree로 `cd` 이동 후 작업 계속 |
| **병렬 worktree** (브랜치 2개+) | 첫 번째 worktree로 이동 후 executor 병렬 실행. 완료 후 사용자에게 어느 worktree에서 작업할지 확인 |

```bash
# 단일: 즉시 이동
cd ../banking-loan-worktrees/<브랜치명>

# 병렬: executor 완료 후 사용자 선택
echo "어느 worktree에서 작업하시겠습니까?"
echo "1) ../banking-loan-worktrees/feature/task-1"
echo "2) ../banking-loan-worktrees/feature/task-2"
# 선택된 worktree로 cd
```

> **주의**: `cd`하지 않으면 이후 모든 파일 편집/빌드/테스트가 원래 프로젝트에서 실행되어 의도치 않은 변경이 발생한다.

### Phase 3: 병렬 실행

각 worktree에서 `executor` 에이전트를 병렬로 실행한다.

```
메인 → executor(worktree-1, task-1) ─┐
     → executor(worktree-2, task-2) ─┤ 병렬
     → executor(worktree-3, task-3) ─┘
                                      ↓
                              결과 수집 및 통합
```

각 executor에게 전달할 프롬프트에 반드시 포함:
- 해당 작업의 상세 요구사항
- 변경 대상 파일/모듈 범위
- 다른 워크트리와의 경계 (수정 금지 파일)
- 구조화된 응답 형식 (agents.md 참조)

### Phase 4: 결과 수집 및 통합 보고

모든 executor 완료 후 아래 형식으로 통합 보고한다:

```markdown
## Parallel Dev Results

### Task Summary
| # | Task | Branch | Status | Files Changed | LOC Delta |
|---|------|--------|--------|---------------|-----------|
| 1 | [작업명] | feature/task-1 | SUCCESS/PARTIAL/FAILED | N개 | +X/-Y |

### Per-Task Details
#### Task 1: [작업명]
- **Branch**: feature/task-1
- **Worktree**: /path/to/worktree
- **변경 파일**: [목록]
- **핵심 내용**: [요약]
- **미해결 사항**: [있으면]

### Integration Plan
- [ ] 머지 순서: task-1 → task-2 → task-3 (의존성 순)
- [ ] 충돌 예상 파일: [있으면]
- [ ] 통합 테스트 필요 여부: Y/N

### Next Steps
어떤 작업부터 머지할까요? (예: "1번부터 머지해줘")
```

### Phase 5: 검증 (자동)

각 워크트리의 결과에 대해 **verifier 에이전트를 병렬로** 실행:
- 빌드 통과 확인
- 변경 파일 실재 확인
- 보고된 내용과 실제 diff 일치 확인

## 제한사항

- 최대 병렬 워크트리: **3개** (리소스 경합 방지)
- 동일 파일을 여러 워크트리에서 수정하는 작업은 **순차 실행**으로 전환
- 공통 모듈(`common:*`) 변경이 포함된 작업은 단독 실행 권장

## Worktree 관리

### 목록 확인
`/parallel-dev list` → `git worktree list` 실행 후 banking-loan-worktrees 하위만 필터링하여 표시.

### 개별 삭제
`/parallel-dev remove <브랜치명>` → 해당 worktree만 삭제:
```bash
# 1. 미커밋 변경사항 확인 (있으면 경고 후 사용자 확인)
cd ../banking-loan-worktrees/<브랜치명> && git status --short

# 2. worktree 삭제
git worktree remove ../banking-loan-worktrees/<브랜치명>

# 3. 로컬 브랜치도 삭제할지 사용자에게 확인
# (이미 머지/푸시된 경우만 삭제 제안)
git branch -d <브랜치명>  # 머지 안 된 경우 실패 → 사용자에게 -D 여부 확인
```

### 전체 정리
`/parallel-dev cleanup` → 모든 banking-loan-worktrees 하위 worktree 삭제:
```bash
# 1. 각 worktree의 미커밋 변경사항 일괄 확인
# 2. 미커밋 있는 worktree 목록 경고
# 3. 사용자 승인 후 전체 삭제
git worktree list | grep banking-loan-worktrees | while read path _; do
  git worktree remove "$path"
done
git worktree prune
```

### 정리 안전 규칙
- **미커밋 변경사항이 있으면 절대 자동 삭제하지 않음** — 사용자 확인 필수
- **원격에 푸시되지 않은 브랜치는 경고** — "이 브랜치는 원격에 없습니다. 삭제하면 작업이 유실됩니다"
- 빈 디렉토리(`../banking-loan-worktrees/`)는 마지막 worktree 삭제 시 함께 제거

## 원칙

- **Plan-First**: Phase 1에서 반드시 사용자 승인 후 실행
- **격리 보장**: 워크트리 간 파일 수정 범위가 겹치지 않도록 분할
- **결과 투명성**: 모든 워크트리의 결과를 통합 보고, PARTIAL/FAILED도 숨기지 않음

$ARGUMENTS
