---
name: feature
description: "새 기능 구현 전체 파이프라인. brainstorming → plans → execution을 2-gate 확인으로 연결. Use when user says '/feature', '새 기능', 'new feature', '기능 만들자'."
---

# Feature Pipeline — 2-Gate 워크플로우

새 기능 구현의 전체 흐름(설계 → 계획 → 실행)을 하나의 명령으로 시작하되, 각 단계 사이에 사용자 확인 게이트를 둔다.

## When to Apply

- `/feature {설명}` 또는 관련 트리거 입력 시
- 새 기능 구현이 필요할 때 (2개+ 파일 변경 예상)
- 단일 파일 100줄 이하 수정은 이 스킬 불필요 — 직접 실행

## 파이프라인

```
/feature {설명}
    │
    ▼
Phase 1: Brainstorming
    → superpowers:brainstorming 스킬 invoke (인자: {설명})
    → 접근법 탐색, 인터뷰, 설계안 도출
    │
    ▼
Gate 1: 설계 확인 ←── 사용자 "ㅇㅋ" 또는 피드백
    │
    ▼
Phase 2: Planning
    → superpowers:writing-plans 스킬 invoke
    → 스펙 기반 태스크 분해, 파일 맵, 단계별 구현 계획
    │
    ▼
Gate 2: 플랜 확인 ←── 사용자 "ㅇㅋ" 또는 피드백
    │
    ▼
Phase 3: Execution
    → superpowers:subagent-driven-development 스킬 invoke
    → 태스크별 서브에이전트 파견, 2-stage 리뷰
```

## 실행 방법

### Pre-flight: Vault 경로 계산

brainstorming/writing-plans 호출 **이전**에 저장 경로를 결정해 preference로 전달한다.
두 skill 모두 `(User preferences for location override this default)`를 지원하므로, 하드코딩된 `docs/superpowers/{specs,plans}/` 대신 Obsidian vault를 주 저장소로 쓴다.

1. **Project 감지** (CWD 기반, `docs-save` skill과 동일 규칙):
   - `~/.claude` 또는 매칭 없음 → `global`
   - 그 외 → 디렉토리명 (예: `banking-loan`, `haru`, `rms`)
2. **Branch 감지**:
   ```bash
   BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
   ```
   - `main`/`master`/`develop` → 브랜치 폴더 없음
   - 그 외 → 슬래시를 `--`로 치환 (`fix/avro-dlt` → `fix--avro-dlt`)
3. **Target 디렉토리**: `~/vault/{project}/{branch-slug}/` (base 브랜치면 `~/vault/{project}/`)
4. 디렉토리가 없으면 `mkdir -p`로 생성

### Phase 1: Brainstorming

`superpowers:brainstorming` 스킬을 아래 인자로 invoke한다:

```
{설명}

[저장 선호]
- spec 파일 경로: ~/vault/{project}/{branch-slug}/spec.md
  (이미 같은 이름이 있으면 spec-{topic-slug}.md)
- docs/superpowers/specs/ 에는 저장하지 않음 (vault가 정본)
- commit은 해당 디렉토리가 git 저장소가 아니면 skip
```

brainstorming 스킬이 인터뷰 → 접근법 제안 → 설계안 → 스펙 문서 작성까지 수행한다.

### Gate 1

brainstorming 완료 후 사용자에게 확인:

> "설계 완료. 스펙: `~/vault/{project}/{branch}/spec.md`. 플랜 작성으로 넘어갈까요?"

- 사용자 OK → Phase 2 진행
- 사용자 피드백 → brainstorming 내에서 수정 후 다시 Gate 1

### Phase 2: Planning

`superpowers:writing-plans` 스킬을 아래 인자로 invoke한다:

```
[스펙 경로] ~/vault/{project}/{branch-slug}/spec.md

[저장 선호]
- plan 파일 경로: ~/vault/{project}/{branch-slug}/plan.md
  (이미 같은 이름이 있으면 plan-{topic-slug}.md)
- docs/superpowers/plans/ 에는 저장하지 않음 (vault가 정본)
```

스펙 문서 기반으로 구현 계획을 작성한다.

### Gate 2

플랜 완료 후 사용자에게 확인:

> "플랜 완료. `~/vault/{project}/{branch}/plan.md`. 구현 시작할까요? (1: Subagent-Driven / 2: Inline)"

- 사용자 OK → Phase 3 진행
- 사용자 피드백 → 플랜 수정 후 다시 Gate 2

### Phase 3: Execution

사용자 선택에 따라:
- **1 (기본)**: `superpowers:subagent-driven-development` invoke
- **2**: `superpowers:executing-plans` invoke

## 제약사항

1. 각 Phase는 해당 스킬의 전체 프로세스를 따른다 (이 스킬이 축약하지 않음)
2. Gate에서 사용자 확인 없이 다음 Phase로 넘어가지 않는다
3. 단순 작업(단일 파일, 100줄 이하)에는 이 파이프라인을 적용하지 않는다
