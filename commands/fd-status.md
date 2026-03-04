# /fd-status — Feature Design 상태 대시보드

현재 프로젝트의 FD 인덱스를 읽어 상태를 보고한다.

## 절차

1. `docs/features/FEATURE_INDEX.md`를 읽는다.
2. 아래 형식으로 요약 보고:

```
📋 Feature Design Status
━━━━━━━━━━━━━━━━━━━━━━━
🔵 Active:              {count}개
🟡 Pending Verification: {count}개
✅ Completed:           {count}개
⏸️  Deferred/Closed:     {count}개
━━━━━━━━━━━━━━━━━━━━━━━
```

3. Active 상태인 FD를 우선순위별로 나열한다.
4. Pending Verification이 있으면 `/fd-verify` 실행을 제안한다.

## 규칙
- `FEATURE_INDEX.md`가 없으면 "FD 시스템 미초기화. `/fd-new`로 시작하세요." 안내
- 실제 FD 파일과 인덱스가 불일치하면 경고
