# Core Memory

## 사용자 프로필
- 상세: [topics/user-profile.md](topics/user-profile.md)

## 작업 환경
- macOS, zsh, Claude Code CLI 사용
- GitHub: sukeun1997 (gh CLI 인증됨)
- Notion: MCP (`plugin:Notion:notion`, 도구 프리픽스 `mcp__plugin_Notion_notion__*`) 연동
- Memory: 4계층 (Active: active/+sessions/, Hot: daily/, Always: MEMORY.md, Cold: topics/)

## 글로벌 설정 구조 (~/.claude/)
- `CLAUDE.md`: 글로벌 에이전트 운영 매뉴얼 (Core Rules + Profile + 9섹션)
- `hooks/`: 20개 — memory-lib, session-start/end, precompact, stop-guard, edit-tracker, read-edit-gate, session-digest, post-tool, promote-analyzer, active-context, governance-guard, skill-usage-tracker, observer-runner, pre-clear-handoff, memory-sync, instinct-evolve, memory-search, memory-system-portable, prisma-auto-generate, telegram-notify
- `scripts/`: failure-log-classify (self-healing 분류), sync-settings, deploy 등
- `memory-search MCP`: ~/IdeaProjects/관리/memory-mcp-server (BM25+Vector 하이브리드)

## CLAUDE.md 구조 (2026-03-30 갱신)
1. Session Rules  2. Task Routing & Delegation  3. Model Routing  4. Post-Implementation
5. Coding Standards  6. Git Workflow  7. Security  8. Parallel Execution  9. Auto Skill Routing

## 원격 레포 동기화
- 글로벌 설정 레포: `sukeun1997/claude-config` (GitHub, public)
- 로컬 ~/.claude: git 초기화됨

## 주요 결정 이력
- [결정 이력](topics/absorbed-articles.md) — absorb 적용 기록
- [삽질 패턴](topics/failure-log.md) — 원인 분류 + 해법
- [평가 교정](topics/evaluation-calibration-pattern.md) — 리뷰어 평가 기준
- [L5 로드맵](topics/l5-roadmap.md) — 4.5→5.0 단계별 액션, 점수 이력
- [Promoted 인사이트 아카이브](topics/promoted-insights-archive.md) — 프로젝트별/CSS/Prisma/배포 상세 (2026-03~04, 온디맨드)

## Promoted 인사이트 (메타/프로세스 — Always)
> 프로젝트별 상세는 위 아카이브. 여기엔 하네스/프로세스 교훈만 유지.

- **(04-06)** settings base+local 분리 시 hooks 보호: frozen-keys + integrity guard
- **(04-10)** 하네스 4.5 유지 (Opus critic: 오케스트레이션 4.7, 자기진화 4.2). 5.0 갭: evolved skill 미발동 + friction 은퇴 0건 / absorb 주 2회(화·금) 배치 / Active Context Hygiene 자동 경고(stale 3일+변경0, 비대 7일+)
- **(04-18)** failure-log 적체 게이트 = 주간 리뷰 첫 관문 (15건+ 쌓이면 KPI 분석 무의미). 분류는 Harness/Context/Prompt 3계층, 모델명·추정 레이블 금지 / W16 1위 원인 = 파일 Read 선행 미흡(Context)
- **(04-24)** 2단 critic(내부+독립+적용가치 재검증)이 단계별로 다른 false positive를 거름. "버그인지"와 "적용 가치 있는지"는 다른 축 / 리뷰어는 라인번호+근거 필수 + critic Read 검증 없으면 오독 통과 (단일 리뷰 layer 부족)
- **(04-26)** TestFlight 새 빌드 실패 최빈 원인 = CFBundleVersion 동일 (project.yml 정적 빌드번호 금지) / 클라 에러 LGTM 수집 = SLF4J logger.warn 한 줄 → docker stdout → Alloy 자동 수집
- **(05-16)** deprecated 정리 PR은 fallback 동작 dry-run 검증 후 머지 (silent regression 방지) / "성숙도" 척도(8축 vs L1-L5) 명시 — 같은 단어로 다른 측정값 혼용 금지
- **(05-19)** 새 라우트 안 잡힐 때: ① grep 라우트 존재 → ② lsof 서버 PID+uptime → ③ stale이면 SIGTERM+재시작 (tsx watch stale 코드 주의)
- **(05-23)** Read-before-Edit를 PreToolUse 차단 훅으로 승격 (경고@2 → 차단@3, 소스 파일+Edit 한정). failure-log 자동 분류(self-healing)를 observer-runner 조기 배치 — friction 룰의 코드 enforcement 전환 첫 사례


### Promoted 2026-05-25
### Promoted 2026-05-25
- friction 룰 60회 방지실패 → 코드 enforcement 승격 패턴: 프롬프트 룰이 N회 재등장하면 (a)강도상향 (b)훅 자동화 (c)은퇴 중 택1. read-edit-gate가 (b) 첫 사례
- friction 룰 60회 방지실패 → 코드 enforcement 승격 패턴: 프롬프트 룰이 N회 재등장하면 (a)강도상향 (b)훅 자동화 (c)은퇴 중 택1. read-edit-gate가 (b) 첫 사례
- 패턴: "KPI 카드 = 섹션과 별개". 공과금처럼 같은 도메인이 (a) 다운로드 섹션 (b) KPI 카드 두 곳에 분산될 수 있음. "X 숨겨줘" 요청 시 grep으로 모든 노출 지점 확인 필요
- 패턴: "KPI 카드 = 섹션과 별개". 공과금처럼 같은 도메인이 (a) 다운로드 섹션 (b) KPI 카드 두 곳에 분산될 수 있음. "X 숨겨줘" 요청 시 grep으로 모든 노출 지점 확인 필요

### Promoted 2026-07-11
- JPA N+1(@BatchSize/@EntityGraph), DB 인덱스, Redis 캐시, iOS @Observable 구조는 이미 최적화 완료 상태 — 재분석 불필요

### Promoted 2026-07-11
- worktree 병렬 패턴: 백엔드 main 수정 + 테스트 작성을 동시 진행할 때 "public 시그니처 유지 계약 + 테스트 레인 worktree 격리 + 완료 후 파일 복사·통합 재검증"이 잘 작동함

### Promoted 2026-07-11
- 투자자 겹침 비율이 높으면 목적계좌 직렬화 때문에 6100 c=2 이득 급감 — Phase 3 go/no-go 핵심 입력

### Promoted 2026-07-11
- 6100 동시성 재개 시 전용 controller보다 006000 계좌 lane 모델 통합 우선 (busy_accounts에 6100 계좌 집합 포함) — 단 계좌 lock은 중복 이체를 못 막으므로 durable claim은 여전히 선행
- 보안: .mcp.json memory-search에 GEMINI_API_KEY 평문 노출 발견 — ${ENV_VAR} 참조로 전환 필요 (사용자 조치 대기)

### Promoted 2026-07-12
- review-week 수동 트리거 의존이 구조적 약점 — 리마인더 자동화 필요
