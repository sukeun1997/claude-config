# /fd-explore — 세션 부트스트랩

새 에이전트 세션을 시작할 때 프로젝트 컨텍스트를 로드한다.

## 절차

1. 다음 파일들을 순서대로 읽는다:
   - 프로젝트 `CLAUDE.md` (있으면)
   - `docs/features/FEATURE_INDEX.md`
   - Active 상태인 FD 파일들 (최대 5개, 우선순위 높은 순)

2. 코드베이스 구조를 빠르게 파악:
   - 프로젝트 루트의 디렉토리 구조
   - 주요 설정 파일 (build.gradle.kts, package.json 등)

3. 현재 상태 요약 보고:
   - 활성 FD 목록과 각 상태
   - 가장 최근 변경된 파일들
   - 다음 작업 추천

## $ARGUMENTS 사용
- 특정 FD 번호가 주어지면 해당 FD만 집중 로드 (예: `/fd-explore 14`)
- "all"이면 모든 Active FD 로드

## 규칙
- Read-only 작업. 파일 수정 없음
- 컨텍스트 윈도우 효율을 위해 필요 최소한만 로드
