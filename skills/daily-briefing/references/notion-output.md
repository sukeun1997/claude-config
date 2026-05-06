# Notion Output — 출력 가이드

`--notion` 플래그 시 사용. Notion MCP(`mcp__plugin_Notion_notion__*`) 사용.

## 부모 페이지 찾기

1. `mcp__plugin_Notion_notion__notion-search(query="Tech Briefing")`
2. 결과 있으면: 해당 페이지를 부모로 사용
3. 결과 없으면:
   - 사용자에게 "Notion 어디에 저장할까요?" 질문 (1회만)
   - 선택 결과의 page_id를 이 파일 하단 `## 캐시` 섹션에 기록
   - 이후 실행부터 캐시된 ID 사용

## 페이지 생성

```
mcp__plugin_Notion_notion__notion-create-pages(
  parent={"page_id": "{parent_id}"},
  pages=[{
    "properties": {"title": "Tech Briefing — {date}"},
    "content": "{markdown_content}"
  }]
)
```

## 콘텐츠 포맷

- terminal 출력과 동일한 마크다운
- 비교표 → 마크다운 테이블 (Notion이 자동 변환)
- 이미지 없음 (텍스트 전용)

## 검증

```
mcp__plugin_Notion_notion__notion-fetch(id="{page_id}")
```

- 모든 섹션 렌더링 확인
- 표가 정상 변환되었는지 확인

## 에러 처리

- MCP 호출 실패 → "Notion 저장 실패. terminal 출력으로 대체합니다." 메시지

## 캐시

부모 페이지 ID (첫 실행 시 자동 기록):
- parent_page_id: (미설정)
