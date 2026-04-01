---
name: absorb
description: "외부 기술 아티클 URL을 분석하여 현재 Claude Code 설정에 적용 가능한 패턴/원칙/기법을 도출하고 항목별 승인 후 자동 적용. Use when user says '/absorb <URL>', '이 글에서 적용할 거 찾아줘', '이 링크 분석해서 적용해줘', 'URL 분석 후 적용'."
---

# Absorb — 외부 아티클 → 내 설정에 자동 적용

기술 아티클 URL을 분석하여 현재 CLAUDE.md, hooks, skills, memory에 적용 가능한 아이템을 도출하고, 항목별 승인 후 자동 적용한다.

## When to Apply

- `/absorb <URL>` 호출 시
- 사용자가 링크를 주며 "적용할 내용 찾아줘", "분석해서 적용해줘" 등 요청 시

## 파라미터 파싱

인자에서 URL 추출:
- 첫 번째 URL 패턴 (`https://...`) 을 대상 URL로 사용
- URL이 없으면 에러: "URL을 입력해주세요. 예: `/absorb https://example.com/article`"

## Phase 1: Extract (추출)

1. WebFetch로 아티클 전문 추출. 프롬프트:
   ```
   이 아티클의 전체 내용을 구조화하여 추출해줘:
   1. 메타데이터: title, author, source domain, publish date
   2. 아티클 유형: engineering-blog | tutorial | documentation | case-study | opinion
   3. 핵심 패턴/원칙/기법 목록 (각각: 이름, 1줄 요약, 상세 설명)
   4. 코드 예시 또는 구현 가이드 (있는 경우)
   5. 주요 인사이트 및 교훈
   6. 핵심 주제 태그 3-5개
   ```

2. WebFetch 실패 시 → "URL에 접근할 수 없습니다" 메시지 출력 후 종료

3. 추출 결과를 사용자에게 간략히 보여주기:
   ```
   📖 "<title>" (<type>) by <author>
   🏷️ 태그: tag1, tag2, tag3
   📌 핵심 패턴 N개 식별
   ```

## Phase 2: Analyze (분석)

현재 설정을 읽고 아티클 내용과 대조:

1. **설정 파일 읽기** (병렬):
   - `~/.claude/CLAUDE.md` (글로벌 지침)
   - 현재 프로젝트 CLAUDE.md (있는 경우)
   - `~/.claude/hooks/` — 훅 파일 **내용까지** 읽기 (중복 감지에 필요)
   - `~/.claude/skills/` — 스킬 목록 + 각 SKILL.md의 **description** 읽기
   - `memory/MEMORY.md`

2. **대조 분석**: 아티클의 각 패턴/원칙에 대해:
   - 이미 적용 중 → `status: already_applied` (어디에 있는지 표시)
   - 현재 설정과 충돌 → `status: conflict` (양쪽 내용 기술)
   - 새로 적용 가능 → `status: applicable`

3. 적용 가능 아이템을 5가지 카테고리로 분류:

   | 카테고리 | 대상 | 자동 적용 |
   |----------|------|-----------|
   | `guideline` | CLAUDE.md 규칙 추가/수정 | ✅ 승인 후 |
   | `hook` | hooks 파일 생성/수정 | ✅ 승인 후 |
   | `skill` | skills/ 새 스킬 생성 | ✅ 승인 후 |
   | `architecture` | 코드 구조 변경 | ❌ 제안만 |
   | `memory` | memory/topics/ 인사이트 기록 | ✅ 승인 후 |

4. 각 아이템 구조:
   ```
   - category: guideline
     title: "간결한 제목"
     insight: "핵심 인사이트 1-2문장"
     action: "구체적 적용 방법 (어느 파일, 어느 섹션, 무슨 내용)"
     target_file: "~/.claude/CLAUDE.md"
     effort: low | medium | high
     conflict: null | "충돌 설명"
   ```

## Phase 2.5: Verify & Enhance (Opus 검증)

Phase 2의 분석 결과를 Opus architect 에이전트에 위임하여 심층 검증 + 개선안 도출.
사용자가 `--skip-verify` 플래그를 지정하거나 "검증 스킵" 요청 시 이 Phase를 건너뛰고 Phase 3으로 진행.

1. **Opus architect 에이전트 호출** (model: opus, subagent_type: architect):

   프롬프트에 포함할 내용:
   - Phase 2에서 도출한 적용 가능 항목 전체 (category, title, insight, action, target_file)
   - 현재 CLAUDE.md 전문 (Read 결과)
   - 기존 스킬/훅 목록

   에이전트 지시:
   ```
   각 적용 가능 항목에 대해 아래 5가지를 분석하라:
   A. 현재 상태 정밀 진단: 현재 설정에서 이 기능을 어느 정도 커버하는지, 실제 gap
   B. 적용 시 예상 효과: high/medium/low
   C. 충돌/위험 분석: 기존 규칙과 충돌 가능성, 특히 기존 스킬이 명시적으로 경고하는 패턴과의 충돌
   D. 개선된 적용안: 원본 그대로가 아닌, 현재 CLAUDE.md 구조/컨벤션에 최적화된 구체적 변경 내용
   E. 추가 개선 아이디어: 아티클에는 없지만 원칙을 발전시킬 수 있는 아이디어
   최종으로 권장 적용 우선순위 (즉시/점진적/보류)와 보류 사유를 제시하라.
   ```

2. **Opus 결과 반영**:
   - 적용 가능 항목의 status를 Opus 판단에 따라 재분류:
     - `즉시 적용` → Phase 3에서 최우선 표시
     - `점진적` → Phase 3에서 "(점진적 — Opus 권장)" 라벨
     - `보류` → Phase 3에서 "(보류 — 사유: ...)" 라벨. 적용 가능 목록에서 하단으로 이동
   - Opus가 제안한 **개선된 적용안**으로 action 필드 교체 (원본 action은 backup으로 보존)
   - Opus가 식별한 **충돌**은 해당 항목에 `conflict` 필드 추가
   - Opus가 제안한 **추가 개선 아이디어**는 별도 `[Opus 추가 제안]` 섹션으로 분리

3. **사용자에게 Opus 검증 요약 표시**:
   ```
   🔍 Opus 검증 완료

   [즉시 적용 권장] N건
   [점진적 적용 권장] M건
   [보류 권장] K건 (사유 포함)
   [추가 제안] L건

   원래 분석 대비 변경점:
   - #N: status 변경 (applicable → 보류, 사유: ...)
   - #M: action 개선 (원본: ... → 개선: ...)
   ```

## Phase 3: Approve (승인)

1. 결과를 카테고리별로 그룹화하여 표시 (Phase 2.5의 Opus 검증 결과를 반영):

   ```
   📋 "<아티클 제목>" 분석 완료

   [이미 적용 중] N건
     - 항목명 → 현재 위치

   [적용 가능] M건

   [지침] K건
   1. 항목명 (effort)
      → 인사이트: ...
      → 적용: CLAUDE.md §X에 추가

   [메모리] K건
   ...

   [아키텍처 제안] K건 ⚠️ 별도 세션 권장
   ...
   ```

2. 적용 가능 아이템이 0건이면:
   → "현재 설정에 이미 잘 반영되어 있거나, 참고용 아티클입니다. 핵심 인사이트를 메모리에 기록할까요?"

3. AskUserQuestion(multiSelect=true)으로 적용할 항목 일괄 선택:
   - 각 적용 아이템이 하나의 선택지 (label: 제목, description: 인사이트 + 적용 방법)
   - "전체 적용" 옵션 포함
   - 선택되지 않은 항목 = 스킵
   - `effort: high` 또는 `category: architecture` → 라벨에 "⚠️ 별도 세션 권장" 부착
   - 사용자가 "Other"로 특정 항목의 action 수정 가능 (예: "3번은 §2 대신 §4에 추가해줘")

## Phase 4: Apply (적용)

승인된 항목만 순서대로 적용:

1. 대상 파일 Read
2. 적절한 위치에 Edit:
   - **CLAUDE.md**: 기존 섹션 구조 유지, 관련 섹션에 규칙 추가. 새 섹션 필요 시 기존 넘버링 맞춤
   - **hooks**: 기존 훅 내용이 git tracked 상태임을 확인 (복구 가능). 기존 패턴 따름
   - **skills**: `~/.claude/skills/<name>/SKILL.md` 표준 frontmatter + 본문. 신규 생성 vs 기존 수정 구분
   - **memory**: `memory/topics/` frontmatter 포맷 준수
3. 개별 항목 적용 실패 시 → 해당 항목 스킵 + 실패 목록에 추가. 나머지 계속 진행
4. 각 적용마다 변경 내역 누적

**Note**: git commit은 Phase 5 완료 후 수행 (기록 파일도 함께 커밋)

## Phase 5: Record (기록)

`memory/topics/absorbed-articles.md`에 항목 추가:

```markdown
### YYYY-MM-DD: <아티클 제목>
- **URL**: <url>
- **유형**: <type>
- **적용**: N건 (카테고리별 내역)
- **스킵**: M건
- **실패**: K건 (있는 경우)
- **핵심 인사이트**: 1줄 요약
```

모든 변경사항 (설정 파일 + 기록 파일) git commit:
```
absorb: <아티클 제목 요약> (N건 적용)
```

파일이 없으면 frontmatter 포함하여 새로 생성:
```markdown
---
name: absorbed-articles
description: "/absorb 스킬로 분석한 외부 아티클 이력. 어떤 아티클에서 무엇을 적용했는지 추적."
type: reference
---

# Absorbed Articles

(항목들...)
```

## 주의사항

- **architecture 카테고리**: 코드 직접 수정 금지. 제안만 하고 "별도 세션에서 /absorb 결과를 기반으로 구현하세요" 안내
- **충돌 감지**: 기존 규칙과 충돌 시 양쪽을 보여주고 사용자 판단에 위임. 자의적 판단 금지
- **중복 방지**: 이미 적용된 항목은 "이미 적용 중" 표시만. 중복 추가 금지
- **scope 제한**: 아티클 내용과 직접 관련 없는 "일반적 개선" 제안 금지
