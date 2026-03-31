# /fd-close — Feature Design 아카이빙

검증 완료된 FD를 아카이브하고 인덱스를 업데이트한다.

## 사전 조건
- $ARGUMENTS로 대상 FD 번호 필수 (예: `/fd-close 14`)
- 해당 FD의 Status가 `Pending Verification` 또는 `Complete`여야 함

## 절차

1. 대상 FD 파일을 읽는다.

2. FD 파일 업데이트:
   - Status → `Complete`
   - Updated → 오늘 날짜
   - Changelog에 완료 기록 추가

3. `FEATURE_INDEX.md` 업데이트:
   - Active Features에서 제거
   - Recently Completed에 추가 (날짜 포함)

4. FD 파일을 `docs/features/archive/`로 이동한다.

5. 변경 로그 커밋: `FD-{NUMBER}: Complete — {title}`

## Deferred/Closed 처리
- $ARGUMENTS에 `--defer` 또는 `--close` 플래그가 있으면:
  - `--defer`: Status → `Deferred`, 사유 기록, Deferred 테이블로 이동
  - `--close`: Status → `Closed`, 사유 기록, Deferred/Closed 테이블로 이동
  - 어느 경우든 archive/로 이동

## 규칙
- 아카이브된 FD는 삭제하지 않음 (과거 결정 참조용)
- `/fd-explore` 시 archive/ 파일도 검색 가능하도록 유지
