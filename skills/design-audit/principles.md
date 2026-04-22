# Design Principles (6 Axes)

원본 `frontend-design` skill의 5축 + Claude Design review 축을 감사 관점으로 재구성.

---

## Axis 1. Typography

### 좋음
- Display 폰트(헤드라인)와 Body 폰트(본문)가 구분된 스택
- Font feature (ligatures, tabular nums, variable weight) 활용
- 한국어-영문 혼용 시 영문 폰트가 명시적 (ko fallback이 제네릭 sans로 떨어지지 않음)
- 행간 / 자간이 본문 16px 기준 1.5+ / -0.01em 수준으로 조율

### 나쁨 (AI slop)
- `font-family: Inter, system-ui, sans-serif` 단일 스택 — 모든 요소 동일 폰트
- Arial / Helvetica 직접 지정
- 제목과 본문이 같은 weight (500 하나로 전체 처리)
- `font-feature-settings` 미설정 → 숫자 비정렬, 합자 미적용

### 체크 질문
1. 제목과 본문이 다른 폰트거나 최소 다른 weight인가?
2. 한 페이지에 폰트 크기 종류가 4-5개 범위인가? (2개 = 단조로움, 7개+ = 혼돈)
3. 한국어 본문의 자간·행간이 기본값(0, 1.2)이 아닌, 의도된 값인가?

---

## Axis 2. Color & Contrast

### 좋음
- 1개 dominant + 1-2개 accent + neutral scale. 팔레트가 의도적
- Semantic 색이 기능으로 일관 (성공=초록, 경고=노랑, 오류=빨강)
- 배경과 본문 대비 WCAG AA 통과 (일반 텍스트 4.5:1, 큰 텍스트 3:1)
- Disabled / placeholder 상태 대비가 최소 3:1 유지

### 나쁨
- **보라 그라디언트 + 흰 배경** — 가장 전형적 AI slop
- 모든 버튼이 파란색 primary (위계 실종)
- 회색 14단계 중 실제로 사용하는 건 3-4단계뿐
- 본문이 `#666` 이하 회색 on 흰 배경 (대비 4.5:1 미만)
- Semantic 색을 장식으로 사용 (의미 없는 초록 버튼)

### 체크 질문
1. 색이 **정보 전달**하는가 아니면 **장식**인가?
2. 이 페이지를 흑백으로 변환해도 위계가 살아있는가?
3. 대비 최저 구간 (placeholder, disabled, 보조 텍스트)이 접근성 기준을 넘는가?

---

## Axis 3. Spatial Composition

### 좋음
- 간격 스케일이 소수 (예: 4/8/12/16/24/32/48/64 — 8배수 기반)
- 카드/섹션 간 "숨쉬는 공간" — 세로 리듬이 반복되지 않으면 감점
- 정렬 기준이 일관 — 좌측 정렬 / 중앙 정렬이 섞이지 않음
- Asymmetry / overlap / 그리드 파괴 요소가 **의도적**으로 배치

### 나쁨
- 간격이 11px, 13px, 18px처럼 임의값 (디자인 토큰 미사용)
- 섹션마다 padding이 다른데 규칙성 없음
- 모든 요소가 중앙 정렬 → 리듬 없음
- 한 섹션 내 요소가 꽉 차서 분리 어려움 (dense grouping 실패)

### 체크 질문
1. 간격에 사용된 고유 px 값이 6개 이하인가?
2. 섹션 간 세로 간격이 규칙적인가 (예: 48, 48, 48)?
3. 가장 중요한 요소 주위에 "보호 공간"이 있는가?

---

## Axis 4. Hierarchy & Information Scent

### 좋음
- 시선이 상→하, 좌→우로 흐르는 명확한 경로
- F-pattern / Z-pattern 중 하나를 따르고 의도된 breakpoint가 있음
- 한 화면에 primary action이 하나 — 눈에 즉시 들어옴
- 섹션 헤더가 body와 명백히 구분 (size, weight, color 중 2개 이상)
- 빈 상태 / 에러 상태 / 로딩 상태가 **서로 다른 시각적 언어**를 가짐

### 나쁨
- 같은 레벨의 카드가 8개 — 어디를 봐야 할지 모름
- 헤더와 본문이 같은 weight / size — 그냥 굵은 줄 하나 있음
- Call-to-action이 3개 — 다 중요하다고 외치면 아무것도 안 중요
- 인지 부하: 한 화면에 15개+ 상호작용 가능 요소

### 체크 질문
1. 화면에서 가장 먼저 눈에 들어오는 것은? 그게 가장 중요한가?
2. 사용자가 다음 액션을 **1초 안에** 판단할 수 있는가?
3. 같은 위계로 보이는 요소가 실제로 같은 위계인가?

---

## Axis 5. Distinctiveness (Anti-slop)

### 좋음
- 화면을 보면 **이 서비스구나** 를 기억할 단서가 있음
- 고유한 레이아웃 / 시그니처 컬러 / 특이 타이포 / 고유 일러스트 / 고유 interaction
- 배경이 단색이 아니라 그라디언트/노이즈/패턴/레이어로 atmosphere
- 컴포넌트 모양이 기본값(라운드 카드 + 그림자)을 벗어나 고유

### 나쁨 (Claude Design이 가장 싫어하는 패턴)
1. **보라 그라디언트 + 흰 배경** (vercel/supabase 템플릿 클리셰)
2. Rounded card + soft shadow + icon top-center + title + description — 부트스트랩 템플릿
3. Hero: "Build X Y Z faster" + primary button + secondary button + 3단 feature 카드
4. 무지개 색 gradient border
5. 회색 배경 + 흰 카드 + blue accent만 반복
6. Glassmorphism 남용 (블러 + 반투명)
7. Icon이 모두 stroke 1.5px lucide-react 기본

### 체크 질문
1. 이 화면을 3초 후 덮고 기억할 **유일한 디테일**이 있는가?
2. 경쟁 제품 3개 스크린샷 사이에 이걸 놓으면 구분 가능한가?
3. 배경이 `#ffffff` 또는 `#fafafa` 단색인가? (대부분 그렇다면 atmosphere 부재)

---

## Axis 6. Interaction & Motion

### 좋음
- Hover / focus / active / disabled / loading / empty / error 전체 상태 설계
- 모션은 **고임팩트 순간**에 집중 (페이지 진입, 상태 변화) — 모든 곳에 애니메이션 X
- Transition duration 100-300ms 범위, easing이 기본값(`ease`)이 아님
- Scroll-triggered reveal은 선택적, 과용 금지
- 버튼 클릭 feedback (ripple / scale / color shift 중 하나)

### 나쁨
- Hover 상태가 `opacity: 0.8`만 — 모든 요소 동일 처리
- Loading 상태가 없음 — 클릭 후 2초 공백
- 전역 `transition: all 0.3s` — 의도되지 않은 요소까지 전이
- 스크롤 진입 애니메이션을 모든 요소에 적용 → 페이지 로드가 느려 보임
- Focus ring이 브라우저 기본값 그대로거나 아예 제거됨 (접근성 위반)

### 체크 질문
1. 인터랙션 상태 중 **설계되지 않은 것**이 있는가?
2. 모션이 의미를 전달하는가 아니면 장식인가?
3. 키보드만으로 페이지를 탐색할 수 있는가? (focus 경로)

---

## 프로젝트 제약 우선

프로젝트 CLAUDE.md에 명시된 UI/UX 원칙은 위 원칙보다 **우선**한다.

예: 건물관리 프로젝트
- "큰 글씨 14px+" → Typography 축 최소 크기 기준을 14px로 상향
- "빨=미납, 초=완납, 노=부분납" → Color 축에서 이 규약 위반은 CRITICAL
- "부모님 사용" → Distinctiveness보다 명료함이 우선, 모션 최소화

이 제약들은 감점 사유가 아니라 **평가 기준 자체를 조정**한다.
