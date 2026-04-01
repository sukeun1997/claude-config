# Deep Queries — WebSearch 쿼리 템플릿

deep 모드에서 고정 소스 외 추가 리서치용.
{date}: 실행일 (YYYY-MM-DD), {year}: 실행 연도 (YYYY)

## AI 쿼리 (scope: ai)

1. `Claude Code update {date}`
2. `OpenAI Codex news {date}`
3. `AI developer tools news {year} this week`
4. `AI coding agent comparison {year}`

## 백엔드 쿼리 (scope: backend)

1. `Spring Boot Kotlin {year} trends`
2. `Kafka event driven architecture {year} best practices`
3. `토스 배민 카카오 기술블로그 인기글 {year}`
4. `Kotlin JDSL coroutine virtual thread {year}`

## 커뮤니티 쿼리 (Enrich 단계용)

HIGH 항목의 {topic}을 대입:
1. `site:news.ycombinator.com {topic}`
2. `site:reddit.com/r/kotlin {topic}`
3. `site:reddit.com/r/java {topic}`

## 사용 규칙

- scope=ai: AI 쿼리만 실행
- scope=backend: 백엔드 쿼리만 실행
- scope=all: 양쪽 모두
- 커뮤니티 쿼리: Phase 3 Enrich에서만 (HIGH 항목 대상)
- WebSearch 결과에서 핵심 소스 5-10개를 선별하여 WebFetch

## 에러 처리

- **WebSearch 0건**: 날짜 범위를 확대하여 1회 재시도 (예: `{date}` → `{year} this week` → `{year} this month`)
- 재시도에도 0건: 해당 쿼리 스킵, "⚠ {query} 결과 없음" 표시
- 전체 WebSearch 실패: 고정 소스 결과만으로 진행
