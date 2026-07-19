# Governance as Code

"차단이 아닌 자동 교정" — Toss "Harness" 패턴 적용.

## frozen.yml vs governance.yml

| 파일 | 역할 | 동작 | 사용 시점 |
|------|------|------|-----------|
| `frozen.yml` | **수정 차단** | 파일 수정 시 에러 + 사용자 승인 필요 | build.gradle.kts 등 절대 보호 |
| `governance.yml` | **변경 감시** | 파일 수정 시 경고 + 관련 검증/command 추천 | Avro, Consumer, Migration 등 주의 필요 파일 |

Codex/OMX 기본 위치:

- 프로젝트 로컬: `.claude/governance.yml`
- 실행 오버레이: `AGENTS.md`의 Governance Warnings 섹션

## governance.yml 구조

```yaml
rules:
  - pattern: "*.avsc"
    message: "Avro 스키마 변경 감지"
    recommend: "/avro-plan"
    severity: warn

  - pattern: "*Consumer*.kt"
    message: "Kafka Consumer 변경 감지"
    recommend: "토픽/DLT/멱등성 확인 필요"
    severity: warn
```

이 저장소에서는 `.claude/governance.yml`을 기본 샘플로 유지한다.

## Hook 우선순위

PostToolUse Hook 실행 순서 (settings.json 기준):
1. `memory-post-tool.py` (메모리 기록 + 파일 추적 + 삽질 감지 + Agent/Skill 사용 기록 — matcher: `*`)
2. `prisma-auto-generate.mjs` (Prisma schema 감지 — matcher: `Edit|Write`)
3. **`governance-guard.sh`** (변경 감시 — matcher: `Edit|Write`)

Codex/OMX 적응 원칙:

- Hook이 있으면 `governance.yml`을 자동 경고로 사용
- Hook이 없어도 동일 규칙을 `AGENTS.md`와 검증 체크리스트로 수동 적용
- 핵심은 "막는 것"이 아니라 "빠진 검증을 떠올리게 하는 것"

## 원칙

- **경고는 하되 차단하지 않는다**: governance.yml 매칭은 stderr로 경고만 출력
- **행동을 추천한다**: 관련 slash command나 확인사항을 안내
- **프로젝트별 독립**: 각 프로젝트가 자체 governance.yml을 가질 수 있음
- **점진적 확장**: 규칙은 실제 실수 사례에서 추출하여 추가

## Codex용 기본 추천 경로

아래는 이 저장소에서 기본으로 감시하는 민감 경로다.

- `AGENTS.md`, `CLAUDE.md`, `rules/common/*.md`
- `.omx/*.json`, `.omx/notepad.md`
- `hooks/*`, `scripts/*`
- `settings*.json`

## 훅 출력 설계 원칙

- **결정적 출력**: 훅이 시스템 프롬프트에 주입하는 텍스트는 동일 입력 시 동일 출력을 보장. 타임스탬프, 랜덤 값 등 비결정적 요소는 사이드이펙트(파일 기록)로 처리하고 프롬프트 주입에는 포함하지 않음 — 프롬프트 캐시 hit rate 향상
- **출력 크기 제한**: 훅 출력이 시스템 프롬프트에 주입되는 경우 간결하게 유지. 상세 내용은 파일에 기록하고 경로만 안내
