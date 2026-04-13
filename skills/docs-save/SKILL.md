---
name: docs-save
description: "Claude 생성 문서(plan/spec)를 Obsidian vault에 저장. Use when user says '/docs-save', 'docs에 저장', '옵시디언에 저장', 'vault에 넣어줘'."
---

# docs-save — Obsidian Vault 저장

Claude가 생성한 plan/spec/설계 문서를 `~/vault/{project}/{branch}/`에 저장한다.

## When to Apply

- `/docs-save {파일경로}` 호출 시
- 사용자가 "docs에 저장해줘", "옵시디언에 넣어줘" 등 요청 시
- `writing-plans`, `brainstorming` 완료 후 사용자가 저장 승인 시

## 파라미터

`$ARGUMENTS`에서 파일 경로를 추출한다.
- 경로가 없으면: 현재 세션에서 가장 최근에 생성/수정한 plan 또는 spec 파일을 자동 감지
- 복수 파일: 공백으로 구분

## 실행 흐름

### 1. Project 감지

CWD 기반으로 프로젝트명 결정:
- `banking-loan`, `haru`, `rms` 등 → 프로젝트 이름
- `~/.claude` 또는 매칭 없음 → `global`

### 2. Branch 감지

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
```

- `main`, `master`, `develop` → 프로젝트 폴더 직하에 저장 (브랜치 폴더 없음)
- 그 외 → 슬래시를 `--`로 변환 (예: `fix/avro-dlt` → `fix--avro-dlt`)

### 3. 저장 경로 결정

```
~/IdeaProjects/docs/{project}/{branch-slug}/
```

### 4. 파일명 결정

| 원본 유형 | 저장 이름 |
|-----------|-----------|
| superpowers plan (랜덤 이름 .md) | `plan.md` 또는 `plan-{topic}.md` (같은 브랜치에 이미 plan.md 있으면) |
| superpowers spec (*-design.md) | `spec.md` 또는 `spec-{topic}.md` |
| 기타 | 원본 파일명 유지 |

topic은 원본 파일에서 `# ` 헤딩의 첫 번째 단어 2-3개를 slug화하여 사용.

### 5. Frontmatter 주입

원본 파일에 frontmatter가 없으면 추가, 있으면 병합:

```yaml
---
title: "(원본 # 헤딩에서 추출)"
type: plan | spec | design
project: (감지된 프로젝트)
branch: (감지된 브랜치)
created: (오늘 날짜)
status: active
---
```

### 6. 복사 + 확인

```bash
mkdir -p ~/vault/{project}/{branch-slug}/
```

원본 파일을 Read → frontmatter 주입 → Write로 대상 경로에 저장.

저장 완료 메시지:
> "저장 완료: `~/vault/{project}/{branch}/{파일명}`"

## 제외

- `memory/active/*.md`, `memory/daily/*.md` → 저장 거부 + 안내
- 이미 `~/vault/` 하위에 있는 파일 → "이미 vault에 있습니다" 안내
