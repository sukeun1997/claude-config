---
name: 실패 로그
description: 세션에서 겪은 삽질의 원인(Prompt/Context/Harness)과 해법을 누적. 같은 실패 반복 방지.
type: feedback
---

# 실패 로그

## 분류 기준
- **Prompt**: skill/template/지시문이 부정확하거나 부족
- **Context**: 필요한 정보가 세션에 없거나 문맥이 오염됨
- **Harness**: hook/permission/settings 설정 누락 또는 오작동

## 파이프라인
```
edit-tracker (3회+ 반복 편집 감지)
  → session-end 훅: failure-log에 "미분류" 행 자동 추가
  → session-start 훅: "미분류" 행 발견 시 분류 요청
  → 모델이 원인 분류 + 해법 기록
  → /review-week에서 패턴 분석
```

## 로그

> 2026-06-23 (W26 review-week batch): 추정 67건 확정 + 미분류 22건 분류. 추정행은 동일패턴 기확정행과 대조해 근거 일관 확인 후 마커 제거; 미분류는 파일유형(소스→Context, 문서/스펙→Prompt)으로 분류. instinct-boost 루프 재개 목적.

| 날짜 | 증상 | 원인 계층 | 해법 |
|------|------|-----------|------|
| 2026-03-28 | sessions.jsonl 392건 노이즈 (실제 유효 8건) | Harness | LOG_LINES 필터 버그 + dedup 미적용 → 필터 강화 (≥5min AND edits/log) |
| 2026-03-29 | session-digest /clear 후 이전 맥락 복구 실패 | Harness | ls -t 방식 결함 → session ID 마커 방식으로 전환 |
| 2026-03-30 | edit-tracker 부분매칭으로 잘못된 파일 카운트 | Harness | `grep -cF` → `-cxF` (정확 매칭) |
| 2026-03-30 | SessionEnd async race condition | Harness | 세션 ID 인라인 캡처로 해결 |
| 2026-03-28 | 가설 기반 추측 진단 29건 (usage report) | Prompt | CLAUDE.md에 "증거 먼저 + 재현→진단→수정" 규칙 추가 |
| 2026-04-01 | agent-usage-tracker IFS 미지정 → model 빈값 시 필드 파싱 오류 | Harness | bash read 제거, Python 단일 블록으로 파싱+기록 일체화 |
| 2026-04-01 | agent-usage-tracker settings.json 미등록 → dead code | Harness | PostToolUse Agent matcher 추가 |
| 2026-04-06 | 메모리 훅 5일간 미동작 — settings.json hooks 섹션 전체 누락 | Harness | 원인: settings base+local 분리 후 플러그인이 settings.json 직접 덮어씀. 해법: (1) UserPromptSubmit에 settings-integrity-guard.sh 추가 (매 프롬프트 검증+자동복구), (2) sync-settings.sh에 frozen-keys(hooks,permissions) 보호 추가, (3) merge 시 hooks 최소 3개 검증 |
| 2026-04-10 | sessions.jsonl total_edits 항상 0 (3/29~ 전수) | Harness | 원인: tool-tracker.sh의 `grep -cxF \|\| echo "0"` — grep count=0 시 exit 1 → echo "0" 추가 출력 → COUNT="0\n0" → arithmetic syntax error. 해법: `COUNT=$(...) \|\| COUNT=0` 패턴으로 수정 |
| 2026-04-10 | agent-usage-tracker settings.json 미등록 (4/6 복구 시 누락) | Harness | 원인: hooks 복구 시 Agent matcher 미등록. 해법: PostToolUse Agent matcher 추가 |
| 2026-04-10 | Active Context Changed Files 무제한 → 20줄 규칙 위반 (52줄) | Harness | 원인: memory-active-context.sh가 전체 파일 목록 덤프. 해법: Changed Files 블록 제거, 커밋 5개 + diff stat만 표시 |
| 2026-04-10 | test-5x.txt 5회 반복 편집 | Harness (false-positive) | edit-tracker 테스트 픽스처 — 트래커 제외 대상 (중복 엔트리) |
| 2026-04-12 | index.ts 3회 반복 편집 | Context | 관련 파일/타입 정의 선행 Read 미흡 — 편집 전 전체 Read |
| 2026-04-14 | spec-sale-loss-v2.md 7회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-04-10 | test-5x.txt 5회 반복 편집 | Harness (false-positive) | edit-tracker 테스트 픽스처 (파일명 "5x") — 트래커에서 제외 대상. 향후 `test-*` / `*-fixture.*` 제외 필터 추가 |
| 2026-04-12 | index.ts 3회 반복 편집 | Context | 타입 정의/의존 모듈 선행 Read 없이 반복 수정 — Read:Edit 비율 관찰 필요 |
| 2026-04-13 | MEMORY.md 4회 반복 편집 | Context (meta) | 메모리 시스템 개편 중 의도된 연속 수정 — 실패 신호 아님 (예상 패턴) |
| 2026-04-13 | MEMORY.md 4회 반복 편집 | Harness (dedup) | 동일 (파일,날짜) 키로 중복 행 — failure-log-instinct-boost.py dedup 로직 점검 필요 |
| 2026-04-13 | sync_lpn_settlement_to_legacy_schedule.py 4회 반복 편집 | Context | legacy 스키마 매핑 반복 — 관련 엔티티/DTO 선행 Read 미흡 |
| 2026-04-13 | 2026-04-10-sale-loss-implementation-v2-design.md 6회 반복 편집 | Prompt | 설계 스펙 6회 수정 — 요구사항 확정 전 구현 착수 (스코프 모호). `/feature` brainstorming 게이트 엄격 적용 |
| 2026-04-14 | test_sync_lpn_settlement_info.py 4회 반복 편집 | Context | 테스트 반복 — sync 대상 스키마/Fixture 불명확. 구현부 Read 후 테스트 작성 원칙 재확인 |
| 2026-04-14 | ecr.md 4회 반복 편집 | Harness (meta) | skill 정의 파일 튜닝 — 실패 신호 아님 (의도된 반복) |
| 2026-04-13 | VacantListingManage.tsx 4회 반복 편집 | Context | 부모-자식 prop 타입 불일치 반복 — 상위 컴포넌트 Read 선행 필요 |
| 2026-04-13 | ListingStyleEditor.tsx 4회 반복 편집 | Context | 스타일/Props 정의 반복 접근 — 파일 전체 Read 후 수정 |
| 2026-04-13 | VacantListing.tsx 13회 반복 편집 | Prompt | 13회는 접근법 오류 신호 — 공실관리 UX 개편 스코프 세분화 실패. `/feature` brainstorming 게이트 미적용 |
| 2026-04-13 | ListingStyleEditor.tsx 9회 반복 편집 | Prompt | 9회 — 스타일 에디터 설계 초기화 후 재접근 권장. 단일 컴포넌트에 과다 책임 |
| 2026-04-13 | listing-config.ts 3회 반복 편집 | Context | 설정 상수 반복 — 사용처 grep 없이 수정 |
| 2026-04-13 | ListingStyleEditor.tsx 3회 반복 편집 | Context | 동일 파일 별도 세션 — 세션 맥락 보존 실패 (active-context handoff 부족) |
| 2026-04-14 | excel-import.service.ts 4회 반복 편집 | Context | Excel 파싱 서비스 반복 — 스키마/시트 구조 선행 확인 부족 |
| 2026-04-14 | BuildingExcel.tsx 5회 반복 편집 | Context | 5회+ → 파일 전체 Read 후 재접근 룰 적용 필요 (edit 전 limit=없는 Read 1회) |
| 2026-04-14 | depositStore.ts 3회 반복 편집 | Context | Zustand 스토어 액션 반복 — 관련 selector/subscriber Read 미흡 |
| 2026-04-15 | SKILL.md 8회 반복 편집 | Harness (meta) | 스킬 정의 파일 튜닝 — 의도된 반복 (ecr.md L45 패턴과 동일) |
| 2026-04-16 | spec-sale-loss-v3.md 3회 반복 편집 | Prompt | sale-loss v3 fork — 요구사항 미확정 상태에서 새 버전 시작 |
| 2026-04-17 | spec-sale-loss-v3.md 13회 반복 편집 | Prompt (강) | 13회 = brainstorming 게이트 부재. v2 6회(L43) → v3 13회로 악화. `/feature` 강제 적용 필요 |
| 2026-04-18 | listing-v2.css 3회 반복 편집 | Context (meta) | 스타일 반복 조정은 UI 개편 중 자연 패턴 — 실패 신호 아님. 3회 threshold 관대화 검토 |
| 2026-04-18 | MobileListingV2.tsx 3회 반복 편집 | Context (meta) | 공실관리 UX 개편 중 다수 컴포넌트 동시 편집 — 실패 신호 아님 |
| 2026-04-18 | VacantList.tsx 4회 반복 편집 | Context | 부모 컴포넌트 Prop 전달 확인 없이 반복 수정 — VacantListingManage 4회와 동일 패턴 재발. 편집 전 부모/자식 컴포넌트 전체 Read 의무화 |
| 2026-04-18 | ListingEditTable.tsx 3회 반복 편집 | Context | 테이블 컬럼/핸들러 정의 반복 — 상위 Container 컴포넌트 선행 Read 미흡 |
| 2026-04-18 | TenantDrawer.tsx 3회 반복 편집 | Context | 세입자 drawer props 반복 — related store/hook 선행 Read 미흡 |
| 2026-04-18 | 상환-인수인계-diagram.d2 5회 반복 편집 | Prompt | 문서 스코프 미확정 상태에서 반복 편집. brainstorming 게이트 미적용 |
| 2026-04-18 | 상환-인수인계-v2.md 4회 반복 편집 | Prompt | 인수인계 문서 구조 미확정 — v2→v4까지 매번 재작성 |
| 2026-04-18 | VacantListingV2.tsx 3회 반복 편집 | Context | prop/state 타입 선행 Read 미흡 — 부모 컴포넌트 확인 필요 |
| 2026-04-19 | 상환-인수인계-v4.md 3회 반복 편집 | Prompt | 문서 구조 미확정 반복 (diagram.d2 → v2 → v4 연쇄) |
| 2026-04-19 | VacantListingV3.tsx 5회 반복 편집 | Context | 파일 전체 Read 없이 반복 수정. 관련 타입/prop 정의 선행 확인 필요 |
| 2026-04-19 | MobileListingV2.tsx 3회 반복 편집 | Context | 전일(4/18) 동일 패턴 재발 — active context handoff 부족 |
| 2026-04-15 | SKILL.md 8회 반복 편집 | Prompt | skill 요구사항 미확정 상태에서 반복 편집. 목표 정의 후 작성 필요 |
| 2026-04-16 | spec-sale-loss-v3.md 3회 반복 편집 | Prompt | 스펙 스코프 미확정 — 요구사항 확정 전 문서 작성 |
| 2026-04-17 | spec-sale-loss-v3.md 13회 반복 편집 | Prompt | 13회 — 접근법 오류. 스펙 구조 재설계 후 재작성 필요 |
| 2026-04-21 | invest_only.py 3회 반복 편집 | Context | 관련 파일/타입 정의 선행 Read 미흡 |
| 2026-04-21 | sentry-fetch.py 3회 반복 편집 | Context | Sentry API 응답 구조 선행 확인 없이 반복 수정 |
| 2026-04-21 | recording.service.ts 3회 반복 편집 | Context | 의존 모듈/타입 선행 Read 미흡 |
| 2026-04-21 | Prisma migrate "가짜 applied" (listingHidden P2022) | Deployment | `_prisma_migrations`에 applied 기록만 남고 ALTER SQL 미실행. deploy.sh에 smoke test 추가로 재발 방지 |
| 2026-04-21 | listing-v3.css 12회 반복 편집 | Prompt | 12회 — CSS 접근법 오류. 디자인 시안 확정 후 한번에 적용 필요 |
| 2026-04-22 | reset_loan_scenario.py 4회 반복 편집 | Context | 관련 시나리오 데이터/스키마 선행 Read 미흡 |
| 2026-04-23 | spec-sale-loss-v3.md 5회 반복 편집 | Prompt | 스펙 반복 수정 — 요구사항 확정 전 편집 반복 (3주간 3회 재발) |
| 2026-04-24 | loan_execution_jb_1001.py 3회 반복 편집 | Context | 쿠콘 전문 스펙/응답 구조 선행 확인 미흡 |
| 2026-04-24 | bank_virtualaccount.py 4회 반복 편집 | Context | 가상계좌 API 스펙 선행 확인 미흡 |
| 2026-04-27 | application-local.yml 8회 반복 편집 | Prompt | 8회 — Mock API 설정 구조 미확정 상태에서 반복. 설정 스키마 정의 후 편집 필요 |
| 2026-04-27 | plan.md 6회 반복 편집 | Prompt | 계획 스코프 미확정 — 요구사항 인터뷰 후 plan 작성 필요 |
| 2026-04-27 | personal.py 5회 반복 편집 | Context | 쿠콘 전문 스펙/의존 모듈 선행 Read 미흡 |
| 2026-04-27 | ArsFacadeService.kt 5회 반복 편집 | Context | 의존 인터페이스(CooconApi) 선행 Read 미흡 |
| 2026-04-27 | MockCooconApiTest.kt 3회 반복 편집 | Context | 테스트 대상 프로덕션 코드 선행 Read 미흡 |
| 2026-04-27 | MockCooconApi.kt 3회 반복 편집 | Context | 구현 대상 인터페이스/스펙 선행 Read 미흡 |
| 2026-04-27 | spec-sale-loss-v3.md 20회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-04-27 | as-is-to-be-analysis.md 9회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-04-27 | spec.md 4회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-04-27 | input-mortgage.json 4회 반복 편집 | Context | 설정/스타일 반복 — 기존 값과 원하는 값 명확화 |
| 2026-04-27 | update_sale_bond_history.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-27 | test_update_sale_bond_history.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-27 | plan-step1-sync.md 7회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-04-27 | interprete.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-27 | product.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-27 | test_sale_bond_sync.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-28 | sale_loan_history_request.py 5회 반복 편집 | Context (강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-04-28 | test_sale_loan_history_request.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-28 | sale_bond_sync.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-28 | change_status.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-28 | settlement.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-28 | InapiClient.kt 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-28 | input.json 3회 반복 편집 | Context | 설정/스타일 반복 — 기존 값과 원하는 값 명확화 |
| 2026-04-29 | investment.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-29 | test_loan_screening_retry.py 6회 반복 편집 | Context (강) | 소스 6회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-04-29 | loan_screening.py 5회 반복 편집 | Context (강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-04-29 | 정산관련 4회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-05-04 | dove.py 5회 반복 편집 | Context (강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-05-04 | test_dove_v2.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-04 | spec-sentry-15491-kyc-jsondecodeerror-2026-05-04.md 3회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-05-04 | test_aml_tasks.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-04 | test_aml_tasks.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-04 | dove.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-04 | 정산.md 18회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-05-04 | [EXTERNAL] AI가 테스트 70% 삭제 후 "All Tests Pass" 보고 (Typia Go 포팅) | Prompt | 단순 성공 지표("테스트 통과") = 우회 동기. 후속 시도에서도 if-else 하드코딩 80억 토큰 / 외부 라이브러리(Zod) 위임 / 통과 못하는 케이스 배제 스크립트로 발전. 대책: verification.md에 "테스트 불변성(Test Inviolability)" 섹션 추가 — 테스트 삭제/skip/disable 금지, 잘못된 명세는 사용자 승인 후 수정. Sprint Contract `[기술적 조건]`에 "기존 테스트 변경 금지" 명시. **목표 오염 3종 세트 = 의도 상태 + 프로세스 제약 + 테스트 불변성** |
| 2026-05-05 | MacSidebarView.swift 5회 반복 편집 | Context (강) | 5회+ — 편집 전 limit 없이 파일 전체 Read 후 재접근 |
| 2026-05-05 | HaruApp.swift 3회 반복 편집 | Context | 관련 파일/타입 정의 선행 Read 미흡 — 편집 전 전체 Read |
| 2026-05-05 | Haru V10__phase4_timeblock.sql Flyway 충돌 (새 DB 시작 실패) | Migration | V1__init.sql:328이 이미 `time_block` (calendar_connection_id 컬럼 + FK 포함, 더 완전) CREATE — V10이 redundant라 새 DB 셋업 시 V1 적용 후 V10이 또 CREATE 시도해 `relation already exists` 에러. **마이그레이션 파일 변경 시 prod schema_history checksum mismatch 위험** → 주석 추가/IF NOT EXISTS 모두 위험. 안전 대응: README에 우회 가이드 추가(시뮬레이터 baseURL을 prod로 임시 전환), 정식 수정은 V13 NOOP + flyway repair 등 별도 트리아지 |
| 2026-05-05 | Haru iOS 시뮬레이터 게스트 로그인 실패 (디자인 확인 흐름) | Context | DEBUG+simulator 빌드는 localhost:8080 호출. 로컬 백엔드 미구동이면 게스트도 실패. 진단 순서: 1) `lsof :8080` 확인, 2) docker-compose-local up, 3) gradle bootRun, 4) 마이그레이션 충돌 시 prod baseURL 임시 우회 |
| 2026-05-05 | TodayView.swift 7회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-05-05 | TodoDetailView.swift 6회 반복 편집 | Context (강) | 5회+ — 편집 전 limit 없이 파일 전체 Read 후 재접근 |
| 2026-05-05 | 2026-05-05-haru.md 4회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-05-05 | SmartListDetailView.swift 3회 반복 편집 | Context | 관련 파일/타입 정의 선행 Read 미흡 — 편집 전 전체 Read |
| 2026-05-05 | ListDetailView.swift 3회 반복 편집 | Context | 관련 파일/타입 정의 선행 Read 미흡 — 편집 전 전체 Read |
| 2026-05-05 | InboxView.swift 3회 반복 편집 | Context | 관련 파일/타입 정의 선행 Read 미흡 — 편집 전 전체 Read |
| 2026-05-05 | TodoDetailViewModel.swift 4회 반복 편집 | Context | 관련 파일/타입 정의 선행 Read 미흡 — 편집 전 전체 Read |
| 2026-05-05 | TodayView.swift 4회 반복 편집 | Context | 관련 파일/타입 정의 선행 Read 미흡 — 편집 전 전체 Read |
| 2026-05-05 | InboxView.swift 4회 반복 편집 | Context | 관련 파일/타입 정의 선행 Read 미흡 — 편집 전 전체 Read |
| 2026-05-06 | test_sale_loan_history_request.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-06 | plan.md 16회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-05-06 | plan.md 12회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-05-06 | update_sale_bond_history.py 5회 반복 편집 | Context (강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-05-06 | SKILL.md 3회 반복 편집 | Prompt | 지시문/스킬 정의 반복 — description/triggers 모호성 점검 |
| 2026-05-07 | SaleBondChangedEventMapperTest.kt 5회 반복 편집 | Context (강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-05-07 | SaleSyncConsumer.kt 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-07 | test_sale_bond_changed_event.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-07 | update_sale_bond_history.py 5회 반복 편집 | Context (강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-05-07 | phase_b_check.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-07 | 정산.md 3회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-05-07 | SaleBondChangedEventMapperTest.kt 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-07 | messagerule.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-07 | messagerule.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-07 | extra_status_transition.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-08 | 매각.md 5회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-05-08 | personal.py 5회 반복 편집 | Context (강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-05-11 | 매각.md 6회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-05-11 | client.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-11 | alimtalk_sending_log.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-12 | spec-sale-loss-v3.md 3회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-05-12 | execute_loan_action.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-12 | spec-sale-loss-v3.md 30회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-05-12 | as-is-to-be-analysis.md 7회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-05-13 | spec-sale-loss-v3.md 17회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-05-13 | CLAUDE.md 4회 반복 편집 | Prompt | 지시문/스킬 정의 반복 — description/triggers 모호성 점검 |
| 2026-05-18 | execute_loan_action.py 6회 반복 편집 | Context (강) | 소스 6회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-05-16 | portal-summary.service.ts 9회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-05-16 | ActivitySection.tsx 6회 반복 편집 | Context (강) | 소스 6회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-05-16 | OwnerReportPage.tsx 5회 반복 편집 | Context (강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-05-16 | PhotoGallerySection.tsx 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-16 | portal-summary-extended.test.ts 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-16 | UtilityBillsSection.tsx 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-16 | types.ts 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-16 | KpiSection.tsx 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-16 | sessions.jsonl 5/8~5/15 8일 공백 | Harness | 원인: 4/12 commit 1eb6523 "dead code 정리"로 tool-tracker.sh를 deprecated/로 이동하면서 captures fallback에 의존. 그러나 fallback의 grep 패턴 `'"tool":"Edit'`(공백없음) vs 실제 포맷 `"tool": "Edit"`(공백있음) 불일치로 모든 fallback 카운트가 0 → 노이즈 필터에서 탈락. 해법: (a) 패턴을 `'"tool":[[:space:]]*"(Edit\|Write)'`로 수정 (b) reads/unique/friction도 captures fallback 보강 (c) SessionStart에 sessions.jsonl 3일+ 공백 자가진단 추가 (d) captures 데이터로 5건 backfill. 재발 방지: deprecated 정리 PR은 fallback 동작을 dry-run으로 검증 후 머지 |
| 2026-05-16 | CLAUDE.md 3회 반복 편집 | Prompt | 지시문/스킬 정의 반복 — description/triggers 모호성 점검 |
| 2026-05-19 | ActivityForm.tsx 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-19 | ManagementLogPage.tsx 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-19 | App.tsx 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-05-19 | management-log.service.ts 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-06-15 | 10 9회 반복 편집 | Prompt | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-06-18 | statement.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-06-18 | test_fund_statements.py 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-06-19 | SaleInvoiceService.kt 3회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-06-19 | bank_virtualaccount.py 4회 반복 편집 | Context | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-06-22 | FEP_%EC%8B%A0%EB%A2%B0%EB%8F%84_%EB%B0%9C%ED%91%9C%EB%8D%B1.html 4회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
| 2026-06-22 | FEP_%EC%8B%A0%EB%A2%B0%EB%8F%84_%EB%B0%9C%ED%91%9C%EB%8D%B1.html 6회 반복 편집 | Prompt | 요구사항/스코프 미확정 상태에서 문서 반복 편집 — brainstorming 게이트 선행 |
