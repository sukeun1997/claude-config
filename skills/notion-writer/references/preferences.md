# Notion Page Preferences

## 표 형식
- 마크다운 테이블(`| col | col |`)은 항상 Notion 네이티브 `table` + `table_row` 블록으로 변환
- 비교표, 매핑표 등 데이터가 있는 콘텐츠는 표 형태로 구성

## 이미지 인라인 배치
- 시각자료는 부록이 아닌 해당 섹션 본문에 삽입 (글→이미지→설명 흐름)

## MCP 경로

### Anthropic Notion MCP (기본)
- 엔드포인트: `mcp.notion.com/mcp` (Notion 직접 호스팅, Anthropic 경유 아님)
- 도구: `notion-search`, `notion-fetch`, `notion-create-pages`, `notion-update-page`, `notion-create-database` 등
- 부분 업데이트: `replace_content_range` + `selection_with_ellipsis` (앞~10자...뒤~10자)
- 이미지 임베드: `![alt](url)` 마크다운 지원
- Notion 앱 실행 불필요

### CDP Notion MCP (폴백, 미사용)
- `notion-cdp`: Notion Electron 앱 CDP 포트 9222 WebSocket 직접 통신
- 현재 미설정 상태. 벤치마크 데이터 없이 속도 비교 불가
- 활성화 시 Notion 앱 항상 실행 필요 (운영 부담)

## 토큰 최적화 원칙

1. **Notion I/O는 서브에이전트에 위임** — 페이지 원시 데이터가 메인 컨텍스트를 오염시키지 않게
2. **Page ID 직접 사용** — `projects.json`에 캐시된 ID로 search 호출 생략
3. **배치 쓰기** — 여러 블록을 하나의 마크다운 문자열로 합쳐 1회 write
4. **append-only 시 read 생략** — 기존 내용에 추가만 할 때 fetch 불필요
