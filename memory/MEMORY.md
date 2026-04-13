# Core Memory

## 사용자 프로필
- 상세: [topics/user-profile.md](topics/user-profile.md)

## 작업 환경
- macOS, zsh, Claude Code CLI 사용
- GitHub: sukeun1997 (gh CLI 인증됨)
- Notion: MCP (notion-cdp + Anthropic Notion MCP) 연동
- Memory: 4계층 (Active: active/+sessions/, Hot: daily/, Always: MEMORY.md, Cold: topics/)

## 글로벌 설정 구조 (~/.claude/)
- `CLAUDE.md`: 글로벌 에이전트 운영 매뉴얼 (Core Rules + Profile + 9섹션)
- `hooks/`: 19개 — memory-lib, session-start/end, precompact, stop-guard, edit-tracker, session-digest, post-tool, promote-analyzer, active-context, governance-guard, skill-usage-tracker, observer-runner, pre-clear-handoff, memory-sync, instinct-evolve, memory-search, memory-system-portable, prisma-auto-generate, telegram-notify
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
- [L5 로드맵](topics/l5-roadmap.md) — 4.5→5.0 단계별 액션, 점수 이력

### Promoted 2026-03-31
- Haru 프로젝트 히스토리: [topics/haru-project-history.md](topics/haru-project-history.md)
- migrate-legacy-deposits.ts 금액 소스: R_Cost.Minus_Cost는 적용금액(부분), TBLBANK.Bkinput이 실제 입금액. R_Cost는 전체 거래 기록 테이블
- gstack Fix-First 패턴 + 크로스 리뷰: `/review` 스킬에 통합됨. 소규모(<100줄)에서는 --quick 권장
- Session Digest: /clear 시 JSONL 자동 파싱으로 이전 대화 복구. /new 으로 완전 초기화

### Promoted 2026-04-06
- settings base+local 분리 시 hooks 보호 패턴: frozen-keys + integrity guard

### Promoted 2026-04-09
- 스마트.exe Lazy Copy 메커니즘: R_Cost_Smart(원본) → R_Cost(조회 시 복사). 마이그레이션은 R_Cost_Smart 기준으로 해야 함

### Promoted 2026-04-10
- 하네스 4.5 유지 (Opus critic 검증: 오케스트레이션 4.7, 자기진화 4.2). 5.0 갭: evolved skill 미발동 + friction 은퇴 0건
- absorb 주 2회 제한 (화/금 배치). 적용률 41%→70% 목표. Phase 0 사전 필터링 추가
- Active Context Hygiene: SessionStart에서 stale(3일+변경0)/비대(7일+) context 자동 경고
