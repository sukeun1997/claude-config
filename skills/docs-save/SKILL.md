---
name: docs-save
description: "Claude 생성 문서(plan/spec)를 Obsidian vault에 저장. Use when user says '/docs-save', 'docs에 저장', '옵시디언에 저장', 'vault에 넣어줘'."
---

# docs-save — Obsidian Vault 저장

Claude가 생성한 plan/spec/설계 문서를 `~/vault/20 프로젝트/{project}/{branch}/`에 저장한다.

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

CWD 기반으로 프로젝트명 후보 결정:
- `banking-loan`, `haru`, `rms` 등 → 프로젝트 이름
- `~/.claude` 또는 매칭 없음 → `global`

**기존 폴더 근접 매칭 (새 폴더 남발 방지)**: 후보 이름을 그대로 새 폴더로 만들지 말고, `20 프로젝트` 기존 폴더와 대조한다.

```bash
ls "$HOME/vault/20 프로젝트/"
```

- 정확히 일치하는 폴더 있으면 → 그 폴더 사용
- 오타/하이픈/대소문자 차이만 있는 근접 폴더 있으면 (예: CWD `building-manger` → 기존 `building-manager`) → 근접 폴더 재사용
- 애매하거나 근접 폴더가 여러 개면 → 사용자에게 1-tap 확인 (AskUserQuestion)
- 진짜 신규 프로젝트면 → 후보 이름으로 새 폴더 생성

### 2. Branch 감지

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
```

- `main`, `master`, `develop` → 프로젝트 폴더 직하에 저장 (브랜치 폴더 없음)
- 그 외 → 슬래시를 `--`로 변환 (예: `fix/avro-dlt` → `fix--avro-dlt`)

### 3. 저장 경로 결정

```
~/vault/20 프로젝트/{project}/{branch-slug}/
```
(공백 포함 경로 — bash 사용 시 `"$HOME/vault/20 프로젝트/{project}/{branch-slug}/"` 로 인용)

### 4. 파일명 결정

모든 저장 파일명 끝에 **작성일(YYYY-MM-DD)** postfix를 붙여 생성 시점을 식별 가능하게 한다.

| 원본 유형 | 저장 이름 |
|-----------|-----------|
| superpowers plan (랜덤 이름 .md) | `plan-{YYYY-MM-DD}.md` 또는 `plan-{topic}-{YYYY-MM-DD}.md` (topic이 추출 가능한 경우) |
| superpowers spec (*-design.md) | `spec-{YYYY-MM-DD}.md` 또는 `spec-{topic}-{YYYY-MM-DD}.md` |
| 기타 | `{원본파일명}-{YYYY-MM-DD}.md` (확장자 앞에 삽입) |

topic은 원본 파일에서 `# ` 헤딩의 첫 번째 단어 2-3개를 slug화하여 사용.
같은 날 같은 이름이 이미 존재하면 `-2`, `-3` 순번을 덧붙인다.

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
mkdir -p "$HOME/vault/20 프로젝트/{project}/{branch-slug}/"
```

원본 파일을 Read → frontmatter 주입 → Write로 대상 경로에 저장.

저장 완료 메시지:
> "저장 완료: `~/vault/20 프로젝트/{project}/{branch}/{파일명}-{YYYY-MM-DD}.md`"

## 제외

- `memory/active/*.md`, `memory/daily/*.md` → 저장 거부 + 안내
- 이미 `~/vault/` 하위에 있는 파일 → "이미 vault에 있습니다" 안내
