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
- `hooks/`: 활성 21개 (2026-07-12 기준, 정확 목록은 `ls hooks/`) — 메모리 계열(memory-lib, session-start/end, precompact, stop-guard, post-tool, active-context, search, system-portable, pre-clear-handoff), 가드 계열(agent-model-guard, read-edit-gate, governance-guard, settings-integrity-guard), 관측 계열(session-digest, observer-runner/analyzer, subagent-result-tracker, failure-log-instinct-boost), 기타(instinct-evolve, prisma-auto-generate). 은퇴 훅은 `hooks/deprecated/`
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
- [haru 프로젝트 이력](topics/haru-project-history.md) — haru 앱/인프라 결정 이력
- [토큰 효율](topics/token-efficiency.md) — 컨텍스트 절약 패턴 상세
- [학습 계획 2026-05](topics/learning-plan-2026-05.md) — 백엔드 학습 로드맵

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
- friction 룰 60회 방지실패 → 코드 enforcement 승격 패턴: 프롬프트 룰이 N회 재등장하면 (a)강도상향 (b)훅 자동화 (c)은퇴 중 택1. read-edit-gate가 (b) 첫 사례
- 패턴: "KPI 카드 = 섹션과 별개". 공과금처럼 같은 도메인이 (a) 다운로드 섹션 (b) KPI 카드 두 곳에 분산될 수 있음. "X 숨겨줘" 요청 시 grep으로 모든 노출 지점 확인 필요

### Promoted 2026-07-11
- JPA N+1(@BatchSize/@EntityGraph), DB 인덱스, Redis 캐시, iOS @Observable 구조는 이미 최적화 완료 상태 — 재분석 불필요

### Promoted 2026-07-11
- worktree 병렬 패턴: 백엔드 main 수정 + 테스트 작성을 동시 진행할 때 "public 시그니처 유지 계약 + 테스트 레인 worktree 격리 + 완료 후 파일 복사·통합 재검증"이 잘 작동함

### Promoted 2026-07-11
- 투자자 겹침 비율이 높으면 목적계좌 직렬화 때문에 6100 c=2 이득 급감 — Phase 3 go/no-go 핵심 입력

### Promoted 2026-07-11
- 6100 동시성 재개 시 전용 controller보다 006000 계좌 lane 모델 통합 우선 (busy_accounts에 6100 계좌 집합 포함) — 단 계좌 lock은 중복 이체를 못 막으므로 durable claim은 여전히 선행
- 보안: .mcp.json memory-search GEMINI_API_KEY 평문 노출 → ~/.zshrc export + ${GEMINI_API_KEY} 참조로 이관 완료 (2026-07-12). .mcp.json에는 항상 ${ENV_VAR} 참조만

### Promoted 2026-07-12
- review-week 수동 트리거 의존이 구조적 약점 — 리마인더 자동화 필요

### Promoted 2026-07-12
- macOS에서 `find /tmp -maxdepth 1`은 무동작 — /tmp이 symlink라 하강 안 함, trailing slash(`find /tmp/`) 필수

### Promoted 2026-04-14
- **executor 안전 게이트 위반 패턴**: 안전 체크("BLOCKED 보고") 지시를 명시했어도 executor가 "어떻게든 진행할 수 있는 경로"를 찾으면 우회. 운영 DB 같은 critical 경로는 명시 차단(예: `git checkout -b temp; pnpm prisma migrate dev || exit 1`)이나 executor에 미리 cd로 다른 .env 확인하게 하기, 또는 메인 세션이 사전 .env 확인 후 위임
- **subagent-driven 17 Task 동시 실행 효율**: 병렬 가능한 phase(D 3개, E 1차 3개)에서 Agent 병렬 dispatch로 시간 단축. git index.lock 충돌은 1회도 발생하지 않음 — 실제 commit timing이 분산되어 실용적으로 안전
- **자동 발송 차단 3중 게이트**: testMode 플래그 + isSendingAllowed 게이트키퍼 + 명시 버튼 클릭 트리거(5초 카운트다운). 재발송도 동일 패턴 유지 (useEffect로 자동 호출되지만 사용자가 [재발송] 버튼을 누른 후 카운트다운 끝나야 발동, 그 사이 [취소] 가능). 코드-리뷰 중 안전성 PASS 확인

### Promoted 2026-04-14
- **폴링 주기 최적화 1원칙**: 병목이 "내 폴링 빈도"인지 "upstream 결과 생성 속도"인지 먼저 구분. upstream이 병목이면 간격 줄여도 체감 이득 없고 API 과부하만 증가. adaptive backoff(초반 길게 → 후반 짧게)가 고정 간격보다 체감 빠른 경우 많음

### Promoted 2026-04-15
- **운영 가드 vs 운영 시나리오 정합성**: 초창기 안전장치(분당 15건)가 이후 추가된 운영 시나리오(은행별 300건+ 일괄 발송)와 충돌. "안전장치는 시나리오 변경 시 재검토" 체크리스트 필요
- **에러 메시지 분류 일관성**: rate limit / 한도 초과 / 비즈니스 검증 실패는 BusinessError로 통일해야 프로덕션 errorHandler에서 메시지가 살아남음. 일반 Error는 진짜 예외에만

### Promoted 2026-04-15
- **운영자 친화 에러 패턴**: (1) 사용자에게 메시지 그대로 노출 + (2) 시크릿 마스킹 + (3) 짧은 trace ID 부착 + (4) 서버 로그 stack 보존 — 4가지가 함께 가야 운영 디버깅이 자기친화적. ID는 사용자(어머니/지원담당자) ↔ 개발자 사이의 공통 언어

### Promoted 2026-04-15
- **외부 API 결과 코드 매핑은 추정 금지**: 공식 문서 fetch 후 검증. 자체 추정 매핑은 시간이 지나며 사용자 신뢰 훼손. 출처 URL을 코드 주석에 박아두면 검증 가능성 상승
- **테스트가 잘못된 가정을 굳히는 위험**: `400=전원꺼짐 검증` 같은 테스트가 있으면 매핑 오류를 발견하기 어려워짐. 외부 API 의미는 "공식 문서 링크가 살아있는지" 정도만 검증하고 의미 자체를 fixture화하지 않는 게 안전

### Promoted 2026-04-15
- **배포 타이밍 안전 룰**: 사용자 활성 시간(특히 SMS/장기 요청 진행 중)을 피해 배포. PM2 cluster reload는 graceful이지만 진행 중 HTTP request의 connection 끊김 윈도우가 존재. nginx upstream 없이 직접 노출 구조에서 502로 보일 수 있음
- **외부 시스템 미응답 ≠ 우리 버그**: SMS/메일/외부 API 결과 추적 시 "응답 안 옴" 케이스를 코드에서 명시 처리해야 함. "확인 중" 같은 진행형 표시가 영원히 남으면 사용자가 시스템 고장으로 오해
- **AI 비서 도구의 화이트리스트 패턴**: AI가 임의 ID로 `bulk_update_phones` 호출해도 미리보기 단계 matched에 있는 ID만 update 허용. 동명이인은 `selected_from_duplicates` 별도 인자로 명시 선택 — 안전 분리. importId 5분 TTL로 미리보기 위조 차단

### Promoted 2026-04-15
- **자동 생성 시스템의 시간 경계 검증**: "매월 자동 생성" 같은 cron 작업은 대상 entity의 라이프사이클(시작/종료 날짜)을 항상 체크해야 함. 이번 케이스는 `tenant.contractStart`가 모델에 있지만 자동 생성 로직이 그걸 무시. 자동 생성 코드 작성 시 "대상이 그 시점에 활성 상태인가?"를 첫 필터로

### Promoted 2026-04-16
- **토큰 전체 일치 정규식의 실제 데이터 함정**: 주소 같은 사용자 입력은 이상적 패턴(공백 구분) 안 따름. `^([가-힣]{1,6}(?:동))$` → "구천동47-2" 매칭 실패. lookahead(`(?=[\d\-호]|$)`) 기반 prefix 매칭으로 해결. dry-run 백필이 기본 디버거
- **분류 필드 자동화 3종 세트**: nullable DB 필드 + 자동 추출 수단 없음 → 죽은 기능. 해결 = (1) 서비스단 자동 추출 (2) UI 선택적 오버라이드 (3) backfill 스크립트 한 커밋에

### Promoted 2026-04-18
- failure-log 적체 게이트는 **주간 리뷰 첫 관문**으로 유지 — 15건 쌓이면 KPI 분석 의미 없음. 자체 분류 기준을 Harness/Context/Prompt 3계층으로 일관화 (모델명·추정 레이블 금지)
- **주간 15건 분류 결과 (W16 분포)**: Context 9 / Prompt 3 / Harness 3 / Meta 2. **1위 원인 = "파일 Read 선행 미흡"(Context 9건)**. 단일 파일 5회+ 반복 시 파일 전체 Read 의무화. Prompt 3건은 모두 스코프 경계 모호(6회·9회·13회) → `/feature` brainstorming 게이트 미적용
- **SessionEnd 훅 관측 갭 (진단 중)**: `sessions.jsonl` 4/16~17 누락. 훅 코드·settings 등록 정상, 수동 실행 정상. `async: true` 종료 경합 또는 특정 종료 경로에서 미트리거 추정 — debugger 에이전트 별도 세션 위임 예정

### Promoted 2026-04-18
- **주간 리뷰 후 즉시 적용 패턴**: 리뷰 결과 → opus critic 검증 → REVISE 수용 → 작은 것부터 병렬 실행. critic이 실제 파일 확인으로 범위 좁혀줌 ("4개가 아니라 5개", "경로는 metrics/sessions.jsonl")

### Promoted 2026-04-18
- CSS specificity 계산법: inline > class×n > (class + pseudo) > element. `:nth-child`는 pseudo-class로 0,0,1,0 추가. 같은 class를 두 번 쓰면 specificity bump 가능 (hack인 듯 hack 아닌)

### Promoted 2026-04-19
- Playwright MCP 네트워크 인터셉트로 로컬 API 없이도 UI 시각 검증 가능 — `page.context().route('**/api/public/listing/**', route => route.fulfill({...mock}))` 패턴. Express dev 서버가 JWT_SECRET 누락으로 안 뜰 때 유용
- 순환 import 방지 패턴: 두 컴포넌트(A가 B를 import)가 공통 유틸을 필요로 할 때 → 유틸을 별도 파일로 분리. 처음엔 VacantListingV2.tsx에서 export했다가 MobileListingV2에서 import 시도 → circular risk 감지하고 smart-summary.tsx로 리팩토

### Promoted 2026-04-19
- 디자인 핸드오프 번들 디코딩 패턴: Anthropic Design API의 `webfetch-*.bin`은 gzip+tar → `gunzip payload.gz && tar -xf payload -C extracted` 2단계로 풀림. chat transcript(`untitled/chats/chat1.md`)에 사용자 의도 흐름이 담겨 있어 반드시 먼저 읽을 것. README의 "선택 구현" 표시가 실제로 사용자가 원한 범위와 엇갈릴 수 있어 확인 필수
- CSS 프리픽스 격리 패턴: 기존 컴포넌트(V2)와 공존하는 새 variant는 전용 프리픽스(`lt-v3-*`)로 CSS 스코프를 잘라내는 것이 가장 단순. CSS 변수(`--mono`, `--orange`)는 `.lt-v3-root` 안에 가두면 V2의 동명 변수와 충돌 없음

### Promoted 2026-04-19
- CSS 변수 런타임 주입 패턴(B안): 컴포넌트에 props를 줄줄이 내려꽂지 않고, 루트 DOM에 inline style로 `--token-name: value` 를 쏟아넣으면 자식 CSS가 `var(--token-name, fallback)`로 받음. 프리픽스(`.lt-v2-*` vs `.lt-v3-*`)로 스코프 격리돼 있으면 두 variant의 토큰 세트를 다르게 유지 가능. 단점은 CSS 하드코딩 → 변수 치환 1회성 작업 필요. 장점은 V1/V2/V3처럼 variant가 늘어나도 props drill 없이 루트 한 곳에서만 토큰 주입
- html-to-image 캡처 안 잘리게: 부모 컨테이너에 `overflow: hidden` + 반응형 레이아웃 있으면 좁은 뷰포트 상태가 그대로 캡처됨. 해결: 캡처 동안만 (1) 캡처 대상 `width`/`maxWidth` 강제, (2) 부모의 `overflow: visible`로 풀기, (3) 부모 `minWidth`를 타겟 폭 + padding만큼 확장, (4) `void el.offsetWidth`로 리플로우, (5) 캡처 후 모든 스타일 원복. V2는 `overflow: hidden`이 없어서 width만 바꿔도 됐지만 V3는 부모 overflow까지 풀어야 함

### Promoted 2026-04-19
- variant별 독립 토큰 원칙: V2(다크 배경)와 V3(라이트 배경)처럼 배경 톤이 반대되는 variant는 "공통" 토큰(색/배경)을 공유하지 말 것. 흰색 텍스트가 V2에선 완벽하지만 V3에서 투명처럼 보임. 기본값이 다른 variant는 처음부터 토큰을 분리하고, 필요하면 "프리셋 복사" UI로 옮기도록 설계. 이번처럼 먼저 공유했다가 분리하는 리팩토도 괜찮지만 DB 마이그레이션 필요 없는 것만 장점

### Promoted 2026-04-19
- WYSIWYG RichTextEditor 매칭/렌더 분리 패턴: 공통조건 dedup처럼 "텍스트 매칭 후 원본 HTML 보존"이 필요할 때 → (1) DOMParser로 블록 단위 HTML 조각 배열 생성, (2) 매칭은 각 조각의 textContent 정규화로 수행, (3) 반환/렌더는 원본 HTML 조각 그대로 + DOMPurify sanitize. 결과: 에디터 색/굵기 살아남으면서 dedup 동작
- `scrollWidth` 함정: 부모가 `overflow: visible`이면 자식 overflow를 scrollWidth가 잡지 못함. 캡처/측정에서 정확한 자연 폭이 필요할 땐 모든 자식 `getBoundingClientRect().right` 최대값 순회. 1회성 이벤트(캡처)라면 DOM 순회 overhead 허용

### Promoted 2026-04-19
- 모바일 fallback → variant별 분리 패턴: `isMobile` 분기에서 variant 대응 모바일 컴포넌트를 아예 분리하는 것이 (V2 모바일 재사용 + CSS variable 덮어쓰기)보다 깔끔. V3 모바일은 토큰은 공유하되(root에 CSS var 주입), DOM 구조/프리픽스는 완전 독립 — V2 모바일 CSS 충돌 위험 제로

### Promoted 2026-04-19
- Cloudflare Tunnel + `trust proxy 1` 환경의 `requireLocal` 올바른 구현: `req.socket.remoteAddress` 단독 검증은 역효과 — cloudflared가 loopback으로 express에 접속하므로 모든 터널 트래픽이 127.0.0.1로 보임. 정답은 `req.ip`(XFF 기반) AND `req.socket.remoteAddress` 둘 다 127.0.0.1일 때만 통과. 터널 트래픽: socket=127.0.0.1 ✓ / ip=실제클라이언트IP ✗ → 차단. 로컬 직접 접속: 둘 다 127.0.0.1 → 통과. XFF 스푸핑: socket=공격자IP ✗ → 차단
- `dangerouslySetInnerHTML` 감사 패턴: 공개 페이지에 DOMPurify 적용해도 **관리자 내부 페이지가 누락**되면 XSS → 세션 탈취 → 전체 앱 장악 경로 그대로 열려 있음. `grep -n dangerouslySetInnerHTML` 로 전수 검사 후 sanitize 없는 곳 모두 보완해야 함. 입력 신뢰도(공개 vs 관리자)와 무관하게 sanitize 기본 적용

### Promoted 2026-04-20
- `@ts-expect-error + tsconfig.test.json` 패턴: "이 필드가 공개 타입에 있으면 빌드 깨진다"는 계약을 컴파일 타임에 강제. 재노출 회귀 방지. `typecheck` 스크립트를 `tsc && tsc -p tsconfig.test.json`로 확장해 CI에 자동 편입.
- `buildListingData`를 공용으로 유지하고 **반환 시점 spread destructuring**(`{ tenantId: _tid, ...unit }`)으로 strip하는 패턴이, "공개/어드민 경로 분기 함수 2개로 쪼개기"보다 변경량이 작고 단일 소스 유지. 단점은 공개 DTO 타입 명시성이 약함(`as` 단언 필요) — 명시적 DTO 타입 분리는 후속 리팩터 후보.
- V2 레거시 격리 전략 변화: 처음엔 "V2 types.ts 수정 금지"로 두려 했으나 `smart-summary.tsx`(V2/V3 공유 유틸)가 `@/types`로 전환되면서 V2 Building에 `ownerName` 누락이 structural subtyping 에러로 드러남. 결국 V2 types.ts에도 `ownerName: string | null` + `type: string | null` 최소 보정. "격리"보다 "공용 유틸 → 공용 타입 일원화"가 우선순위가 높았던 사례.

### Promoted 2026-04-20
- "카톡 단톡방에 자동 발송" 요구 시 현실: 공식 API 없음. 봇폰(auto.js), computer-use cron, Automate는 모두 UI 변경·잠금·재부팅으로 주기적 깨짐 + 오픈채팅방 오발송 리스크. **"1명이 하루 30초 작업"으로 안정성 > 완전 자동**이 실용 정답. 텔레그램 봇 공식 API가 진짜 솔루션이지만 가족 설득 필요
- 업로드 파이프라인 패턴: 상대방 폰에 커스텀 코드/flow 박지 말고, **공식 동기화 앱 + 서버 pull** 구조가 안정적. Autosync (Google Drive 전용) → 서버 Drive API cron 5분. 지연 5~10분이지만 "준실시간" 체감 충분. Service Account 쓰면 OAuth 재인증 없이 영구 동작

### Promoted 2026-04-21
- Anthropic 공식 frontend-design 스킬은 짧다(200줄 미만). 단일 SKILL.md + lazy-load reference 구조 — 스킬 설계 시 메인은 얇게 유지하고 상세는 references/로 분리가 정답

### Promoted 2026-04-21
- 하네스 패턴: 어제 도입한 `@ts-expect-error + tsconfig.test.json` 계약 테스트가 이번에 반대 방향(복원)으로도 **의도된 변경임을 명시**하는 용도로 재활용됨. @ts-expect-error를 허용 주석으로 교체하고 필드를 타입에 추가 → 운영 정책 변경이 타입 계약 + 테스트에 동기화. "금지 계약"이 "정책 문서"로도 기능

### Promoted 2026-04-21
- 사용자 증상 보고 + 내 해석의 2-pass 조정: 1차에 "연락처 없는 호실은 그대로 '-'로"라고 했지만, 실제로는 "관리자에 연락처가 있는 호실(= 퇴거예정 세입자 포함)이 매물장에 안 보이는 것이 불만"이었음. 사용자 자연어는 축약되므로 스크린샷으로 실제 데이터 비교 시 **표현과 의도 간극** 재확인 필요. 증상 스크린샷은 의도 스크린샷보다 훨씬 구체적

### Promoted 2026-04-24
- **2단 critic 평가의 가치**: aggregator 내부 critic(Phase 1) + 독립 critic 1차(Phase 2) + 적용가치 재검증 critic(Phase 2 재검증) 3단 구조에서 각 단계가 추가 false positive를 걸러냄. 특히 "적용할 가치 있는지" 프롬프트는 "버그인지"와 다른 축 — 이론적 버그 vs 실사용 영향을 분리 평가하는 프롬프트 설계가 filler 수정 방지에 유효
- **리뷰어 코드 오독 패턴**: reviewer 4명 중 3명이 CSS 1635 라인을 잘못 지목, address null을 타입 무시하고 경고, regions null 플래시를 early-return 없이 가정. critic이 실제 Read로 잡음 → **"리뷰어는 라인 번호 + 근거 필수"** 규칙이 유효하나 critic Read 검증 단계가 없으면 통과. 생산-검증 분리가 단일 리뷰 layer만으로 부족함을 시사

### Promoted 2026-04-26
- TestFlight 새 빌드 못 올라가는 가장 흔한 원인: CFBundleVersion 동일. xcodegen project.yml에 정적 빌드 번호 두지 말 것.
- 클라이언트 에러를 LGTM에 흘리는 가장 단순한 패턴: SLF4J logger.warn(...) 한 줄. docker stdout → Alloy/Promtail이 자동 수집. 별도 HTTP push 코드 불필요.

### Promoted 2026-05-16
- **deprecated 정리 PR은 fallback 동작을 dry-run으로 검증 후 머지** — 1eb6523(4/12) 같은 silent regression 재발 방지
- **평가 척도 일관성**: "성숙도" 단어 사용 시 척도(8축/L1-L5) 명시 — 같은 단어로 다른 측정값 혼용 금지

### Promoted 2026-05-19
- 삽질: `tsx watch`가 백그라운드에서 stale 코드로 돌고 있어 첫 UI 삭제 시도가 404 → 서버 재시작으로 해결. 검증 전 서버 PID 확인 또는 명시적 reload 필요
- 패턴: 새 라우트가 안 잡힐 때 → ① 파일 grep으로 라우트 존재 확인 → ② lsof로 서버 PID + uptime 확인 → ③ stale이면 SIGTERM + 재시작

### Promoted 2026-06-23
- 다음 주 액션: ①66건 backlog batch 분류 ②동일파일 3회 Edit PreToolUse 경고 승격 ③SessionEnd stale active 자동 archive
- **대형 PR 분할 전략**: "diff 크다" 호소 시 prod/test 라인 분포부터 확인. 테스트가 주범이면 도메인 분리(scaffolding)만으론 체감 안 줄어듦 → 관심사별 stacked PR로 테스트 덩어리까지 분리. 파일seam 깨끗하면 checkout-by-file + 각 단계 컴파일검증 + 최종 트리동일성 검증이 안전.

### Promoted 2026-06-24
- **stacked PR rebase 함정**: base를 amend(SHA 변경)한 뒤 calc에서 plain `git rebase base` 하면 merge-base가 develop으로 바뀌어 원본 base 커밋까지 재생→이미 제거한 변경(raw)이 도로 살아남. 반드시 `git rebase --onto <new-base> <old-base-sha>`로 old-base 이후 커밋만 재생. force-with-lease로 calc/orch 순차 갱신.

### Promoted 2026-06-24
- **Avro 빌드 검증 환경 제약**: 이 환경은 fetchAvroFromSR(Schema Registry) 접근 불가. -PskipFetchAvro 시 common:kafka가 corebanking Avro 클래스(InvoiceCreated/LoanExecuted/EventEnvelope 등) 미생성 → repayment의 glue 파일(InvoiceCreatedGluePublisher/AvroMapper/LoanCreationConsumer 등, **Step2 무관**) compile 실패. 우회: 메인 repo의 `common/kafka/build`(컴파일 산출물+jar) 통째 복사 후 -PskipFetchAvro.

### Promoted 2026-06-25
- **stacked PR develop 재정착 레시피**: 토대 브랜치가 재분할 머지된 경우, 원본 서브브랜치들을 순차 rebase --onto로 develop 위 재구성하면 단계 경계·통계 보존. 단일커밋 단계의 마이그 버전상향은 git mv + --amend로 히스토리 클린. 최종 트리를 기검증 브랜치와 diff해 동일성 확인하면 재검증 불필요.

### Promoted 2026-07-07
- FEP 교훈: "TCP send() 성공 ≠ 전달". 전달 증거는 응답 전문(RECV_TIME)뿐. 실패를 '미발송 확실' 구간으로 몰아 자연 재시도시키는 설계가 재시도 큐보다 단순

### Promoted 2026-07-07
- 교훈(FEP 재현): **로컬/DB 상태로는 전달 여부를 증명 못 한다. auto-resend는 재시도 로직이 아니라 "발송 경계의 멱등성"으로만 안전해진다.** 멱등 확보 전엔 at-most-once(감지+알림)가 기본값. 환경 함정: JAVA_HOME 미설정 시 JDK21로 잡혀 빌드 실패 → 이 repo는 Corretto 17 필요.

### Promoted 2026-07-08
- 야간 인덱스 대기 3개(DBSAFER): repayment_depositable(date), repayment_settleable(repayment_completed_datetime), repayment_settleable(post_settlement_completed_datetime). settlement_schedule 인덱스는 rs-driven 구조로 불필요해짐.
- **설계 영향 발견**: 최다 집중 계좌 396건/10분 → 계좌 내 직렬 유지 시 그 계좌만 ~6.6분 = **계좌 병렬화만으로 max<60초 목표 수학적 불가**. 집중 계좌 대책(계좌 내 처리 개선·전북 동시전송 협의)을 P2 범위에 명시. 덱 P2 2/5 bullet + 4/5 "정직한 하한"으로 반영.

### Promoted 2026-07-09
- 대형 단일 HTML 산출물(3MB+)은 Edit 직접 수정 금지 — 백업본 + 빌드 스크립트(scratchpad/build_deck_v2.py, BAK에서 read→재조립)로 idempotent 빌드. 7/8 13~18회 Edit 스파이럴의 해법으로 검증됨(이번 재구성 스크립트 3회 실행으로 종료). failure-log 해당 엔트리 Harness(확정) 분류 완료.

### Promoted 2026-07-10
- repayment_depositable은 "오늘 갚을 수 있는 모든 대출(연체 포함 매일 재등장)" — 유입 예측 소스로 쓰면 상한선만 나옴. 예측하려면 from_plan_date로 당일 약정분 분리 + 최근 28일 자기보정 이행률 필요

### Promoted 2026-07-10
- Grafana MySQL 타임존 규칙: $__timeFilter/$__timeGroupAlias 경유는 epoch 변환으로 정확하지만, raw datetime 컬럼을 직접 SELECT하면 UTC로 해석돼 +9h 표시됨. 해법 = 표시용은 DATE_FORMAT 문자열, time축은 UNIX_TIMESTAMP() epoch

### Promoted 2026-07-13
- fep.JB_SEND 금액: 전용 컬럼 없음, MSG_SEND(LONGBLOB) 고정폭 파싱 — 공통부 164B(messagerule.py HEADER REQ: 5+3+3+3+4+6+10+8+8+10+4+100), 006000 이체금액 = SUBSTRING(MSG_SEND,224,13) (업무부 offset 59), 006100 총이체금액 = SUBSTRING(MSG_SEND,187,13). optional 헤더 3필드 생략 시 헤더 50B → 006000 금액 위치 110 (검증 쿼리로 판별)

### Promoted 2026-07-12
- Codex 위임 시 가시성 필요하면 codex-bridge(tmux) 대신 orca CLI 경로 사용: terminal create → task-create → dispatch --inject → terminal wait/read. 완료 감지는 tui-idle이 조기 반환될 수 있어 terminal read로 RESULT_JSON 확인이 확실
