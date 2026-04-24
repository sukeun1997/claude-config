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
| 2026-04-10 | test-5x.txt 5회 반복 편집 | Harness (false-positive) | edit-tracker 테스트 픽스처 (파일명 "5x") — 트래커에서 제외 대상. 향후 `test-*` / `*-fixture.*` 제외 필터 추가 |
| 2026-04-12 | index.ts 3회 반복 편집 | Context | 타입 정의/의존 모듈 선행 Read 없이 반복 수정 — Read:Edit 비율 관찰 필요 |
| 2026-04-13 | MEMORY.md 4회 반복 편집 | Context (meta) | 메모리 시스템 개편 중 의도된 연속 수정 — 실패 신호 아님 (예상 패턴) |
| 2026-04-13 | MEMORY.md 4회 반복 편집 | Context (meta) | 상동 — 중복 엔트리. dedup 로직 점검 필요 (Harness) |
| 2026-04-13 | sync_lpn_settlement_to_legacy_schedule.py 4회 반복 편집 | Context | legacy 스키마 매핑 반복 — 관련 엔티티/DTO 선행 Read 미흡 |
| 2026-04-13 | 2026-04-10-sale-loss-implementation-v2-design.md 6회 반복 편집 | Prompt | 설계 스펙 6회 수정 — 요구사항 확정 전 구현 착수 (스코프 모호). `/feature` brainstorming 게이트 엄격 적용 |
| 2026-04-14 | test_sync_lpn_settlement_info.py 4회 반복 편집 | Context | 테스트 반복 — sync 대상 스키마/Fixture 불명확. 구현부 Read 후 테스트 작성 원칙 재확인 |
| 2026-04-14 | ecr.md 4회 반복 편집 | Harness (meta) | skill 정의 파일 튜닝 — 실패 신호 아님 (의도된 반복) |
| 2026-04-12 | index.ts 3회 반복 편집 | Context | 타입 정의/의존 모듈 선행 Read 미흡 |
| 2026-04-13 | VacantListingManage.tsx 4회 반복 편집 | Context | 부모-자식 prop 타입 불일치 반복 — 상위 컴포넌트 Read 선행 필요 |
| 2026-04-13 | ListingStyleEditor.tsx 4회 반복 편집 | Context | 스타일/Props 정의 반복 접근 — 파일 전체 Read 후 수정 |
| 2026-04-13 | VacantListing.tsx 13회 반복 편집 | Prompt | 13회는 접근법 오류 신호 — 공실관리 UX 개편 스코프 세분화 실패. `/feature` brainstorming 게이트 미적용 |
| 2026-04-13 | ListingStyleEditor.tsx 9회 반복 편집 | Prompt | 9회 — 스타일 에디터 설계 초기화 후 재접근 권장. 단일 컴포넌트에 과다 책임 |
| 2026-04-13 | listing-config.ts 3회 반복 편집 | Context | 설정 상수 반복 — 사용처 grep 없이 수정 |
| 2026-04-13 | ListingStyleEditor.tsx 3회 반복 편집 | Context | 동일 파일 별도 세션 — 세션 맥락 보존 실패 (active-context handoff 부족) |
| 2026-04-14 | excel-import.service.ts 4회 반복 편집 | Context | Excel 파싱 서비스 반복 — 스키마/시트 구조 선행 확인 부족 |
| 2026-04-14 | BuildingExcel.tsx 5회 반복 편집 | Context | 5회+ → 파일 전체 Read 후 재접근 룰 적용 필요 (edit 전 limit=없는 Read 1회) |
| 2026-04-14 | depositStore.ts 3회 반복 편집 | Context | Zustand 스토어 액션 반복 — 관련 selector/subscriber Read 미흡 |
| 2026-04-18 | listing-v2.css 3회 반복 편집 | Context (meta) | 스타일 반복 조정은 UI 개편 중 자연 패턴 — 실패 신호 아님. 3회 threshold 관대화 검토 |
| 2026-04-18 | MobileListingV2.tsx 3회 반복 편집 | Context (meta) | 공실관리 UX 개편 중 다수 컴포넌트 동시 편집 — 실패 신호 아님 |
| 2026-04-18 | VacantList.tsx 4회 반복 편집 | Context | 부모 컴포넌트 Prop 전달 확인 없이 반복 수정 — VacantListingManage 4회와 동일 패턴 재발. 편집 전 부모/자식 컴포넌트 전체 Read 의무화 |
| 2026-04-18 | ListingEditTable.tsx 3회 반복 편집 | Context | 테이블 컬럼/핸들러 정의 반복 — 상위 Container 컴포넌트 선행 Read 미흡 |
| 2026-04-18 | TenantDrawer.tsx 3회 반복 편집 | Context | 세입자 drawer props 반복 — related store/hook 선행 Read 미흡 |
| 2026-04-18 | 상환-인수인계-diagram.d2 5회 반복 편집 | 미분류 | 다음 세션에서 원인 분석 필요 |
| 2026-04-18 | 상환-인수인계-v2.md 4회 반복 편집 | 미분류 | 다음 세션에서 원인 분석 필요 |
| 2026-04-18 | listing-v2.css 3회 반복 편집 | Context (추정) | 설정/스타일 반복 — 기존 값과 원하는 값 명확화 |
| 2026-04-18 | VacantListingV2.tsx 3회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-19 | 상환-인수인계-v4.md 3회 반복 편집 | 미분류 | 다음 세션에서 원인 분석 필요 |
| 2026-04-19 | 상환-인수인계-v4.md 3회 반복 편집 | 미분류 | 다음 세션에서 원인 분석 필요 |
| 2026-04-19 | VacantListingV3.tsx 3회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-19 | VacantListingV3.tsx 5회 반복 편집 | Context (추정·강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-04-19 | MobileListingV2.tsx 3회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-10 | test-5x.txt 5회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |
| 2026-04-12 | index.ts 3회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |
| 2026-04-13 | MEMORY.md 4회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |
| 2026-04-13 | MEMORY.md 4회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |
| 2026-04-13 | sync_lpn_settlement_to_legacy_schedule.py 4회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |
| 2026-04-13 | 2026-04-10-sale-loss-implementation-v2-design.md 6회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |
| 2026-04-14 | test_sync_lpn_settlement_info.py 4회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |
| 2026-04-14 | ecr.md 4회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |
| 2026-04-12 | index.ts 3회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-13 | VacantListingManage.tsx 4회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-13 | ListingStyleEditor.tsx 4회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-13 | VacantListing.tsx 13회 반복 편집 | Prompt (추정·13회) | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-04-13 | ListingStyleEditor.tsx 9회 반복 편집 | Prompt (추정·9회) | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-04-13 | listing-config.ts 3회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-13 | ListingStyleEditor.tsx 3회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-14 | excel-import.service.ts 4회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-14 | BuildingExcel.tsx 5회 반복 편집 | Context (추정·강) | 소스 5회+ — 파일 전체 Read 후 재접근 권장 |
| 2026-04-14 | depositStore.ts 3회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-15 | SKILL.md 8회 반복 편집 | Prompt (추정·8회) | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-04-16 | spec-sale-loss-v3.md 3회 반복 편집 | 미분류 | 다음 세션에서 원인 분석 필요 |
| 2026-04-17 | spec-sale-loss-v3.md 13회 반복 편집 | Prompt (추정·13회) | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-04-21 | recording.service.ts 3회 반복 편집 | Context (추정) | 소스 반복 — 관련 파일/타입 정의 확인 필요 |
| 2026-04-21 | Prisma migrate "가짜 applied" (listingHidden P2022) | Deployment | `_prisma_migrations`에 applied 기록만 남고 ALTER SQL 미실행. `migrate status`는 "up to date" 반환하며 감지 불가. 라이브 API가 전부 500 에러. 수동 `ALTER TABLE ADD COLUMN IF NOT EXISTS` + pm2 restart로 복구. deploy.sh에 smoke test 단계 추가로 재발 방지 |
| 2026-04-21 | listing-v3.css 12회 반복 편집 | Prompt (추정·12회) | 접근법 오류 가능성 — 초기화 후 재설계 권장 |
| 2026-04-24 | SKILL.md 3회 반복 편집 | Prompt (추정) | 지시문/스킬 정의 반복 — description/triggers 모호성 점검 |
