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

### Promoted 2026-04-13
- Phrase 설계 원칙: p1은 "답변 필요 없이 내가 말하고 끝나는 문장"이 핵심. 질문형은 답변 못 알아들으면 무용지물이라 p2/p3로. 일본 현금 결제 비율 높아 c-002(카드로)/c-005(현금만?) 둘 다 p1.

### Promoted 2026-04-13
- OCI 인프라 메모: maple 서버 80/443은 어머니 todo-app 전용 — 새 서비스는 반드시 별도 포트 + OCI Security List ingress 사용자 콘솔 작업 사전 고지

### Promoted 2026-04-13
- critic + verifier + code-reviewer를 단계별로 다른 시점에 부르면 서로 다른 결함을 잡는다 — Spec critic = "제로패딩/공백 prefix 누락", Plan critic = "웹 모드 routes 누락", code-reviewer(opus) = "정규식 불일치/rowIdSeq". 각 단계마다 비용 적고 효과 큼
- /feature 파이프라인은 한 세션에서 spec + plan + 8커밋 구현 + 2중 opus 검증 + PR까지 완주 가능. compaction 없이 끝남

### Promoted 2026-04-14
- code-reviewer 지적을 처리할 때 "해당 이슈가 실제로 존재하는지" 다른 관성(errorHandler 전략, app.use middleware 등)을 먼저 확인하면 skip 근거를 문서화할 수 있다. 맹목적 반영 금지

### Promoted 2026-04-14
- 순수 함수는 반드시 export하고 테스트에서 import — 복사하면 테스트-구현 drift 발생
- 같은 파이프라인 함수들은 정규화 전략(대소문자, 공백) 통일 필수

### Promoted 2026-04-14
- **Prisma `distinct` 옵션 함정**: DB 레벨 `SELECT DISTINCT`가 아니라 application-side dedup — 전체 row를 client로 가져와서 중복 제거. 큰 테이블에선 치명적 핫스팟. `groupBy` 또는 raw `SELECT DISTINCT` 사용
- **Prisma slow query duration 한계**: `$on('query')`의 duration은 DB exec만. JS deserialize / BigInt 직렬화 / IPC 왕복 / GC 압력 제외 → 사용자 체감과 괴리 가능
- **실측 miss ≠ 문제 없음**: 현재 duration이 낮아도 구조적 O(N) 부채(전체 테이블 로드 패턴)는 선제 대응 가치 있음. 단, 비용-편익 비교 시 invalidation 리스크와 실사용 호출 빈도도 함께 고려

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
