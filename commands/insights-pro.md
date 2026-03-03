# Insights Pro - 다크 모드 한국어 리포트 생성

`/insights` 실행 후 생성된 리포트를 다크 글래스모피즘 테마 + 한국어로 변환합니다.

## 전제 조건
- 먼저 `/insights`를 실행하여 `~/.claude/usage-data/report.html`이 생성되어 있어야 합니다
- 리포트가 없으면 사용자에게 `/insights`를 먼저 실행하라고 안내하세요

## 실행 단계

1. `~/.claude/usage-data/report.html` 파일을 읽습니다
2. `~/.claude/templates/insights-dark.css` 파일을 읽습니다
3. 아래 디자인 규격에 따라 HTML을 완전히 재구성합니다
4. 결과를 `~/.claude/usage-data/report.html`에 저장합니다
5. 파일 경로를 `file:///` URL로 사용자에게 안내합니다

## 디자인 규격

### 테마
- **다크 글래스모피즘**: 배경 #0a0a0f, 카드 rgba(255,255,255,0.03)
- **폰트**: Pretendard (본문), JetBrains Mono (코드)
- **히어로**: 그래디언트 텍스트 (indigo → purple → pink), 세션 수 표시 배지
- **통계**: 5열 그리드, 그래디언트 숫자
- **Sticky 내비게이션**: backdrop-filter blur, 스크롤 시 상단 고정
- **차트 바**: 섹션별 그래디언트 fill (blue, cyan, green, purple, red, amber)
- **카드**: 섹션별 색상 그래디언트 배경 (green=잘한점, red=마찰, blue=제안, purple=미래, amber=요약)
- **애니메이션**: Intersection Observer 스크롤 fade-in, pulse dot
- **시간대**: KST(UTC+9) 기본 선택

### HTML 구조 (lang="ko")
```
<hero> → 배지 + h1 "Claude Code Insights" + subtitle (한국어 날짜 범위)
<stats-grid> → 5열: 메시지, 추가 라인, 파일, 커밋, 일평균 메시지
<nav-bar> → sticky: 한눈에 보기 | 작업 영역 | 사용 패턴 | 잘한 점 | 개선 포인트 | 추천 기능 | 활용 팁 | 미래 가능성
<glance-card> → amber 테마, 4개 요약 항목
<section: 작업 영역> → area-card 리스트
<charts-grid> → 주요 목표 + 도구 사용량
<charts-grid> → 언어별 분포 + 세션 유형
<section: 사용 패턴> → narrative-card + key-insight-box
<chart: 응답 시간> → indigo 바
<chart: 멀티 클로딩> → multi-stat 3열
<charts-grid> → 시간대별 메시지(KST) + 도구 에러
<section: 잘한 점> → win-card (green)
<charts-grid> → 도움된 기능 + 목표 달성률
<section: 개선 포인트> → friction-card (red)
<charts-grid> → 마찰 유형 + 만족도
<section: 추천 기능> → claude-md-box + feature-card
<section: 활용 팁> → pattern-card (blue)
<section: 미래 가능성> → horizon-card (purple)
<fun-card> → amber, 마무리 유머
```

### 한국어 번역 범위
- **모든 텍스트**: 섹션 제목, 차트 라벨, 통계 라벨, AI 생성 서술 내용 전부 한국어로 번역
- **번역하지 않는 것**: 코드 블록, 명령어, 기술 용어 (Kafka, TestContainers, Spring Boot 등), 히어로 타이틀

### 주요 번역 매핑

| English | Korean |
|---------|--------|
| At a Glance | 한눈에 보기 |
| What You Work On | 작업 영역 |
| How You Use Claude Code | 사용 패턴 |
| Impressive Things You Did | 잘한 점 |
| Where Things Go Wrong | 개선 포인트 |
| Existing CC Features to Try | 추천 기능 |
| Suggested CLAUDE.md Additions | CLAUDE.md 추가 추천 |
| New Ways to Use Claude Code | 새로운 활용 방법 |
| On the Horizon | 미래 가능성 |
| What You Wanted | 주요 목표 |
| Top Tools Used | 도구 사용량 |
| Languages | 언어별 분포 |
| Session Types | 세션 유형 |
| What Helped Most | 가장 도움이 된 기능 |
| Outcomes | 목표 달성률 |
| Primary Friction Types | 주요 마찰 유형 |
| Inferred Satisfaction | 추정 만족도 |
| User Response Time | 사용자 응답 시간 분포 |
| Multi-Clauding | 멀티 클로딩 |
| Debugging | 디버깅 |
| Plugin Management | 플러그인 관리 |
| Multi Task | 멀티 태스크 |
| Single Task | 단일 태스크 |
| Fully Achieved | 완전 달성 |
| Mostly Achieved | 대부분 달성 |
| Partially Achieved | 부분 달성 |
| Not Achieved | 미달성 |
| Frustrated | 좌절 |
| Dissatisfied | 불만족 |
| Likely Satisfied | 만족 |
| Wrong Approach | 잘못된 접근 |
| Copy | 복사 |
| Copy All Checked | 선택 항목 모두 복사 |
| Paste into Claude Code | Claude Code에 붙여넣기 |
| Why for you | 당신에게 유용한 이유 |
| Getting started | 시작 방법 |
| Morning | 오전 |
| Afternoon | 오후 |
| Evening | 저녁 |
| Night | 야간 |
| Messages | 메시지 |
| Lines | 라인 |
| Files | 파일 |
| Median | 중앙값 |
| Average | 평균 |

### CSS 참조
`~/.claude/templates/insights-dark.css` 파일의 CSS를 HTML `<style>` 태그에 inline으로 포함합니다.

### JavaScript 요구사항
- 시간대 선택기: KST(UTC+9) 기본, rawHourCounts 데이터를 원본에서 추출
- 복사 버튼: navigator.clipboard API, 복사 완료 시 "복사됨!" 표시
- CLAUDE.md 체크박스 전체 복사 기능
- Intersection Observer: 카드 스크롤 애니메이션 (fade-in + slide-up)
