---
name: daily-briefing
description: "매일/주간 기술 브리핑. AI 도구 + 백엔드 기술 동향을 프로필 기반 관련도 스코어링으로 제공. Use when user says '/briefing', '브리핑', '오늘 뉴스', 'tech briefing', '기술 브리핑'."
---

# Daily Tech Briefing

프로필 맞춤 기술 브리핑. quick 모드(매일, 1분)와 deep 모드(주간, 3분)를 지원한다.

## When to Apply

- `/briefing` 또는 관련 트리거 입력 시
- 사용자가 오늘의 기술 뉴스/동향을 요청할 때

## 파라미터 파싱

인자에서 플래그를 추출:
- `--deep` → deep=true (없으면 quick)
- `--notion` → notion=true
- `--html` → html=true
- `--ai` → scope=ai
- `--backend` → scope=backend
- `--ai` + `--backend` 또는 플래그 없음 → scope=all

## Phase 0: Profile Load

1. Read `~/.claude/memory/topics/user-profile.md`
2. 기술 스택 키워드 추출 (주력, 인프라, 관심사, 도구)
3. 파일 없으면 기본값: `["Kotlin", "Spring Boot", "Claude Code"]`
4. 추출된 키워드를 이후 Phase에서 사용

## Phase 1: Research

### quick 모드

`references/quick-sources.md`를 읽고, scope에 해당하는 소스만 WebFetch 병렬 실행.
각 소스의 추출 지시(extract)에 따라 `{title, summary, url, date, source}` 수집.

**에러 처리**: 개별 소스 실패 시 스킵 + "⚠ {source} 스킵" 표시. 전체 실패 시 WebSearch 폴백.

### deep 모드

1. quick과 동일하게 고정 소스 스캔
2. `references/deep-queries.md`를 읽고 쿼리 템플릿의 {date}, {year}를 치환하여 WebSearch 6-8회 실행 (scope 필터 적용)
3. WebSearch 결과에서 핵심 소스 5-10개 선별하여 WebFetch
4. 서브에이전트(Explore, haiku) 2-3개로 병렬 처리 가능

## Phase 2: Filter & Score

`references/scoring-guide.md`를 읽고 스코어링 프롬프트를 실행.

입력: Phase 0의 프로필 키워드 + Phase 1의 수집 항목 전체
출력: 각 항목에 score(0-100), tier(HIGH/MED/LOW), action, category 부여

필터링:
- quick: HIGH + MED만 유지, score 내림차순, 최대 10개
- deep: 전체, score 내림차순, 최대 20개

**에러 처리**: 스코어링 후 0개면 "오늘은 관련 뉴스가 없습니다. `--deep` 모드나 scope 변경을 시도해보세요."

## Phase 3: Enrich (deep 모드만)

quick 모드에서는 이 Phase를 건너뛴다.

HIGH 항목 중 해당하는 것만 보강:

| 조건 | 생성물 |
|------|--------|
| 기술 비교 키워드 (vs, 비교, 차이) | 비교표 (마크다운 테이블) |
| 마이그레이션/업그레이드 키워드 | 체크리스트 |
| 새 릴리스/버전 | 변경 사항 요약 + breaking changes |
| 아키텍처 패턴 | 다이어그램 설명 + 실전 사례 링크 |

커뮤니티 반응 보강:
- `references/deep-queries.md`의 커뮤니티 쿼리로 WebSearch
- HN/Reddit 핵심 의견 2-3개 요약하여 해당 항목에 추가

## Phase 4: Output

### terminal (기본)

아래 포맷으로 마크다운 출력:

    # Tech Briefing — {date} ({요일})
    > 프로필: {keywords}
    > 모드: {mode} | 항목: {n}개 | 소스: {source_count}개 스캔

    ## 🔴 HIGH ({n}개)
    ### [{score}%] {title}
    {summary}
    **적용**: {action}
    > 출처: [{source}]({url})

    ## 🟡 MED ({n}개)
    (동일 구조)

    ## 🔵 LOW ({n}개) — deep 모드만

    ## 📋 오늘의 액션
    - [ ] {action items from HIGH}

    Sources:
    - [{title}]({url})

### html (`--html`)

`references/html-template.md`를 읽고 지시에 따라 HTML 파일 생성. Phase 2 결과를 카드 데이터로 변환하여 삽입.

### notion (`--notion`)

`references/notion-output.md`를 읽고 지시에 따라 Notion 페이지 생성. terminal 출력과 동일한 마크다운을 Notion에 저장.

### Master Guide 업데이트 감지 (Phase 4 부가)

terminal/notion/html 출력 **이후** 추가 단계:

1. `~/.claude/skills/master-guide/references/notion-registry.md` Read
2. 등록된 기술명 + 현재 버전 목록 추출
3. 이번 브리핑의 HIGH/MED 항목 제목/요약에서 등록 기술의 릴리스/업데이트 키워드 매칭
   - 매칭 키워드: "release", "릴리스", "출시", "업데이트", "v{N}", "{N}.0"
4. 매칭 항목이 있으면 출력 하단에 별도 섹션 추가:

```
## ⚡ Master Guide 업데이트 추천
- {기술명} {새 버전} 릴리스됨 (현재 가이드: {현재 버전})
  → `/master-guide update {기술명}`
```

5. 매칭 없으면 이 섹션 생략
6. **주의**: scoring 로직(Phase 2)에는 손대지 않음 — Output 단계에서 부가 정보로만 표시

## Budget

| 모드 | WebFetch | WebSearch | 목표 시간 | 최대 허용 |
|------|----------|-----------|----------|----------|
| quick | 8회 | 0회 | 1분 | 2분 |
| deep | 8 + 5-10회 | 6-8회 | 3분 | 5분 |
| deep+notion | 위 + MCP 3회 | 6-8회 | 4분 | 6분 |

quick이 2분 초과 시: 실패한 소스 스킵하고 보유 결과로 즉시 출력.

## 제약사항

1. **캐싱 없음** — 매번 fresh 스캔. 같은 날 재실행 시 동일 결과 가능
2. **속보 감지 아님** — 고정 소스의 최신 포스트 기준. 실시간 모니터링은 `/loop`으로 별도
3. **이미지 미포함** — terminal/notion은 텍스트만. HTML에서만 시각 요소
4. **프로필 수동 관리** — `user-profile.md` 업데이트는 사용자 책임
5. **소스 리스트 유지보수** — `quick-sources.md` URL 유효성을 분기 1회 점검 권장
