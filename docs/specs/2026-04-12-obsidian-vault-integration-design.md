---
title: Obsidian Vault Integration
type: spec
project: global
branch: main
created: 2026-04-12
status: active
---

# Obsidian Vault Integration — 설계 문서

Claude Code의 설계·플래닝·구현 문서를 `~/vault/`(Obsidian vault)에서 통합 관리하는 시스템.

## 배경

- 기존: plan/spec 파일이 `docs/superpowers/` 임시 경로에 생성되어 세션 종료 후 찾기 어려움
- 목표: Obsidian에서 프로젝트별·브랜치별로 문서를 탐색하고 관리

## 결정 사항

| 항목 | 결정 | 근거 |
|------|------|------|
| Vault 경로 | `~/vault/` | 공백 없음, CLI 접근 용이, sandbox 문제 없음 |
| 저장 방식 | plan/spec 자동 저장 | Obsidian에서 보려면 생성 즉시 vault에 있어야 함 |
| Memory | `~/.claude/memory/` 유지 | 8+ hooks 연동, 자동 rotate, 이동 시 파손 위험 |
| Codex | Claude만 우선 | Codex 출력은 비정형, harvest→daily log로 이미 연결됨 |
| 접근법 | docs-save 스킬 리팩토링 + hook | superpowers 원본 미수정, 업데이트 안전 |

## 아키텍처

### Vault 폴더 구조

```
~/vault/
├── .obsidian/                        ← Obsidian 설정
├── {project}/
│   ├── spec.md                       ← main 브랜치 문서
│   ├── plan.md
│   └── {branch-slug}/               ← feature 브랜치 문서
│       ├── spec.md
│       └── plan.md
└── global/                           ← ~/.claude 또는 매칭 없는 프로젝트
```

### 브랜치 슬러그 규칙

- `main`, `master`, `develop` → 브랜치 폴더 생략 (프로젝트 직하)
- 그 외 → slash를 `--`로 변환 (예: `fix/avro-dlt` → `fix--avro-dlt`)

### 프로젝트 감지

CWD 기반:
- `~/IdeaProjects/{name}/` → `{name}`
- `~/.claude` 또는 매칭 없음 → `global`

## 변경 대상

### 1. docs-save 스킬 (`~/.claude/skills/docs-save/SKILL.md`)

저장 경로 변경:
```diff
- ~/IdeaProjects/docs/{project}/{branch-slug}/
+ ~/vault/{project}/{branch-slug}/
```

제외 규칙 업데이트:
```diff
- 이미 ~/IdeaProjects/docs/ 하위 → "이미 vault에 있습니다"
+ 이미 ~/vault/ 하위 → "이미 vault에 있습니다"
```

나머지 로직 유지:
- 프로젝트 감지 (CWD 기반)
- 브랜치 감지 (`git rev-parse --abbrev-ref HEAD`)
- 파일명 결정 (plan.md, spec.md, 중복 시 topic suffix)
- Frontmatter 주입 (title, type, project, branch, created, status)

### 2. vault-auto-save.sh (`~/.claude/hooks/vault-auto-save.sh`)

PostToolUse hook. Write/Edit 도구 호출 시 실행.

**감지 대상:**
- `docs/superpowers/specs/*-design.md` → `spec.md`로 저장
- `docs/superpowers/plans/*.md` → `plan.md`로 저장

**동작:**
1. 파일 경로가 패턴에 매칭되는지 확인
2. 매칭되면 프로젝트/브랜치 감지
3. `~/vault/{project}/{branch-slug}/` 디렉토리 생성
4. frontmatter 주입 후 복사
5. stderr로 저장 완료 메시지 출력

**프로젝트/브랜치 감지:** hook은 Claude 프로세스의 CWD를 상속하므로, CWD 기반 프로젝트 감지가 정상 동작함.

**비매칭 시:** 아무 동작 안 함 (exit 0)

### 3. settings.json (`~/.claude/settings.json`)

PostToolUse hooks 배열에 vault-auto-save.sh 등록:
```json
{
  "matcher": "Write|Edit",
  "command": "bash ~/.claude/hooks/vault-auto-save.sh"
}
```

### 4. Vault 초기화

- `~/vault/.obsidian/app.json` — 최소 Obsidian 설정
- `~/vault/.gitkeep` — 빈 vault 상태에서도 git 추적 가능

## 데이터 흐름

```
superpowers:brainstorming
  → Write: docs/superpowers/specs/2026-04-12-topic-design.md
  → [PostToolUse hook: vault-auto-save.sh]
  → 패턴 매칭 → 프로젝트/브랜치 감지
  → Write: ~/vault/{project}/{branch}/spec.md (frontmatter 포함)

superpowers:writing-plans
  → Write: docs/superpowers/plans/xxxx.md
  → [PostToolUse hook: vault-auto-save.sh]
  → 패턴 매칭 → 프로젝트/브랜치 감지
  → Write: ~/vault/{project}/{branch}/plan.md (frontmatter 포함)

수동: /docs-save some-file.md
  → docs-save 스킬 실행
  → Write: ~/vault/{project}/{branch}/some-file.md
```

## Frontmatter 형식

```yaml
---
title: "(원본 # 헤딩에서 추출)"
type: plan | spec | design
project: banking-loan
branch: feature--loan-repayment
created: 2026-04-12
status: active
---
```

## 제외 규칙

- `memory/active/*.md`, `memory/daily/*.md` → 저장 거부
- 이미 `~/vault/` 하위에 있는 파일 → "이미 vault에 있습니다"

## 향후 확장 (이번 스코프 아님)

- Codex harvest → vault 자동 저장
- memory topics의 Obsidian symlink
- Obsidian 태그/백링크 활용
- iCloud 동기화 설정
