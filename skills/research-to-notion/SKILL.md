---
name: research-to-notion
description: "주제를 심층 리서치하여 Notion 페이지로 생성. AI/일반 기술/제품/트렌드/비교 분석에 적합. 업무 기술(Spring, Kafka 등)은 master-guide 스킬로 안내. Use when user says 'research and write to notion', '분석해서 노션에 정리', URL + '정리해줘/분석해줘'."
---

# Research to Notion v3 — 리서치 → 주제분석 → 시각자료 수집 → Notion 페이지 생성

주제를 자동 분류하고, 유형에 맞는 섹션을 구성하며, 관련 이미지/다이어그램을 수집하여 본문에 인라인 배치하는 종합 리서치 파이프라인.

## When to Apply

- 사용자가 특정 주제를 분석하여 Notion에 정리하려 할 때
- "~에 대해 분석해서 노션에 정리해줘" 패턴
- URL 링크 + "정리해줘/분석해줘/노션에" 패턴
- GitHub 레포, 기술 스택, 제품 분석 등 심층 리서치가 필요한 경우

## Pipeline Overview (v3)

```
Phase 0: Topic Analysis
  → 주제 유형 판별 (6가지 분류)
  → 해당 유형의 섹션 템플릿 로드
  → 검색 키워드 자동 생성

Phase 1: Research + Visual (병렬)
  ├── [텍스트] WebSearch 3-5회 (다양한 키워드/한영)
  ├── [텍스트] WebFetch 5-10개 핵심 소스 심층 읽기
  └── [이미지] 각 소스에서 img src URL 병렬 추출
      → prompt: "이 페이지의 다이어그램/아키텍처/인포그래픽 이미지 URL 추출"

Phase 1.5: Visual Gap Fill (조건부)
  └── 이미지 < 섹션 수의 50% → 추가 이미지 전용 검색
      → "{주제} architecture diagram infographic"
      → 발견된 기사에서 img src 추출

Phase 2: Plan
  → 섹션 구조 설계 (유형별 템플릿 기반)
  → 각 섹션에 매칭할 이미지 지정 (이미지 매핑 테이블)
  → 사용자 피드백 후 확정

Phase 3: Write to Notion
  → Anthropic MCP 우선 (mcp__claude_ai_Notion__*)
  → 실패 시 CDP MCP 폴백 (mcp__notion-cdp__*)
  → 이미지는 ![alt](url) 마크다운으로 각 섹션 본문에 인라인 삽입

Phase 4: Verification
  → notion-fetch로 렌더링 확인
  → 이미지 임베드 존재 여부 체크

Phase 5: Opus Content Review
  → architect 에이전트(opus)로 내용 검증
  → 사실 정확성, 논리 흐름, 깊이, 누락 체크
  → 주요 이슈 발견 시 자동 수정 반영
```

---

## Phase 0: Topic Analysis

### 업무 기술 분기 (Phase 0 첫 단계)

1. 입력 주제가 `~/.claude/skills/master-guide/references/tech-keywords.md`의 키워드와 매칭되는지 확인
2. 매칭되면 → 사용자에게 분기 질문:
   > "이 주제는 업무 기술입니다. 어떻게 진행할까요?
   > 1. `/master-guide {기술명}` — 심층 학습 가이드 (개념+이론+실무+트러블슈팅)
   > 2. 일반 리서치 — 현재 스킬로 계속"
3. 사용자가 1 선택 → master-guide 스킬로 전환 (이 스킬 종료)
4. 사용자가 2 선택 또는 키워드 미매칭 → 기존 로직 그대로 진행

### 주제 유형 분류

입력된 주제/URL을 분석하여 6가지 유형 중 하나로 판별:

| 유형 | 트리거 키워드 | 예시 |
|------|-------------|------|
| **기술/프레임워크** | AI, 프레임워크, 프로토콜, 아키텍처, ~란? | "에이전틱 AI", "MCP 프로토콜", "RAG" |
| **제품/서비스** | ~앱, ~서비스, ~플랫폼, 회사명 | "Cursor", "Devin", "Notion AI" |
| **개념/방법론** | ~패턴, ~방법론, ~전략, ~원칙 | "TDD", "마이크로서비스", "DevOps" |
| **이슈/트렌드** | 뉴스 URL, ~동향, ~전망, 최신 | "AI 규제 동향", "2026 기술 전망" |
| **비교/분석** | vs, 비교, 차이, 선택 | "React vs Vue", "AWS vs GCP" |
| **튜토리얼/가이드** | 사용법, 시작하기, 구축, 만들기 | "LangChain 시작하기" |

### 유형별 필수 섹션 템플릿

`references/topic-templates.md` 참조. 6가지 유형별 필수/선택 섹션이 정의되어 있다.

### 검색 키워드 자동 생성

유형에 따라 Phase 1에서 사용할 검색 키워드를 자동 생성:

```yaml
기술/프레임워크:  # 예: "에이전틱 AI"
  텍스트 검색:
    - "{topic} 정의 개념 {year}"
    - "{topic} architecture components diagram"
    - "{topic} vs 비교 차이점"
    - "{topic} use cases applications industry"
    - "{topic} market size forecast Gartner McKinsey"
    - "{topic} 한국 기업 도입 사례 {year}"
    - "{topic} latest news trends {year}"
  이미지 검색:
    - "{topic} architecture diagram infographic"
    - "{topic} workflow loop diagram"
    - "{topic} comparison chart"

제품/서비스:
  텍스트 검색:
    - "{topic} review features {year}"
    - "{topic} vs 경쟁제품 comparison"
    - "{topic} pricing plans"
    - "{topic} architecture tech stack"
    - "{topic} 사용후기 장단점"
  이미지 검색:
    - "{topic} screenshot UI"
    - "{topic} architecture diagram"
    - "{topic} comparison chart"

개념/방법론:
  텍스트 검색:
    - "{topic} definition principles"
    - "{topic} process workflow steps"
    - "{topic} vs 기존 방법론"
    - "{topic} maturity model adoption"
    - "{topic} tools frameworks"
  이미지 검색:
    - "{topic} workflow process diagram"
    - "{topic} maturity model"
    - "{topic} principles infographic"

이슈/트렌드:
  텍스트 검색:
    - "{topic} {year} latest"
    - "{topic} 한국 동향"
    - "{topic} industry impact analysis"
    - "{topic} 글로벌 동향 전망"
  이미지 검색:
    - "{topic} infographic statistics"
    - "{topic} market trend chart"

비교/분석:
  텍스트 검색:
    - "{topicA} vs {topicB} comparison {year}"
    - "{topicA} vs {topicB} benchmark performance"
    - "{topicA} vs {topicB} 차이점 비교"
    - "{topicA} architecture" / "{topicB} architecture"
  이미지 검색:
    - "{topicA} vs {topicB} comparison chart"
    - "{topicA} architecture diagram"
    - "{topicB} architecture diagram"

튜토리얼/가이드:
  텍스트 검색:
    - "{topic} getting started tutorial {year}"
    - "{topic} step by step guide"
    - "{topic} troubleshooting common errors"
    - "{topic} best practices"
  이미지 검색:
    - "{topic} setup screenshot"
    - "{topic} workflow diagram"
```

---

## Phase 1: Research + Visual (병렬)

### 텍스트 리서치

1. **WebSearch** 3-5회 (Phase 0에서 생성된 키워드 사용)
2. **WebFetch** 5-10개 핵심 소스 심층 읽기 (병렬 3-5개 동시)
3. 소스 카테고리화:
   - 공식 문서 / 기술 분석
   - 개발자 철학 / 인터뷰
   - 비교 / 맥락 분석

### 이미지 수집 (텍스트 리서치와 병렬)

WebFetch 시 텍스트와 함께 이미지도 동시 추출:

```
WebFetch(url, prompt="이 페이지의 모든 다이어그램/아키텍처/인포그래픽 이미지 URL(img src)을 추출해줘")
```

**이미지 수집 규칙:**
- webp/png/jpg만 (svg 제외 — Notion 임베드 불안정)
- 최소 width 600px 이상 (1024px 추천)
- 로고, 배너, 광고 이미지 제외
- 핫링크 차단 가능성 높은 도메인 주의

**이미지 소스 우선순위:**
1. 리서치 소스 기사 내 이미지 (가장 관련성 높음)
2. 기술 블로그 (ByteByteGo, AWS docs, 공식 문서)
3. 전용 검색 결과

### 병렬 실행 팁

```
# 텍스트 + 이미지 동시 수집 (한 소스에서)
WebFetch(url, prompt="본문 내용을 자세히 요약하고, 모든 다이어그램/인포그래픽 이미지 URL도 추출해줘")
```

---

## Phase 1.5: Visual Gap Fill (조건부)

수집된 이미지 수 < 섹션 수의 50% 일 때만 실행:

```
WebSearch("{topic} architecture diagram infographic")
→ 발견된 기사에서 WebFetch로 img src 추출
→ 섹션별 매핑
```

### 이미지 폴백 정책

- 핫링크 차단 감지: 이미지 URL이 403/404 반환 가능성 인지
- 대체 소스 우선: ByteByteGo, AWS docs, 공식 문서 블로그
- 최종 폴백: 이미지 없는 섹션은 텍스트 설명으로 대체 (무리하게 넣지 않음)
- 이미지 정책: **best-effort** — 이미지 없어도 페이지 생성 중단하지 않음

---

## Phase 2: Plan

### 플랜 구조

```markdown
# {주제} 분석 플랜

## 목적
{왜 이 분석을 하는지}

## 주제 유형
{판별된 유형} → {적용 템플릿}

## 섹션 구조
### 1. {섹션명}
- 핵심 포인트 1
- 핵심 포인트 2
- 이미지: {매핑된 이미지 URL 또는 "없음"}

### 2. {섹션명}
...

## 이미지 매핑
| 섹션 | 이미지 | 출처 |
|------|--------|------|
| 1. 개요 | 메인 이미지 URL | 출처 |
| 3. 아키텍처 | 다이어그램 URL | 출처 |
...

## 참고 자료
- [소스명](URL) - 활용 내용 설명
```

### 이미지 매핑 규칙

| 섹션 유형 | 이미지 유형 |
|-----------|-----------|
| 개념 정의 | 개요 다이어그램 / 메인 이미지 |
| 아키텍처 | 구성요소 다이어그램 |
| 비교 | 비교 인포그래픽 (없으면 테이블 대체) |
| 워크플로우 | 플로우 다이어그램 |
| 시장/통계 | 차트 (없으면 텍스트 통계) |
| 응용 사례 | 산업별 아이콘/다이어그램 |

### 사용자 피드백 루프

- 플랜 작성 후 반드시 사용자에게 보여주고 피드백 받기
- 섹션 추가/삭제/수정 반영
- "진행해" 확인 후 다음 단계로

---

## Phase 3: Write to Notion (듀얼 MCP)

### Notion MCP 경로 (우선순위)

```
1차: Anthropic Notion MCP (mcp__claude_ai_Notion__*)
  - notion-search → 부모 페이지 찾기
  - notion-create-pages → 페이지 + 전체 콘텐츠 한번에 생성
  - notion-update-page (replace_content_range) → 부분 수정
  - notion-fetch → 검증

2차: CDP Notion MCP (mcp__notion-cdp__*) — 폴백
  - search_notion → 부모 찾기
  - create_notion_page → 생성
  - write_to_notion_page → 콘텐츠 추가
  - read_notion_page → 검증

판단: Anthropic MCP 도구가 응답하면 계속 사용, 연결 에러 시 CDP 전환
```

### 부모 페이지 찾기

```
# Anthropic MCP
mcp__claude_ai_Notion__notion-search(query="부모 페이지 키워드")

# CDP 폴백
mcp__notion-cdp__search_notion(query="부모 페이지 키워드")
```

### 페이지 생성

```
# Anthropic MCP — 페이지 + 콘텐츠 동시 생성
mcp__claude_ai_Notion__notion-create-pages(
  parent={"page_id": "부모ID"},
  pages=[{
    "properties": {"title": "제목"},
    "content": "전체 마크다운 콘텐츠..."
  }]
)

# CDP 폴백 — 생성 후 콘텐츠 분리 추가
mcp__notion-cdp__create_notion_page(parent_page_id="부모ID", title="제목")
mcp__notion-cdp__write_to_notion_page(page_id="새ID", markdown="콘텐츠...")
```

### 부분 수정 (Anthropic MCP 전용)

```
mcp__claude_ai_Notion__notion-update-page(
  page_id="ID",
  command="replace_content_range",
  selection_with_ellipsis="# 기존 섹션...섹션 끝",
  new_str="# 수정된 섹션\n새 내용..."
)
```

### 콘텐츠 구조 템플릿

```markdown
# 개요
![메인 이미지](url)
> 핵심 한줄 요약 또는 인용구
---

# 1. {개념 정의}
![개념 다이어그램](url)
> 출처: [소스명](url) — 간단 설명
본문 내용...

# 2. {비교/분류}
비교 테이블 (Notion 네이티브 table)

# 3. {아키텍처/구조}
![아키텍처 다이어그램](url)
> 출처: [소스명](url)
상세 설명...

# N. {각 섹션}
[관련 이미지 있으면 섹션 상단에 삽입]
본문...

---
# 참고 자료
- [소스명](URL) — 활용 내용 설명

# 시각자료 출처
- [이미지 원본 출처](URL) — 설명
```

**이미지 인라인 배치 원칙:**
- 각 섹션 제목 바로 아래에 관련 이미지 삽입
- 이미지 아래에 `> 출처:` 인용 블록으로 출처 명시
- 부록이 아닌 본문 흐름에 자연스럽게 배치
- 이미지 없는 섹션은 텍스트만으로 구성 (무리하게 넣지 않음)

---

## Phase 4: Verification

### 페이지 확인

```
# Anthropic MCP
mcp__claude_ai_Notion__notion-fetch(id="페이지ID")

# CDP 폴백
mcp__notion-cdp__read_notion_page(page_id="페이지ID")
```

### 체크리스트
- [ ] 모든 섹션이 정상 렌더링되는가
- [ ] 이미지 임베드가 존재하는가 (`![` 패턴 확인)
- [ ] 표가 네이티브 table로 변환되었는가
- [ ] 참고 자료 링크가 유효한가
- [ ] 빈 섹션 없는지 확인 (제목만 있고 내용 없는 경우)
- [ ] 비교표/데이터 테이블이 네이티브 table로 렌더링되는지
- [ ] 이미지 블록에 실제 URL이 있는지 (빈 ![](url) 방지)

### 오류 시 수정

```
# Anthropic MCP — 부분 교체
mcp__claude_ai_Notion__notion-update-page(
  page_id="ID",
  command="replace_content_range",
  selection_with_ellipsis="문제 섹션 시작...문제 섹션 끝",
  new_str="수정된 내용"
)

# CDP 폴백 — 삭제 후 재작성
mcp__notion-cdp__delete_notion_blocks(page_id="ID", block_count=N)
mcp__notion-cdp__write_to_notion_page(page_id="ID", markdown="수정된 내용")
```

---

## Phase 5: Opus Content Review

Phase 4 검증 완료 후, **architect 에이전트(opus)**로 내용 품질을 검증한다.

### 실행 방법

```
Agent(
  subagent_type="architect",
  model="opus",
  prompt="아래 Notion 페이지의 내용을 검토해줘. 페이지 ID: {페이지ID}

검토 기준:
1. 사실 정확성: 잘못된 정보, 과장, 오해의 소지
2. 논리 흐름: 섹션 간 연결, 빠진 핵심 개념
3. 깊이와 실용성: 읽고 나서 실제로 적용할 수 있는 수준인지
4. 중복/불필요: 반복되거나 불필요한 내용
5. 누락: 다뤄야 하지만 빠진 중요 주제

코드를 수정하지 말고 리뷰 결과만 반환해줘. 한국어로 작성."
)
```

### 리뷰 결과 처리

1. 리뷰 결과를 사용자에게 **요약 테이블**로 제시 (심각도/항목/문제/수정안)
2. 사용자가 "진행" 시 → `notion-update-page`로 주요 이슈 자동 수정
3. 사용자가 "스킵" 시 → 수정 없이 종료

### 자동 수정 기준

| 심각도 | 처리 |
|--------|------|
| 심각 (사실 오류) | 반드시 수정 |
| 중간 (부정확/누락) | 수정 권장, 사용자 확인 후 |
| 경미 (표기/수치) | 일괄 수정 |

---

## Prerequisites

**Anthropic MCP (우선):**
- Claude.ai Notion 연동이 활성화되어 있으면 자동 사용
- 별도 앱 실행 불필요

**CDP MCP (폴백):**
- Notion Electron 앱이 `--remote-debugging-port=9222`로 실행 중
- 런처: `/Users/sukeun/IdeaProjects/관리/launch-notion.sh`
- Notion MCP 서버가 `.mcp.json`에 등록됨

---

## Example Workflows

### 기술 리서치 (가장 일반적)

```
사용자: "에이전틱 AI에 대해 노션에 정리해줘"

Phase 0: → 유형: 기술/프레임워크 → 10개 필수 섹션 로드
Phase 1: → WebSearch 5회 + WebFetch 8개 소스 (이미지 병렬 추출)
          → 텍스트 소스 8개, 이미지 12개 수집
Phase 2: → 12섹션 플랜 + 이미지 매핑 테이블 → 사용자 승인
Phase 3: → Anthropic MCP로 Notion "AI" 하위에 페이지 생성
Phase 4: → notion-fetch로 렌더링 확인 완료
Phase 5: → Opus 내용 검증 → 이슈 수정 반영
```

### URL 기반 분석

```
사용자: "https://news.google.com/... 이거 분석해서 노션에 정리해줘"

Phase 0: → URL 분석 → 유형: 이슈/트렌드
          → Google News RSS는 리다이렉트 → WebSearch로 원본 기사 탐색
Phase 1: → 원본 기사 + 관련 소스 리서치 + 이미지 수집
Phase 2: → 8섹션 플랜 (배경, 핵심 내용, 글로벌/한국 동향, 전망...)
Phase 3: → Notion 페이지 생성
Phase 4: → 검증
Phase 5: → Opus 내용 검증 → 이슈 수정 반영
```

### 비교 분석

```
사용자: "React vs Vue vs Svelte 비교해서 노션에 정리해줘"

Phase 0: → 유형: 비교/분석 → 7개 필수 섹션
Phase 1: → 각 프레임워크별 검색 + 비교 검색 (병렬)
          → 벤치마크 차트, 아키텍처 다이어그램 수집
Phase 2: → 대형 비교표 중심 플랜
Phase 3: → Notion 페이지 생성 (비교표는 네이티브 table)
Phase 4: → 검증
Phase 5: → Opus 내용 검증 → 이슈 수정 반영
```

---

## Changelog

- **v4** (2026-03-29): Phase 5 Opus Content Review 단계 추가
- **v3** (2026-02-28): 주제 유형 자동 분류, 이미지 병렬 수집, Anthropic MCP 듀얼 경로, 인라인 이미지 배치
- **v2** (2026-02-18): CDP MCP 기반, TypeScript 레거시 제거
- **v1** (초기): TypeScript CDP 직접 사용
