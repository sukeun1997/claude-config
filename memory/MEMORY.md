# Core Memory

## 사용자 프로필
- 상세: [topics/user-profile.md](topics/user-profile.md)

## 작업 환경
- macOS, zsh, Claude Code CLI 사용
- GitHub: sukeun1997 (gh CLI 인증됨)
- Notion: MCP (notion-cdp + Anthropic Notion MCP) 연동
- Memory: 4계층 (Active: sessions/, Hot: daily/, Always: MEMORY.md, Cold: topics/)

## 글로벌 설정 구조 (~/.claude/)
- `CLAUDE.md`: 글로벌 에이전트 운영 매뉴얼 (Core Rules + Profile + 9섹션)
- `rules/typescript/`: TypeScript 프로젝트 규칙
- `hooks/`: memory-lib, memory-session-start, memory-session-end, memory-precompact-path, memory-stop-guard, edit-tracker, session-digest.py, telegram-notify, prisma-auto-generate
- `memory-search MCP`: ~/IdeaProjects/관리/memory-mcp-server (BM25+Vector 하이브리드)

## CLAUDE.md 구조 (2026-03-30 갱신)
1. Session Rules (세션 규율 + 컨텍스트 절약 + 메모리 + Active Context + Daily Log)
2. Task Routing & Delegation (직접 허용 + 판단 플로우 + Agent 위임 테이블)
3. Model Routing (haiku/sonnet/opus 티어)
4. Post-Implementation (리뷰 정책 + 빌드 검증 + 테스트 + 경계면 교차 검증)
5. Coding Standards (불변성, 파일/함수 크기 제한)
6. Git Workflow (커밋 형식 + PR 규칙)
7. Security (민감 파일 + 비밀값 + 의존성)
8. Parallel Execution (병렬/순차 규칙 + 팀 패턴)
9. Auto Skill Routing (파일/언어 + 워크플로우 트리거)

## 원격 레포 동기화
- 글로벌 설정 레포: `sukeun1997/claude-config` (GitHub, public)
- 로컬 ~/.claude: git 초기화됨

## 주요 결정 이력
- [결정 이력](topics/absorbed-articles.md) — absorb 적용 기록
- [삽질 패턴](topics/failure-log.md) — 원인 분류 + 해법
- [평가 교정](topics/evaluation-calibration-pattern.md) — 리뷰어 평가 기준
