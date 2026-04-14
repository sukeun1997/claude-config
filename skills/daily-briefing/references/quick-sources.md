# Quick Sources — 고정 소스 리스트

quick 모드에서 WebFetch로 병렬 스캔하는 소스.
소스 추가/삭제: 이 파일만 수정.

## AI 소스

### 1. Anthropic Blog
- **URL**: https://www.anthropic.com/news
- **추출**: 최신 3개 포스트의 제목, 요약(2-3줄), 날짜, URL
- **scope**: ai

### 2. Claude Code Releases
- **URL**: https://github.com/anthropics/claude-code/releases
- **추출**: 최신 1-2개 릴리스의 버전, 주요 변경사항, 날짜
- **scope**: ai

### 3. OpenAI Blog (Releasebot 경유)
- **URL**: https://releasebot.io/updates/openai
- **추출**: 최신 3개 업데이트 중 Codex/개발자 도구 관련 항목의 제목, 요약, 날짜, URL
- **scope**: ai
- **참고**: openai.com/news/ 직접 접근 시 403 → Releasebot 경유

### 4. Hacker News (Algolia API)
- **URL**: https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=30
- **추출**: JSON 응답의 `hits` 배열에서 각 항목의 `title`, `url`, `points`, `num_comments`, `created_at` 추출. **points ≥ 50** 항목만 유지. `points`와 `num_comments`를 `popularity` 필드로 전달.
- **scope**: ai
- **참고**: 기존 HN 프론트페이지 HTML 대신 Algolia API 사용 — 포인트/댓글 수를 정확히 파싱 가능

## 백엔드 소스

### 5. Spring Blog (Releasebot 경유)
- **URL**: https://releasebot.io/updates/spring
- **추출**: 최신 3개 릴리스/기능 업데이트의 제목, 요약, 날짜, URL
- **scope**: backend
- **참고**: spring.io/blog 직접 접근 시 JS 렌더링 필요하여 빈 페이지 → Releasebot 경유

### 6. Kotlin Blog
- **URL**: https://blog.jetbrains.com/kotlin/
- **추출**: 최신 2개 포스트의 제목, 요약, 날짜, URL
- **scope**: backend

### 7. Apache Kafka Blog
- **URL**: https://kafka.apache.org/blog
- **추출**: 최신 2개 포스트의 제목, 요약, 날짜, URL
- **scope**: backend

### 8. 토스 기술블로그
- **URL**: https://toss.tech
- **추출**: 최신 3개 포스트의 제목, 요약, 날짜, URL
- **scope**: backend

## 트렌딩 소스

### 9. GitHub Trending (Daily)
- **URL**: https://github.com/trending?since=daily
- **추출**: 상위 15개 저장소의 이름, 설명, 오늘 스타 수(`stars today`), 언어, URL 추출. **오늘 스타 ≥ 50** 항목만 유지. AI/개발도구/Kotlin/Spring/Kafka 관련 항목 우선. `stars_today`를 `popularity` 필드로 전달.
- **scope**: all
- **참고**: 공식 API 없음, HTML 파싱. `stars today` 숫자가 인기도 지표

### 10. Dev.to Top (24시간)
- **URL**: https://dev.to/api/articles?top=1&per_page=15
- **추출**: JSON 배열에서 `title`, `description`, `url`, `published_at`, `positive_reactions_count`, `comments_count` 추출. `positive_reactions_count ≥ 30` 항목만 유지. `positive_reactions_count`를 `popularity` 필드로 전달.
- **scope**: all

## 추출 결과 포맷

각 항목을 아래 구조로 정리:
- title: 포스트 제목
- summary: 2-3줄 요약
- url: 원본 링크
- date: 게시일 (YYYY-MM-DD 또는 상대 날짜)
- source: 소스명 (예: "Anthropic Blog")
- popularity: 인기도 지표 (선택) — HN points, GitHub stars today, Dev.to reactions 등. 없으면 null
