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

### 4. Hacker News
- **URL**: https://news.ycombinator.com/
- **추출**: 상위 30개 타이틀 전체 (제목 + 포인트 + URL). AI/개발도구 필터링은 Phase 2에서 처리.
- **scope**: ai

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

## 추출 결과 포맷

각 항목을 아래 구조로 정리:
- title: 포스트 제목
- summary: 2-3줄 요약
- url: 원본 링크
- date: 게시일 (YYYY-MM-DD 또는 상대 날짜)
- source: 소스명 (예: "Anthropic Blog")
