# /fd-verify — Feature Design 검증

구현 완료된 FD의 코드를 검수하고 검증 계획을 실행한다.

## 사전 조건
- $ARGUMENTS로 대상 FD 번호 필수 (예: `/fd-verify 14`)
- 해당 FD의 Status가 `In Progress`여야 함

## 절차

1. 대상 FD 파일을 읽어 `Files to Modify`와 `Verification` 체크리스트를 확인한다.

2. **자동 검증 체인** (Opus verifier 서브에이전트에 위임):
   - 현재 변경사항 커밋: `FD-{NUMBER}: {title} — verification checkpoint`
   - Agent(verifier, model=opus)에 위임: 빌드 검증 + 테스트 실행 (변경 모듈)
   - 코드 리뷰 (code-reviewer + security-reviewer 병렬) — verifier와 별도

3. **FD 자체 검증**:
   - FD의 `Implementation Plan`과 실제 구현 비교
   - 누락된 단계 또는 추가된 변경 식별
   - `Verification` 체크리스트 항목별 통과/실패 기록

4. 결과에 따라:
   - **모두 통과**: Status → `Pending Verification`, 사용자에게 라이브 검증 안내
   - **실패 항목 있음**: 실패 내용 보고, Status 유지 (`In Progress`)

5. FD 파일의 `Changelog`에 검증 결과 기록한다.
6. `FEATURE_INDEX.md` 업데이트한다.

## 규칙
- 검증 실패 시 자동 수정 시도하지 않음 (보고만)
- 라이브 검증은 사용자가 직접 수행 후 `/fd-close`로 마무리
