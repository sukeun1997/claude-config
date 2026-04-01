---
name: notion-writer
description: "Convert markdown content to Notion native blocks via Anthropic Notion MCP (primary) or CDP MCP (fallback). Supports headers, lists, tables, code blocks, dividers, rich text, inline images. Use when user says 'write to notion', 'create notion page', '노션에 작성', '노션 페이지 만들어'."
---

# Notion Writer — MCP 기반 Notion 페이지 생성

Anthropic Notion MCP(`mcp__claude_ai_Notion__*`)를 우선 사용하고, 실패 시 CDP MCP(`notion-cdp`)로 폴백. 마크다운 → Notion 네이티브 블록 자동 변환.

## When to Apply

- 마크다운 콘텐츠를 Notion 페이지로 만들 때
- 기존 데이터를 Notion에 정리할 때
- Notion 페이지 읽기/검색/수정할 때

## Architecture (v2 — MCP 기반)

```
[마크다운 콘텐츠]
       |
       v
[Notion MCP Tool] ──→ 내부에서 마크다운 파싱 + 블록 변환
       |
       v
[CDP WebSocket] ──→ Notion 내부 API (submitTransaction)
       |
       v
[Notion 페이지 렌더링]
```

**vs 레거시 (TypeScript 직접 CDP)**:
- MCP: 1회 도구 호출, ~3.5K tokens
- 레거시: TS 생성 → 빌드 → 실행 → 파싱, 5+ 도구 호출, ~15K tokens

## Prerequisites

Notion Electron 앱이 CDP 포트로 실행 중이어야 함:

```bash
/Users/sukeun/IdeaProjects/관리/launch-notion.sh
```

## MCP Tools

ToolSearch로 로드 후 사용:

```
ToolSearch("notion")  # 최초 1회
```

### 읽기
```
mcp__notion-cdp__read_notion_page(page_id="URL 또는 ID")
→ 정제된 마크다운 반환
```

### 쓰기
```
mcp__notion-cdp__write_to_notion_page(page_id="URL 또는 ID", markdown="# 제목\n내용...")
→ 블록 추가 완료 메시지
```

### 페이지 생성
```
mcp__notion-cdp__create_notion_page(parent_page_id="부모 ID", title="제목", content="마크다운")
→ 새 페이지 ID 반환
```

### 검색
```
mcp__notion-cdp__search_notion(query="검색어", limit=10)
→ 페이지 목록 반환
```

### 삭제
```
mcp__notion-cdp__delete_notion_blocks(page_id="ID", block_count=5)
→ 마지막 N개 블록 삭제 (0=전체)
```

### 하위 페이지 목록
```
mcp__notion-cdp__get_notion_page_list(page_id="부모 ID")
→ 하위 페이지 목록
```

## Supported Markdown

MCP 서버가 자동 변환하는 마크다운 문법:

| 마크다운 | Notion 블록 |
|----------|------------|
| `# 제목` | `header` |
| `## 제목` | `sub_header` |
| `### 제목` | `sub_sub_header` |
| `- 항목` / `* 항목` | `bulleted_list` |
| `1. 항목` | `numbered_list` |
| `> 인용` | `quote` |
| `` ``` 코드 ``` `` | `code` (언어 자동 감지) |
| `---` | `divider` |
| `**볼드**` | 리치 텍스트 bold |
| `*이탤릭*` | 리치 텍스트 italic |
| `` `인라인코드` `` | 리치 텍스트 code |
| `[텍스트](url)` | 리치 텍스트 link |
| 일반 텍스트 | `text` |

## Workflow Example

### 기존 페이지에 콘텐츠 추가

```
1. mcp__notion-cdp__search_notion(query="대상 페이지명")
2. mcp__notion-cdp__write_to_notion_page(page_id="찾은ID", markdown="# 새 섹션\n내용...")
```

### 새 페이지 생성

```
1. mcp__notion-cdp__search_notion(query="부모 페이지명")  # 부모 ID 확인
2. mcp__notion-cdp__create_notion_page(parent_page_id="부모ID", title="새 페이지", content="마크다운...")
```

### 페이지 읽기 → 수정

```
1. mcp__notion-cdp__read_notion_page(page_id="URL")  # 현재 내용 확인
2. mcp__notion-cdp__delete_notion_blocks(page_id="ID", block_count=3)  # 필요시 삭제
3. mcp__notion-cdp__write_to_notion_page(page_id="ID", markdown="수정된 내용")
```

## Important Rules

1. **MCP 우선**: 읽기/쓰기/검색은 항상 Notion MCP 도구 사용. TypeScript CDP 스크립트 생성 불필요.
2. **표 형식 우선**: 비교/매핑 데이터는 마크다운 테이블로 작성 → MCP가 네이티브 table 블록으로 자동 변환.
3. **CDP 직접 사용은 고급 UI 조작만**: 드래그, DB 뷰 변경 등 MCP 미지원 작업에 한정.
4. **page_id 형식 유연**: URL 전체, 32자 hex, UUID 모두 지원 (MCP가 자동 정규화).

## Fallback: Legacy TypeScript CDP

MCP 서버 장애 시에만 레거시 방식 사용:

- 레퍼런스: `src/create-notion-page.ts`, `src/create-openclaw-analysis-page.ts`
- 빌드: `cd /Users/sukeun/IdeaProjects/관리 && npx tsc`
- 실행: `node dist/create-{name}-page.js`
