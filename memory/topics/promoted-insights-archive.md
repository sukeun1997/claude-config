---
name: Promoted Insights Archive
description: "MEMORY.md에서 승격됐던 상세 인사이트 아카이브 (프로젝트별/CSS/Prisma/배포 등). 온디맨드 Read 또는 memory_search로 조회. MEMORY.md에는 메타/프로세스 인사이트만 유지."
type: reference
---

# Promoted Insights Archive

> MEMORY.md(Always 계층) 슬림화(2026-05-23, 177→<150줄)로 이관. 프로젝트별 상세는 여기서 조회.

### Promoted 2026-03-31
- Haru 프로젝트 히스토리: [topics/haru-project-history.md](haru-project-history.md)
- migrate-legacy-deposits.ts 금액 소스: R_Cost.Minus_Cost는 적용금액(부분), TBLBANK.Bkinput이 실제 입금액. R_Cost는 전체 거래 기록 테이블
- gstack Fix-First 패턴 + 크로스 리뷰: `/review` 스킬에 통합됨. 소규모(<100줄)에서는 --quick 권장
- Session Digest: /clear 시 JSONL 자동 파싱으로 이전 대화 복구. /new 으로 완전 초기화

### Promoted 2026-04-09
- 스마트.exe Lazy Copy 메커니즘: R_Cost_Smart(원본) → R_Cost(조회 시 복사). 마이그레이션은 R_Cost_Smart 기준으로 해야 함

### Promoted 2026-04-13
- Phrase 설계 원칙: p1은 "답변 필요 없이 내가 말하고 끝나는 문장"이 핵심. 질문형은 답변 못 알아들으면 무용지물이라 p2/p3로. 일본 현금 결제 비율 높아 c-002(카드로)/c-005(현금만?) 둘 다 p1.
- OCI 인프라 메모: maple 서버 80/443은 어머니 todo-app 전용 — 새 서비스는 반드시 별도 포트 + OCI Security List ingress 사용자 콘솔 작업 사전 고지
- critic + verifier + code-reviewer를 단계별로 다른 시점에 부르면 서로 다른 결함을 잡는다 — Spec critic = "제로패딩/공백 prefix 누락", Plan critic = "웹 모드 routes 누락", code-reviewer(opus) = "정규식 불일치/rowIdSeq". 각 단계마다 비용 적고 효과 큼
- /feature 파이프라인은 한 세션에서 spec + plan + 8커밋 구현 + 2중 opus 검증 + PR까지 완주 가능. compaction 없이 끝남

### Promoted 2026-04-14
- code-reviewer 지적을 처리할 때 "해당 이슈가 실제로 존재하는지" 다른 관성(errorHandler 전략, app.use middleware 등)을 먼저 확인하면 skip 근거를 문서화할 수 있다. 맹목적 반영 금지
- 순수 함수는 반드시 export하고 테스트에서 import — 복사하면 테스트-구현 drift 발생
- 같은 파이프라인 함수들은 정규화 전략(대소문자, 공백) 통일 필수
- **Prisma `distinct` 옵션 함정**: DB 레벨 `SELECT DISTINCT`가 아니라 application-side dedup — 전체 row를 client로 가져와서 중복 제거. 큰 테이블에선 치명적 핫스팟. `groupBy` 또는 raw `SELECT DISTINCT` 사용
- **Prisma slow query duration 한계**: `$on('query')`의 duration은 DB exec만. JS deserialize / BigInt 직렬화 / IPC 왕복 / GC 압력 제외 → 사용자 체감과 괴리 가능
- **실측 miss ≠ 문제 없음**: 현재 duration이 낮아도 구조적 O(N) 부채(전체 테이블 로드 패턴)는 선제 대응 가치 있음. 단, 비용-편익 비교 시 invalidation 리스크와 실사용 호출 빈도도 함께 고려
- **executor 안전 게이트 위반 패턴**: 안전 체크("BLOCKED 보고") 지시를 명시했어도 executor가 "어떻게든 진행할 수 있는 경로"를 찾으면 우회. 운영 DB 같은 critical 경로는 명시 차단(예: `git checkout -b temp; pnpm prisma migrate dev || exit 1`)이나 executor에 미리 cd로 다른 .env 확인하게 하기, 또는 메인 세션이 사전 .env 확인 후 위임
- **subagent-driven 17 Task 동시 실행 효율**: 병렬 가능한 phase(D 3개, E 1차 3개)에서 Agent 병렬 dispatch로 시간 단축. git index.lock 충돌은 1회도 발생하지 않음 — 실제 commit timing이 분산되어 실용적으로 안전
- **자동 발송 차단 3중 게이트**: testMode 플래그 + isSendingAllowed 게이트키퍼 + 명시 버튼 클릭 트리거(5초 카운트다운). 재발송도 동일 패턴 유지. 코드-리뷰 중 안전성 PASS 확인
- **폴링 주기 최적화 1원칙**: 병목이 "내 폴링 빈도"인지 "upstream 결과 생성 속도"인지 먼저 구분. upstream이 병목이면 간격 줄여도 체감 이득 없고 API 과부하만 증가. adaptive backoff가 고정 간격보다 체감 빠른 경우 많음

### Promoted 2026-04-15
- **운영 가드 vs 운영 시나리오 정합성**: 초창기 안전장치(분당 15건)가 이후 추가된 운영 시나리오(은행별 300건+ 일괄 발송)와 충돌. "안전장치는 시나리오 변경 시 재검토" 체크리스트 필요
- **에러 메시지 분류 일관성**: rate limit / 한도 초과 / 비즈니스 검증 실패는 BusinessError로 통일해야 프로덕션 errorHandler에서 메시지가 살아남음. 일반 Error는 진짜 예외에만
- **운영자 친화 에러 패턴**: (1) 사용자에게 메시지 그대로 노출 + (2) 시크릿 마스킹 + (3) 짧은 trace ID 부착 + (4) 서버 로그 stack 보존 — 4가지가 함께 가야 운영 디버깅이 자기친화적
- **외부 API 결과 코드 매핑은 추정 금지**: 공식 문서 fetch 후 검증. 출처 URL을 코드 주석에 박아두면 검증 가능성 상승
- **테스트가 잘못된 가정을 굳히는 위험**: `400=전원꺼짐 검증` 같은 테스트가 있으면 매핑 오류를 발견하기 어려워짐. 외부 API 의미는 "공식 문서 링크가 살아있는지" 정도만 검증하고 의미 자체를 fixture화하지 않는 게 안전
- **배포 타이밍 안전 룰**: 사용자 활성 시간(특히 SMS/장기 요청 진행 중)을 피해 배포. PM2 cluster reload는 graceful이지만 진행 중 HTTP request의 connection 끊김 윈도우가 존재
- **외부 시스템 미응답 ≠ 우리 버그**: SMS/메일/외부 API 결과 추적 시 "응답 안 옴" 케이스를 코드에서 명시 처리. "확인 중" 진행형 표시가 영원히 남으면 사용자가 시스템 고장으로 오해
- **AI 비서 도구의 화이트리스트 패턴**: AI가 임의 ID로 호출해도 미리보기 단계 matched에 있는 ID만 update 허용. 동명이인은 별도 인자로 명시 선택. importId 5분 TTL로 미리보기 위조 차단
- **자동 생성 시스템의 시간 경계 검증**: "매월 자동 생성" cron은 대상 entity의 라이프사이클(시작/종료 날짜)을 항상 체크. "대상이 그 시점에 활성 상태인가?"를 첫 필터로

### Promoted 2026-04-16
- **토큰 전체 일치 정규식의 실제 데이터 함정**: 주소 같은 사용자 입력은 이상적 패턴(공백 구분) 안 따름. `^([가-힣]{1,6}(?:동))$` → "구천동47-2" 매칭 실패. lookahead 기반 prefix 매칭으로 해결. dry-run 백필이 기본 디버거
- **분류 필드 자동화 3종 세트**: nullable DB 필드 + 자동 추출 수단 없음 → 죽은 기능. 해결 = (1) 서비스단 자동 추출 (2) UI 선택적 오버라이드 (3) backfill 스크립트 한 커밋에

### Promoted 2026-04-18
- failure-log 적체 게이트는 **주간 리뷰 첫 관문**으로 유지 — 15건 쌓이면 KPI 분석 의미 없음. 자체 분류 기준을 Harness/Context/Prompt 3계층으로 일관화 (모델명·추정 레이블 금지)
- **주간 15건 분류 결과 (W16 분포)**: Context 9 / Prompt 3 / Harness 3 / Meta 2. **1위 원인 = "파일 Read 선행 미흡"(Context 9건)**
- **주간 리뷰 후 즉시 적용 패턴**: 리뷰 결과 → opus critic 검증 → REVISE 수용 → 작은 것부터 병렬 실행. critic이 실제 파일 확인으로 범위 좁혀줌
- CSS specificity 계산법: inline > class×n > (class + pseudo) > element. `:nth-child`는 pseudo-class로 0,0,1,0 추가

### Promoted 2026-04-19
- Playwright MCP 네트워크 인터셉트로 로컬 API 없이도 UI 시각 검증 가능 — `page.context().route(...)` 패턴
- 순환 import 방지: 두 컴포넌트가 공통 유틸을 필요로 할 때 → 유틸을 별도 파일로 분리
- 디자인 핸드오프 번들: Anthropic Design API의 `webfetch-*.bin`은 gzip+tar 2단계. chat transcript에 사용자 의도 흐름 → 먼저 읽을 것
- CSS 프리픽스 격리: 새 variant는 전용 프리픽스(`lt-v3-*`)로 CSS 스코프 격리. CSS 변수도 루트 클래스 안에 가둠
- CSS 변수 런타임 주입(B안): 루트 DOM에 inline style로 `--token: value` 주입 → 자식이 `var()`로 받음. props drill 없이 variant 토큰 분리
- html-to-image 캡처 안 잘리게: 캡처 동안만 width 강제 + 부모 overflow visible + minWidth 확장 + 리플로우 + 캡처 후 원복
- variant별 독립 토큰 원칙: 배경 톤이 반대인 variant는 공통 토큰 공유 금지. 처음부터 분리
- WYSIWYG 매칭/렌더 분리: DOMParser 블록 배열 → textContent 정규화 매칭 → 원본 HTML + DOMPurify
- `scrollWidth` 함정: 부모 overflow visible이면 자식 overflow 못 잡음. getBoundingClientRect().right 최대값 순회
- 모바일 fallback → variant별 분리가 (V2 재사용 + CSS var 덮어쓰기)보다 깔끔
- Cloudflare Tunnel + `trust proxy 1`의 `requireLocal`: `req.ip`(XFF) AND `req.socket.remoteAddress` 둘 다 127.0.0.1일 때만 통과
- `dangerouslySetInnerHTML` 감사: 공개 페이지만 DOMPurify 적용하고 관리자 내부 페이지 누락하면 XSS 경로 그대로 열림. grep 전수 검사

### Promoted 2026-04-20
- `@ts-expect-error + tsconfig.test.json`: "이 필드가 공개 타입에 있으면 빌드 깨진다"는 계약을 컴파일 타임 강제. `typecheck`를 `tsc && tsc -p tsconfig.test.json`로 확장
- `buildListingData` 공용 유지 + 반환 시점 spread destructuring으로 strip이 함수 2개 분리보다 변경량 작음
- V2 레거시 격리보다 "공용 유틸 → 공용 타입 일원화" 우선순위가 높았던 사례

### Promoted 2026-04-20 (운영/자동화)
- "카톡 단톡방 자동 발송": 공식 API 없음. 봇폰/computer-use cron은 깨짐 + 오발송 리스크. **"1명이 하루 30초"로 안정성 > 완전 자동**이 실용 정답. 텔레그램 봇 공식 API가 진짜 솔루션
- 업로드 파이프라인: 상대 폰에 커스텀 코드 박지 말고 **공식 동기화 앱 + 서버 pull**. Autosync → 서버 Drive API cron 5분. Service Account로 OAuth 재인증 없이 영구 동작

### Promoted 2026-04-21
- Anthropic 공식 frontend-design 스킬은 짧다(200줄 미만). 단일 SKILL.md + lazy-load reference — 스킬 메인은 얇게, 상세는 references/로
- 하네스 패턴: `@ts-expect-error + tsconfig.test.json` 계약 테스트가 반대 방향(복원)으로도 "의도된 변경 명시"용으로 재활용. "금지 계약"이 "정책 문서"로도 기능
- 사용자 증상 보고 + 내 해석의 2-pass 조정: 자연어는 축약되므로 스크린샷으로 **표현과 의도 간극** 재확인. 증상 스크린샷이 의도 스크린샷보다 구체적
