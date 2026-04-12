---
name: notion-update
description: "Update Notion project pages from daily logs and session context. Use when user says '/notion-update <project>', 'notion update', '노션 업데이트'. Supports multiple projects via registry."
user_invocable: true
---

# Notion Update — 프로젝트 Notion 페이지 자동 업데이트

세션의 daily log와 작업 컨텍스트를 기반으로 프로젝트의 Notion 페이지들을 업데이트합니다.

## Usage

```
/notion-update <project-alias>
```

**Examples:**
- `/notion-update haru` — TODO APP Haru 프로젝트 업데이트
- `/notion-update building` — 건물관리 프로젝트 업데이트
- `/notion-update maple` — 하자서버 프로젝트 업데이트

## How It Works

### Step 1: 프로젝트 레지스트리 로드

`~/.claude/skills/notion-update/projects.json`에서 프로젝트 설정을 읽습니다.

**경로 규칙:**
- `project_dir`은 `~`로 시작 (머신 간 이식성 보장)
- `memory_dir`은 JSON에 없음 — `project_dir`에서 자동 생성:
  1. `~`를 `$HOME`으로 확장
  2. 확장된 절대경로에서 `/` → `-`로 치환
  3. `~/.claude/projects/{치환된경로}/memory`

```json
{
  "<alias>": {
    "name": "프로젝트 표시명",
    "project_dir": "~/path/to/project",
    "notion_pages": {
      "main": "메인 페이지 ID (대시보드)",
      "log": "작업 일지 페이지 ID (날짜별 하위페이지 허브)",
      "reference": "참조 문서 페이지 ID (optional)",
      "archive": "아카이브 페이지 ID (optional)"
    },
    "update_sections": ["progress", "log"]
  }
}
```

### Step 2: 컨텍스트 수집

아래 소스에서 업데이트할 내용을 수집합니다:

1. **Daily Log** (`memory/daily/YYYY-MM-DD.md`) — 오늘 작업 내역
2. **세션 컨텍스트** — 현재 세션에서 수행한 작업 (커밋, 코드 리뷰, 버그 수정 등)
3. **Git Log** — 최근 커밋 메시지 (`git log --oneline -10`)
4. **MEMORY.md** — 프로젝트 장기 메모리

### Step 3: 작업 일지 업데이트 (`log`)

**날짜별 하위페이지 구조:**
```
📝 작업 일지
├── 2026-03-01 (토)        ← 날짜 페이지
│   ├── 오늘의 요약 (callout)
│   ├── 작은 작업 ✅ (인라인)
│   ├── [큰 작업 ✅] (하위페이지)
│   └── 의사결정/버그 (인라인)
└── ...
```

#### 3-1. 오늘 날짜 페이지 확인
- `notion-fetch`로 작업 일지 페이지를 읽어 오늘 날짜 하위페이지 존재 여부 확인
- **없으면** → `notion-create-pages`로 날짜 페이지 생성 (parent: log 페이지)
- **있으면** → 기존 날짜 페이지에 추가

#### 3-2. 작업별 분류
각 작업을 아래 기준으로 인라인/하위페이지로 분류:

**하위페이지 생성 기준** (하나라도 충족):
- 커밋 3개 이상
- 변경 파일 10개 이상
- 리뷰 수정 5건 이상

**인라인 작업 포맷:**
```
### 작업 제목 ✅

**요약**: 한 줄 설명
**주요 변경**:
- 변경사항 1
- 변경사항 2
**커밋**: `해시` — N파일, +N줄
**검증**: 테스트 결과
```

**하위페이지 포맷:**
```
(페이지 제목: "작업 제목 ✅")

**요약**: 한 줄 설명

**주요 변경**:
- 변경사항 (상세)

**리뷰 수정 반영**: (있는 경우)
- CRITICAL/HIGH/MEDIUM 항목

**커밋**: `해시` — N파일, +N줄
**검증**: 테스트 결과
```

### Step 4: 메인 페이지 업데이트 (`main`)

- 진행 상태 테이블의 상태 값 업데이트
- 구현 현황 테이블 (커밋 해시, 파일 수, 상태)
- Phase 남은 항목: 완료 시 행 삭제

### Step 5: 결과 보고

업데이트 완료 후 변경 요약을 표시합니다:
```
Notion 업데이트 완료:
- [log] 날짜 페이지 생성 + 인라인 2건 + 하위페이지 1건
- [main] 상태 테이블 2개 항목 업데이트
```

## Procedure

### Phase 1: 메인 세션 — 콘텐츠 준비 (Notion I/O 없음)

1. Read `~/.claude/skills/notion-update/projects.json` to find the project config
2. If alias not found, list available projects and ask user to choose
3. Read the project's daily log (`memory/daily/YYYY-MM-DD.md`)
4. Run `git log --oneline -10` in the project directory
5. 수집한 정보로 **마크다운 콘텐츠를 미리 작성**:
   - 작업일지 인라인 섹션 (마크다운 문자열)
   - 하위페이지용 콘텐츠 (필요 시)
   - 메인 페이지 상태 변경 사항 (old_str → new_str 쌍)

### Phase 2: 서브에이전트 — Notion I/O 전담

**서브에이전트에 위임** (general-purpose, model=sonnet):

```
프롬프트에 포함할 정보:
- projects.json의 page ID들 (search 호출 생략)
- Phase 1에서 준비한 마크다운 콘텐츠
- 작업일지 기록 지침 (아래 섹션)
- 구체적 Notion MCP 호출 순서
```

서브에이전트 작업:
1. `notion-fetch` log 페이지 (page ID 직접 사용) → 오늘 날짜 하위페이지 존재 여부 확인
2. **날짜 페이지가 없으면** → `notion-create-pages`로 생성 (parent: log page ID)
   - 제목: `YYYY-MM-DD (요일)`
   - 내용: 요약 callout
3. **작업별 분류**:
   - 하위페이지 기준 충족 → `notion-create-pages`로 하위페이지 생성 (parent: 날짜 페이지)
   - 미충족 → 날짜 페이지에 `insert_content_after`로 인라인 섹션 추가
4. 메인 페이지 업데이트 필요 시: `notion-fetch` main page ID → `replace_content_range`로 업데이트
5. 결과 보고: 생성/수정한 페이지 목록 + 성공/실패

### Phase 3: 메인 세션 — 결과 보고

서브에이전트 결과를 사용자에게 요약 보고.

### 토큰 절약 핵심

| 기법 | 절약량 | 설명 |
|------|--------|------|
| 서브에이전트 위임 | ~10K tokens | Notion 페이지 원시 데이터가 메인 컨텍스트에 안 들어옴 |
| Page ID 직접 사용 | ~2K tokens/회 | search 호출 + 응답 생략 |
| 콘텐츠 사전 준비 | ~3K tokens | 서브에이전트가 판단할 필요 없이 준비된 마크다운만 전달 |

## Important Rules

- **Never overwrite** — 항상 `replace_content_range` 또는 `insert_content_after` 사용, `replace_content` 금지
- **Preserve child pages** — `<page url="...">` 태그를 반드시 포함하여 하위 페이지 보존
- **Korean** — 모든 Notion 콘텐츠는 한국어
- **Idempotent** — 두 번 실행해도 중복 생성 없음; 추가 전 항상 확인
- **날짜 페이지 재사용** — 같은 날짜의 페이지가 이미 있으면 새로 만들지 않고 기존에 추가

## 작업일지 기록 지침 (필수 준수)

> 참조: [AI 작업일지 기록 지침](https://www.notion.so/sukeun1997/AI-31652c2d4a6381c6b41afecd9942ff5e)

### 기록 위치 분리
| 변경 대상 | 기록 위치 | 비고 |
|----------|----------|------|
| 일일 작업 내용 | **📝 작업 일지** → 날짜 페이지 | 인라인 or 하위페이지 |
| 기능 완료/상태 변경 | **메인 페이지** 상태 테이블 | 해당 행만 업데이트 |
| Phase 항목 완료 | **메인 페이지** 남은 항목 테이블 | 완료 행 삭제 |

### 금지 사항
- **메인 페이지에 일일 작업 로그 작성 금지** — 메인은 대시보드 전용
- **중복 기록 금지** — 같은 내용을 여러 번 반복하지 않음
- **파일별 변경 나열 금지** — 커밋 해시와 요약만 기록
- **완료 항목 취소선 금지** — 행 삭제 or 상태 변경
- **내부 실행 방식 기록 금지** — "Subagent-Driven", "executor 3개 병렬" 등 노출 X

### 메인 페이지 업데이트 규칙
- 상태 테이블: 완료 시 `✅ 완료`로 변경, 비고는 핵심 키워드만 (1줄)
- Phase 남은 항목: 완료 시 행 삭제, 새 항목은 우선순위별 정렬
- Callout: 큰 마일스톤 달성 시만 갱신
