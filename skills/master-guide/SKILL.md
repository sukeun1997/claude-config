---
name: master-guide
description: "업무 기술(Spring, Kotlin, Kafka, Redis, LGTM, EDA 등) 마스터 학습 가이드 생성. 개념/이론/트레이드오프/대안 비교/실무 적용(Spring+Kotlin)/트러블슈팅을 노션 DB+메인/서브페이지로 생성. Use when user says '/master-guide <tech>', '마스터 가이드', 또는 업무 기술 키워드 + '학습/정리/가이드'."
---

# Tech Master Guide — 업무 기술 심층 학습 가이드 생성

## When to Apply

이 스킬을 트리거하는 조건:

1. **명시적 호출**: `/master-guide <기술명>` (예: `/master-guide Kafka`)
2. **Update 모드**: `/master-guide update <기술명>` (기존 가이드 갱신)
3. **자동 키워드 매칭**: `tech-keywords.md`에 등록된 키워드 + "학습 / 정리 / 가이드 / 마스터 / 공부" 조합
   - 예: "Kafka 학습 정리해줘", "Redis 마스터 가이드 만들어줘"
4. **리다이렉트**: `research-to-notion` 스킬 실행 중 업무 기술로 판별되면 이 스킬로 전환

---

## Pipeline Overview

```
Phase 0: Topic Analysis
   ↓ (키워드 매칭 + 대안 WebSearch)
Phase 1: Deep Research (병렬 4개 채널)
   ↓ (공식문서 + 심층분석 + 비교 + 실전)
Phase 2: Plan + 사용자 확인
   ↓ (메인 8섹션 + 서브 6종 플랜 제시)
Phase 3: Write to Notion (듀얼 MCP)
   ↓ (DB 확인/생성 → 메인 페이지 → 서브 6종)
Phase 4: Verification
   ↓ (notion-fetch로 전체 확인)
Phase 5: Registry Update
   (notion-registry.md 기록)

Update Mode (/master-guide update <기술명>):
Phase 0: Registry 조회 → Phase 1: 최신 리서치 → Phase 2: 영향 분석
→ Phase 3: 서브페이지 교체 → Phase 4: 버전 히스토리 → Phase 5: DB 업데이트
→ Phase 6: Registry 갱신
```

---

## Phase 0: Topic Analysis

### 카테고리 판별

`references/tech-keywords.md`를 읽어 입력된 기술명이 어느 카테고리에 속하는지 확인:
- backend / messaging / database / infra / observability / architecture / cloud / build

**동적 판별**: 키워드 파일에 없는 기술명 입력 시:
1. 카테고리를 동적 판별 (기술 성격 기반)
2. 해당 카테고리에 `tech-keywords.md` 자동 추가

### 버전 및 대안 조사 (WebSearch 2회)

```
Search 1: "{기술명} latest stable version {현재년도}"
  → 현재 권장 버전, Spring Boot 호환 버전 확인

Search 2: "{기술명} alternatives comparison {현재년도}"
  → 주요 대안 기술 3개 자동 선정 (최신 트렌드 기반)
```

### 사용자 확인

```
조사 결과 요약:
- 기술: {기술명} v{버전}
- 카테고리: {카테고리}
- 비교 대안: {alt1}, {alt2}, {alt3}

위 대안으로 진행할까요? (변경 원하시면 알려주세요)
```

---

## Phase 1: Deep Research (병렬)

4개 채널을 병렬로 실행:

### [공식 문서] WebFetch
```
URL: {기술명 공식 docs URL}
목적: 공식 개념 정의, 핵심 아키텍처, 설정 레퍼런스 수집
```

### [심층 분석] WebSearch 2-3회 + WebFetch
```
Search 1: "{기술명} architecture internals how it works"
Search 2: "{기술명} Spring Boot Kotlin integration {현재년도}"
Search 3 (옵션): "{기술명} production best practices {현재년도}"
WebFetch: 가장 관련성 높은 결과 1-2개 페이지 전체 내용
목적: 내부 동작 원리, Spring+Kotlin 통합 패턴 수집
```

### [비교] WebSearch 1-2회
```
Search 1: "{기술명} vs {alt1} vs {alt2} benchmark performance {현재년도}"
Search 2: "{기술명} vs {alt3} when to use tradeoffs"
목적: 정량 벤치마크, 사용 시나리오별 비교 데이터
```

### [실전] WebSearch 1-2회
```
Search 1: "{기술명} production experience lessons learned"
Search 2: "{기술명} troubleshooting anti-patterns common mistakes"
목적: 현장 경험담, 안티패턴, 트러블슈팅 사례 수집
```

### 이미지 수집 정책

각 소스에서 `img src` 추출:
- **허용**: webp / png / jpg, 최소 600px 이상
- **핫링크 차단 시**: 텍스트 대체 다이어그램으로 전환
- **우선순위**: 아키텍처 다이어그램 > 용어 관계도 > 비교 차트
- **정책**: best-effort. 이미지 없어도 페이지 생성 중단하지 않음

---

## Phase 2: Plan + 사용자 확인

리서치 완료 후 플랜을 출력하고 확인 요청:

```
[Master Guide 생성 플랜]

기술: {기술명} v{버전}
예상 소요: 약 {N}분

메인 페이지 (8섹션):
  1. 읽기 가이드
  2. 한 줄 정의 + 핵심 키워드
  3. 핵심 용어 관계도 {이미지 있음/없음}
  4. 핵심 개념 (왜 존재하는가 / 어떤 문제 해결)
  5. 동작 원리 + 아키텍처 {이미지 있음/없음}
  6. 트레이드오프 (장점/한계/쓰면 안 되는 경우)
  7. 대안 비교 ({alt1} / {alt2} / {alt3})
  8. 첫 도입 설정 가이드

서브페이지 6종:
  [1] Quick Start (Spring+Kotlin)
  [2] 프로덕션 체크리스트
  [3] 실전 패턴 & 안티패턴
  [4] 트러블슈팅 (증상별 의사결정 트리)
  [5] 스케일링 가이드
  [6] 버전 히스토리

이미지 매핑:
  - 아키텍처 다이어그램: {source_url or "텍스트 대체"}
  - 용어 관계도: {source_url or "텍스트 대체"}

진행할까요? (서브페이지 제외 원하시면 알려주세요)
```

---

## Phase 3: Write to Notion (듀얼 MCP)

### 3-1. DB 확인

```
notion-search("Tech Master Guides")
→ DB 존재하면: data_source_id 획득 → 3-3으로
→ DB 없으면: 3-2로
```

### 3-2. DB 생성 (최초 1회)

```
질문: "Master Guide DB를 어느 페이지 아래에 생성할까요? 페이지 URL을 알려주세요."

답변 받은 후:
1. notion-create-database(
     parent: {사용자 지정 페이지 ID},
     title: "Tech Master Guides",
     properties: {
       Name: title,
       기술명: rich_text,
       버전: rich_text,
       카테고리: select,
       생성일: date,
       최종업데이트: date,
       메인페이지ID: rich_text
     }
   )
2. notion-fetch(db_id) → data_source_id 확인
3. references/notion-registry.md 업데이트 (DB ID / URL / data_source_id 기록)
```

### 3-3. 메인 페이지 생성

`references/guide-template.md` 기반으로 플레이스홀더를 리서치 결과로 채워:

```
notion-create-pages(
  parent: { database_id: {data_source_id} },
  properties: {
    Name: "{기술명} — Master Guide",
    기술명: "{기술명}",
    버전: "{버전}",
    카테고리: "{카테고리}",
    생성일: "{오늘 날짜}"
  },
  content: {guide-template.md 내용, 플레이스홀더 치환}
)
→ 메인 페이지 ID 획득
```

### 3-4. 서브페이지 6종 생성

`references/subpage-templates.md` 기반으로 순차 생성:

```
[1~6] 각각:
notion-create-pages(
  parent: { page_id: {메인 페이지 ID} },
  title: "{서브페이지 제목}",
  content: {해당 서브페이지 템플릿, 플레이스홀더 치환}
)
```

생성 순서: Quick Start → 프로덕션 체크리스트 → 실전 패턴 → 트러블슈팅 → 스케일링 → 버전 히스토리

→ **서브페이지 ID 6개를 메모리에 보관** (Phase 4 검증 + Update 모드에서 사용)

### CDP 폴백 경로

Anthropic MCP 실패 시:
1. CDP MCP (`notion-mcp-server/server.py`) 폴백 시도
2. CDP도 실패 시: 생성된 마크다운을 출력 + 수동 복사 안내

---

## Phase 4: Verification

```
# 메인 페이지 확인
notion-fetch({메인 페이지 ID})
→ 8섹션 존재 여부 확인

# 서브페이지 6종 확인
notion-fetch({서브페이지 ID}) × 6
→ 각 서브페이지 핵심 섹션 존재 여부 확인
```

### 체크리스트

- [ ] 메인 페이지: 8섹션 모두 존재
- [ ] Quick Start: 의존성 + 설정 + 코드 예시 + Testcontainers
- [ ] 프로덕션 체크리스트: 보안 + 모니터링 + 테스트 + 운영
- [ ] 실전 패턴: 패턴 3개+ + 안티패턴 3개+
- [ ] 트러블슈팅: 증상 3개+ 의사결정 트리 + FAQ + 디버깅 명령어
- [ ] 스케일링: 중규모 + 대규모 섹션
- [ ] 버전 히스토리: 현재 권장 버전 + 버전별 상세

### 실패 시 처리

체크리스트 항목 누락 발견 시:
```
notion-update-page({해당 페이지 ID}, replace_content: {보완된 내용})
→ 1회 수정 시도
→ 재확인 후 여전히 실패면 수동 보완 안내
```

---

## Phase 5: Registry Update

`references/notion-registry.md` Guides 테이블에 행 추가:

```markdown
| {기술명} | {메인 페이지 ID} | {버전} | {생성일} | {생성일} |
```

---

## Update Mode

`/master-guide update <기술명>` 실행 시:

### Phase 0: 페이지 ID 조회
```
references/notion-registry.md에서 {기술명} 행 찾기
→ 페이지 ID 획득
→ 없으면: "registry에 없습니다. 신규 생성할까요?"
```

### Phase 1: 최신 변경사항 조사
```
WebSearch: "{기술명} changelog release notes {현재년도}"
WebSearch: "{기술명} breaking changes migration {현재년도}"
→ 새 버전, Breaking Changes, 주요 변경 파악
```

### Phase 2: 변경 영향 분석
```
변경사항 요약 출력:
- 새 버전: {new_version} (기존: {old_version})
- Breaking Changes: {있음/없음}
- 영향받는 서브페이지: {목록}

업데이트할 서브페이지를 확인해주세요.
```

### Phase 3: 서브페이지 업데이트
```
영향받는 서브페이지 각각:
notion-update-page({서브페이지 ID}, replace_content: {갱신된 내용})
```

### Phase 4: 버전 히스토리 추가
```
버전 히스토리 서브페이지 상단에 새 버전 섹션 추가:
notion-update-page({버전 히스토리 페이지 ID}, prepend_content: {새 버전 섹션})
```

### Phase 5: DB Row 업데이트
```
notion-update-page(
  {메인 페이지 ID},
  properties: {
    버전: "{new_version}",
    최종업데이트: "{오늘 날짜}"
  }
)
```

### Phase 6: Registry 갱신
```
references/notion-registry.md에서 해당 행의 버전 + 최종 업데이트 갱신
```

---

## Prerequisites

### Anthropic Notion MCP (우선)
- `.mcp.json`에 Anthropic Notion MCP 등록 확인
- 필요 도구: `notion-search`, `notion-create-database`, `notion-create-pages`, `notion-fetch`, `notion-update-page`

### CDP MCP (폴백)
- `notion-mcp-server/server.py` 실행 상태 확인
- Notion CDP 포트 9222 활성화 확인

### WebSearch / WebFetch
- Phase 0~1 리서치에 필수
- 없으면: 사용자에게 직접 공식 문서 URL 입력 요청

---

## Example Workflows

### `/master-guide Kafka` 실행 예시

```
[Phase 0]
> tech-keywords.md 확인 → messaging 카테고리 매칭
> WebSearch: "Kafka latest stable version 2026"
  → Kafka 3.9.0 (권장), Spring Boot 3.x 호환
> WebSearch: "Kafka alternatives comparison 2026"
  → RabbitMQ, AWS SQS, Pulsar 선정

사용자 확인:
"Kafka v3.9.0, 비교 대안: RabbitMQ / AWS SQS / Pulsar 로 진행할까요?"

[Phase 1] 병렬 리서치 실행
> [공식] WebFetch(kafka.apache.org/documentation)
> [심층] WebSearch × 3 + WebFetch
> [비교] WebSearch × 2
> [실전] WebSearch × 2

[Phase 2] 플랜 출력 → 사용자 승인

[Phase 3] Notion 작성
> notion-search("Tech Master Guides") → DB 없음
> 부모 페이지 질문 → 사용자 답변
> notion-create-database → data_source_id 획득
> notion-create-pages(메인) → page_id: "abc-123"
> notion-create-pages(서브 × 6) → 완료

[Phase 4] Verification
> notion-fetch × 7 → 체크리스트 통과

[Phase 5] Registry Update
> notion-registry.md: | Kafka | abc-123 | 3.9.0 | 2026-03-28 | 2026-03-28 |

완료: Kafka Master Guide 생성됨
메인 페이지: https://notion.so/abc-123
```

---

## Changelog

| 버전 | 날짜 | 변경 내용 |
|------|------|---------|
| v1 | 2026-03-28 | 최초 생성. Phase 0~5 파이프라인, 듀얼 MCP, Update 모드 포함 |
