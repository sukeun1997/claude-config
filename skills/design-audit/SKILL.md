---
name: design-audit
description: UI 감사 및 개선 파이프라인. 스크린샷 또는 코드 경로를 받아 Claude Design 수준의 관점(Typography, Color & Contrast, Spatial, Hierarchy, Distinctiveness, Interaction)으로 채점하고 근거+수정 diff를 포함한 리포트를 생성. Use when user says '/design-audit', '디자인 감사', 'UI 리뷰', 'UI 감사', 'design review', '화면 리뷰', '디자인 개선'.
license: MIT
metadata:
  version: "1.0"
  source: "github.com/anthropics/claude-code/plugins/frontend-design (review 버전으로 각색)"
---

# Design Audit

Claude Design이 내부적으로 돌리는 평가 축(`frontend-design` skill의 5원칙 + 접근성/계층 리뷰)을 **감사 워크플로우**로 포팅한 스킬.

생성이 아니라 **개선**이 목적. 기존 UI의 이슈를 증거와 함께 지적하고, 사용자 승인 후 수정을 executor에 위임.

---

## 0. 입력 수집

사용자가 `/design-audit <target>` 형태로 호출. target은 다음 중 하나 이상:

| 입력 | 처리 |
|------|------|
| `.png` / `.jpg` 파일 경로 | vision으로 Read → 실제 렌더링 평가 |
| `.tsx` / `.jsx` / `.vue` / `.html` 파일 경로 | Read → 코드 레벨 감사 |
| URL | WebFetch → HTML/스크린샷 확보 |
| 디렉토리 경로 | Glob으로 관련 UI 파일 수집 (상위 5개까지) |

**원칙**: 스크린샷이 있으면 우선 — Claude Design도 이미지가 있을 때 판단 품질이 급격히 오른다. 없으면 사용자에게 "이 화면을 구동해서 스크린샷을 주시겠어요?" 한 번 요청하되, 없어도 코드만으로 진행.

컨텍스트 추가 수집:
- 페이지 목적 (대시보드? 폼? 리스트?) — 파일명/상위 라우트로 추론
- 디자인 토큰 — 프로젝트의 theme 파일 / tailwind config / CSS 변수 자동 감지
- 사용자/제약 — 프로젝트 CLAUDE.md의 UI/UX 원칙 섹션 Read

---

## 1. 평가 루브릭 (6축)

각 축은 `rubric.md`에 0–5점 채점 기준. 로드는 lazy — 리포트 작성 단계에서만 Read.

| 축 | 질문 | 원본 frontend-design 매핑 |
|---|------|--------------------------|
| **Typography** | 폰트가 제네릭한가? 위계(display/body)가 있는가? | Typography |
| **Color & Contrast** | 색 신호가 의미를 전달하는가? WCAG AA 대비? | Color & Theme + accessibility |
| **Spatial** | 간격 vocabulary가 일관? 숨쉬는 공간? 정렬? | Spatial Composition |
| **Hierarchy** | 시선 흐름이 명확? 같은 레벨 반복? 인지 부하? | (Claude Design review 축) |
| **Distinctiveness** | AI slop인가 — 보라 그라디언트, Inter+흰 배경, 제네릭 카드? | Critical Principles |
| **Interaction** | Hover/focus/loading/empty 상태 설계? 모션 의도? | Motion (선택적) |

---

## 2. 파이프라인

```
1. Intake        → target 수집, 컨텍스트 파악
2. Extract       → 디자인 토큰 자동 감지 (색, 폰트, 간격 스케일)
3. Score         → 6축 각각 0-5점 + 증거 (파일:줄 or 스크린샷 영역)
4. Report        → templates/audit-report.md 형식으로 출력
5. Approve & Fix → 사용자 승인 시 executor(sonnet)에게 CRITICAL/HIGH 수정 위임
```

### 2.1 Intake
`principles.md`를 먼저 Read하여 평가 관점을 로드. 그 다음 target 파일들을 Read/View.

### 2.2 Extract (디자인 토큰 감지)
프로젝트에서 아래 파일을 Glob으로 찾고, 존재하는 것만 Read:
- `tailwind.config.*`, `theme.ts`, `*.css` (CSS 변수), `antd` theme 오버라이드
- `package.json` — 사용 중인 UI 라이브러리 확인

추출 결과: 현재 색 팔레트 / 폰트 스택 / 간격 스케일. 이 스킬의 감사는 **프로젝트의 실제 시스템을 존중**하며, "이 시스템에서 일관성이 깨진 지점"을 우선 지적한다. 외부 취향을 강요하지 않는다.

### 2.3 Score
각 축에 대해:
1. 2-3줄 관찰 (무엇을 봤는가)
2. 점수 0-5 (`rubric.md` 기준)
3. 증거 — 스크린샷이면 "영역: 상단 히어로 카드" / 코드면 `path/to/file.tsx:42`
4. **이슈** — 구체 문제를 한 줄로 (예: "버튼 3개가 동일 강조 → primary 단일화")
5. **수정 제안** — 적용 가능한 1-3줄 코드/디자인 토큰 diff

한 축당 최대 3개 이슈. 더 많으면 severity 기준 상위 3개.

### 2.4 Report
`templates/audit-report.md` 형식 사용. 산출물:
- Exec Summary (3줄 이내, 전반 평가)
- 6축별 점수 + 증거 + 이슈 + 제안
- Severity 분류: CRITICAL (사용자 차단) / HIGH (품질 저하) / MEDIUM (개선) / LOW (취향)
- Top-3 Fix 우선순위 (이 3개만 고쳐도 체감 큼)

### 2.5 Approve & Fix (선택)
사용자가 "고쳐줘" / "apply" 확인 시:
- CRITICAL + HIGH만 우선 추출
- `executor` 에이전트 (sonnet)에게 위임, 완료 조건 = "본 리포트의 Top-3 Fix를 diff로 적용, 빌드 통과"
- 단일 파일 + 100줄 이하면 메인이 직접 Edit 가능

사용자가 승인하지 않으면 리포트만 반환하고 종료.

---

## 3. Anti-slop 규칙 (Distinctiveness 축 강화)

원본 `frontend-design` skill의 Critical Principles를 감사 관점으로 뒤집은 것. 아래 패턴 발견 시 **자동으로 HIGH severity**:

- 보라/바이올렛 그라디언트 on 흰 배경
- Inter / Arial / Helvetica만으로 구성된 타이포 스택
- 카드 그리드 3열 + 동일 패딩 + 아이콘 상단 + 제목 + 설명 (전형적 AI 템플릿)
- Primary 버튼이 같은 페이지에 3개 이상 (위계 실종)
- 전체 중립 회색톤 + 한 가지 blue accent — "안 틀렸지만 기억 안 남"

단, **프로젝트 제약이 강제하는 경우 제외**. 예: 이 프로젝트 `CLAUDE.md`의 "큰 글씨 / 빨=미납, 초=완납, 노=부분납"은 기능적 제약이므로 Distinctiveness 감점 대상 아님.

---

## 4. 프로젝트별 제약 주입

스킬 실행 시 **프로젝트 CLAUDE.md의 UI/UX 원칙 섹션**을 먼저 Read. 거기에 명시된 제약(접근성 요구, 사용자 연령, 컬러 규약 등)은 감사 기준에 **가산** 된다.

예: 건물관리 프로젝트는 부모님 사용 → 타이포 14px+ 기준을 더 엄격하게, 빨/초/노 컬러 의미를 위반하는 색 사용은 CRITICAL.

프로젝트 CLAUDE.md에 해당 섹션이 없으면 글로벌 기본값만 사용.

---

## 5. 출력 분량 & 톤

- 리포트 본문 **300-500줄** 범위 (너무 짧으면 무성의, 너무 길면 노이즈)
- 각 이슈는 **증거 먼저, 처방 다음** — "이 부분이 문제다"보다 "A영역 B요소가 C 때문에 D 문제"
- 점수는 **정직하게**. 모두 4점 주면 신호가 죽는다. 1-2점이 나오는 축이 없다면 감사가 무르다는 뜻
- **칭찬도 구체적으로** — 잘한 부분이 있으면 왜 잘했는지 한 줄. 시스템이 의도적으로 설계됐는지 확인하는 시그널

---

## 6. 상세 참조 파일

- [`principles.md`](principles.md) — 6축 상세 원칙 + 안티패턴 카탈로그 (AI slop 예시)
- [`rubric.md`](rubric.md) — 0-5점 채점 기준표 + 증거 표준
- [`templates/audit-report.md`](templates/audit-report.md) — 출력 템플릿

Lazy-load: 파이프라인 단계에 따라 필요한 파일만 Read. SKILL.md만으로는 상세 기준 판단 불가.

---

## 7. 실패 모드

- 스크린샷+코드 둘 다 없음 → 사용자에게 "최소 하나 필요합니다. 화면 경로나 코드 경로를 주세요." 반환
- target 파일이 프레임워크 불명 → 프레임워크 질문 대신 HTML 수준의 일반 원칙만 적용
- 6축 중 해당 없음 축 (예: 정적 이미지에 Interaction) → "N/A, 이미지 입력으로 평가 불가"로 표기하고 감점 없음
