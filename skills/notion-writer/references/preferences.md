# Notion Page Preferences

## 표 형식
- 마크다운 테이블(`| col | col |`)은 항상 Notion 네이티브 `table` + `table_row` 블록으로 변환
- 비교표, 매핑표 등 데이터가 있는 콘텐츠는 표 형태로 구성

## 이미지 인라인 배치
- 시각자료는 부록이 아닌 해당 섹션 본문에 삽입 (글→이미지→설명 흐름)

## MCP 듀얼 경로
- **Anthropic Notion MCP** (`mcp__claude_ai_Notion__*`): Notion 공식 연동, CDP 불필요
  - 도구: `notion-search`, `notion-fetch`, `notion-create-pages`, `notion-update-page`, `notion-create-database` 등
  - 부분 업데이트: `replace_content_range` + `selection_with_ellipsis` (앞~10자...뒤~10자)
  - 이미지 임베드: `![alt](url)` 마크다운 지원
  - Notion 앱 실행 불필요, 토큰 효율적
- **CDP Notion MCP** (`notion-cdp`): 기존 방식, Notion 앱 CDP 포트 9222 필요
- **선택 기준**: Anthropic MCP 우선 시도 → 실패 시 CDP 폴백
