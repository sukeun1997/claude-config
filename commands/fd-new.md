# /fd-new — 새 Feature Design 생성

$ARGUMENTS 를 바탕으로 새 FD 파일을 생성한다.

## 절차

1. `docs/features/FEATURE_INDEX.md`를 읽어 다음 FD 번호를 결정한다 (가장 큰 번호 + 1).
2. `docs/features/TEMPLATE.md`를 복사하여 `docs/features/FD-{NUMBER}.md`를 생성한다.
3. 사용자의 아이디어 덤프($ARGUMENTS)를 바탕으로:
   - Title, Problem 섹션을 채운다
   - Status를 `Planned`로 설정
   - Created/Updated를 오늘 날짜로 설정
4. `FEATURE_INDEX.md`의 Active Features 테이블에 새 항목을 추가한다.
5. 생성된 FD 파일 경로를 보고한다.

## 규칙
- FD 번호는 항상 3자리 zero-padding (예: FD-001, FD-012)
- Problem 섹션은 반드시 채우고, Solution은 아직 비워둔다
- 프로젝트별 `docs/features/`가 없으면 현재 프로젝트 루트에 생성
