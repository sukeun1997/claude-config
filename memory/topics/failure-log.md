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
| 2026-04-10 | test-5x.txt 5회 반복 편집 | 미분류 — 다음 세션에서 원인 분석 필요 | - |
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
