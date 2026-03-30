---
name: new-session
description: "Complete session reset. Use when user says '/new', '새 세션', 'new session', '초기화'. Clears all session context so /clear starts fresh without previous conversation memory."
---

# /new — 완전 초기화 (새 세션)

## 실행 순서

1. `~/.claude/memory/sessions/.fresh-start` 플래그 파일을 생성하세요 (내용: 현재 타임스탬프)
2. 현재 프로젝트의 active context 파일을 삭제하세요:
   - 프로젝트명 확인: `~/.claude/hooks/memory-lib.sh`의 `detect_project()` 로직 참고
   - 삭제 대상: `~/.claude/memory/sessions/{project}-context.md`
3. `~/.claude/memory/sessions/.last-session-jsonl` 마커 파일이 있으면 삭제하세요
4. 사용자에게 다음을 출력하세요:

> 세션 초기화 준비 완료. `/clear`를 실행하면 이전 대화 기억 없이 새로 시작합니다.

## 주의사항

- Daily log는 삭제하지 않음 (작업 기록은 보존)
- MEMORY.md는 삭제하지 않음 (장기 기억은 보존)
- `/new`만으로는 대화가 초기화되지 않음 — 반드시 `/clear`가 필요
