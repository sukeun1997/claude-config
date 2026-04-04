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
- `rules/typescript/`: TypeScript 프로젝트 규칙
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
- EventKit 연동: CalendarManager actor, iCloud 우선 + fallback, endDate=startDate(종일)
- 품질: @BatchSize N+1 해결, DateFormatter 중앙화, Color(hex:) 통합
- v379 repo: sukeun1997/v379, branch: main, 로컬: /Users/sukeun/379
- v379 서버 포트: 8584 (v373은 8484)
- 캘린더 CRUD: DayDetail 집중형, optimistic update, EKEventEditWrapper iOS only
- 브랜치 전략: 앞으로 모든 PR base = main (feat/phase1 은퇴)
- Phase 4 진행: P4-2(자연어 필터) + P4-4(타임블로킹) 완료, 워크트리 feat-phase4-p2-p4
- JaCoCo 커버리지 73% — P4-2/P4-4 테스트 추가 필요
- StoreKit 2 Freemium 모델: Free (리스트 3개, 기본 기능) / Pro ₩3,900/월 or ₩29,000/년
- 위젯 3종 구현: Small + Medium + LockScreen (WidgetKit)
- Pro 잠금 패턴: .proGated() ViewModifier + PaywallView
- harutodo.com 도메인 + HTTPS 활성화 완료
- 온보딩 5스텝 구현 완료
- GitHub Pages 법적 문서: https://sukeun1997.github.io/haru-legal/
- migrate-legacy-deposits.ts의 금액 소스: R_Cost.Minus_Cost는 적용금액(부분), R_Cost.R_Cost/TBLBANK.Bkinput이 실제 입금액. 향후 마이그레이션 시 TBLBANK 기준 사용 필수
- gstack의 Fix-First 패턴과 증거 기반 리뷰 규칙이 `/review` 스킬에 통합됨. 향후 리뷰 시 AUTO-FIX/ASK 분류 + Codex 크로스 리뷰 자동 실행.
- 크로스 리뷰 실전 테스트 완료. 대규모 변경에서 Codex Only 1건 발견 → 가치 확인. 소규모(<100줄)에서는 --quick 권장.
- 게임 프로젝트 "Empires in Your Pocket" 시작. Godot 4.6, 모바일 4X, Offset hex.
- Haru LGTM Phase 1 운영 중: Prometheus+Grafana, OCI 158.179.165.211
- Grafana 대시보드 import 시 ${DS_*} → datasource uid 문자열 교체 + __inputs 제거 필수
- LGTM 풀스택 옵저버빌리티 구축 완료 (Prometheus + Grafana + Loki + Alloy + Tempo)
- RitualScheduler — 하루 자동 시작/마감 스케줄러 구현
- Session Digest: /clear 시 JSONL 자동 파싱으로 이전 대화 복구. /new 으로 완전 초기화.
- 하네스 L4.5 (2026-04-01 Opus 평가). 병목: 자기 진화 4.0
- R_Cost 테이블은 입금 전용이 아닌 전체 거래 기록 테이블 — 재마이그레이션 시 주의
